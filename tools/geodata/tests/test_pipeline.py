import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../src')))

import pytest
from pyproj import Transformer
from config import OSM_CRS, WORKING_CRS, PILOT_BBOX

def test_coordinate_transform():
    # Test EPSG:4326 to EPSG:25832
    transformer = Transformer.from_crs(OSM_CRS, WORKING_CRS, always_xy=True)
    # Approx Norderstedt center: 9.995, 53.705
    x, y = transformer.transform(9.995, 53.705)
    
    # Check if roughly in UTM 32N valid range
    assert 500000 < x < 600000
    assert 5900000 < y < 6000000

def test_pilot_bbox():
    min_lon, min_lat, max_lon, max_lat = PILOT_BBOX
    assert min_lon < max_lon
    assert min_lat < max_lat
    # Check that it's within sensible limits
    assert 9.0 < min_lon < 11.0
    assert 53.0 < min_lat < 55.0

def test_tile_id_stability():
    # Generate tile ID based on coordinates
    def generate_tile_id(e, n, size):
        # Round down to nearest size
        grid_e = int(e // size * size)
        grid_n = int(n // size * size)
        return f"NO_E{grid_e}_N{grid_n}_{size}"

    # For 500m grid
    assert generate_tile_id(565123, 5949123, 500) == "NO_E565000_N5949000_500"
    assert generate_tile_id(565499, 5949499, 500) == "NO_E565000_N5949000_500"

