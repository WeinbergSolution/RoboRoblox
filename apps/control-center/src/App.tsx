import { useEffect, useRef, useState } from 'react'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import './App.css'

function App() {
  const mapContainer = useRef<HTMLDivElement>(null)
  const mapRef = useRef<maplibregl.Map | null>(null)
  const [manifest, setManifest] = useState<any>(null)
  const [filters, setFilters] = useState({
    roads: true,
    buildings: true,
    rail: true,
    water: true,
    green: true
  })
  const [selectedTile, setSelectedTile] = useState<string | null>(null)

  useEffect(() => {
    fetch('/generated/pilot_manifest.json')
      .then(r => r.json())
      .then(data => setManifest(data))
      .catch(e => console.error("Manifest load failed", e))
  }, [])

  useEffect(() => {
    if (!mapContainer.current || !manifest) return

    const center = [
      (manifest.pilot_bbox_wgs84[0] + manifest.pilot_bbox_wgs84[2]) / 2,
      (manifest.pilot_bbox_wgs84[1] + manifest.pilot_bbox_wgs84[3]) / 2
    ] as [number, number]

    const initialMap = new maplibregl.Map({
      container: mapContainer.current,
      style: {
        version: 8,
        sources: {},
        layers: []
      },
      center: center,
      zoom: 14
    })
    
    mapRef.current = initialMap

    initialMap.on('load', () => {
      // BBox
      initialMap.addSource('pilot-bbox', {
        type: 'geojson',
        data: {
          type: 'Feature',
          geometry: {
            type: 'Polygon',
            coordinates: [[
              [manifest.pilot_bbox_wgs84[0], manifest.pilot_bbox_wgs84[1]],
              [manifest.pilot_bbox_wgs84[2], manifest.pilot_bbox_wgs84[1]],
              [manifest.pilot_bbox_wgs84[2], manifest.pilot_bbox_wgs84[3]],
              [manifest.pilot_bbox_wgs84[0], manifest.pilot_bbox_wgs84[3]],
              [manifest.pilot_bbox_wgs84[0], manifest.pilot_bbox_wgs84[1]]
            ]]
          },
          properties: {}
        }
      })
      initialMap.addLayer({
        id: 'pilot-bbox-line',
        type: 'line',
        source: 'pilot-bbox',
        paint: { 'line-color': '#ff0000', 'line-width': 2 }
      })

      // Load Layers
      const layers = [
        { id: 'water', color: '#0077ff', type: 'fill' },
        { id: 'green', color: '#00ff00', type: 'fill' },
        { id: 'buildings', color: '#cccccc', type: 'fill' },
        { id: 'rail', color: '#555555', type: 'line' },
        { id: 'roads', color: '#ffffff', type: 'line' }
      ]

      layers.forEach(l => {
        initialMap.addSource(l.id, {
          type: 'geojson',
          data: `/generated/pilot_${l.id}.geojson`
        })
        
        if (l.type === 'fill') {
          initialMap.addLayer({
            id: l.id + '-layer',
            type: 'fill',
            source: l.id,
            paint: { 'fill-color': l.color, 'fill-opacity': 0.6 }
          })
        } else {
          initialMap.addLayer({
            id: l.id + '-layer',
            type: 'line',
            source: l.id,
            paint: { 'line-color': l.color, 'line-width': 2 }
          })
        }
      })

      // Click for tile selection
      initialMap.on('click', 'buildings-layer', (e) => {
        if (e.features && e.features[0]) {
          setSelectedTile(e.features[0].properties.tile_500)
        }
      })
    })

    return () => {
      initialMap.remove()
    }
  }, [manifest])

  // Update Filters
  useEffect(() => {
    if (!mapRef.current) return
    const map = mapRef.current
    Object.entries(filters).forEach(([key, visible]) => {
      if (map.getLayer(key + '-layer')) {
        map.setLayoutProperty(key + '-layer', 'visibility', visible ? 'visible' : 'none')
      }
    })
  }, [filters])

  const toggleFilter = (key: keyof typeof filters) => {
    setFilters(f => ({ ...f, [key]: !f[key] }))
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100vh', fontFamily: 'sans-serif' }}>
      <header style={{ padding: '1rem', backgroundColor: '#222', color: '#fff' }}>
        <h1>Norderstedt City Importer MVP - Control Center</h1>
      </header>
      <div style={{ display: 'flex', flex: 1, overflow: 'hidden' }}>
        <aside style={{ width: '350px', padding: '1rem', backgroundColor: '#f4f4f4', overflowY: 'auto' }}>
          <h2>Status</h2>
          {manifest ? (
            <ul>
              <li><span style={{color: 'green'}}>✔</span> Pilot Data Loaded</li>
              <li>Source: {manifest.source}</li>
              <li>Features:</li>
              <ul>
                <li>Roads: {manifest.counts.roads}</li>
                <li>Buildings: {manifest.counts.buildings}</li>
                <li>Rail: {manifest.counts.rail}</li>
                <li>Water: {manifest.counts.water}</li>
                <li>Green: {manifest.counts.green}</li>
              </ul>
              <li>Roblox Origin: [{manifest.roblox_origin[0].toFixed(2)}, {manifest.roblox_origin[1].toFixed(2)}]</li>
            </ul>
          ) : (
            <p>Loading manifest...</p>
          )}

          <h3>Filters</h3>
          {Object.keys(filters).map(k => (
            <div key={k}>
              <label>
                <input 
                  type="checkbox" 
                  checked={filters[k as keyof typeof filters]} 
                  onChange={() => toggleFilter(k as keyof typeof filters)} 
                /> {k}
              </label>
            </div>
          ))}

          {selectedTile && (
            <div style={{marginTop: '1rem', padding: '1rem', background: '#e0e0e0', borderRadius: 4}}>
              <h4>Tile Detail</h4>
              <p>ID: {selectedTile}</p>
            </div>
          )}
        </aside>
        <main ref={mapContainer} style={{ flex: 1, backgroundColor: '#111' }} />
      </div>
    </div>
  )
}

export default App
