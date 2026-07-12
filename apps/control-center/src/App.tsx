import { useEffect, useRef, useState } from 'react'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import './App.css'

function App() {
  const mapContainer = useRef<HTMLDivElement>(null)
  const [map, setMap] = useState<maplibregl.Map | null>(null)

  useEffect(() => {
    if (!mapContainer.current) return

    const initialMap = new maplibregl.Map({
      container: mapContainer.current,
      style: {
        version: 8,
        sources: {
          osm: {
            type: 'raster',
            tiles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],
            tileSize: 256,
            attribution: '&copy; OpenStreetMap Contributors'
          }
        },
        layers: [
          {
            id: 'osm',
            type: 'raster',
            source: 'osm',
            minzoom: 0,
            maxzoom: 19
          }
        ]
      },
      center: [9.995, 53.705], // Norderstedt-Mitte
      zoom: 14
    })

    initialMap.on('load', () => {
      // Draw pilot area bbox
      initialMap.addSource('pilot-bbox', {
        type: 'geojson',
        data: {
          type: 'Feature',
          geometry: {
            type: 'Polygon',
            coordinates: [
              [
                [9.988, 53.700],
                [10.015, 53.700],
                [10.015, 53.715],
                [9.988, 53.715],
                [9.988, 53.700]
              ]
            ]
          },
          properties: {}
        }
      })
      
      initialMap.addLayer({
        id: 'pilot-bbox-fill',
        type: 'fill',
        source: 'pilot-bbox',
        paint: {
          'fill-color': '#088',
          'fill-opacity': 0.2
        }
      })
      
      initialMap.addLayer({
        id: 'pilot-bbox-line',
        type: 'line',
        source: 'pilot-bbox',
        paint: {
          'line-color': '#088',
          'line-width': 2
        }
      })
    })

    setMap(initialMap)

    return () => {
      initialMap.remove()
    }
  }, [])

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh', fontFamily: 'sans-serif' }}>
      <header style={{ padding: '1rem', backgroundColor: '#222', color: '#fff' }}>
        <h1>Norderstedt City Importer MVP - Control Center</h1>
      </header>
      <div style={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
        <aside style={{ width: '300px', padding: '1rem', backgroundColor: '#f4f4f4', overflowY: 'auto' }}>
          <h2>Progress</h2>
          <ul>
            <li>Pilot Data Extracted: <span style={{color: 'green'}}>Pending</span></li>
            <li>Roblox Place Generated: <span style={{color: 'green'}}>Pending</span></li>
          </ul>
          <h3>Filters</h3>
          <p>
            <label><input type="checkbox" defaultChecked /> Show Pilot Area</label>
          </p>
        </aside>
        <main ref={mapContainer} style={{ flex: 1 }} />
      </div>
    </div>
  )
}

export default App
