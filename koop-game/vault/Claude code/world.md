# World-Szene (Karte, Spawn-Flow, HUD)

Erklärt `scenes/world/World.gd`/`World.tscn` auf Szenen-Ebene: Kartenlayout,
wie Spieler beim Betreten der Szene mit ihren Start-Einheiten versorgt
werden, und das Status-Message-System. Kamera/Auswahl/Befehle sind in
[`docs/commander.md`](commander.md) ausgelagert, das generische Bausystem
in [`docs/building.md`](building.md). `World` ist die zentrale Node, an
die praktisch jedes andere System andockt — siehe die Dateikopf-Kommentare
in `World.gd` für die volle Querverweisliste.

## Kartenlayout

**Großer Kartenumbau (2026-07-31):** die Karte war zuvor komplett
hartcodiert (feste `.tscn`-Kind-Nodes für jedes Gebäude/Fahrzeug/Nest,
vier feste Zombie-Spawnpunkte, ein fester Ressourcen-Streuradius um den
Weltursprung). Jetzt **prozedural generiert** beim Host-`_ready()`
(`World._generate_world()`), reine lokale Zufallsplatzierung — kein
Noise/Terrain (Höhenrelief-Idee als spätere Backlog-Option vorgemerkt,
siehe persistentes Memory "koopgame_map_planning_session"), kein
Chunk-Streaming. Fog of War seit 2026-08-01 umgesetzt, siehe unten.

- **Bodenfläche `MAP_SIZE := 5000.0` Weltmeter** (vorher 160×160) —
  einzige Quelle der Wahrheit, Boden-`MeshInstance3D`/`CollisionShape3D`
  werden in `_ready()` prozedural aus `MAP_SIZE` erzeugt
  (`(ground_mesh_instance.mesh as BoxMesh).size = Vector3(MAP_SIZE, 0.2,
  MAP_SIZE)`), löst die frühere Drei-Stellen-Duplizierung
  (Konstante/`BoxMesh`/`BoxShape3D`) auf. `ZOOM_MAX` moderat auf `60.0`
  angehoben (vorher 40), **bewusst nicht** linear mit der Fläche
  mitskaliert — bei 5000 wären einzelne Einheiten sonst unsichtbar klein,
  Navigation über größere Distanzen läuft über Minimap-Klick (siehe
  unten). **Neue Kamera-Pan-Begrenzung** in `_handle_pan()`
  (`clampf(pivot.position.x/z, -MAP_SIZE/2, MAP_SIZE/2)`) — gab es vorher
  gar nicht, bei 5000 würde man sonst unbemerkt lange ins Leere fahren.
- **Fünf Stadt-Zonen in ZWEI Größen** (2026-08-01, Kartenplanungs-Session
  — vorher fünf gleich große, Nutzerwunsch "statt eine große mehrere eine
  kleine da zwei große": `CITY_ZONE_LARGE_COUNT := 2` + `CITY_ZONE_SMALL_
  COUNT := 3`, zusammen weiterhin `CITY_ZONE_COUNT := 5`, Performance-
  Rücksicht siehe persistentes Memory "koopgame_map_scale_performance").
  Zentren zufällig gewürfelt mit Mindestabstand (`CITY_ZONE_MIN_SPACING :=
  800.0`, `_pick_zone_center(radius)`) statt einer einzigen Stadt an der
  Kartenmitte. Pro Zone (`_generate_city_zone()`):
  - **Radius:** `CITY_ZONE_RADIUS_LARGE := 260.0` (große Zonen) bzw.
    `CITY_ZONE_RADIUS_SMALL := 150.0` (kleine) — vorher einheitlich 200.
  - **Gebäudezahl:** `BUILDINGS_PER_LARGE_ZONE := 60` bzw.
    `BUILDINGS_PER_SMALL_ZONE := 30` aus `BUILDING_TYPES` (vier benannte
    Gebäudetypen mit echten Loot-Tabellen statt der früheren zwölf
    anonymen Vorlagen, siehe [`docs/scavenging.md`](scavenging.md),
    "Gebäude-Typen + Loot-Tabellen"). Summe (2×60+3×30=210)
    bewusst nah an der vorherigen Gesamtzahl (5×40=200) — reine
    Umverteilung, keine Mehrbelastung für Zielsuche/Netzwerk-Sync. Genau
    ein zufälliger Bauplatz pro Zone bekommt `has_survivor = true` (siehe
    [`docs/recruitment.md`](recruitment.md)).
  - `VEHICLES_PER_ZONE := 2` Fahrzeuge, siehe [`docs/vehicle.md`](vehicle.md).
  - Ein Zombie-Nest, siehe [`docs/zombies.md`](zombies.md), "Zombie-Nest".
  - `ZOMBIES_PER_ZONE := 4` Zombies auf einem Ring, Radius jetzt PRO ZONE
    hergeleitet (`radius + ZOMBIE_SPAWN_RING_OFFSET(60)`, vorher als fester
    `ZOMBIE_SPAWN_RING_RADIUS`-Wert, ging nicht mehr mit zwei
    unterschiedlichen Zonen-Radien). `World.ZOMBIE_DESPAWN_RADIUS` (siehe
    [`docs/zombies.md`](zombies.md), "Zombie-Despawn") ist aus dem
    schlimmsten Fall (größte Zone) hergeleitet, bei dieser Änderung
    mitgepflegt (460→580).

### Straßen-Raster + Gebäudereihen (2026-08-01, Kartenplanungs-Session)

Nutzer verglich mit Infection Free Zone (`infeczion free zone.PNG`,
Projekt-Root): dort echte Häuserblöcke in Reihen entlang klarer Straßen,
bei uns bis dahin komplett zufälliges Streuen ohne jede Ausrichtung.
`_generate_city_zone()` platziert Gebäude jetzt NICHT mehr über
`_spaced_position()` (reines Zufallsstreuen), sondern über ein
Straßen-Raster:

- **`_generate_street_slots(center, radius)`**: legt ein quadratisches
  Blockraster über die Zone (`STREET_BLOCK_SIZE` Blockkante,
  `STREET_WIDTH` Straßenbreite dazwischen, `STREET_CELL_SIZE` =
  Summe beider = Wiederholraster — seit der Kachel-Umstellung (siehe
  "Straßen-Geometrie" unten) beide aus `STREET_TILE_SIZE`/`BLOCK_TILES`
  hergeleitet: `STREET_BLOCK_SIZE = BLOCK_TILES(2) × 12m = 24m` unverändert,
  `STREET_WIDTH` jetzt exakt eine Kachel = `12m` statt vorher `10m`,
  `STREET_CELL_SIZE` dadurch `36m` statt `34m`), pro Zone um `center` zentriert (nicht
  global über die Karte ausgerichtet — jede Zone bleibt optisch in sich
  geschlossen). Nur Blöcke, deren Mittelpunkt innerhalb `radius` liegt,
  zählen (hält die Zone insgesamt kreisförmig statt eckig). Pro Block
  entstehen entlang aller vier Kanten Reihenplätze im Abstand
  `BUILDING_MIN_SPACING`, leicht nach innen versetzt
  (`BUILDING_ROW_INSET := 2.0`) von der Straßenkante — liefert absichtlich
  DEUTLICH mehr Plätze als gebraucht (für eine große Zone mehrere tausend).
- **`_generate_city_zone()`** mischt diese Plätze zufällig
  (`Array.shuffle()`) und bebaut nur `BUILDINGS_PER_*_ZONE` davon — der
  Rest bleibt als unbebaute Lücke stehen. Das hält sowohl die
  Gesamt-Gebäudezahl (Performance) als auch die Zufallsvariation zwischen
  Partien, nur die GEOMETRIE folgt jetzt echten Reihen statt reinem
  Zufall.
- **Sichtbare Straßen-Geometrie seit 2026-08-01 umgesetzt** (siehe
  "Straßen-Geometrie" unten) — **echtes Fahrzeug-Pathing entlang der
  Straßen bleibt weiterhin offen**, eigener Folgeschritt (siehe
  persistentes Memory "koopgame_map_planning_session").
- **Home-Bases/Survivor-Start** weiterhin keine festen Kartenecken — jeder
  Peer wählt beim Betreten der Szene eines der Gebäude **irgendeiner**
  Stadt-Zone als Start-Basis (siehe [`docs/zones.md`](zones.md),
  "Start-Basis wählen"), Home-Base/Survivor spawnen relativ dazu.
- **Fünf Wald-Zonen** (2026-08-01, Punkt 10 der Gesamtliste, `FOREST_ZONE_
  COUNT := 5`), gleiches Cluster-Prinzip wie die Stadt-Zonen — eigener
  Mindestabstand-Check (`_is_far_from_zone_centers()`, ersetzt die frühere
  Stadt-Zonen-eigene Prüfung), gemeinsam mit den Stadt-Zonen über denselben
  `CITY_ZONE_MIN_SPACING`-Wert, damit sich keine zwei Zonen — egal welchen
  Typs — überlappen können. Läuft NACH den Stadt-Zonen in `_generate_world()`
  (kennt beim Platzieren also schon alle Stadt-Zentren). Pro Zone
  (`_generate_forest_zone()`, Radius `FOREST_ZONE_RADIUS := 150.0`):
  - `TREES_PER_FOREST_ZONE := 40` Bäume, deutlich dichter gestreut als die
    allgemeine Wildnis-Streuung (~69× dichter, siehe Konstanten-Kommentar
    in `World.gd`) — das ist der eigentliche visuelle Unterschied zu einem
    "hier stehen halt ein paar Bäume"-Gebiet.
  - Ein **Jagdstand** (`FOREST_BUILDING_TEMPLATE`, aus `Infos/02
    Item-Liste.md`: "Waldrand"-Loot Munition/Waffen) über denselben
    `building_spawner` wie Stadt-Gebäude, aber mit einer festen Vorlage
    statt eines zufälligen Eintrags aus `BUILDING_TYPES` — taucht
    dadurch nie zufällig auch in einer Stadt-Zone auf.
  - **Bewusst kein** neues Terrain/keine andere Bodenfarbe/-textur, kein
    Biom-Blending — reine Entity-Platzierung wie bei den Stadt-Zonen,
    gleiche Philosophie (kein `FastNoiseLite`).
  - **Bekannte, in Kauf genommene Vereinfachung:** die allgemeine
    Wildnis-Streuung (siehe unten) weicht Wald-Zonen NICHT extra aus (nur
    Stadt-Zonen) — zusätzliche Bäume in einer Wald-Zone durch die
    Wildnis-Streuung sind harmlos (machen sie nur noch etwas dichter),
    deshalb kein zusätzlicher Check eingebaut.
- **Wildnis-Ressourcen** (`_spawn_wilderness_resources()`): feste,
  moderat erhöhte Gesamtzahlen über die ganze Karte verteilt (außerhalb
  aller Zonen-Radien, `_is_far_from_city_zones()`) —
  `TREES_TOTAL := 200`, `CAR_WRECKS_TOTAL := 80`, `STONE_PILES_TOTAL :=
  100`, `BRICK_PILES_TOTAL := 100` (vorher 10/4/5/5 auf 160×160).
  **Bewusst nicht** proportional zur ~977× größeren Fläche hochskaliert —
  dieselbe Dichte hätte zehntausende Entities zur Folge und liefe direkt
  in das schon dokumentierte Performance-Risiko (Entity-Zahl, nicht
  Fläche, ist der Flaschenhals bei der Ziel-Suche). **Wächst seit 2026-08-01
  gedeckelt nach** (`World._regrow_resources()`, siehe
  [`docs/zombies.md`](zombies.md) für das analoge Zombie-Despawn-Muster im
  selben Umbau) — alle `RESOURCE_REGROWTH_INTERVAL := 30.0`s höchstens ein
  neuer Knoten pro Typ, nie über die jeweilige `*_TOTAL`-Konstante hinaus
  (dieselbe Grenze wie beim einmaligen Anfangs-Spawn).
- **Konsequenz behoben:** fünf Zonen × je ein Zombie-Nest bedeutete 5×
  so schnelles Zombie-Wachstum wie vorher (ein Nest gesamt) — dafür gibt
  es inzwischen einen globalen Zombie-Deckel (`World.MAX_ZOMBIES`, siehe
  [`docs/zombies.md`](zombies.md), "Zombie-Obergrenze").

Gebäude/Fahrzeuge/Zombie-Nest laufen seit diesem Umbau **wie jede andere
dynamische Entität** über `MultiplayerSpawner`
(`building_spawner`/`buildings_container`,
`vehicle_spawner`/`vehicles_container`,
`zombie_nest_spawner`/`zombie_nests_container` — gleiches Muster wie
Survivor/Zombie/Baum, siehe [`docs/networking.md`](networking.md)), nicht
mehr als feste `.tscn`-Kind-Nodes. Das schließt nebenbei eine frühere
bekannte Grenze: späte Peers bekommen jetzt echtes Catch-up für alle drei
Typen (`_catch_up_building()`/`_catch_up_vehicle()`/
`_catch_up_zombie_nest()`).

### Straßen-Geometrie (2026-08-01, Kartenplanungs-Session, direkte Fortsetzung von "Straßen-Raster")

Nutzer-Feedback nach dem Straßen-Raster-Umbau: Gebäude stehen jetzt zwar
in Reihen, aber es gibt noch keine sichtbaren Straßen selbst — Wunsch
"echte Straßen wie im Infection-Free-Zone-Bild sichtbar machen". Reine
Deko-Geometrie, kein neues Gameplay:

- **`_city_zone_centers` erreicht Clients jetzt per PULL statt PUSH.**
  Bisher kannten NUR Host-Peers `_city_zone_centers` (wurde nirgends an
  Clients verteilt, da bis dahin niemand außer dem Host es brauchte).
  **Erster Versuch (Bug, sofort gefixt):** Host verschickt einmalig per
  `.rpc()`-Broadcast direkt in `_ready()`, "call_local" inklusive — kam
  bei einem Client nicht an ("nur bei einem Spieler werden Straßen
  angezeigt"). Ursache: der Broadcast lief SOFORT nach `_generate_world()`
  auf dem Host, noch BEVOR der langsamere Client sein eigenes `World`-Node
  überhaupt im Netzwerk-Baum hatte — ein RPC an einen zu diesem Zeitpunkt
  noch nicht existierenden NodePath geht beim High-Level-Multiplayer
  spurlos verloren (kein Puffern/Nachliefern). **Fix:** umgedreht auf
  PULL — jeder Client fragt SELBST beim Host an
  (`request_city_zones.rpc_id(1)`), garantiert erst NACHDEM sein eigenes
  `_ready()` (und damit sein `World`-Node) existiert. Der Host antwortet
  darauf gezielt (`_sync_city_zones.rpc_id(anfragender_peer, ...)`) — sein
  eigenes `_ready()` ist beim Verarbeiten eingehender RPCs immer schon
  vollständig durchgelaufen, also `_city_zone_centers` immer schon
  korrekt gefüllt, kein Race mehr möglich. Deckt Frisch-Start UND spät
  beitretende Peers einheitlich ab, ganz ohne separaten Catch-up-Sonderfall
  in `_spawn_for_peer()`.
- **`_build_street_visuals()`**: jeder Peer baut daraus UNABHÄNGIG,
  aber IMMER IDENTISCH dieselben Straßen-Meshes — komplett deterministisch
  aus `(center, radius)` hergeleitet, keine Zufallskomponente (anders als
  die Gebäude-Auswahl in `_generate_city_zone()`, die zufällig unter den
  Raster-Plätzen wählt). Radius pro Zone wird aus dem Index abgeleitet
  (erste `CITY_ZONE_LARGE_COUNT` Zentren = große Zone, Rest = kleine —
  entspricht der festen Reihenfolge aus `_generate_world()`, bleibt beim
  Speichern/Laden erhalten, keine zusätzliche Persistenz nötig).
**Kachel-Umbau (2026-08-02):** die anfängliche `BoxMesh`-Streifen-Fassung
(reines Deko-Rechteck pro Straßenabschnitt, Kreuzungen als kleine
akzeptierte Lücke) ist ersetzt durch echte, vom Nutzer in Blender gebaute
Straßen-Tiles über Godots `GridMap`-Node (siehe `Infos/04 Straßen-Kacheln
Modellier-Referenz.md` für die Asset-Vorgaben: 12m×12m×0,2m, Ursprung
horizontal mittig/vertikal unten, feste Nord=−Z-Ausrichtung pro Form).

- **`$StreetGridMap`** (`World.tscn`, ersetzt den früheren `Streets`-
  Node3D-Container): `cell_size = Vector3(12, 0.2, 12)`,
  `cell_center_y = false` (Kacheln sind unten-verankert, nicht
  mittig — passend zum Blender-Ursprung), `position = Vector3(0, -0.1, 0)`
  (Kachel-Unterkante liegt damit exakt auf der Ground-Mesh-Mitte, die
  Kachel-Oberkante `y=0.1` trifft exakt die Ground-Oberfläche — kein
  Offset-Wert mehr nötig, keine Z-Fighting-Sonderbehandlung wie früher
  `STREET_GROUND_Y`). `mesh_library` zeigt auf die vom Nutzer erstellte
  `res://assets/street_tiles.meshlib`.
- **`World.STREET_TILE_SIZE := 12.0`/`BLOCK_TILES := 2`**: neue
  Basiskonstanten, `STREET_BLOCK_SIZE`/`STREET_WIDTH`/`STREET_CELL_SIZE`
  jetzt daraus abgeleitet (siehe oben, "Straßen-Raster") — GridMap braucht
  eine echte Zelle pro Kachel, ein Block ist `BLOCK_TILES` Kacheln breit,
  danach folgt GENAU EINE Straßen-Kachel-Reihe/-Spalte.
- **`World._pick_zone_center()` snappt jetzt auf das Kachelraster**
  (`_snap_to_tile_grid()`, `snappedf(_, STREET_TILE_SIZE)` pro Achse) —
  ohne das hätte jede Zone einen zufälligen Sub-Tile-Versatz, wodurch die
  Straßen-Kacheln nicht mehr exakt auf ganze `GridMap`-Zellen fallen würden
  (die Gebäude-Reihen aus `_generate_street_slots()` bleiben relativ zum
  Zonen-Zentrum exakt und verschieben sich automatisch mit).
- **`_build_zone_street_tiles(center, radius)`** (ersetzt das frühere
  `_build_zone_streets()`): nutzt dasselbe Blockraster wie
  `_compute_zone_blocks()`. Jeder Block "besitzt" den Straßen-Kachelstreifen
  an seiner Ost-/Südkante + die Südost-Eckkachel, nur wenn der jeweilige
  Nachbarblock existiert (gleiches Dedup-Prinzip wie vorher: nur der
  "nächste" Nachbar wird geprüft, keine doppelt gezeichneten Kanten). Füllt
  zusätzlich das Blockinnere mit der `grass`-Kachel (rein optisch, rein
  optional — fehlt sie in der `MeshLibrary`, bleibt die Zelle einfach beim
  bisherigen flachen Boden, kein Crash).
- **`_place_street_tile()`**: 4er-Nachbarschafts-Bitmaske (N/O/S/W —
  Norden = `-Z`, siehe Modellier-Referenz) pro Straßen-Kachel entscheidet
  Form (`road_straight`/`road_corner`/`road_t`/`road_cross`, per eigener
  `_find_mesh_library_item()`-Suche über `get_item_list()`/`get_item_name()`
  — `MeshLibrary` hat kein eingebautes `find_item_by_name()`, robust gegen
  Neusortierung durch den Nutzer) + Rotation (`GridMap.get_orthogonal_index_from_basis()` aus
  einer reinen Y-Achsen-`Basis`, 90°-Schritte). Dadurch entstehen jetzt
  echte, passende Kreuzungs-/T-/Eck-Kacheln automatisch aus der
  Nachbarschaft — die frühere akzeptierte Kreuzungs-Lücke ist damit
  aufgelöst.

**Drei Folge-Bugs beim ersten echten F5-Test gefunden und behoben
(2026-08-02, direkt im Anschluss an den Kachel-Umbau):**

1. **Meshlib-Dateiname-Tippfehler.** `World.tscn` referenziert
   `res://assets/street_tiles.meshlib`, per Godot-GUI-Konvertierung
   entstand aber wiederholt nur `street_tails.meshlib` (Tippfehler,
   nie behoben, siehe `koopgame_street_tiles_assets`-Memory) —
   `ext_resource` zeigte damit ins Leere, `mesh_library` blieb `null`,
   `_place_grid_tile()`s defensiver `if mesh_library == null: return`
   schluckte das Problem lautlos (keine Straßen, kein Crash, kein
   Fehler-Log). **Fix:** `tools/fix_meshlib_names.gd` (Editor-Tool,
   baut die Meshlib direkt aus den 5 `.glb`-Dateien statt per fehler-
   anfälliger GUI-Konvertierung) mit korrektem Pfad neu ausgeführt.
   Dabei nebenbei einen zweiten, gleich gearteten Bug gefixt: das Tool
   selbst zeigte noch auf den längst umbenannten `road_coner.glb`
   (fehlt seit der Umbenennung zu `road_corner.glb`).
2. **Straßen-Kacheln Y-versetzt, dadurch unter dem Boden versunken.**
   `grass.glb` hat seinen Ursprung (fast) an der Unterkante (Blender-
   Konvention lt. Modellier-Referenz), die vier `road_*.glb` aber
   MITTIG (AABB-Unterkante bei `y≈-0.14` statt `0`, per
   `mesh.get_aabb()` verifiziert) — bei `cell_center_y = false`
   platziert `GridMap` jedes Item an der Zell-UNTERKANTE, wodurch die
   Straßen-Kacheln ~0,14m zu tief lagen und komplett unter der
   Ground-/Gras-Ebene verschwanden (sichtbar war nur noch die
   dunkelolivgrüne `Ground`-Fläche an den Straßenstellen). **Fix:**
   `fix_meshlib_names.gd` berechnet jetzt pro Item automatisch
   `y_fix = -aabb.position.y` und setzt das per
   `MeshLibrary.set_item_mesh_transform()` — bottom-aligned unabhängig
   vom tatsächlichen Blender-Ursprung, kein Blender-Reexport nötig.
3. **Rotationsrichtung war vertauscht.** Der Kommentar direkt oberhalb
   dieses Abschnitts nahm (nach einem Bildvergleich vom 2026-08-01)
   an, `road_straight` sei nativ Ost-West ausgerichtet. Per direkter
   Vertex-Analyse (`mesh.surface_get_arrays()`, alle vier
   Linien-Flächen sind 12m lang in Z, nur 0,2m breit in X) steht jetzt
   fest: nativ ist **Nord-Süd**, die Bildvergleich-Korrektur vom
   Vortag hatte es genau umgedreht. Symptom: Nord-Süd-Straßen zeigten
   quer statt entlang der Fahrbahn laufende Markierungen (vom Nutzer
   per Screenshot bestätigt). **Fix:** `rotation_steps` in
   `_place_street_tile()` an beiden Stellen zurückgetauscht (`0` für
   Nord-Süd, `1` für Ost-West).
- **Bewusst NICHT enthalten:** eine `road_entrance`/Parkplatz-Kachel (der
  Nutzer hat zusätzlich `Straßeneinfahrt.glb` gebaut, bewusst als
  spätere Erweiterung — z. B. Parkplatz — zurückgestellt, nicht Teil
  dieser `MeshLibrary`/dieses Bitmask-Systems).

**Vierter Bug nach dem ersten echten F5-Test (2026-08-02): Ecken/T-Stücke
180° verdreht.** `road_corner`/`road_t` waren in `_place_street_tile()`
nur GERATEN (Nord+Ost bzw. "alles außer Süd"), anders als `road_straight`
nie per Vertex-Daten verifiziert. Nutzer-Screenshot bestätigte falsch
ausgerichtete Ecken. Neues Diagnose-Tool `tools/inspect_road_shapes.gd`
(gleiches EditorScript-Muster wie `fix_meshlib_names.gd`) berechnet den
Vertex-Schwerpunkt beider Meshes — Ergebnis: `road_corner` ist nativ
**Süd+West** offen, `road_t` hat die geschlossene Seite nativ **Nord**,
beide exakt 180° gegenüber der geratenen Annahme verdreht. **Fix:** alle
`rotation_steps`-Werte in beiden Zweigen um 2 (mod 4) verschoben. **Vom
Nutzer bestätigt getestet:** "passt sind jetzt richtig".

### Fahrzeug-Pathing (2026-08-01, Kartenplanungs-Session, letzter offener Punkt)

Der eigentliche ursprüngliche Auslöser der ganzen Kartenplanungs-Session
("Straßen für Autos als Pathing kann auch auf die Liste"). Bewusst KEIN
`NavigationServer3D`/gebackenes Navigationsmesh (bräuchte eigene
Collision-Erfassung pro Gebäude + einen Bake-Schritt, deutlich größerer
Umbau) — stattdessen ein simpler Wegpunkt-Graph aus denselben
Straßen-Kachel-Daten, die schon für die Straßen-Sicht-Geometrie existieren.

- **`World._compute_zone_blocks(center, radius)`**: liefert die Menge der
  Block-Koordinaten (`Vector2i`) innerhalb einer Zone (36m-Raster).
- **`World._zone_street_tiles(center, radius)`**: liefert die Menge der
  tatsächlichen 12m-Straßen-KACHEL-Koordinaten (dieselben Positionen wie
  die sichtbare `$StreetGridMap`-Geometrie) — aus `_build_zone_
  street_tiles()` herausgelöst, damit `find_vehicle_path()` exakt dieselben
  Positionen nutzt wie die sichtbare Straße.
- **`World.find_vehicle_path(from, to)`**: liegt `to` in KEINER Stadt-Zone
  (`_zone_index_containing()`), bleibt es bei der bisherigen Luftlinie
  (`[to]`) — in der Wildnis zwischen den Zonen gibt es keine Straßen-
  Daten, das ist inhaltlich korrekt, keine Lücke. Liegt `to` in einer
  Zone: nächstgelegene Straßen-Kachel zu `from` UND zu `to` bestimmen
  (`_nearest_street_tile()`), dazwischen mit einem simplen BFS
  (`_bfs_grid_path()`, kein gewichtetes A* nötig — jede Kante hat exakt
  dieselbe Länge `STREET_TILE_SIZE`) den kürzesten Weg über die
  Straßen-Kacheln finden, als Weltkoordinaten zurückgeben. Letztes Stück
  vom nächsten Straßen-Punkt zum eigentlichen Ziel bleibt Luftlinie (z. B.
  ein Gebäude leicht abseits der Straße, siehe `BUILDING_ROW_INSET`) —
  unproblematisch, da Fahrzeuge ohnehin nur mit Mauern/Toren kollidieren,
  nicht mit Gebäuden.
- **Korrektur (2026-08-02, Nutzer-Report "fährt über das Gras statt über
  die Straße"):** die ursprüngliche Fassung pathete über Block-MITTEN
  (36m-Raster) statt über echte Straßen-Kacheln — zwei benachbarte
  Block-Mitten liegen 36m auseinander, ein Block ist aber nur 24m breit,
  die direkte Linie dazwischen verlief also zu zwei Dritteln mitten durchs
  Blockinnere (Gras) und nur zu einem Drittel auf der Straße selbst. Fix:
  Pathing komplett auf die 12m-Straßen-Kacheln umgestellt (siehe
  `_zone_street_tiles()`/`_nearest_street_tile()`/`_bfs_grid_path()` oben)
  — jedes Wegstück liegt jetzt vollständig auf Straße.
- **Zweite Korrektur direkt danach** (Nutzer-Report "ein bisschen versetzt
  ist er noch"): halber Kachel-Versatz (6m) durch `$StreetGridMap`s
  `cell_center_x`/`cell_center_z` (Godot-Standard `true`) — neue
  gemeinsame `_street_tile_world_pos()`, siehe oben.
- **Vom Nutzer bestätigt getestet:** "passt fährt genau auf der straße".
  **Backlog (kein Bugfix, Nutzer explizit "kann man später machen wenn
  die assets kommen"):** Einparken am Zielpunkt ist noch ungenau (letztes
  Wegstück bleibt bewusst Luftlinie, siehe oben) — dürfte sich lösen,
  sobald die zurückgestellte `Straßeneinfahrt.glb`/Parkplatz-Kachel (siehe
  "Straßen-Geometrie" oben) eingebaut wird.
- **`Vehicle.order_move()`** ruft `find_vehicle_path()` jetzt statt den
  rohen Zielpunkt direkt als einzigen Wegpunkt anzuhängen — der
  bestehende `_waypoints`-Mechanismus (`_handle_movement()` fährt sie der
  Reihe nach ab) bleibt dabei komplett unverändert, bekommt nur mehr
  Zwischenpunkte. Bei einer bereits laufenden Wegpunkt-Warteschlange
  (Rechtsklick zum Anhängen) startet der neue Pfad-Abschnitt am LETZTEN
  Wegpunkt, nicht an der aktuellen Fahrzeugposition.
- **Bewusst NICHT enthalten:** echtes Umfahren von Gebäuden (siehe oben),
  Pathing für Trupps zu Fuß (nur Fahrzeuge — Trupps liefen schon vorher
  frei über die ganze Karte, kein vergleichbares "Straßen"-Bedürfnis),
  Kreuzungs-Verhalten/Verkehrsregeln.

## Spawn-Flow beim Szenenwechsel

`World.tscn` wird erst betreten, **nachdem** der Host in der Lobby "Spiel
starten" gedrückt hat (siehe [`docs/networking.md`](networking.md)) — zu
diesem Zeitpunkt sind alle mitspielenden Peers schon in
`NetworkManager.players` bekannt.

1. **`_ready()`** (nur auf dem Host): `_spawn_all_players()` (iteriert
   `NetworkManager.players.keys()`, ruft `_spawn_for_peer()` für jeden)
   und `_spawn_zombies()` (spawnt die vier festen Zombies).
2. **`_spawn_for_peer(peer_id)`** — reines Catch-up aller bereits
   existierenden Entitäten an diesen einen Peer (siehe
   [`docs/networking.md`](networking.md)). Spawnt **keine** eigenen
   Einheiten mehr — jeder Peer bekommt seine zwei Survivor (siehe
   [`docs/recruitment.md`](recruitment.md)) + Home-Base erst, sobald er
   selbst eine Start-Basis wählt (siehe [`docs/zones.md`](zones.md),
   "Start-Basis wählen").
3. **`NetworkManager.player_connected`** bleibt auch **innerhalb** dieser
   Szene verbunden (`_on_player_connected()`) — jeder Peer, der hier noch
   ankommt, ist per Definition ein später Beitritt (alle regulären
   Mitspieler sind schon vor dem Szenenwechsel bekannt), es gibt also
   keinen "vor/nach Start"-Sonderfall wie in der früheren 2D-Testszene.

## Status-Nachrichten

`report_status(peer_id, message)` (public) — von praktisch jedem anderen
Node aufrufbar (`get_tree().current_scene.report_status(...)`, gleiches
Cross-Node-Muster wie `spawn_recruit()`, siehe
[`docs/recruitment.md`](recruitment.md)) für kurzes Feedback bei
fehlgeschlagenen Aktionen (Bauversuch, "Kein freier Trupp verfügbar.",
Fahrzeug zerstört, ...) statt stiller Ablehnung. Leitet an
`_show_status_message.rpc_id(peer_id, message)` weiter
(`@rpc("authority", "call_local", "reliable")` — `call_local` ist hier
Pflicht: ohne es sähe der Host seine eigenen Statusmeldungen nie, ein
früher tatsächlich aufgetretener Bug). Blendet sich für
`STATUS_MESSAGE_DURATION := 2.5` Sekunden ein, danach automatisch
ausgeblendet (`_process()` zählt `_status_message_timer` herunter).

## HUD-Refresh-Takt

Kamera/HUD/Ghost-Preview laufen jeden Frame (`_process()`), die
Wachposten-/Einheiten-Listen und Bau-Buttontexte dagegen gedrosselt über
`WORKER_UI_REFRESH_INTERVAL := 0.5` (`_worker_ui_timer`) — vollständiges
Neuaufbauen der Listen bei jedem Refresh statt Einzelupdate (gleiches
einfache Muster wie `Lobby._refresh_player_list()`, siehe
[`docs/networking.md`](networking.md)), ein häufigerer Takt wäre für UI-
Text unnötig.

## Tag/Nacht-Zyklus

Nutzerwunsch: Horde-Nächte (siehe [`docs/zombies.md`](zombies.md),
"Horde-Nächte") sollten an einen echten Spieltag gekoppelt werden statt
an ein reines Echtzeit-Intervall. Später ergänzt um eine sichtbare
Uhrzeit-Anzeige und einen an dieselbe Uhrzeit gekoppelten
Zombie-Nachtbonus (siehe [`docs/zombies.md`](zombies.md),
"Nacht-Schadensbonus").

- **`_day_time: float`** läuft in `_process()` auf **jedem** Peer
  (nicht nur Host) über `_handle_day_night(delta)` hoch — Beleuchtung
  und Anzeige müssen lokal überall stimmen, anders als z. B. der
  Horde-Trigger selbst, der nur host-seitig ausgelöst werden darf (siehe
  unten). Feld-Default `62.5` (= 05:00 Uhr, Nutzerwunsch) statt `0.0` —
  gilt nur für den Frisch-Start, ein geladener Spielstand überschreibt das
  sofort mit dem gespeicherten Wert (siehe [`docs/save_load.md`](save_load.md)).
- **`CYCLE_LENGTH := 300.0`** Sekunden Echtzeit = genau ein
  **`HOURS_PER_DAY := 24.0`**-Stunden-Spieltag — bewusst derselbe
  Gesamtrhythmus wie das frühere, jetzt entfallene `HORDE_INTERVAL`.
  `current_game_hour()` leitet daraus die angezeigte Uhrzeit ab
  (`_day_time / CYCLE_LENGTH * HOURS_PER_DAY`), `_clock_text()` formatiert
  sie als `HH:MM` (+ " (Nacht)"-Suffix), `_update_clock_label()` schreibt
  das jeden Frame ins neue `ClockLabel` im Ressourcen-Panel
  (`$ResourcesUI/Panel/VBoxContainer/ClockLabel`).
- **`NIGHT_START_HOUR := 22.0`**, **`NIGHT_END_HOUR := 4.0`** — Nutzerwunsch
  ("Zombies ab 22 Uhr bis 4 Uhr morgens 20% stärker"), umgerechnet in
  Sekunden als `NIGHT_START_TIME`/`NIGHT_END_TIME` (275s/50s). **Einziger
  Ort**, der sowohl bestimmt, wann optisch Nacht ist, als auch wann
  Zombies zuschlagen dürfen — kein zweites, unabhängiges Zeitfenster,
  das auseinanderlaufen könnte.
- **`is_night()`** (`_day_time >= NIGHT_START_TIME or _day_time <
  NIGHT_END_TIME`, wrapt also über das Zyklusende) ist **öffentlich** —
  `Zombie.gd` fragt das direkt über `get_tree().current_scene.is_night()`
  ab (siehe docs/zombies.md).
- **`_night_amount()`** liefert einen weichen 0–1-Übergang statt eines
  harten Umschaltens: `DUSK_LENGTH := 20.0` Sekunden Ab-/Aufdämmerung
  jeweils vor Nachtbeginn und vor Tagesbeginn, inklusive
  Mitternachts-Wrap-Berechnung (Nachtende liegt zeitlich VOR
  Nachtbeginn im selben Zyklus).
- **`_update_day_night_visuals()`** (läuft auf jedem Peer) blendet
  `DirectionalLight3D.light_energy`/`light_color` sowie
  `WorldEnvironment.environment.background_color`/`ambient_light_color`/
  `ambient_light_energy` zwischen Tag- und Nachtwerten — reine Optik,
  keine Spiellogik.
- **Horde-Trigger:** `_handle_day_night()` prüft zusätzlich (nur wenn
  `multiplayer.is_server()`) `is_night() and not
  _horde_triggered_this_night` und ruft dann einmalig
  `_trigger_horde_night()` auf (löst also exakt um 22:00 Spielzeit aus);
  `_horde_triggered_this_night` wird beim nächsten Zyklus-Wrap
  (`_day_time >= CYCLE_LENGTH`) zurückgesetzt.
- **Späte Peers:** `_spawn_for_peer()` schickt den aktuellen `_day_time`
  per `_catch_up_day_time.rpc_id(peer_id, _day_time)` — sonst würde ein
  später beitretender Peer lokal wieder bei 00:00 anfangen, unabhängig
  vom tatsächlichen Spielstand.
- **Kein echter Kalender** — die Uhrzeit läuft nach 24:00 einfach wieder
  bei 00:00 los, kein fortlaufender Tageszähler.

## UI-Overhaul (2026-08-01)

Nutzerwunsch: "ein komplettes UI overhaul mit dropdown menu verschiedene
tabs etc bevor die koop handel oder rucksackslot oder sonstiges was ui
braucht" — Auslöser war die zuletzt schon mehrfach kommentierte Enge
("alle vier Bildschirmecken sind schon belegt", siehe `_refresh_crafting_
ui()`/`_refresh_building_upgrade_ui()`-Kommentare vor diesem Umbau): Bauen/
Herstellen/Einheiten liefen als drei separate `CanvasLayer`-Panels, je
eines pro Bildschirmecke, mit dem Crafting-System (Punkt 12) war die
letzte Ecke belegt.

**Erste Stufe umgesetzt** (Nutzer wollte danach noch Detail-Feedback geben,
siehe unten): ein gemeinsames Panel `MainTabsUI` mit Godots eingebautem
`TabContainer` ersetzt die drei Panels. Jeder alte Panel-Inhalt ist jetzt
ein Tab:

- **`Bauen`** — 1:1 der alte `BuildUI`-Inhalt (Bau-Buttons, Arbeiter-Liste,
  Ausbauen-Abschnitt).
- **`Herstellen`** — 1:1 der alte `CraftingUI`-Inhalt (Rezept-Liste). Die
  frühere "ganzes Panel ein-/ausblenden bei fehlender Werkstatt"-Logik
  (`crafting_ui.visible = has_workshop`) wurde zu
  `main_tabs.set_tab_hidden(tab_idx, not has_workshop)` — der TAB
  verschwindet jetzt, statt eines ganzen Panels.
- **`Einheiten`** — 1:1 der alte `UnitsUI`-Inhalt (Kontrollgruppen-Buttons,
  Trupp-Liste).
- **Vierter Tab "Handel" seit Punkt 14 (2026-08-01)** — wie hier
  vorausgesagt einfach als weiteres `TabContainer`-Kind ergänzt, siehe
  [`trading.md`](trading.md) für die volle Beschreibung (Schenken +
  echtes Tausch-Angebot).
- **Minimap nachgerückt:** stand vorher "direkt oberhalb des `UnitsUI`-
  Panels" (siehe unten) — jetzt, wo die rechte untere Ecke frei ist, direkt
  in die Ecke selbst (`Minimap.tscn`, Panel-Offsets angepasst).
- **Ressourcen-Panel (oben rechts) bewusst unverändert gelassen** — eine
  Zeile pro der inzwischen 16 Ressourcenarten ist ein eigenes, größeres
  Layout-Problem (eine horizontale Leiste wäre bei 16 Einträgen ohne Icons
  kaum lesbar) und war nicht Teil dieser ersten Stufe.
- **Trupp-Detailfenster ursprünglich unverändert gelassen** (eigenes,
  kontextabhängiges Panel, passte damals nicht ins Tab-Schema) — **seit
  2026-08-03 doch als fünfter Tab "Trupp" integriert**, siehe
  "Fünfter Tab: Trupp-Detailfenster" weiter unten (Auslöser: sichtbare
  Panel-Überlappung).

**Nutzer wollte nach diesem ersten Schritt noch konkretes Detail-Feedback
geben** ("ich sag dir dann was man ändern könnte") — noch nicht final,
weitere Anpassungsrunde vermutlich nötig.

**Noch nicht vom Nutzer getestet** (kein laufender Godot-Editor in dieser
Umgebung — `TabContainer`-Layout insbesondere nicht visuell verifizierbar).

### Ressourcen-Panel kategorisiert (2026-08-01, erstes Detail-Feedback)

Erstes konkretes Feedback nach dem UI-Overhaul: "rechts die Ressourcen sind
bisschen zu viele" — 16 (mittlerweile 14, siehe unten) Ressourcenarten in
einer einzigen Liste (siehe `RESOURCE_DISPLAY_NAMES`) war unübersichtlich
geworden. `RESOURCE_CATEGORIES` (`World.gd`) gruppiert sie in vier feste
Kategorien, jede mit eigenem Label statt einer einzigen Liste:

- **Baurohstoffe:** Holz, Metall, Stein, Ziegel.
- **Überleben:** Nahrung, Medizin, Munition.
- **Ausrüstung:** Waffen, Rüstung, Helm.
- **Forschungsbücher:** die vier `book_*`-Arten.

Reine Anzeige-Gruppierung, **keine neue Spielmechanik** — Nutzer hat eine
mögliche Veredelungsstufe angedacht (Holz → Holzplanken über Crafting,
analog zu den bestehenden Rezepten), das aber bewusst als eigenes,
späteres Thema zurückgestellt (Rückfrage: nur Panel gruppieren vs. beides
zusammen — Nutzer wollte nur die Gruppierung jetzt). Siehe persistentes
Memory `koopgame_resource_refinement_idea` für den Wiedereinstieg.

`_update_resources_label()` befüllt jetzt ein Label pro Kategorie
(`resource_category_labels`, Array in fester Reihenfolge passend zu
`RESOURCE_CATEGORIES`) statt eines einzigen `ResourcesLabel`. Panel dafür
höher (`offset_bottom` 274 → 560) und etwas breiter (174 → 244px) — mehr
Zeilen durch die vier Kategorie-Überschriften, längere Namen wie "Buch:
Munitionsherstellung" brauchten mehr Breite.

**Nutzer-Feedback (2026-08-01, direkt im Anschluss):** "ist besser, aber
sinnvoller wäre in zwei unterschiedliche tabs für später dann" — die
Vier-Kategorien-Gruppierung in einem einzigen, immer sichtbaren Panel ist
schon eine Verbesserung, aber der Nutzer würde stattdessen perspektivisch
lieber **zwei Tabs** dafür sehen (vermutlich analog zum `MainTabsUI`-
Tab-Prinzip, siehe oben) statt eines Dauer-Panels mit vier Labels
übereinander. **Explizit "für später"** — kein Auftrag für jetzt, als
nächster Verbesserungsschritt am Ressourcen-Panel vorgemerkt, sobald
weiter an der UI gearbeitet wird. Noch nicht geklärt: welche zwei
Gruppen genau (z. B. "Bau" [Baurohstoffe+Überleben] vs. "Ausrüstung"
[Ausrüstung+Bücher]?), ob als eigener kleiner `TabContainer` innerhalb von
`ResourcesUI` oder anders gelöst.

**Noch nicht vom Nutzer final getestet/abgenommen.**

**Zwei-Tabs-Umbau umgesetzt (2026-08-03, Nutzerwunsch "UI überarbeiten...
dass es übersichtlicher ist"):** der oben zurückgestellte Punkt ist jetzt
nachgeholt. `ResourcesUI/Panel/VBoxContainer` bekam einen `TabContainer`
mit zwei Tabs statt der vier Kategorien direkt untereinander:

- **"Rohstoffe":** Baurohstoffe + Forschungsbücher (beides
  Produktions-/Ausbau-Material, wird gesammelt und für Bauen/Herstellen/
  Forschen verbraucht, nicht direkt am Trupp getragen).
- **"Ausrüstung":** Überleben + Ausrüstung (beides trupp-nahe
  Verbrauchsgüter — Nahrung/Medizin/Munition halten Trupps am Leben,
  Waffen/Rüstung rüsten sie aus).

`World.resource_category_labels` (Array, Reihenfolge weiterhin passend zu
`RESOURCE_CATEGORIES`) zeigt jetzt in die `TabContainer`-Unterordner statt
direkt in die VBoxContainer — `_update_resources_label()` selbst
unverändert, reine Pfad-Änderung. Panel dabei verkleinert (`offset_bottom`
560 → 290) — pro Tab sind jetzt nur zwei statt vier Kategorien sichtbar,
der vorherige Platzbedarf war nicht mehr nötig.

**Noch nicht vom Nutzer getestet.**

### Fünfter Tab: Trupp-Detailfenster (2026-08-03)

Nutzer-Report: "die ui sind übereinander das truppen ui und alles andere" —
das bis dahin frei positionierte `UnitDetailUI`-Panel (links mittig, feste
Pixel-Offsets von oben) und `MainTabsUI` (unten links, feste Pixel-Offsets
von unten) waren unabhängig voneinander verankert und konnten sich bei
kleineren Fensterhöhen überlappen (keine Beziehung zueinander, nur zum
jeweiligen Bildschirmrand). Nutzerwunsch als Lösung: "am besten alles in
eigene tabs".

**Umsetzung:** `UnitDetailUI` komplett entfernt, sein Inhalt als fünfter
Tab "Trupp" in `MainTabsUI/Panel/TabContainer` eingehängt (nach
"Einheiten", vor "Handel") — dadurch strukturell keine Überlappung mehr
möglich, da ein `TabContainer` immer nur genau einen Kind-Tab gleichzeitig
zeichnet. `World._update_unit_detail_panel()` nutzt jetzt `main_tabs.
set_tab_hidden()` (gleiches Muster wie beim "Herstellen"-Tab) statt eines
eigenen `visible`-Togglens auf CanvasLayer-Ebene — macht den Tab nur
ANWÄHLBAR, sobald genau ein eigener Survivor ausgewählt ist, schaltet aber
NICHT automatisch dorthin um (kein erzwungener Fokuswechsel, konsistent
mit den anderen vier Tabs). Siehe [`survivor.md`](survivor.md),
"Trupp-Detailfenster" für die volle Beschreibung des Panel-Inhalts.

**Noch nicht vom Nutzer getestet.**

## Minimap

`scenes/world/Minimap.tscn`/`.gd` — unten rechts in der Ecke (seit dem
UI-Overhaul oben, vorher direkt oberhalb des separaten `UnitsUI`-Panels,
das jetzt der "Einheiten"-Tab in `MainTabsUI` ist). Reine lokale Anzeige,
**kein neuer Netzwerk-Zustand**: alle
gezeigten Nodes (Gebäude, Home-Bases, Survivor, Fahrzeuge, Zombies,
Zombie-Nest) liegen über das bestehende `MultiplayerSpawner`+RPC-System
längst auf jedem Peer lokal repliziert vor, die Minimap liest sie nur über
dieselben Gruppen-Abfragen aus, die auch sonst überall im Projekt verwendet
werden (`get_tree().get_nodes_in_group(...)`).

- **Zeichnet prozedural** (`Control._draw()`) statt über eine zweite
  Top-Down-Kamera/`SubViewport` — leichtgewichtiger, passt zum bisherigen
  Projektstil (Text-Panels + einfache Farbcodierung statt aufwändigerer
  Rendering-Pipelines).
- **Farbcodierung:** eigene Gebäude/Home-Bases/Trupps weiß, andere Spieler
  cyan, unbeanspruchte Gebäude grau, Zombies rot, Zombie-Nest dunkelrot,
  Fahrzeuge blau. Bäume/Autowracks/Stein-/Ziegelhaufen werden **bewusst
  nicht** gezeigt — potenziell viele Instanzen, würden eher zumüllen als
  nützen.
- **Kamera-Marker:** kleines Dreieck an `World.pivot.position`, ausgerichtet
  nach `pivot.rotation.y` — zeigt Position + Blickrichtung der eigenen
  Kamera.
- **Klick auf die Minimap verschiebt die eigene Kamera dorthin**
  (`pivot.position` setzen) — rein lokal, `pivot` wird nie über das
  Netzwerk repliziert (siehe oben).
- **`World.MAP_SIZE`** (jetzt `5000.0`, siehe "Kartenlayout" oben) wird von
  `Minimap._to_minimap()` für die Umrechnung Welt-XZ → lokale
  Pixel-Koordinate über `get_tree().current_scene.MAP_SIZE` gelesen —
  skaliert sich dadurch automatisch mit, keine Code-Änderung an der
  Minimap selbst nötig gewesen.

## Fog of War (2026-08-01, Kartenplanungs-Session, Punkt 22 der Gesamtliste)

Vision (`Infos/01 Architektur.md`, "Kooperation trotz getrennter Basen"):
"Geteilte Aufklärung — entdeckte Kartenbereiche (Fog of War) werden
zwischen Spielern geteilt." Einer der vier Vision-Koop-Kanäle, bei der
Minimap-Entscheidung (2026-07-31) zunächst zurückgestellt, jetzt im Zug
der Kartenplanungs-Session nachgeholt.

- **Kein neuer Netzwerk-Zustand** — `World._explored_cells: Dictionary`
  (`Vector2i` Rasterzelle → `true`) wird auf JEDEM Peer unabhängig lokal
  berechnet, aus Daten, die ohnehin schon über `MultiplayerSpawner`/RPC
  repliziert vorliegen (Positionen aller `"living"`-Einheiten UND
  Home-Bases, ALLER Spieler, nicht nur der eigenen). Da alle Peers
  dieselben synchronisierten Positionen über dieselbe Zeit hinweg sehen,
  konvergiert `_explored_cells` auf jedem Peer unabhängig zum selben
  Ergebnis — "geteilt" entsteht dadurch von selbst, ganz ohne eine
  einzige zusätzliche RPC.
- **`FOG_CELL_SIZE := 100.0`** (Rasterzellen-Kantenlänge, 50×50 Zellen bei
  `MAP_SIZE := 5000.0`) — grob genug für die Minimap-/Kartenansicht-
  Auflösung, hält `_explored_cells` klein. **`FOG_VISION_RADIUS := 130.0`**
  — etwas über einer Zellenkante, damit sich bewegende Einheiten lückenlos
  aufdecken. **`FOG_UPDATE_INTERVAL := 1.0`**s gedrosselt (eigener Timer in
  `_process()`, läuft auf JEDEM Peer, nicht host-gated — reiner Lese-
  Zugriff auf lokale Daten, keine Autorität nötig).
- **`_update_fog_of_war()`/`_reveal_around()`**: einmal pro Takt werden
  alle Rasterzellen im `FOG_VISION_RADIUS` um jede Einheit/Home-Base als
  erkundet markiert. **Dauerhaft, kein Vergessen** ("geteilte Aufklärung"
  heißt permanent aufgedeckt, nicht nur "aktuell in Sicht") —
  `_explored_cells` wird nur ergänzt, nie geleert.
- **`is_cell_explored(world_pos)`**: öffentliche Abfrage, von
  `Minimap.gd`/`MapView.gd` über `get_tree().current_scene` gelesen
  (gleiches Zugriffsmuster wie dort schon für `MAP_SIZE`/`pivot`
  etabliert).
- **Rendering:** beide Karten zeichnen einen deckenden Nebel-Layer
  (`FOG_COLOR`, fast schwarz) als LETZTEN Schritt über allen Symbolen,
  außer dem Kamera-Marker (bleibt immer sichtbar, auch in unerkundeten
  Bereichen — die eigene Position kennt man ja immer). Iteriert alle
  50×50 Rasterzellen und zeichnet nur für nicht-erkundete ein Rechteck —
  einfacher und robuster als jeden einzelnen Symbol-Zeichenaufruf um eine
  Sichtbarkeits-Prüfung zu ergänzen.
- **Bewusst NICHT enthalten:** kein Fog of War in der eigentlichen
  3D-Kamera-Ansicht (nur auf Minimap/Kartenansicht) — die begrenzte
  Zoom-Reichweite (`ZOOM_MAX`, siehe unten) sorgt dort ohnehin schon dafür,
  dass man nur einen kleinen Kartenausschnitt sieht, ein zusätzliches
  3D-Verdecken wäre doppelt gemoppelt. Kein Catch-up für spät beitretende
  Peers, keine Speicherstand-Persistenz (siehe "Bekannte Grenzen" unten) —
  bewusste Vereinfachung, der Nebel füllt sich ohnehin schnell nach, sobald
  sich Einheiten bewegen.

## Gegenseitige Verteidigung/Hilfe (2026-08-03, Punkt 20 der Gesamtliste)

Vision (`Infos/01 Architektur.md`, "Kooperation trotz getrennter Basen"):
"Gegenseitige Verteidigung/Hilfe — Trupps eines Spielers können einem
anderen Spieler beim Kämpfen/Verteidigen helfen, auch ohne gemeinsame
Basis." Dritter der vier Vision-Koop-Kanäle (Gemeinsame Gefahr ✓, Handel
[14] ✓, Geteilte Aufklärung [22] ✓).

**Mechanisch ging das schon vorher** — `order_attack()`/`order_move()`
haben keinen Zonen- oder Besitzer-Filter, ein Feldtrupp konnte immer schon
zu einer fremden Basis laufen und dort Zombies bekämpfen. Was fehlte, war
die **Sichtbarkeit**: ohne aktiv hinzuschauen merkte kein anderer Spieler,
dass gerade jemand angegriffen wird. Diese Session ergänzt genau das —
einen Hilferuf/SOS-Alarm.

- **`Zombie._try_attack()`** ruft nach jedem erfolgreichen Treffer
  `World.maybe_alert_sos(target)` auf (gleiches Cross-Node-Muster wie
  `report_status()`/`spawn_recruit()`). `target` ist Survivor/Vehicle
  (Gruppe `"living"`), eine geclaimte Building (Gruppe `"searchable"`)
  ODER eine blockierende Wall/Gate — alle vier haben ein `owner_peer_id`-
  Feld, per `target.get("owner_peer_id")` duck-typed statt eines
  Klassencasts abgefragt.
- **`SOS_COOLDOWN := 30.0`** drosselt PRO OPFER-PEER (`_last_sos_broadcast`,
  `Time.get_ticks_msec()`), nicht pro Treffer — sonst würde bei jedem
  Zombie-Schlag (alle `ATTACK_COOLDOWN` = 1s) ein neuer Alarm rausgehen.
- **Zwei Effekte pro Alarm:** (1) `report_status()` an ALLE Spieler außer
  dem Opfer selbst ("<Name> wird angegriffen! Hilfe gebraucht."), (2)
  `_sync_sos_alert.rpc()` — repliziert Position + Dauer
  (`SOS_MARKER_DURATION := 20.0`) an alle Peers, die daraus lokal ihren
  eigenen Ablaufzeitpunkt berechnen (`Time.get_ticks_msec()` läuft pro
  Prozess unabhängig, ein vom Host gesendeter absoluter Zeitstempel wäre
  auf einem Client bedeutungslos).
- **`World.active_sos_alerts()`**: öffentliche Abfrage (gleiches
  Zugriffsmuster wie `is_cell_explored()`), gibt alle noch nicht
  abgelaufenen Alarm-Positionen zurück, filtert abgelaufene beim Lesen raus
  (kein eigener Cleanup-Timer nötig — `_sos_alerts` bleibt ohnehin klein,
  ein Eintrag pro Opfer-Peer, überschrieben statt akkumuliert).
- **Rendering:** `Minimap.gd`/`MapView.gd` zeichnen einen pulsierenden
  roten Ring pro aktivem Alarm, NACH dem Fog-of-War-Layer (wie der
  Kamera-Marker) — ein Hilferuf soll gerade AUSSERHALB des selbst schon
  erkundeten Gebiets warnen, sonst wäre die Vorwarnung nutzlos.
- **Bewusst KEIN neuer Zwangsmechanismus** — kein automatisches
  Teleportieren, kein Pflicht-Eingreifen, nur Sichtbarkeit. Ob ein anderer
  Spieler tatsächlich hilft, bleibt komplett freiwillig, wie es die Vision
  beschreibt ("können ... helfen", keine Pflicht).

**Noch nicht vom Nutzer getestet.**

## Kamera-Zoom-Bereich (2026-08-01, Nutzerwunsch nach Bildvergleich)

Nutzer hat einen Infection Free Zone-Screenshot verglichen (Kamera dort
kommt nie so nah an einzelne Einheiten heran wie es bei uns möglich war) —
`ZOOM_MIN` von `4.0` auf `10.0` angehoben, bleibt unter dem
Default-Start-Zoom (`_zoom_distance := 12.0`), sonst wäre der Startwert
beim ersten Frame außerhalb des gültigen Bereichs.

**Bewusst als reine Stil-/Gameplay-Entscheidung geklärt, KEINE
Performance-Maßnahme:** `_apply_zoom()`/`_zoom()` verschieben die Kamera
nur als Positions-Offset zum `Pivot` — keine Level-of-Detail-Logik, kein
`visibility_range`, keine Entfernungs-basierte Simulationsdrosselung im
gesamten Projekt. Ein Zombie außerhalb des Bildschirms wird exakt genauso
oft berechnet wie einer direkt vor der Kamera, unabhängig vom Zoom-Level.

**Vom Nutzer explizit im Hinterkopf zu behalten (2026-08-01):** "nah ran
zoomen" könnte später nochmal relevant werden — noch keine konkrete
Anforderung, nur eine Erinnerung, dieses Thema nicht als endgültig
abgehakt zu betrachten. Siehe auch persistentes Memory
`koopgame_map_planning_session` (Kamera/Zoom passt thematisch in die
geplante Gesamt-Kartenplanung).

**Falls Performance bei vielen Einheiten künftig nochmal ein Thema wird:**
eine ECHTE Entfernungs-basierte Simulationsdrosselung (Zombies weit weg
von jedem Spieler seltener/gar nicht simulieren) wäre die eigentlich
wirksame Optimierung — unabhängig vom Zoom-Bereich, noch nicht gebaut.

## Kartenansicht (2026-08-01, Punkt 11 der Gesamtliste)

`scenes/world/MapView.tscn`/`.gd` — ergänzt die Minimap (siehe oben) um
eine große, per Taste (`KEY_M`, siehe `World._unhandled_input()`) ein-/
ausblendbare Vollbild-Ansicht (Vorbild: Infection Free Zone, siehe
`Infos/01 Architektur.md`). **Offene Design-Frage aus der Planung geklärt:**
Nutzer wollte eine eigene Taste statt automatisch bei `ZOOM_MAX` — bewusste
Entscheidung, unabhängig vom Zoom-Level jederzeit aufrufbar.

- **Strukturell fast identisch zur Minimap** (gleiches
  `Control._draw()`-Prinzip, gleiche Gruppen-Abfragen, gleiche
  Farbcodierung/Kamera-Marker) — eigenes Script statt Wiederverwendung, weil
  die Radien/Größen für die deutlich größere Fläche anders skaliert sind
  (`UNIT_RADIUS`/`BUILDING_HALF_SIZE`/etc. jeweils gut doppelt so groß wie
  in `Minimap.gd`).
- **Zusätzlich zur Minimap: Loot-Status pro Gebäude** (Vision:
  "Icons (u. a. 'noch nicht geplündert' pro Gebäude)") —
  `_draw_square_outline()` zeichnet einen gelben Rahmen (`LOOT_AVAILABLE_
  COLOR`) um jedes Gebäude mit `is_looted == false`, unabhängig vom
  Besitzer-Status. Bewusst ein Farbrahmen statt eines echten Icons — kein
  Icon-Set im Projekt, gleiches Prinzip wie überall sonst (Farbe/Form statt
  Textur).
- **Klick = "Fast Travel":** verschiebt die Kamera dorthin (`_pan_to()`,
  1:1 wie bei der Minimap) UND schließt die Kartenansicht direkt wieder
  (`World.toggle_map_view()`) — die eigene Taste galt fürs bewusste Öffnen,
  nicht dafür, dass die Ansicht nach der Navigation offen bleiben soll.
- **`World.toggle_map_view()`** ist die einzige Stelle, die
  `map_view_ui.visible` umschaltet — sowohl `KEY_M` als auch
  `MapView._gui_input()` (nach dem Klick) rufen dieselbe Methode auf.
- **`_process()` überspringt `queue_redraw()`, solange die Ansicht
  unsichtbar ist** — anders als die Minimap (die immer sichtbar ist und
  deshalb ohne Sichtbarkeits-Check auskommt), spart das unnötige
  Neuzeichnungen, während die Karte geschlossen ist.

**Grundmodell vom Nutzer bestätigt** ("passt das Grundmodel"). **Backlog,
kein Bugfix:** Nutzerwunsch "später sollten wir das schöner machen" —
noch ganz offen, was genau (Icons statt Farbrahmen? Layout? Beschriftung?),
erst angehen, wenn der Nutzer konkretisiert. Siehe
[`pending-tests.md`](pending-tests.md), "Vollbild-Kartenansicht".

## Bekannte Grenzen (noch nicht gelöst)

- **Maximal 4 Spieler** (`MAX_PLAYERS` in `NetworkManager.gd`), 5 Zonen ×
  24 Gebäude zur Start-Basis-Wahl — bei 4 Spielern bleiben reichlich frei
  zum späteren Claimen (siehe [`docs/zones.md`](zones.md)).
- **Fog of War hat kein Catch-up für spät beitretende Peers und keine
  Speicherstand-Persistenz** — ein neu beigetretener Peer (oder nach dem
  Laden) startet mit komplett ungeklärtem Nebel, füllt sich aber schnell
  wieder, sobald sich Einheiten bewegen (siehe "Fog of War" unten). Gleiche
  bewusste Vereinfachung wie bei `HomeBase.unlocked_recipes`/den
  Handel-Angeboten (kein neuer Netzwerk-Zustand nötig).

## Testen

Debug → Customize Run Instances → 2 → F5, Host + Join, "Spiel starten".
Beide Peers sollten in `World.tscn` zunächst ohne Trupps/Home-Base starten,
mit sichtbarem `"Wähle deine Start-Basis"`-Label. Je ein anderes Gebäude
anklicken — sollte sich bläulich färben, zwei Trupps + eine Home-Base
sollten daneben erscheinen, das Label verschwindet. Dasselbe Gebäude mit
dem anderen Peer anklicken (bevor der erste fertig ist) — sollte
fehlschlagen ("Dieses Gebäude ist schon vergeben."). Einen dritten Client
später beitreten lassen (vor "Spiel starten" in der Lobby) — sollte
ebenfalls die Basis-Wahl sehen und ein eigenes Gebäude wählen können.
