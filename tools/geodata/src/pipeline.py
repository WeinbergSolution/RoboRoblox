import os
import json
import math
from pathlib import Path
from datetime import datetime

import osmium
import shapely.wkb as wkblib
from shapely.geometry import Point, LineString, Polygon, mapping, box
import geopandas as gpd
from pyproj import Transformer
import requests

from config import RAW_DIR, PROCESSED_DIR, PBF_URL, PBF_FILENAME, PILOT_BBOX, MANIFESTS_DIR, WORKING_CRS, OSM_CRS

METERS_TO_STUDS = 3.571428
wkbfab = osmium.geom.WKBFactory()

def generate_tile_id(e, n, size=500):
    grid_e = int(e // size * size)
    grid_n = int(n // size * size)
    return f"NO_E{grid_e}_N{grid_n}_{size}"

def get_obb_params(polygon):
    mrr = polygon.minimum_rotated_rectangle
    if mrr.geom_type == 'LineString' or mrr.geom_type == 'Point':
        return polygon.centroid.x, polygon.centroid.y, 0, 0, 0
    coords = list(mrr.exterior.coords)
    p0, p1, p2 = coords[0], coords[1], coords[2]
    dist1 = math.hypot(p1[0]-p0[0], p1[1]-p0[1])
    dist2 = math.hypot(p2[0]-p1[0], p2[1]-p1[1])
    
    # We want width to be the shorter side
    if dist1 < dist2:
        width, depth = dist1, dist2
        angle_rad = math.atan2(p2[1]-p1[1], p2[0]-p1[0])
    else:
        width, depth = dist2, dist1
        angle_rad = math.atan2(p1[1]-p0[1], p1[0]-p0[0])
        
    angle_deg = math.degrees(angle_rad)
    center = mrr.centroid
    return center.x, center.y, width, depth, angle_deg

def parse_height(w):
    h = w.tags.get("height")
    if h:
        h = h.replace('m', '').replace(',', '.').strip()
        try:
            return float(h)
        except ValueError:
            pass
    levels = w.tags.get("building:levels")
    if levels:
        try:
            return float(levels) * 3.0
        except ValueError:
            pass
    
    # Defaults
    btype = w.tags.get("building", "default")
    defaults = {
        "garage": 3.0, "garages": 3.0,
        "shed": 2.8,
        "house": 8.0, "detached": 8.0,
        "residential": 10.0,
        "apartments": 12.0,
        "commercial": 9.0,
        "retail": 7.0,
        "industrial": 8.0,
        "school": 10.0,
        "hospital": 14.0,
        "church": 15.0
    }
    val = defaults.get(btype, 8.0)
    return max(2.5, min(60.0, val))

def parse_road_width(w):
    hw_type = w.tags.get("highway", "default")
    
    # 1. Determine LaneCount and DirectionMode
    lane_count = 2
    dir_mode = "two-way"
    
    if w.tags.get("oneway") == "yes":
        lane_count = 1
        dir_mode = "one-way"
        
    lanes_tag = w.tags.get("lanes")
    lanes_fwd = w.tags.get("lanes:forward")
    lanes_bwd = w.tags.get("lanes:backward")
    
    if lanes_tag:
        try:
            lane_count = int(lanes_tag.split(';')[0])
        except ValueError:
            pass
    elif lanes_fwd and lanes_bwd:
        try:
            lane_count = int(lanes_fwd) + int(lanes_bwd)
        except ValueError:
            pass
            
    if lane_count < 1:
        lane_count = 1
        
    # 2. Gameplay Minimums
    gameplay_min = 28.0 # default 2 lanes
    if hw_type == "footway":
        gameplay_min = 7.0
    elif hw_type == "path":
        gameplay_min = 6.0
    elif hw_type == "cycleway":
        gameplay_min = 9.0
    else:
        if lane_count == 1:
            gameplay_min = 14.0
        elif lane_count == 2:
            gameplay_min = 28.0
        elif lane_count >= 4:
            gameplay_min = 52.0
        else:
            # 3 lanes -> ~ 40 studs
            gameplay_min = 14.0 * lane_count
            
    # 3. Read OSM Width if available
    osm_width = 0.0
    width_tag = w.tags.get("width")
    if width_tag:
        w_str = width_tag.replace('m', '').replace(',', '.').strip()
        try:
            osm_width = float(w_str)
        except ValueError:
            pass
            
    # If no OSM width, use some geographic default
    if osm_width <= 0:
        defaults = {
            "motorway": 24.0, "motorway_link": 14.0,
            "trunk": 20.0, "trunk_link": 12.0,
            "primary": 18.0, "primary_link": 10.0,
            "secondary": 14.0, "secondary_link": 10.0,
            "tertiary": 12.0, "tertiary_link": 10.0,
            "residential": 6.0,
            "unclassified": 6.0,
            "living_street": 5.0,
            "service": 4.0,
            "track": 3.0,
            "cycleway": 2.5,
            "footway": 2.0,
            "path": 1.5,
            "pedestrian": 5.0,
            "steps": 2.0
        }
        osm_width = defaults.get(hw_type, 4.0)
        
    scaled_width = osm_width * METERS_TO_STUDS
    final_width = max(scaled_width, gameplay_min)
    
    return {
        "LaneCount": lane_count,
        "DirectionMode": dir_mode,
        "OSMWidthMeters": osm_width,
        "ScaledOSMWidthStuds": scaled_width,
        "GameplayMinimumStuds": gameplay_min,
        "FinalWidthStuds": final_width,
        "highway": hw_type,
        "crossing": w.tags.get("crossing", ""),
        "stop": w.tags.get("stop", ""),
        "traffic_signals": w.tags.get("traffic_signals", ""),
        "sidewalk": w.tags.get("sidewalk", "")
    }

class PilotHandler(osmium.SimpleHandler):
    def __init__(self, bbox_bounds):
        super(PilotHandler, self).__init__()
        self.bbox_polygon = box(*bbox_bounds)
        self.roads = []
        self.buildings = []
        self.water = []
        self.green = []
        self.rail = []
        self.pois = []
        
        self.transformer = Transformer.from_crs(OSM_CRS, WORKING_CRS, always_xy=True)
        self.errors = {"invalid_geom": 0, "transform": 0, "clip": 0}
        self.skipped = 0
        self.total_road_length = 0.0
        self.tiles_500 = set()
        self.tiles_250 = set()

    def process_feature(self, w, geom, feature_list, category):
        try:
            if not geom.intersects(self.bbox_polygon):
                return
            clipped_geom = geom.intersection(self.bbox_polygon)
            if clipped_geom.is_empty:
                return

            if clipped_geom.geom_type == 'GeometryCollection':
                self.skipped += 1
                return

            parts = [clipped_geom]
            if clipped_geom.geom_type.startswith('Multi'):
                parts = list(clipped_geom.geoms)
                
            for part in parts:
                if part.is_empty:
                    continue
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
                
                if category == "roads" and transformed_part.geom_type == 'LineString':
                    self.total_road_length += transformed_part.length

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
                
                if category == "buildings" and transformed_part.geom_type == 'Polygon':
                    cx, cz, ow, od, rot = get_obb_params(transformed_part)
                    feature["properties"]["OBB_CenterX"] = cx
                    feature["properties"]["OBB_CenterZ"] = cz
                    feature["properties"]["OBB_Width"] = ow
                    feature["properties"]["OBB_Depth"] = od
                    feature["properties"]["OBB_Rotation"] = rot
                    feature["properties"]["HeightMeters"] = parse_height(w)
                elif category == "roads":
                    road_data = parse_road_width(w)
                    for k, v in road_data.items():
                        feature["properties"][k] = v
                elif category == "pois":
                    # For POIs we want to keep name and amenity/shop/public_transport
                    feature["properties"]["name"] = w.tags.get("name", "")
                    feature["properties"]["amenity"] = w.tags.get("amenity", "")
                    feature["properties"]["shop"] = w.tags.get("shop", "")
                    feature["properties"]["public_transport"] = w.tags.get("public_transport", "")
                    feature["properties"]["railway"] = w.tags.get("railway", "")
                
                feature_list.append(feature)

        except Exception as e:
            self.errors["clip"] += 1

    def process_poi(self, osmium_obj, geom):
        amenity = osmium_obj.tags.get("amenity")
        shop = osmium_obj.tags.get("shop")
        pt = osmium_obj.tags.get("public_transport")
        railway = osmium_obj.tags.get("railway")
        building = osmium_obj.tags.get("building")
        
        is_poi = False
        if amenity in ["fuel", "bank", "fast_food", "restaurant", "hospital", "clinic", "fire_station", "police", "school", "kindergarten", "townhall", "pharmacy"]:
            is_poi = True
        elif shop in ["supermarket", "bakery", "mall"]:
            is_poi = True
        elif pt in ["station", "stop_position"]:
            is_poi = True
        elif railway in ["station", "halt"]:
            is_poi = True
        elif building in ["train_station"]:
            is_poi = True
            
        if is_poi:
            self.process_feature(osmium_obj, geom, self.pois, "pois")

    def node(self, n):
        if not (n.tags.get("amenity") or n.tags.get("shop") or n.tags.get("public_transport") or n.tags.get("railway")):
            return
        geom = Point(n.location.lon, n.location.lat)
        self.process_poi(n, geom)

    def way(self, w):
        if not (w.tags.get("highway") or w.tags.get("building") or w.tags.get("water") or w.tags.get("natural") or w.tags.get("landuse") or w.tags.get("railway") or w.tags.get("amenity") or w.tags.get("shop")):
            return
            
        try:
            wkb = wkbfab.create_linestring(w)
            geom = wkblib.loads(wkb, hex=True)
            if w.tags.get("highway"):
                self.process_feature(w, geom, self.roads, "roads")
            elif w.tags.get("railway") and not w.tags.get("railway") in ["station", "halt"]:
                self.process_feature(w, geom, self.rail, "rail")
            elif w.tags.get("water") or w.tags.get("natural") == "water":
                if w.is_closed():
                    wkb = wkbfab.create_multipolygon(w)
                    geom = wkblib.loads(wkb, hex=True)
                self.process_feature(w, geom, self.water, "water")
            elif w.tags.get("landuse") in ["grass", "forest", "park", "meadow", "recreation_ground", "cemetery", "village_green"] or w.tags.get("natural") in ["wood", "scrub"]:
                if w.is_closed():
                    wkb = wkbfab.create_multipolygon(w)
                    geom = wkblib.loads(wkb, hex=True)
                self.process_feature(w, geom, self.green, "green")
        except Exception:
            pass 
        
        self.process_poi(w, geom) if 'geom' in locals() else None 
        
        if w.tags.get("building"):
            try:
                if w.is_closed():
                    wkb = wkbfab.create_linestring(w)
                    geom_line = wkblib.loads(wkb, hex=True)
                    geom_poly = Polygon(geom_line.coords)
                    self.process_feature(w, geom_poly, self.buildings, "buildings")
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
    response = requests.get(PBF_URL, stream=True)
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
    save_geojson(handler.pois, "pois")
    
    transformer = Transformer.from_crs(OSM_CRS, WORKING_CRS, always_xy=True)
    minx, miny = transformer.transform(PILOT_BBOX[0], PILOT_BBOX[1])
    maxx, maxy = transformer.transform(PILOT_BBOX[2], PILOT_BBOX[3])
    proj_bbox = [minx, miny, maxx, maxy]
    
    origin_x = (minx + maxx) / 2
    origin_y = (miny + maxy) / 2
    
    local_min_x = minx - origin_x
    local_max_x = maxx - origin_x
    local_min_z = miny - origin_y
    local_max_z = maxy - origin_y
    
    manifest = {
        "source": "Geofabrik Schleswig-Holstein",
        "fetch_time": datetime.utcnow().isoformat() + "Z",
        "pbf_size_bytes": file_size,
        "pilot_bbox_wgs84": PILOT_BBOX,
        "crs": WORKING_CRS,
        "OriginEPSG25832": {
            "Easting": origin_x,
            "Northing": origin_y
        },
        "MetersToStuds": METERS_TO_STUDS,
        "LocalBoundsMeters": {
            "MinX": local_min_x,
            "MinZ": local_min_z,
            "MaxX": local_max_x,
            "MaxZ": local_max_z
        },
        "LocalBoundsStuds": {
            "MinX": local_min_x * METERS_TO_STUDS,
            "MinZ": local_min_z * METERS_TO_STUDS,
            "MaxX": local_max_x * METERS_TO_STUDS,
            "MaxZ": local_max_z * METERS_TO_STUDS
        },
        "AbsoluteBoundsEPSG25832": {
            "MinEasting": minx,
            "MinNorthing": miny,
            "MaxEasting": maxx,
            "MaxNorthing": maxy
        },
        "Coverage": "Norderstedt-Mitte Pilot",
        "IsFullNorderstedt": False,
        "counts": {
            "roads": len(handler.roads),
            "buildings": len(handler.buildings),
            "rail": len(handler.rail),
            "water": len(handler.water),
            "green": len(handler.green),
            "pois": len(handler.pois)
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
