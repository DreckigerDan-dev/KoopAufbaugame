# Scavenging (Gebäude durchsuchen)

Erklärt den Durchsuchen-Ablauf über `scenes/world/Building.gd` und die
`order_search()`/`_finish_search()`-Kette in
`scenes/entities/survivor/Survivor.gd`. Aufbauend auf
[`docs/survivor.md`](survivor.md) (Bewegung/Wegpunkte). Was mit einem
bereits durchsuchten Gebäude weiter passiert (claimen), steht in
[`docs/zones.md`](zones.md); Rekrutierung eines neuen Trupps aus einem
Gebäude mit `has_survivor = true` in [`docs/recruitment.md`](recruitment.md).

## Auslösen (`World._select_at()`)

Klick auf ein Gebäude in der `"searchable"`-Gruppe, während eine Auswahl
aktiv ist, ruft je nach Zustand `order_search()` oder (schon geplündert)
`order_claim_building()` auf — siehe [`docs/zones.md`](zones.md) für die
Zustandsunterscheidung und den dynamischen RPC-Dispatch per
`unit.rpc_id(1, order_method, ...)`. Zielkoordinaten kommen vom
Raycast-Treffpunkt (`result.position`), nicht von `building.global_position`
— sonst läge das Ziel mitten im Box-Mesh und der Trupp wäre während der
ganzen Suche unsichtbar. Die Y-Höhe ist bewusst eine feste Konstante
(`SURVIVOR_GROUND_Y`), nicht vom Treffpunkt übernommen, weil je nach
getroffener Seite/Dach der Box diese Höhe schwankt.

## Ablauf in `Survivor.gd`

1. **`order_search(target, building_path, requesting_peer_id)`**
   (`@rpc("any_peer", "call_local", "reliable")`) — ersetzt die gesamte
   Wegpunkt-Schlange durch das eine Ziel, merkt sich `building_path` in
   `_pending_building_path` (als `NodePath`, nicht als direkte
   Node3D-Referenz — funktioniert unverändert seit dem Kartenumbau, siehe
   `docs/world.md`: Gebäude laufen jetzt zwar über `MultiplayerSpawner`
   statt als feste `.tscn`-Kind-Nodes, aber ein `NodePath` zu einem
   konkreten, schon existierenden Node ist auf jedem Peer weiterhin
   identisch gültig).
2. **Ankunft** (`_handle_movement()`, letzter Wegpunkt erreicht) — setzt
   `_searching = true`, `_sheltered = true` (siehe
   [`docs/survivor.md`](survivor.md), "Im Haus"/`is_sheltered()`) und
   startet `_search_timer := SEARCH_DURATION` (3 Sekunden).
3. **Während der Suche** — `_process_search(delta)` zählt den Timer
   herunter, kein zusätzliches Feedback (kein Fortschrittsbalken).
4. **`_finish_search()`** bei Timer-Ablauf:
   - `building.mark_looted.rpc()` — `@rpc("authority", "call_local",
     "reliable")` in `Building.gd`, setzt `is_looted = true` und färbt das
     Gebäude grau (`_update_visual()`).
   - `_pick_up_loot(building.loot)` — siehe unten.
   - Falls `building.has_survivor == true`:
     `get_tree().current_scene.spawn_recruit(owner_peer_id, position)` —
     siehe [`docs/recruitment.md`](recruitment.md).
   - `_return_to_base()` — automatischer Rückweg, siehe unten.

## Gebäude-Typen + Loot-Tabellen (2026-08-02, Punkt 17 der Gesamtliste)

`building.loot` (siehe unten) ist keine feste Dictionary mehr, sondern
wird bei jedem Gebäude-Spawn aus einer echten Loot-TABELLE gewürfelt.

- **`World.BUILDING_TYPES`** ersetzt die früheren zwölf ANONYMEN
  Vorlagen durch ECHTE, aus der Vision benannte Gebäudetypen
  (`Infos/02 Item-Liste.md`, "Gebäude-Fundorte"). Ursprünglich vier
  (Wohnhaus, Supermarkt, Apotheke, Waffenladen/Polizeistation),
  2026-08-03 (Nutzerwunsch nach der Vision-Gap-Analyse) um zehn weitere
  ergänzt: Klinik, Militärbasis, Privatbunker, Feuerwehrstation,
  Restaurant/Kneipe, Tankstelle, Bibliothek, Universität, Garten-Center,
  Camping-Laden — macht 14 insgesamt. Jeder Typ hat `main_loot`
  (garantiert, Betrag als Bereich, z. B. Wohnhaus 1-2× Nahrung) +
  `secondary_loot` (Liste unabhängiger Chancen, z. B. Apotheke 50%
  zusätzliche Medizin).
- **Die zehn neuen im Detail:** Klinik (Apotheke-Variante, mehr Medizin),
  Militärbasis + Privatbunker (beide wie Waffenladen, aber mit höheren
  Sekundär-Chancen — keine echte Seltenheits-Stufe, da unser System keine
  Waffen-Tiers kennt), Feuerwehrstation (Rüstung statt "Feuerwehr-Anzug",
  der als eigene Ressource nicht existiert), Restaurant/Kneipe + Tankstelle
  (beide Nahrungs-Varianten, kleiner als Supermarkt), Bibliothek +
  Universität (NEU: erster Typ mit garantiertem Buch als Hauptloot, vorher
  gab's Bücher nur als Nebenloot-Chance irgendwo), Garten-Center
  (Nahkampfwaffe statt "Axt/Machete", die als eigene Werkzeug-Ressource
  nicht existiert), Camping-Laden (Beinschutz statt "Rucksack", den es seit
  der Rucksack-Rückabwicklung nicht mehr als Item gibt, siehe
  [`survivor.md`](survivor.md), "Rucksack").
- **Bewusst weiterhin NICHT übernommen: Baumarkt/Werkstatt,
  Auto-Werkstatt, Elektronikgeschäft** — deren Vision-Hauptloot
  (Baumaterial/Stahlrahmen/Ersatzteile/Elektronik-Items) bräuchte entweder
  neue Ressourcenarten, die es in diesem System nicht gibt, oder würde die
  Baurohstoff-Regel direkt unten verletzen.
- **`_roll_building_loot(template)`/`_apply_loot_roll()`** würfeln daraus
  EINMALIG beim Spawn die konkrete `loot`-Dictionary (host-seitig, wie
  der Rest der Weltgenerierung) — das Ergebnis wird wie bisher als
  normale Spawn-/Speicherstand-Daten repliziert, kein eigener Zufall auf
  dem Client nötig.
- **Waffenladen/Polizeistation ist der einzige Typ mit
  Ausrüstungs-Loot** (Waffe garantiert + Munition/Rüstung/Helm als
  Chancen) — vorher kamen Waffe/Rüstung/Helm ausschließlich aus
  Zombie-Loot (siehe [`zombies.md`](zombies.md)) oder Crafting (siehe
  [`building.md`](building.md), "Herstellen"), jetzt zusätzlich aus
  gezieltem Gebäude-Scavenging.
- **"Buch"** in `main_loot`/`secondary_loot` steht für einen zufälligen der
  fünf `book_*`-Typen (`BOOK_LOOT_TYPES`, seit 2026-08-03 inkl.
  `book_medical_upgrade`, siehe [`building.md`](building.md),
  "Forschungsbücher"/"Erweiterte Krankenstation") — die Vision nennt Bücher
  nur allgemein als Nebenloot, ohne Typ-Bezug.
- **Bewusst NICHT übernommen: "Werkstatt/Baumarkt"** (fünfter
  Vision-Typ, Loot wäre Baumaterial) — Holz/Metall/Stein/Ziegel kommen
  in diesem System ausschließlich aus eigenen Ressourcenknoten (Baum/
  Autowrack/Stein-/Ziegelhaufen), nie aus Stadt-Gebäude-Loot. Eine
  frühere, vom Nutzer bestätigte Korrektur ("Bautrupp hat im Haus normal
  gelootet, das sollen die nicht [tun]", siehe `docs/base.md`, "Vier
  Baurohstoffe") hatte genau dieses Vermischen schon einmal aufgelöst —
  hier bewusst nicht wieder eingeführt.
- **Größenspanne bewusst im bisherigen Platzhalter-Rahmen belassen**
  statt der echten Vision-Maße (z. B. "18m Supermarkt") — Neukalibrierung
  erst mit echten 3D-Assets (gleiche Einschränkung wie beim Lager, siehe
  [`building.md`](building.md)).
- **Jagdstand (Wald-Zonen) bewusst unverändert** — eigene, feste
  `FOREST_BUILDING_TEMPLATE` (garantiert Munition + Waffe), nicht Teil
  von `BUILDING_TYPES`, nicht Teil dieses Umbaus.

**Noch nicht vom Nutzer getestet.**

## Loot aufsammeln (`_pick_up_loot()`)

Greedy, nicht proportional über die Ressourcenarten verteilt: iteriert
`building.loot` (z. B. `{"food": 10, "brick": 5}`, seit der
Rohstoff-Aufteilung siehe [`docs/base.md`](base.md)) und füllt
`carried_loot` auf, bis `CARRY_CAPACITY` (Summe über alle Arten, 20)
erreicht ist — was über die Kapazität hinausgeht, geht schlicht verloren.
Das Gebäude gilt trotzdem als vollständig geplündert (`is_looted = true`
bleibt, kein zweites Mal durchsuchbar), auch wenn nicht der komplette
Loot mitgenommen werden konnte.

## Rückweg + Ablieferung

`_return_to_base()` setzt `_sheltered = false` (der Rückweg ist genauso
gefährlich wie der Hinweg, kein Sicherheitsbonus) und einen neuen
Wegpunkt zum NÄHEREN von Home-Base ODER einem eigenen Außenposten (siehe
`_find_nearest_drop_off_point()` unten, [`docs/building.md`](building.md),
"Außenposten") mit zufälligem Streuungs-Offset (`randf_range(-1.5, 1.5)`
auf X/Z) — ohne Kollisionssystem würden sonst mehrere gleichzeitig
zurücklaufende Trupps exakt übereinander ankommen und ineinander clippen
(dasselbe Grundproblem wie bei Gruppenbefehlen, dort löst
`World._formation_offset()` es, siehe [`docs/commander.md`](commander.md)).

`_handle_carried_loot()` läuft **jeden Frame** (wie `_handle_healing()`/
`_handle_eating()`), nicht nur einmalig bei Ankunft — sobald der Trupp in
`HEAL_RADIUS` um das Ziel (Home-Base oder Außenposten) kommt, liefert es
`carried_loot` ab und leert es. Das funktioniert auch, wenn der Rückweg
durch einen neuen Befehl unterbrochen wurde und der Trupp später aus
anderem Grund am Ziel vorbeikommt.

**`_find_nearest_drop_off_point()`** (seit 2026-08-01, Außenposten): sucht
unter der eigenen Home-Base UND allen eigenen `"outpost"`-Knoten den
nächstgelegenen. `_handle_carried_loot()` unterscheidet beim Abliefern
zwischen den beiden Zieltypen — `HomeBase.add_resources()` ist selbst ein
`@rpc` (`target.add_resources.rpc(...)`), `Outpost.add_resources()` ist
eine einfache Methode ohne eigene RPC-Konfiguration, reicht intern schon an
die Home-Base weiter (siehe `docs/building.md`) und wird deshalb normal
aufgerufen (`target.add_resources(...)`, kein `.rpc()` — hätte dort einen
Laufzeitfehler ausgelöst).

## Abbrechbar

`_cancel_search()` (ausgelöst durch jeden neuen Befehl — Bewegen,
Stationieren, Stopp) setzt `_searching = false`, `_sheltered = false` und
leert `_pending_building_path` — eine laufende oder noch nicht begonnene
Suche wird dadurch sauber abgebrochen, nicht im Hintergrund
weitergeführt.

## Banditen-Restloot (2026-08-03, Punkt 23 der Gesamtliste)

Aus dem Ideen-Backlog der Vision (`Infos/01 Architektur.md`): "gelegentlich
hinterlassen Banditen-Camps kleinen Restloot in bereits geplünderten
Gebäuden — Grund für gelegentliches Zurückkehren, ohne vollen
Loot-Respawn." Umgesetzt als rein serverseitiger periodischer Timer, KEINE
tatsächlichen Banditen-NPCs (reine Loot-Mechanik, die den Namen aus der
Vision übernimmt).

- **`World._spawn_bandit_restock()`** läuft alle `BANDIT_RESTOCK_INTERVAL`
  (180s Echtzeit, `World._process()`) und würfelt EIN zufälliges,
  bereits geplündertes, NICHT geclaimtes Gebäude ohne schon laufenden
  Restock aus (`buildings_container.get_children()`, gefiltert auf
  `is_looted && owner_peer_id == 0 && not has_bandit_loot`) — kein Effekt,
  wenn es gerade keinen Kandidaten gibt.
- **Kleine Menge statt vollem Respawn:** genau EINE Ressource aus
  `BANDIT_LOOT_RESOURCES` (`food`/`medicine`/`ammo` — bewusst dieselbe
  Ressourcenfamilie wie normaler Stadt-Gebäude-Loot, keine Baurohstoffe,
  siehe `docs/base.md`, "Vier Baurohstoffe"), Menge 3-8
  (`BANDIT_LOOT_MIN`/`MAX`).
- **`Building.grant_bandit_loot(loot)`** (`@rpc("authority", "call_local",
  "reliable")`) setzt `has_bandit_loot = true`/`bandit_loot = loot`,
  färbt das Gebäude golden ein (`_update_visual()`, gleicher Farbton wie
  ein markierter Baum/Autowrack, siehe `docs/survivor.md`,
  "Markier-System") — visuell klar unterscheidbar vom neutralen Grau eines
  "leer, nichts mehr zu holen"-Gebäudes.
- **`World._select_at()`** behandelt ein Gebäude mit `has_bandit_loot` wie
  ein noch nicht durchsuchtes — `order_search()` statt
  `order_claim_building()`/`order_demolish_building()` — obwohl
  `is_looted` weiterhin `true` ist. Einzige Ausnahme von der sonst
  endgültigen `is_looted`-Sperre.
- **`Survivor._finish_search()`** verzweigt VOR der normalen
  `is_looted`-Sperre: `has_bandit_loot` → `_pick_up_loot(bandit_loot)` +
  `clear_bandit_loot.rpc()` (kein `mark_looted()` nötig, ist es schon,
  keine erneute Rekrutierung), sonst normaler Erst-Suche-Ablauf
  unverändert. Nach dem Einsammeln fällt das Gebäude zurück auf den
  normalen "geplündert, unbesetzt"-Zustand — claim-/abreißbar wie zuvor.
- **Vollmap-Ansicht (`MapView._draw_buildings()`):** der gelbe
  "hier gibt's noch Loot"-Rahmen erscheint jetzt auch bei
  `has_bandit_loot`, nicht mehr nur bei `not is_looted`.
- **Catch-up + Speichern/Laden:** `has_bandit_loot`/`bandit_loot` laufen
  über dieselben optionalen Zusatzfelder wie `is_looted`/`owner_peer_id`/
  `hp` (`_catch_up_building()`/`_collect_save_data()`/`_create_building()`).

**Noch nicht vom Nutzer getestet** — Erst-Test dauert mindestens 3 Minuten
Echtzeit bis zum ersten Restock (nur wenn zu diesem Zeitpunkt schon
mindestens ein Gebäude geplündert-aber-unbesetzt ist).

## Bekannte Grenzen (noch nicht gelöst)

- **Catch-up für `Building.is_looted` seit dem Kartenumbau gelöst** (siehe
  `docs/world.md`) — Gebäude laufen jetzt über `MultiplayerSpawner`,
  `_catch_up_building()` schickt den vollständigen Zustand (inkl.
  `is_looted`/`owner_peer_id`/`hp`) an spät beitretende Peers mit.
  `Vehicle.owner_peer_id`-Catch-up seit 2026-08-01 ebenfalls gelöst (siehe
  [`docs/vehicle.md`](vehicle.md)) — diese Zeile war seitdem veraltet, hier
  korrigiert.
- **Kein Fortschrittsbalken/-anzeige** während der 3 Sekunden Suchzeit.
- **Loot-Verlust bei voller Kapazität** ohne Warnung vorher (Ghost-Preview
  o. Ä.) — der Spieler merkt es erst am Ergebnis.

## Testen

Debug → Customize Run Instances → 2 → F5, Host + Join, "Spiel starten".
Trupp auswählen, auf ein noch nicht durchsuchtes Gebäude klicken — Trupp
sollte hinlaufen, kurz stehen bleiben (Suche), das Gebäude sollte grau
werden, danach automatisch Richtung eigener Home-Base zurücklaufen und
dort die HUD-Ressourcen erhöhen. Ein Gebäude mit `has_survivor = true`
(genau ein zufälliger Bauplatz pro Stadt-Zone, siehe
`World._generate_city_zone()`) durchsuchen — sollte einen zusätzlichen
Trupp spawnen.
