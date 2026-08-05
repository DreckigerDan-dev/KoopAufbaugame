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
   - `_advance_search_queue_or_return_to_base()` — siehe "Multi-Ziel-
     Pfadfindung" unten; ohne Warteschlange identisch zum vorherigen
     `_return_to_base()`.

## Loot-Ziel-Anzeige (2026-08-05, Nutzerwunsch "fehlt eine Anzeige wo die Units die looten hinlaufen")

Dünne, halbtransparente gelbe Linie vom Trupp zum Zielgebäude, solange er
noch unterwegs ist — man sieht auf einen Blick, wohin ein plündernder
Feldtrupp gerade läuft, ohne ihn erst anklicken zu müssen.

- **Rein lokal/kosmetisch, kein Netzwerk-Sync nötig:** `World._select_at()`
  trägt beim Erteilen von `order_search()` das Paar (Trupp, Gebäude) in
  `_loot_routes` ein — der klickende Client kennt beide bereits selbst,
  bevor der Host überhaupt geantwortet hat. Zeigt deshalb nur die eigenen,
  selbst erteilten Suchbefehle (bewusste Scope-Entscheidung, kein
  Mitspieler-weites Feature).
- **`_loot_routes[unit]` ist eine LISTE** (2026-08-06-Korrektur, Nutzer-
  Report "wenn ich 3 Stück markiere ... wird nur das letzte Gebäude
  gezeigt") — ursprünglich ein Einzelwert, dabei überschrieb jeder weitere
  Shift-Klick (additive Mehrfachziel, siehe unten) den vorherigen Eintrag.
  Additive Klicks hängen jetzt an die bestehende Liste an (spiegelt
  `Survivor._search_queue`, rein lokal nachgebildet, kein Zugriff auf den
  echten host-seitigen Zustand nötig), ein normaler (nicht-additiver)
  Klick ersetzt die Liste komplett.
- **`World._update_loot_route_lines()`** (läuft jeden Frame auf jedem Peer):
  baut/aktualisiert pro Trupp eine dünne `BoxMesh`-Linie zum VORDERSTEN
  (aktuellen) Listen-Eintrag (gleiche Zeichen-Technik wie
  `Survivor._play_shot_effect()`s Schuss-Leuchtstreif, nur dauerhaft statt
  einmalig). Ziel-Y kommt bewusst von der EIGENEN Trupp-Höhe, nicht von
  `building.global_position.y` (sitzt auf halber Gebäudehöhe, siehe "Units
  schweben in der Luft"-Bugfix in `survivor.md`) — sonst würde die Linie
  schräg in die Gebäudemitte statt flach über den Boden zeigen.
- **Aufräumen:** Der vorderste Listen-Eintrag wird entfernt, sobald der
  Trupp näher als `_loot_arrival_distance(building)` (horizontale Distanz)
  ans Gebäude kommt oder es ungültig wird — bei einer Mehrfachziel-Route
  rückt danach automatisch das nächste Ziel nach, statt die ganze Route zu
  löschen. Läuft über reine Distanzprüfung, nicht über `_searching`/
  `is_idle()` (beide bleiben während der ganzen Such-/Rückweg-Phase
  "beschäftigt", würden die Linie also viel zu lange stehen lassen).
  **Dritter Fix (2026-08-06, Nutzer-Report "bei 3 Häusern wird die Linie
  nie aktualisiert"):** Ankunfts-Distanz war zunächst ein fester Wert
  (`LOOT_ROUTE_ARRIVAL_DISTANCE`, 4m) gegen den GEBÄUDE-MITTELPUNKT
  gemessen — ein Trupp durchsucht ein Gebäude aber von dessen Rand/
  Oberfläche aus (Klickpunkt auf der Box, nicht die Box-Mitte selbst), bei
  größeren Gebäuden (z. B. Supermarkt, ~18m) blieb er dadurch dauerhaft
  weiter als 4m vom Mittelpunkt entfernt — die Linie rückte bei einer
  Mehrfachziel-Route NIE zum nächsten Eintrag vor, egal wie lange man
  wartete. `_loot_arrival_distance()` berechnet die Schwelle jetzt aus der
  halben Gebäude-Diagonale (gleiche Herleitung wie
  `HOME_BASE_HALF_DIAGONAL`) plus dem alten festen Puffer.
  **Zweiter Fix (2026-08-06, Nutzer-Report "der Streifen geht nicht weg
  wenn ich was anderes angeklickt habe"):** neue `World._clear_loot_route(
  unit)` wird jetzt zusätzlich bei JEDEM anderen Befehl aufgerufen
  (Bewegen — nur bei nicht-additivem Klick, da additives `order_move()`
  die Suche laut `Survivor.gd` nicht abbricht —, Stoppen, Angreifen,
  Einsteigen, Claimen, Abreißen), vorher verschwand die Linie NUR über die
  Ankunfts-Distanz, blieb also stehen, wenn der Trupp stattdessen woanders
  hin umbefohlen wurde.

## Multi-Ziel-Pfadfindung (2026-08-04, Ideen-Backlog)

Shift-Klick auf weitere `"searchable"`-Gebäude, während ein Feldtrupp schon
einen laufenden Such-/Bewegungsauftrag hat, hängt sie als weitere Ziele an,
statt den aktuellen Auftrag zu ersetzen — ein Befehl für eine ganze Route
statt eines erneuten Klicks nach jedem einzelnen Gebäude.

- **`order_search(target, building_path, requesting_peer_id, additive :=
  false)`** — neuer vierter Parameter, gleiches Konzept wie der `additive`-
  Parameter von `order_move()`. `World._select_at()` reicht `shift_pressed`
  durch (dieselbe Variable, die auch die Bewegungs-Wegpunkt-Schlange
  steuert), aber NUR für `order_search` — `order_claim_building()`/
  `order_demolish_building()` bleiben immer Sofort-Befehle, Claimen/
  Abreißen ist konzeptionell ein einzelner Vorgang, keine Route.
- **`Survivor._search_queue: Array[Dictionary]`** — jeder Eintrag `{"target":
  Vector3, "building_path": NodePath}`, exakt das Paar, das `order_search()`
  sonst direkt bekommt. Additive Klicks hängen NUR an diese Warteschlange
  an, ohne den gerade laufenden Auftrag (`_waypoints`/`_pending_building_
  path`/`_searching`) anzufassen — Ausnahme: ein **untätiger** Trupp
  (`is_idle()`) startet sofort, statt eine Warteschlange aufzubauen, die
  nie abgearbeitet würde.
- **`_advance_search_queue_or_return_to_base()`** — ersetzt die frühere,
  immer bedingungslose `_return_to_base()` am Ende von `_finish_search()`
  (an allen drei Ausstiegspunkten: normaler Loot, Banditen-Restloot,
  zwischenzeitlich schon von einem anderen Trupp geplündert). Ist die
  Warteschlange leer, unverändertes Verhalten (Rückweg zur Basis/zum
  nächsten Außenposten). Sonst: nimmt den vordersten Eintrag, setzt
  `_waypoints`/`_pending_building_path` darauf — der Trupp läuft DIREKT
  zum nächsten Gebäude weiter, OHNE zwischendurch zur Basis
  zurückzukehren. Getragener Loot bleibt bis zur `CARRY_CAPACITY`-Grenze
  einfach weiter im Rucksack (kein Zwischen-Abliefern) — bekanntes,
  unverändertes Verhalten, siehe [`survivor.md`](survivor.md), "Rucksack".
- **`_cancel_search()` leert `_search_queue` mit** — jeder komplett neue
  Befehl (Bewegen ohne Shift, Angriff, Stationieren, Stopp) verwirft eine
  noch offene Route genauso wie den aktuell laufenden Auftrag.
- **Nicht persistiert** — `_search_queue` ist reiner Laufzeit-Zustand wie
  `_waypoints`, taucht bewusst nicht in `_collect_save_data()` auf (gleiche
  Kategorie wie die Bewegungs-Wegpunkte, die auch nie gespeichert wurden).

**Noch nicht vom Nutzer getestet.**

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
  der als eigene Ressource nicht existiert), Restaurant/Kneipe (kleine
  Nahrungs-Variante, kleiner als Supermarkt) — **Tankstelle liefert seit
  2026-08-04 Treibstoff statt Nahrung als Hauptloot** (siehe
  [`vehicle.md`](vehicle.md), "Treibstoff", Nahrung bleibt als kleinerer
  Nebenloot-Anteil erhalten), Bibliothek +
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
