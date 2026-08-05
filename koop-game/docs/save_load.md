# Speichern/Laden

Erklärt `autoloads/SaveManager.gd` + die `_collect_save_data()`/
`_load_game_state()`-Erweiterung in `World.gd`. Nutzerwunsch: für
3–4-Stunden-Sessions gab es bisher **keinerlei Persistenz** — ein Absturz
oder Server-Neustart warf den kompletten Spielstand weg.

## Warum host-seitig genügt

Das Spiel ist durchgehend host-autoritativ (siehe `docs/world.md`,
`docs/zombies.md`) — nur der Host simuliert (`if not multiplayer.is_server():
set_process(false)` in praktisch jedem Entity-Script), Clients bekommen
Zustand ausschließlich über `MultiplayerSpawner`+RPCs repliziert. Speichern/
Laden liest bzw. schreibt deshalb **ausschließlich den Host-eigenen,
autoritativen Node-Baum** — Clients brauchen keine Sonderbehandlung, sie
bekommen den geladenen Zustand über dieselben Mechanismen, die auch beim
normalen späten Beitritt schon funktionieren (`_spawn_for_peer()`/
`_catch_up_*`).

## `SaveManager` (Autoload) — reine Datei-I/O

```gdscript
var pending_load: Dictionary = {}

func save_to_disk(data: Dictionary) -> bool: ...
func load_from_disk() -> Dictionary: ...
func has_save() -> bool: ...
```

Ein einzelner Speicherstand (`user://saves/savegame.sav`, kein Slot-System)
— serialisiert über `var_to_str()`/`str_to_var()` (Godot-natives Format,
versteht `Vector3`/`Dictionary` direkt, keine manuelle
Vector3-zu-`{x,y,z}`-Konvertierung nötig). `SaveManager` kennt nur das
Dateiformat, nicht den Inhalt — WAS gespeichert wird, weiß ausschließlich
`World.gd`.

`pending_load` ist der einzige Weg, geladene Daten über den Szenenwechsel
hinweg mitzugeben: Autoloads überleben `change_scene_to_file()`, lokale
Szenen-Variablen nicht. `MainMenu._on_load_pressed()` liest die Datei, setzt
`pending_load`, danach erst der Szenenwechsel — `World._ready()` prüft
`SaveManager.pending_load` und verzweigt entsprechend.

## Wiederverwendung der bestehenden Spawn-Infrastruktur

Jede `_create_*()`-Funktion in `World.gd` (z. B. `_create_survivor`,
`_create_zombie`, `_create_wall`, `_create_tree`) nimmt ein reines
`Dictionary` und wird über `xxx_spawner.spawn(data)` aufgerufen — das
repliziert automatisch an alle Peers (`MultiplayerSpawner.spawn()` gibt den
erzeugten Node zurück, schon vorher so genutzt z. B. in
`_trigger_horde_night()`). **Laden ruft exakt dieselben Spawn-Aufrufe auf**
wie das normale Spiel, nur mit Daten aus der Save-Datei statt frisch
generierten Positionen — kein neuer Replikationsweg nötig.

Acht `_create_*()`-Funktionen bekamen dafür **zusätzliche, optionale**
`data.get("hp", ...)`/`data.get("is_marked", false)`-Fallbacks
(`_create_survivor`, `_create_zombie`, `_create_tree`, `_create_car_wreck`,
`_create_stone_pile`, `_create_brick_pile`, `_create_guard_post`,
`_create_wall` — Letzteres erst 2026-08-04, Systematik-Review, siehe
[`walls.md`](walls.md), vorher fehlte `hp` dort komplett) — bestehende
Aufrufer (normales Spiel) übergeben diese Keys nie, Verhalten dort bleibt
exakt unverändert.

**Bekannte `@export`-Timing-Falle beachtet:** `Zombie._ready()` berechnet
`hp = _max_hp` abhängig von `is_brute` (siehe `docs/zombies.md`,
"Zombie-Typen") — ein vor dem Hinzufügen zum Baum gesetzter `hp`-Wert würde
sofort überschrieben. Deshalb setzt `_load_game_state()` bei Zombies das
`hp`-Override **erst nach** dem `spawn()`-Aufruf, auf dem zurückgegebenen
Node. Bei allen anderen betroffenen Typen (Survivor, Tree, CarWreck,
StonePile, BrickPile) überschreibt `_ready()` diese Felder nicht, deshalb
dort direkt in der jeweiligen `_create_*()`-Funktion gesetzt.

## Gebäude, Fahrzeuge, Zombie-Nest: array-basiert (seit dem Kartenumbau)

Ursprünglich waren die Stadt-Gebäude/Fahrzeuge/das Zombie-Nest feste
Kind-Nodes direkt in `World.tscn`, referenziert über feste Namenslisten
(`SAVED_BUILDING_NAMES`/`SAVED_VEHICLE_NAMES`/`SAVED_ZOMBIE_NEST_NAME`).
Seit dem großen Kartenumbau (prozedurale Zonen-Generierung, siehe
`docs/world.md`) laufen alle drei Typen wie jede andere dynamische
Entität über `MultiplayerSpawner` (`building_spawner`/`buildings_container`
usw.) — die festen Namenslisten sind komplett entfallen, echte
Vereinfachung statt Mehrkomplexität:

- **Speichern:** `_collect_save_data()` iteriert einfach
  `buildings_container.get_children()`/`vehicles_container.get_children()`/
  `zombie_nests_container.get_children()` und baut je ein Array aus
  Dictionaries (id, position, `zone_center`, `size`, `loot`,
  `default_color`, `has_survivor`, `is_looted`, `owner_peer_id`, `hp` bei
  Buildings; id/position/hp bei Vehicle/ZombieNest) — **exakt dasselbe
  Muster wie Tree/Zombie schon immer**.
- **Laden:** `_load_game_state()` ruft für jeden Array-Eintrag einfach
  `building_spawner.spawn(entry)`/`vehicle_spawner.spawn(entry)`/
  `zombie_nest_spawner.spawn(entry)` auf — dieselben `_create_*()`-
  Funktionen wie beim normalen Spiel.
- **Zerstört/demoliert:** entfällt als eigener Sentinel-Wert komplett — ein
  zerstörtes/demoliertes Gebäude/Fahrzeug/Nest taucht schlicht nicht mehr
  in seinem Container auf, landet also gar nicht erst im Save-Array
  (identisch zu Tree/Zombie, die dieses Problem nie hatten).
- `_next_building_id`/`_next_vehicle_id`/`_next_zombie_nest_id` werden wie
  alle anderen `_next_*_id`-Zähler in `next_ids` mitgespeichert/geladen,
  `_city_zone_centers` (Array der fünf Zonen-Zentren) wird separat
  mitgespeichert, damit geladene Gebäude ihre `zone_center`-Referenz für
  die Start-Basis-Wahl (siehe `docs/zones.md`) behalten.

## Bewusste Vereinfachungen

- **Mehrspieler-Wiederaufnahme über Peer-IDs, nicht über Spieler-Identität.**
  ENet vergibt Peer-IDs streng nach Verbindungsreihenfolge (Host immer 1,
  danach 2, 3, 4). Verbindet sich dieselbe Gruppe in derselben Reihenfolge
  neu, bekommt jeder automatisch wieder seine alte Home-Base/Trupps
  zugeordnet, ganz ohne Zusatzcode. Andere Reihenfolge oder neue Spieler →
  alte Home-Bases eines nicht mehr verbundenen Peers bleiben einfach
  unbesetzt in der Welt stehen. Ein Spieler ohne (wiederhergestellte)
  Home-Base nutzt einfach die normale Start-Basis-Wahl
  (`request_choose_start_base()`, siehe `docs/zones.md`) — funktioniert
  unverändert, ob frisch gestartet oder in einer geladenen Welt.
- **Wachposten-Arbeiter (`_stationed_workers`), Fahrzeug-Fahrer (`driver`)
  werden nicht wiederhergestellt** — beides Live-Referenzen auf
  Survivor-Nodes, kein trivial serialisierbarer Zustand. Nach dem Laden sind
  alle Trupps frei (nicht mehr stationiert/nicht mehr im Fahrzeug), Fahrzeuge
  unbesetzt.
- **Ein Speicherstand, keine Slots/Zeitstempel.**

## Ausstiegspunkt aus dem Spiel (Voraussetzung fürs Speichern)

Vorher gab es **keinen Weg**, `World.tscn` wieder zu verlassen — kein
Escape-Handling, kein Button. Neu: `PauseMenu.tscn`/`.gd`
(`scenes/world/PauseMenu.tscn`), als Kind-Node in `World.tscn`, von
`World._unhandled_input()` über `KEY_ESCAPE` (vorher komplett ungenutzt)
umgeschaltet (`pause_menu.toggle()`). "Speichern" ist nur für
`multiplayer.is_server()` sichtbar (gleiches Muster wie
`Lobby.start_button.visible = multiplayer.is_server()`), ruft
`World.save_game()` → `SaveManager.save_to_disk(_collect_save_data())` auf,
mit Rückmeldung über das bestehende `report_status()`-Muster. "Zurück zum
Hauptmenü" ruft `NetworkManager.leave_game()` + `GameManager.change_state(
MAIN_MENU)` auf, identisch zu `Lobby._on_leave_pressed()`.

## Hauptmenü-Integration

`MainMenu.gd`: **Solo** (`host_game()` + direkt `IN_GAME`, überspringt die
Lobby-Wartephase — bei nur einem Spieler gibt es nichts, worauf man warten
müsste) und **Laden** (zusätzlich `SaveManager.pending_load` befüllt, gleicher
Sprung) sind neue Direktstarts. **Koop** (Host/Join) bleibt unverändert über
`Lobby.tscn`. Der Laden-Button ist deaktiviert, wenn `SaveManager.has_save()`
`false` liefert.

## Korrektheits-Fix: `unlocked_recipes` fehlte (2026-08-04)

`_collect_save_data()`/`_load_game_state()` haben `HomeBase.resources`/
`storage_capacity` schon immer gesichert, aber `unlocked_recipes` (die
über Forschungsbücher freigeschalteten Rezepte/Gebäude-Ausbaustufen,
siehe [`building.md`](building.md), "Forschungsbücher") komplett
übergangen — ein Korrektheits-Durchgang hat das aufgedeckt. Da Bücher
beim Erforschen VERBRAUCHT werden (`request_research()`), hätte ein
Speichern+Laden jede schon erforschte Freischaltung dauerhaft rückgängig
gemacht, ohne das Buch zurückzugeben (permanenter, nicht behebbarer
Fortschrittsverlust, solange keine neue Kopie des Buchs gefunden wird).
Jetzt Teil von `home_bases` im Speicherstand, `.get()` mit leerem
Dictionary-Fallback für ältere, vor diesem Fix gespeicherte Dateien (kein
harter Fehler beim Laden).

## Testen

Eine Weile spielen (Ressourcen sammeln, Gebäude claimen, Mauer bauen, Baum
anschneiden, Trupp verletzen lassen, EIN Rezept erforschen) → Escape →
Speichern → Zurück zum Hauptmenü → Laden → prüfen, dass Ressourcen/
Gebäude-Besitz/Baumstumpf-HP/Trupp-HP UND die erforschte Freischaltung
(Crafting-Button zeigt weiterhin "herstellen" statt wieder "erforschen")
wie erwartet wiederhergestellt sind. Kein laufender Godot-Editor in der
Entwicklungsumgebung verfügbar — bisher nur über statische Checks
(Trap-Muster-Grep, `$NodePath`-Integrität, Tab-Einrückung) verifiziert, noch
nicht tatsächlich im Editor gespielt.
