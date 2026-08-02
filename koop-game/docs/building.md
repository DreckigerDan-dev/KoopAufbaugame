# Bausystem + Wachposten

Erklärt das generische Bausystem in `scenes/world/World.gd` (Baumodus,
Kosten, Ghost-Preview, Werkstatt-Rabatt) sowie `scenes/entities/base/
GuardPost.gd` als konkreten Bautyp. Mauer/Tor haben eigene
Platzierungslogik (Ziehen statt Einzelklick) — siehe
[`docs/walls.md`](walls.md). Krankenstation/Werkstatt selbst haben keine
eigene Laufzeit-Logik (siehe unten) und sind seit dem Baumenü-Umbau (siehe
"Ausbauen" unten) nicht mehr frei platzierbar. Claimen bestehender
Gebäude als zusätzlicher Bauzonen-Anker: siehe [`docs/zones.md`](zones.md).

## Baumenü-Umbau (Nutzerwunsch)

Ursprünglich waren alle fünf Bautypen (Wachposten/Mauer/Tor/Krankenstation/
Werkstatt) frei im eigenen Baumenü platzierbar. Nutzer-Feedback: das fühlte
sich zu beliebig an — Krankenstation/Werkstatt/(perspektivisch Lager etc.)
sollen stattdessen **Ausbaustufen bereits geclaimter Gebäude** sein, direkt
platzierbar bleiben nur noch Bautypen, die eine eigene, freie Position in
der Zone brauchen (Mauer/Wachposten/Tor + neu Felder).

## Bautypen

```gdscript
enum BuildType { GUARD_POST, WALL, GATE, MEDICAL_STATION, WORKSHOP, FIELD, STORAGE, OUTPOST }
```

**Direkt platzierbar** (Baubuttons im "Bauen"-Tab von `MainTabsUI`, siehe
[`world.md`](world.md), "UI-Overhaul" — vor dem UI-Overhaul ein eigenes
`BuildUI`-Panel, jetzt ein Tab, gleiche Buttons, jeder an
`_on_toggle_build_mode_pressed(type)` gebunden):

| Bautyp | Kosten | Art |
|---|---|---|
| Wachposten | 30 | Holz (Holzturm) |
| Mauer | 15 | Stein (Steinwall) |
| Tor | 20 | Metall (Beschlag/Scharniere) |
| Feld | 20 | Holz (Zaun/Umrandung) |
| Außenposten | 15 Holz + 10 Stein | siehe "Außenposten" unten — einziger Bautyp AUSSERHALB der eigenen Zone |

**Nur noch über Ausbauen erreichbar** (siehe unten, kein eigener
Bau-Button mehr):

| Bautyp | Kosten | Art |
|---|---|---|
| Krankenstation | 25 | Ziegel (Ziegelbau) |
| Werkstatt | 25 | Metall (Maschinen/Werkzeug) |

`MEDICAL_STATION`/`WORKSHOP` bleiben als `BuildType`-Werte bestehen
(weiterhin für Kosten-Lookup über `_cost_for_build_type()` gebraucht,
siehe unten), sind aber über keinen Bau-Button/`_build_type` mehr
direkt erreichbar. Jeweils als `const ..._COST := {"<art>": N}` in
`World.gd`. Beträge unverändert zur alten `materials`-Fassung, nur
umgehängt. Buttons (Bauen wie Ausbauen) zeigen den Preis live inklusive
Art (`_build_button_label()`, generisch über `RESOURCE_DISPLAY_NAMES`
statt fest auf eine Art verdrahtet).

## Baumodus (Einzelklick-Typen)

Wachposten/Feld laufen über denselben Ein-Klick-Fluss:

1. Button-Klick → `_build_mode = true`, `_build_type` gesetzt.
2. `_process()` aktualisiert währenddessen laufend das `BuildGhost`
   (Preview-Mesh unter dem Mauszeiger, `_update_build_ghost()`) — grün
   (`BUILD_GHOST_VALID_COLOR`) wenn `_can_build_at()` zutrifft, sonst rot.
3. Klick in die Welt (`_select_at()`, Baumodus-Zweig) schickt
   `request_build_structure.rpc_id(1, _build_type, result.position,
   multiplayer.get_unique_id())` und schaltet den Baumodus **immer** ab —
   auch bei späterer Ablehnung durch den Host (kein Fehler-Feedback bei
   Ablehnung, konsistent mit dem 2D-Original).

`World.request_build_structure(type, build_position, requesting_peer_id)`
(host-only, `@rpc("any_peer", "call_local", "reliable")`) prüft
`_can_build_at()` (siehe unten), zieht bei Erfolg die Kosten ab
(`base.add_resources.rpc()` mit negiertem Delta) und spawnt die Struktur
über den passenden `MultiplayerSpawner` (`guard_post_spawner`,
`field_spawner`, Mauer/Tor über `request_build_wall_line()` separat).
`MEDICAL_STATION`/`WORKSHOP` sind hier seit dem Baumenü-Umbau **nicht**
mehr erreichbar — die spawnen jetzt über `request_upgrade_building()`
(siehe "Ausbauen" unten). Bei Fehlschlag `_report_build_failure()` (siehe
unten).

Mauer/Tor nutzen **nicht** diesen Fluss — Ziehen statt Einzelklick, eigene
RPC `request_build_wall_line()`, siehe [`docs/walls.md`](walls.md).

## Felder (`Field.gd`)

Neuer, einfacher Bautyp — produziert passiv Nahrung für den Besitzer,
kein Baumaterial-Sink wie die anderen Bautypen, sondern eine echte
Ressourcenquelle:

```gdscript
const YIELD_INTERVAL := 8.0
const YIELD_AMOUNT := 2
```

`_process()` (nur Host) zählt `_yield_timer` hoch, schreibt alle
`YIELD_INTERVAL` Sekunden `YIELD_AMOUNT` Nahrung der eigenen Home-Base gut
(`_find_home_base()`, gleiches Gruppen-Muster wie
`Survivor._find_home_base()`). Kein Bauzeit-Timer wie beim Wachposten
(sofort einsatzbereit), keine eigene HP/Zerstörbarkeit.

## Außenposten (`Outpost.gd`, 2026-08-01, Punkt 8 der Gesamtliste)

Aus der Vision übernommen (`Infos/01 Architektur.md`, "Außenposten": "Kleine,
unabhängige Bauten außerhalb der Hauptzone, nur zum Rasten/Schlafen der
Trupps — Ausnahme von der Zusammenhang-Regel"). **Wichtige Abgrenzung:** nur
der Teil, der sich mit dem aktuellen Spielstand sinnvoll umsetzen lässt, ist
umgesetzt — "Rasten/Schlafen" bräuchte ein Müdigkeits-/Bedürfnissystem
(Punkt 16 der Gesamtliste), das es noch nicht gibt. Umgesetzt ist die
zweite, in der Vision genannte Funktion: ein kürzerer Rückweg beim
Scavenging ("Rückweg zur Basis (oder zum Außenposten zum Zwischenlagern)",
`Infos/01 Architektur.md`, "Trage-Kapazität").

- **Einziger Bautyp ohne Zonen-Prüfung:** `_can_build_at()` überspringt
  `is_within_own_zone()` für `BuildType.OUTPOST` (neuer, optionaler `type`-
  Parameter, Standard `GUARD_POST` für alle bestehenden Aufrufer, die die
  Prüfung weiterhin brauchen) — das ist die "Ausnahme von der
  Zusammenhang-Regel" aus der Vision, ein Außenposten lässt sich buchstäblich
  überall auf der Karte platzieren.
- **Kein eigener Ressourcen-Pool.** `Outpost.add_resources(delta)` ist eine
  einfache Methode (KEIN `@rpc`, anders als `HomeBase.add_resources()`), die
  intern `World._find_home_base_for_peer(owner_peer_id)` sucht und dorthin
  `base.add_resources.rpc(delta)` weiterreicht — "Zwischenlagern" bedeutet
  hier nur einen kürzeren Weg für den Trupp, keine zweite, separate
  Lager-Instanz (das deckt schon `Storage`/"Lager" ab, siehe oben). Bewusst
  einfacher als eine echte zweite Ressourcen-Stelle mit eigener Kapazität/
  Abhol-Mechanik.
- **`Survivor._find_nearest_drop_off_point()`** (siehe
  [`docs/survivor.md`](survivor.md)) ersetzt das bisherige "immer zur
  Home-Base" in `_return_to_base()`/`_handle_carried_loot()` — läuft zum
  NÄHEREN von Home-Base oder einem eigenen Außenposten (Gruppe
  `"outpost"`, `owner_peer_id`-Filter). `_handle_carried_loot()`
  unterscheidet dabei explizit zwischen den beiden Zieltypen: Home-Base
  braucht `.rpc()` (ihr `add_resources()` IST das replizierte RPC), ein
  Außenposten braucht einen normalen Aufruf (er hat selbst kein `@rpc`,
  reicht nur intern weiter) — ein einheitliches `.rpc()` für beide Typen
  hätte beim Außenposten einen Laufzeitfehler ausgelöst (Methode ohne
  RPC-Konfiguration).
- **Bewusst schlank wie `MedicalStation.gd`:** kein HP, kein Bautimer (kein
  "fertig gebaut"-Feedback nötig, sofort einsatzbereit nach dem Platzieren).
  Kosten `{"wood": 15, "stone": 10}` — die Vision nennt "5× Holz + 3×
  Baumaterial" ("Baumaterial" auf Stein umgehängt, gleiche Preisklasse wie
  Mauer/Zonen-Claim), Beträge moderat verdoppelt statt 1:1 übernommen (die
  Vision-Beträge sind für ein größeres Ressourcensystem kalibriert).

**Noch nicht vom Nutzer getestet.**

## Ausbauen

Krankenstation und Werkstatt entstehen seit dem Baumenü-Umbau **nicht**
mehr durch freies Platzieren, sondern durch Ausbauen eines bereits
geplünderten UND vom Spieler selbst geclaimten Gebäudes (siehe
[`docs/zones.md`](zones.md) fürs Claimen selbst).

- **Auswählen:** Klick auf ein eigenes, geclaimtes Gebäude (egal ob
  gerade ein Trupp ausgewählt ist oder nicht — `World._select_at()`,
  `"searchable"`-Branch, läuft dafür bewusst unabhängig von `selected`)
  setzt `_selected_claimed_building` und blendet einen "Ausbauen"-
  Abschnitt im "Bauen"-Tab ein (`_refresh_building_upgrade_ui()`, siehe
  [`world.md`](world.md), "UI-Overhaul") — kein eigenes Panel.
- **`World.request_upgrade_building(building_path, upgrade_type,
  requesting_peer_id)`** (`@rpc("any_peer", "call_local", "reliable")`):
  prüft Besitz (`building.owner_peer_id == requesting_peer_id`) und
  Bezahlbarkeit (`_cost_for_build_type(upgrade_type, ...)`, dieselben
  Kosten wie das frühere freie Platzieren), zieht die Kosten ab, entfernt
  das `Building` an derselben Position und spawnt dort stattdessen die
  `MedicalStation`/`Workshop`-Struktur über den jeweiligen
  `MultiplayerSpawner`.
- **Entfernen des Building-Nodes ohne neues RPC:** ruft einfach
  `building.take_damage(building.hp)` auf — nutzt denselben, bereits
  netzwerksicheren Abriss-Pfad wie beim echten Abreißen (siehe
  [`docs/survivor.md`](survivor.md), "Gebäude abreißen"), aber **ohne**
  die dortige Rohstoff-Auszahlung (die passiert nur in
  `Survivor._process_harvest()`, nicht in `Building.take_damage()`
  selbst) — ein Ausbau ist ein Umbau, kein Abriss-für-Rohstoffe.
- **Optimistisches UI-Reset:** `_on_upgrade_building_pressed()` setzt
  `_selected_claimed_building = null` sofort nach dem RPC-Aufruf, ohne auf
  die Server-Bestätigung zu warten — verhindert einen versehentlichen
  zweiten Ausbau-Versuch auf ein bereits ersetztes Gebäude.
- **Lager** (aus der Vision-Idee des Nutzers) ist noch **nicht** als
  dritte Ausbau-Option umgesetzt — bräuchte erst ein Ressourcen-Limit-
  System (siehe [`docs/base.md`](base.md), "Bekannte Grenzen"), das es
  noch nicht gibt, bewusst zurückgestellt wie im ursprünglichen
  Roadmap-Punkt "Lager + Betten".

## Zonen-Prüfung (`_can_build_at()`)

```gdscript
func _can_build_at(peer_id: int, build_position: Vector3, cost: Dictionary, type: BuildType = BuildType.GUARD_POST) -> bool:
    if type != BuildType.OUTPOST and not is_within_own_zone(peer_id, build_position):
        return false
    return _can_afford(peer_id, cost)
```

`is_within_own_zone()` ist public (auch von Mauer-Placement und
Claim-Validierung genutzt) und prüft `BUILD_RADIUS` (8 Weltmeter) um die
eigene Home-Base **oder** um jedes bereits geclaimte Gebäude dieses
Spielers — Details und die Design-Begründung dazu in
[`docs/zones.md`](zones.md). Seit dem Außenposten (siehe oben) optionaler
`type`-Parameter, der genau diese Prüfung für `BuildType.OUTPOST`
überspringt — die einzige bisherige Ausnahme von der Zonen-Regel.

## Werkstatt-Rabatt

`_cost_for_build_type(type, peer_id)` multipliziert die Basiskosten mit
`WORKSHOP_DISCOUNT` (0.8, also 20 % günstiger), sofern
`_has_own_workshop(peer_id)` zutrifft (eigene Werkstatt in der
`"searchable"`-Gruppe... genauer: eigener `workshop`-Node mit passender
`owner_peer_id`). Gilt für **alle anderen** Bautypen inkl. Zonen-Claim,
nicht für die Werkstatt selbst (keine Kettenreaktion beim Bau der
ersten).

**Live-Buttontext:** `_update_button_texts()` /
`_build_button_label(display_name, type, peer_id)` berechnet den
tatsächlichen (ggf. rabattierten) Preis bei jedem UI-Refresh neu, statt
einen statischen String zu zeigen — ein früherer Bug-Report ("Werkstatt-
Rabatt funktioniert nicht") stellte sich als rein kosmetisch heraus: der
Rabatt wurde korrekt abgezogen, nur der Buttontext blieb der ursprüngliche
Preis. Seitdem live berechnet.

## Herstellen (Crafting-System, 2026-08-01, Punkt 12 der Gesamtliste)

Verwandelt die bisher rein passive Werkstatt (nur `WORKSHOP_DISCOUNT`, siehe
oben) in eine echte Herstellungs-Station. **Wichtige Abgrenzung** (gleiches
Muster wie beim Waffen-/Rüstungssystem, siehe [`survivor.md`](survivor.md)):
nicht die volle Vision (`Infos/02 Item-Liste.md`: viele Rezeptstufen,
Waffen-Mods, Slots), sondern vier feste Rezepte, alle sofort ohne
Freischaltung nutzbar — kein Forschungsbücher-Gate, das ist Punkt 13, ein
eigener, noch offener Listenpunkt.

- **`CRAFTING_RECIPES`** (`World.gd`): vier feste Rezepte, jedes mit
  `id`/`name`/`cost`/`yield`. Erzeugt genau die Ausrüstungsgegenstände, die
  bisher NUR über Zombie-Loot-RNG erreichbar waren (siehe
  [`survivor.md`](survivor.md), [`zombies.md`](zombies.md),
  "Zombie-Loot-Drop") — eine verlässliche Alternative zum Glück beim
  Zombie-Kill, kostet dafür Basis-Rohstoffe (Holz/Metall/Stein):

  | Rezept | Kosten | Ertrag |
  |---|---|---|
  | Waffe | 15 Metall + 10 Holz | 1 Waffe |
  | Rüstung | 20 Metall + 10 Stein | 1 Rüstung |
  | Helm | 10 Metall + 5 Stein | 1 Helm |
  | Munition | 10 Metall | 15 Munition |

  Beträge grob an den jeweiligen Zombie-Loot-Mengen orientiert, keine
  echte Balancing-Analyse (wie bei den meisten anderen Kosten in diesem
  Projekt).
- **`World.request_craft(recipe_id, requesting_peer_id)`**
  (`@rpc("any_peer", "call_local", "reliable")`): prüft eigene, gebaute
  Werkstatt (`_has_own_workshop()`, dieselbe Prüfung wie beim Rabatt, hier
  aber eine **Pflicht** statt nur eines Rabatts) und Bezahlbarkeit
  (`_can_afford()`), zieht Kosten ab UND schreibt den Ertrag gut — beides
  in einem einzigen `base.add_resources.rpc(delta)`-Aufruf (Kosten und
  Ertrag überschneiden sich nie in denselben Ressourcenarten, Kosten sind
  immer Basis-Rohstoffe, Ertrag immer ein Ausrüstungsgegenstand).
- **"Herstellen"-Tab** (seit dem UI-Overhaul, siehe [`world.md`](world.md),
  "UI-Overhaul" — ursprünglich ein eigenes Panel `CraftingUI`), sichtbar/
  der Tab ausgeblendet ohne eigene Werkstatt (`_refresh_crafting_ui()` +
  `TabContainer.set_tab_hidden()`, gleicher gedrosselter Takt wie
  `_refresh_worker_ui()` &Co., `WORKER_UI_REFRESH_INTERVAL`). Ein Button
  pro Rezept, Beschriftung zeigt Kosten UND Ertrag live
  (`_craft_button_label()`, generisch über `RESOURCE_DISPLAY_NAMES` wie
  `_build_button_label()`). Seit den Forschungsbüchern (siehe unten) drei
  Button-Zustände statt nur einem — Herstellen-Kosten-Prüfung selbst
  bleibt weiterhin ohne Vorab-Deaktivieren (Fehlschlag zeigt
  `report_status()` wie beim normalen Bauen), nur der Freischaltungs-
  Status wird jetzt vorab per `disabled` sichtbar gemacht.

**Vom Nutzer bestätigt getestet** (Grundfunktion, vor den
Forschungsbüchern unten): "crafting in der werkstatt hat soweit geklappt".

## Forschungsbücher (2026-08-01, Punkt 13 der Gesamtliste)

Baut auf dem gerade fertigen Crafting-System auf (siehe oben) — genau die
dort schon angelegte Lücke ("Kein Forschungsbücher-Gate, das ist Punkt
13") wird hier geschlossen. **Wichtige Abgrenzung** (Vision:
`Infos/02 Item-Liste.md`, "Forschungsbücher & Progression"): nur das MVP
("nur als Loot in der Welt"), NICHT das dortige Endgame-Feature
("lesend erlernt, dann über Werkstatt reproduzierbar/kopierbar") — kein
Buch-Kopieren, keine physischen Lese-Aktionen am Survivor, nur ein
Ressourcen-Verbrauch analog zu allen anderen Systemen hier.

- **Vier neue Ressourcenarten** `book_weapon`/`book_armor`/`book_helmet`/
  `book_ammo` (1:1 zu den `CRAFTING_RECIPES`-IDs) — siehe
  [`docs/base.md`](base.md).
- **Eigener, SELTENERER Drop-Mechanismus statt Teil von
  `ZOMBIE_LOOT_TABLE`:** die Vision beschreibt Bücher explizit als
  "selten"/"sehr selten" — ein gleichgewichteter Fünf-Typen-Pool
  (wie bei `ZOMBIE_LOOT_TABLE`) wäre viel zu häufig. Stattdessen
  `BOOK_DROP_CHANCE := 0.08`, unabhängig vom normalen Loot-Wurf ausgewürfelt
  (`World.grant_zombie_loot()`) — kann zusätzlich zu normalem Loot ODER
  ganz ohne ihn auftreten.
- **`HomeBase.unlocked_recipes: Dictionary`** (`recipe_id -> true`) —
  dauerhaft, kein Vergessen ("die Spieler-Kolonie behält das Wissen",
  Vision-Zitat). Kein Catch-up für spät beitretende Peers, gleiche
  bestehende Vereinfachung wie bei `resources`/`storage_capacity` (siehe
  [`docs/base.md`](base.md), "Bekannte Grenzen").
- **`World.request_research(recipe_id, requesting_peer_id)`**
  (`@rpc("any_peer", "call_local", "reliable")`): verbraucht 1× das
  passende `book_<id>`, ruft `HomeBase.unlock_recipe.rpc(recipe_id)` auf.
  Bewusst OHNE Werkstatt-Pflicht (Lesen geht überall, nur das eigentliche
  Herstellen bleibt an die Werkstatt gebunden, siehe oben).
- **`request_craft()`** prüft jetzt zusätzlich `base.unlocked_recipes.get(
  recipe_id, false)`, bevor es überhaupt zur Kosten-/Bezahlbarkeits-Prüfung
  kommt — ohne Forschung kein Herstellen, unabhängig von Ressourcen.
- **`CraftingUI`-Buttons, drei Zustände:** erforscht → normaler
  Herstellen-Button (Kosten/Ertrag). Nicht erforscht, aber Buch vorhanden →
  "X erforschen (Buch: ...)"-Button. Nicht erforscht, kein Buch → derselbe
  Button, aber `disabled = true` (sichtbar, damit Spieler wissen, was es
  gibt, aber nicht klickbar).

**Noch nicht vom Nutzer getestet.**

## Fehlschlag-Feedback

`_report_build_failure(peer_id, build_position, cost)` unterscheidet, ob
die Zonenprüfung oder die Ressourcenprüfung fehlgeschlagen ist, und
schickt per `report_status()` (siehe [`docs/networking.md`](networking.md))
die passende Meldung ("Zu weit von der eigenen Zone entfernt." bzw.
"Nicht genug Ressourcen.").

## Wachturm + Holzmauer (eigene 3D-Assets)

Zweite und dritte eigene 3D-Assets des Nutzers nach der Home-Base (siehe
[`docs/base.md`](base.md)): `assets/wachturmtest.glb` ersetzt die
Platzhalter-Box in `GuardPost.tscn`, `assets/holzmauertest.glb` die in
`Wall.tscn` — **nur** die Mauer, nicht das Tor (`Gate.tscn` ist eine
eigenständige Szene mit demselben `Wall.gd`-Script, bleibt bewusst bei der
Box). Gleiches `[node name="Model" ... instance=ExtResource(...)]`-Muster
wie bei der Home-Base, alte `BoxMesh` bleibt jeweils unsichtbar für die
Kollisionsform erhalten.

**Farb-Feedback musste generalisiert werden:** Wachposten (Baugelb →
Fertig-Grau) und Mauer (HP-abhängiges Nachdunkeln) färbten bisher genau
EIN `$Mesh`-Node ein — die importierten Modelle haben aber beliebig viele
verschachtelte `MeshInstance3D`-Kinder (Wachturm z. B. über 20). Neue
`_find_mesh_instances(node)` (rekursiv, in beiden Scripts bewusst
dupliziert statt geteilt) sammelt alle davon ein, `_update_color()` färbt
jetzt alle statt nur der einen (jetzt unsichtbaren) Box. `Wall.gd` prüft
zusätzlich, ob überhaupt ein `$Model`-Node existiert — fällt sonst (Gate)
auf die alte Einzel-Mesh-Logik zurück, damit Tore weiterhin ihre
HP-Farbe bekommen.

**Noch nicht vom Nutzer visuell bestätigt** (Skalierung/Ausrichtung könnte
je nach Blender-Exportgröße daneben liegen, wie zuvor bei der Home-Base).

## Wachposten (`GuardPost.gd`)

Baubares Verteidigungsgebäude, host-autoritativ wie Survivor/Zombie.
`_process()` läuft nur auf dem Host (`set_process(false)` sonst).

- **Bauzeit:** `BUILD_TIME := 5.0` Sekunden ab Spawn, danach
  `_set_built_visual()` (RPC, `call_local` Pflicht — sonst sieht der Host
  seinen eigenen fertigen Wachposten nie grau werden) schaltet die Farbe
  von Baugelb auf Fertig-Grau.
- **Feuert automatisch** auf Zombies **und Zombie-Nester** (siehe
  [`docs/zombies.md`](zombies.md), "Zombie-Nest") in `FIRE_RANGE` (6.0),
  Cooldown `FIRE_COOLDOWN := 1.0`, Schaden `FIRE_DAMAGE := 10` — **aber nur,
  solange mindestens ein Arbeiter stationiert ist** (`_stationed_workers`
  nicht leer). Ein fertig gebauter, aber unbemannter Wachposten schießt
  nicht.
- **Lärm:** jeder Schuss auf einen echten Zombie alarmiert weitere Zombies
  in `FIRE_NOISE_RADIUS` (13.0) — dupliziert bewusst
  `Zombie._alert_nearby_zombies()` statt einer geteilten Utility-Funktion
  (siehe "Bewusst dupliziert statt geteilt" unten). Schüsse auf ein Nest
  lösen bewusst keinen Alarm aus (kein bewegliches Ziel, siehe
  [`docs/zombies.md`](zombies.md)).

### Arbeiter zuweisen

- **HUD:** `World._refresh_worker_ui()` baut pro eigenem Wachposten eine
  Zeile mit Namen/Arbeiterzahl und zwei Buttons.
- **"Arbeiter zuweisen"** → `request_worker(requesting_peer_id)`
  (`@rpc("any_peer", "call_local", "reliable")`, host-only wirksam): sucht
  per `_find_idle_trupp()` den ersten eigenen Trupp mit `is_idle() ==
  true` und ruft `trupp.order_station(self)` auf. Kein freier Trupp →
  `report_status(peer_id, "Kein freier Trupp verfügbar.")` statt stiller
  Ablehnung.
- **"Arbeiter abziehen"** (nur sichtbar, wenn `worker_count > 0`) →
  `request_recall_worker(requesting_peer_id)`: nimmt
  `_stationed_workers[0]` und ruft `trupp.order_stop(requesting_peer_id)`
  auf — `order_stop()` löst intern schon `_unstation()` →
  `unregister_worker()` aus, kein doppelter Code nötig.
- **`register_worker()`/`unregister_worker()`** pflegen
  `_stationed_workers` und synchronisieren `worker_count` per
  `_sync_worker_count.rpc()` — die reine Zahl reicht fürs HUD, welche
  konkreten Trupps stationiert sind, ist nur host-seitig relevant.

## Lager

Dritte Ausbau-Option (siehe "Ausbauen" oben) — im Unterschied zu
Krankenstation/Werkstatt hebt ein Lager nicht Baukosten oder Heilrate,
sondern die **Speicherkapazität** der eigenen Home-Base an. Löst damit die
frühere Voraussetzung auf ("Lager braucht erst ein Ressourcen-Limit-
System") — das Limit-System entstand gleich mit.

- **`HomeBase.storage_capacity`** — EIN gemeinsamer Deckel für alle sieben
  Ressourcenarten (kein separates Limit pro Art). `BASE_STORAGE_CAPACITY
  := 150` gilt schon ohne jedes Lager. `HomeBase.add_resources()` deckelt
  seitdem jeden **Zuwachs** (`delta > 0`) an `storage_capacity` — Verlust
  (negatives Delta, z. B. Baukosten) bleibt immer uneingeschränkt möglich.
- **Kapazität aus Gebäude-Volumen berechnet**
  (`World._building_volume(building)` — liest `size` der `BoxMesh` unter
  `$Mesh` aus, `size.x × size.y × size.z`), multipliziert mit
  `STORAGE_CAPACITY_PER_VOLUME := 40.0`. Kalibriert an
  `Infos/03 Asset-Checkliste.md` (Nutzer-Vorgabe: ein "Wohnhaus" grob 500
  Kapazität, ein "Hochhaus"/eine "alte Schule" grob 1000) — die
  aktuellen Platzhalter-Gebäude sind mit ~14–23 m³ aber viel kleiner als
  echte Gebäude aus der Vision (~500–1000 m³ laut Asset-Checkliste), der
  Faktor ist deshalb entsprechend hochskaliert, damit ein einzelnes Lager
  schon jetzt sinnvolle Werte (~550–920) liefert. **Muss neu kalibriert
  werden**, sobald echte, unterschiedlich große Gebäude-Assets die
  Platzhalter-Boxen ersetzen.
- **`Storage.gd`** trägt die berechnete Kapazität einmalig bei Erstellung
  ein (`_ready()` → `HomeBase.add_storage_capacity.rpc()`), rein
  host-seitig ausgelöst (`if not multiplayer.is_server(): return`) — sonst
  würde jeder verbundene Peer die eigene lokale Kopie des Nodes einmal
  zählen. Kein `_process()`, keine eigene HP/Zerstörbarkeit (wie
  Krankenstation/Werkstatt).
- **Ressourcen-Panel** zeigt seitdem `Wert/Kapazität` statt nur `Wert`
  (`World._update_resources_label()`).
- **Ausbauen-Button zeigt die konkrete Kapazität DIESES Gebäudes** —
  anders als bei Krankenstation/Werkstatt hängt der Nutzen hier vom
  ausgewählten Gebäude selbst ab, nicht nur von festen Kosten
  (`_refresh_building_upgrade_ui()`).

## Betten (2026-08-02, Punkt 16 der Gesamtliste)

Vierte Ausbau-Option (siehe "Ausbauen" oben), aus der Vision
(`Infos/02 Item-Liste.md`: "Betten/Schlafraum: Survivor-Regeneration
(Müdigkeit, Moral)"). Löst die Voraussetzung für das neue
Müdigkeits-/Moral-Bedürfnissystem auf (siehe
[`survivor.md`](survivor.md), "Bedürfnisse: Müdigkeit + Moral").

- **`Bed.gd`/`Bed.tscn`** — genauso schlank wie `MedicalStation.gd`: kein
  HP, kein Bautimer, reiner Datenträger (`bed_id`/`owner_peer_id`),
  Gruppe `"bed"` über den `.tscn`-Node-Header.
- **`BuildType.BED`**, `BED_COST := {"wood": 20}` — Holz statt der
  Vision-Angabe "Holz + Baumaterial" (kein generisches "Baumaterial" in
  diesem Ressourcensystem, siehe [`base.md`](base.md), "Vier
  Baurohstoffe"), gleiches Vereinfachungsmuster wie bei allen anderen
  Bautypen hier.
- **`request_upgrade_building()`** spawnt bei `BuildType.BED` über
  `bed_spawner` — identischer Ablauf wie Krankenstation/Werkstatt/Lager
  (Building wird über den bestehenden Abriss-Pfad entfernt, ohne
  Rohstoff-Auszahlung, siehe "Ausbauen" oben).
- **Keine eigene Laufzeit-Logik am Gebäude selbst** — die eigentliche
  Regeneration passiert in `Survivor._handle_resting()`
  (`BED_REST_RADIUS` 5.0 um ein eigenes Bett), siehe
  [`survivor.md`](survivor.md).
- **Fund beim Umsetzen:** ein Grundgerüst (Szene, Kosten-Konstante,
  Spawner/Container, UI-Button) lag schon im Code, war aber nicht fertig
  verdrahtet — `_cost_for_build_type()`/`request_upgrade_building()`
  kannten `BuildType.BED` noch nicht (Fallback auf Wachposten-Kosten UND
  falsches Gebäude), kein Catch-up (`_catch_up_bed()` fehlte komplett),
  kein Speicherstand-Eintrag, und auf `Survivor.gd` existierte das
  eigentliche Bedürfnissystem noch gar nicht. Alles ergänzt, siehe
  [`survivor.md`](survivor.md) für die Survivor-Seite.

**Noch nicht vom Nutzer getestet.**

## Krankenstation + Werkstatt (keine eigene Laufzeit-Logik)

`MedicalStation.gd`/`Workshop.gd` sind reine Datenträger (`..._id`,
`owner_peer_id`), ohne `_process()`, unverändert seit dem Baumenü-Umbau —
nur die Art, wie sie entstehen, hat sich geändert (siehe "Ausbauen" oben).
Ihr Effekt entsteht komplett in anderen Scripts:

- Krankenstation: `Survivor._handle_healing()` sucht per
  `_find_nearby_medical_station()` nach einer Station in
  `MEDICAL_STATION_HEAL_RADIUS` (5.0) und heilt dann mit doppelter Rate
  (`MEDICAL_STATION_HEAL_RATE`) statt der Home-Base-Basisrate — siehe
  [`docs/survivor.md`](survivor.md).
- Werkstatt: `World._cost_for_build_type()`/`_has_own_workshop()`, siehe
  oben.

## Bewusst dupliziert statt geteilt

Mehrere kleine, fast identische Logikblöcke sind absichtlich **nicht** in
eine gemeinsame Utility-Funktion extrahiert, weil sie an unterschiedlichen
Stellen im Node-Baum sitzen (`GuardPost` vs. `Zombie`) und der
Abstraktionsaufwand den Nutzen bei diesem Umfang nicht rechtfertigt:
Lärm-Alarm-Schleife (`_alert_nearby_zombies()` in `GuardPost.gd` und
`Zombie.gd`), `OBSTACLE_LAYER`-Konstante (`Survivor.gd`/`Zombie.gd`).

## Bekannte Grenzen (noch nicht gelöst)

- **Kein Catch-up für `built`/`worker_count`** bei spät beitretenden
  Peers über die reine Node-Existenz hinaus — `_catch_up_guard_post()`
  spawnt den Node korrekt, aber ein bereits fertig gebauter Wachposten
  erscheint beim neuen Peer kurz im Baugelb, bis der nächste Sync-Zufall
  ihn korrigiert (kein expliziter State-Catch-up wie bei `is_looted`).
- **Nur ein Wachposten-Typ**, keine Ausbaustufen.
- **Keine Reichweiten-/Zonen-Vorschau** außer dem punktuellen Ghost am
  Mauszeiger.
- **Kapazitäts-Faktor fürs Lager an Platzhalter-Gebäudegrößen kalibriert**
  — muss neu justiert werden, sobald echte Gebäude-Assets die Boxen
  ersetzen, siehe "Lager" oben.
- **Ausbauen hat kein Ghost-Preview/keine Bestätigung** — Klick auf den
  Button baut sofort um (bei Erfolg), anders als der Bau-Fluss mit
  Ghost-Vorschau.
- **Kein Catch-up beim Ausbauen für spät beitretende Peers** — dasselbe
  bereits bestehende Problem wie bei `Building.is_looted` (siehe
  [`docs/scavenging.md`](scavenging.md)): ein spät beitretender Peer
  sieht ein bereits ausgebautes Gebäude lokal weiterhin als unausgebautes
  `Building`.
- **Außenposten: "Rasten/Schlafen" aus der Vision nicht umgesetzt** —
  braucht erst ein Müdigkeits-/Bedürfnissystem (Punkt 16 der Gesamtliste,
  siehe `docs/status.md`). Nur die Rückweg-Funktion ist umgesetzt.
- **Außenposten haben kein HP/keine Zerstörbarkeit** (wie
  `MedicalStation`/`Workshop`) und keinen eigenen Bau-Timer.

## Testen

Debug → Customize Run Instances → 2 → F5, Host + Join, "Spiel starten".
Wachposten in Home-Base-Nähe bauen (Preview sollte grün sein, rot außerhalb
der Zone), 5 Sekunden warten (Farbwechsel), "Arbeiter zuweisen" klicken —
Zombie in Reichweite laufen lassen und Beschuss beobachten. "Arbeiter
abziehen" klicken, Trupp sollte wieder frei wählbar/befehligbar sein.

**Felder:** Feld bauen, ein paar Sekunden warten — Nahrung im
Ressourcen-Panel sollte alle 8s um 2 steigen.

**Ausbauen:** ein Gebäude durchsuchen und claimen lassen (siehe
[`docs/zones.md`](zones.md)), danach OHNE Trupp-Auswahl draufklicken —
"Ausbauen"-Abschnitt sollte im "Bauen"-Tab erscheinen. "Zu
Krankenstation ausbauen" klicken — Gebäude sollte verschwinden, an
derselben Stelle eine Krankenstation erscheinen, Ziegel im
Ressourcen-Panel sollten sinken. Buttontext der übrigen Bautypen prüfen,
nachdem eine eigene Werkstatt existiert — Preis sollte sich um 20 %
reduzieren.

**Lager:** ein zweites Gebäude claimen, "Zu Lager ausbauen" klicken —
Kapazitätszahl im Button (z. B. "+700 Kapazität") sollte plausibel wirken.
Danach im Ressourcen-Panel prüfen, ob die zweite Zahl (`Wert/Kapazität`)
gestiegen ist. Eine Ressource bis zum alten, niedrigeren Deckel
hochsammeln lassen (z. B. viele Bäume fällen) — sollte jetzt über den
alten Deckel hinaus weiter steigen, bis zum neuen.
