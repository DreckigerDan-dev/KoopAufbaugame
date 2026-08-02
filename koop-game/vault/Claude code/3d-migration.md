# 3D-Umstieg (abgeschlossen)

**Status: fertig verkabelt.** Der komplette Inhalt dieser Testszene
(`World3DTest.gd`/`.tscn` und die `Test*`-Skripte, alle mittlerweile
gelöscht) lebt jetzt in den echten Dateien: `scenes/world/World.gd`/`.tscn`,
`scenes/entities/survivor/Survivor.gd`, `scenes/entities/zombie/Zombie.gd`,
`scenes/entities/base/HomeBase.gd`, `scenes/entities/base/GuardPost.gd`,
`scenes/world/Building.gd`. `Commander.gd`/`.tscn` sind entfallen (Rolle in
`World.gd` gefaltet, siehe `docs/commander.md`). Das 2D-`World.tscn` wurde
komplett ersetzt, nicht parallel weitergeführt — die aktuelle,
tatsächliche Doku pro System steht jetzt in `docs/world.md`,
`docs/survivor.md`, `docs/zombies.md`, `docs/base.md`, `docs/building.md`,
`docs/scavenging.md`. **Bekannte Regression:** Rekrutierung (siehe
`docs/recruitment.md`) ist nicht mit übernommen worden.

Diese Datei bleibt als **historisches Protokoll** des gesamten
Migrationsverlaufs stehen — jeder Zwischenschritt, jeder unterwegs
gefundene Bug (inkl. voller Diagnose) und jede Design-Entscheidung ist unten
in der Reihenfolge dokumentiert, in der sie passiert ist. Für den aktuellen
Code-Stand sind aber die oben verlinkten System-Docs die richtige Quelle,
nicht dieses Dokument.

---

Der folgende Abschnitt beschreibt den Stand, als diese Datei noch aktiv
gepflegt wurde (Testszene `scenes/world/World3DTest.gd` + `.tscn`, seitdem
gelöscht) — Code-Referenzen darin zeigen auf Dateien, die es nicht mehr
gibt.

## Renderer-Wechsel: D3D12 → Vulkan

`project.godot` erzwang bisher `rendering_device/driver.windows="d3d12"`
(ungenutzter Godot-4.7-Projekterstellungs-Standard, siehe
`ARCHITECTURE.md`, "Perspektive") — entfernt, damit Windows auf Godots
Standard-Backend (Vulkan) zurückfällt. War Teil der Fehlersuche zum
Rendering-Bug unten, hat den eigentlichen Bug aber **nicht** behoben (der
lag am Vererbungsmuster, nicht am Renderer) — trotzdem als sinnvolle
Bereinigung drin gelassen, da Vulkan in Godot 4 der ausgereiftere
Standard-Pfad ist.

## Warum und was das bedeutet

Wunsch: Bird's-Eye-Ansicht, aber echtes 3D mit freier 360°-Rotation um die
Kamera (in 2D nicht möglich — `Camera2D` kennt nur Pan/Zoom, keine
Rotation um eine dritte Achse). Das ist **kein kleiner Umbau**: alle neun
bisher gebauten Gameplay-Systeme (World, Commander, Survivor, Zombie,
HomeBase, GuardPost, Buildings) sind komplett auf `Node2D`/`Vector2`/
`ColorRect`-Platzhaltern aufgebaut. **Nicht betroffen** sind Networking
(`NetworkManager`, `GameManager`, RPC-Muster) und die reinen Datenmodelle
(Ressourcen, HP, Hunger) — die sind dimensionsunabhängig und bleiben beim
Umstieg unverändert.

## Vorgehen: Fundament zuerst, dann Entity für Entity

Statt alles auf einmal umzubauen (nichts wäre bis zum Schluss testbar,
Fehler schwer eingrenzbar), läuft die Migration wie jedes andere Feature in
diesem Projekt in kleinen, einzeln testbaren Schritten:

1. **Fundament** (dieser Schritt): 3D-Boden + Kamera-Rig mit Pan/Rotation/
   Zoom, isoliert getestet, `World.tscn` bleibt währenddessen unangetastet
   und spielbar (2D).
2. Danach nacheinander: Commander (echte 3D-Kamera + Klick-Auswahl per
   Raycast statt `get_global_rect()`), World-Boden/Gebäude, Survivor,
   Zombie, HomeBase, GuardPost — jeweils eigener Schritt mit eigenem Test.
3. Erst wenn alle Einzelteile stehen, werden sie zusammen in eine neue,
   echte 3D-`World.tscn` verkabelt.

**Ordner-Konvention:** Bleibt wie bei `CommanderTestScene.tscn` — Test-/
Prototyp-Dateien liegen direkt neben den echten Dateien im selben Ordner
(hier `scenes/world/`), nicht in einem eigenen Baum. Grund: die 3D-Dateien
sollen die 2D-Dateien am Ende *ersetzen*, nicht dauerhaft parallel
existieren — ein separater Ordner müsste bei jeder Migrations-Etappe wieder
aufgelöst werden.

## `World3DTest.gd` + `.tscn`

Kamera- und Auswahl-Testszene: 3D-Boden (`BoxMesh` mit
`StandardMaterial3D`, flaches, grünes Rechteck — bewusst weiterhin
Platzhalter statt echter Assets, wie schon bei den 2D-ColorRects), ein
`DirectionalLight3D` (3D braucht anders als 2D eine Lichtquelle, sonst
bleibt alles schwarz). Zur besseren Unterscheidbarkeit (anfangs standen
hier drei identische neutrale Würfel, was beim Testen für Verwirrung
sorgte, ob das Gebäude oder Einheiten sein sollen) jetzt klar getrennt:

- **`Building1`/`Building2`** — braune Boxen, reine Deko wie die
  Platzhalter-Gebäude in der echten `World.tscn`, **nicht** `"selectable"`.
- **`Trupp1`** — helle Kapsel (Pendant zum 2D-`Survivor`-Marker), in der
  Gruppe `"selectable"`, das eigentliche Testobjekt für Auswahl + Bewegen.

**Kamera-Rig:** `Pivot` (Node3D, Rotationszentrum) → `Camera3D` als Kind,
positioniert entlang eines aus `_tilt_angle` berechneten Richtungsvektors
(`Vector3(0, sin(_tilt_angle), cos(_tilt_angle))`, schräg oben-hinten,
klassischer RTS-Blickwinkel). Die Kamera bleibt beim Zoomen immer auf
derselben Linie vom Pivot aus (`camera.position = offset_dir *
_zoom_distance`) — dadurch ändert sich beim Zoomen nur die Distanz, nie der
Blickwinkel.

**Update — Neigungswinkel jetzt änderbar (ursprünglich fest
`BASE_OFFSET_DIR = Vector3(0, 0.6, 1)`):** Auf Nutzerwunsch nicht mehr nur
360°-Drehung, sondern auch der Blickwinkel selbst einstellbar. `_tilt_angle`
(Radiant, Start `0.5404` ≈ der ursprüngliche feste Winkel) wird von
`TILT_MIN` (~15°, flacher Blickwinkel) bis `TILT_MAX` (~80°, fast senkrecht
von oben) geklemmt. Weil sich die Blickrichtung dadurch jetzt ändern kann
(anders als beim reinen Zoom entlang einer festen Linie), muss
`camera.look_at()` in `_apply_zoom()` jetzt bei **jedem** Aufruf neu
berechnet werden, nicht mehr nur einmalig in `_ready()`.

- **Pan** (WASD/Pfeiltasten, `_handle_pan`): bewegt `global_position` der
  ganzen Szene (also den Pivot-Mittelpunkt) auf der X/Z-Ebene. Wird per
  `Vector3.rotated(Vector3.UP, pivot.rotation.y)` um die aktuelle
  Blickrichtung gedreht, damit "W" immer "nach vorne aus Kamerasicht"
  bedeutet, unabhängig davon, wie weit gerade rotiert wurde — sonst würde
  sich WASD nach einer 90°-Drehung falsch anfühlen (Welt-relativ statt
  Bildschirm-relativ).
- **Rotation + Neigung** (**rechte** Maustaste halten + ziehen, in
  `_unhandled_input`): horizontale Mausbewegung dreht den `Pivot` um die
  Y-Achse (`pivot.rotate_y(-event.relative.x * MOUSE_ROTATE_SENSITIVITY)`)
  — das ist die eigentliche 360°-Drehung, die in 2D nicht ging. Vertikale
  Mausbewegung ändert zusätzlich `_tilt_angle`
  (`-event.relative.y * MOUSE_TILT_SENSITIVITY`, geklemmt zwischen
  `TILT_MIN`/`TILT_MAX`) — dieselbe Geste steuert also beides gleichzeitig,
  wie bei den meisten RTS-Kameras üblich. **Nicht per Taste** für die
  Rotation — zwei Tasten-Versuche sind gescheitert: erst Q/E (vermutlich
  Kollision mit Godots eigenen 3D-Editor-Viewport-Werkzeug-Shortcuts, die
  zufällig auch Q/E heißen), dann `[`/`]` (auf deutscher QWERTZ-Tastatur
  nicht direkt belegt, braucht `Alt Gr`, funktioniert mit
  `Input.is_key_pressed()` nicht zuverlässig). Auch **mittlere** Maustaste
  schlug fehl (vermutlich keine bequem drückbare mittlere Maustaste
  vorhanden) — **rechte** Maustaste hat schließlich funktioniert und
  bestätigt: das eigentliche Problem beim ersten Versuch war gar nicht der
  Code, sondern dass **F5 statt F6** gedrückt wurde und dadurch die ganze
  Zeit das echte 2D-Spiel lief, nicht diese Testszene (siehe "Bekannte
  Stolpersteine beim Testen" unten).
- **Zoom** (Mausrad, `_zoom`): wie beim 2D-Commander prozentual skaliert
  (`_zoom_distance * ZOOM_STEP_FACTOR`), nicht linear — fühlt sich bei
  großen wie bei kleinen Distanzen gleich schnell an.

## Klick-Auswahl per Raycast

Zweite Hälfte des "Commander"-Migrationsschritts (Kamera stand schon):
3D-Pendant zu `Commander._select_at()` (siehe `docs/commander.md`) — dort
ein simpler Distanz-Check (kein Pathfinding/Physik nötig in 2D), hier ein
echter **Physik-Raycast**:

- `Marker1`–`Marker3` sind jetzt `StaticBody3D` (mit `MeshInstance3D` +
  `CollisionShape3D` als Kinder) statt reiner `MeshInstance3D` — ein
  Raycast braucht eine Collision-Shape, um überhaupt etwas treffen zu
  können. `Ground` genauso, damit Klicks auf den Boden nicht ins Leere
  laufen (relevant für später: Bewegungsbefehle per Bodenklick).
- `_select_at(screen_pos, additive)`: `camera.project_ray_origin()` +
  `camera.project_ray_normal()` liefern Startpunkt und Richtung eines
  Strahls von der Kamera durch die Klickposition auf dem Bildschirm — das
  ist die 3D-Entsprechung von "wo in der Welt wurde geklickt", die es in 2D
  nicht braucht (dort ist Bildschirm- und Weltkoordinate bei einer
  Top-Down-Kamera ohne Rotation direkt ineinander umrechenbar).
  `get_world_3d().direct_space_state.intersect_ray()` mit diesem Strahl
  liefert den nächstgelegenen getroffenen Collider (oder nichts).
- Nur Treffer in der Gruppe `"selectable"` (Marker1–3) zählen als Auswahl,
  Boden-Treffer werden ignoriert — gleiche Rolle wie die
  `"selectable"`-Gruppe in 2D (siehe `docs/commander.md`).
- Shift-Klick togglet additiv (in `selected` rein/raus), normaler Klick
  ersetzt die Auswahl — identisches Verhalten wie beim 2D-Commander.

**Bug gefunden und behoben (Gruppen-Zuweisung in `.tscn` ignoriert):** Beim
Testen war `Trupp1` zwar per Raycast treffbar, aber nie auswählbar — Debug-
Print direkt vor der `is_in_group`-Prüfung zeigte `Gruppen: []`, obwohl die
Szenendatei `groups = ["selectable"]` auflistete. Ursache: `groups` steht in
Godots `.tscn`-Format als **Attribut im `[node ...]`-Header selbst**
(`[node name="Trupp1" ... groups=["selectable"]]`), nicht als eigene
Property-Zeile darunter — eine Zeile wie `groups = [...]` unterhalb des
Headers wird beim Laden stillschweigend ignoriert (kein Fehler, aber auch
keine Wirkung). Praktische Konsequenz: bei künftigen Node-Gruppen in `.tscn`
immer im Node-Header selbst eintragen, nicht als Property-Zeile — und im
Zweifel per Debug-Print (`result.collider.get_groups()`) verifizieren statt
der Szenendatei zu vertrauen.

## Bewegen per Bodenklick

Rechtsklick ist hier für Kamera-Rotation belegt, nicht wie beim
2D-Commander für Bewegungsbefehle. Damit Auswahl nicht folgenlos bleibt,
übernimmt stattdessen der **Linksklick** eine zweite Rolle:

- Treffer auf ein `"selectable"`-Objekt → wie oben, Auswahl togglen.
- Treffer auf den Boden **während `selected` nicht leer ist** → statt zu
  deselektieren, bekommen alle ausgewählten Marker ein Bewegungsziel
  (`_move_targets[unit] = result.position` aus dem Raycast, + Höhenversatz),
  das `_handle_movement()` jeden Frame per `move_toward()` abträgt (Geschwindigkeit
  `MOVE_SPEED`, Ankunfts-Toleranz `ARRIVE_THRESHOLD`) — echtes Hinlaufen statt
  Teleport. Noch kein Pathfinding/Hindernisumgehung (nur Geradeaus-Interpolation)
  und kein `order_move`-Äquivalent wie bei `Survivor.gd` (kein Zustand für
  "läuft gerade"/Animation) — das kommt erst mit der Survivor-Migration.
- Treffer auf den Boden **ohne** Auswahl (oder gar kein Treffer) →
  deselektiert wie zuvor.

## World-Boden/Gebäude (zweiter Migrationsschritt)

Nächster Schritt nach Fundament + Commander, siehe "Vorgehen" oben —
`World3DTest` bekommt jetzt vier Gebäude statt zwei, als 3D-Pendant zu den
vier `ColorRect`-Platzhaltern in `World.tscn` (siehe `docs/world.md`):
`Building1`–`Building4`, gleiche braune Box wie zuvor, in der Gruppe
`"searchable"` statt `"selectable"` — entspricht der Trennung im 2D-Original
(`docs/scavenging.md`: Gebäude sind `"searchable"`, Trupps/Survivor sind
`"selectable"`).

**Wichtig, gelernt aus dem Gruppen-Bug oben:** `groups=[...]` steht bei allen
vier Gebäuden direkt im `[node ...]`-Header, nicht als Property-Zeile
darunter.

**Nur Grundlage, noch kein echtes Scavenging:** `_select_at()` erkennt einen
Klick auf ein `"searchable"`-Gebäude jetzt als eigenen Fall (geprüft *vor*
dem allgemeinen Bodenklick-Fall) und lässt die ausgewählte Einheit dorthin
laufen, loggt aber nur `"Ziel gesetzt (Gebäude, durchsuchen vorgemerkt): ..."`
— kein Timer, kein Loot, kein `is_looted`-Zustand. Die echte Anbindung an
`order_search()`/`Building.gd`-Logik (siehe `docs/scavenging.md`) kommt erst
mit der Survivor-Migration, wenn `Trupp1` durch eine echte Survivor-Instanz
ersetzt wird.

## Survivor (dritter Migrationsschritt)

Die frühere Testkapsel `Trupp1` (statischer Node direkt in
`World3DTest.tscn`, Zustand als Dictionaries in `World3DTest.gd`) bekam
zunächst die drei Kernmechaniken aus `docs/survivor.md` (HP/Permadeath,
Heilung an der Basis, Hunger) **ohne** Networking — testbar im
Singleplayer. Kurz darauf, im selben Zug wie der Multiplayer-Schritt
(siehe unten), wurde daraus die eigene Szene `TestTrupp.gd`/`.tscn`, weil
mit einem Trupp pro Peer mehrere Instanzen gleichzeitig existieren und
jede ihren eigenen Zustand braucht. Die Mechanik-Werte selbst blieben dabei
unverändert, nur der Ort des Codes hat sich verschoben:

- **HP + Permadeath** (`TestTrupp.take_damage`, `_die`, `_update_color`):
  `MAX_HP = 100`, Marker färbt sich per
  `MeshInstance3D.set_surface_override_material` proportional zum
  HP-Verlust rot ein (3D-Pendant zum `Color.lerp` auf dem 2D-`ColorRect`).
  Bei 0 HP `queue_free()` — kein Wiederbeleben.
- **Heilung** (`TestTrupp._handle_healing`): aktiv, wenn `hp < MAX_HP`, seit
  dem letzten Treffer `HEAL_DELAY_AFTER_DAMAGE` (4s) vergangen sind, die
  Einheit innerhalb `HEAL_RADIUS` (3 Weltmeter) der `HomeBase`-Testbox
  (Gruppe `"home_base_test"`) steht und `_base_medicine > 0` — verbraucht 1
  Medizin pro geheiltem HP, genau wie im 2D-Original, nur mit einer
  einfachen Test-Variable (`_base_medicine`, jetzt **pro Trupp-Instanz**
  statt global) statt eines echten `HomeBase.gd`-Ressourcenmodells (siehe
  `docs/base.md` fürs Original).
- **Hunger** (`_handle_hunger`, `_current_move_speed`, `_handle_eating`):
  sinkt kontinuierlich, halbiert `MOVE_SPEED` unter `HUNGER_LOW_THRESHOLD`
  (30), wird beim Stehen an der `HomeBase` gegen `_base_food` gegessen
  (`EAT_INTERVAL`/`EAT_AMOUNT`) — 1:1 dieselben Werte wie `docs/survivor.md`.
- **`HomeBase`-Testbox:** gelbe Box (`docs/world.md`-Konvention: Home-Base
  ist gelb/groß) bei `Vector3(0, 0.75, 10)`, bewusst außerhalb von
  `HEAL_RADIUS` ab den Startpositionen — man muss aktiv hinlaufen, um
  Heilung/Essen zu sehen, statt dass es sofort beim Start passiv greift.
  Aktuell eine einzige, geteilte Basis für alle Peers (keine eigene pro
  Spieler wie im 2D-Original) — reicht für diesen Testzweck.
- **Debug-Tasten, weil es noch keine Zombies in 3D gibt:** `H` fügt der
  Auswahl 20 Testschaden zu (Ersatz fürs fehlende Zombie-Gefecht), `P`
  druckt HP/Hunger der Auswahl zusätzlich ins Output-Panel (bleibt als
  Log-Beleg, siehe unten). Seit dem Multiplayer-Schritt laufen beide über
  RPCs statt Direktaufruf, siehe nächster Abschnitt.
- **HUD** (`CanvasLayer` + `Label`, `_update_hud()`): zeigt `HP x/100,
  Hunger x` pro ausgewählter Einheit live an, aktualisiert jeden Frame in
  `_process()` — kein eigenes UI-Design, nur genug zum Ablesen ohne
  ständig ins Output-Panel schauen zu müssen. 3D-Vorgriff auf das, was
  `docs/survivor.md` unter "Was fehlt" (Healthbar/Hunger-Feedback) noch
  offenlässt.

## Multiplayer (vorgezogen, nicht erst beim finalen Verkabeln)

`ARCHITECTURE.md` und der ursprüngliche Plan oben stuften Networking als
dimensionsunabhängig ein und legten die eigentliche Verkabelung ans Ende
(Schritt 3: "wenn alle Einzelteile stehen"). Auf Wunsch vorgezogen: statt am
Schluss alle Systeme auf einmal netzwerkfähig zu machen, bekommt jede
Entity ihr Multiplayer-Verhalten direkt in ihrem eigenen Migrationsschritt
— hier also zusammen mit Survivor/`TestTrupp`. Zombie/HomeBase/GuardPost
übernehmen künftig direkt dasselbe Muster, statt es am Ende neu herzuleiten.

**`TestTrupp.gd` + `.tscn` (neu, ersetzt das bisherige `Trupp1` in
`World3DTest.tscn`):** Eigene kleine Szene statt der bisherigen
Dictionary-Logik in `World3DTest.gd`, weil jetzt mehrere Instanzen (eine pro
Peer) gleichzeitig existieren und jede ihren eigenen Zustand (HP, Hunger,
Bewegungsziel) braucht — 1:1 dasselbe Host-autoritative RPC-Muster wie
`scenes/entities/survivor/Survivor.gd` (`docs/survivor.md`):

- `order_move(target, requesting_peer_id)` / `order_search(target,
  building_name, requesting_peer_id)` — `@rpc("any_peer", "call_local",
  "reliable")`, aufgerufen per `unit.order_move.rpc_id(1, ...)` von
  `World3DTest._select_at()`. Läuft nur, wenn `multiplayer.is_server()` **und**
  `requesting_peer_id == owner_peer_id` — dieselbe vereinfachte
  Vertrauensannahme wie im 2D-Original (siehe `docs/survivor.md`, "Bekannte
  Grenzen": `requesting_peer_id` wird ungeprüft vertraut).
- `request_test_damage(requesting_peer_id)` — Debug-Ersatz fürs fehlende
  Zombie-Gefecht in 3D, aus demselben Grund als RPC statt Direktaufruf: ein
  Client, der Taste `H` drückt, muss den Schaden beim simulierenden Host
  auslösen, nicht nur lokal bei sich selbst.
- `_sync_state(position, hp, hunger)` — `@rpc("authority", "call_local",
  "unreliable_ordered")`, jeden Frame vom Host gesendet. **Abweichung vom
  2D-Original:** dort sind `_sync_position` und `_sync_hp` getrennte RPCs;
  hier zu einer zusammengefasst, weil beide dieselbe
  Zustellungs-Begründung teilen (gelegentlicher Verlust okay, Reihenfolge
  muss stimmen) und weil `hunger` hier zusätzlich mitgeschickt wird — anders
  als im 2D-Original (das laut `docs/survivor.md` "bewusst kein Sync von
  hunger" macht, weil es dort noch kein Hunger-HUD gibt). Unser 3D-HUD zeigt
  Hunger aber schon an, deshalb muss auch die eigene Instanz beim
  nicht-simulierenden Peer den aktuellen Wert kennen.
- `_die()` — `@rpc("authority", "call_local", "reliable")`, Permadeath wie
  im Original.
- **Autorität bleibt immer Default (Peer 1 = Host)**, wie bei `Survivor.gd`
  — anders als beim Commander wird hier `set_multiplayer_authority()` nie
  auf den jeweiligen Eigentümer umgesetzt. `owner_peer_id` ist rein Daten,
  keine Godot-Autorität, geprüft von Hand in jeder RPC-Funktion.

**`World3DTest.gd` übernimmt jetzt zusätzlich die Commander-Rolle:**

- **Kein Lobby-Flow.** Diese Testszene startet direkt per F6, ohne
  MainMenu/Lobby. Host/Join läuft über zwei Debug-Tasten: **`1`** ruft
  `NetworkManager.host_game()`, **`2`** ruft
  `NetworkManager.join_game("127.0.0.1")` — dieselben Autoload-Funktionen
  wie im echten Spiel (`docs/networking.md`), nur ohne die UI drumherum.
  **Wichtig:** dadurch spawnt jetzt **kein** Trupp mehr automatisch beim
  Szenenstart — `1` drücken ist auch für Solo-Tests nötig (entspricht dem
  echten Spiel, wo man ebenfalls immer hostet, auch alleine).
- **Spawnen reaktiv statt einmalig:** `World.gd` spawnt einmalig beim
  Betreten der Szene (`_spawn_all_players()`, siehe `docs/world.md`) — hier
  gibt es diesen festen Startpunkt nicht, also abonniert `_ready()` stattdessen
  `NetworkManager.player_connected` und spawnt reaktiv (`_on_player_connected`,
  nur host-seitig) für jeden Peer, der dazukommt, egal ob beim `host_game()`
  selbst (Peer 1) oder später per `join_game()`.
- **Auswahl jetzt eigentumsgeprüft:** `_select_at()` verweigert die Auswahl
  fremder `"selectable"`-Treffer (`hit.owner_peer_id != multiplayer.get_unique_id()`).
  Beim 2D-Commander ist das implizit gelöst (jeder Spieler hat nur seine
  eigene Kamera/Szene-Instanz) — diese Testszene hat weiterhin eine einzige,
  geteilte Kamera für alle Peers (Commander/Kamera-Spawning pro Peer war
  nicht Teil dieses Schritts), deshalb die explizite Prüfung.

**Bug gefunden und behoben (späte Peers sahen bereits gespawnte Trupps
nicht):** Erster Test mit 2 Instanzen zeigte nur einen Trupp statt zwei —
Ursache ist eine bekannte Godot-Lücke: `MultiplayerSpawner` repliziert
bereits gespawnte Nodes **nicht automatisch** an Peers, die erst später
beitreten (nur Peers, die zum Zeitpunkt des `spawn()`-Aufrufs schon
verbunden sind, bekommen den Node). Der Host-Trupp (gespawnt bevor der
Client joint) tauchte deshalb beim Client nie auf. Fix in
`_on_player_connected()`: bevor der neue Peer seinen eigenen Trupp bekommt,
schickt der Host für jeden bereits existierenden Trupp gezielt eine
`_catch_up_spawn.rpc_id(peer_id, ...)` **nur an diesen einen neuen Peer**
(`@rpc("authority", "reliable")`, baut lokal per `add_child()` eine Kopie,
umgeht bewusst `trupp_spawner.spawn()`, weil das an **alle** Peers
broadcasten und bei den längst verbundenen Duplikate erzeugen würde).
Jeder Trupp trägt dafür jetzt zusätzlich `trupp_id: int` (statt die ID aus
dem Node-Namen zu parsen). **Praktische Konsequenz für Zombie/HomeBase/
GuardPost:** dasselbe Nachliefer-Muster brauchen alle künftig dynamisch
gespawnten Entity-Typen, sobald spätes Beitreten getestet wird — nicht nur
Trupps.

**Echter Lobby-Schritt statt sofortigem Reaktiv-Spawn:** Auf Nutzerwunsch
zusätzlich ein kleiner Lobby-Flow angelehnt an `scenes/lobby/Lobby.gd`
(`docs/networking.md`): nach Host/Join (`ConnectUI`) erscheint `LobbyUI`
(Spielerzähler + `Start`-Button, nur beim Host sichtbar —
`start_button.visible = multiplayer.is_server()`, exakt wie im 2D-Original).
Erst ein Klick auf `Start` löst `_rpc_start_game()`
(`@rpc("authority", "call_local", "reliable")`) aus, das **alle zu diesem
Zeitpunkt verbundenen Peers auf einmal** durchgeht
(`NetworkManager.players.keys()`) und für jeden `_spawn_for_peer()` aufruft
— vorher passierte das Spawnen sofort reaktiv bei jedem einzelnen Connect
(`_on_player_connected`), was ohne Lobby-Anzeige wie ein Bug aussah (siehe
oben). Peers, die **nach** dem Start noch dazustoßen, laufen weiterhin über
`_on_player_connected` → `_spawn_for_peer()` (Guard `_game_started`
entscheidet, welcher Pfad greift). `_spawn_for_peer()` ist reines
Refactoring der alten `_on_player_connected`-Logik, unverändert im
Verhalten (inkl. Nachliefer-RPCs).

## Größere Karte + mehr Gebäude + mehr Abstand zwischen Spielern

Auf Nutzerwunsch, im selben Zug wie der Lobby-Schritt:

- **Boden 40×40 → 100×100** (`BoxMesh_ground`/`BoxShape3D_ground`).
- **Vier neue Gebäude** (`Building5`–`Building8`), verteilt um die
  Kartenmitte (`±15` auf X/Z) — zusammen mit den ursprünglichen vier
  (`±6`) acht Gebäude, die den mittleren Bereich der Karte füllen.
- **`START_POSITIONS`/`HOME_BASE_POSITIONS` komplett neu**, jetzt in den
  vier Ecken der größeren Karte (`±30`/`±35`) statt eng beieinander bei
  `z≈4`/`z≈10` — viel Abstand zwischen den Spielern zum Ausbreiten, dabei
  bleiben die Gebäude in der Mitte für alle gleich erreichbar. Trupp-Start
  liegt weiterhin 5 Einheiten näher zur Mitte als die eigene Home-Base
  (grober 3D-Vorgriff auf `SURVIVOR_OFFSET`, siehe `docs/world.md`).
- **Alle acht Gebäude jetzt mit eigener Größe + Farbnuance** (eigenes
  `BoxMesh`/`BoxShape3D`/`StandardMaterial3D`-Trio pro Gebäude statt einem
  geteilten Set für alle) — Vorbild ist `World.tscn`s 2D-Original, wo jedes
  der vier Platzhalter-Gebäude schon immer eigene Größe/Farbe hatte. Rein
  optische Auflockerung, keine Funktionsänderung (`"searchable"`-Gruppe,
  Loot-Platzhalter-Logik gibt es in 3D ohnehin noch nicht, siehe
  "World-Boden/Gebäude" oben).

## ConnectUI/LobbyUI jetzt Vollbild, HUD zeigt eigenen Trupp permanent

Zwei weitere Politur-Wünsche im selben Schritt:

- **`ConnectUI`/`LobbyUI` verdecken jetzt die ganze Karte** (`Background`:
  `ColorRect` mit vollem Anchor-Rect `0,0`–`1,1`, Panel zentriert per
  `anchor_*=0.5` + negative/positive Offsets) statt als kleines Panel in
  der Ecke, hinter dem Boden/Gebäude schon sichtbar waren — passt zum
  echten Spiel, wo man vor `IN_GAME` ebenfalls nichts von der Welt sieht.
  Nebeneffekt: der vollflächige `ColorRect` (Standard-`mouse_filter` =
  `STOP`) blockt nebenbei auch Mausklicks in die 3D-Welt, solange der
  Screen offen ist — man kann also während Connect/Lobby nicht versehentlich
  schon Kamera-Klicks auslösen.
- **HUD zeigt den Status des eigenen Trupps jetzt permanent** (`Eigener
  Trupp — HP x/100, Hunger x`), nicht erst nach Anklicken —
  `_find_own_trupp()` sucht in `trupps_container` nach
  `owner_peer_id == multiplayer.get_unique_id()`. Da aktuell nur ein Trupp
  pro Peer existiert, deckt das dieselbe Information ab wie die vorherige
  `selected`-basierte Anzeige; wird relevant, sobald Rekrutierung (siehe
  `docs/recruitment.md` fürs 2D-Original) mehrere Trupps pro Peer erlaubt.

**Zweiter Bug/UX-Lücke gefunden, dann durch echten Host/Join-Screen
ersetzt:** Ohne Lobby-UI war von außen nicht erkennbar, dass man erst
etwas drücken muss — ein Test mit 2 Instanzen zeigte in beiden Fenstern nur
die statische Basis + Gebäude, was wie ein Spawn-Bug aussah, tatsächlich
aber schlicht daran lag, dass noch niemand gehostet/gejoint hatte. Erster
Fix war ein reiner Text-Hinweis im HUD; auf Nutzerwunsch daraus direkt ein
richtiger Screen geworden:

- **`ConnectUI`** (`CanvasLayer` mit `Panel`/`VBoxContainer`): `Host`-Button
  → `NetworkManager.host_game()`; IP-Feld (Default `127.0.0.1`) +
  `Join`-Button → `NetworkManager.join_game(address)` — dasselbe Muster wie
  `MainMenu.gd` (`docs/networking.md`), nur eingebettet statt einer eigenen
  Szene. Verschwindet (`connect_ui.hide()`) bei erfolgreichem Host sofort,
  bei Join erst über das `connection_succeeded`-Signal (Verbindung ist
  asynchron, siehe `docs/networking.md`) — ein `StatusLabel` zeigt
  "Verbinde..." bzw. Fehlermeldungen in der Zwischenzeit. Ersetzt die
  anfänglichen Debug-Tasten `1`/`2` komplett (entfernt aus
  `_handle_debug_key`), `H`/`P` bleiben.

**Eigene Home-Base pro Peer statt einer geteilten Testbox:** Auf
Nutzerwunsch zusätzlich zum Screen — `ARCHITECTURE.md` sieht "Jeder Spieler
hat seine eigene Basis/Kolonie, nicht geteilt" vor, die bisherige einzelne
`HomeBase`-Testbox widersprach dem eigentlich schon. Jetzt: eigene Szene
`TestHomeBase.gd`/`.tscn` (nur `owner_peer_id`, keine eigene Simulation
nötig — Heilung/Essen laufen weiterhin in `TestTrupp.gd`), gespawnt über
`HomeBaseSpawner`/`HomeBases` nach demselben Muster wie die Trupps
(reaktiv auf `player_connected`, plus dasselbe `_catch_up_home_base()`
gegen dieselbe Spätbeitritts-Lücke wie oben). `TestTrupp._find_home_base()`
filtert jetzt nach `owner_peer_id` statt einfach die erste gefundene Base
zu nehmen. Positionen in `HOME_BASE_POSITIONS`, gleicher x-Versatz wie
`START_POSITIONS`, nur bei `z=10` statt `z=4`.

## Zombie (vierter Migrationsschritt)

`TestZombie.gd`/`.tscn` (neu), 3D-Testversion von `Zombie.gd`
(`docs/zombies.md`) — wandert ziellos um seinen Spawn-Punkt, erkennt und
verfolgt einen nahen `TestTrupp`, beidseitiger Schaden bei Kontakt. Das
Lärm-System (gegenseitiges Alarmieren anderer Zombies) kam zunächst bewusst
noch nicht mit, wurde aber kurz danach als eigener kleiner Folgeschritt
nachgezogen (siehe "Lärm-System" unten).

- Grüne Kapsel (`_update_color()`, dunkelt statt rot zu werden — Pendant zu
  "Zombie-Quadrat zunehmend dunkler" im 2D-Original), sonst strukturell wie
  `TestTrupp` (`StaticBody3D` + `Mesh`/`Collision`).
- **`"selectable"` statt einer eigenen `"living"`-Gruppe:** Zombies suchen
  ihr Angriffsziel über `get_tree().get_nodes_in_group("selectable")` — im
  2D-Original gibt es eine eigene `"living"`-Gruppe nur für Survivor, hier
  bewusst wiederverwendet, weil `"selectable"` aktuell ohnehin ausschließlich
  `TestTrupp`-Instanzen enthält (keine Verhaltensänderung, nur ein Name
  gespart). Müsste getrennt werden, sobald es weitere `"selectable"`-Typen
  gibt, die keine Zombie-Ziele sein sollen.
- **Wandern/Verfolgen/Angreifen** 1:1 nach `docs/zombies.md`-Beschreibung:
  `_update_chase_target()` mit getrenntem `DETECT_RADIUS` (neues Ziel
  finden, 8 Weltmeter) und größerem `GIVE_UP_RADIUS` (Ziel behalten, 14) —
  derselbe Bugfix-Grund wie im 2D-Original (siehe dort, "Gefundener Bug").
  Im `ATTACK_RANGE` (1.2) beidseitiger Schaden pro `ATTACK_COOLDOWN` (1s):
  `ATTACK_DAMAGE` (10) an den Trupp, danach (nur falls der Trupp den Treffer
  überlebt) `COUNTER_DAMAGE` (15) an sich selbst — bei `MAX_HP = 40`
  rechnerisch nach 3 Treffern tot, exakt wie im 2D-Original.
- **Kein RPC für den Schaden selbst** (`take_damage()` ist eine normale
  Funktion) — läuft ausschließlich host-seitig, wie im 2D-Original
  begründet: beide Seiten (Zombie-KI und Trupp-Schaden) simulieren ohnehin
  nur auf dem Host, erst das Ergebnis (`_sync_state`/`_die`) wird repliziert.
- **Kein Peer-Bezug beim Spawnen** (anders als Trupp/Home-Base): feste
  `ZOMBIE_SPAWN_POINTS` (4, nahe der mittleren Gebäude-Cluster, klar
  getrennt von den Spieler-Ecken), gespawnt einmalig in `_rpc_start_game()`
  zusammen mit den Trupps/Home-Bases aller zu dem Zeitpunkt verbundenen
  Peers. Spät beitretende Peers bekommen die schon existierenden Zombies
  trotzdem über dasselbe `_catch_up_zombie()`-Muster nachgeliefert wie bei
  Trupp/Home-Base (Zombies sind sonst nicht auswähl-/befehligbar, sollen
  aber für alle sichtbar sein).

## Lärm-System (Nachtrag zum Zombie-Schritt)

`TestZombie.gd` bekommt jetzt auch das Lärm-System aus `docs/zombies.md`,
das im Zombie-Schritt bewusst ausgeklammert war:

- `_ready()` fügt jeden Zombie zusätzlich zur Gruppe `"zombie"` hinzu (per
  `add_to_group()` zur Laufzeit — **kein** Gruppen-Bug wie beim `groups =
  [...]`-Property-Zeilen-Fund oben, das war spezifisch für `.tscn`-Dateien,
  `add_to_group()` im Skript funktioniert unabhängig davon immer zuverlässig).
- Bei jedem Angriffs-Tick ruft `_try_attack()` zusätzlich
  `_alert_nearby_zombies(_chase_target)` auf: geht alle Nodes in Gruppe
  `"zombie"` durch, jeder andere Zombie innerhalb `NOISE_RADIUS` (11
  Weltmeter, zwischen `DETECT_RADIUS` 8 und `GIVE_UP_RADIUS` 14 — dieselbe
  Anordnung wie im 2D-Original) übernimmt sofort dasselbe Verfolgungsziel
  über die neue öffentliche Methode `alert(target)`.
- `alert(target)` setzt einfach `_chase_target = target` — öffentliche
  Methode statt direktem Zugriff auf die private Variable eines anderen
  Zombies, wie im 2D-Original begründet (siehe `docs/zombies.md`).
- `NOISE_RADIUS` bewusst kleiner als `GIVE_UP_RADIUS`, aus demselben Grund
  wie im 2D-Original: ein frisch alarmierter Zombie ist per Definition
  weiter weg als `DETECT_RADIUS` (sonst hätte er den Trupp schon selbst
  bemerkt) — `_update_chase_target()` läuft jeden Frame vor der Bewegung
  und würde ein zu weit entferntes Ziel sofort wieder verwerfen, wäre
  `GIVE_UP_RADIUS` nicht extra größer.

## HomeBase (echtes Ressourcenmodell statt Testbox)

`TestHomeBase.gd` bekommt jetzt das echte Ressourcenmodell aus
`HomeBase.gd` (`docs/base.md`), statt einer reinen Positions-/
Eigentumsmarkierung:

- `resources: Dictionary` (`food`/`materials`/`medicine`/`ammo`), initialisiert
  aus `START_RESOURCES` (`.duplicate()`, damit nicht alle Instanzen dieselbe
  Dictionary-Referenz teilen) — ursprünglich dieselben Startwerte wie im
  2D-Original (`20/20/5/10`), im GuardPost-Schritt auf Nutzerwunsch erhöht
  auf `food: 30, materials: 60, medicine: 15, ammo: 20`, damit sich Bauen
  (kostet 30 Baumaterial) sofort testen lässt, ohne erst echtes Scavenging
  zu brauchen (siehe "GuardPost" unten).
- `add_resources(delta: Dictionary)` (`@rpc("authority", "call_local",
  "reliable")`) addiert `delta` auf `resources` und feuert
  `resources_changed(resources)` — identisch zum 2D-Original.
- `TestTrupp._handle_healing()`/`_handle_eating()` verbrauchen jetzt echte
  Medizin/Nahrung aus der **eigenen** Base (`base.resources.get(...)`,
  `base.add_resources.rpc({...: -1})`) statt der bisherigen lokalen
  Test-Zahlen (`_base_medicine`/`_base_food`, jetzt entfernt) — 1:1 dieselbe
  Logik wie `docs/survivor.md`, "Medizin-Verbrauch"/"Essen".
- HUD (`World3DTest._update_hud()`) zeigt zusätzlich zum Trupp-Status alle
  vier Ressourcenwerte der eigenen Base (`_find_own_home_base()`, analog zu
  `_find_own_trupps()`).

**Bewusst nicht enthalten** (kommt erst mit echtem Bauen/Gebäudetypen):
Zonen-Erweiterung/Claiming, Verderb von Nahrung über Zeit, Lagerkapazität —
identisch zum Umfang, den `docs/base.md` für das 2D-Original selbst
beschreibt. Scavenging speist die Base in 3D weiterhin nicht real (nur der
Log-Platzhalter aus dem "World-Boden/Gebäude"-Schritt) — das war für diesen
Schritt bewusst ausgeklammert.

## GuardPost (Bauen)

`TestGuardPost.gd`/`.tscn` (neu), 3D-Testversion von `GuardPost.gd`
(`docs/building.md`) — Bau-Timer, automatisches Feuern auf Zombies
(inklusive Lärm-Alarmierung), aber nur solange mindestens ein Trupp
stationiert ist. Auf Nutzerwunsch gleich der volle Umfang inklusive
Arbeiter-Zuweisung, nicht nur "baut und feuert sofort".

**Erster Schritt — eigenes Baumenü statt Taste `B` + Weltklick:** ein
eigener `BuildUI`-Screen (unten links, dauerhaft sichtbar, kein Vollbild wie
Connect/Lobby) mit einem Button `"Wachposten bauen (30 Baumaterial)"`, der
zunächst direkt an einem festen Versatz zur eigenen Home-Base baute, ohne
Weltklick-Zielwahl — echte Platzierung kam als eigener Folgeschritt (siehe
"GuardPost-Platzierung" unten).

- **`request_build_guard_post(build_position, requesting_peer_id)`**
  (`@rpc("any_peer", "call_local", "reliable")`, auf `World3DTest.gd` wie im
  2D-Original auf `World.gd`) prüft der Reihe nach: eigene Home-Base
  gefunden (`_find_home_base_for_peer`), nah genug (`GUARD_POST_BUILD_RADIUS`,
  8 Weltmeter), genug Ressourcen (`GUARD_POST_COST`, 30 Baumaterial). Erst
  wenn alle drei bestehen: Kosten abziehen, `guard_post_spawner.spawn()`.
- **Bauphase → fertig:** `_build_timer` zählt `BUILD_TIME` (5s) runter,
  Marker gelblich; danach `_set_built_visual.rpc()` (`call_local` Pflicht,
  sonst sieht der Host den eigenen fertigen Wachposten nie grau werden —
  dasselbe wiederkehrende Muster wie bei `TestTrupp._sync_state`).
- **Feuern:** `_try_fire()` läuft nur, solange `_stationed_workers` (rein
  host-intern, siehe unten) nicht leer ist — sucht per
  `get_tree().get_nodes_in_group("zombie")` das nächste Ziel in
  `FIRE_RANGE` (6), schädigt direkt per Funktionsaufruf (`target.take_damage()`,
  keine RPC nötig, läuft schon host-seitig) und alarmiert danach alle
  Zombies in `FIRE_NOISE_RADIUS` (13, größer als Zombies' eigener
  `NOISE_RADIUS`) über `zombie.alert(target)` — **bewusst dupliziert** statt
  einer geteilten Utility-Funktion mit `TestZombie._alert_nearby_zombies()`,
  genau wie im 2D-Original begründet (`docs/building.md`, "Bewusst
  dupliziert statt geteilt").
- **Arbeiter-Zuweisung über UI statt Weltklick** (wie im 2D-Original):
  `World3DTest._refresh_worker_ui()` baut alle `WORKER_UI_REFRESH_INTERVAL`
  (0.5s) die `WorkersList` im `BuildUI`-Panel komplett neu auf (gleiches
  Muster wie `Lobby._refresh_player_list()`), eine Zeile pro eigenem
  Wachposten mit Button `"Arbeiter schicken"`. Klick ruft
  `post.request_worker.rpc_id(1, peer_id)` — der Wachposten sucht sich
  selbst einen freien Trupp (`_find_idle_trupp`, wieder über die
  wiederverwendete `"selectable"`-Gruppe) und ruft `trupp.order_station(self)`
  auf (plain Funktionsaufruf, kein eigenes RPC nötig — beide Seiten laufen
  schon host-seitig, da `request_worker` selbst schon die RPC-Grenze war).
- **`TestTrupp.gd` neu:** `is_idle()` (`true`, wenn weder unterwegs noch
  stationiert), `order_station(post)` (merkt sich Ziel-Wachposten,
  registriert sich per `post.register_worker(self)` bei Ankunft),
  `_unstation()` (meldet beim alten Wachposten ab — aufgerufen zu Beginn von
  `order_move`/`order_search` und in `_die()`, damit ein Wachposten nicht mit
  einer toten/abgezogenen Worker-Referenz "besetzt" bleibt).
- **`worker_count`** ist die einzige an alle Peers replizierte Stelle
  (`_sync_worker_count`-RPC) — die eigentliche `_stationed_workers`-Liste
  mit echten Node-Referenzen bleibt host-intern, weil Node-Referenzen nicht
  über RPCs verschickt werden können (identische Begründung wie im
  2D-Original).

**Zwei Trupps pro Peer statt einem** (auf Nutzerwunsch, `SECOND_TRUPP_OFFSET`
in `_spawn_for_peer()`): ohne Rekrutierung (gibt es in 3D noch nicht) hätte
ein Spieler mit nur einem Trupp keinen freien Trupp mehr übrig, sobald der
eine am Wachposten stationiert ist — zwei Trupps machen das Zusammenspiel
sofort testbar. `_update_hud()` zeigt seitdem eine Zeile pro eigenem Trupp
statt nur einem (`_find_own_trupps()` statt `_find_own_trupp()`).

## Echtes Scavenging/Loot

Bisher loggte `order_search()` nur die Absicht und ließ den Trupp hinlaufen
(siehe "World-Boden/Gebäude" oben). Jetzt vollständig wie
`docs/scavenging.md`:

- **`TestBuilding.gd`** (neu, direkt an alle acht `Building1`–`8` in
  `World3DTest.tscn` angehängt, kein eigenes `.tscn` — wie
  `scenes/world/Building.gd` an den 2D-`ColorRect`s): `@export var loot:
  Dictionary` (unterschiedliche Werte pro Gebäude, an die real existierenden
  acht angepasst statt nur vier), `is_looted: bool`, `mark_looted()`
  (`@rpc("authority", "call_local", "reliable")`) setzt `is_looted` und
  färbt das Gebäude dunkelgrau — identisch zum 2D-Original.
- **`TestTrupp.order_search(target, building_path, requesting_peer_id)`**
  merkt sich `building_path` jetzt als `NodePath` (nicht mehr nur den Namen
  fürs Log) — Gebäude sind statisch in `World3DTest.tscn` verankert (kein
  `MultiplayerSpawner`), derselbe Pfad zeigt auf jedem Peer auf denselben
  Node, exakt wie im 2D-Original begründet (`docs/scavenging.md`, "Warum
  building_path als NodePath quer durchs Netzwerk funktioniert").
  `World3DTest._select_at()` übergibt dafür `building.get_path()` statt
  `building.name`.
- **Ablauf bei Ankunft** (`_handle_movement()`, letzter Wegpunkt erreicht):
  ist `_pending_building_path` gesetzt, startet `_searching = true` +
  `_search_timer = SEARCH_DURATION` (3s, wie im 2D-Original) statt einfach
  stehen zu bleiben. `_process_search()` zählt herunter, `_finish_search()`
  löst den Node über `get_node_or_null(_pending_building_path)` auf, bricht
  ab, falls das Gebäude inzwischen schon geplündert wurde, sonst
  `mark_looted.rpc()` + `_deposit_loot(building.loot)` →
  `base.add_resources.rpc(loot)` an die **eigene** Home-Base.
- **Abbrechbar:** ein neuer `order_move`/`order_station` ruft `_cancel_search()`
  auf (setzt `_searching = false`, leert `_pending_building_path`) — eine
  laufende oder noch nicht begonnene Suche läuft nicht im Hintergrund weiter,
  wenn der Trupp anders befohlen wird. `is_idle()` berücksichtigt `_searching`
  entsprechend (ein suchender Trupp gilt nicht als frei für GuardPost-Arbeit).

## Wegpunkte statt festem Bewegungsziel

Auf Nutzerwunsch, direkt nach GuardPost: `TestTrupp._move_target`/
`_has_target` (ein einzelnes festes Ziel) ersetzt durch `_waypoints: Array`
(eine Schlange). **Kein neues Eingabegerät nötig** — Shift+Klick, das
`_select_at()` beim Klick auf ein `"selectable"`-Objekt schon für additive
Mehrfachauswahl nutzt, übernimmt beim Klick auf **Boden** eine zweite Rolle:

- **Linksklick auf den Boden (ohne Shift):** ersetzt die ganze Schlange
  durch das eine neue Ziel — wie bisher.
- **Shift+Linksklick auf den Boden:** hängt das neue Ziel hinten an die
  bestehende Schlange an, statt sie zu ersetzen — Standard-RTS-Verhalten für
  Wegpunkte.
- `order_move(target, requesting_peer_id, queue)` bekommt dafür einen
  dritten Parameter `queue` (`= additive` aus `_select_at()`); `queue =
  false` leert `_waypoints` und `_unstation()`t zuerst (wie der bisherige
  Ersatz-Fall), `queue = true` hängt nur an.
- `_handle_movement()` läuft immer auf `_waypoints[0]` zu und poppt es bei
  Ankunft (`pop_front()`) — der nächste Wegpunkt (falls vorhanden) wird
  automatisch im nächsten Frame angelaufen, ganz ohne Extra-Logik.
- `order_search()`/`order_station()` **ersetzen weiterhin immer** die ganze
  Schlange (setzen sie auf genau ein Element) statt anzuhängen — Durchsuchen
  und Stationieren sind bewusst einzelne, unmittelbare Ziele, kein
  Warteschlangen-Fall. Stationierung (`_pending_station_target`) greift
  deshalb zuverlässig erst, wenn `_waypoints` durch das Abarbeiten der
  Schlange leer wird (der letzte/einzige Wegpunkt).
- `is_idle()` entsprechend auf `_waypoints.is_empty()` umgestellt.

**Bewusst nicht enthalten:** keine visuelle Anzeige der Wegpunkte in der
Welt (z. B. Linien/Marker) — nur die Funktionalität selbst.

## Kontrollgruppen

Auf Nutzerwunsch, direkt danach: RTS-Standard-Kontrollgruppen in
`World3DTest.gd`, rein lokal/peer-seitig (keine Netzwerklogik nötig,
`selected` war das schon vorher).

- `_control_groups: Dictionary` (Gruppennummer 1–9 → Array eigener
  Einheiten).
- **Strg+Zifferntaste** (`event.ctrl_pressed`): weist die aktuelle
  `selected`-Auswahl dieser Gruppennummer zu (`.duplicate()`, damit
  spätere Änderungen an `selected` die gespeicherte Gruppe nicht
  mitverändern).
- **Zifferntaste allein:** wählt die gespeicherte Gruppe wieder aus, egal
  wo die Einheiten inzwischen stehen — dabei werden ungültige Einträge
  (z. B. inzwischen gestorbene Trupps) automatisch übersprungen
  (`is_instance_valid`), ohne die Gruppe selbst zu bereinigen.
- Abgefangen in `_unhandled_input()`, bevor `_handle_debug_key()` (H/P)
  greift — `KEY_1`–`KEY_9` sind dafür reserviert.

**Nachtrag — UI statt nur Tastatur:** Klick-Auswahl in der 3D-Welt +
Strg+Zifferntaste war umständlich, deshalb zusätzlich ein `UnitsUI`-Panel
(unten rechts, dauerhaft sichtbar): pro eigenem Trupp eine Zeile
(`_refresh_units_ui()`, gleiches Neuaufbau-Muster wie `_refresh_worker_ui()`)
mit `"Wählen"`-Button (setzt `selected` direkt auf genau diesen Trupp) und
drei Umschalt-Buttons `1`/`2`/`3` (`_on_toggle_group_pressed()`, fügt den
Trupp der Gruppe hinzu/entfernt ihn — Häkchen `✓` zeigt aktuelle
Mitgliedschaft). Darüber drei `"Gruppe N"`-Buttons, die dieselbe
`_handle_control_group_key(n, false)`-Auswahl-Logik wie die Zifferntaste
aufrufen (`.bind()`). Tastatur-Variante bleibt zusätzlich nutzbar, beide
Wege schreiben in dieselbe `_control_groups`-Struktur.

## Kamera startet an der eigenen Home-Base

Auf Nutzerwunsch: `_create_home_base()` setzt `pivot.position` auf die
eigene Home-Base-Position, sobald `data["peer_id"] ==
multiplayer.get_unique_id()` — läuft unabhängig davon, ob die Base gerade
über `_rpc_start_game()` (Host) oder per `_catch_up_home_base()` (später
beigetretener Peer) erzeugt wird, weil beide Pfade über dieselbe
`_create_home_base()`-Funktion laufen. Vorher startete die Kamera immer am
Kartenursprung (0,0,0) — bei einer 100×100-Karte mit Spieler-Ecken bei
`±30`/`±35` leerer Boden weit weg von der eigenen Basis.

## Rechtsklick: Ziehen rotiert, reiner Klick stoppt

Auf Nutzerwunsch: rechte Maustaste war bisher ausschließlich für
Kamera-Rotation (Halten + Ziehen) belegt. Jetzt unterschieden über
`_right_click_dragged: bool` (`false` bei Tastendruck, `true` sobald
während des Haltens tatsächlich eine `InputEventMouseMotion` ankommt):

- **Ziehen** (mindestens eine Mausbewegung während gehaltener rechter
  Taste): wie bisher, rotiert + neigt die Kamera.
- **Reiner Klick** (Loslassen, ohne dass sich die Maus dazwischen bewegt
  hat): ruft `_stop_selected_units()` auf — schickt `order_stop()` an alle
  ausgewählten Trupps.
- **`TestTrupp.order_stop(requesting_peer_id)`** (`@rpc("any_peer",
  "call_local", "reliable")`): `_unstation()` + `_cancel_search()` +
  `_waypoints.clear()` — hält die Einheit sofort an, egal ob sie gerade
  lief, suchte oder stationiert war. Erspart den Umweg, extra auf den
  Boden neben der Einheit klicken zu müssen, nur um sie anzuhalten.

## GuardPost-Platzierung: Baumodus + Weltklick statt fixem Versatz

Ersetzt den bisherigen festen `GUARD_POST_OFFSET` zur eigenen Home-Base
durch echten Baumodus + freie Platzierung — jetzt 1:1 wie im 2D-Original
(`Commander._build_mode`, `docs/building.md`), nur der Auslöser ist der
`BuildUI`-Button statt Taste `B`:

- **`_build_mode: bool`** (`World3DTest.gd`) wird durch Klick auf den
  `BuildUI`-Button umgeschaltet (`_on_toggle_build_mode_pressed()`) —
  Button-Text wechselt zwischen `BUILD_BUTTON_TEXT` und
  `BUILD_MODE_ACTIVE_TEXT` (`"Baumodus aktiv — in die Welt klicken"`), da es
  wie im 2D-Original sonst kein visuelles Feedback für den aktiven Modus
  gibt (Cursor ändert sich nicht).
- **`_select_at()` prüft `_build_mode` als Allererstes**, noch vor Auswahl/
  Bewegung/Gebäude-Fall — der nächste Linksklick ist dann eine
  Bauplatz-Anfrage (`request_build_guard_post.rpc_id(1, result.position,
  peer_id)`) an genau der angeklickten Stelle (Raycast-Trefferpunkt, egal ob
  Boden oder ein anderes Objekt), **nicht** mehr Auswahl/Bewegungsbefehl.
- **Ein-Klick-Modus wie im 2D-Original:** `_build_mode` schaltet sich nach
  dem nächsten Linksklick immer automatisch wieder ab — unabhängig davon,
  ob `request_build_guard_post()` den Bau tatsächlich zulässt (zu weit weg,
  zu wenig Ressourcen). Kein Fehler-Feedback bei Ablehnung, bewusste
  Vereinfachung wie im 2D-Original ("keine Fehlermeldung an den Spieler").
  Kein Treffer (ins Leere geklickt) schaltet ebenfalls einfach ab, ohne
  einen Bauversuch auszulösen.
- **`request_build_guard_post()` selbst unverändert** — die Prüfungen
  (eigene Base gefunden, `GUARD_POST_BUILD_RADIUS`, `GUARD_POST_COST`)
  greifen jetzt aber erstmals wirklich, weil die Zielposition nicht mehr per
  Konstruktion garantiert innerhalb des Radius liegt.
- `GUARD_POST_OFFSET`-Konstante entfernt (nicht mehr gebraucht).

## Was bewusst noch fehlt

- Keine echten 3D-Assets, nur Platzhalter-Boxen.
- Kein Pathfinding/Hindernisumgehung beim Laufen (nur Geradeaus-Interpolation),
  keine Lauf-Animation/Zustand — nur die reine Positionsbewegung.
- Kein eigener Commander/keine eigene Kamera pro Peer — eine einzige,
  geteilte Kamera für alle Peers in dieser Testszene (siehe "Multiplayer"
  oben).
- Keine visuelle Bau-Vorschau (Ghost-Mesh an der Mausposition während
  `_build_mode` aktiv ist) — wie im 2D-Original kein Feedback, ob der Modus
  gerade an ist, außer dem Button-Text.
- Kein Zonen-/Claiming-System, keine Mauern/Barrikaden, kein zweiter
  Gebäudetyp — identisch zum Umfang, den `docs/building.md` fürs
  2D-Original selbst beschreibt.
- Nicht ins echte Spiel eingebunden — `World.tscn` (2D) ist weiterhin die
  tatsächlich gespielte Welt.

## Bekannte Stolpersteine beim Testen

Diese Testszene hat beim ersten Durchgang eine ungewöhnlich lange
Fehlersuche ausgelöst — nicht wegen eines einzelnen großen Bugs, sondern
wegen **mehrerer sich überlagernder Kleinigkeiten**, die sich erst durch
systematisches Eingrenzen (Debug-Prints, Screenshots) auseinandersortieren
ließen. Der Reihe nach, damit man's beim nächsten Mal schneller erkennt:

1. **F5 statt F6:** F5 startet immer `project.godot`s Hauptszene
   (`MainMenu.tscn` → das echte 2D-Spiel), unabhängig davon, welcher
   Szenen-Tab gerade offen ist. F6 startet die **aktuell fokussierte**
   Szene — `World3DTest.tscn` muss dafür als Szenen-Tab aktiv sein (im
   FileSystem-Dock doppelklicken), nicht nur als Skript-Datei geöffnet
   sein. Dadurch lief der allererste Testdurchlauf komplett mit dem echten
   2D-`Commander.gd` statt mit dieser Szene — jeder Steuerungs-Fehlversuch
   (Q/E, `[`/`]`, mittlere Maustaste) hätte so oder so nichts bewirkt.
2. **Mittlere Maustaste nicht immer verfügbar** (Trackpads, manche Mäuse
   ohne klickbares Scrollrad) — deshalb rechte statt mittlerer Maustaste
   fürs Rotieren.
3. **Tastatur-Fokus vs. Maus-Fokus:** Nach F6 hatte das Spielfenster
   zunächst keinen Tastatur-Fokus; ein Mausklick hinein behebt das meist,
   aber wenn man anschließend zum Editor wechselt, um das Output-Panel zu
   lesen, geht der Tastatur-Fokus dabei wieder verloren — ein Tastendruck,
   der "während" des Umschauens passiert, kommt dann beim Editor an, nicht
   beim Spiel. Sichtbar wurde das erst durch einen Debug-Print, der bei
   jedem `_process()`-Tick den Tastenstatus mitgeloggt hat.
4. **Screenshots von unfokussierten Fenstern zeigen einen eingefrorenen
   Frame:** Zwei Screenshots im Abstand von über einer Minute zeigten
   exakt dasselbe Bild, obwohl die geloggte Position sich um über 200
   Einheiten verändert hatte — Godot reduziert/pausiert offenbar das
   Neuzeichnen für Fenster, die gerade nicht den OS-Fokus haben (zum
   Screenshotten musste zwangsläufig kurz weggeklickt werden). Die Logik
   lief die ganze Zeit korrekt weiter, nur sichtbar war's nicht.
5. **`PAN_SPEED` war tatsächlich zu langsam,** um es bei einem kurzen Blick
   zu bemerken — erst mit Godots eingebautem Debug-Geschwindigkeitsregler
   (oben in der Spiel-Fenster-Symbolleiste, Standard `1.0×`) auf `16×`
   gestellt wurde die Bewegung eindeutig sichtbar. Behoben durch Erhöhen von
   `PAN_SPEED` auf `30.0` (vorher `12.0`).

**Fazit fürs nächste Mal:** Bei "Steuerung tut nichts"-Berichten lohnt sich
früh ein Debug-Print direkt in der verdächtigen Funktion (nicht nur am
Auslöser), der sowohl den erkannten Input-Zustand als auch den
resultierenden Wert (hier: `Input.is_key_pressed()` **und** `global_position`
in derselben Zeile) mitloggt — das trennt zuverlässig zwischen
"Input kommt nicht an", "Logik läuft, ändert aber nichts" und
"ändert sich, wird nur nicht sichtbar/wahrgenommen".

## Der eigentliche Rendering-Bug (Punkt 5 war nur die halbe Wahrheit)

Nach Erhöhen von `PAN_SPEED` blieb das Problem: Bewegung passierte laut Log
(`global_position` änderte sich nachweislich, auch die daraus berechnete
`camera.global_position` — Godots eigene Transform-Berechnung war beweisbar
korrekt), aber im gerenderten Bild tat sich **nichts**, auch nicht bei einem
harten Sofort-Teleport um 60 Einheiten. Systematisch eingegrenzt:

- **Direkte Kamera-Positionsänderung** (`camera.position = ...`, wie beim
  Zoom) → rendert korrekt.
- **Rotation des direkten Elternteils** (`pivot.rotate_y()`) → rendert
  korrekt.
- **Positionsänderung der Wurzel** (`global_position` auf `World3DTest`
  selbst — dem **Großelternteil** der Kamera, da Kamera → Pivot →
  World3DTest) → Transform-Werte stimmen nachweislich, das Bild
  aktualisiert sich aber nicht.

**Der Unterschied war die Tiefe der Vererbung:** Änderungen am direkten
Elternteil der Kamera (Pivot) oder an der Kamera selbst haben den Renderer
zuverlässig benachrichtigt — eine Änderung zwei Ebenen weiter oben
(Großelternteil) offenbar nicht zuverlässig, trotz korrekter
Transform-Berechnung. Die genaue interne Godot-Ursache (vermutlich eine
Benachrichtigungslücke zwischen Transform-System und RenderingServer bei
mehrstufig vererbten Kamera-Transforms) ist nicht abschließend geklärt,
aber das Muster wurde mehrfach reproduziert.

**Fix:** Pan bewegt jetzt `pivot.position` statt `global_position` der
Wurzel — Pivot übernimmt damit sowohl Rotation als auch Position, beides
nachweislich zuverlässig. Die Wurzel-Node (`World3DTest`) bewegt sich gar
nicht mehr.

**Praktische Konsequenz für die weitere Migration:** Bei jeder künftigen
3D-Kamera-/Entity-Bewegung (Commander, Survivor, Zombie, …) Positions-
Änderungen möglichst **direkt am Node, der die Kamera trägt oder selbst die
Kamera ist** vornehmen, nicht über einen mehrstufig übergeordneten
Container — zur Sicherheit lieber einmal mit einem Log wie in diesem
Abschnitt verifizieren, bevor viel Folgecode draufgebaut wird.

## Testen

**Solo (1 Instanz):** `World3DTest.tscn` im FileSystem-Dock doppelklicken
(aktiver Tab), Debug → Customize Run Instances wieder auf 1 Instanz stellen
falls vom Networking-Test noch auf 2, **F6** (nicht F5, siehe oben). Es
erscheint zuerst der `ConnectUI`-Screen (Host-Button, IP-Feld + Join-Button)
— **`Host`** klicken, danach `LobbyUI` (Spielerzähler + `Start`-Button) —
**`Start`** klicken, dann verschwindet auch dieser Screen und die eigene
Kapsel + eigene gelbe Home-Base erscheinen am Startpunkt (eine der vier
Kartenecken). **Wichtig, seit dem Multiplayer-Schritt:** es spawnt nichts
mehr automatisch, auch solo nicht (entspricht dem echten Spiel: man hostet
und startet immer, auch alleine).

**Kamera:** WASD zum Pannen, **rechte Maustaste halten + Maus bewegen**
horizontal zum Rotieren (sollte sich wie eine Kamera anfühlen, die um einen
Punkt kreist, nicht wie ein Objekt, das sich selbst dreht) **und** vertikal
zum Neigen (flacher/steiler, geklemmt zwischen `TILT_MIN`/`TILT_MAX`),
Mausrad zum Zoomen.

**Auswahl + Bewegung:** Linksklick auf die eigene helle Kapsel zum Auswählen
(Output zeigt `Ausgewählt: [...]`), Shift-Linksklick für Mehrfachauswahl,
Linksklick auf freien Boden **mit Auswahl** lässt sie sichtbar dorthin
laufen (kein Teleport) — die Karte ist jetzt 100×100 groß, also ruhig weit
zur Kartenmitte pannen (WASD), um eines der jetzt acht braunen Gebäude zu
erreichen. Linksklick auf ein Gebäude **mit Auswahl** lässt sie ebenfalls
hinlaufen und loggt `Ziel gesetzt (Gebäude, durchsuchen vorgemerkt): ...`
statt des normalen Bewegungs-Logs, Linksklick auf den Boden **ohne** Auswahl
deselektiert.

**Wegpunkte:** Trupp auswählen, auf einen Bodenpunkt klicken (`Bewegungsbefehl
geschickt: ...`), **dann Shift+Linksklick** auf einen zweiten, weiter
entfernten Punkt (`Wegpunkt hinzugefügt: ...`) — der Trupp sollte zuerst
den ersten Punkt ansteuern und automatisch zum zweiten weiterlaufen, ohne
dass man dafür nochmal klicken muss. Ein normaler (nicht-Shift) Klick
während er noch unterwegs ist sollte die Schlange verwerfen und sofort zum
neuen Ziel umlenken.

**HP/Permadeath/Heilung/Hunger:** Kapsel auswählen, Taste **`H`** fügt 20
Testschaden zu — Kapsel färbt sich sichtbar rötlich, Output zeigt
`Schaden: ... HP jetzt: ...`. Taste **`P`** druckt jederzeit
`HP=... Hunger=...` der Auswahl, zusätzlich zum HUD oben links. Mehrfach `H`
drücken, bis HP auf 0 fällt → Kapsel verschwindet (`queue_free()`,
`Gestorben (Permadeath): ...` im Output) und lässt sich danach nicht mehr
auswählen — kein Wiederbeleben (die eigene Home-Base bleibt bestehen, ein
Neustart der Szene ist aktuell der einzige Weg zu einem neuen Trupp, siehe
"Was bewusst noch fehlt"). Zum Testen von Heilung: vor dem letzten Treffer
zur eigenen gelben Home-Base hinlaufen lassen (Linksklick auf den Boden
dort) und dort stehen bleiben — nach `HEAL_DELAY_AFTER_DAMAGE` (4s) ohne
weiteren Treffer sollte HP wieder steigen und die Rotfärbung zurückgehen.
Hunger sinkt von selbst über die Zeit; lange genug an der eigenen Home-Base
stehen bleiben füllt ihn wieder auf.

**Multiplayer (2 Instanzen):** Debug → Customize Run Instances → "Enable
Multiple Instances" → 2 → F6 (beide Fenster starten `World3DTest.tscn`
gleichzeitig, beide zeigen den `ConnectUI`-Screen). Im **einen** Fenster
**Host** klicken — `LobbyUI` erscheint (`Start`-Button nur hier sichtbar,
Spielerzähler zeigt `1`). Im **anderen** Fenster IP-Feld auf `127.0.0.1`
lassen und **Join** klicken (`StatusLabel` zeigt kurz "Verbinde...") — auch
hier erscheint `LobbyUI`, jetzt zeigt der Spielerzähler in **beiden**
Fenstern `2`, aber nur im Host-Fenster ist der `Start`-Button da. Im
Host-Fenster **`Start`** klicken: `LobbyUI` verschwindet in **beiden**
Fenstern gleichzeitig, und in beiden erscheinen zwei Kapseln + zwei
Home-Basen an unterschiedlichen Kartenecken (weit auseinander, siehe
"Größere Karte..." oben). Testen: im Host-Fenster nur die eigene Kapsel
lässt sich auswählen, Klick auf die andere loggt `Nicht deine Einheit: ...`
statt einer Auswahl — dasselbe umgekehrt im Client-Fenster. `H`/Bewegung/
Heilung/Hunger auf der eigenen Kapsel wirken sich in **beiden** Fenstern
sichtbar aus (Beweis der Host-Replikation) — im Client-Fenster ausgelöst,
aber vom Host simuliert. Heilung/Essen der eigenen Kapsel darf nur an der
**eigenen** Home-Base funktionieren, nicht an der des anderen Peers. HUD
zeigt zusätzlich zum Trupp-Status jetzt `Nahrung 20  Baumaterial 20
Medizin 5  Munition 10` (Startwerte) — nach mehrfacher Heilung/mehrfachem
Essen sollten `Medizin`/`Nahrung` sichtbar sinken (1 pro geheiltem HP bzw.
pro `EAT_INTERVAL`), bei 0 Medizin sollte die Heilung trotz Aufenthalt an
der Base stoppen.

**Zombies:** Nach `Start` sollten vier grüne Kapseln nahe der mittleren
Gebäude in der Kartenmitte auftauchen und ziellos herumwandern (mit Pausen
dazwischen). Eigenen Trupp per Linksklick auf den Boden in die Nähe eines
Zombies schicken (innerhalb `DETECT_RADIUS` ≈ 8 Weltmeter) — der Zombie
sollte das Wandern abbrechen und geradewegs auf den Trupp zulaufen. Bei
Kontakt: eigene Kapsel färbt sich zunehmend rötlich (HP sinkt, HUD zeigt
den Wert), Zombie-Kapsel wird zunehmend dunkler — je nach Timing stirbt
entweder der Trupp (`MAX_HP` 100 vs. `ATTACK_DAMAGE` 10/Tick) oder der
Zombie zuerst (`MAX_HP` 40 vs. `COUNTER_DAMAGE` 15/Tick, rechnerisch nach 3
Treffern). Bei 2 Instanzen: Zombies sind für **beide** Peers sichtbar und
identisch (Host simuliert für alle), aber nicht auswählbar/befehligbar —
Klick auf einen Zombie sollte wie ein Klick auf leeren Boden wirken (kein
`"selectable"`).

**Lärm-System:** zwei Zombies suchen, die weit genug auseinander wandern,
dass sie sich gegenseitig nicht bemerken (> `DETECT_RADIUS`, aber <
`NOISE_RADIUS`, am einfachsten zwei der vier festen `ZOMBIE_SPAWN_POINTS`
beobachten). Eigenen Trupp nah an einen der beiden schicken. Sobald der
Kampf beginnt, sollte kurz danach auch der zweite, eigentlich zu weit
entfernte Zombie plötzlich die Richtung wechseln und ebenfalls
angelaufen kommen.

**GuardPost:** Nach `Start` unten links den Button `"Wachposten bauen (30
Baumaterial)"` klicken — Button-Text wechselt zu `"Baumodus aktiv — in die
Welt klicken"`. Jetzt irgendwo **in der Nähe der eigenen Home-Base**
(innerhalb `GUARD_POST_BUILD_RADIUS`, 8 Weltmeter) auf den Boden klicken —
genau dort sollte ein gelblicher kleiner Würfel auftauchen und
`Baumaterial` im HUD um 30 sinken, Button-Text springt zurück. Zum
Testen der Radius-Prüfung: Baumodus aktivieren, dann **weit weg** von der
eigenen Base klicken (z. B. in der Kartenmitte) — nichts sollte passieren,
kein Baumaterial-Abzug, Button-Text trotzdem zurück (kein Feedback bei
Ablehnung, siehe oben). Nach erfolgreichem Bau sollte nach 5 Sekunden
(`BUILD_TIME`) der Würfel grau werden. Direkt darunter sollte
jetzt eine Zeile `"Wachposten 0: 0 Arbeiter"` mit Button `"Arbeiter
schicken"` stehen — draufklicken, einer der zwei eigenen Trupps sollte sich
selbstständig zum Wachposten bewegen (der HUD zeigt oben weiterhin beide
Trupps einzeln), die Zeile danach `"1 Arbeiter"`. Erst jetzt sollte der
Wachposten auf Zombies in `FIRE_RANGE` (6 Weltmeter) feuern — vorher
passiert trotz fertig gebaut nichts. Den stationierten Trupp per Linksklick
auf den Boden woandershin schicken — Wachposten sollte danach aufhören zu
feuern (`"0 Arbeiter"`). Bei 2 Instanzen: jeder Peer sieht/baut nur seinen
eigenen Wachposten im `BuildUI` (`owner_peer_id`-Filter), aber beide
Wachposten sind für beide Peers sichtbar (Host simuliert/repliziert für
alle).

**Scavenging/Loot:** Trupp auswählen, auf eines der acht Gebäude klicken —
er sollte hinlaufen, kurz stehen bleiben (`SEARCH_DURATION` = 3s), danach
wird das Gebäude dunkelgrau und im HUD sollten die zum Gebäude passenden
Ressourcenwerte steigen (siehe `loot`-Werte pro Gebäude in
`World3DTest.tscn`). Nochmal draufklicken (Trupp erneut hinschicken) sollte
danach keinen weiteren Loot mehr bringen (schon geplündert). Während der
Suche einen neuen Bewegungsbefehl geben — der Trupp sollte sofort
losgehen, statt die Suche noch zu Ende zu bringen.

**Kamera-Start:** Nach `Start` sollte die Kamera direkt bei der eigenen
Home-Base stehen (eine der vier Kartenecken), nicht am leeren
Kartenursprung.

**Kontrollgruppen-UI:** Unten rechts sollte ein Panel `"Eigene Trupps"` mit
einer Zeile pro Trupp stehen. Bei einem Trupp auf `2` klicken (Häkchen
sollte erscheinen), beim anderen ebenfalls — dann oben auf `"Gruppe 2"`
klicken: beide sollten ausgewählt sein (HUD/Output bestätigen). Tastatur
(Strg+2 zum Zuweisen, 2 zum Auswählen) sollte weiterhin genauso
funktionieren.

**Rechtsklick-Stopp:** Trupp auswählen, per Linksklick auf einen weit
entfernten Punkt schicken, während er noch läuft **kurz** (ohne Ziehen)
rechtsklicken — er sollte sofort stehen bleiben. Rechte Maustaste
**halten + ziehen** sollte weiterhin nur die Kamera rotieren/neigen, ohne
die Bewegung zu stoppen.
