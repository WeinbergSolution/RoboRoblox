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
    
    lua_content = "return {\n"
    lua_content += f"    Source = \"{manifest['source']}\",\n"
    lua_content += f"    FetchTime = \"{manifest['fetch_time']}\",\n"
    lua_content += f"    Origin = {{{manifest['roblox_origin'][0]:.2f}, {manifest['roblox_origin'][1]:.2f}}},\n"
    lua_content += "}\n"
    
    with open(ROBLOX_SRC_DIR / "Manifest.lua", "w", encoding="utf-8") as f:
        f.write(lua_content)
        
    return manifest['roblox_origin']

def export_features(category, origin):
    geojson_path = PROCESSED_DIR / f"pilot_{category}.geojson"
    if not geojson_path.exists():
        return
        
    with open(geojson_path, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    out_dir = ROBLOX_SRC_DIR / category.capitalize()
    ensure_dir(out_dir)
    
    # Group by chunk 250
    chunks = {}
    for feature in data.get("features", []):
        tile_id = feature["properties"]["tile_250"]
        if tile_id not in chunks:
            chunks[tile_id] = []
        chunks[tile_id].append(feature)
        
    for tile_id, features in chunks.items():
        # Sort features by osm_id to ensure determinism
        features.sort(key=lambda x: str(x["properties"].get("osm_id", "")))
        
        lua_content = f"return {{\n"
        for idx, feature in enumerate(features):
            osm_id = feature["properties"].get("osm_id", idx)
            geom_type = feature["geometry"]["type"]
            coords = feature["geometry"]["coordinates"]
            
            props = feature["properties"]
            # Clean string values to avoid Lua syntax errors
            clean_props = {}
            for k, v in props.items():
                if isinstance(v, str):
                    clean_props[k] = v.replace('"', '\\"').replace('\n', ' ')
                else:
                    clean_props[k] = v
            
            lua_content += f"    [{idx+1}] = {{\n"
            lua_content += f"        Id = \"{osm_id}\",\n"
            lua_content += f"        Type = \"{geom_type}\",\n"
            
            # Export properties
            lua_content += "        Properties = {\n"
            for k, v in clean_props.items():
                if isinstance(v, str):
                    lua_content += f"            [\"{k}\"] = \"{v}\",\n"
                elif isinstance(v, (int, float)):
                    lua_content += f"            [\"{k}\"] = {v},\n"
            lua_content += "        },\n"
            
            # Export Geometry
            lua_content += "        Geometry = {\n"
            
            def export_coord(c):
                # Subtract origin to get local space
                x_local = c[0] - origin[0]
                y_local = c[1] - origin[1]
                return f"{{{x_local:.2f}, {y_local:.2f}}}"
                
            if geom_type == "LineString":
                points_str = ", ".join([export_coord(c) for c in coords])
                lua_content += f"            {points_str}\n"
            elif geom_type == "Polygon":
                # Only use outer ring for MVP
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
    
    # Copy manifests
    shutil.copy(MANIFESTS_DIR / "pilot_manifest.json", frontend_dir / "pilot_manifest.json")
    shutil.copy(MANIFESTS_DIR / "tile_manifest.json", frontend_dir / "tile_manifest.json")
    
    # Copy GeoJSONs
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
