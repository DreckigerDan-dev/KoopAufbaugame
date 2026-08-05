# Zonen-System (Claimen)

**Update 2026-08-03 (Nutzerwunsch, `test.txt`: "man kann nicht überall
bauen können das sollte man"):** die Bau-Abstandsprüfung
(`is_within_own_zone()`/`BUILD_RADIUS`, weiter unten in diesem Dokument
noch ausführlich beschrieben) ist komplett entfernt — Bauen geht jetzt
überall auf der Karte, unabhängig von Home-Base/geclaimten Gebäuden. Das
**Claimen selbst** war ohnehin schon immer ohne Abstandsprüfung (siehe
"Warum Claimen ohne Abstandsprüfung" unten) — dieser Unterschied zwischen
Bauen und Claimen existiert jetzt also nicht mehr, beides ist
uneingeschränkt. Die Abschnitte unten beschreiben den historischen Stand
VOR diesem Fix, größtenteils weiterhin relevant fürs Claimen-Konzept
selbst (Gebäude wird Anker, nur einmal claimbar etc.), nur die
Bau-Abstandsregel ist überholt.

Erklärt die Zonen-/Claiming-Ergänzungen in `scenes/world/Building.gd`,
`scenes/world/World.gd` und `scenes/entities/survivor/Survivor.gd`.
Konzept siehe `ARCHITECTURE.md`, "Zone erweitern" — sowie das ausführliche
Vision-Dokument in `D:\CWorkspace\KoopGame\Infos\01 Architektur.md`
("Zone erweitern: Muss zusammenhängend bleiben — nur an die bestehende
Zone angrenzende Gebäude sind claimbar (erst säubern, dann claimen)").
Baut auf [`docs/scavenging.md`](scavenging.md) (Durchsuchen als
Voraussetzung) und [`docs/building.md`](building.md) (`BUILD_RADIUS`,
`_can_build_at()`) auf.

## Umfang

Ein bereits **geplündertes** Gebäude kann von einem Trupp geclaimt werden
(15 Stein, siehe [`docs/base.md`](base.md), "Vier Baurohstoffe") — es
gehört danach diesem Spieler und wird selbst zum
Anker für die eigene Bauzone: Wachposten/Mauer/Krankenstation/Werkstatt
lassen sich jetzt auch in `BUILD_RADIUS` (8 Weltmeter) um das geclaimte
Gebäude bauen, nicht mehr nur um die Home-Base. Ein Gebäude kann nur
**einmal** geclaimt werden (erster Spieler bekommt den Zuschlag).

**Umsetzt aus der größeren Nutzer-Idee** (siehe `docs/status.md`,
Roadmap-Punkt 2/3): sowohl das Claimen der acht Stadt-Gebäude als auch die
Start-Basis-Wahl (siehe unten) sind jetzt umgesetzt.

## Start-Basis wählen

Ergänzung zum ursprünglichen Claiming: statt einer festen, automatisch
gespawnten Home-Base in der Kartenecke wählt jeder Peer beim Betreten von
`World.tscn` selbst eines der Stadt-Gebäude (mittlerweile über fünf
verteilte Zonen, siehe [`docs/world.md`](world.md), "Kartenlayout") als
Start-Basis — click auf ein noch niemandem gehörendes Gebäude, kein Trupp
nötig (den gibt es vor der Wahl ja noch nicht). Ersetzt die früheren
festen `HOME_BASE_POSITIONS`/`START_POSITIONS`-Kartenecken vollständig.

- **`World._select_at()`** hat dafür einen eigenen Branch **vor** der
  normalen Auswahl-/Such-/Claim-Logik: solange `_find_own_home_base() ==
  null`, ersetzt ein Klick auf ein `"searchable"`-Gebäude die normale Logik
  komplett — `request_choose_start_base.rpc_id(1, ...)` statt
  `order_search()`/`order_claim_building()`.
- **`World.request_choose_start_base()`** (host-seitig): prüft, dass der
  Peer noch keine Home-Base hat und das Gebäude noch niemandem gehört
  (`owner_peer_id == 0`) — dann `building.mark_looted.rpc()` +
  `building.set_claimed_owner(peer_id)` (dasselbe Muster wie
  `claim_building()`, aber **kostenlos und ohne vorheriges Durchsuchen** —
  man startet dort, das Gebäude gilt von Anfang an als gesichert). Home-Base
  spawnt danach direkt an der Position des Gebäudes (siehe "Home-Base
  ersetzt das gewählte Gebäude" unten). Die zwei Start-Survivor spawnen
  seitlich versetzt (`BASE_CHOICE_SURVIVOR_OFFSET` + `HOME_BASE_HALF_
  DIAGONAL`, vom Gebäude-Mittelpunkt aus in Richtung von der **eigenen
  Zonen-Mitte** (`building.zone_center`) weg, damit nichts mit der neuen
  Home-Base überlappt — **seit dem Kartenumbau** (siehe
  [`docs/world.md`](world.md)) zonen-relativ statt weltursprung-relativ
  berechnet, siehe "Warum Claimen ohne Abstandsprüfung" unten für den Grund
  dieses Fixes).
- **Gebäude-Loot geht an die neue Home-Base** (2026-08-04, Systematik-
  Review, Fund 4) — das gewählte Gebäude hat schon einen vorgewürfelten
  `loot` (siehe `docs/scavenging.md`, "Gebäude-Typen + Loot-Tabellen"),
  der bis dahin beim `mark_looted()` einfach verworfen wurde, ohne je
  eingesammelt zu werden. `request_choose_start_base()` schreibt ihn jetzt
  direkt der neu gespawnten Home-Base gut (`home_base.add_resources.rpc(
  building.loot)`) — kein Neu-Würfeln, kein Einfluss auf die festen
  `HomeBase.START_RESOURCES`, nur ein kleiner thematischer Bonus je nach
  zufällig gewähltem Starttyp (z. B. etwas mehr Nahrung bei einem
  Supermarkt-Start, eine Waffe bei einem Waffenladen-Start).
- **Home-Base ersetzt das gewählte Gebäude (2026-08-05, Nutzer-Report
  "startbase sitzt auf der straße"):** vorher stand die Home-Base NEBEN dem
  gewählten Gebäude (versetzt um `BASE_CHOICE_HOME_OFFSET` + halbe
  Gebäude-Diagonale, Richtung "away" von der Zonen-Mitte) — bei vielen
  Gebäude-/Zonen-Konstellationen landete sie dabei auf der Straße statt auf
  freiem Baugrund. Jetzt spawnt die Home-Base exakt an der Position des
  gewählten Gebäudes, das Gebäude selbst wird direkt danach abgerissen
  (`building._demolish.rpc()`, gleiches RPC-Muster wie beim normalen
  Gebäude-Abriss über `order_demolish_building()`) — keine zwei
  überlappenden Meshes an derselben Stelle. `HOME_BASE_HALF_DIAGONAL`
  (Konstante aus der einheitlichen `HomeBase.tscn`-Boxgröße) ersetzt dafür
  die bisherige, gebäudespezifische `half_diagonal`-Berechnung beim
  Trupp-Versatz, da das ursprüngliche Gebäude danach nicht mehr existiert.
  Das Ressourcen-Datenmodell (`docs/base.md`) lebt weiterhin unverändert in
  der separaten `HomeBase`, um den bestehenden Ressourcen-Code nicht
  anzufassen — nur die räumliche Beziehung zum Gebäude hat sich geändert.
  **Noch nicht getestet.**
- **`World._spawn_for_peer()`** macht seitdem nur noch Catch-up für spät
  beitretende Peers (siehe `docs/networking.md`) — die eigene Home-Base samt
  Survivor-Start entsteht nicht mehr automatisch beim Verbinden, sondern
  erst über die eigene Wahl.
- **UI:** `$HUD/BaseChoiceLabel` ("Wähle deine Start-Basis — klicke auf
  eines der Gebäude"), sichtbar solange `_find_own_home_base() == null`
  (`World._update_hud()`), blendet sich danach automatisch aus.
- Zwei Peers können theoretisch gleichzeitig dasselbe Gebäude anklicken —
  der Host verarbeitet RPCs sequenziell, der erste bekommt den Zuschlag,
  beim zweiten schlägt die `owner_peer_id != 0`-Prüfung fehl
  (`report_status()`, "Dieses Gebäude ist schon vergeben."), UI bleibt
  sichtbar, er muss ein anderes Gebäude wählen.

## Warum Claimen ohne Abstandsprüfung (wichtige Design-Entscheidung)

Die Vision sagt "nur an die bestehende Zone angrenzende Gebäude sind
claimbar" — das würde aber praktisch **nie funktionieren**: Home-Base
liegt seit der Start-Basis-Wahl (siehe oben) selbst in einem der Gebäude
einer Stadt-Zone, alle übrigen Gebäude dieser Zone liegen aber
typischerweise weiter als `BUILD_RADIUS` (8 Weltmeter) entfernt (jede Zone
hat `CITY_ZONE_RADIUS_LARGE := 260.0` bzw. `CITY_ZONE_RADIUS_SMALL :=
150.0`, siehe [`docs/world.md`](world.md)). Mit einer strikten
Nachbarschaftsregel könnte also **kein einziges** weitere Gebäude je
geclaimt werden, das erste "angrenzende" gäbe es nie.

**Lösung:** `World.claim_building()` prüft bewusst **nur** drei Dinge —
geplündert, noch niemandem gehörend, bezahlbar (`_can_afford()`) — nie mit
einer Abstandsprüfung. Das eigentliche Bauen
(`request_build_structure()`/`request_build_wall_line()`) hatte zwischen-
zeitlich eine eigene Abstandsprüfung (`is_within_own_zone()`, inklusive
aller geclaimten Gebäude als zusätzliche Anker) — die ist seit 2026-08-03
ebenfalls komplett entfernt (siehe Update-Hinweis ganz oben), Claimen und
Bauen sind seitdem beide uneingeschränkt.

## `Building.gd`

- **`owner_peer_id: int = 0`** — 0 = nicht geclaimt, analog zu
  `Vehicle.owner_peer_id` (siehe `docs/vehicle.md`).
- **`set_claimed_owner(peer_id)`** — von `World.claim_building()`
  aufgerufen (schon host-seitig, kein eigenes RPC nötig, gleiches Muster
  wie `Vehicle.enter()`). Kapselt das Sync-RPC (`_sync_owner`,
  `@rpc("authority", "call_local", "reliable")`), damit `World.gd` nicht
  direkt eine `_`-Methode eines fremden Nodes aufrufen muss.
- **`_update_visual()`** (vorher `_update_looted_visual()`, umbenannt und
  erweitert): geclaimt → bläulicher Ton (`Color(0.3, 0.5, 0.75)`),
  geplündert-aber-frei → grau (unverändert), sonst unangetastet (Original-
  Material aus dem `.tscn` bleibt).

## Claimen auslösen (`World._select_at()`)

Der bestehende Gebäude-Klick-Zweig (siehe `docs/scavenging.md`) prüft
jetzt den Gebäude-Zustand, bevor er einen Befehl schickt:

- **Noch nicht geplündert** → `order_search()` wie bisher.
- **Geplündert, `owner_peer_id == 0`** → `order_claim_building()` statt
  `order_search()`.
- **Geplündert, schon jemandem gehörend** → Klick tut nichts (kein
  Feedback nötig, ist einfach schon vergeben, gleiches Prinzip wie ein
  schon besetztes Fahrzeug in `docs/vehicle.md`).

**Dynamischer RPC-Aufruf:** `order_search`/`order_claim_building` haben
identische Signaturen (`target: Vector3, building_path: NodePath,
requesting_peer_id: int`) — welcher RPC gefeuert wird, entscheidet ein
`StringName`, aufgerufen über `unit.rpc_id(1, order_method, ...)` (Node
hat eine generische `rpc_id(peer_id, method_name, ...)`-Methode für genau
diesen Fall). **Wichtig:** `unit.call(order_method, ...)` hätte hier NICHT
funktioniert — das ruft die Methode nur lokal auf, ohne übers Netzwerk zu
gehen.

## Ablauf in `Survivor.gd`

Analog zu `order_search()`/`_finish_search()`
(siehe `docs/scavenging.md`) bzw. `order_enter_vehicle()`/`_enter_vehicle()`
(siehe `docs/vehicle.md`):

1. `order_claim_building(target, building_path, requesting_peer_id)` —
   merkt sich `_pending_claim_path`, setzt den Wegpunkt.
2. Bei Ankunft (letzter Wegpunkt) ruft `_handle_movement()`
   `_claim_building()` auf: löst den Node auf, ruft
   `get_tree().current_scene.claim_building(owner_peer_id, building)`
   auf (World.gd prüft dort erneut, siehe unten — falls sich der Zustand
   seit dem Loslaufen geändert hat, z. B. ein anderer Spieler war
   schneller).
3. **Abbrechbar** wie Suche/Fahrzeug-Einstieg — `_cancel_search()` setzt
   auch `_pending_claim_path` zurück.

## Prüfung + Claim (`World.claim_building()`)

1. **Geplündert?** (`building.is_looted`.)
2. **Noch niemandem gehörend?** (`building.owner_peer_id == 0`.)
3. **Bezahlbar?** (`_can_afford(peer_id, ZONE_CLAIM_COST)` — 15 Stein,
   dieselbe Preisklasse/Art wie eine Mauer.)

Erst wenn alle drei bestehen: Kosten abziehen
(`base.add_resources.rpc()` mit negiertem Delta) und
`building.set_claimed_owner(peer_id)`. Schlägt die Ressourcen-Prüfung
fehl, zeigt `report_status()` "Nicht genug Ressourcen." (kein
`_report_build_failure()` — das würde fälschlich eine
Zonen-Abstandsmeldung prüfen, die hier gar nicht zutrifft).

## `is_within_own_zone()` — entfernt (2026-08-03)

Gab es früher (siehe historische Beschreibung oben im Update-Hinweis) —
`_can_build_at()` (siehe `docs/building.md`) prüft seit dem Wegfall der
Bau-Abstandsprüfung nur noch, ob genug Ressourcen da sind, egal wo auf der
Karte gebaut wird. Die Funktion selbst sowie die Konstante `BUILD_RADIUS`
sind aus `World.gd` gelöscht (keine tote Funktion stehen gelassen).
Geclaimte Gebäude bleiben trotzdem sinnvoll (Ressourcen-Loot, Ausbauen zu
Krankenstation/Werkstatt/Lager/Bett), sind nur kein Bauzonen-Anker mehr.

## Bekannte Grenzen (noch nicht gelöst)

**Update 2026-08-04 (Systematik-Review):** Bullet "Kein Außenposten-
Sonderfall — noch nicht umgesetzt" entfernt, war veraltet (von vor
2026-08-01) — Außenposten existieren seitdem als eigener Bautyp, siehe
[`building.md`](building.md), "Außenposten".

- **Catch-up für `Building.owner_peer_id`/`is_looted` seit dem
  Kartenumbau gelöst** (siehe `docs/world.md`): Gebäude laufen jetzt über
  `MultiplayerSpawner`, `_catch_up_building()` schickt den vollständigen
  Zustand (inkl. `owner_peer_id`/`is_looted`/`hp`) an spät beitretende
  Peers mit — anders als weiterhin bei `Vehicle.owner_peer_id` (siehe
  `docs/vehicle.md`, dort bewusst noch offen).
- **Kein visuelles Zonen-Overlay** — man sieht nur an der Gebäudefarbe,
  was geclaimt ist, nicht die tatsächliche Bauzonen-Ausdehnung selbst
  (z. B. als Bodendecal). Ghost-Preview beim Bauen zeigt die Gültigkeit
  nur punktuell am Mauszeiger.
- **Erster Claim ist "frei" von der Zusammenhang-Regel** (siehe oben,
  bewusste Design-Entscheidung wegen der Kartengeometrie) — echte
  Zusammenhang-Pflicht gilt erst ab dem zweiten Gebäude.
- **Kein Fallback, wenn ein Peer nie wählt** — bleibt ohne Home-Base
  handlungsunfähig (kein Trupp, kein Bauen), solange niemand ein Gebäude
  anklickt. Für ein Coop-Spiel unter Freunden bewusst kein Timeout/
  Zufalls-Fallback eingebaut.
- **Home-Base/Survivor-Start können sich bei dicht beieinanderliegenden
  Gebäuden überlappen** — `BASE_CHOICE_HOME_OFFSET`/
  `BASE_CHOICE_SURVIVOR_OFFSET` sind feste Abstände, keine
  Kollisionsprüfung gegen andere Home-Bases/Gebäude in der Nähe.
- **Echter Bug gefunden und behoben (2026-07-31):** der zweite Start-Trupp
  wurde ursprünglich mit dem festen Welt-Vektor `SECOND_SURVIVOR_OFFSET`
  (`+X`) versetzt — bei Gebäuden, deren `away`-Richtung (von der
  Kartenmitte weg) einen negativen X-Anteil hat, zeigte dieser feste
  Versatz zurück Richtung/in das Gebäude-Mesh, der zweite Trupp landete
  darin und war weder sichtbar noch anklickbar ("zweiter Spieler hatte nur
  eine Unit", vom Nutzer gemeldet). Fix: Versatz jetzt senkrecht zu `away`
  (`sideways := Vector3(-away.z, 0, away.x)`), bleibt dadurch unabhängig
  von der Gebäuderichtung immer gleich weit vom Gebäude entfernt.

## Testen

Debug → Customize Run Instances → 2 → F5, Host + Join, "Spiel starten".
Ein Gebäude durchsuchen lassen (siehe `docs/scavenging.md`), danach
denselben Trupp nochmal draufklicken — sollte jetzt hinlaufen und
"claimen" statt nochmal zu suchen, das Gebäude sollte sich bläulich
färben und 15 Stein abziehen. Ghost-Preview beim Bauen sollte seit 2026-08-03 überall auf der Karte
grün sein, auch weit weg von jeder eigenen Basis/jedem Claim (siehe
`docs/pending-tests.md`, "Bauen ohne Zonen-Restriktion").
