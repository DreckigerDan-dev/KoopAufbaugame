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
  Feldern (z. B. `Building.is_looted`, `GuardPost.built`) — siehe die
  jeweiligen "Bekannte Grenzen"-Abschnitte in den Entity-Docs.

## Testen

Debug → Customize Run Instances → 2 → F5. Einen Client hosten, den
zweiten beitreten lassen, in der Lobby "Spiel starten" (nur beim Host
sichtbar) — beide sollten gleichzeitig in `World.tscn` wechseln. Einen
dritten Client erst **nach** Spielstart beitreten lassen — sollte alle
bereits existierenden Entitäten korrekt sehen (Catch-up).
