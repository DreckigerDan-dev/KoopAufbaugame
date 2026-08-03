# Fahrzeuge

Erklärt `scenes/entities/vehicle/Vehicle.gd`. Seit dem Kartenumbau (siehe
`docs/world.md`) über `vehicle_spawner`/`World._create_vehicle()`
erzeugt, zwei Instanzen pro Stadt-Zone (`VEHICLES_PER_ZONE := 2`) —
ursprünglich zwei feste `.tscn`-Kind-Nodes ohne `MultiplayerSpawner` für
die ganze Karte. Ein Trupp muss erst hinlaufen und einsteigen, danach
fährt es sich wie ein schnellerer, lauterer Trupp. Kein eigener Angriff,
reiner Transport (Nutzerentscheidung). Einstiegsseite in
[`docs/survivor.md`](survivor.md), Zombie-Zielwahl in
[`docs/zombies.md`](zombies.md).

## Differenzierte Fahrzeugtypen (2026-08-03, Punkt 19 der Gesamtliste)

Vorher ein einziger Fahrzeugtyp mit festen Werten, jetzt drei Archetypen
über `vehicle_type: String` (`"car"`/`"motorcycle"`/`"truck"`,
`Vehicle.VEHICLE_STATS`) — EIN Skript/EINE Szene für alle drei (String-Key
statt Enum, damit `World.gd` beim Spawnen keinen Cross-Script-Enum-Zugriff
braucht, gleiches Vereinfachungsmotiv wie `Wall.gd`s `is_gate`-Bool), Vorbild
`Infos/03 Asset-Checkliste.md` ("FAHRZEUGE"). Drei bewusst simple
Archetypen statt aller sechs Vision-Fahrzeuge:

| Typ | `max_hp` | `move_speed` | `noise_radius` | Größe |
|---|---|---|---|---|
| **Auto** (`car`) | 200 | 8.0 | 10.0 | 1.6×1.2×3.2 (bisheriger Basiswert) |
| **Motorrad** (`motorcycle`) | 80 | 13.0 | 7.0 | 0.8×1.0×2.0 (schnell/leise/fragil) |
| **LKW** (`truck`) | 320 | 6.0 | 15.0 | 2.0×1.6×4.2 (langsam/laut/robust) |

`NOISE_INTERVAL := 2.0` bleibt für alle Typen gleich (nur der Radius
unterscheidet sich) — reines Fahren (auch ohne Kampf) lockt Zombies
periodisch an, "lauter als ein Trupp" war explizit Teil der Konzept-Idee.

- **Zufällig pro Spawn gewählt** (`World.VEHICLE_TYPES`, `randi() %
  size()`) — kein fester Typ pro Zonen-Slot.
- **Sichtbar unterscheidbar** ohne echte Assets: eigene Grundfarbe pro Typ
  (`_update_color()`, HP-Verlauf Richtung Schwarz bleibt gleich) UND eigene
  Mesh-/Collision-Größe (`Vehicle._ready()` dupliziert `BoxMesh`/
  `BoxShape3D` aus der `.tscn` pro Instanz, sonst würde ein Resize alle
  Fahrzeuge gleichzeitig verzerren — sie teilen sich sonst dieselbe
  SubResource). Einstiegs-Statusmeldung ("Auto/Motorrad/LKW bestiegen.",
  `Survivor.VEHICLE_TYPE_LABELS`) macht den Typ zusätzlich textlich klar.
- **Eigene Boden-Y pro Typ** (`World.VEHICLE_GROUND_Y_BY_TYPE`, halbe
  Mesh-Höhe) — sonst würde z. B. der LKW sichtbar im Boden versinken
  (gleiche Falle wie `ZOMBIE_BRUTE_GROUND_Y`).
- **`hp`/`_max_hp` erst in `_ready()` berechnet**, NICHT beim Instanziieren
  gesetzt (gleiche `@export`-Timing-Falle wie `Zombie.gd`/`is_brute`) — ein
  vor `add_child()` gesetzter `hp`-Wert würde sofort überschrieben.
  Catch-up (`_catch_up_vehicle()`) und Spielstand-Laden (`_load_game_state()`)
  setzen `hp` deshalb jetzt beide erst NACH dem Spawnen, nicht mehr über
  das `data`-Dictionary selbst.
- **Bewusst OHNE Trage-Kapazitäts-Bonus** (Vision nennt "+X Slots" pro
  Fahrzeug): passt nicht sauber in die aktuelle Architektur, weil ein
  fahrender Trupp beim Einsteigen unsichtbar/aus `"living"` entfernt wird
  (`Survivor._board()`) und dabei gar nicht looten kann — Kapazität bleibt
  ausschließlich `Survivor.CARRY_CAPACITY`, geloottet wird zu Fuß nach dem
  Aussteigen. Ein echter Kapazitäts-Bonus bräuchte ein eigenes
  Fahrzeug-Inventar-System, das hier bewusst nicht mitgebaut wurde. (Das
  ist eine ANDERE Kapazität als die Sitzplatz-Kapazität weiter unten —
  "mehr Leute reinpassen" betrifft nur Sitze, nicht Loot-Tragfähigkeit.)
- **Mehrere Sitzplätze pro Fahrzeug** (Nutzerwunsch 2026-08-03, `test.txt`:
  "autos mehr läute rein passen") — `VEHICLE_STATS[...]["seats"]`: Auto 3,
  Motorrad 1 (kein Soziussitz), LKW 5. Siehe "Einsteigen"/"Aussteigen"
  unten, ersetzt die vorherige "nur ein Fahrersitz"-Grenze.
- Spielstand speichert `vehicle_type` jetzt mit (`_collect_save_data()`/
  `_load_game_state()`), Catch-up für spät beitretende Peers ebenfalls
  (`_catch_up_vehicle()` bekommt `vehicle_type` als fünften Parameter).

**Noch nicht vom Nutzer getestet.**

## Besitz (`owner_peer_id`)

`0` = unbesetzt/geparkt, sonst der Peer, der gerade fährt.
`owner_peer_id` ist auf **allen** Peers korrekt (repliziert über
`_sync_owner()`), im Gegensatz zu `driver` (nur host-seitig
aussagekräftig — die tatsächliche `Survivor`-Node-Referenz muss nicht
über das Netzwerk). `is_occupied()` prüft deshalb bewusst
`owner_peer_id != 0`, nicht `driver != null`.

## Einsteigen (`enter()`) — jetzt mit Mitfahrern

Host-seitig von `Survivor._enter_vehicle()` aufgerufen, nachdem dort schon
geprüft wurde, dass das Fahrzeug noch nicht VOLL ist (`is_full()`, siehe
unten) — kein eigenes RPC nötig, gleiches Cross-Node-Muster wie
`GuardPost.request_worker()` → `Survivor.order_station()`. Erster
einsteigender Trupp wird **Fahrer** (`owner_peer_id`/`driver` gesetzt,
repliziert per `_sync_owner.rpc()`, hat als einziger Steuerungsrechte für
`order_move()`/`order_stop()`/`request_exit()`), jeder weitere bis zur
`seats`-Kapazität wird **Mitfahrer** (`passengers`-Array, KEINE eigenen
Steuerungsrechte). `World._select_at()` schickt beim Klick auf ein
unbesetztes Fahrzeug jetzt ALLE ausgewählten eigenen Trupps gleichzeitig
als Einsteige-Versuch (statt nur den ersten), `enter()` weist sie
entsprechend zu, überzählige (wenn mehr Trupps ausgewählt waren als Sitze
frei sind) laufen einfach ins Leere — `enter()` gibt dafür `bool` zurück
(`false` = kein Platz mehr). Jeder einsteigende Trupp wird währenddessen
unsichtbar und aus `"selectable"`/`"living"` entfernt (siehe
`Survivor._board()`, [`docs/survivor.md`](survivor.md)) — das Fahrzeug
übernimmt die Rolle als auswählbare/befehligbare Einheit für die ganze
Besatzung.

## Aussteigen (`request_exit()`) — ganze Besatzung auf einmal

Ausgelöst über die **F-Taste** (`World._exit_selected_vehicles()`), kein
eigener UI-Button — analog zu den Kontrollgruppen-Tasten.
`@rpc("any_peer", "call_local", "reliable")`, weil der Aufruf (anders als
`enter()`) von jedem Peer selbst kommen kann, nicht nur host-intern. Nur
der **Fahrer** kann das auslösen (`owner_peer_id`-Check) — steigt er aus,
ruft `request_exit()` `exit_vehicle(position)` für den Fahrer UND alle
Mitfahrer auf (jeder mit leicht versetzter Position, damit sie nicht
exakt übereinanderstehen), leert `driver`/`passengers`, setzt
`owner_peer_id = 0`, leert die Wegpunkte, repliziert `_sync_owner.rpc(0)`.
**Mitfahrer können nicht einzeln aussteigen** — kein eigenständiges
Aussteigen einzelner Passagiere ohne den Fahrer, siehe "Bekannte Grenzen".

## Bewegung + Blocking

`order_move()`/`order_stop()` — identisches Muster wie
`Survivor.order_move()`/`order_stop()` (siehe
[`docs/survivor.md`](survivor.md)), nur ohne Wegpunkt-Schlangen-Ankunfts-
Weiche (Fahrzeuge suchen/claimen/stationieren nicht). `_is_path_blocked()`
nutzt dieselbe `OBSTACLE_LAYER`-Raycast-Logik wie beim Survivor — Mauern/
fremde Tore lassen das Fahrzeug einfach stehen bleiben, kein Durchbrechen
wie beim Zombie, kein Ausweichen.

## Zombie-Ziel nur bei Besetzung

`Zombie._is_unoccupied_vehicle()` schließt ein Fahrzeug mit
`owner_peer_id == 0` explizit von der Zielsuche aus — **Nutzerentscheidung
während dieser Session**: zuvor konnten Zombies auch geparkte, unbesetzte
Fahrzeuge angreifen und zerstören, was als "Autos verschwinden einfach,
ohne dass man weiß warum" gemeldet wurde (kein Feedback beim Zerstören
eines Fahrzeugs, das gerade niemand beobachtet). Seit der Änderung sind
nur noch **besetzte** Fahrzeuge angreifbar — siehe
[`docs/zombies.md`](zombies.md).

## Zerstörung

`take_damage()` — kein RPC, ausschließlich host-seitig von `Zombie`
aufgerufen. Bei `hp <= 0`:

- **Feedback:** `report_status(owner_peer_id, "Fahrzeug wurde von einem
  Zombie zerstört.")` — nur, wenn `owner_peer_id != 0` (ein längst
  unbesetztes Fahrzeug hat niemanden, der informiert werden müsste; in
  der Praxis ohnehin nur noch besetzte Fahrzeuge erreichbar, siehe oben).
- **Permadeath:** `take_damage()` ruft `vehicle_destroyed()` für den
  Fahrer UND alle Mitfahrer auf — die ganze Besatzung stirbt mit dem
  Fahrzeug, kein Rauswurf in letzter Sekunde (Konzept, `ARCHITECTURE.md`).
- `_die.rpc()` entfernt den Node.

## Replikation

Zwei getrennte Sync-RPCs statt einem kombinierten wie bei Survivor/
Zombie: `_sync_owner()` (`reliable`, seltene Änderung, muss ankommen) und
`_sync_state()`/`_sync_hp()` (Position/HP, `unreliable_ordered` bzw.
`reliable` je nach Auslöser). `_process()` überspringt `_sync_state()`
komplett, solange `driver == null` — ein geparktes Fahrzeug bewegt sich
nicht, kein unnötiger Sync-Spam.

## Platzierung auf der Karte

Zwei Fahrzeuge pro Stadt-Zone (siehe `docs/world.md`), platziert über
`_spaced_position()` innerhalb des jeweiligen Zonen-Radius (`CITY_ZONE_
RADIUS_LARGE`/`_SMALL`, seit der Kartenplanungs-Session 2026-08-01 zwei
Größen statt einer) mit typspezifischer Boden-Y (`VEHICLE_GROUND_Y_BY_TYPE`,
siehe "Differenzierte Fahrzeugtypen" oben) — ursprünglich zwei feste
Fahrzeuge auf der ganzen (viel kleineren)
Karte bei `(±20, 0.6, 0)`, die zunächst bei `(±12, ∓12)` standen und dort
nur 5.7 Weltmeter von einem festen Zombie-Spawnpunkt entfernt lagen
(innerhalb `DETECT_RADIUS := 8.0`) — praktisch sofort nach Spielstart
angegriffen, deshalb weiter weg verschoben. Der neue,
zufalls-abstandsbasierte Platzierungsalgorithmus (`BUILDING_MIN_SPACING`/
`MIN_RESOURCE_SPACING`) verhindert dieses konkrete Problem jetzt
strukturell statt durch eine von Hand gewählte Koordinate.

## Bekannte Grenzen (noch nicht gelöst)

- **Kein Nachspawnen nach der Weltgenerierung, kein Reparieren** — feste
  Anzahl pro Zone bei Weltstart.
- **Mitfahrer können nicht einzeln aussteigen** — nur der Fahrer kann
  `request_exit()` auslösen, dann steigt die ganze Besatzung zusammen aus
  (siehe "Aussteigen" oben). Kein Weg, gezielt nur EINEN Mitfahrer
  rauszulassen, während der Rest weiterfährt.
- **Kein Boarding über Peer-Grenzen hinweg** — man kann nur die eigenen
  ausgewählten Trupps gemeinsam einsteigen lassen, nicht als Mitfahrer bei
  einem schon von einem ANDEREN Spieler besetzten Fahrzeug zusteigen
  (`World._select_at()` erlaubt den Einsteige-Branch nur bei
  `hit.owner_peer_id == 0`, ein bereits besetztes fremdes Fahrzeug bleibt
  wie bisher nur anklickbar/nicht befehligbar).
- **Kein Nachträglich-Zusteigen zum eigenen, schon fahrenden Fahrzeug** —
  wer schon Fahrer ist und später weitere eigene Trupps als Mitfahrer
  dazuholen will, muss das Fahrzeug dafür erneut zusammen mit den neuen
  Trupps anklicken (aktuell nicht unterstützt, da ein Klick auf das
  EIGENE, schon besetzte Fahrzeug es nur auswählt statt neue Mitfahrer
  aufzunehmen).
- **Pathing folgt Straßen nur INNERHALB von Stadt-Zonen** (siehe
  "Fahrzeug-Pathing" in [`world.md`](world.md), umgesetzt 2026-08-01) —
  `order_move()` berechnet über `World.find_vehicle_path()` einen Weg
  entlang des Straßen-Rasters, wenn das Ziel in einer Stadt-Zone liegt.
  In der Wildnis (zwischen den Zonen) bleibt es bei der Luftlinie — dort
  gibt es keine Straßen-Daten, inhaltlich korrekt. **Weiterhin kein
  echtes Umfahren von Gebäuden** (Fahrzeuge kollidieren nach wie vor nur
  mit Mauern/Toren, siehe `_is_path_blocked()`, `OBSTACLE_LAYER`) — das
  letzte Stück vom nächsten Straßen-Punkt zum eigentlichen Ziel bleibt
  Luftlinie, kann also theoretisch minimal durch ein Gebäude "schneiden".
  Kein `NavigationServer3D`/gebackenes Navigationsmesh, bewusst ein
  simplerer Wegpunkt-Graph aus den ohnehin vorhandenen Blockraster-Daten.

## Catch-up für `owner_peer_id` (2026-08-01, Punkt 6 der Performance-Liste)

War bis dahin die letzte offene Catch-up-Lücke seit dem Kartenumbau (siehe
`docs/world.md`): `_catch_up_vehicle()` sendete bewusst nur Position/HP an
spät beitretende Peers, kein `owner_peer_id` — ein schon besetztes Fahrzeug
erschien beim neuen Peer zunächst als unbesetzt, bis der nächste
`_sync_owner()`-Aufruf (nur bei Ein-/Aussteigen) es zufällig korrigierte.
Jetzt behoben: `_catch_up_vehicle()` bekommt `owner_peer_id` als vierten
Parameter, reicht ihn an `_create_vehicle()` durch (analog zu
`Building.owner_peer_id`/`is_looted`, siehe [`docs/zones.md`](zones.md)).
Speichern/Laden bleibt bewusst unverändert — Fahrzeug-Fahrer werden dort
weiterhin nicht wiederhergestellt (eigene, schon dokumentierte
Vereinfachung, kein Teil dieses Fixes).

**Noch nicht vom Nutzer getestet.**

## Testen

Debug → Customize Run Instances → 2 → F5, Host + Join, "Spiel starten".
Trupp auswählen, auf ein Fahrzeug klicken — sollte hinlaufen und
einsteigen, danach als Fahrzeug befehligbar sein (schnellere Bewegung).
F drücken — Trupp sollte wieder aussteigen und sichtbar/auswählbar
werden. Mit besetztem Fahrzeug in Zombie-Nähe fahren — sollte angegriffen
werden; unbesetzt geparkt daneben stehen lassen — sollte ignoriert
werden.
