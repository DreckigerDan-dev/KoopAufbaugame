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
  - **`RESOURCES_PER_CITY_ZONE := 6`** (2026-08-04, siehe
    `docs/mechanics-review.md`, "Ressourcen-Wirtschaft") — Bäume/Stein-/
    Ziegelhaufen/Autowracks (`CITY_RESOURCE_TYPES`) gab es vorher NUR in
    der Wildnis (`_random_wilderness_position()`), jetzt zusätzlich auch
    verteilt innerhalb jeder Stadt-Zone (`_spaced_position()`, gleiches
    Muster wie Fahrzeuge/Zombie-Nest oben) — kürzere Laufwege gerade am
    Anfang. 6 × 5 Zonen = 30 zusätzliche Knoten kartenweit, zählen normal
    gegen die jeweilige `_TOTAL`-Konstante/Nachwachs-Obergrenze mit.
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
  `BUILDING_MIN_SPACING` (2026-08-04 von 6m auf 10m erhöht, ans erste
  echte Gebäude-Asset angepasst, siehe `docs/building.md`, "Wohnhaus";
  noch am selben Tag wieder auf 5m halbiert, siehe "Straßenabstand
  tiefenabhängig" unten), leicht nach innen versetzt von der Straßenkante
  (`BUILDING_STREET_MARGIN`, seit derselben zweiten Runde tiefenabhängig
  statt eines festen Werts) — liefert absichtlich DEUTLICH mehr Plätze als
  gebraucht (für eine große Zone mehrere tausend).
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

### Mehrfach-Reihenplätze (2026-08-04)

Behebt die bis dahin bekannte, bewusst offen gelassene Lücke bei
`BUILDING_MIN_SPACING` oben ("Größere Typen wie Supermarkt (18m) brauchen
... eine eigene Slot-Breite pro Typ — hier bewusst noch nicht vorgebaut") —
Anlass war die Nutzerfrage, ob der Supermarkt beim Blender-Modellieren
wirklich in den vollen Vision-Maßen (18×12m) gebaut werden soll, obwohl ein
Reihenplatz nur 10m Abstand zum nächsten hat.

- **`_generate_street_slots()` liefert jetzt strukturierte Slots**
  (`Array[Dictionary]` statt `Array[Vector3]`) — jeder Eintrag zusätzlich zu
  `"position"` mit `"row_id"` (identifiziert eine der vier Reihen pro Block:
  Süd/Nord entlang X, West/Ost entlang Z), `"row_index"` (Position
  innerhalb dieser Reihe, 0/1/2/...) und `"along_x"` (verläuft die Reihe
  entlang X oder Z). Damit lässt sich der direkte Nachbar-Slot in
  DERSELBEN Reihe gezielt finden (`row_id` gleich, `row_index` ± 1) statt
  nur einen isolierten Punkt zu haben.
- **`_generate_city_zone()` reserviert bei breiten Typen mehrere Slots**:
  `span := clampi(ceili(along_row_size / BUILDING_MIN_SPACING), 1,
  MAX_BUILDING_SLOT_SPAN)`, wobei `along_row_size` die Größe ENTLANG der
  jeweiligen Reihenrichtung ist (`size.x` auf einer X-Reihe, `size.z` auf
  einer Z-Reihe — beim Supermarkt (18×12) überschreitet in BEIDEN
  Ausrichtungen die jeweils maßgebliche Seite die 10m-Lücke, `span = 2` in
  jedem Fall, keine Rotation des Gebäudes nötig). Findet der aktuelle Slot
  genug freie, direkt benachbarte Slots (`row_index + 1`, `+ 2`, ...), wird
  die Bauposition der MITTELPUNKT aller reservierten Slots, alle werden als
  verbraucht markiert. Reicht der Platz nicht (Reihenrand erreicht oder
  Nachbar schon vergeben), bleibt der Slot leer — kein Retry mit einem
  schmaleren Typ, passt zur bestehenden "unbebaute Lücke wirkt organischer"-
  Philosophie.
- **Zweiphasig statt direkt erzeugend** — `_generate_city_zone()` sammelt
  erst alle Platzierungen in einem Array, bevor es sie erzeugt, weil die
  tatsächliche Anzahl PLATZIERTER Gebäude (wegen gescheiterter breiter
  Rollen) kleiner als `building_count` ausfallen kann — der zufällige
  `has_survivor`-Index braucht deshalb die tatsächliche, erst hinterher
  bekannte Platzierungs-Anzahl.
- **`MAX_BUILDING_SLOT_SPAN := 3`** — Sicherheitsnetz gegen einen
  versehentlich riesigen Wert in einem künftigen Gebäudetyp, der sonst
  unbegrenzt viele Slots am Stück verlangen könnte.
- **Supermarkt-Platzhalter vorab auf echte Maße gesetzt** (`Vector3(18.0,
  4.5, 12.0)`, siehe `Infos/03 Asset-Checkliste.md`) — VOR der eigentlichen
  Asset-Lieferung, damit der Mechanismus schon an der aktuellen
  Platzhalter-Box im Spiel überprüfbar ist, nicht erst nach dem
  Modell-Einbau. Reine Vorbereitung — bleibt Supermarkt der einzige Typ,
  der aktuell `span > 1` braucht.
- **Keine Gebäude-Rotation** — zunächst bewusst nicht gebaut, siehe
  Nachtrag "Gebäude-Rotation" weiter unten: hat sich beim Supermarkt-Test
  als echter Bug herausgestellt (Front zeigte nicht zur Straße) und wurde
  noch am selben Tag nachgerüstet.

**Noch nicht vom Nutzer getestet** (Platzhalter-Box, echtes Modell fehlt
noch).

### Straßenabstand tiefenabhängig + kompaktere Stadt (2026-08-04)

Direkte Fortsetzung von "Mehrfach-Reihenplätze" oben, ausgelöst durch den
Nutzer-Screenshot `bilder/supermarkt in game.PNG`: die Supermarkt-Front
stand fast auf der Fahrbahnmarkierung, UND generelles Feedback, dass die
Stadt gegenüber Infection Free Zone "3x größer" wirkt (ein Haus bei uns
fühlt sich an wie drei IFZ-Häuser).

**Ursache geklärt, kein Bug:** `World.BUILDING_TYPES`/Straßen-Kacheln
verwenden ECHTE Maße (18×12m Supermarkt, 12m-Straßenbreite = eine
vierspurige Straße), IFZ (wie die meisten Städtebau-/Survival-Spiele)
staucht Gebäude/Straßen dagegen bewusst auf Spiel-Maßstab. Nutzer-
Entscheidung: Gebäude bleiben bei ihren echten Maßen (keine Asset-
Neuskalierung), Stadt wird stattdessen INSGESAMT kompakter gepackt.

- **`BUILDING_STREET_MARGIN := 1.5`** ersetzt den festen
  `BUILDING_ROW_INSET` (5.0) — der war auf die Wohnhaus-Tiefe (8,2m)
  kalibriert und ließ den tieferen Supermarkt (12,2m) über die Blockkante
  hinaus auf die Straße ragen. Jetzt wird die Position auf der
  REIHEN-SENKRECHTEN Achse (Z bei Süd/Nord-Reihen, X bei West/Ost-Reihen)
  erst in `_generate_city_zone()` berechnet, NACHDEM die tatsächliche
  Gebäudetiefe in dieser Richtung bekannt ist: `perp_coord = perp_base +
  perp_sign × (halbe_Tiefe + BUILDING_STREET_MARGIN)`. `_generate_street_
  slots()` liefert dafür `perp_base` (rohe Blockkante) und `perp_sign`
  (+1/−1, Richtung "nach innen") pro Slot mit — jede Gebäudetiefe bekommt
  dadurch denselben knappen, aber sicheren 1,5m-Abstand zur Straße, egal
  ob Wohnhaus oder Supermarkt.
- **`BUILDING_MIN_SPACING` 10m → 5m halbiert** — verkleinert den Abstand
  ZWISCHEN Gebäuden INNERHALB einer Reihe, ohne die Straßenbreite
  anzufassen (die ist an echte, unveränderbare Straßen-Kachel-Assets
  gebunden, `STREET_TILE_SIZE`, siehe unten — eine Verkleinerung dort
  hätte Asset-Neuarbeit gebraucht). Der Mehrfach-Reihenplätze-Mechanismus
  (siehe oben) skaliert automatisch mit: `span = ceili(along_row_size /
  BUILDING_MIN_SPACING)` wächst bei kleinerem Nenner, `MAX_BUILDING_SLOT_
  SPAN` deshalb von 3 auf 5 angehoben (der Supermarkt braucht bei 5m
  Abstand jetzt 4 Slots statt 2 — mathematisch weiterhin überlappungsfrei,
  siehe Herleitung im Code-Kommentar dort).
- **Bewusst NICHT angefasst: `BUILDINGS_PER_LARGE_ZONE`/`_SMALL_ZONE`**
  (aktuell 100/50) — die wurden nach einem echten Multiplayer-
  Verbindungsabsturz bei 1750 Gebäuden absichtlich zurückgenommen (siehe
  Kommentar dort). Eine engere Reihen-Packung bedeutet mehr VERFÜGBARE
  Slots pro Zone, aber dieselbe Anzahl TATSÄCHLICH gebauter Gebäude — der
  Füllgrad (gebaute/verfügbare Slots) sinkt dadurch eher, was der
  gewünschten Verdichtung entgegenwirken könnte. Eine Erhöhung der
  Gebäudezahl wäre eine separate, riskantere Entscheidung (braucht eigenen
  Multiplayer-Stresstest), bewusst nicht Teil dieser Änderung.

**Noch nicht vom Nutzer getestet.**

### Gebäude-Rotation (2026-08-04)

Nutzer-Screenshot `bilder/falsche ausrichtung.PNG`: der Supermarkt stand
mit erkennbar falscher Ausrichtung — Fenster/Tür zeigten nicht zur
Straße. Ursache: Gebäude bekamen bisher NIE eine `rotation.y`, dieselbe
Modell-Ausrichtung landete auf jeder der vier Blockkanten gleich, egal
wohin die Fassade eigentlich zeigen sollte. Beim Wohnhaus (eher
symmetrisch wirkende Form) war das kaum sichtbar, beim Supermarkt mit
klaren Fenstern fällt es sofort auf.

- **Rotation aus der Blender-Achsen-Konvention abgeleitet** (siehe
  `Infos/05 Assets im Spiel.md`, "Blender-Achsen-Konvention": Front zeigt
  unrotiert nach Godot -Z). `_generate_street_slots()` gibt jetzt pro Slot
  ein `"rotation_y"` mit: 0° (Süd-Kante, Straße liegt schon bei -Z) / 180°
  (Nord-Kante, Straße bei +Z) / +90° (West-Kante, Straße bei -X) / −90°
  (Ost-Kante, Straße bei +X).
- **`World._create_building()` setzt `building.rotation.y` auf dem
  BUILDING-NODE selbst**, nicht nur auf dem `Model`-Kind — dreht dadurch
  Mesh, Collision-Box UND das echte Modell gemeinsam. Wichtig: die
  Kollisionsbox dreht sich MIT, dadurch passt die Klickfläche/Kollision
  nach der Rotation weiterhin exakt zum sichtbaren Gebäude.
- **Vereinfachung als Nebeneffekt:** weil die Rotation die Fassade IMMER
  korrekt zur Straße ausrichtet, ist `size.x` ab jetzt IMMER die
  Entlang-der-Reihe-Achse und `size.z` IMMER die Senkrecht-zur-Reihe-Achse
  — unabhängig davon, ob die Reihe entlang X oder Z verläuft (`along_x`).
  Die Mehrfach-Reihenplätze-Berechnung (`along_row_size`) und der
  tiefenabhängige Straßenabstand (`perp_extent`) mussten dadurch NICHT
  mehr zwischen beiden Fällen unterscheiden — beide nutzen jetzt einfach
  `size.x`/`size.z` direkt, kein `if along_x else`-Zweig mehr nötig.
- **Gilt einheitlich für alle drei Erzeugungswege** (echtes Modell,
  prozedurales Haus, reine Platzhalter-Box) — bei der prozeduralen
  Box+Satteldach-Form gibt es keine gerichtete Fassade, die Rotation
  ändert dort nur, in welche Richtung der Dachfirst zeigt (eher
  Verbesserung als Risiko: First jetzt öfter parallel zur Straße statt
  immer gleich ausgerichtet). Bei der Platzhalter-Box ohne Modell ist
  Rotation optisch wirkungslos (einfarbige Box), aber harmlos.
- **Nicht betroffen:** Jagdstand (Wald-Zonen), Schutzsuchende, Ruinen —
  alle drei erzeugen ihre `_create_building()`-Aufrufe ohne
  `"rotation_y"`-Feld, `.get()`-Fallback bleibt `0.0` (kein Reihen-Konzept
  für diese drei, keine Rotation nötig).
- **Speicherstand-/Catch-up-fähig** wie Position — `_collect_save_data()`/
  `_load_game_state()`/`_catch_up_buildings_bulk()` führen `rotation.y`
  jetzt mit.
- **Voraussetzung für künftige Assets:** jedes neu gelieferte
  Gebäude-Modell muss mit der Front Richtung Blender -Y (= Godot -Z)
  modelliert sein, damit diese automatische Rotation korrekt greift —
  ist bereits die dokumentierte Standard-Konvention, keine neue Vorgabe.

**Noch nicht vom Nutzer getestet** — insbesondere die genaue
Rotationsrichtung (West/Ost könnten vertauscht sein, falls sich beim
Testen zeigt, dass die Fassade dort in die falsche Richtung zeigt; Fix
wäre dann nur, die beiden Vorzeichen in `_generate_street_slots()` zu
tauschen).

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

## Bildlook: Farbanpassung für den Apokalypse-Stil (2026-08-04)

Nutzerfrage: "können wir sowas wie Shader machen, das es bisschen mehr
diesen Apokalypsen-Style hat" — Godots eingebaute `Environment`-
`Adjustments` (kein eigener Shader-Code nötig, laufen intern selbst über
einen Shader, aber komplett über Properties einstellbar) auf der
bestehenden `Environment_day_night`-Resource in `World.tscn` aktiviert:
`adjustment_saturation := 0.55` (deutlich entsättigt), `adjustment_
contrast := 1.15`, `adjustment_brightness := 0.95` — wirkt global über
die ganze Szene, unabhängig von Tag/Nacht (`_update_day_night_visuals()`
ändert nur `background_color`/`ambient_light_color`/`-energy`, nie die
Adjustments, keine Kollision). Reine Startwerte, nach Testen
nachjustierbar.

**Weitere Ausbaustufen, falls mehr gewünscht ist** (bewusst noch nicht
umgesetzt, größerer Aufwand):
- **Leichter Nebel/Dunst** (`Environment.fog_*`) — billig, viel
  Atmosphäre, aber Vorsicht: zu dicht würde Zombie-Sichtbarkeit auf
  Distanz beeinträchtigen (Gameplay-relevant), deshalb nicht ungefragt
  aktiviert.
- **Eigener Grime-/Rost-Shader pro Material** (Verschmutzung in Ecken/
  Kanten, z. B. über Vertex-Colors oder eine Curvature-/AO-Maske) — mehr
  Wirkung, aber echter Custom-Shader- + Blender-Vorbereitungsaufwand
  (Vertex-Painting oder AO-Bake nötig).
- **Bildschirm-Postprocessing** (Vignette, Filmkörnung, leichte
  chromatische Aberration) — eigener Full-Screen-Shader auf einem
  `CanvasLayer`, moderater Aufwand, rein kosmetisch ohne Gameplay-Risiko.

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

## Pause (nur Host, 2026-08-04)

Nutzerwunsch (siehe `docs/mechanics-review.md`, "Zeitskala") — Möglichkeit,
die Zeit anzuhalten, um in Ruhe zu managen, ohne dass Nächte/Hordes
weiterlaufen.

- **`World._game_paused: bool`**, umgeschaltet über
  `request_toggle_pause()` (nur Peer-ID 1 = Host darf, gleiche
  Host-only-Prüfung wie `start_game()`), an alle Peers gespiegelt
  (`_sync_game_paused()`), weil `_handle_day_night()` lokal auf JEDEM
  Peer läuft (siehe oben) und sonst auseinanderliefe.
- **Button im Pause-Menü** (`PauseMenu.tscn`, `PauseGameButton`, nur für
  den Host sichtbar, gleiches Muster wie der Speichern-Button).
- **`HUD/PauseLabel`** zeigt bei JEDEM Peer sichtbar "PAUSIERT" an,
  solange pausiert ist.
- **Kein zentraler `process_mode`-Umbau über den Szenenbaum** — bewusst
  kleinerer, vorhersehbarerer Eingriff: `World._process()` gated seinen
  eigenen host-only-Simulationsblock UND `_handle_day_night()` mit
  `_game_paused`; jedes Entity-Script mit eigenem `_process()`
  (`Zombie`/`Survivor`/`Building`/`GuardPost`/`ZombieNest`/`Vehicle`/
  `Field`) fragt `get_tree().current_scene.is_paused()` selbst am
  Anfang seines eigenen `_process()` ab. Kamera/UI (`_handle_pan()`,
  `_update_hud()` etc.) bleiben während der Pause bewusst aktiv.
- Noch nicht vom Nutzer getestet.

## Zeitraffer (nur Host, 2026-08-04)

Nutzerwunsch nach der Infection-Free-Zone-Recherche (siehe
`Infos/06 Infection Free Zone Recherche.md`, "Kritikpunkte ernst nehmen":
IFZ-Reviews nennen spürbar zu langsames Tempo ohne Zeitraffer als
Schwäche) — 1x/2x/3x-Buttons statt eines eigenen Zeitraffer-Systems.

- **Nutzt `Engine.time_scale` direkt** statt eines eigenen, manuell
  durchgereichten Multiplikators wie beim Pause-Flag oben — skaliert
  automatisch JEDEN `delta`-Wert im ganzen Spiel (Tag/Nacht, Zombie-KI,
  Bautrupp-Timer, Ressourcen-Nachwachsen, ...), keine einzelne Stelle
  musste dafür angefasst werden. Deutlich kleinerer Eingriff als die
  Pause-Lösung, gerade WEIL hier (anders als bei Pause) wirklich ALLES
  gleichmäßig mitskalieren soll, nicht nur bestimmte host-only-Blöcke.
- **`World._time_scale: float`**, gesetzt über `request_set_time_scale()`
  (nur Peer-ID 1 = Host darf, gleiche Prüfung wie bei Pause), an alle
  Peers gespiegelt (`_sync_time_scale()`) — jeder Peer setzt sein eigenes
  `Engine.time_scale` lokal, sonst liefe z. B. der lokal auf jedem Peer
  laufende Tag/Nacht-Zyklus bei Host und Client unterschiedlich schnell
  auseinander (gleiches Muster/gleicher Grund wie bei Pause).
- **`ResourcesUI/Panel/VBoxContainer/SpeedRow`** — drei Toggle-Buttons
  (1x/2x/3x) direkt über der Uhr, nur für den Host sichtbar
  (`speed_row.visible = multiplayer.is_server()`, gleiches Muster wie
  `PauseGameButton`). `_update_speed_buttons()` zeigt die aktive Stufe
  gedrückt.
- **`World._exit_tree()` setzt `Engine.time_scale` zurück auf 1.0** —
  wichtig, weil das eine GLOBALE Engine-Eigenschaft ist, kein
  Szenen-lokaler Zustand: ohne Reset bliebe ein Zeitraffer-Wert über das
  Verlassen von `World.tscn` hinaus aktiv (Game Over, Hauptmenü,
  Trennung) und würde z. B. das Hauptmenü unbeabsichtigt beschleunigt
  darstellen.
- Kombiniert sich mit Pause unverändert richtig: Pause prüft weiterhin
  nur `_game_paused` (gated einzelne host-only-Blöcke/Entity-`_process()`),
  Zeitraffer skaliert `delta` unabhängig davon — beide zusammen aktiv
  heißt "pausiert bei eingestellter Geschwindigkeit", genau wie erwartet.
- Noch nicht vom Nutzer getestet.

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

### UI-Überarbeitung Runde 2 (2026-08-04, Punkt 29 der Gesamtliste)

Nutzer schickte ein Referenz-Screenshot aus "Infection Free Zone"
(`bilder/ui.PNG`) mit dem Hinweis, sich daran zu orientieren, aber
"vielleicht paar stats vertauschen ... damit es nicht wie eine Kopie
aussieht" — explizit als reine Struktur-/Richtungsvorlage gemeint, nicht
zum 1:1-Nachbauen (das Referenzspiel hat fertige Icon-Assets, wir haben
weiterhin 0% eigene Assets). Auf Nachfrage "mach erstmal wie du meinst,
wir müssen später eh hin und her wechseln, nur damit man eine Richtung
bekommt" — als erster Wurf ohne Anspruch auf Feinschliff umgesetzt,
weitere Iteration ausdrücklich erwartet:

- **Ressourcen-Panel: Zwei-Tabs-Aufteilung wieder entfernt, dafür
  kompakte Einzeiler.** Die Referenz zeigt alle Ressourcen gleichzeitig in
  einer knappen Zeile statt tab-umschaltbar — `_update_resources_label()`
  baut pro Kategorie jetzt EINE Zeile (`"Kategoriename: Wert1, Wert2, ..."`)
  statt vorher mehrzeilig (ein Eintrag pro Ressource). `ResourcesUI/Panel`
  dabei ohne `TabContainer`, alle vier Kategorien direkt untereinander im
  `VBoxContainer` — spürbar kompakter als der alte mehrzeilige Block trotz
  Tab-Wegfall. **Bleibt oben RECHTS** (siehe Korrektur unten).
- **Auswahl-/Status-Anzeige (`HUD/Label`+`HUD/StatusLabel`) bekommt
  erstmals einen Panel-Hintergrund** (`HUD/InfoPanel`, analog zur
  Quest-Tracker-Karte im Referenzbild) statt nur freistehendem Text mit
  Kontur — Position unverändert oben links.
- **`MainTabsUI`-Panel (Bauen/Herstellen/Einheiten/Handel/Trupp) vergrößert**
  (Breite 360→404px, Höhe moderat erhöht, siehe Korrektur unten) —
  Auslöser: Nutzer-Feedback direkt nach dem ersten Baustellen-Test ("bau
  menü ist nicht so sichtbar"), die feste Panel-Höhe wurde mit Bau-Buttons +
  Ausbauen-Abschnitt + Wachposten-Liste + der neuen Baustellen-Liste zu
  eng. Bewusst nur eine größere feste Höhe statt eines echten
  `ScrollContainer`-Umbaus (kleinerer Eingriff für einen ersten Wurf) —
  reicht laut Überschlagsrechnung (siehe Korrektur unten) vermutlich
  weiterhin NICHT für den kompletten Fixinhalt plus variable Listen, ein
  `ScrollContainer` bleibt die eigentlich saubere Lösung für eine
  spätere Iteration.
- Minimap unten rechts unverändert.

**Korrektur nach erstem Screenshot-Test (2026-08-04, `bilder/ui 1.PNG`):**
Nutzer-Feedback "irgendwie schaut das nicht so wie gewünscht aus" — der
ursprüngliche erste Wurf hatte die Ressourcen-Leiste tatsächlich nach oben
LINKS verschoben (bewusst seitenverkehrt zur Referenz) UND das
`MainTabsUI`-Panel auf 620px Höhe gebracht. Das ging schief, weil die
UI-Koordinaten NICHT in der tatsächlichen Fensterauflösung laufen,
sondern im projektweiten Basis-Viewport (`window/stretch/mode=
"canvas_items"`, kein explizites `window/size/viewport_height` gesetzt →
Godot-Standard 648px) — bei nur 648 Gesamthöhe nahm das 620px hohe
Bauen-Panel fast den ganzen Bildschirm ein und überlappte dadurch massiv
mit dem neu positionierten Ressourcen-Panel UND der Status-Karte, beide
ebenfalls oben links. Ergebnis im Screenshot: Ressourcen-Text und
Bau-Buttons lagen sichtbar übereinander.

### UI-Redesign Runde 3: obere Leiste + Wetter + Forschung + Event-Log (2026-08-04)

Nutzer-Skizze (`bilder/ui skizze.jpg`), nach Rückfragen geklärt (Plan
`floating-shimmying-stonebraker.md`): Kalender/Zeit-Steuerung + 9 Tabs
wandern in eine neue obere Leiste, dazu drei komplett neue Tabs
(Wettervorhersage, Forschung, Infos/Event) + eine kompakte Info-Box.

- **`MainTabsUI/Panel` jetzt oben statt unten links verankert**
  (`anchor_top=0`, volle Breite). Neuer `TimeBox`-`VBoxContainer` links
  daneben (NICHT als eigener Node vor dem `TabContainer` verschachtelt,
  sondern als GESCHWISTER-Control innerhalb desselben `Panel` — dadurch
  bleiben ALLE bestehenden `$MainTabsUI/Panel/TabContainer/<Tab>/...`-
  Pfade unverändert, kein Massen-Umschreiben der Dutzenden `@onready
  var`s für Bauen/Herstellen/Einheiten/Trupp/Handel nötig).
  `TimeBox` enthält `DayLabel` (neu, zeigt `_day_count`), `ClockLabel` +
  `SpeedRow` (aus `ResourcesUI` hierher verschoben) + neuer
  `PauseButton` (ruft dieselbe `request_toggle_pause`-RPC wie
  `PauseMenu.pause_game_button`, gleiches host-only-Sichtbarkeitsmuster).
- **648px-Basishöhen-Falle erneut zugeschlagen** (siehe oben, "Korrektur
  nach erstem Screenshot-Test") — der erste Wurf hätte die alte 454px-
  Panelhöhe einfach nach oben verschoben, das hätte sich mit dem
  darunter jetzt ebenfalls neu positionierten `ResourcesUI`-Panel UND der
  bodenverankerten Minimap (`-208` bis `-16` = absolut 440–632 bei 648px
  Basishöhe) überlappt. Fix: `MainTabsUI/Panel`-Höhe auf 152px reduziert
  (`offset_top` 8→160), `ResourcesUI/Panel` folgt direkt darunter
  (168→420) — endet mit 20px Abstand klar vor der Minimap.
  **Bekannter Nachteil dieser Lösung:** die Tab-Inhalte (v. a. "Bauen"
  mit ~15 Buttons/Listen) passen bei 152px sichtbar NICHT mehr vollständig
  hinein — bestehendes, schon vorher dokumentiertes Risiko (siehe "UI-
  Überarbeitung Runde 2" oben, "ein `ScrollContainer` bleibt die
  eigentlich saubere Lösung"), durch die geringere Höhe jetzt akuter.
  Kein `ScrollContainer`-Umbau in dieser Runde (hätte dieselben vielen
  `@onready var`-Pfade durch eine zusätzliche Verschachtelungsebene
  gebrochen) — bewusst zurückgestellt, nächster sinnvoller Schritt.
- **Neue Tabs** (Node-Namen bewusst kurz statt der längeren
  Skizzen-Beschriftung, passend zum bestehenden Stil): `Wetter`,
  `Forschung`, `Karte` (nur ein "Karte öffnen"-Button →
  `toggle_map_view()`, kein zweiter echter Kartenweg), `Ereignisse`.
  Reihenfolge über `main_tabs.move_child()` in `_ready()` hergestellt
  (Wetter, Forschung, Herstellen, Bauen, Einheiten, Trupp, Karte,
  Ereignisse, Handel) — ändert nur die Anzeige-Reihenfolge, keine Pfade.
  `main_tabs.current_tab` danach explizit auf den Bauen-Tab gesetzt
  (`move_child()` verschiebt Kinder, nicht automatisch den angezeigten
  Index mit — ohne den Fix wäre "Wetter" der neue Default-Tab gewesen).
- **Forschungs-Tab**: rein lesende Übersicht über `CRAFTING_RECIPES` +
  `BUILDING_RESEARCH` (Erforscht-Status aus `HomeBase.unlocked_recipes`),
  kein eigener Erforschen-Button — die bestehenden Buttons in Herstellen/
  Bauen bleiben die einzigen Auslöser. `_refresh_research_ui()` läuft im
  selben periodischen Block wie `_refresh_crafting_ui()`.
- **Wettervorhersage-Tab + echtes neues Gameplay-System**:
  `_weather`/`_next_weather` (State:
  "clear"/"rain"), zufällig alle `WEATHER_MIN_DURATION`–
  `WEATHER_MAX_DURATION` Sekunden neu gewürfelt (host-seitig, per
  `_sync_weather.rpc()` gebroadcastet, gleiches Muster wie
  `_sync_time_scale()`). **Effekt:** Regen multipliziert JEDEN Fog-of-War-
  Aufdeckungsradius (Einheiten/Home-Base/Wachturm) mit
  `WEATHER_VISION_MULTIPLIER := 0.6`, einziger Eingriffspunkt in
  `_update_fog_of_war()`. Catch-up (`_catch_up_weather()`, nach dem
  `_catch_up_day_time()`-Muster) + Speicherstand-Persistenz
  (`data["weather"]`/`data["next_weather"]`/`data["weather_timer"]`).
- **Infos/Event-Tab + Info-Box**: neues `_event_log: Array` (lokal je
  Peer, nicht repliziert/gespeichert — kurzlebiger Sitzungs-Verlauf wie
  `_trade_offers`), gefüllt über einen einzigen Hook in
  `_show_status_message()` — erfasst dadurch AUTOMATISCH jede
  bestehende Meldung (Horde/Blutmond, SOS, Home-Base verloren, Rettungs-
  Anfrage, Handel, Baufehler etc.), ohne jeden `report_status()`-
  Aufrufer einzeln anzufassen. Info-Box (`InfoBoxUI`, eigene
  `CanvasLayer`, bodenverankert direkt über der Minimap) zeigt immer nur
  die letzte Zeile.
- **Neu: "Blutmond nähert sich"-Vorwarnung** (im Sketch explizit
  genannt, gab es vorher nicht) — `_handle_day_night()` prüft jetzt
  zusätzlich, ob `is_blood_moon_night()` UND noch Tag (nicht `is_night()`)
  UND `current_game_hour() >= NIGHT_START_HOUR - 2.0`, warnt dann einmalig
  pro Tag (`_blood_moon_warned_day`-Gate) alle Peers — läuft automatisch
  ins Event-Log/die Info-Box mit, weil es denselben `report_status()`-Weg
  nutzt wie alles andere.

**Noch nicht vom Nutzer im Spiel gesichtet — bei der Größe dieser
Änderung (fast jedes UI-Element betroffen) besonders wahrscheinlich,
dass mindestens die Panelhöhen/Tab-Inhalt-Sichtbarkeit noch eine
Nachjustierungsrunde braucht.**

Behoben: Ressourcen-Panel bleibt (Fehler eingesehen) doch oben RECHTS wie
ursprünglich — dort gibt es reichlich freien Platz, keine Konkurrenz mit
dem links verankerten Bauen-Panel. Status-Karte bleibt ebenfalls an ihrer
ursprünglichen Position oben links (8–166px). `MainTabsUI`-Panel-Höhe auf
einen Wert reduziert, der innerhalb der 648px-Basishöhe tatsächlich Platz
lässt: `offset_top` -420→-470 (statt -620), Höhe damit 404→454px (moderate
+50px statt der zu aggressiven +200px), oberer Rand bei y≈178, mit 12px
Abstand zur Status-Karte darüber (endet bei y≈166) — kein Überlappen mehr,
aber auch nur ein kleiner tatsächlicher Zugewinn an Platz für die
Baustellen-Liste. **Lektion:** UI-Anker-Offsets in diesem Projekt IMMER
gegen die 648px-Basishöhe rechnen, nicht gegen die tatsächliche
Fensterauflösung.

**Noch nicht vom Nutzer erneut getestet** — Korrektur behebt das gemeldete
Überlappen, ob die Baustellen-Liste jetzt tatsächlich ausreichend sichtbar
ist, bleibt zu prüfen (siehe Hinweis zum `ScrollContainer` oben, falls
nicht).

**Zweite Korrektur, gleicher Test (2026-08-04):** "wird besser aber zu
viel ressourcen am besten nur die bau materialien das mit waffen bücher
etc. soll dann in ein unter tab" — die vier Kategorien liefen nach der
ersten Korrektur wieder alle gleichzeitig sichtbar (kein Tab-Wegfall
rückgängig gemacht). Jetzt: **Baurohstoffe (Index 0) bleiben dauerhaft
sichtbar** direkt im `VBoxContainer` (kein Klick nötig, das ist die
alltäglich relevante Ressource fürs Bauen), die anderen drei Kategorien
(Überleben/Ausrüstung/Forschungsbücher) sitzen jetzt in einem kleinen
`TabContainer` darunter (`custom_minimum_size` 56px hoch, drei Tabs, nur
einer gleichzeitig sichtbar). `World.resource_category_labels` (Array,
Reihenfolge weiterhin passend zu `RESOURCE_CATEGORIES`) zeigt für Index
1-3 jetzt in die `TabContainer`-Unterordner, Index 0 bleibt direkt im
`VBoxContainer` — `_update_resources_label()` selbst unverändert, reine
Pfad-Änderung. Panel dabei verkleinert (`offset_bottom` 164→148,
`VBoxContainer`-Breite etwas schmaler) — durch den Tab-Wegfall für drei
von vier Kategorien wird wieder weniger Höhe gebraucht.

**Noch nicht vom Nutzer getestet.**

**Dritte Korrektur, gleicher Test (2026-08-04):** "wird besser die
schrifft geht aber aus dem bildschirm raus" — die einzeilige
Kategorie-Zeile (z. B. "Baurohstoffe: Holz 40/500, Metall 12/500, Stein
20/500, Ziegel 10/500") war bei 4-5 Einträgen pro Kategorie schlicht
breiter als die verfügbare Panel-Breite (376px); `Label` hat standardmäßig
KEINEN Zeilenumbruch, lief also seitlich über den Bildschirmrand hinaus
statt umzubrechen. Zwei Korrekturen zusammen:

- **`_update_resources_label()`:** Kapazität wird nicht mehr PRO Ressource
  wiederholt (`"Holz 40/500"` → `"Holz 40"`), sondern einmal am
  Zeilenende (`"... (je max 500)"`) — deutlich kürzere Zeilen, Kapazität
  ist ohnehin für alle Ressourcen identisch.
- **`autowrap_mode = 3`** (word-smart) auf allen vier Kategorie-Labels als
  Absicherung, falls eine Zeile trotzdem noch zu lang ist (v. a.
  "Forschungsbücher" mit fünf langen Buchnamen) — bricht dann sauber auf
  mehrere Zeilen um statt seitlich rauszulaufen. `TabContainer`
  (`custom_minimum_size`) und Panel entsprechend höher (56→140px bzw.
  148→260px Gesamthöhe), damit umgebrochene mehrzeilige Texte nicht
  ihrerseits unten abgeschnitten werden.

**Vom Nutzer bestätigt (2026-08-04):** "deutlich besser als vorher" —
Ressourcen-Panel-Umbau (Runde 2 + alle drei Korrekturen) damit
abgeschlossen. Restliches Feedback zu Punkt 29 (falls die
Baustellen-Liste im `MainTabsUI`-Panel trotz der moderaten
Höhenerhöhung noch zu eng ist) weiterhin offen, siehe "ScrollContainer"-
Hinweis weiter oben.

**Vierte Korrektur — `HUD/InfoPanel` (2026-08-04):** Nutzer bemerkte
danach "was ist links oben im eck für eine schwarze box", dann "nur ne
leere schwarze box, kein text drauf" — der bei der ersten Korrektur
hinzugefügte Panel-Hintergrund hinter `HUD/Label`/`HUD/StatusLabel` war
DAUERHAFT sichtbar, obwohl `hud_label` seit dem HUD-Aufräumen vom
2026-08-03 ("das mit trupp 1 hp 100 kann weg", siehe `_update_hud()`) die
meiste Zeit komplett LEER ist (nur "F: Aussteigen" beim Fahrzeug, sonst
nichts) — vorher (ohne Panel-Hintergrund) fiel das nie auf, weil leerer
Text einfach unsichtbar war, jetzt aber sehr wohl der leere schwarze
Kasten dahinter. Behoben: `hud_info_panel.visible` folgt jetzt, ob
tatsächlich Inhalt da ist (`not lines.is_empty() or status_label.visible`
in `_update_hud()`, zusätzlich beim Ablaufen einer Statusmeldung im
`_process()`-Timer-Block aktualisiert) — Panel taucht nur noch auf, wenn
wirklich Text/eine Statusmeldung angezeigt wird, `visible = false` auch
als `.tscn`-Startwert.

**Vom Nutzer bestätigt (2026-08-04):** "passt ist weg". Punkt 29
(UI-Überarbeitung Runde 2) damit inklusive aller vier Korrekturrunden
abgeschlossen.

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
- **Wachturm-Sichtbonus (2026-08-03, Punkt 25 der Gesamtliste):**
  `_reveal_around()` hat seit dem einen optionalen `radius`-Parameter
  (Standard weiterhin `FOG_VISION_RADIUS`) — `_update_fog_of_war()` ruft
  ihn zusätzlich für jeden `"watchtower"` mit `WATCHTOWER_VISION_RADIUS :=
  350.0` auf, deutlich mehr als die 130 für Einheiten/Home-Base. Details
  in [`building.md`](building.md), "Echter Wachturm".
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

**2026-08-03 nachjustiert** (Nutzerwunsch: "kamera wie sie rausgezoomt
ist auf standard machen und bisschen mehr rauszoomen"): `ZOOM_MAX` von
`60.0` auf `80.0` angehoben, `_zoom_distance`-Startwert von `12.0` auf
`25.0` — vorher startete jede Partie fast komplett reingezoomt (knapp
über dem damaligen `ZOOM_MIN`), jetzt näher an der Mitte des jetzt auch
größeren Bereichs (10-80) für einen brauchbareren Überblick direkt beim
Start.

**2026-08-04 nochmal nachjustiert**, wieder nach Vergleich mit einem
echten Infection Free Zone-Screenshot (dort immer viele Gebäude
gleichzeitig im Bild): `_zoom_distance`-Startwert von `25.0` auf `40.0`
— Anlass war das erste echte Gebäude-Asset (Wohnhaus, 9m breit statt der
bisherigen 2-4m-Platzhalter, siehe `docs/building.md`), das beim alten
Standard-Zoom fast den ganzen Bildschirm füllte. Bewusst eine
Kamera-Anpassung statt das Gebäude kleiner zu skalieren (9×8m entspricht
dem ursprünglichen Checkliste-Zielwert) — `ZOOM_MAX` (80) unverändert.

**Direkt im Anschluss außerdem `ZOOM_MIN` von `10.0` auf `20.0`
angehoben** (Nutzerfeedback nach dem Standard-Zoom-Test: "kann zu viel
reinzoomen") — beim alten `ZOOM_MIN` kam die Kamera nah genug heran, um
nur noch einen Wand-Ausschnitt des jetzt 9m breiten Wohnhauses zu sehen
statt des ganzen Gebäudes. Gleiches Muster wie die 2026-08-01-Anhebung
oben (4→10): das Minimum wächst mit, sobald die tatsächlichen
Asset-Größen zeigen, dass die Kamera näher rankommt als gewollt.

**Noch am selben Tag ein weiteres Mal leicht nachjustiert**, `20.0` →
`26.0` ("reinzoom bisschen weiter raus, kann bisschen zu nah zoomen") —
`20.0` war als erster Schritt in die richtige Richtung, aber noch nicht
genug. Grundlegender Standard-Zoom (40.0)/`ZOOM_MAX` (80.0) unverändert,
nur das Minimum nochmal etwas näher an den Standard-Zoom herangerückt.

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

**Grundmodell vom Nutzer bestätigt** ("passt das Grundmodel"). Der Backlog-
Wunsch "später sollten wir das schöner machen" ist mit der Loot-Kategorie-
Farbcodierung + Legende (siehe unten) teilweise umgesetzt — Layout/
Beschriftung bleiben weiterhin offen für spätere Politur.

## Kartenansicht zoombar (2026-08-03)

Nutzerwunsch: "die eine idee mit map reinzoomen das kann man jetzt
machen wichtig alles muss mit controller stuerbar sein" — vorher zeigte
`MapView.gd` immer zwingend die komplette Karte (`_to_map()` skalierte
`MAP_SIZE` fix auf die Panelgröße), kein Rein-/Rauszoomen möglich.

- **`_zoom_level`** (1.0 = ganze Karte, bis `MAP_ZOOM_MAX := 8.0`) +
  **`_view_center`** (Welt-X/Z, das in der Panelmitte liegt) ersetzen die
  bisherige feste Skalierung — `_to_map()`/neue `_from_map()` (Umkehrung)
  rechnen jetzt beide relativ zu diesen beiden Werten statt fix zur ganzen
  Karte.
- **`MapView.reset_view(world_center)`** — von `World.toggle_map_view()`
  beim ÖFFNEN aufgerufen, setzt Zoom auf 1.0 zurück UND zentriert auf die
  aktuelle 3D-Kameraposition (`pivot.position`) statt auf den
  Kartenmittelpunkt — jede Sitzung mit der Karte startet vorhersehbar bei
  voller Übersicht, zentriert dort, wo man gerade ist.
- **Drei Bedienelemente in `_gui_input()`:** Linksklick reist weiterhin
  hin + schließt (unverändert). NEU: Rechtsklick verschiebt nur den
  Kartenausschnitt (`_view_center`), OHNE die 3D-Kamera zu bewegen oder
  die Karte zu schließen — sonst könnte man beim Reingezoomt-Sein gar
  nicht navigieren. Mausrad zoomt (`zoom_in()`/`zoom_out()`, multiplikativ
  wie der 3D-Kamera-Zoom).
- **`clip_contents = true`** auf dem `MapView`-Control (siehe
  `MapView.tscn`) — nötig, weil `_to_map()` beim Reingezoomt-Sein nicht
  mehr auf die Panelgröße clamped (das würde beim Zoomen falsch aussehen,
  Symbole würden an den Rand "kleben" statt zu verschwinden); Godot
  schneidet die Zeichenausgabe jetzt stattdessen sauber am Panel-Rand ab.
- **Kompletter Controller-Support (explizite Nutzer-Vorgabe):** Linksklick/
  Rechtsklick laufen automatisch über den globalen virtuellen Cursor
  (`GamepadCursor.gd`, A/B synthetisieren echte Klicks) — kein
  Zusatzcode nötig. Einzige Ergänzung: `World._handle_gamepad_input()`
  leitet LB/RB auf `map_view.zoom_in()`/`zoom_out()` um, SOLANGE die
  Kartenansicht offen ist (`map_view_ui.visible`), sonst zoomen sie wie
  gewohnt die 3D-Kamera — kontextabhängige Doppelbelegung derselben zwei
  Tasten.

**Noch nicht vom Nutzer getestet.**

## Gebäude-Farbcode nach Loot-Kategorie + Legende (2026-08-03)

Nutzerwunsch: "färbe die gebäude typen ein zu den jeweiligen lootarten,
krankenhaus heilung grün etc." — vorher zeigten unbesetzte Gebäude auf der
Karte alle dieselbe neutrale graue Farbe (`UNCLAIMED_BUILDING_COLOR`),
obwohl die 14 Gebäudetypen (siehe `docs/scavenging.md`) inzwischen sehr
unterschiedlichen Loot liefern.

- **`World.LOOT_CATEGORY_BY_RESOURCE`** ordnet jede `main_loot.resource`
  (siehe `BUILDING_TYPES`) einer von vier Kategorien zu: `food` (Nahrung),
  `medicine` (Medizin), `equipment` (Waffen/Rüstung/Munition/Nahkampfwaffe/
  Beinschutz), `books` (Forschungsbücher). Bewusst aus `main_loot`
  ABGELEITET statt einem redundanten Extra-Feld pro `BUILDING_TYPES`-
  Eintrag — eine Quelle der Wahrheit.
- **`Building.loot_category: String`** — einmalig beim Spawn gesetzt
  (`_loot_category_for_template()`), läuft über dieselben optionalen
  Catch-up-/Speicherstand-Zusatzfelder wie `is_looted`/`owner_peer_id`/
  `hp`/`has_bandit_loot`.
- **`MapView.LOOT_CATEGORY_COLORS`** (Nahrung orange, Medizin grün —
  genau wie vom Nutzer vorgegeben, Ausrüstung rot, Bücher lila) —
  `_draw_buildings()` nutzt das jetzt als NEUTRALFARBE für unbesetzte
  Gebäude statt des generischen Grautons. Sobald ein Gebäude geclaimt ist,
  hat weiterhin die Besitzer-Farbe (eigen/verbündet) Vorrang — an dem
  Punkt ist "wem gehört das" die wichtigere Information als der Typ.
- **`MapView._draw_legend()`** — neues, festes Panel oben links (nur in
  der großen Kartenansicht, NICHT auf der Minimap — zu wenig Platz dort)
  mit vier Farbfeldern + Beschriftung sowie einer fünften Zeile für den
  gelben "Loot verfügbar"-Rahmen. Reiner `draw_rect()`/`draw_string()`-
  Ansatz mit dem Theme-Standardfont, kein neuer `.tscn`-Node nötig.
- **Bewusst NICHT auf der Minimap** — die ist zu klein für eine sinnvolle
  Legende und dient eher der groben Orientierung, nicht der detaillierten
  Gebäude-Typ-Erkennung (dafür gibt's ja die große Kartenansicht).

**Noch nicht vom Nutzer getestet.**

## Gamepad-Steuerung (2026-08-03, Nutzerwunsch: Controller/Steam-Deck-Support)

Nutzerwunsch: "controller und steamdeck support wäre ganz net dann könnte
mein andere freund auch testen der hat ein rog alloy" — volle
Gamepad-Steuerung gewählt (Alternative wäre nur Touch-Emulation auf dem
Handheld-Bildschirm gewesen, siehe Rückfrage im Chat). Komplett additiv.

> [!warning] Zwei Bugfixes direkt nach dem ersten echten Test (2026-08-03,
> Nutzer-Report mit Screenshot + PS5-Controller)
> 1. **Parser-Fehler, Spiel startete gar nicht erst:** `var viewport_size :=
>    get_viewport().size` — bekannte GDScript-Variant-Inferenz-Falle (siehe
>    `docs/ARCHITECTURE.md`), `get_viewport().size` lässt sich nicht auf
>    einen festen Typ inferieren. Fix: explizit `Vector2i` typisiert statt
>    `:=`.
> 2. **"Konnte den Controller im Hauptmenü nicht benutzen"** — die
>    ursprüngliche erste Fassung lebte komplett in `World.gd`, funktionierte
>    also erst, NACHDEM man `World.tscn` schon erreicht hatte. Ohne Maus/
>    Tastatur kam man aber nie dorthin (MainMenu/Lobby hatten kein
>    Gamepad-Handling). **Fix: Cursor-Bewegung + A/B-Klicks in ein neues
>    Autoload `autoloads/GamepadCursor.gd` ausgelagert** (in
>    `project.godot` registriert) — läuft dadurch dauerhaft unter `/root`,
>    unabhängig vom Szenenwechsel, MainMenu/Lobby/World funktionieren jetzt
>    alle automatisch mit. `World.gd` behält nur noch den wirklich
>    weltspezifischen Teil (Kamera-Pan/-Rotation/-Zoom, Pause/Kartenansicht/
>    Fahrzeug-Ausstieg) und steuert `GamepadCursor.cursor_suspended`, damit
>    sich Kamera-Rotation (linker Trigger gehalten) und Cursor-Bewegung
>    nicht um denselben rechten Stick streiten. `GamepadCursor._process()`
>    setzt `cursor_suspended` jedes Frame zuerst auf `false` zurück, BEVOR
>    `World._handle_gamepad_input()` (läuft laut Baum-Reihenfolge danach)
>    es bei Bedarf wieder auf `true` setzt — verhindert, dass der Wert
>    "hängen bleibt", falls `World.tscn` ausgerechnet bei gehaltenem
>    Trigger verlassen wird (z. B. übers Pause-Menü zurück ins Hauptmenü).
> PS5-Controller (DualSense) funktioniert dabei ohne Sonderfall — Godots
> `JOY_BUTTON_A`/`_B`/etc.-Konstanten sind Xbox-Layout-benannt, meinen aber
> bei jedem Controllertyp die jeweils layoutgleiche physische Taste
> (Cross=A, Circle=B, ...), keine Plattform-spezifische Anpassung nötig.

- **Kern-Trick: virtueller Cursor = echter Fenster-Mauszeiger.** Statt RTS-
  Klickauswahl/Bau-UI/Tabs komplett für Gamepad-Navigation neu zu bauen
  (Risiko: doppelte Logik, die auseinanderlaufen kann), bewegt der rechte
  Stick über `Input.warp_mouse()` den TATSÄCHLICHEN Mauszeiger, A/B
  synthetisieren über `Input.parse_input_event()` echte
  `InputEventMouseButton`-Klicks an der aktuellen Cursor-Position. Dadurch
  reagieren ALLE bestehenden mausbasierten Systeme unverändert: MainMenu-/
  Lobby-Buttons, Welt-Klick-Auswahl (`_select_at()`), Mauer-Ziehen
  (Klicken+Halten+Ziehen), jeder UI-Button/Tab (Bauen/Herstellen/Einheiten/
  Trupp/Handel), sogar der Klick-zum-Hinreisen in der Kartenansicht
  (`MapView._gui_input()`) — ganz ohne eigene Gamepad-Menünavigation.
  **Lebt als Autoload `GamepadCursor.gd`** (siehe Bugfix-Kasten oben), nicht
  in `World.gd` — nur dadurch funktioniert es schon im Hauptmenü.
- **Tastenbelegung** (Xbox-Layout, passt auf ROG Ally/Steam Deck/normale
  Controller):
  - Linker Stick → Kamera-Pan (additiv in `_handle_pan()`, WASD bleibt
    unverändert funktionsfähig).
  - Rechter Stick → virtueller Cursor (Standard).
  - Linker Trigger GEHALTEN + rechter Stick → Kamera-Rotation/-Neigung
    (Analogon zum gehaltenen Rechtsklick+Ziehen bei Maus; direkte
    `pivot.rotate_y()`/`_tilt_angle`-Manipulation, keine synthetischen
    Events nötig).
  - A → Linksklick (Auswahl/Bauen/Mauer-Ziehen-Start, press+release wie
    ein echter Klick — Halten reproduziert also auch das Mauer-Ziehen).
  - B → Rechtsklick-Tap (stoppt ausgewählte Einheiten, über denselben
    Klick-vs.-Ziehen-Unterscheidungscode wie bei der Maus).
  - LB/RB → Zoom rein/raus (diskrete Schritte, wiederholt alle
    `GAMEPAD_ZOOM_REPEAT_INTERVAL` beim Halten, wie Mausrad-Ticks).
  - Start → Pause-Menü (`ESC`-Äquivalent).
  - Back/View → Kartenansicht (`M`-Äquivalent).
  - Y → Aus Fahrzeug aussteigen (`F`-Äquivalent).
- **Strikt additiv, kein Regressionsrisiko für Maus/Tastatur:** sowohl
  `GamepadCursor._process()` als auch `World._handle_gamepad_input()`
  brechen sofort ab, wenn `Input.get_connected_joypads()` leer ist — ohne
  angeschlossenes Gamepad läuft exakt derselbe Code wie vorher, kein
  einziger bestehender Pfad wurde verändert oder umgeleitet.
- **Button-"gerade gedrückt"/"gerade losgelassen"-Erkennung** über ein
  Vorframe-Vergleichs-Dictionary (`GamepadCursor._button_state` für A/B,
  `World._gamepad_button_state` für Start/Back/Y, gleiches Prinzip in
  beiden) — `Input.is_joy_button_pressed()` allein ist Level-getriggert,
  ohne InputMap-Action gibt es kein eingebautes "just pressed".
- **Bewusst NICHT umgesetzt: Kontrollgruppen (1-9) per Gamepad** — ein
  Standard-Controller hat keine zehn frei belegbaren Tasten dafür, eine
  D-Pad/Face-Button-Kombination wäre für den Nutzen unverhältnismäßig
  komplex geworden. Mit angeschlossener Tastatur (bei einem Windows-
  Handheld wie ROG Ally jederzeit möglich, z. B. per Bluetooth) weiterhin
  normal nutzbar.
- **Bekannte Einschränkung:** hält man B (Rechtsklick-Tap) UND bewegt
  gleichzeitig den rechten Stick OHNE den linken Trigger zu halten, kann
  kurzzeitig ungewollt die Kamera rotieren (das synthetische Rechtsklick-
  Event setzt `_rotating = true`, solange B gehalten wird, und der dann
  ebenfalls dispatchte Cursor-Bewegungs-Event trifft auf den bestehenden
  Rechtsklick-Dreh-Zweig in `_unhandled_input()`) — seltener Randfall
  (ungewöhnliche Eingabe-Kombination), behebt sich sofort beim Loslassen
  von B, nicht extra abgefangen.

**Noch nicht vom Nutzer getestet** (insbesondere nicht auf echter
Handheld-Hardware — Design/Code basiert auf Godots Standard-Gamepad-API,
kein Steam-spezifischer Input, sollte auf ROG Ally/Steam Deck/jedem
Xbox-artigen Controller gleich funktionieren).

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
