import os
import json
import urllib.request
import urllib.error
import math
from pathlib import Path

import osmium
import shapely.wkb as wkblib
from shapely.geometry import Point, LineString, Polygon, mapping
import geopandas as gpd
from pyproj import Transformer

from config import RAW_DIR, PROCESSED_DIR, PBF_URL, PBF_FILENAME, PILOT_BBOX, MANIFESTS_DIR, WORKING_CRS, OSM_CRS

wkbfab = osmium.geom.WKBFactory()

class PilotHandler(osmium.SimpleHandler):
    def __init__(self, bbox):
        super(PilotHandler, self).__init__()
        self.bbox = bbox # (min_lon, min_lat, max_lon, max_lat)
        self.roads = []
        self.buildings = []
        self.water = []
        self.green = []
        self.rail = []
        
        self.transformer = Transformer.from_crs(OSM_CRS, WORKING_CRS, always_xy=True)

    def in_bbox(self, lon, lat):
        return (self.bbox[0] <= lon <= self.bbox[2] and
                self.bbox[1] <= lat <= self.bbox[3])

    def way(self, w):
        # We only care about objects with certain tags
        if not (w.tags.get("highway") or w.tags.get("building") or w.tags.get("water") or w.tags.get("natural") or w.tags.get("landuse") or w.tags.get("railway")):
            return
            
        try:
            wkb = wkbfab.create_linestring(w)
            geom = wkblib.loads(wkb, hex=True)
            
            # Simple bbox check (centroid)
            if not self.in_bbox(geom.centroid.x, geom.centroid.y):
                return
                
            # Transform to UTM 32N
            if geom.geom_type == 'LineString':
                transformed_coords = [self.transformer.transform(x, y) for x, y in geom.coords]
                geom = LineString(transformed_coords)
            elif geom.geom_type == 'Polygon':
                transformed_exterior = [self.transformer.transform(x, y) for x, y in geom.exterior.coords]
                geom = Polygon(transformed_exterior)
                
            feature = {
                "type": "Feature",
                "geometry": mapping(geom),
                "properties": {k: v for k, v in w.tags}
            }
            feature["properties"]["osm_id"] = w.id
            
            if w.tags.get("highway"):
                self.roads.append(feature)
            if w.tags.get("building"):
                # Treat as polygon if closed
                if w.is_closed():
                    try:
                        wkb_poly = wkbfab.create_multipolygon(w)
                        geom_poly = wkblib.loads(wkb_poly, hex=True)
                        if geom_poly.geom_type == 'MultiPolygon':
                            geom_poly = list(geom_poly.geoms)[0] # Just take first part for MVP
                        transformed_exterior = [self.transformer.transform(x, y) for x, y in geom_poly.exterior.coords]
                        geom_poly = Polygon(transformed_exterior)
                        feature["geometry"] = mapping(geom_poly)
                    except:
                        pass
                self.buildings.append(feature)
            if w.tags.get("railway"):
                self.rail.append(feature)
            if w.tags.get("water") or w.tags.get("natural") == "water":
                self.water.append(feature)
            if w.tags.get("landuse") in ["grass", "forest", "park", "meadow"]:
                self.green.append(feature)
                
        except Exception as e:
            pass # Ignore invalid geometries for now

def download_pbf():
    filepath = RAW_DIR / PBF_FILENAME
    if filepath.exists():
        print(f"Using cached PBF: {filepath}")
        return filepath
        
    print(f"Downloading {PBF_URL}...")
    import requests
    response = requests.get(PBF_URL, verify=False, stream=True)
    response.raise_for_status()
    with open(filepath, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)
    print("Download complete.")
    return filepath

def run_pipeline():
    filepath = download_pbf()
    
    print("Extracting pilot area features...")
    handler = PilotHandler(PILOT_BBOX)
    handler.apply_file(str(filepath), locations=True)
    
    print(f"Extracted {len(handler.roads)} roads, {len(handler.buildings)} buildings.")
    
    # Save as GeoJSON
    def save_geojson(features, name):
        out_path = PROCESSED_DIR / f"pilot_{name}.geojson"
        with open(out_path, "w") as f:
            json.dump({
                "type": "FeatureCollection",
                "features": features
            }, f)
            
    save_geojson(handler.roads, "roads")
    save_geojson(handler.buildings, "buildings")
    save_geojson(handler.rail, "rail")
    save_geojson(handler.water, "water")
    save_geojson(handler.green, "green")
    
    # Save Manifest
    manifest = {
        "pilot_area": PILOT_BBOX,
        "crs": WORKING_CRS,
        "counts": {
            "roads": len(handler.roads),
            "buildings": len(handler.buildings),
            "rail": len(handler.rail),
            "water": len(handler.water),
            "green": len(handler.green)
        }
    }
    with open(MANIFESTS_DIR / "pilot_manifest.json", "w") as f:
        json.dump(manifest, f, indent=2)
        
    print("Pipeline complete.")

if __name__ == "__main__":
    run_pipeline()
