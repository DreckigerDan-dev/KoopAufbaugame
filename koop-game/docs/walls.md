# Mauern + Tore

Erklärt `scenes/entities/wall/Wall.gd` sowie die Zieh-Platzierung in
`scenes/world/World.gd` (`_start_wall_drag()`/`_finish_wall_drag()`/
`_compute_wall_line()`/Snap-Helfer). Grundlegendes Bausystem (Baumodus,
Kosten, Werkstatt-Rabatt) siehe [`docs/building.md`](building.md).
Blockierverhalten aus Sicht von Survivor/Zombie/Fahrzeug siehe
[`docs/survivor.md`](survivor.md), [`docs/zombies.md`](zombies.md),
[`docs/vehicle.md`](vehicle.md).

## Ein Script für beide

`Wall.gd` bedient Mauer **und** Tor über `@export var is_gate: bool` —
nur Kosten, Blockier-Regel und Farbe unterscheiden sich, nicht die
Grundmechanik (HP, Zerstörbarkeit). `WALL_MAX_HP := 150`,
`GATE_MAX_HP := 100` (Tor schwächer, dafür passierbar für den Eigentümer).

## Blockieren (`blocks()`)

```gdscript
func blocks(requesting_peer_id: int) -> bool:
    if is_gate:
        return requesting_peer_id != owner_peer_id
    return true
```

Eine **Mauer** blockiert jeden, auch die eigenen Trupps — genau deshalb
gibt es das Tor: nur der Eigentümer (`owner_peer_id`) kommt durch, jeder
andere (fremde Spieler, und implizit auch Zombies) wird blockiert.
`Zombie.gd` ruft `blocks()` gar nicht erst auf (siehe
[`docs/zombies.md`](zombies.md)) — ein Zombie hat nie eine passende
`owner_peer_id`, jede Mauer und jedes Tor blockiert ihn also ausnahmslos.

## Physik-Layer

`collision_layer = 2` im `.tscn` (statt Standard-Layer 1) — eigene,
isolierte Physik-Ebene, damit die Blockier-Raycasts in
`Survivor._is_path_blocked()`, `Zombie._blocking_obstacle()` und
`Vehicle._is_path_blocked()` (jeweils `OBSTACLE_LAYER := 2`) gezielt nur
Mauern/Tore treffen, nicht Boden/Gebäude/Einheiten auf Layer 1.

## Platzieren: Ziehen statt Einzelklick

Anders als Wachposten/Krankenstation/Werkstatt (Einzelklick, siehe
[`docs/building.md`](building.md)) werden Mauer/Tor **gezogen** — ein
Klick-und-Halt-Drag über mehrere Weltmeter erzeugt eine ganze Reihe
aneinandergrenzender Segmente in einem Zug.

1. **`_unhandled_input()`** dispatcht bei Baumodus mit `_build_type in
   [WALL, GATE]` auf `_start_wall_drag()` statt `_select_at()`.
2. **`_start_wall_drag(screen_pos)`** — Raycast auf den Klickpunkt, setzt
   `_wall_drag_active = true`. Der Startpunkt wird zuerst versucht, ans
   Ende einer bestehenden Mauer/eines Tors zu **snappen**
   (`_nearest_wall_endpoint()`, Radius `WALL_SNAP_ENDPOINT_RADIUS := 1.0`)
   — nur falls nichts in der Nähe ist, fällt es auf das allgemeine
   Weltraster zurück (`_snap_to_grid()`, `WALL_SEGMENT_LENGTH := 2.0`
   Zellgröße, fest am Weltursprung verankert statt an der Home-Base,
   damit mehrere Züge zuverlässig auf denselben Punkten landen).
3. **Während des Ziehens** — `_update_wall_drag_ghost()` (aufgerufen aus
   `_update_build_ghost()`, ersetzt dort den normalen Einzel-Ghost-Würfel)
   ruft pro Frame `_compute_wall_line(_wall_drag_start, aktuelle Mausposition)`
   auf und zeigt eine Reihe grüner/roter Ghost-Segmente entlang der
   berechneten Linie.
4. **Loslassen** — `_finish_wall_drag(screen_pos)` berechnet die Linie ein
   letztes Mal und schickt sie komplett als `request_build_wall_line.rpc_id
   (1, positions, line_rotation_y, requesting_peer_id, is_gate)`.

### Snap (`_compute_wall_line()`)

Ein einziger Ort berechnet **sowohl** die Segment-Positionen **als auch**
die gemeinsame Rotation — würden beide getrennt gerundet, könnten
Segment-Reihe und ihre eigene Drehung leicht auseinanderlaufen und
sichtbare Lücken zeigen:

- Zugrichtung (`end - start`) wird auf `WALL_SNAP_ANGLE := PI/4.0` (45°,
  8 Richtungen) gerundet (`atan2` + `round(... / WALL_SNAP_ANGLE) *
  WALL_SNAP_ANGLE`) — die 180°-Mehrdeutigkeit von `atan2` ist irrelevant,
  der Mauer-Quader ist um die Y-Achse symmetrisch.
- Segmentanzahl: `round(distance / WALL_SEGMENT_LENGTH) + 1`, jedes
  Segment `WALL_SEGMENT_LENGTH` (2.0, deckt sich mit der 2×2×0.4
  BoxMesh-Breite in `Wall.tscn`/`Gate.tscn`) entlang der gerasterten
  Richtung vom Startpunkt aus platziert.
- **Reiner Klick ohne Ziehen** (`distance < 0.01`) ergibt genau ein
  Segment beim Startpunkt — identisch zum alten Einzelklick-Verhalten,
  kein Sonderfall nötig.

## Bauen (`request_build_wall_line()`)

`@rpc("any_peer", "call_local", "reliable")`, host-only wirksam. Ein RPC
für beliebig viele Segmente — jedes wird **einzeln** geprüft
(`_can_build_at()`) und bezahlt, in der Reihenfolge des Zugs:

```gdscript
for build_position in positions:
    if not _can_build_at(requesting_peer_id, build_position, cost):
        break
    ...
    base.add_resources.rpc(cost_delta)
    wall_spawner.spawn(...)
    built_count += 1
```

`add_resources.rpc()` ist `call_local`, der Host sieht die Kosten des
vorigen Segments also schon **vor** der Prüfung des nächsten — bricht
beim ersten nicht mehr leistbaren Segment einfach ab. Wer mehr zieht, als
er sich leisten kann, bekommt dadurch schlicht eine kürzere Mauer statt
eines Fehlers. Nur wenn **gar kein** Segment gebaut werden konnte
(`built_count == 0`), gibt es Feedback über `_report_build_failure()` —
ein teilweiser Erfolg braucht keine Fehlermeldung.

## Zerstören

`take_damage()` — kein RPC, ausschließlich host-seitig aufgerufen (vom
Zombie beim Durchbrechen, siehe [`docs/zombies.md`](zombies.md)). Kein
eigenes `_process()` (eine Mauer bewegt sich nicht), daher Sync nur bei
tatsächlicher HP-Änderung statt jeden Frame (`_sync_hp.rpc()`, analog zu
`GuardPost._sync_worker_count()`). Farbe dunkelt mit sinkendem HP nach,
Tor und Mauer haben unterschiedliche Basisfarben (Holzbraun vs.
Steingrau).

## HP bei Catch-up + Spielstand (Fix 2026-08-04, Systematik-Review)

Ursprünglich übernahmen `_catch_up_wall()` (spät beitretende Peers) und
`_collect_save_data()`/`_load_game_state()` (Spielstand) nur Position/
Rotation/`is_gate`/Besitzer — der aktuelle HP-Stand eines schon
beschädigten Segments ging in beiden Fällen verloren (bei Catch-up
sah der neue Peer eine unbeschädigte Mauer, bei jedem Laden eines
Spielstands wurden ALLE beschädigten Mauern kommentarlos komplett
geheilt). Behoben nach demselben Muster wie `Building.hp`: `Wall.hp`
jetzt Teil beider Pfade, `Wall._ready()` wendet den normalen Default
(`WALL_MAX_HP`/`GATE_MAX_HP`) nur noch an, falls kein Wert von außen
gesetzt wurde (Sentinel `hp < 0`, gültige Werte sind nie negativ — bei
0 wird die Mauer sofort über `_die()` entfernt).

## Bekannte Grenzen (noch nicht gelöst)

- **Keine Reparatur** — einmal beschädigt, bleibt eine Mauer beschädigt.
- **Snap-Raster ist global, nicht pro Zone** — zwei weit voneinander
  entfernte Mauer-Züge landen zufällig auf demselben Weltraster, auch
  wenn das für die jeweilige Bauzone irrelevant ist.

## Testen

Debug → Customize Run Instances → 2 → F5, Host + Join, "Spiel starten".
Mauer-Baumodus aktivieren, kurz klicken (ohne Ziehen) — genau ein Segment
sollte entstehen. Danach mit gehaltener Maustaste über mehrere Meter
ziehen — mehrere Segmente in 45°-Schritten, lückenlos aneinander
anschließend. Direkt an ein bestehendes Mauerende heranklicken — der neue
Zug sollte nahtlos daran andocken. Ein Tor bauen, mit eigenem Trupp
hindurchlaufen (sollte funktionieren) und mit einem Zombie dagegenlaufen
lassen (sollte blockiert werden und die Mauer angreifen).
