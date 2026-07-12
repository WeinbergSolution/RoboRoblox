import os
import json
from pathlib import Path
from datetime import datetime

import osmium
import shapely.wkb as wkblib
from shapely.geometry import Point, LineString, Polygon, mapping, box
import geopandas as gpd
from pyproj import Transformer
import requests

from config import RAW_DIR, PROCESSED_DIR, PBF_URL, PBF_FILENAME, PILOT_BBOX, MANIFESTS_DIR, WORKING_CRS, OSM_CRS

wkbfab = osmium.geom.WKBFactory()

def generate_tile_id(e, n, size=500):
    grid_e = int(e // size * size)
    grid_n = int(n // size * size)
    return f"NO_E{grid_e}_N{grid_n}_{size}"

class PilotHandler(osmium.SimpleHandler):
    def __init__(self, bbox_bounds):
        super(PilotHandler, self).__init__()
        self.bbox_polygon = box(*bbox_bounds)
        self.roads = []
        self.buildings = []
        self.water = []
        self.green = []
        self.rail = []
        
        self.transformer = Transformer.from_crs(OSM_CRS, WORKING_CRS, always_xy=True)
        self.errors = {"invalid_geom": 0, "transform": 0, "clip": 0}
        self.skipped = 0
        self.total_road_length = 0.0
        self.tiles_500 = set()
        self.tiles_250 = set()

    def process_feature(self, w, geom, feature_list, is_road=False):
        try:
            # Real clipping
            if not geom.intersects(self.bbox_polygon):
                return
            clipped_geom = geom.intersection(self.bbox_polygon)
            if clipped_geom.is_empty:
                return

            # Simplify geometries slightly to save space
            clipped_geom = clipped_geom.simplify(0.0001, preserve_topology=True)

            if clipped_geom.geom_type == 'GeometryCollection':
                # Skip collections for MVP simplicity
                self.skipped += 1
                return

            # Handle MultiPolygons/MultiLineStrings by taking the largest part or first part
            parts = [clipped_geom]
            if clipped_geom.geom_type.startswith('Multi'):
                parts = list(clipped_geom.geoms)
                
            for part in parts:
                if part.is_empty:
                    continue
                # Transform to UTM 32N
                if part.geom_type in ['LineString', 'LinearRing']:
                    transformed_coords = [self.transformer.transform(x, y) for x, y in part.coords]
                    transformed_part = LineString(transformed_coords)
                elif part.geom_type == 'Polygon':
                    transformed_exterior = [self.transformer.transform(x, y) for x, y in part.exterior.coords]
                    transformed_part = Polygon(transformed_exterior)
                elif part.geom_type == 'Point':
                    x, y = self.transformer.transform(part.x, part.y)
                    transformed_part = Point(x, y)
                else:
                    self.errors["transform"] += 1
                    continue
                
                if is_road and transformed_part.geom_type == 'LineString':
                    self.total_road_length += transformed_part.length

                # Calculate tile
                centroid = transformed_part.centroid
                tile_500 = generate_tile_id(centroid.x, centroid.y, 500)
                tile_250 = generate_tile_id(centroid.x, centroid.y, 250)
                self.tiles_500.add(tile_500)
                self.tiles_250.add(tile_250)

                feature = {
                    "type": "Feature",
                    "geometry": mapping(transformed_part),
                    "properties": {k: v for k, v in w.tags}
                }
                feature["properties"]["osm_id"] = w.id
                feature["properties"]["tile_500"] = tile_500
                feature["properties"]["tile_250"] = tile_250
                
                feature_list.append(feature)

        except Exception as e:
            self.errors["clip"] += 1

    def way(self, w):
        if not (w.tags.get("highway") or w.tags.get("building") or w.tags.get("water") or w.tags.get("natural") or w.tags.get("landuse") or w.tags.get("railway")):
            return
            
        try:
            wkb = wkbfab.create_linestring(w)
            geom = wkblib.loads(wkb, hex=True)
            if w.tags.get("highway"):
                self.process_feature(w, geom, self.roads, is_road=True)
            elif w.tags.get("railway"):
                self.process_feature(w, geom, self.rail)
            elif w.tags.get("water") or w.tags.get("natural") == "water":
                # Convert to polygon if closed
                if w.is_closed():
                    wkb = wkbfab.create_multipolygon(w)
                    geom = wkblib.loads(wkb, hex=True)
                self.process_feature(w, geom, self.water)
            elif w.tags.get("landuse") in ["grass", "forest", "park", "meadow"]:
                if w.is_closed():
                    wkb = wkbfab.create_multipolygon(w)
                    geom = wkblib.loads(wkb, hex=True)
                self.process_feature(w, geom, self.green)
        except Exception:
            pass # fallback to polygon if it's a building
        
        if w.tags.get("building"):
            try:
                if w.is_closed():
                    wkb = wkbfab.create_linestring(w)
                    geom_line = wkblib.loads(wkb, hex=True)
                    geom_poly = Polygon(geom_line.coords)
                    self.process_feature(w, geom_poly, self.buildings)
                else:
                    self.skipped += 1
            except Exception as e:
                if self.errors["invalid_geom"] < 5:
                    print("Building error:", str(e))
                self.errors["invalid_geom"] += 1

def download_pbf():
    filepath = RAW_DIR / PBF_FILENAME
    if filepath.exists():
        print(f"Using cached PBF: {filepath}")
        return filepath
        
    print(f"Downloading {PBF_URL}...")
    response = requests.get(PBF_URL, stream=True) # removed verify=False
    response.raise_for_status()
    with open(filepath, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)
    print("Download complete.")
    return filepath

def run_pipeline():
    filepath = download_pbf()
    file_size = os.path.getsize(filepath)
    
    print("Extracting pilot area features...")
    handler = PilotHandler(PILOT_BBOX)
    handler.apply_file(str(filepath), locations=True)
    
    print(f"Extracted {len(handler.roads)} roads, {len(handler.buildings)} buildings.")
    print(f"Errors: {handler.errors}")
    
    def save_geojson(features, name):
        out_path = PROCESSED_DIR / f"pilot_{name}.geojson"
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump({
                "type": "FeatureCollection",
                "features": features
            }, f)
            
    save_geojson(handler.roads, "roads")
    save_geojson(handler.buildings, "buildings")
    save_geojson(handler.rail, "rail")
    save_geojson(handler.water, "water")
    save_geojson(handler.green, "green")
    
    transformer = Transformer.from_crs(OSM_CRS, WORKING_CRS, always_xy=True)
    minx, miny = transformer.transform(PILOT_BBOX[0], PILOT_BBOX[1])
    maxx, maxy = transformer.transform(PILOT_BBOX[2], PILOT_BBOX[3])
    proj_bbox = [minx, miny, maxx, maxy]
    
    manifest = {
        "source": "Geofabrik Schleswig-Holstein",
        "fetch_time": datetime.utcnow().isoformat() + "Z",
        "pbf_size_bytes": file_size,
        "pilot_bbox_wgs84": PILOT_BBOX,
        "pilot_bbox_epsg25832": proj_bbox,
        "roblox_origin": [minx, miny], # using bottom-left as origin
        "crs": WORKING_CRS,
        "counts": {
            "roads": len(handler.roads),
            "buildings": len(handler.buildings),
            "rail": len(handler.rail),
            "water": len(handler.water),
            "green": len(handler.green)
        },
        "stats": {
            "road_length_m": handler.total_road_length,
            "tiles_500_count": len(handler.tiles_500),
            "tiles_250_count": len(handler.tiles_250),
            "errors": handler.errors,
            "skipped": handler.skipped
        }
    }
    with open(MANIFESTS_DIR / "pilot_manifest.json", "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
        
    tile_manifest = {
        "tiles_500": list(handler.tiles_500),
        "tiles_250": list(handler.tiles_250)
    }
    with open(MANIFESTS_DIR / "tile_manifest.json", "w", encoding="utf-8") as f:
        json.dump(tile_manifest, f, indent=2)
        
    print("Pipeline complete.")

if __name__ == "__main__":
    run_pipeline()
