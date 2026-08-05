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

**Echtes Asset seit 2026-08-04** (`assets/feld.glb`) — ersetzt die
Platzhalter-Box (2,5×0,2×2,5m), gleiches Vorrang-/Y-Ausgleich-Prinzip wie
beim Wohnhaus. Keine Farb-/HP-Logik nötig (Field hat kein
`_update_color()`, keine Zerstörbarkeit), deshalb reine `.tscn`-Änderung
ohne Skript-Anpassung. Größe nicht extra vom Nutzer bestätigt, am
Platzhalter orientiert.

**Ghost-Preview-Fix (2026-08-04):** Nutzer-Feedback "die vorschau vom
feld ist zu klein" — Feld fiel beim Platzieren vorher generisch auf die
kleine 1,5³-Wachposten-Ghost-Box zurück (`_update_build_ghost()`,
`World.gd`). Neue, passend große `_field_ghost_mesh`
(`FIELD_GHOST_SIZE := Vector3(2.5, 0.2, 2.5)`), gleiches Muster wie
`_watchtower_ghost_mesh`. Zeigt weiterhin eine (jetzt richtig große)
grün/rote Box, NICHT das echte Modell selbst — das würde eine größere
Umstellung des Ghost-Systems brauchen (aktuell ein einzelnes
austauschbares `MeshInstance3D.mesh`, kein generischer Szenen-Container).

## Außenposten (`Outpost.gd`, 2026-08-01, Punkt 8 der Gesamtliste)

Aus der Vision übernommen (`Infos/01 Architektur.md`, "Außenposten": "Kleine,
unabhängige Bauten außerhalb der Hauptzone, nur zum Rasten/Schlafen der
Trupps — Ausnahme von der Zusammenhang-Regel"). Ursprünglich (2026-08-01)
nur die zweite, in der Vision genannte Funktion umgesetzt — ein kürzerer
Rückweg beim Scavenging ("Rückweg zur Basis (oder zum Außenposten zum
Zwischenlagern)", `Infos/01 Architektur.md`, "Trage-Kapazität") — mit dem
Vorbehalt, "Rasten/Schlafen" bräuchte erst ein Müdigkeits-/Bedürfnissystem,
das es damals noch nicht gab. Das System kam einen Tag später (Betten,
Punkt 16 der Gesamtliste), der Außenposten wurde dabei aber nie
nachgerüstet — erst am 2026-08-04, bei der Systematik-Review (Fund 5),
aufgefallen und behoben: **`Survivor._handle_resting()` akzeptiert seitdem
auch einen eigenen Außenposten als Rastpunkt**, exakt wie ursprünglich in
der Vision vorgesehen (siehe [`survivor.md`](survivor.md),
"Bedürfnisse: Müdigkeit + Moral").

- **Ursprünglich einziger Bautyp ohne Zonen-Prüfung** — das war die
  "Ausnahme von der Zusammenhang-Regel" aus der Vision, ein Außenposten
  ließ sich schon immer überall platzieren. Seit dem Wegfall der
  Zonen-Abstandsprüfung für ALLE Bautypen (2026-08-03, siehe "Zonen-Prüfung"
  unten) ist das kein Sonderfall mehr, gilt inzwischen für jeden Bautyp
  gleichermaßen.
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

Krankenstation/Werkstatt/Lager/Schlafraum entstehen seit dem Baumenü-Umbau
**nicht** mehr durch freies Platzieren, sondern durch Ausbauen eines
bereits geplünderten UND vom Spieler selbst geclaimten Gebäudes (siehe
[`docs/zones.md`](zones.md) fürs Claimen selbst). Seit dem Bau-Markier-
Modus (Punkt 28 der Gesamtliste, siehe unten) läuft dieser Ausbau **nicht
mehr sofort**, sondern über einen offenen Bauauftrag mit zuweisbaren
Bautrupps.

- **Auswählen:** Klick auf ein eigenes, geclaimtes Gebäude OHNE offenen
  Bauauftrag (egal ob gerade ein Trupp ausgewählt ist oder nicht —
  `World._select_at()`, `"searchable"`-Branch, läuft dafür bewusst
  unabhängig von `selected`) setzt `_selected_claimed_building` und
  blendet einen "Ausbauen"-Abschnitt im "Bauen"-Tab ein
  (`_refresh_building_upgrade_ui()`, siehe [`world.md`](world.md),
  "UI-Overhaul") — kein eigenes Panel.
- **`World.request_start_construction(building_path, upgrade_type,
  requesting_peer_id)`** (`@rpc("any_peer", "call_local", "reliable")`,
  vorher `request_upgrade_building()` — umbenannt, weil es seit dem
  Bau-Markier-Modus nicht mehr sofort baut): prüft Besitz
  (`building.owner_peer_id == requesting_peer_id`), dass noch kein
  Bauauftrag läuft, und Bezahlbarkeit (`_cost_for_build_type(upgrade_type,
  ...)`, dieselben Kosten wie das frühere freie Platzieren). Zieht die
  Kosten SOFORT ab (verhindert, dass mehrere Bauaufträge mit
  nicht-vorhandenen Ressourcen gestartet werden), ruft dann
  `building.start_construction(upgrade_type, required_work)` — das
  Building bleibt dabei bestehen (nur amberfarben eingefärbt, siehe unten),
  nichts wird sofort ersetzt.
- **Lager** ist inzwischen als dritte (vierte) Ausbau-Option umgesetzt.

## Baustellen (Bau-Markier-Modus, Punkt 28 der Gesamtliste, 2026-08-04)

RTS-typisches "Gebäude markieren, Bautrupps zuweisen, Baufortschritt läuft
über Zeit" statt des früheren Ein-Klick-Sofortbaus — Nutzerwunsch aus der
Planungssession vom 2026-08-03 Abend: "man kann geclaimte gebäude sagen
das soll ein lager werden dann ein krankesation etc. und dann sagen 3 bau
units dort hin 4 dort hin etc. besseres management rts feeling".

- **Datenmodell (auf `Building.gd`, nicht `World.gd`):**
  `has_open_construction`/`construction_target_type` (als `int` gehalten,
  nicht als `World.BuildType` typisiert — `Building.gd` kennt `World.gd`
  bewusst nicht als Typ-Abhängigkeit)/`construction_progress`/
  `construction_required`/`construction_worker_count`/
  `_construction_workers` (Array, privat).
- **Bauzeit:** `World._construction_work_required()` — bis 2026-08-04 hatten
  Krankenstation/Werkstatt/Schlafraum einen FESTEN Wert (30/35/20 Trupp-
  Sekunden), unabhängig von der Größe des ausgewählten Gebäudes, nur das
  Lager skalierte mit dem Volumen. Bei den jetzt sehr unterschiedlich
  großen echten Gebäude-Assets (Tankstelle ~90 m³ bis Supermarkt ~927 m³)
  fiel diese Inkonsistenz bei der Systematik-Review auf — **alle vier
  Ausbauten skalieren jetzt mit dem Gebäude-Volumen**, exakt wie das
  Lager: `BED_CONSTRUCTION_WORK_PER_VOLUME := 0.03`,
  `MEDICAL_STATION_CONSTRUCTION_WORK_PER_VOLUME := 0.045`,
  `WORKSHOP_CONSTRUCTION_WORK_PER_VOLUME := 0.05`,
  `STORAGE_CONSTRUCTION_WORK_PER_VOLUME := 1.5 → 0.05` (ebenfalls neu
  kalibriert, siehe "Lager" oben — der alte Wert hätte bei echten
  Gebäude-Volumen absurd lange Bauzeiten ergeben). Faktoren so gewählt,
  dass ein Wohnhaus (671 m³) ungefähr die alten Flachwerte trifft (Bett
  20,1s, Krankenstation 30,2s, Werkstatt 33,6s) — größere Gebäude dauern
  jetzt proportional länger, kleinere kürzer, statt für jede Gebäudegröße
  gleich lang. **Nur die Bauzeit skaliert, nicht die Ressourcenkosten**
  (`_cost_for_build_type()` bleibt bewusst flach) — gleiches Prinzip wie
  beim Lager selbst (dort skaliert auch nur Zeit+Kapazität, nicht der
  Holzpreis). Alles weiterhin Startwerte, nach Testen nachjustierbar.
- **Fortschritt:** `Building._process()` (host-only wie GuardPost/Survivor,
  erst seit dem Bau-Markier-Modus hat `Building.gd` überhaupt einen
  `_process()`) erhöht `construction_progress` um
  `_construction_workers.size() * CONSTRUCTION_WORK_PER_TROOP * delta` —
  mehr zugewiesene Bautrupps bauen also schneller, exakt wie gewünscht.
  Ein throttled Sync-RPC (`CONSTRUCTION_SYNC_INTERVAL := 0.5s`, gleiches
  Throttle-Prinzip wie die Fog-of-War-/Worker-UI-Refresh-Intervalle)
  repliziert den Fortschritt an alle Peers für die UI.
- **Fertigstellung:** sobald `construction_progress >= construction_required`,
  ruft `Building._process()` `World.finish_construction(building)` auf
  (Building kennt seine World-Spawner nicht selbst, gleiches
  Cross-Node-Prinzip wie unten bei "Bewusst dupliziert statt geteilt") —
  das macht denselben Umbau, den früher `request_upgrade_building()`
  sofort gemacht hat: alle noch zugewiesenen Trupps freigeben
  (`order_stop()`), `building.take_damage(building.hp)` (derselbe
  netzwerksichere Abriss-Pfad wie beim echten Abreißen, siehe
  [`docs/survivor.md`](survivor.md), "Gebäude abreißen", aber ohne die
  dortige Rohstoff-Auszahlung), dann die Zielstruktur spawnen.
- **Trupps zuweisen:** entweder direkt in der Welt auf die (amberfarbene)
  Baustelle klicken, während Bautrupps ausgewählt sind (`World._select_at()`
  – Sonderfall im `"searchable"`-Branch), oder über den "Trupp
  zuweisen"-Button in der neuen Baustellen-Liste im "Bauen"-Tab
  (`_refresh_construction_ui()`, `ConstructionList`) — beide rufen
  `_assign_selected_to_construction()`, das für jeden ausgewählten Trupp
  `Survivor.order_station_at_building(building_path, peer_id)` sendet
  (neues RPC, NodePath-Argument aus demselben Grund wie
  `order_search()`/`order_claim_building()`). Nur `TroopType.BUILD`
  (gleiche Exklusivität wie `order_harvest()`).
- **Registrierung wiederverwendet das Wachposten-Muster:** bei Ankunft
  registriert sich der Trupp am Building genau wie an einem `GuardPost`
  (`Survivor._stationed_at`/`_unstation()` werden mitbenutzt) —
  **Abziehen/Umverteilen braucht dadurch keinen neuen Code**, läuft über
  denselben bestehenden `order_stop()`-Pfad. Der "Trupp abziehen"-Button in
  der Baustellen-Liste ruft `Building.request_recall_worker()` (identisch
  zu `GuardPost.request_recall_worker()`).
- **Stornieren mit Rückerstattung:** `World.request_cancel_construction(
  building_path, peer_id)` erstattet die Kosten (`_cost_for_build_type()`
  live berechnet, z. B. mit aktuellem Werkstatt-Rabatt statt dem
  ursprünglich gezahlten Betrag), zieht alle zugewiesenen Trupps ab und
  ruft `building.cancel_construction()` — das Gebäude fällt zurück in den
  normalen "geplündert + geclaimt"-Zustand (blau statt amber).
- **Persistenz + Catch-up:** `has_open_construction`/
  `construction_target_type`/`construction_progress`/
  `construction_required` sind jetzt Teil von `_collect_save_data()`/
  `_catch_up_building()`/`_create_building()` (gleiches optionale-
  Zusatzfeld-Muster wie `is_looted`/`owner_peer_id`/`hp`). **Bewusste
  Lücke:** die zugewiesenen Trupps selbst (`_construction_workers`)
  werden NICHT mitgespeichert/übertragen — nach Laden/Beitritt läuft der
  Fortschritt weiter, aber mit 0 zugewiesenen Trupps, der Spieler muss
  neu zuweisen. Eine stabile Trupp-ID-Verknüpfung übers Savegame gibt es
  nirgends in der Codebase, das wäre ein deutlich größerer Zusatzaufwand
  für einen Randfall (Baupause exakt beim Speichern/Rejoin).
- **Visuell:** amberfarben (`Color(0.9, 0.6, 0.15)`), geht dem
  "geclaimt"-Blau in `Building._update_visual()` vor.
- Noch nicht vom Nutzer getestet, siehe `docs/pending-tests.md`.

## Zonen-Prüfung (`_can_build_at()`) — Abstandsteil entfernt (2026-08-03)

```gdscript
func _can_build_at(peer_id: int, build_position: Vector3, cost: Dictionary, type: BuildType = BuildType.GUARD_POST) -> bool:
    return _can_afford(peer_id, cost)
```

Prüft seit einem Nutzerwunsch (`test.txt`: "man kann nicht überall bauen
können das sollte man") nur noch die Bezahlbarkeit — die frühere
Abstandsprüfung `is_within_own_zone()`/`BUILD_RADIUS` (8 Weltmeter um
Home-Base oder geclaimte Gebäude) ist komplett aus `World.gd` gelöscht,
Details zur alten Regel und Design-Begründung (jetzt historisch) in
[`docs/zones.md`](zones.md). Bauen ist seitdem überall auf der Karte
möglich — der Außenposten (siehe oben, ehemals "die einzige Ausnahme von
der Zonen-Regel") ist dadurch kein Sonderfall mehr, der `type`-Parameter
bleibt aber für mögliche künftige typspezifische Regeln erhalten.

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

- **Eine Ressourcenart, `book_research`** (`World.RESEARCH_BOOK_RESOURCE`)
  schaltet JEDE Freischaltung frei — Crafting-Rezept ODER Gebäude-
  Ausbaustufe, egal welche (siehe "Universal-Buch-Migration" unten). Vor
  2026-08-04 gab es hier fünf getrennte `book_<id>`-Ressourcen, eine pro
  Rezept/Ausbaustufe.
- **Eigener, SELTENERER Drop-Mechanismus statt Teil von
  `ZOMBIE_LOOT_TABLE`:** die Vision beschreibt Bücher explizit als
  "selten"/"sehr selten" — ein gleichgewichteter Pool (wie bei
  `ZOMBIE_LOOT_TABLE`) wäre viel zu häufig. Stattdessen
  `BOOK_DROP_CHANCE := 0.08`, unabhängig vom normalen Loot-Wurf ausgewürfelt
  (`World.grant_zombie_loot()`) — kann zusätzlich zu normalem Loot ODER
  ganz ohne ihn auftreten.
- **`HomeBase.unlocked_recipes: Dictionary`** (`recipe_id -> true`) —
  dauerhaft, kein Vergessen ("die Spieler-Kolonie behält das Wissen",
  Vision-Zitat). Kein Catch-up für spät beitretende Peers, gleiche
  bestehende Vereinfachung wie bei `resources`/`storage_capacity` (siehe
  [`docs/base.md`](base.md), "Bekannte Grenzen").
- **`World.request_research(recipe_id, requesting_peer_id)`**
  (`@rpc("any_peer", "call_local", "reliable")`): verbraucht 1×
  `book_research`, ruft `HomeBase.unlock_recipe.rpc(recipe_id)` auf.
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

## Universal-Buch-Migration (2026-08-04)

Nutzer-Entscheidung aus der IFZ-Gap-Analyse (siehe `Infos/07 Backlog-
Umsetzungspläne.md`, "Forschungszentrum + echter Tech-Baum"): statt fünf
getrennter `book_<id>`-Ressourcen (eine pro Crafting-Rezept/Gebäude-
Ausbaustufe) gibt es jetzt genau EINE, `World.RESEARCH_BOOK_RESOURCE :=
"book_research"` — schaltet jede Freischaltung gleichermaßen frei.
Einfacheres Ressourcenmodell (ein Loot-Typ statt vieler), Vorbereitung für
einen möglichen künftigen echten Tech-Baum (siehe `Infos/08 Weg zur
1.0.md`).

- **Betroffen:** `RESOURCE_DISPLAY_NAMES`/`RESOURCE_CATEGORIES` (ein
  Eintrag "Forschungsbuch" statt fünf), Zombie-Buch-Drop
  (`grant_zombie_loot()`, kein Zufalls-Pick mehr nötig), Gebäude-
  Nebenloot (`_apply_loot_roll()`, `"book"` steht jetzt direkt für
  `book_research`), `_refresh_crafting_ui()`/`_refresh_advanced_medical_
  ui()`/`request_research()` (alle prüfen jetzt `book_research` statt
  `"book_%s" % recipe_id`).
- **`unlocked_recipes` selbst unverändert** — welches Rezept/welche
  Ausbaustufe erforscht ist, bleibt weiterhin pro `recipe_id` getrennt
  gespeichert, nur die dafür VERBRAUCHTE Ressource ist jetzt einheitlich.
- **Keine Rückwärtskompatibilität für alte Spielstände** mit den
  ehemaligen `book_weapon`/`book_armor`/`book_helmet`/`book_ammo`/
  `book_medical_upgrade`-Einträgen eingebaut (Prototyp-Stand, keine
  Notwendigkeit) — ein alter Spielstand würde diese Ressourcen einfach als
  unbekannte, nie mehr verbrauchbare Einträge im `resources`-Dictionary
  mitschleppen, keine harten Fehler.

**Noch nicht vom Nutzer getestet.**

## Erweiterte Krankenstation (2026-08-03, Punkt 24 der Gesamtliste)

Die Vision meint mit Forschungsbüchern eigentlich primär GEBÄUDE-
Ausbaustufen (`Infos/02 Item-Liste.md`, "Forschungsbücher & Progression":
Bücher wie "Elektrik 101"/"Landwirtschaft & Anbau"/"Verteidigungsanlagen"
schalten Stromgenerator/Garten-Anlage/Palisaden frei), nicht primär
Crafting-Rezepte wie Punkt 13 oben. Erste (und bewusst einzige, siehe
"Bewusst zurückgestellt" unten) konkrete Ausbaustufe: Erweiterte
Krankenstation, gleiche Buch-Mechanik wie oben, aber am Ende steht ein
Gebäude-Upgrade statt eines Items.

- **`World.BUILDING_RESEARCH: Array[Dictionary]`** — eigene, kleine Liste
  parallel zu `CRAFTING_RECIPES`, bewusst GETRENNT (kein "cost"/"yield",
  `request_craft()` würde sonst bei versehentlichem/böswilligem Aufruf mit
  dieser ID einen `KeyError` werfen). Aktuell ein Eintrag: `{"id":
  "medical_upgrade", "name": "Erweiterte Krankenstation"}`.
- **`World.request_research()` generalisiert** — prüft jetzt `_find_recipe()`
  ODER `_find_building_research()`, davon abgesehen unverändert (gleicher
  Buch-Verbrauch, gleiches `HomeBase.unlocked_recipes`-Dictionary als
  gemeinsamer Speicher für BEIDE Systeme). Neue Ressource `book_medical_upgrade`
  in `BOOK_LOOT_TYPES`/`BOOK_TABLE` (droppt also genau wie die anderen vier
  Bücher aus Zombie-Kills UND als Gebäude-Sekundärloot).
- **`MedicalStation.is_advanced: bool`** (statt eines zweiten Gebäudetyps)
  — `upgrade_to_advanced()` (`@rpc("authority", "call_local", "reliable")`)
  setzt es dauerhaft, kein Zurückbauen. Funktional einziger Unterschied:
  `Survivor._handle_healing()` nutzt `ADVANCED_MEDICAL_STATION_HEAL_RATE`
  (`HEAL_RATE * 3.0`) statt `MEDICAL_STATION_HEAL_RATE` (`* 2.0`), wenn die
  gefundene Station `is_advanced` ist. Kein visueller Unterschied (bewusst
  schlank, wie schon der Rest von `MedicalStation.gd`).
- **`World.request_upgrade_medical_station(requesting_peer_id)`**
  (`@rpc("any_peer", "call_local", "reliable")`) — ANDERS als
  `request_upgrade_building()` (Building → MedicalStation/Werkstatt/...,
  ersetzt einen Node durch einen anderen) wird hier eine BESTEHENDE
  MedicalStation in-place erweitert, kein Gebäudetausch. Kosten
  `MEDICAL_UPGRADE_COST := {"brick": 15, "medicine": 3}` (Vision: "5×
  Baumaterial + 3× Medizin", Ziegel als nächstliegender Baurohstoff analog
  zu `MEDICAL_STATION_COST`). Braucht: erforscht + eigene, noch nicht
  erweiterte Krankenstation (`_find_own_basic_medical_station()`) +
  bezahlbar.
- **UI: eigene Sektion im "Bauen"-Tab**, NICHT an eine Gebäude-Auswahl
  gebunden (anders als die "Ausbauen"-Buttons für claimte `Building`-Nodes)
  — sichtbar, sobald der Spieler mindestens eine eigene, nicht erweiterte
  Krankenstation besitzt. Ein Button, zwei Zustände: nicht erforscht →
  "Erweiterte Krankenstation erforschen (Buch: Medizinische Praxis)"
  (disabled ohne Buch), erforscht → "Krankenstation erweitern (15 Ziegel,
  3 Medizin)".
- **Catch-up + Speichern/Laden für `is_advanced`** ergänzt, gleiches
  optionales-Zusatzfeld-Muster wie `Building.is_looted`/`owner_peer_id`/
  `hp` (`_catch_up_medical_station()`/`_collect_save_data()`/
  `_load_game_state()`/`_create_medical_station()`). **`unlocked_recipes`
  selbst** (also OB "medical_upgrade" erforscht ist) hat weiterhin KEIN
  Catch-up/keine Persistenz — bestehende, schon dokumentierte Lücke seit
  Punkt 13 (siehe oben), gilt jetzt für beide Systeme gleichermaßen.
- **Bewusst zurückgestellt** (Scope-Entscheidung, um Punkt 24 nicht zu
  einer Fünf-Gebäude-Marathon-Aufgabe zu machen): Stromgenerator,
  Garten-Anlage (deckt sich großteils mit dem schon existierenden `Field.gd`
  ohne Buch-Gate), Palisaden/Falle-Module. Wachturm ist explizit ein
  eigener Listenpunkt (25, "Echter Wachturm mit Sichtweiten-Bonus").

**Noch nicht vom Nutzer getestet.**

## Echter Wachturm (Sichtweiten-Gebäude, 2026-08-03, Punkt 25 der Gesamtliste)

**Wichtige Begriffs-Klärung, um Verwechslung mit dem bestehenden
`GuardPost.gd` zu vermeiden:** die Vision unterscheidet explizit zwei
verschiedene Gebäude — "Wachposten" (Kampf, deckt `GuardPost.gd` ab) und
"Wachturm" (reine Sicht, "Erweiterte Sicht auf die Map, Zombie-
Früherkennung", `Infos/02 Item-Liste.md`). Verwirrend: `GuardPost.tscn`
nutzt seit "Wachturm + Holzmauer (eigene 3D-Assets)" oben zufällig ein
3D-Asset namens `wachturmtest.glb` als Modell, ist aber weiterhin
funktional der KAMPF-Wachposten. Dieser Abschnitt hier beschreibt das
NEUE, separate `Watchtower.gd`/`Watchtower.tscn` — reine Sichtweiten-
Funktion, kein Kampf, kein Worker-Slot.

- **Neue, eigene Entität** (`scenes/entities/watchtower/Watchtower.gd`,
  bewusst schlank wie `Outpost.gd`/`MedicalStation.gd`: kein HP, kein
  Bautimer, kein Ressourcen-Pool) — `watchtower_id`/`owner_peer_id`, sonst
  nichts. Platzhalter-Box (1,2×5×1,2, schiefergrauer Ton) statt eines
  echten Assets — 5m Höhe bewusst deutlich höher als die übrigen 1,5³-
  Bautypen, sichtbar als "Turm" erkennbar.
- **Freies Platzieren wie Wachposten/Feld/Außenposten** — vierter Button
  im "Bauen"-Tab (`WatchtowerButton`), gleicher Baumodus-/Ghost-Preview-
  Ablauf (`request_build_structure()`, `BuildType.WATCHTOWER` neu im
  Enum). Kosten `WATCHTOWER_COST := {"wood": 30, "metal": 20}` (Vision:
  "12× Holz + 8× Stahlrahmen", Stahlrahmen auf Metall umgehängt, gleiche
  Umhängungs-Logik wie bei Außenposten/Lager). **Bewusst OHNE
  Forschungsbuch-Gate** (Vision nennt zwei Bücher, "Verteid." + "Elektrik")
  — zwei neue Bücher nur für ein einziges Gebäude wären für den aktuellen
  Umfang unverhältnismäßig, siehe Scope-Entscheidung bei Punkt 24 oben.
- **Eigene Boden-Y + eigene Ghost-Mesh** (`WATCHTOWER_GROUND_Y := 2.5`,
  `WATCHTOWER_MESH_SIZE`) — bei 5m Höhe hätte der rohe Boden-Raycast-Y-Wert
  (wie bei den 1,5³-Typen) den Turm zum Großteil im Boden versinken lassen.
- **Sichtweiten-Bonus über das bestehende Fog-of-War-System** (siehe
  [`world.md`](world.md), "Fog of War") — `World._reveal_around()` bekommt
  einen optionalen `radius`-Parameter (Standard `FOG_VISION_RADIUS`),
  `_update_fog_of_war()` ruft ihn für jeden Wachturm zusätzlich mit
  `WATCHTOWER_VISION_RADIUS := 350.0` auf (vs. 130 für Einheiten/Home-Base)
  — deutlich größerer, dauerhaft aufgedeckter Bereich, kein neuer
  Mechanismus nötig.
- **"Zombie-Früherkennung" ist strukturell schon erfüllt, ohne eigenen
  Code:** Zombies werden auf Minimap/Kartenansicht bereits IMMER
  gezeichnet, unabhängig vom Fog-of-War-Stand (`Minimap.gd`/`MapView.gd`,
  `_draw_zombies()`, keine `is_cell_explored()`-Prüfung dort) — der
  Wachturm liefert einfach mehr aufgedecktes Terrain drumherum, in dem
  diese ohnehin schon sichtbaren Zombie-Punkte in Kontext (Straßen/
  Gebäude) erscheinen, statt im grauen Nebel zu schweben.
- **Kein eigener Kartenmarker** — Wachtürme werden (wie Wachposten/
  Außenposten/Krankenstation/Werkstatt/Lager) NICHT auf Minimap/
  Kartenansicht gezeichnet, nur Buildings/Home-Bases/"living"/Zombies
  haben eigene Marker. Bestehende, akzeptierte Einschränkung, kein neuer
  Rückschritt.
- **Catch-up + Speichern/Laden** vollständig (gleiches Muster wie
  Außenposten: `_catch_up_watchtower()`, `watchtowers`-Array in
  `_collect_save_data()`/`_load_game_state()`, `next_ids["watchtower"]`).

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

## Wohnhaus (echtes Asset, 2026-08-04)

Erstes Loot-Gebäude-Asset (`assets/wohnhaustest.glb`, Vorgabe siehe
`Infos/05 Assets im Spiel.md`, "Modellier-Prompt: Wohnhaus"). Anders als
Wachturm/Holzmauer/Home-Base (jeweils eine EIGENE `.tscn` mit fest
verdrahtetem `Model`-Node) teilen sich alle 14 Stadt-Gebäudetypen
dieselbe `Building.tscn` — das Modell wird deshalb NICHT statisch im
`.tscn` verdrahtet, sondern **dynamisch pro Instanz** in
`World._create_building()` per `load(model_path).instantiate()`
hinzugefügt, nur wenn der gewürfelte `BUILDING_TYPES`-Eintrag ein
`model_path`-Feld hat (aktuell nur Wohnhaus). Alle anderen Typen bleiben
unverändert Platzhalter-Boxen. Gleiches Fallback-Prinzip wie überall sonst
(`Mesh`-Box bleibt vorhanden, nur unsichtbar — `_collect_save_data()`
liest die Gebäude-Größe weiterhin darüber aus). `Building.model_path`
(neues Feld) wird bei Catch-up/Speichern mit übertragen, damit ein
Wohnhaus bei einem anderen Peer bzw. nach dem Laden wieder sein echtes
Modell bekommt statt auf die Box zurückzufallen.

**Farb-Feedback:** `Building._update_visual()` bevorzugt jetzt genau wie
`HomeBase.gd` einen `$Model`-Node (rekursiv über `_find_mesh_instances()`
eingefärbt), fällt ohne `Model` auf die alte Einzel-`$Mesh`-Logik zurück
— identisches Muster wie bei Wachturm/Mauer oben, hier ein drittes Mal
dupliziert statt geteilt.

**Maße aus der echten glTF-Bounding-Box ausgelesen** (nicht die Zielwerte
aus dem Prompt): 9,1m × 8,2m Grundfläche, 9,0m Höhe (Prompt sah 7m vor —
das Modell kam höher raus). `BUILDING_TYPES`-Eintrag/Kollisionsbox nutzen
diese echten Maße. **Straßenraster-Abstände angepasst**, weil das erste
reale Gebäude größer als jeder bisherige Platzhalter ist (siehe
Nutzerfrage "Supermarkt 18×12, Tiles nur 12×12"): `BUILDING_MIN_SPACING`
6m→10m, `BUILDING_ROW_INSET` 2m→5m (siehe `world.md`, "Straßen-Raster") —
gilt einheitlich für alle Typen, macht die Straßen insgesamt etwas
lichter besetzt, bis auch die übrigen Typen echte Assets bekommen.

## Supermarkt (echtes Asset, 2026-08-04)

Zweites Loot-Gebäude-Asset (`assets/supermarkttest.glb`) — noch ein
FRÜHER Entwurf des Nutzers ("noch keine Farbe drauf, nur mal grob Fenster
Türen zum Angucken"), gleiches Einbau-Muster wie beim Wohnhaus
(`World.SUPERMARKT_MODEL_PATH`, `model_path`-Feld im `BUILDING_TYPES`-
Eintrag).

- **Maße aus der echten glTF-Bounding-Box ausgelesen:** 18,1m × 4,2m ×
  12,2m — praktisch exakt die Vision-Zielwerte (18×4,5×12m, siehe
  `Infos/03 Asset-Checkliste.md`), kein Nachjustieren nötig. Genau der
  Größenbereich, für den das Mehrfach-Reihenplätze-System gebaut wurde
  (siehe [`world.md`](world.md), "Mehrfach-Reihenplätze") — der
  Supermarkt-Platzhalter hatte diese Maße schon VOR der Asset-Lieferung,
  jetzt bekommt er zusätzlich das echte Modell.
- **Modell-Ursprung nicht exakt an der Basis** — die glTF-Bounding-Box
  läuft von Y=−0,22 bis Y=4,0 (Wohnhaus lief dagegen exakt 0 bis 9, siehe
  oben), das Modell hätte dadurch ca. 22cm im Boden versunken. **Behoben
  (2026-08-04, siehe "Apotheke" unten):** statt weiterhin auf einen exakt
  bei 0 liegenden Ursprung zu vertrauen, liest `_model_min_y()` jetzt die
  TATSÄCHLICHE Unterkante jedes Modells aus und gleicht sie aus — der
  Supermarkt profitiert davon automatisch mit, ohne dass am Modell selbst
  etwas geändert werden musste.
- Noch OHNE eigenes Material/Farbe (Platzhalter-Grau aus Blender) — die
  Farb-Feedback-Logik (`Building._update_visual()`, siehe oben bei
  Wohnhaus) färbt trotzdem ein, sobald das Gebäude geclaimt/HP-gemindert
  wird, nur eben aktuell alles grau statt der finalen Textur.

**Noch nicht vom Nutzer im Spiel gesichtet.**

## Apotheke (echtes Asset, 2026-08-04)

Drittes Loot-Gebäude-Asset (`assets/Ahpoteke.glb`, Dateiname vom Nutzer so
geliefert, bewusst nicht umbenannt). Maße aus der echten glTF-Bounding-Box
(7,1×8,2×6,1m) — Grundfläche trifft den Checklisten-Zielwert (7×6m) fast
exakt, Höhe (8,2m) liegt weit über der Vorgabe (4,5m), gleiches Muster wie
schon beim Wohnhaus (Höhen kommen in der Praxis öfter höher raus als
geplant).

**Auslöser für eine generelle Korrektur:** Anders als Wohnhaus/Supermarkt
(Modell-Ursprung nahe Y=0, siehe dort) liegt der Ursprung dieses Assets
bei Y≈−7,17 relativ zur tatsächlichen Unterkante — die alte Annahme
"Modell-Ursprung ist die Basis" hätte das Gebäude um über 7m im Boden
versenkt. `World._model_min_y()` (neu) berechnet die tatsächliche
Unterkante rekursiv aus der Mesh-AABB aller Kind-Nodes, BEVOR das Modell
positioniert wird, und gleicht exakt diesen Wert aus (`model.position.y =
-size.y / 2.0 - _model_min_y(model)`) — funktioniert jetzt unabhängig
davon, wo genau der Ursprung in Blender liegt, nicht mehr nur für den
Sonderfall "Ursprung exakt an der Basis". Wohnhaus/Supermarkt profitieren
automatisch mit (ersetzt die dortige Sonderfall-Erklärung).

**Noch nicht vom Nutzer im Spiel gesichtet.**

## Grime-Overlay-Experiment (2026-08-04, Nutzerfrage)

Nutzerfrage: Modelle sind bisher nur flach eingefärbt (keine Vertex-AO,
keine Detail-Geometrie) — reicht ein Shader, um das aufzuwerten, oder
braucht es mehr Blender-Arbeit? Zwei güngstige, sofort testbare Optionen
gebaut, EXPLIZIT als A/B-Vergleich, noch nichts endgültig entschieden
(kein laufender Godot-Editor in dieser Entwicklungsumgebung verfügbar,
kann selbst nicht visuell gegenprüfen):

- **Grime-Overlay-Shader** (`assets/shaders/grime_overlay.gdshader`) —
  ein zusätzlicher `next_pass` auf JEDEM Material eines echten
  Asset-Modells (nur Gebäude bisher, siehe `_apply_grime_overlay()` in
  `World.gd`), legt fleckige, dunkle Patches per Value-Noise drüber,
  stärker nahe der Objekt-Basis (Verwitterung sammelt sich unten). Ändert
  die eigentliche Blender-Farbe nicht, reine Overlay-Ebene. Jedes Gebäude
  bekommt eine eigene Material-Kopie + eigenen Zufalls-Seed (`.duplicate()`
  Pflicht — ein importiertes glTF-Material ist sonst zwischen ALLEN
  Instanzen desselben Modells geteilt, gleiches Resource-Sharing-Problem
  wie bei `BoxMesh` in `_create_building()`, siehe dortiger Kommentar).
- **SSAO** (`Environment_day_night` in `World.tscn`, `ssao_enabled = true`)
  — Godots eingebautes Screen-Space-Ambient-Occlusion, verdunkelt Ecken/
  Kanten/Kontaktflächen automatisch aus der Tiefenkarte, KEIN eigener
  Shader-Code, KEIN Blender-Schritt nötig (Alternative zur ursprünglich
  angedachten Vertex-Color-AO, die einen zusätzlichen AO-Bake-Schritt in
  Blender gebraucht hätte).

Beide unabhängig voneinander vergleichbar/abschaltbar: SSAO über den
`Environment`-Inspektor (`ssao_enabled`-Haken), Grime-Overlay durch
Entfernen des `_apply_grime_overlay(model)`-Aufrufs in `_create_building()`.
Bisher nur auf Gebäude verdrahtet (nicht Wachposten/Mauer/Home-Base) —
Ausweitung auf die anderen echten Assets erst, falls der Effekt gefällt.

**Vom Nutzer bestätigt (2026-08-04): "besser so schaut ganz gut aus"** —
Grime-Overlay + SSAO zusammen bleiben aktiv. Dabei ein echter Bug
gefunden+behoben (siehe `status.md`, "Grime-Overlay-Bugfix"):
`_apply_grime_overlay()`s `base_material`-Variable löste die GDScript-
Variant-Inferenz-Falle aus (`node` ist als generischer `Node` deklariert,
`:=` kann den Rückgabetyp von `get_surface_override_material()` darüber
nicht ableiten) — Skript lud dadurch gar nicht, `World.tscn` fiel auf
den nackten `Node3D`-Basistyp zurück. Fix: `base_material` explizit als
`Material` typisiert statt `:=`.

## Nebel-Schleier (2026-08-04, Nutzerwunsch nach dem Grime/SSAO-Test)

Direkter Folgewunsch: "nebel fehlt dann noch ... ein ganz leichten nebel
schleier". Godots eingebauter, einfacher Distanz-Nebel (kein
`FogVolume`/volumetrischer Nebel — dafür reicht der einfache
`Environment`-Nebel, deutlich billiger, passt zum "ganz leicht"-Wunsch)
in `Environment_day_night` (`World.tscn`): `fog_enabled = true`,
`fog_density = 0.006` (bewusst niedrig gehalten), `fog_light_color =
Color(0.62, 0.64, 0.62, 1)` (neutrales Grau, passt zur schon bestehenden
Entsättigung statt eines bläulichen Himmel-Nebels). Werte nicht selbst
gegengeprüft (kein laufender Editor hier) — im Inspektor bei Bedarf
`fog_density` nachjustieren, falls zu stark/schwach.

**Vom Nutzer bestätigt (2026-08-04): "ja nebel schaut gut aus"** — bleibt
unverändert bei `fog_density = 0.006`.

## Platzhalter-Boxen auf echte Zielmaße vorgezogen (2026-08-04)

Nutzerwunsch: "lass vorerst Platzhalterboxen bis ich Blender weiter bin,
aber mach die Platzhalterboxen so groß wie die eigentlichen Gebäude" —
Freunde sollen schon jetzt testen, während weiter an echten Assets
gearbeitet wird, ohne dass die Stadt bei den noch-Platzhalter-Typen
unrealistisch klein wirkt (gleiches Vorziehen-Prinzip, das beim
Supermarkt schon vor dessen Asset-Lieferung angewendet wurde).

- **Zehn Loot-Gebäude** (`World.BUILDING_TYPES`, alle noch ohne Modell):
  Waffenladen/Polizeistation, Feuerwehrstation, Privatbunker, Restaurant/
  Kneipe, Tankstelle, Bibliothek, Universität, Garten-Center, Camping-
  Laden auf die exakten Maße aus `Infos/03 Asset-Checkliste.md`
  vorgezogen; Klinik + Militärbasis haben dort keinen Eintrag (Checkliste:
  "Map-abhängig" bzw. gar nicht gelistet), Größe aus `Infos/05 Assets im
  Spiel.md`s eigenem Vorschlag + geschätzter Höhe.
- **Vier "Ausbauten"** (Krankenstation/Werkstatt/Lager/Bett,
  `MedicalStation.tscn`/`Workshop.tscn`/`Storage.tscn`/`Bed.tscn`) und
  **Außenposten** (`Outpost.tscn`) ebenfalls auf Checklisten-Maße
  vergrößert (vorher alle ~1,5³, jetzt 3–6m je Achse).
- **Fund beim Vergrößern (echter Bug, gleich mitbehoben):**
  `finish_construction()` übernahm für die vier Ausbauten bisher
  ungeprüft `building.position.y` des GEPLÜNDERTEN Gebäudes (dessen
  eigenes Box-Zentrum) als Y-Position der NEUEN Struktur — bei überall
  ähnlich kleinen Platzhaltern fiel die Differenz kaum auf, bei einem
  großen Gebäude (z. B. Wohnhaus, Zentrum bei 4,5m) UND den jetzt
  größeren neuen Strukturen wäre die neue Struktur deutlich zu hoch in
  der Luft gelandet. Jede der vier bekommt jetzt ihre eigene halbe
  Zielhöhe (neue `MEDICAL_STATION_GROUND_Y`/`WORKSHOP_GROUND_Y`/
  `STORAGE_GROUND_Y`/`BED_GROUND_Y`-Konstanten). Außenposten (freies
  Platzieren wie Wachturm) bekam aus demselben Grund eine eigene
  `OUTPOST_GROUND_Y` + eigene, größenrichtige Ghost-Preview-Mesh
  (`OUTPOST_GHOST_SIZE`) statt der generischen 1,5³-Box.
- **Nicht angefasst:** Wachturm (Checklisten-Zahl dort laut `Infos/05`
  vertauscht/unplausibel, aktueller Platzhalter schon schmal+hoch wie
  gewollt), Tor/Mauer (eigenes Ziehen-System, Größe schon nah am
  Zielwert).

**Noch nicht vom Nutzer im Spiel gesichtet.**

## Gebäude-Varianten pro Typ (2026-08-04)

Nutzerwunsch: "brauchen die wohnhäuser variationen von den gebäuden für
mehr abwechslung wie bei IFZ" — IFZ hat automatisch Variation, weil es
echte OSM-Gebäude-Footprints nutzt (siehe `Infos/06 Infection Free Zone
Recherche.md`); KoopGames prozedurale Gebäude wiederholen sonst exakt
dasselbe Modell für jede Instanz eines Typs.

- **`World._pick_model_path(template)`** — neue, rein additive
  Infrastruktur: ein `BUILDING_TYPES`-Eintrag kann optional
  `"model_paths": Array[String]` statt nur `"model_path": String` haben.
  Ist das Array gesetzt, wählt `_generate_city_zone()` PRO INSTANZ
  zufällig eine Variante daraus, statt immer dasselbe Modell zu
  wiederholen. Bestehende Einträge mit nur `"model_path"` (aktuell alle,
  inkl. Wohnhaus) bleiben unverändert gültig.
- **Kein Zusatzaufwand bei Speicherstand/Catch-up** — die zufällige Wahl
  passiert nur einmal bei der Generierung, das Ergebnis wird danach wie
  bisher als fester `model_path`-Wert pro Building-Instanz
  gespeichert/repliziert (`Building.model_path`).
- **Für dich beim Modellieren:** eine zweite Wohnhaus-Variante (oder
  Variante für jeden anderen Typ) einzubauen braucht KEINE weitere
  Code-Änderung — einfach zweites `.glb` exportieren, in
  `BUILDING_TYPES` bei `"model_paths"` mit eintragen.
- **Empfehlung (siehe `Infos/08 Weg zur 1.0.md`):** erst alle 14 Typen
  einmal mit je einem Modell abdecken (Breite), dann erst Varianten
  einzelner Typen ergänzen (Tiefe) — bringt fürs Auge mehr, weil 14
  unterschiedliche Gebäude schon deutlich mehr Abwechslung liefern als
  mehrere Varianten desselben Typs.

**Erste echte Varianten seit 2026-08-04:** Wohnhaus bekommt drei
zusätzliche Varianten (`WOHNHAUS_VARIANT_2_PATH`/`_3_PATH`/`_4_PATH` —
laut Nutzer reine Farb-/Dach-Unterschiede, "hab einfach farben bischen
getauscht"), Supermarkt zwei zusätzliche (`SUPERMARKT_VARIANT_2_PATH`/
`_3_PATH`, deutlich höher als das erste Modell — 7,89m statt 4,2m,
vermutlich anderer Dachstil, geometrisch unproblematisch, der Y-Ausgleich
in `_create_building()` ist höhenunabhängig). Beide `BUILDING_TYPES`-
Einträge nutzen jetzt `"model_paths"` statt `"model_path"`. Wohnhaus-
`procedural_chance` gleichzeitig 0.5→0.3 gesenkt — bei vier statt einer
echten Variante hätte ein weiterhin hoher Prozedural-Anteil die neue
Abwechslung optisch verwässert.

**Noch nicht vom Nutzer im Spiel gesichtet.**

## Prozedurale "Masse"-Häuser (2026-08-04)

Direkte Folge der IFZ-Recherche-Nachfrage (siehe `Infos/06 Infection Free
Zone Recherche.md`) — IFZ hat automatische Gebäude-Varianz, weil es echte
OSM-Grundriss-Polygone extrudiert, kein Vorbild, das man mit Handarbeit
1:1 nachbauen kann. Nutzer-Entscheidung stattdessen: **er modelliert die
"speziellen" POI-Gebäude von Hand** (Home-Base, Krankenstation-Typen,
Militärbasis, Bibliothek etc.), **die "Masse" (Wohnhäuser) wird
prozedural generiert** — kein Blender-Aufwand für die zahlreichste,
narrativ unwichtigste Gebäudeart.

- **`World._random_house_proc_params()`** würfelt Breite/Tiefe/Wandhöhe/
  Dachhöhe (Bereiche grob am echten `wohnhaustest.glb` orientiert) plus
  einen Fassaden-/Dachfarbton aus je vier bzw. drei fest hinterlegten
  Paletten (angelehnt an den ursprünglichen Wohnhaus-Modellier-Prompt:
  "verwittertes Beige/Grau-Braun" Fassade, "dunkleres Rot-Braun oder
  Grau" Dach).
- **`World._build_procedural_house(params)`** baut daraus einen
  einfachen Box-Körper (`BoxMesh`) + Satteldach (`PrismMesh`,
  `left_to_right = 0.5` für eine mittige First-Kante statt eines
  schiefen Pultdachs) als generisches Model-Node — gleiche Y-Ausgleich-
  Konvention wie ein echtes Blender-Asset (Ursprung an der Basis, nicht
  mittig), läuft dadurch durch exakt denselben Code-Pfad in
  `_create_building()` wie ein geladenes `.glb`.
- **`BUILDING_TYPES`-Eintrag bekommt ein optionales `"procedural_chance"`-
  Feld** (0.0–1.0) — `_generate_city_zone()` würfelt PRO INSTANZ, ob ein
  echtes Modell (`model_path`/`model_paths`) oder ein prozedural
  generiertes Haus entsteht. Aktuell nur Wohnhaus, `procedural_chance :=
  0.5` (halb echtes Asset, halb generiert) — Wert bei Bedarf anpassen,
  0.0 = nie, 1.0 = immer prozedural.
- **`Building.proc_params: Dictionary`** — neues Feld, gleiches
  optionales-Zusatzfeld-Muster wie `model_path`, vollständig Speicherstand-
  UND Catch-up-fähig (`_collect_save_data()`/`_catch_up_buildings_bulk()`-
  Entry-Dictionary).
- **Größe (Collision/Bauplatz) wird aus den gewürfelten Maßen
  hergeleitet**, nicht aus der festen Vorlagen-`size` — sonst würde die
  Kollisionsbox nicht zum tatsächlich generierten Modell passen.
- **Auf andere Typen übertragbar:** einfach `"procedural_chance"` bei
  einem weiteren `BUILDING_TYPES`-Eintrag setzen — funktioniert nur
  sinnvoll für "haus-artige" Silhouetten (Box + Satteldach), nicht für
  sehr unterschiedlich geformte Spezialgebäude.

**Noch nicht vom Nutzer getestet.**

**Bewusst NICHT gelöst:** Gebäude bekommen bei der Generierung KEINE
Rotation (`_generate_city_zone()`/`_create_building()` setzen nie
`rotation`) — bei Platzhalter-Boxen unsichtbar, beim Wohnhaus mit seiner
erkennbaren Tür/Fassade jetzt sichtbar: die Vorderseite zeigt auf allen
vier Blockkanten in dieselbe Weltrichtung, nicht zur jeweils angrenzenden
Straße. Eigener, noch offener Folgeschritt (Rotation je nach Blockkante
in `_generate_street_slots()` mitgeben).

**Noch nicht vom Nutzer visuell bestätigt.**

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

### "Kein Arbeiter zugewiesen"-Label (2026-08-04)

Sichtbares Feedback statt nur des unauffälligen Nicht-Feuerns — ein
fertig gebauter, aber unbemannter Wachposten feuert nicht (siehe
`_try_fire()`), was sonst leicht übersehen wird.

- **`GuardPost.tscn`**, neuer `Label3D`-Kind-Node `NoWorkerLabel`
  ("Kein Arbeiter zugewiesen", `billboard`, `no_depth_test = true` — bleibt
  auch hinter dem Modell lesbar), Position grob über dem Wachturm-Modell
  (noch nicht feinjustiert, siehe unten).
- **`GuardPost._update_no_worker_label()`** setzt die Sichtbarkeit
  (`built and worker_count <= 0`), aufgerufen aus `_sync_worker_count()`
  (NICHT aus `register_worker()`/`unregister_worker()` selbst — die laufen
  nur host-seitig, `_sync_worker_count()` ist dagegen das
  `@rpc("authority", "call_local", ...)`, das tatsächlich JEDEN Peer
  erreicht) und aus `_set_built_visual()` (Bau-Fertigstellung).
- **Erbt dieselbe Catch-up-Lücke wie `worker_count`** (siehe "Bekannte
  Grenzen" unten) — ein spät beitretender Peer sieht das Label u. U.
  falsch (zeigt "kein Arbeiter" auch bei einem tatsächlich schon besetzten
  Wachposten), bis der nächste Registrierungs-/Abzieh-Event dort
  natürlich synct. Gleiche akzeptierte Priorität wie die bestehende
  Lücke.

**Noch nicht vom Nutzer getestet** (Label-Position über dem
Wachturm-Modell ist eine Schätzung, ggf. Y-Wert nachjustieren).

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
  `STORAGE_CAPACITY_PER_VOLUME`. Kalibriert an `Infos/03 Asset-
  Checkliste.md` (Nutzer-Vorgabe: ein "Wohnhaus" grob 500 Kapazität, ein
  "Hochhaus"/eine "alte Schule" grob 1000) — also ungefähr 1 Kapazität
  pro m³.
  **Neu kalibriert (2026-08-04):** `40.0 → 1.0`. Bis dahin gab es nur
  Platzhalter-Boxen (~14–23 m³), der Faktor war deshalb künstlich
  hochskaliert, mit dem eigenen Kommentar, das MUSS neu kalibriert
  werden, sobald echte Assets die Platzhalter ersetzen — beim alten
  Faktor hätte ein Lager aus dem inzwischen echten Supermarkt (927 m³)
  37.080 Kapazität ergeben (Home-Base-Basiskapazität ohne jedes Lager:
  150) — kompletter Balance-Bruch, gefunden bei der Systematik-Review nach
  dem Supermarkt-Einbau (siehe `docs/status.md`).
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
  [`survivor.md`](survivor.md). **Seit 2026-08-04 (Systematik-Review,
  Fund 5) auch um einen eigenen Außenposten** — siehe "Außenposten" oben,
  war ursprünglich genau dafür vorgesehen, wurde beim Bau der Betten-
  Mechanik aber nie nachgerüstet.
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

- **`built`-Catch-up behoben (2026-08-04, Korrektheits-Durchgang):**
  `_catch_up_guard_post()` schickt `built` jetzt mit (`_create_guard_post()`
  konnte das Feld schon länger verarbeiten, wurde beim Catch-up aber nie
  übergeben) — ein spät beitretender Peer sah vorher JEDEN bereits fertig
  gebauten Wachposten dauerhaft im "noch im Bau"-Gelb, ohne dass sich das
  je von selbst korrigiert hätte (kein periodischer Resync für dieses
  Feld, anders als die Formulierung hier vorher vermutete).
- **`worker_count`-Catch-up weiterhin fehlend** — betrifft nur die eigene
  Wachposten-Liste im Bauen-Tab (`_refresh_worker_ui()` zeigt ohnehin nur
  eigene Posten), kein rein visuelles Problem wie bei `built` oben, daher
  niedrigere Priorität. **Seit 2026-08-04 betrifft dieselbe Lücke
  zusätzlich das neue "Kein Arbeiter zugewiesen"-Label** (siehe "Arbeiter
  zuweisen" oben) — ein spät beitretender Peer kann es bei einem
  tatsächlich schon besetzten Wachposten fälschlich sehen, bis der
  nächste Registrierungs-/Abzieh-Event dort natürlich synct.
- **Nur ein Wachposten-Typ**, keine Ausbaustufen.
- **Keine Reichweiten-/Zonen-Vorschau** außer dem punktuellen Ghost am
  Mauszeiger.
- **Nur ein Wachposten-Typ**, keine Ausbaustufen.
- **Keine Reichweiten-/Zonen-Vorschau** außer dem punktuellen Ghost am
  Mauszeiger.
- **Kapazitäts-Faktor fürs Lager an Platzhalter-Gebäudegrößen kalibriert**
  — muss neu justiert werden, sobald echte Gebäude-Assets die Boxen
  ersetzen, siehe "Lager" oben.
- **Bauauftrag-Start hat kein Ghost-Preview/keine Bestätigung** — Klick auf
  den Button startet sofort den Bauauftrag (bei Erfolg), anders als der
  Bau-Fluss mit Ghost-Vorschau. Der eigentliche Umbau selbst läuft seit dem
  Bau-Markier-Modus aber nicht mehr sofort, siehe "Baustellen" oben.
- **Catch-up für Bauaufträge seit dem Bau-Markier-Modus behoben** — ein
  spät beitretender Peer sieht jetzt Zieltyp und Fortschritt eines offenen
  Bauauftrags korrekt (siehe "Baustellen" oben, `_catch_up_building()`).
  **Bewusst weiterhin fehlend:** die zugewiesenen Trupps selbst werden
  nicht mitübertragen, der Spieler muss nach Catch-up/Laden neu zuweisen.
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
