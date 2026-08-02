# Performance-Benchmarks

Reines Messprotokoll — WAS gemessen wurde und WELCHER Kartenstand/welche
Fixes dabei aktiv waren. Das WARUM/WIE der einzelnen Fixes steht in
[`zombies.md`](zombies.md) ("Performance: ..."-Abschnitte) und
[`world.md`](world.md) ("Kartenlayout", Städtegröße). Diese Datei nur
fortlaufend um neue Messungen ergänzen, nicht die Fix-Begründungen
duplizieren.

## Testmethodik

- **Debug-Hotkey `F9`** (`World._debug_spawn_zombies()`) spawnt sofort 50
  Zombies um die aktuelle Kameraposition, ignoriert `MAX_ZOMBIES` bewusst —
  mehrfach drücken für höhere Zahlen. Kein Spielfeature, reines
  Entwickler-Werkzeug (siehe `docs/zombies.md`, "Zombie-Obergrenze").
- **FPS/Frametime** werden vom Godot-Debugger/Profiler-Overlay abgelesen
  (Nutzer-Screenshots, z. B. `fehler.PNG` für den ersten Trap-Fehler) — in
  dieser Umgebung kein GUI-Zugriff, also keine automatisierte Messung
  möglich, alle Werte sind Nutzer-Angaben.
- **Ungeklärt, sollte vor der nächsten Messreihe geklärt werden:** läuft der
  Test **solo** (einfaches F5) oder mit zweitem Client (Debug → Customize
  Run Instances, wie beim Trupp-Arten-Feature schon einmal genutzt)? Seit
  dem RPC-Skip-Fix (siehe unten, Zeile 2026-08-01c) ist das relevant — der
  Fix greift nur, wenn `multiplayer.get_peers()` leer ist, also nur im
  echten Solo-Fall.
- **Kartenstand wird pro Messung vermerkt** (Stadtgröße, aktive Fixes) —
  Messungen mit unterschiedlichem Kartenstand sind nicht direkt
  vergleichbar, nur read Zeilen mit gleichem Stand.
- Alle bisherigen Optimierungen entstanden aus **Code-Durchsicht**, nicht
  aus echten Profiler-Daten (Punkt 1 der Performance-Liste, der
  Godot-Profiler-Schritt, wurde auf Nutzerwunsch übersprungen, siehe
  `status.md`).

## Messreihe (chronologisch, neueste zuletzt)

| Datum | Zombies | FPS | Frametime | Kartenstand / aktive Fixes | Notizen |
|---|---|---|---|---|---|
| 2026-07-31 | 500 (F9, über Cap) | 15 | ~66ms | Vor allen Zombie-Performance-Fixes, 5000×5000-Karte, `CITY_ZONE_RADIUS` 120 | Ursprünglicher Messwert, Auslöser der gesamten Performance-Liste (Punkte 1-7) |
| 2026-08-01a | 300 (F9) | 35–40 | bis 40ms | + Spatial Grid (`World.zombies_near()`) + Zielsuche-Throttling (`TARGET_SEARCH_INTERVAL`), noch ohne Material-Cache | Deutliche Besserung ggü. 500@15fps, aber noch spürbar ruckelig — Anlass für den Material-Cache-Fund |
| 2026-08-01b | 320 (F9) | 75 | 17–20ms | + Material-Cache statt Neuallokation pro Frame (`Zombie._material`) | Alle drei Fixes zusammen bestätigt wirksam |
| 2026-08-01c | 620 (F9) | 37 (Ausschläge bis 35) | 40–50ms | + Städte größer (`CITY_ZONE_RADIUS` 120→200, `BUILDINGS_PER_ZONE` 24→40) + Ressourcen-Nachwachsen, noch ohne RPC-Skip | Skaliert jetzt ~linear statt quadratisch (620/320≈1,9×, Frametime-Verhältnis ~2,2–2,9×) |
| 2026-08-01d | 620 (F9) | 38–40 | 45–55ms | + RPC-Skip ohne Remote-Peer (`multiplayer.get_peers().is_empty()`) | Kaum Veränderung ggü. 2026-08-01c, teils sogar leicht höhere Frametime — siehe "Offene Fragen" unten |
| 2026-08-01e | 670 (F9) | ~40 | 40–50ms (schwankt spürbar) | + Netzwerk-Sync-Bündelung (Punkt 7), **echter Multiplayer-Test: beide Clients liefen** (Debug → Customize Run Instances → 2) | Erster explizit bestätigter Multiplayer-Test. Trotz mehr Zombies (670 vs. 620) gleiche/leicht bessere Werte als der Solo-Test 2026-08-01d — Bündelung hält die Multiplayer-Kosten offenbar flach. Frametime schwankt spürbar hoch/runter statt stabil zu bleiben, siehe "Offene Fragen" |

## Offene Fragen / TODO

- **Solo- vs. Multiplayer-Testaufbau bei 2026-08-01a–d weiterhin unklar** —
  seit 2026-08-01e explizit als Multiplayer-Test bestätigt, für die
  früheren Zeilen aber nicht rückwirkend geklärt (nicht mehr sicher
  rekonstruierbar, keine praktische Auswirkung mehr, da alle relevanten
  Fixes inzwischen umgesetzt sind).
- **Frametime-Schwankung bei 2026-08-01e** ("geht hoch und runter" statt
  stabil) — noch nicht untersucht. Mögliche Kandidaten für eine künftige
  Stichprobe: `World._despawn_far_zombies()` (alle 10s,
  `ZOMBIE_DESPAWN_CHECK_INTERVAL`) oder `_regrow_resources()` (alle 30s)
  könnten periodische Spitzen verursachen, ebenso normaler Netzwerk-Jitter
  im echten Multiplayer (bei Solo-Tests nicht vorhanden). Reine Vermutung,
  nicht verifiziert — kein akuter Handlungsbedarf, nur vormerken für den
  nächsten Stichprobentest.
- Kein laufender Godot-Editor in dieser Umgebung — ein echter Profiler-Lauf
  (Punkt 1, übersprungen) würde beide offenen Fragen direkt beantworten,
  falls irgendwann doch verfügbar.
