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
