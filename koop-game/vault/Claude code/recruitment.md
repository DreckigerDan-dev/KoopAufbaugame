# Rekrutierung

Erklärt, wie ein Spieler zu zusätzlichen Trupps kommt: den festen
Zweit-Trupp beim Start (`World.request_choose_start_base()`, siehe
[`docs/zones.md`](zones.md), "Start-Basis wählen") und das Rekrutieren
über ein durchsuchtes Gebäude mit `has_survivor = true`
(`Survivor._finish_search()` → `World.spawn_recruit()`). Aufbauend auf
[`docs/scavenging.md`](scavenging.md) (Durchsuchen als Auslöser) und
[`docs/base.md`](base.md) (Home-Base als Spawn-Bezugspunkt).

## Start: zwei Trupps pro Peer

```gdscript
# Zweiter Survivor pro Peer, weil es (noch) keine Rekrutierung in 3D gibt
# (bekannte Lücke, siehe docs/recruitment.md) — sonst gäbe es nie einen
# freien Trupp für einen GuardPost, sobald der einzige stationiert ist.
const SECOND_SURVIVOR_OFFSET := Vector3(1.5, 0, 0)
```

`request_choose_start_base()` spawnt bei der Basis-Wahl **zwei** Survivor
(`_spawn_survivor(peer_id, survivor_position)` und `_spawn_survivor(peer_id,
survivor_position + SECOND_SURVIVOR_OFFSET)`) statt nur einem — ein
bewusster Kompromiss, bevor es überhaupt eine In-Game-Rekrutierung gab:
mit nur einem Trupp gäbe es nie einen zweiten freien für einen
Wachposten, sobald der einzige irgendwo stationiert oder unterwegs ist.

## Rekrutierung über durchsuchte Gebäude

Ein Platzhalter-Gebäude kann zusätzlich zu seinem Ressourcen-Loot
`@export var has_survivor: bool = false` gesetzt haben (aktuell **eines**
der acht Gebäude in `World.tscn`, mit `loot = {"food": 25, "medicine":
5}` **und** `has_survivor = true`). Beim Abschluss einer Suche
(`Survivor._finish_search()`, siehe [`docs/scavenging.md`](scavenging.md)):

```gdscript
if building.has_survivor:
    get_tree().current_scene.spawn_recruit(owner_peer_id, position)
```

`get_tree().current_scene` ist zuverlässig die `World`-Node, weil
`Survivor` nur existiert, während `World.tscn` die aktuell geladene Szene
ist (gleiches Cross-Node-Muster wie `report_status()`, siehe
[`docs/networking.md`](networking.md)).

`World.spawn_recruit(peer_id, spawn_position)` ruft schlicht denselben
`_spawn_survivor()`-Helfer wie beim Startspawn auf, an der Position des
durchsuchenden Trupps (`position`, also am Gebäude selbst) — der neue
Trupp erscheint dort und muss selbst zurück zur Basis laufen, wie jeder
andere neue Trupp auch.

## Bekannte Grenzen (noch nicht gelöst)

- **Genau ein rekrutierbares Gebäude auf der ganzen Karte** — kein
  Zufalls- oder Wiederauffüll-Mechanismus, sobald es durchsucht ist, gibt
  es keine weitere Rekrutierungsquelle mehr.
- **Kein Limit** auf die maximale Truppzahl pro Spieler.
- **Fester Zweit-Trupp bleibt bestehen**, obwohl es jetzt eine echte
  Rekrutierungsquelle gibt — beide Mechanismen koexistieren, ohne dass
  der Startbonus reduziert wurde.
- **Kein eigener Rekrutierungs-Bautyp** (z. B. eine Kaserne) aus der
  größeren Vision (siehe [`docs/status.md`](status.md)) — bislang nur an
  ein einzelnes, festes Gebäude gebunden.

## Testen

Debug → Customize Run Instances → 2 → F5, Host + Join, "Spiel starten".
Erst je eine Start-Basis wählen (siehe [`docs/zones.md`](zones.md),
"Start-Basis wählen") — danach sollten pro Spieler zwei Trupps in der
Einheiten-Liste (Einheiten-Tab, siehe [`world.md`](world.md),
"UI-Overhaul") stehen. Das Gebäude mit Loot `{"food": 25,
"medicine": 5}` durchsuchen lassen (siehe `World.tscn`, `Building2`) —
danach sollte ein dritter Trupp am Gebäude erscheinen.
