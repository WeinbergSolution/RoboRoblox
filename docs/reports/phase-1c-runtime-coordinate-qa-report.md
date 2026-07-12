# RoboRoblox – Phase 1C Runtime Coordinate Contract & Reliable QA Flight

## 1. Lokale Runtime-Koordinaten
Die Pipeline wurde umgeschrieben, um einen strikten Trennstrich zwischen absoluten UTM-Daten (EPSG:25832) und lokalen Roblox-Meters/Studs zu ziehen:
- Das Zentrum der Pilot-Bounding-Box wird als `OriginEPSG25832` extrahiert.
- Alle Laufzeitkoordinaten (Straßenpunkte, Gebäude-OBB-Zentren) werden in Python relativ zu diesem Ursprung berechnet (als lokale Meter).
- `LocalBoundsMeters` und `LocalBoundsStuds` sind nun um `0,0` zentriert.

Beispiel für PilotBounds (vorher absolute UTM):
*Vorher:* `MinX: 3.55 Mio Studs`
*Jetzt:* `MinX: -8900 Studs` (ungefähr, zentriert um Origin).

## 2. Ground Fix
Der Importer verwendet nun `LocalBoundsStuds` für die Ground-Erzeugung.
- Ground Center ist jetzt fast exakt bei `0, 0`.
- Vor Erzeugung findet eine Sicherheitsabfrage statt: `abs(centerX) < 10000`.

## 3. Gebäude OBB Fix
Die Gebäude-OBBs exportieren ein explizites Feld `CenterLocalMeters`.
- Der Importer multipliziert nur noch diese lokalen Meter mit dem Scale `3.571428`.
- Die Gebäude werden wieder exakt bei den Straßen platziert.
- Validierung: `abs(CenterLocalMeters[X]) < 10000`.

## 4. Import Status & Validierung
Der Importer erzeugt in `ReplicatedStorage.CityImportStatus` String/NumberValues.
- Status: RUNNING -> COMPLETE.
- Zeigt exakte Anzahl erstellter Straßen und Gebäude.

## 5. QA DebugOverlay & Flugmodus
Die Datei `StarterPlayerScripts/DebugOverlay.local.lua` wurde von Grund auf neu geschrieben:
- Zeigt sich sofort nach Start mit `print("[RoboRoblox QA] DebugOverlay LocalScript started")`.
- Nutzt UI-Buttons für: `[FLY: OFF]`, `[OVERVIEW]`, `[CENTER]`, `[NORTH]`, `[SOUTH]`, `[EAST]`, `[WEST]`.
- Fliegen (`F`) schaltet `Humanoid.AutoRotate` ab, setzt Gravity=0, wendet NoClip auf das Character-Rig an und steuert deterministisch via Kameraausrichtung.
- Tastensteuerung (`WASDQE`, `Shift`) erfolgt robuster via `ContextActionService`.

## 6. Bereinigtes Git & Artefakt-Hash
- Die versehentlich eingefügten Binaries `rojo.exe` und `rojo.zip` wurden restlos aus dem Branch gelöscht und in `.gitignore` eingetragen.
- Neues `.rbxlx` Artefakt generiert.

**Dateiname:** `Norderstedt_MVP.rbxlx`
**SHA-256 Hash:** `92EF282BA2A79D911E3F801CD787D35A9EB787318C96D1A221702A72C69E3BA0`

---
**STATUS: GO FOR MANUAL STUDIO QA – RUNTIME COORDINATES PASS**
