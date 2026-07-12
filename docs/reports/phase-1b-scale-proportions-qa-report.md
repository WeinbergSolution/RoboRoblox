# RoboRoblox – Phase 1B Scale, Proportions & Playtest UX Correction Report

## 1. Maßstabsänderung
Die Skalierung wurde von dem fehlerhaften Ansatz "1 Meter = 1 Stud" auf den verbindlichen Wert umgestellt:
- `MetersToStuds = 3.571428`
- Alle Geometrien (X, Z und Y/Höhe) werden im Roblox-Importer exakt einmal mit diesem Maßstab multipliziert.
- Das Manifest und der Studio-Flugmodus-Screen geben den Wert korrekt mit "1 m = 3.571 studs" aus.

## 2. Pilotgröße und Koordinatensystem
Der Roblox-Ursprung wurde vom Rand des Pilotbereichs (Süd-West-Ecke) exakt auf das Zentrum der Pilot-BBox verschoben. 
Dadurch liegt die Stadt im Roblox Workspace symmetrisch um den Nullpunkt.

## 3. Straßenbreiten
Alte fest codierte Stud-Breiten (z. B. 2/3/5 Studs) wurden entfernt. 
Stattdessen parst das Python-Backend den OSM-Tag `width` (in Metern) und rechnet hilfsweise über `lanes * 3.2m`. Fehlen diese Daten, kommen Default-Breiten zum Einsatz, z. B.:
- `residential`: 6.0 m (ca. 21.43 Studs)
- `footway`: 2.0 m (ca. 7.14 Studs)

## 4. Gebäude-OBB-Statistik
Die achsenparallele Bounding Box (AABB) wurde durch Shapelys `minimum_rotated_rectangle` (OBB) ersetzt. Die OBB ermittelt Breite, Tiefe und Rotationswinkel passgenau.
Gebäude nutzen zudem reale Höhen aus dem `height`-Tag, der `building:levels`-Angabe (* 3.0m) oder fallbacks auf Basis des Nutzungstyps (z. B. `house` = 8.0m, `apartments` = 12.0m). Alle Gebäude stehen nun bündig auf dem Boden (Y=0).

## 5. Ground und Spawn
- **PilotGround:** Eine zentrale Gras-Fläche (`Anchored = true`, `CanCollide = true`), die exakt die Größe der PilotBounds in Studs plus 100 Studs Rand abdeckt, wurde bei Y=0 eingezogen.
- **Spawn:** Der Importer sammelt deterministisch Straßenpunkte (ohne Autobahnen), die nahe der Kartenmitte liegen, und setzt dort dynamisch einen `SpawnLocation`-Block ab. Der Avatar startet sicher über dem Straßennetz und steckt nicht mehr in Gebäuden fest.

## 6. Flugmodus und Debug-Overlay
Ein LocalScript in `StarterPlayerScripts/DebugOverlay.local.lua` stellt sicher, dass in Roblox Studio:
- mit `F` ein freier Noclip-Flugmodus aktiviert werden kann (Steuerung per `WASD`, `Q/E`, beschleunigt mit `Shift`).
- mit `O` einmalig eine Top-Down Übersicht ausgelöst wird.
- ein Debug-Overlay links oben alle Projekt-Metriken (FPS, Pilot Coverage, Scale, Counts) anzeigt.

## 7. Tests und Builds
Die vollständige Pipeline lief fehlerfrei durch:
```bash
pnpm geodata:build
pnpm roblox:build
pnpm build:control-center
```
Alle Code-Änderungen sind in `feature/norderstedt-map-importer-mvp` committet.

## 8. Artefakt-Details
- **Dateiname:** `Norderstedt_MVP.rbxlx`
- **SHA-256 Hash:** `75B2DFA3358B3D3859089636470E387E7D25122558C05D779C23FF260616DCFA`

## 9. Verbleibende QA & Limits
- Gebäude-Fassaden sind noch Greybox (OBBs). Reale Polygon-Extrusion folgt in einer späteren Phase.
- Keine Fenster, Texturen oder Dachformen.
- Das Frontend weist den Nutzer nun explizit darauf hin, dass nur Norderstedt-Mitte enthalten ist.

---
**STATUS: GO FOR MANUAL STUDIO QA – SCALE PASS**
