# Networking (Host/Join, RPC-Muster, Replikation)

Erklärt `autoloads/NetworkManager.gd`, `autoloads/GameManager.gd`, den
Szenenübergang MainMenu → Lobby → World, sowie die wiederkehrenden
RPC-/Replikations-Muster, die praktisch jedes Entity-Script in diesem
Projekt verwendet (Survivor, Zombie, Vehicle, Wall, GuardPost, Building,
HomeBase). Grundlage für [`docs/world.md`](world.md) und alle
Entity-Docs.

## Host-and-Play (Listen-Server)

`NetworkManager` (Autoload) kapselt Host/Join über `ENetMultiplayerPeer`,
kein dedizierter Server-Prozess — der Host spielt selbst mit (Peer-ID 1)
und simuliert gleichzeitig das gesamte Spiel. `DEFAULT_PORT := 7777`,
`MAX_PLAYERS := 4`.

- `host_game()` — `create_server()`, trägt sich selbst sofort in
  `players[1]` ein.
- `join_game(address)` — `create_client()`.
- **Gegenseitige Registrierung:** `peer_connected` feuert dank
  Godots Server-Relay auf **beiden** Seiten jedes Peer-Paars — jede Seite
  schickt der jeweils anderen per `_register_player.rpc_id(id, ...)` die
  eigenen Spielerinfos. Dadurch registrieren sich am Ende alle Peers
  gegenseitig, ohne Sonderfall für Host vs. Client.

## Szenenfluss

`GameManager` (Autoload) verwaltet drei States (`MAIN_MENU`, `LOBBY`,
`IN_GAME`) mit fest hinterlegten Szenenpfaden. `start_game()` darf nur
der Host aufrufen (`multiplayer.is_server()`-Check) und wechselt per
`_rpc_change_state.rpc(GameState.IN_GAME)` (`authority`, `call_local`)
**gleichzeitig bei allen Peers** in `World.tscn` — kein Client wechselt
eigenständig.

`MainMenu.gd` (Name eingeben, Host/Join) → `Lobby.gd` (zeigt
`NetworkManager.players` live an, Host sieht einen "Spiel starten"-Button)
→ `World.tscn`. Wichtig für [`docs/world.md`](world.md): Wenn `World.gd`
seine `_ready()` erreicht, sind alle regulären Mitspieler bereits in
`NetworkManager.players` bekannt — nur echte Spätbeitritte laufen über
`player_connected` innerhalb der Weltszene.

## Host-autoritative Simulation

Jedes dynamische Entity-Script (Survivor, Zombie, Vehicle, GuardPost,
Wall) folgt demselben Muster:

```gdscript
func _ready() -> void:
    if not multiplayer.is_server():
        set_process(false)
```

`_process()` läuft **nur** auf dem Host, jeder Client sieht ausschließlich
das Ergebnis der Sync-RPCs. Das hält die Simulation an einer einzigen
Quelle der Wahrheit, ohne Client-seitige Vorhersage/Interpolation.

## RPC-Grundmuster

- **`@rpc("authority", "call_local", ...)`** — nur der Host darf
  aufrufen, repliziert den Effekt an alle (inkl. sich selbst dank
  `call_local`). Für Sync-Methoden (`_sync_state`, `_sync_hp`,
  `mark_looted`, ...).
- **`@rpc("any_peer", "call_local", "reliable")`** — jeder Peer darf
  aufrufen (typischerweise `order_*`/`request_*`-Methoden), die Methode
  selbst prüft dann `multiplayer.is_server()` und
  `requesting_peer_id == owner_peer_id`, bevor sie wirklich etwas tut.
  `call_local`, damit der Host (der eigene Befehle auch lokal auslösen
  kann) sie sofort sieht.
- **`unreliable_ordered`** statt `reliable` für Zustände, die ohnehin
  jeden Frame komplett neu geschickt werden (Position/HP) — ein
  verlorenes Paket korrigiert sich im nächsten Frame von selbst,
  Reihenfolge muss trotzdem stimmen (kein Delta-basiertes Zurückspringen
  in der Zeit).

### Die `call_local`-Falle

`rpc_id(1, ...)`, das der **Host selbst** an sich selbst (Peer 1)
schickt, führt **ohne** `call_local` in der `@rpc(...)`-Annotation
**nicht** lokal aus — ein wiederholt aufgetretener Stolperstein in diesem
Projekt (u. a. `World._show_status_message()` fehlte es zunächst, wodurch
der Host eigene Statusmeldungen nie sah). Faustregel: jede
`@rpc`-Methode, die der Host potenziell auch für sich selbst auslösen
können soll, braucht `call_local`.

### Dynamischer RPC-Dispatch per Methodenname

`Node.rpc_id(peer_id, method_name: StringName, ...args)` kann eine
RPC-Methode generisch per Namen aufrufen — genutzt, wenn je nach Zustand
ein anderer RPC gefeuert werden muss (z. B. `order_search` vs.
`order_claim_building`, siehe [`docs/zones.md`](zones.md) und
[`docs/commander.md`](commander.md)). **Wichtig:** `node.call(method_name,
...)` ruft die Methode nur **lokal** auf, ohne übers Netzwerk zu gehen —
sieht auf den ersten Blick äquivalent aus, ist es aber nicht.

## MultiplayerSpawner + Catch-up-Pattern

Jede dynamische Entität hat ein Paar `XSpawner`/`XContainer` in
`World.tscn`, mit `spawn_function` (z. B. `_create_survivor`) in
`World._ready()` verdrahtet. **Bekannte Godot-Lücke:** `MultiplayerSpawner`
repliziert bereits gespawnte Nodes **nicht automatisch** an Peers, die
erst später beitreten. Lösung: `_spawn_for_peer(peer_id)` liefert beim
Beitritt jedes einzelnen Peers alle schon existierenden Entitäten gezielt
per `_catch_up_*.rpc_id(peer_id, ...)` nach — harmlos redundant (jede
`_catch_up_*`-Funktion prüft per `has_node()`, ob der Node schon
existiert), aber notwendig, damit ein spät beitretender Peer nicht in
einer halb-leeren Welt landet.

## Welt-Sync-Sperre (`WorldSyncOverlay`, 2026-08-04)

Nutzer-Testbericht (echter Zwei-Spieler-Test): "zweiter Spieler hat lange
Minimap-Ladezeiten und konnte keine Startbase wählen". Ursache: bei
aktuell 1750 Gebäuden + hunderten Bäumen/Ressourcen (siehe
`docs/benchmarks.md`) läuft jede einzelne Entität über einen eigenen
`MultiplayerSpawner`-Spawn, rein host-seitig in `_generate_world()`. Der
Host hat danach sofort alles lokal, ein Nicht-Host-Peer muss aber jede
einzelne dieser >2500 Spawn-Nachrichten über das Netzwerk empfangen —
das dauert spürbar lange. Der bestehende Ladebildschirm
(`docs/loading.md`) deckt das nicht ab: er verschwindet, sobald die
`World.tscn`-**Datei** geladen ist, nicht wenn die Welt beim Client
tatsächlich angekommen ist. Der Spieler landete also in einer noch
halb-leeren Welt — leere Minimap, keine Gebäude-Collider zum Anklicken
für die Startbase-Wahl.

**Lösung:** `World._start_world_sync_wait()` (nur im Nicht-Host-Zweig von
`_ready()` aufgerufen) blendet `WorldSyncOverlay` (Vollbild-Blocker,
`mouse_filter = MOUSE_FILTER_STOP`, verhindert Klicks auf die Welt
darunter) ein und verbindet sich mit `child_entered_tree` der
Entity-Container (`buildings_container`/`vehicles_container`/
`trees_container`/`car_wrecks_container`/`stone_piles_container`/
`brick_piles_container`/`zombie_nests_container`). **Bewusst NICHT** über
das `spawned`-Signal der jeweiligen `MultiplayerSpawner` (erste Version,
Bug): ein normal beitretender Peer (nicht nur Spätbeitritte) bekommt
Gebäude/Fahrzeuge/etc. über ZWEI Wege — direkte Spawner-Replikation aus
`_generate_world()` UND die `_catch_up_*`-RPCs (`_spawn_for_peer()`,
ausgelöst durch `request_catch_up()`, das jeder Client in `_ready()`
aufruft). Die Catch-up-RPCs fügen ihre Nodes per `add_child()` direkt in
den Container ein, ganz ohne den Spawner — dessen `spawned`-Signal feuert
dafür nie, `child_entered_tree` auf dem Container dagegen für beide Wege
gleichermaßen.

Gleichzeitiger PULL wie `request_city_zones()`/`request_catch_up()`:
`request_world_gen_totals.rpc_id(1)` fragt beim Host die aktuell wahre
Gesamtzahl ab (`_current_world_gen_totals()` liest einfach die schon
vorhandenen `_next_*_id`-Zähler aus — die erhöhen sich exakt einmal pro
gespawnter Entität, egal ob aus `_generate_world()` oder
`_load_game_state()`, keine zusätzlichen Zähl-Variablen an jeder
einzelnen `spawn()`-Stelle nötig). Der Client vergleicht seinen lokal per
Signal mitgezählten Stand gegen diese Ziel-Zahl; erst wenn beides
übereinstimmt, verschwindet das Overlay (`_check_world_sync_complete()`)
und `_select_at()` lässt wieder Klicks durch (zusätzlicher expliziter
Guard dort, nicht nur auf Overlay-Mausfilter verlassen).

**Zweiter Bugfix im selben Zug:** `_spawn_for_peer()` bricht jetzt sofort
ab, wenn `peer_id == multiplayer.get_unique_id()` — `_spawn_all_players()`
rief das beim Partie-Start auch für die eigene Host-Peer-ID auf, was am
Ende immer beim `_catch_up_day_time`-RPC mit "RPC ... on yourself is not
allowed by selected mode" fehlschlug (im Debugger gefunden). Der Host
braucht nie einen Catch-up für sich selbst.

Deckt automatisch auch spät beitretende Peers ab (gleiches PULL-Prinzip
wie überall sonst) — `_current_world_gen_totals()` liefert bei jedem
Aufruf den aktuellen wahren Stand, egal ob seit Weltstart noch
Flüchtlings-Gebäude (`_maybe_spawn_refugee()`) dazukamen.

**Sicherheitsnetz:** `WORLD_SYNC_TIMEOUT` (30s) — falls eine einzelne
Spawn-Nachricht durch die bekannte Godot-Lücke oben verlorengeht und die
Ziel-Zahl nie exakt erreicht wird, gibt `_force_world_sync_complete()`
nach Ablauf trotzdem frei, statt den Client für immer hinter der Sperre
hängen zu lassen.

**Nachtrag 2026-08-04, echter Zwei-Spieler-Test der Sperre:** Debug-
Logging (`[WorldSync]`-Prints) zeigte etwas Schlimmeres als reine
Langsamkeit — beim beitretenden Peer blieb der Gebäude-Zähler fest bei
193 von 1755 stehen, danach kam NICHTS mehr an (auch nicht die eigene
Ziel-Zahlen-Antwort), und wenig später tauchte im Debugger überall
`"No multiplayer peer is assigned. Unable to get unique ID."` auf — die
Netzwerkverbindung war komplett abgestürzt, nicht nur langsam. Ursache:
`_spawn_for_peer()` feuerte beim Beitritt für Gebäude/Bäume/Wracks/Steine/
Ziegel **über 4000 einzelne `.rpc_id()`-Aufrufe synchron in einer
Funktion** ab — das hat die ENet-Verbindung des Peers überlastet.

**Fix, zwei Teile:**
1. **Bündel-RPCs:** `_catch_up_buildings_bulk()`/`_catch_up_trees_bulk()`/
   `_catch_up_car_wrecks_bulk()`/`_catch_up_stone_piles_bulk()`/
   `_catch_up_brick_piles_bulk()` ersetzen die fünf schwersten
   Einzel-Catch-up-Funktionen — `_spawn_for_peer()` sammelt jetzt pro Typ
   ein Array und schickt EINEN RPC-Aufruf statt hunderter/tausender. Die
   `WorldSyncOverlay`-Zählung (siehe oben) bleibt davon unberührt, weil sie
   auf `child_entered_tree` der Container lauscht, nicht auf den Spawner —
   das feuert unabhängig davon, ob ein Kind einzeln oder in einer Schleife
   aus einem Bündel-RPC hinzugefügt wird.
2. **Zahlen zurückgenommen:** `BUILDINGS_PER_LARGE_ZONE`/`_SMALL_ZONE`
   zurück auf 100/50 (Summe 350, der ursprüngliche Ausgangswert vor allen
   Stresstest-Runden), `TREES_PER_FOREST_ZONE` zurück auf 40,
   `TREES_TOTAL`/`CAR_WRECKS_TOTAL`/`STONE_PILES_TOTAL`/`BRICK_PILES_TOTAL`
   zurück auf 200/80/100/100 — zusätzliche Sicherheitsmarge obendrauf zur
   strukturellen Bündelung.

**Vom Nutzer erneut getestet und bestätigt (2026-08-04)** — funktioniert.
Debug-Logging wieder entfernt.

## Cross-Node-Feedback-Muster

Mehrere Systeme lösen Effekte in `World.gd` aus, ohne direkt eine
`_`-Methode eines fremden Nodes aufzurufen — stattdessen über
`get_tree().current_scene.<public_method>(...)`, verlässlich, weil
`World.tscn` immer die aktuell geladene Szene ist, solange die
aufrufenden Nodes existieren: `report_status()` (siehe
[`docs/world.md`](world.md)), `spawn_recruit()` (siehe
[`docs/recruitment.md`](recruitment.md)), `claim_building()` (siehe
[`docs/zones.md`](zones.md)).

## Bekannte Grenzen (noch nicht gelöst)

- **Keine echte Autorisierung** — `requesting_peer_id`-Checks vertrauen
  dem Absender, kein Abgleich mit `multiplayer.get_remote_sender_id()`.
  Für Koop unter befreundeten Spielern akzeptiert.
- **Kein Reconnect** — trennt die Verbindung, ist die Session für diesen
  Peer vorbei (`server_disconnected`/`connection_failed` führen zurück
  ins Hauptmenü).
- **Kein State-Catch-up über reine Node-Existenz hinaus** bei manchen
  Feldern (z. B. `Wall`-HP eines schon beschädigten Segments,
  `GuardPost.worker_count`, Fog of War) — siehe die jeweiligen "Bekannte
  Grenzen"-Abschnitte in den Entity-Docs. `Building.is_looted` und
  `GuardPost.built` sind inzwischen behoben (siehe `scavenging.md`/
  `building.md`), hier als Beispiele entfernt, um nicht wieder zu
  veralten.

## Testen

Debug → Customize Run Instances → 2 → F5. Einen Client hosten, den
zweiten beitreten lassen, in der Lobby "Spiel starten" (nur beim Host
sichtbar) — beide sollten gleichzeitig in `World.tscn` wechseln. Einen
dritten Client erst **nach** Spielstart beitreten lassen — sollte alle
bereits existierenden Entitäten korrekt sehen (Catch-up).
