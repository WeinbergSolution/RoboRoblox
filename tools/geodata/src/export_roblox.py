import json
import os
from pathlib import Path
from config import PROCESSED_DIR, MANIFESTS_DIR

ROBLOX_SRC_DIR = Path("../../roblox/src/ReplicatedStorage/CityData")

def ensure_dir(path):
    if not os.path.exists(path):
        os.makedirs(path)

def clear_dir(path):
    if os.path.exists(path):
        for root, dirs, files in os.walk(path, topdown=False):
            for name in files:
                os.remove(os.path.join(root, name))

def export_manifest():
    with open(MANIFESTS_DIR / "pilot_manifest.json", "r", encoding="utf-8") as f:
        manifest = json.load(f)
        
    ensure_dir(ROBLOX_SRC_DIR)
    
    origin = manifest['OriginEPSG25832']
    
    lua_content = "return {\n"
    lua_content += f"    Source = \"{manifest['source']}\",\n"
    lua_content += f"    FetchTime = \"{manifest['fetch_time']}\",\n"
    lua_content += f"    OriginEPSG25832 = {{\n        Easting = {origin['Easting']:.2f},\n        Northing = {origin['Northing']:.2f}\n    }},\n"
    lua_content += f"    MetersToStuds = {manifest['MetersToStuds']},\n"
    
    lb_m = manifest['LocalBoundsMeters']
    lua_content += "    LocalBoundsMeters = {\n"
    lua_content += f"        MinX = {lb_m['MinX']:.2f}, MinZ = {lb_m['MinZ']:.2f},\n"
    lua_content += f"        MaxX = {lb_m['MaxX']:.2f}, MaxZ = {lb_m['MaxZ']:.2f}\n"
    lua_content += "    },\n"
    
    lb_s = manifest['LocalBoundsStuds']
    lua_content += "    LocalBoundsStuds = {\n"
    lua_content += f"        MinX = {lb_s['MinX']:.2f}, MinZ = {lb_s['MinZ']:.2f},\n"
    lua_content += f"        MaxX = {lb_s['MaxX']:.2f}, MaxZ = {lb_s['MaxZ']:.2f}\n"
    lua_content += "    },\n"
    
    ab = manifest['AbsoluteBoundsEPSG25832']
    lua_content += "    AbsoluteBoundsEPSG25832 = {\n"
    lua_content += f"        MinEasting = {ab['MinEasting']:.2f}, MinNorthing = {ab['MinNorthing']:.2f},\n"
    lua_content += f"        MaxEasting = {ab['MaxEasting']:.2f}, MaxNorthing = {ab['MaxNorthing']:.2f}\n"
    lua_content += "    },\n"
    
    lua_content += f"    Coverage = \"{manifest['Coverage']}\",\n"
    lua_content += f"    IsFullNorderstedt = {'true' if manifest['IsFullNorderstedt'] else 'false'},\n"
    
    c = manifest['counts']
    lua_content += "    Counts = {\n"
    lua_content += f"        Roads = {c['roads']},\n"
    lua_content += f"        Buildings = {c['buildings']},\n"
    lua_content += f"        Rail = {c['rail']},\n"
    lua_content += f"        Water = {c['water']},\n"
    lua_content += f"        Green = {c['green']}\n"
    lua_content += "    }\n"
    lua_content += "}\n"
    
    # Harte Validierung
    max_m = max(abs(lb_m['MinX']), abs(lb_m['MaxX']), abs(lb_m['MinZ']), abs(lb_m['MaxZ']))
    max_s = max(abs(lb_s['MinX']), abs(lb_s['MaxX']), abs(lb_s['MinZ']), abs(lb_s['MaxZ']))
    if max_m > 10000 or max_s > 50000:
        raise ValueError(f"Local bounds too large! meters={max_m}, studs={max_s}")
    
    with open(ROBLOX_SRC_DIR / "Manifest.lua", "w", encoding="utf-8") as f:
        f.write(lua_content)
        
    return [origin['Easting'], origin['Northing']]

def export_features(category, origin):
    geojson_path = PROCESSED_DIR / f"pilot_{category}.geojson"
    if not geojson_path.exists():
        return
        
    with open(geojson_path, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    out_dir = ROBLOX_SRC_DIR / category.capitalize()
    ensure_dir(out_dir)
    
    chunks = {}
    for feature in data.get("features", []):
        tile_id = feature["properties"]["tile_250"]
        if tile_id not in chunks:
            chunks[tile_id] = []
        chunks[tile_id].append(feature)
        
    for tile_id, features in chunks.items():
        features.sort(key=lambda x: str(x["properties"].get("osm_id", "")))
        
        lua_content = f"return {{\n"
        for idx, feature in enumerate(features):
            osm_id = feature["properties"].get("osm_id", idx)
            geom_type = feature["geometry"]["type"]
            coords = feature["geometry"]["coordinates"]
            
            props = feature["properties"]
            clean_props = {}
            obb_data = None
            
            for k, v in props.items():
                if k.startswith("OBB_"):
                    # We collect OBB parameters explicitly and don't dump them to flat Properties
                    if obb_data is None: obb_data = {}
                    obb_data[k] = v
                    continue
                    
                if isinstance(v, str):
                    clean_props[k] = v.replace('"', '\\"').replace('\n', ' ')
                else:
                    clean_props[k] = v
            
            # Additional validation for OBB
            if obb_data is not None and "OBB_CenterX" in obb_data:
                local_x = obb_data["OBB_CenterX"] - origin[0]
                local_z = obb_data["OBB_CenterZ"] - origin[1]
                w = obb_data["OBB_Width"]
                d = obb_data["OBB_Depth"]
                rot = obb_data["OBB_Rotation"]
                
                if abs(local_x) > 10000 or abs(local_z) > 10000:
                    print(f"Warning: building {osm_id} has center out of local bounds")
                    continue
            
            lua_content += f"    [{idx+1}] = {{\n"
            lua_content += f"        Id = \"{osm_id}\",\n"
            lua_content += f"        Type = \"{geom_type}\",\n"
            
            lua_content += "        Properties = {\n"
            for k, v in clean_props.items():
                if isinstance(v, str):
                    lua_content += f"            [\"{k}\"] = \"{v}\",\n"
                elif isinstance(v, (int, float)):
                    lua_content += f"            [\"{k}\"] = {v},\n"
            lua_content += "        },\n"
            
            if obb_data is not None and "OBB_CenterX" in obb_data:
                lua_content += "        OBB = {\n"
                lua_content += f"            CenterLocalMeters = {{{local_x:.2f}, {local_z:.2f}}},\n"
                lua_content += f"            SizeMeters = {{{w:.2f}, {d:.2f}}},\n"
                lua_content += f"            RotationDegrees = {rot:.2f}\n"
                lua_content += "        },\n"
            
            lua_content += "        Geometry = {\n"
            
            def export_coord(c):
                x_local = c[0] - origin[0]
                y_local = c[1] - origin[1]
                if abs(x_local) > 10000 or abs(y_local) > 10000:
                    raise ValueError(f"Geometry coordinate out of bounds! {x_local}, {y_local}")
                return f"{{{x_local:.2f}, {y_local:.2f}}}"
                
            if geom_type == "LineString":
                points_str = ", ".join([export_coord(c) for c in coords])
                lua_content += f"            {points_str}\n"
            elif geom_type == "Polygon":
                points_str = ", ".join([export_coord(c) for c in coords[0]])
                lua_content += f"            {points_str}\n"
            elif geom_type == "Point":
                lua_content += f"            {export_coord(coords)}\n"
                
            lua_content += "        }\n"
            lua_content += f"    }},\n"
            
        lua_content += "}\n"
        
        with open(out_dir / f"{tile_id}.lua", "w", encoding="utf-8") as f:
            f.write(lua_content)

import shutil

def sync_frontend():
    frontend_dir = Path("../../apps/control-center/public/generated")
    ensure_dir(frontend_dir)
    shutil.copy(MANIFESTS_DIR / "pilot_manifest.json", frontend_dir / "pilot_manifest.json")
    shutil.copy(MANIFESTS_DIR / "tile_manifest.json", frontend_dir / "tile_manifest.json")
    for category in ["roads", "buildings", "rail", "water", "green"]:
        geojson_path = PROCESSED_DIR / f"pilot_{category}.geojson"
        if geojson_path.exists():
            shutil.copy(geojson_path, frontend_dir / f"pilot_{category}.geojson")

def main():
    clear_dir(ROBLOX_SRC_DIR)
    print("Exporting Manifest...")
    origin = export_manifest()
    
    print("Exporting Categories...")
    for category in ["roads", "buildings", "rail", "water", "green"]:
        export_features(category, origin)
        
    print("Syncing Frontend data...")
    sync_frontend()
        
    print("Luau export complete.")

if __name__ == "__main__":
    main()
