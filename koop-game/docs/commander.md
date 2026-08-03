# Commander (Kamera, Auswahl, Befehle)

Erklärt den Steuerungsteil von `World.gd`: Kamera (Pan/Rotieren/Zoomen),
Einheiten-Auswahl, Kontrollgruppen, Befehlsvergabe. Ursprünglich ein
eigener 2D-`Commander`-Node, seit der 3D-Migration direkt in `World.gd`
gefaltet — siehe unten, "Warum kein eigener Node mehr". Baumodus/Bauklick
siehe [`docs/building.md`](building.md), Mauer-Ziehen siehe
[`docs/walls.md`](walls.md).

## Warum kein eigener Node mehr

```gdscript
## Übernimmt zusätzlich die frühere Commander-Rolle (Kamera, Auswahl,
## Bewegungs-/Bau-Befehle) direkt hier statt über einen eigenen gespawnten
## Commander-Node — Kamera braucht keine Netzwerk-Replikation, jeder Peer
## hat ohnehin nur seine eigene lokale Instanz dieser Szene.
```

Die 2D-Version hatte einen eigenen `Commander`-Node. In 3D reicht die
`World`-Node selbst: Kamera/Auswahl/Eingabe sind rein lokal (jeder Peer
hat seine eigene, unreplizierte Sicht), ein eigener Node dafür hätte
keinen Mehrwert gebracht.

## Kamera

- **Pan** (`_handle_pan()`): WASD/Pfeiltasten bewegen `pivot.position`
  (nicht die Wurzel — siehe [`docs/3d-migration.md`](3d-migration.md),
  "Der eigentliche Rendering-Bug"), `PAN_SPEED := 20.0`,
  bildschirm-relativ (Eingaberichtung wird um `pivot.rotation.y`
  rotiert), unabhängig von der aktuellen Kamerarotation.
- **Rotieren + Neigen** (`_unhandled_input()`, `InputEventMouseMotion`
  während `_rotating`): rechte Maustaste halten + ziehen rotiert
  horizontal (`pivot.rotate_y`, `MOUSE_ROTATE_SENSITIVITY`) und neigt
  vertikal (`_tilt_angle`, geclampt zwischen `TILT_MIN`/`TILT_MAX`, ~15°
  bis ~80°).
- **Zoom** (`_zoom(direction)`, Mausrad): multiplikativ
  (`ZOOM_STEP_FACTOR := 0.15` relativ zur aktuellen Distanz statt fixem
  Schritt), geclampt zwischen `ZOOM_MIN`/`ZOOM_MAX` (4–40, `ZOOM_MAX` auf
  Nutzerwunsch von 25 auf 40 angehoben, passend zur größeren Karte — siehe
  [`docs/world.md`](world.md)).
- **`_apply_zoom()`** berechnet die Kameraposition aus `_tilt_angle` neu
  und ruft `camera.look_at()` bei **jedem** Aufruf neu auf (nicht nur
  einmalig in `_ready()`) — weil sich durch die Neigung auch die
  Blickrichtung ändert.

### Klick vs. Ziehen (rechte Maustaste)

Rechtsklick ist doppelt belegt — Ziehen rotiert die Kamera, ein reiner
Klick (kein Ziehen dazwischen) stoppt stattdessen die ausgewählten
Einheiten. Unterschieden über `_right_click_dragged`, das bei
`MOUSE_BUTTON_RIGHT`-Press auf `false` gesetzt und bei jeder
`InputEventMouseMotion` während `_rotating` auf `true` gesetzt wird — erst
beim Loslassen entscheidet der Endzustand, welche Aktion gemeint war.

## Auswahl (`_select_at()`)

3D-Pendant zum alten 2D-`Commander._select_at()` (dort ein reiner
Distanz-Check) — hier ein echter Physik-Raycast von der Kamera durch die
Klickposition (`camera.project_ray_origin`/`project_ray_normal`,
`RAY_LENGTH := 1000.0`). Reihenfolge der Fallunterscheidung:

1. **Baumodus aktiv** → Bauversuch statt Auswahl (siehe
   [`docs/building.md`](building.md)), Baumodus hat Vorrang vor allem
   anderen.
2. **Treffer in `"selectable"`** (eigene oder fremde Einheit/Fahrzeug):
   - **Eigene Einheit** → Toggle in `selected` (ohne Shift: Auswahl
     ersetzt, mit Shift: An-/Abwählen einzelner Einheiten).
   - **Fremdes, unbesetztes Fahrzeug** (`owner_peer_id == 0`) mit aktiver
     Auswahl → nur der **erste** ausgewählte Trupp versucht einzusteigen
     (ein Fahrzeug hat nur einen Fahrersitz), siehe
     [`docs/vehicle.md`](vehicle.md). Die Auswahl schaltet dabei
     **optimistisch** schon auf das Fahrzeug um (`selected = [hit]`),
     noch bevor der Trupp tatsächlich angekommen ist — sonst bliebe bis
     dahin der (nach dem Einsteigen unsichtbare) Trupp ausgewählt.
3. **Treffer in `"searchable"`** (Gebäude) mit aktiver Auswahl → Suchen
   oder Claimen, siehe [`docs/scavenging.md`](scavenging.md)/
   [`docs/zones.md`](zones.md).
4. **Sonstiger Boden-Treffer** mit aktiver Auswahl → `order_move()` an
   alle ausgewählten Einheiten, mit `_formation_offset()` versetzt (siehe
   unten). Shift+Klick (`additive`) hängt den Wegpunkt hinten an, statt
   die Schlange zu ersetzen.
5. **Kein Treffer / nichts auswählbar** → `selected.clear()`.

Gemeinsame Ziel-Y-Höhe für alle Bewegungs-/Such-/Claim-Ziele:
`SURVIVOR_GROUND_Y := 0.85` (feste Konstante statt vom Raycast-Treffpunkt
übernommen — Begründung siehe [`docs/scavenging.md`](scavenging.md). Wert
= halbe Survivor-Kapselhöhe, seit der 1,70m-Trupp-Größe von 0.6 auf 0.85
angehoben, siehe [`docs/survivor.md`](survivor.md)).

## Formation (`_formation_offset()`)

Ohne Kollision/Pathfinding (siehe [`docs/survivor.md`](survivor.md),
"Bekannte Grenzen") würden mehrere gleichzeitig befohlene Einheiten sonst
exakt übereinander laufen. Ursprünglich ein einfaches Raster
(Spaltenzahl `ceil(sqrt(count))`, zentriert um den Zielpunkt) —
2026-08-03 nach Nutzer-Feedback im ersten echten Koop-Test ("Trupps laufen
immer noch zu nah zusammen, sollten sich wie eine Gruppe verhalten: einer
vorne, die anderen um ihn rum verteilt") auf eine Anführer-plus-Kreis-
Formation umgestellt: die zuerst ausgewählte Einheit (Index 0) läuft exakt
zum Zielpunkt, alle weiteren verteilen sich gleichmäßig auf einem Kreis
mit `FORMATION_RADIUS := 2.0` darum (ersetzt die alte, jetzt gelöschte
`FORMATION_SPACING`-Konstante).

**Formation natürlicher (2026-08-04):** die reine Zielpunkt-Verteilung
reichte nicht, Nutzer-Feedback nach dem Kreis-Update: "truppen laufen auf
einer linie sollen er natürlicher laufen" — alle Einheiten liefen trotz
unterschiedlicher Zielpunkte im exakt selben Frame mit exakt gleicher
Geschwindigkeit los. Zwei Ergänzungen, beide ohne Netzwerk-Zustand (rein
host-seitig in `Survivor._process()`):
- **`Survivor.MOVE_SPEED_VARIANCE := 0.08`** — jeder Trupp bekommt bei
  `_ready()` einmalig einen zufälligen Geschwindigkeitsfaktor (±8%,
  `_move_speed_factor`), multipliziert in `_current_move_speed()`.
- **`World.MOVE_STAGGER_STEP := 0.15`** — `_select_at()` gibt jeder
  Einheit im Gruppenbefehl einen index-abhängigen Start-Versatz
  (`float(i) * MOVE_STAGGER_STEP`) als neuen vierten Parameter
  `start_delay` an `order_move()` mit. Der Trupp zählt `_move_start_delay`
  in `_handle_movement()` herunter, bevor er sich überhaupt bewegt —
  Index 0 (Anführer) bekommt 0 und läuft weiterhin sofort los. Gilt nur
  bei einem frischen Befehl, nicht beim Shift-Klick-Anhängen (`queue ==
  true`).
- `Vehicle.order_move()` bekommt denselben vierten Parameter
  (`_start_delay`) nur der Signatur wegen (derselbe generische
  `unit.order_move.rpc_id(...)`-Aufruf trifft auch Fahrzeuge, die
  mitausgewählt sein können) — bleibt dort ungenutzt, Fahrzeuge folgen
  weiter dem Straßen-Pathing.

Noch nicht vom Nutzer getestet.

## Kontrollgruppen

RTS-Standard: `Strg`+Zifferntaste (1–9) weist die aktuelle Auswahl der
Gruppe zu (`_control_groups[group_number] = selected.duplicate()`),
Zifferntaste allein wählt die Gruppe wieder aus (nur noch gültige/
lebende Einheiten werden übernommen). Zusätzlich gibt es im Einheiten-Tab
(siehe [`world.md`](world.md), "UI-Overhaul") Buttons für die ersten
`GROUP_UI_COUNT := 3` Gruppen pro Einheit
(`✓N`/`N`-Toggle-Button je Zeile) als Maus-Alternative zu Strg+Zahl.

## Stopp + Fahrzeug-Ausstieg

- **`_stop_selected_units()`** (reiner Rechtsklick ohne Drag, siehe
  oben) — `order_stop.rpc_id(1, ...)` an jede ausgewählte Einheit.
- **`_exit_selected_vehicles()`** (Taste **F**, kein eigener
  UI-Button, siehe [`docs/vehicle.md`](vehicle.md)) —
  `request_exit.rpc_id(1, ...)` an jedes ausgewählte Fahrzeug, danach
  wird die Auswahl geleert (der ausgestiegene Trupp steht sichtbar
  daneben und ist normal weiter befehligbar).

## Dynamischer RPC-Dispatch

Mehrfach verwendetes Muster, wenn je nach Zustand ein anderer RPC-Name
gefeuert werden muss (Suchen vs. Claimen, siehe
[`docs/zones.md`](zones.md)): `Node.rpc_id(peer_id, method_name:
StringName, ...args)` kann eine RPC-Methode generisch per Namen
aufrufen. **Wichtig:** `unit.call(method_name, ...)` funktioniert dafür
**nicht** — das ruft die Methode nur lokal auf, ohne übers Netzwerk zu
gehen. Details siehe [`docs/networking.md`](networking.md).

## Bekannte Grenzen (noch nicht gelöst)

- **Keine Box-Selektion** (Rechteck aufziehen) — nur Einzelklick oder
  HUD-Buttons.
- **Kein Rechtsklick-Fahrzeug-Ausstieg** — nur über die F-Taste.
- **Keine visuelle Auswahl-Markierung** um ausgewählte Einheiten selbst
  (nur indirekt über die HUD-Liste erkennbar).

## Testen

Debug → Customize Run Instances → 2 → F5, Host + Join, "Spiel starten".
Kamera mit WASD schwenken, rechte Maustaste ziehen zum Rotieren/Neigen,
Mausrad zoomen. Mehrere Trupps auswählen (Shift-Klick), gemeinsam
bewegen — der zuerst ausgewählte Trupp läuft zum Zielpunkt, die anderen
verteilen sich im Kreis darum, nicht übereinanderlaufen. Eine Gruppe per
Strg+1 zuweisen, mit 1 wieder auswählen.
