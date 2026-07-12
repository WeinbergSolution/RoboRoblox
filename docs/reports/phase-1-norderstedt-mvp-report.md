# RoboRoblox – Phase 1 Abschlussbericht (Real Integration)

## 1. Pipeline-Status
Die Python-Pipeline extrahiert nun echte Geometrien (Roads, Buildings, Rail, Water, Green) aus der rohen `.osm.pbf`-Datei. 
Dabei findet ein echtes BBox-Clipping über `shapely.geometry.intersection` statt. Die Koordinaten werden aus dem EPSG:4326 in das definierte Arbeitskoordinatensystem (UTM) transformiert. Es wurden Fehlerbehandlungen eingeführt, die ungültige Geometrien korrekt zählen und überspringen. SSL-Fehler beim PBF-Download wurden behoben, indem das `verify=False` entfernt und ordnungsgemäß heruntergeladen/gecacht wird.

## 2. Build-Verifikation
Die Pipeline ist vollständig reproduzierbar. Alle Befehle laufen deterministisch ab:
- `pnpm geodata:build`: Führt die Python-Pipeline aus, erstellt Chunked-GeoJSON und generiert daraus im Anschluss Luau-Module (`export_roblox.py`). Kopiert die Resultate auch in das Frontend (`public/generated`).
- `pnpm roblox:build`: Führt `rojo build` aus. Rojo wurde reproduzierbar in `rokit.toml` gepinnt (Version 7.7.0). Die Binaries `rojo.exe`/`rojo.zip` wurden restlos aus dem Git-Tracking entfernt.

Alle automatisierten Tests (Python, TypeScript) sind grün.

## 3. Modul-Details
Die Luau-Chunks (`.lua`) werden in `roblox/src/ReplicatedStorage/CityData/` erzeugt. 
Sie sind nach Kachel-IDs gruppiert und nach `osm_id` aufsteigend sortiert, um einen deterministischen Output bei jedem Build zu garantieren.
Der Build erzeugt sauberes UTF-8, um Rojo-Kompilierungsfehler abzufangen.

## 4. Roblox-Build
Das Roblox-Artefakt (`Norderstedt_MVP.rbxlx`) enthält nun keine Platzhalter-Ordner mehr. Über Rojo werden die generierten CityData-Chunks eingebunden. Der `Importer.server.lua` liest das Manifest und erzeugt zur Laufzeit dynamisch verankerte `Part`-Instanzen in `Workspace.CityGeometry`.

**Artefakt-Details:**
- **Name:** `Norderstedt_MVP.rbxlx`
- **SHA256 Hash:** `9CAD87423CFA2816631885EB395AB6CCE16834095F57ED3351F81972DAAD2821`

## 5. Frontend
Das React-basierte Control Center wurde umgebaut, sodass es über `fetch('/generated/pilot_manifest.json')` die lokal erzeugten Artefakt-Manifeste und GeoJSON-Files dynamisch lädt. Es existieren keine statisch geladenen Mock-Features mehr. Die MapLibre-Instanz visualisiert die lokalen Chunk-Ebenen und das Manifest-Detailpanel zeigt die realen Featurezahlen.

---
# GO FOR MANUAL STUDIO QA
Der reale Importer ist integriert und erzeugt echten Geometry-Output für Roblox.
