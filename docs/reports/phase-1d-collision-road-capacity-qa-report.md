# RoboRoblox – Phase 1D Collision & Road Capacity QA Report

## 1. Avatar fällt durch die Welt (Ground Collision Fix)
Das Pilotgebiet Norderstedt-Mitte ist in Studs gemessen sehr groß (mehrere Tausend Studs pro Achse). Bisher wurde der Boden als ein einzelner `PilotGround`-Block erzeugt. Dadurch griff außerhalb des Zentrums das Physics Culling der Engine, oder das Limit der maximal effektiven Kollisionsgröße eines einzelnen Parts wurde überschritten, wodurch der Avatar abseits der Straßen durch den Boden fiel.
**Lösung:** Der Boden wird nun dynamisch in kleinere Kacheln (`1000x1000` Studs) zerlegt ("Tiling"). Jede Kachel ist ein separater verankerter Part. Dadurch bleibt die Kollisionsberechnung über die gesamte Kartengröße hinweg aktiv und stabil.

## 2. QA-/Flug-Overlay erscheint nicht
Das `DebugOverlay.local.lua` Script stoppte bisher die sofortige UI-Erzeugung, da es auf synchrone, potenziell verzögerte Netzwerk-Replikation von Ordnern wie `CityImportStatus` (`WaitForChild(..., 10)`) wartete. Trat hier eine Verzögerung auf, erschien die UI für den Nutzer scheinbar nie.
**Lösung:** Die gesamte GUI-Erstellung (inklusive Buttons und Labels) erfolgt nun sofort in der ersten Zeile des Scripts und wird direkt dem `PlayerGui` angehängt. Erst danach wartet das Script in einer asynchronen Routine (`task.spawn`) auf die `CityData`- und `CityImportStatus`-Daten, um die Labels zu aktualisieren.

## 3. Straßen zu schmal für Gegenverkehr
Die bisher aus OpenStreetMap extrapolierten Standard-Breiten waren physikalisch zwar halbwegs korrekt (z.B. 6 Meter für `residential`), entsprachen im Spiel aber nur ca. 21.4 Studs. Bei der typischen Breite von Roblox-Fahrzeugen (10-12 Studs) ließ das keinen Platz für echten Gegenverkehr.
**Lösung:** Die Default-Straßenbreiten in `pipeline.py` wurden drastisch nach oben korrigiert. `residential` ist nun beispielsweise 10.0 Meter (entspricht knapp 36 Studs). Dadurch können auch große Roblox-Autos problemlos aneinander vorbeifahren.

---

## 4. Tests & Artefakt-Hash
Alle Fixes wurden kompiliert und in das `.rbxlx`-Artefakt exportiert:
- Python-Pipeline lief deterministisch durch.
- Rojo kompilierte erfolgreich in die Roblox-Projektdatei.

**Dateiname:** `Norderstedt_MVP.rbxlx`
**SHA-256 Hash:** `F3702FD1D6D2763DB65B7A645DA93AD213B86275A594575EE21444E0DD6DB5AC`

---
**STATUS: GO FOR MANUAL STUDIO QA – COLLISION & ROAD CAPACITY PASS**
