import os
from pathlib import Path

# Paths
ROOT_DIR = Path(__file__).resolve().parent.parent.parent.parent
DATA_DIR = ROOT_DIR / "data"

RAW_DIR = DATA_DIR / "raw"
CACHE_DIR = DATA_DIR / "cache"
PROCESSED_DIR = DATA_DIR / "processed"
MANIFESTS_DIR = DATA_DIR / "manifests"

# Ensure directories exist
for d in [RAW_DIR, CACHE_DIR, PROCESSED_DIR, MANIFESTS_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# Coordinate Systems
OSM_CRS = "EPSG:4326"       # WGS84
WORKING_CRS = "EPSG:25832"  # ETRS89 / UTM Zone 32N

# Tiling
GRID_SIZE = 500  # meters
SUBGRID_SIZE = 250  # meters

# PBF URL for Schleswig-Holstein
PBF_URL = "https://download.geofabrik.de/europe/germany/schleswig-holstein-latest.osm.pbf"
PBF_FILENAME = "schleswig-holstein-latest.osm.pbf"

# Norderstedt Boundary (approximate BBox in EPSG:4326 for initial filtering if polygon fails)
# Actually, it's better to fetch the exact relation or just use a known BBox for the MVP:
# 9.940, 53.645, 10.050, 53.750 (approximate Norderstedt area)
NORDERSTEDT_BBOX = (9.940, 53.640, 10.070, 53.760)

# Pilot area (Norderstedt-Mitte) in EPSG:4326 for the 1x1km pilot
PILOT_BBOX = (9.988, 53.700, 10.015, 53.715)
