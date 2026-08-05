# Survivor (Trupp)

Erklärt das Grundgerüst von `scenes/entities/survivor/Survivor.gd`:
Auswahl/Bewegung, HP/Permadeath, Hunger/Essen, Heilung. Durchsuchen ist in
[`docs/scavenging.md`](scavenging.md) ausgelagert, Fahrzeug-Einstieg in
[`docs/vehicle.md`](vehicle.md), Stationieren an einem Wachposten in
[`docs/building.md`](building.md), Gebäude claimen in
[`docs/zones.md`](zones.md) — alle vier laufen über dieselbe
Wegpunkt-Ankunfts-Weiche in `_handle_movement()`.

## Grundprinzip

`StaticBody3D` (kein `CharacterBody3D` — Bewegung ist reines
Positions-Lerp, keine Physik-Kollision zwischen Einheiten nötig), in den
Gruppen `"selectable"` und `"living"`. Host-autoritativ: `_process()`
läuft nur auf dem Host (`set_process(false)` auf Clients), jeder Client
sieht ausschließlich das Ergebnis von `_sync_state()`.

**Maßstab:** `CapsuleMesh`, `radius := 0.3`, `height := 1.70` (Nutzerwunsch,
als menschlicher Größen-Referenzwert für andere Assets — 1 Godot-Einheit =
1 Meter, siehe [`docs/world.md`](world.md)). `World.SURVIVOR_GROUND_Y`
(halbe Kapselhöhe, damit die Kapsel mit der Unterkante auf dem Boden
steht statt zu versinken/schweben) entsprechend auf `0.85` angepasst.

## Bewegung

- **Wegpunkt-Schlange** (`_waypoints: Array[Vector3]`) statt einem
  einzelnen Ziel — ein normaler Bewegungsbefehl ersetzt sie komplett,
  Shift+Klick (`queue = true` in `order_move()`) hängt stattdessen hinten
  an (siehe [`docs/commander.md`](commander.md)).
- **`_handle_movement()`** bewegt sich `MOVE_SPEED` (4.0) pro Sekunde auf
  den ersten Wegpunkt zu (`Vector3.move_toward`), poppt ihn bei
  `ARRIVE_THRESHOLD` (0.05) Abstand. Am **letzten** Wegpunkt entscheidet
  eine Weiche über `_pending_station_target`/`_pending_building_path`/
  `_pending_vehicle_path`/`_pending_claim_path`, was als Nächstes passiert
  — Stationieren/Suchen/Einsteigen/Claimen greifen jeweils nur genau dort,
  nie mitten in der Schlange.
- **Hunger-Verlangsamung:** unter `HUNGER_LOW_THRESHOLD` (30) sinkt die
  Geschwindigkeit auf `MOVE_SPEED * HUNGER_SPEED_FACTOR` (0.5×), siehe
  `_current_move_speed()`.
- **Obstacle-Blocking + Ausweichen (2026-08-04):** `_is_path_blocked(next_position)`
  raycastet auf `OBSTACLE_LAYER` (Physik-Layer 2, Mauern/Tore) für den
  nächsten Bewegungsschritt (nicht bis zum Wegpunkt). KoopGame hat KEIN
  echtes Pathfinding (kein Navmesh, Bewegung ist reines
  `position.move_toward()`) — bei blockiertem direktem Weg probiert
  `_sidestep_position()` stattdessen eine seitliche Bewegung senkrecht zur
  Zielrichtung (einfache Ausweich-Heuristik, kein Navmesh), bis der Weg
  wieder frei ist; blieb bisher einfach stehen. Blockiert auch die
  Ausweich-Seite, wird die Seite gewechselt (`_sidestep_direction`,
  z. B. an einer Mauer-Ecke), erst wenn beide Seiten blockiert sind,
  bleibt der Trupp wirklich stehen. Details zu `blocks()`:
  [`docs/walls.md`](walls.md). **Weiterhin kein echtes Navmesh** — reine
  lokale Heuristik, kann bei komplexen Mauer-Layouts (z. B. einer
  U-Form) trotzdem stecken bleiben; ein prozedural gebackenes
  `NavigationRegion3D` wäre der eigentliche, größere Fix, bewusst
  zurückgestellt (siehe `Infos/06 Infection Free Zone Recherche.md`).

## HP + Permadeath

- `take_damage(amount)` — kein RPC, wird ausschließlich host-seitig
  aufgerufen (von `Zombie` im Nahkampf, siehe
  [`docs/zombies.md`](zombies.md)). Setzt `_time_since_damage = 0.0`
  (siehe Heilung unten) und löst bei `hp <= 0` `_die.rpc()` aus.
- `_die()` (`@rpc("authority", "call_local", "reliable")`) — kein
  Wiederbeleben, Permadeath wie im Konzept (`ARCHITECTURE.md`). Ruft
  `_unstation()` (meldet bei einem Wachposten ab, falls stationiert),
  emittiert `died`, `queue_free()`.

## Hunger + Essen

- `hunger` fällt linear mit `HUNGER_DECAY_RATE` (0.3/s, 2026-08-04 von
  1.5/s runtergesetzt — Nutzerwunsch: "alle bedürfnisse sollten länger
  brauchen zum abblaufen", siehe `docs/mechanics-review.md`,
  "Nahrungs-/Bedürfnisökonomie". Vorher 0→100 in ~67s, jetzt ~333s/~5,5
  Minuten, ähnliche Größenordnung-Reduktion wie der Müdigkeit-/Moral-Fix
  vom selben Tag), Boden bei 0.
- `_handle_eating()` läuft analog zur Heilung: in `HEAL_RADIUS` (3.0) um
  die eigene Home-Base, alle `EAT_INTERVAL` (2.0s) wird 1 Food aus dem
  Basis-Pool verbraucht und `hunger` um `EAT_AMOUNT` (15) erhöht, solange
  `hunger < 100` und Food vorhanden ist.

## Bedürfnisse: Müdigkeit + Moral (2026-08-02, Punkt 16 der Gesamtliste)

Aus der Vision übernommen (`Infos/01 Architektur.md`: "Bedürfnisse:
Hunger/Müdigkeit/Moral sinken über Zeit, senken bei niedrigem Stand die
Leistung"; `Infos/02 Item-Liste.md`: "Betten/Schlafraum: Survivor-
Regeneration (Müdigkeit, Moral)"). Beim Einstieg in diese Session lag
bereits ein angefangenes, aber unvollständiges Gerüst im Code (`Bed.gd`/
`Bed.tscn`, `BuildType.BED`, `upgrade_bed_button` in der UI, `BED_COST`
— vermutlich aus einer vorherigen, nicht zu Ende geführten Session):
`request_upgrade_building()`/`_cost_for_build_type()` kannten
`BuildType.BED` noch nicht (fiel auf den Wachposten-Fallback zurück,
falsche Kosten UND falsches Gebäude), kein Catch-up/Speicherstand-Eintrag
für Betten, und auf `Survivor.gd` gab es überhaupt noch keine
Müdigkeits-/Moral-Variablen. Das Bett-Gebäude-Gerüst war sauber und
konsistent zum bestehenden Muster (`MedicalStation.gd`) — komplettiert
statt neu gebaut.

- **`fatigue`/`morale`** (beide `float`, Start 100, Boden 0) fallen linear
  wie `hunger`, aber langsamer (`FATIGUE_DECAY_RATE` 0.15/s,
  `MORALE_DECAY_RATE` 0.075/s — ergänzende statt zentrale Bedürfnisse, kein
  so knapper Rhythmus wie Hunger). **Nachjustiert (2026-08-04):**
  ursprünglich 0.8/0.4 (Nutzer-Feedback: "das mit müde und moral geht zu
  schnell runter ich lauf zu einem gebäude und habe beides auf 0") — bei
  den alten Werten waren beide schon nach 125s bzw. 250s komplett
  aufgebraucht, kürzer als ein einziger Erkundungslauf. Neue Werte: ~11
  Minuten (Müdigkeit) bzw. ~22 Minuten (Moral) bis 0, gleiches
  2:1-Verhältnis beibehalten.
- **Regeneration am eigenen Schlafraum ODER Außenposten**
  (`_handle_resting()`/`_find_nearby_rest_point()`, `BED_REST_RADIUS` 5.0
  um ein Gebäude der Gruppe `"bed"` ODER `"outpost"`, `REST_RATE` 10/s für
  BEIDE Werte gleichzeitig) — bewusst KEINE Home-Base-Grundrate wie bei
  Hunger/Heilung. Ohne eigenen Schlafraum/Außenposten in der Nähe sinken
  beide dauerhaft, das ist laut Vision der ganze Sinn der Betten-Mechanik.
  Kein Ressourcenverbrauch beim Regenerieren selbst (nur die Baukosten,
  siehe [`building.md`](building.md), "Betten"/"Außenposten").
  **Außenposten seit 2026-08-04 dabei** (Systematik-Review, Fund 5) — die
  Vision nennt Außenposten explizit als Rastpunkt ("nur zum Rasten/
  Schlafen der Trupps"), das war beim ursprünglichen Außenposten-Bau
  (2026-08-01) nur deshalb ausgelassen, weil dieses Bedürfnissystem noch
  nicht existierte; beim Nachbau des Systems einen Tag später wurde der
  Außenposten dann schlicht vergessen. Gleicher Radius/gleiche Rate wie
  ein Bett (bewusst keine eigene, schwächere Außenposten-Stufe, um nicht
  ungefragt eine neue Balance-Unterscheidung einzuführen).
- **Leistungsminderung, zwei unterscheidbare Effekte statt eines
  doppelten Speed-Malus:**
  - `fatigue <= FATIGUE_LOW_THRESHOLD` (30): Bewegung `*
    FATIGUE_SPEED_FACTOR` (0.7), kombiniert sich multiplikativ mit dem
    Hunger-/Rüstungs-Malus in `_current_move_speed()`.
  - `morale <= MORALE_LOW_THRESHOLD` (30): Angriffsschaden (Nah- UND
    Fernkampf, `_effective_attack_damage()`) `* MORALE_DAMAGE_FACTOR`
    (0.7). Betrifft nur den proaktiven Angriffsbefehl, NICHT den
    passiven Gegenschaden aus `Zombie._try_attack()` (eigene Konstanten
    in `zombies.md`, bewusst unberührt).
- **Replikation:** Teil von `_sync_state()` (achter/neunter Parameter
  neben Position/HP/Hunger, vor Loot/Waffen-/Rüstungsstatus).
- **UI:** kompakte Trupp-Liste (`Mü%d Mo%d`), Trupp-Detailfenster
  ("Müdigkeit"/"Moral"-Zeilen), HUD-Text — überall neben Hunger, gleiches
  Muster.
- **Speichern/Laden:** Teil des Survivor-Eintrags wie `hunger`, mit
  `entry.get("fatigue"/"morale", 100.0)`-Fallback beim Laden (ältere
  Spielstände ohne diese Felder starten einfach bei voller
  Müdigkeit/Moral statt eines Ladefehlers).

## Heilung

`_handle_healing()`: passive Regeneration beginnt erst
`HEAL_DELAY_AFTER_DAMAGE` (4s) nach dem letzten Treffer. Zwei mögliche
Heilzonen:

- **Home-Base** (`HEAL_RADIUS` 3.0) — Basisrate `HEAL_RATE` (5/s).
- **Krankenstation** (`MEDICAL_STATION_HEAL_RADIUS` 5.0, via
  `_find_nearby_medical_station()`) — doppelte Rate
  (`MEDICAL_STATION_HEAL_RATE`), siehe [`docs/building.md`](building.md).

Medizin wird in beiden Fällen aus dem **Basis-Pool** verbraucht (1 pro
geheiltem HP) — Krankenstationen haben kein eigenes Medizin-Lager, siehe
[`docs/base.md`](base.md). Kein Medizin vorhanden → keine Heilung, auch
in Reichweite.

## "Im Haus" (`is_sheltered()`)

Gibt `_sheltered` zurück — wird `true`, sobald eine Suche **beginnt**
(nicht schon beim Loslaufen zum Gebäude), und bleibt bewusst auch nach
Suchende bestehen, solange der Trupp am Gebäude stehen bleibt. Erst ein
neuer Befehl (`_cancel_search()`) setzt es zurück. Zombies können einen
sheltered-Trupp weder entdecken noch angreifen, siehe
[`docs/zombies.md`](zombies.md). Auf dem Hinweg (noch nicht angekommen)
ist der Trupp weiterhin ungeschützt.

## Angriffsbefehl

Bisher wehrte sich ein Trupp nur passiv, wenn ein Zombie ihn angriff
(Gegenschaden aus `Zombie._try_attack()`, siehe
[`docs/zombies.md`](zombies.md)). `order_attack(target_path,
requesting_peer_id)` ergänzt einen echten, proaktiven Angriffsbefehl —
Ziel ist ein Zombie oder ein Zombie-Nest (siehe
[`docs/zombies.md`](zombies.md), "Zombie-Nest"), ausgelöst per Klick in
`World._select_at()` (Branch für die Gruppen `"zombie"`/`"zombie_nest"`,
vor dem Boden-Fallback). `ATTACK_RANGE`/`ATTACK_COOLDOWN` sind identisch zu
`Zombie.ATTACK_RANGE`/`ATTACK_COOLDOWN`, `ATTACK_DAMAGE := 15` entspricht
`Zombie.COUNTER_DAMAGE` — bewusst dieselben Zahlen wie der bestehende
Gegenschaden, kein neues Balancing.

- **Läuft NICHT über die Wegpunkt-Schlange** — `_attack_target` ist eine
  direkte Node3D-Referenz (nicht per NodePath vorgemerkt wie
  `_pending_building_path` etc.), `_process()` verzweigt direkt in
  `_process_attack(delta)`, solange `is_instance_valid(_attack_target)`
  gilt, statt `_handle_movement()` aufzurufen. Gegenstück zu
  `Zombie._process_chase()`, nur trupp- statt zombie-initiiert.
- **Chase-and-attack ohne Aufgeben:** läuft dem Ziel hinterher (bricht
  NICHT ab, wenn es sich entfernt — anders als `Zombie.GIVE_UP_RADIUS`),
  bis es stirbt oder ein neuer Befehl kommt (jeder `order_*` ruft
  `_cancel_search()` auf, das jetzt zusätzlich `_attack_target = null`
  setzt).
- **Kein Mauer-Durchbrechen** — anders als ein Zombie greift ein Trupp
  eine blockierende Mauer nicht automatisch an, bleibt einfach stehen
  (`_is_path_blocked()`, gleiches Verhalten wie normale Bewegung).
- **Kein eigener Alarm/Lärm** — ein Trupp-Angriff alarmiert keine anderen
  Zombies (anders als Wachposten-Beschuss oder ein Zombie-Angriff). Ein
  angegriffener Zombie bemerkt den Trupp aber ganz normal über seine
  eigene, unabhängige Ziel-Erkennung (`Zombie._update_chase_target()`),
  sobald er nah genug ist — echtes gegenseitiges Gefecht entsteht also
  trotzdem, nur nicht über einen expliziten Alarm-Aufruf.
- **`is_idle()`** prüft jetzt zusätzlich `not
  is_instance_valid(_attack_target)` — ein kämpfender Trupp gilt nicht als
  frei verfügbar für z. B. `GuardPost.request_worker()`.

## Waffensystem

Munition (`ammo`) lag seit Spielbeginn ungenutzt in `HomeBase.resources`,
seit dem Zombie-Loot-Drop (siehe [`docs/zombies.md`](zombies.md),
"Zombie-Loot-Drop") auch "weapon" — beide wurden bis hierhin von keinem
System verbraucht (siehe [`docs/base.md`](base.md)). Diese erste Stufe
schließt das an, **bewusst schlank**: ein einziger Fernkampf-Modus, keine
Waffentypen/-stufen, keine Munitionssorten, kein Crafting, keine Rüstung —
die Vision-Doku (`Infos/02 Item-Liste.md`) beschreibt ein sehr viel
größeres, mehrstufiges System (Waffen-Progressionsbaum, typspezifische
Munition, Forschungsbücher, Waffen-Mods, Haupt-/Sekundärwaffen-Slots), das
hier ausdrücklich **nicht** gebaut wird.

- **`is_armed: bool`** + **`order_equip_weapon(requesting_peer_id)`**
  (`@rpc("any_peer", "call_local", "reliable")`, gleiche Guards wie
  `order_attack()`): nur Feldtrupps (`troop_type == FIELD`), verbraucht 1×
  `weapon` aus der eigenen Home-Base (`_find_home_base()`, gleicher Fund-
  Mechanismus wie `_handle_healing()`/`_handle_eating()`). Kein Ablegen in
  dieser Stufe — einmal ausgerüstet, bleibt ein Trupp bewaffnet, bis er
  stirbt (bewusste Vereinfachung).
- **`RANGED_ATTACK_RANGE := 6.0`** (wie `GuardPost.FIRE_RANGE`),
  **`RANGED_ATTACK_DAMAGE := 20`** (mehr als Nahkampf `ATTACK_DAMAGE := 15`
  — Anreiz fürs Ausrüsten). `_process_attack()` prüft vor jedem Angriff, ob
  Fernkampf möglich ist (`is_armed` UND eigene Home-Base mit `ammo > 0`) —
  wenn ja, wird aus `RANGED_ATTACK_RANGE` geschossen statt in Nahkampf-
  Distanz laufen zu müssen, und 1× `ammo` pro Schuss verbraucht
  (`base.add_resources.rpc({"ammo": -1})`, gleiches Verbrauchsmuster wie
  Medizin/Nahrung). **Geht die Munition aus, fällt der Trupp automatisch
  auf Nahkampf zurück** (bleibt nützlich, kein "wehrlos"-Zustand) —
  passiert implizit jeden Frame neu, kein eigener Zustandswechsel nötig.
  Gleicher `ATTACK_COOLDOWN` für beide Modi, kein eigener
  Fernkampf-Cooldown.
- **Replikation:** `is_armed` ist Teil von `_sync_state()` (fünfter
  Parameter neben Position/HP/Hunger/Loot, mittlerweile sechster mit
  `is_wearing_armor` dazu, siehe "Rüstungssystem" unten) — einziger Weg,
  wie andere Peers und die eigene UI den Status sehen. Die kompakte
  Trupp-Liste (siehe [`world.md`](world.md), "UI-Overhaul", "Einheiten"-Tab)
  zeigt nur noch ein kurzes `[W]`-Tag im Label (kein
  Unequip-Button, siehe oben) — der eigentliche "Ausrüsten"-Button ist ins
  Trupp-Detailfenster gewandert (siehe "Rüstungssystem" unten,
  Nutzer-Feedback: kompakte Liste sollte klein bleiben).
- **Speichern/Laden:** `is_armed` ist Teil des Survivor-Eintrags in
  `World._collect_save_data()`/`_load_game_state()`, exakt wie
  `hp`/`hunger`/`carried_loot`/`troop_type` behandelt (siehe
  [`docs/save_load.md`](save_load.md)).
- **Sichtbares Feedback (Nutzer-Feedback):** Ohne jede optische Reaktion war
  nicht erkennbar, ob ein Fernkampf-Schuss überhaupt stattfand — der Trupp
  bleibt beim Schießen einfach ~6m entfernt stehen, sonst identisch zum
  Nichtstun, und ein bewaffneter Trupp sah bis dahin genauso aus wie ein
  unbewaffneter. Zwei Ergänzungen dagegen:
  - **`_update_color()`** gibt einem bewaffneten Feldtrupp einen
    stahlblauen Grundton (`Color(0.55, 0.75, 1.0)`) statt Weiß — auf einen
    Blick erkennbar, wer eine Waffe trägt.
  - **`_play_shot_effect(target_position)`** (`@rpc("authority",
    "call_local", "reliable")`, von `_process_attack()` bei jedem
    Fernkampf-Schuss aufgerufen) erzeugt einen kurzen, leuchtenden
    Streifen zwischen Trupp und Ziel (dünne `BoxMesh`, 0,12s Lebensdauer,
    als Kind der Welt-Szene statt des Trupps — bleibt an Ort und Stelle,
    unabhängig von Trupp-Bewegung/-Tod). Rein optisch, kein
    Gameplay-Effekt, aber der einzige Weg, einen Schuss überhaupt zu
    "sehen".
  - `HomeBase.START_RESOURCES["weapon"]` steht jetzt auf `1` (war `0`) —
    Waffensystem lässt sich sofort testen, ohne erst einen riskanten
    Nahkampf-Kill für einen Zufalls-Drop abzuwarten (siehe
    [`docs/zombies.md`](zombies.md), "Zombie-Loot-Drop").

### Haupt-/Sekundärwaffe (2026-08-02, Punkt 18 der Gesamtliste)

Das Waffensystem oben war bewusst als "einziger Fernkampf-Modus, kein
Haupt-/Sekundärwaffen-Slot" abgegrenzt — genau das ist jetzt der Auftrag
von Punkt 18 ("Haupt+Sekundärwaffe, mehrere Rüstungsteile statt binärem
1-Slot-System"). Statt gleich das volle Vision-System (Waffentypen/
-stufen, Munitionssorten) zu bauen, bleibt es bei zwei einfachen,
unabhängigen Slots mit je einem festen Effekt — dasselbe Schlankheits-
Prinzip wie beim Rüstungssystem unten.

- **`is_armed`** bleibt die HAUPTWAFFE (Fernkampf, unverändert — siehe
  oben). **`secondary_weapon: bool`** + **`order_equip_secondary_weapon(
  requesting_peer_id)`** ist die neue SEKUNDÄRWAFFE: eine richtige
  Nahkampfwaffe (Vision-Stufe-1-Tools wie Machete/Axt) statt der bloßen
  Fäuste. Gleicher Feldtrupp-Filter wie die Hauptwaffe (Nahkampf wie
  Fernkampf sind Kampfhandlungen, kein Bautrupp-Feature). Verbraucht 1×
  die NEUE Ressource `"melee_weapon"` (eigene Art, damit beide Slots
  unabhängig ausgerüstet werden können).
- **`SECONDARY_MELEE_DAMAGE := 22`** (mehr als der bloße
  `ATTACK_DAMAGE := 15`) + **`SECONDARY_MELEE_COOLDOWN := 0.8`** (kürzer
  als `ATTACK_COOLDOWN := 1.0`) — greift in `_process_attack()` nur, wenn
  kein Fernkampf möglich ist (`use_ranged == false`), ändert aber NICHT
  die Reichweite (bleibt `ATTACK_RANGE`, weiterhin Nahkampf).
- **`melee_weapon`** ist eine ganz normale siebte Zombie-Loot-Art
  (`ZOMBIE_LOOT_TABLE`, siehe [`zombies.md`](zombies.md)) und Teil des
  temporären 150er-Testbestands (siehe `HomeBase.START_RESOURCES`,
  regulärer Rückbau-Wert 1) — kein eigener Crafting-/Forschungsbücher-Pfad
  in dieser Stufe (bewusst nicht jedes neue Item sofort ins
  Crafting-System integriert, gleiche Zurückhaltung wie beim
  Außenposten, der auch kein Crafting-Rezept hat).

## Rüstungssystem

Direkte Fortsetzung des Waffensystems: Nutzer wollte ein eigenes Fenster
pro Trupp mit Waffenslot/Rüstungsslot/Stats — dabei stellte sich heraus,
dass es noch gar kein Rüstungssystem gab. Rückfrage (nur größeres
Stat-Fenster vs. Fenster + echtes Rüstungssystem) → Nutzer wollte beides.
Nach dem ersten Test ("passt soweit") noch um einen zweiten Slot ergänzt:
Helm getrennt vom Brustpanzer. Gleiche Schlankheit wie beim Waffensystem:
**zwei** Rüstungs-Slots mit je festem Effekt, nicht die volle Vision
(`Infos/02 Item-Liste.md`: Rüstungsteile für noch mehr Körperzonen,
Kombinationen, Gasmaske, Rucksack).

- **`is_wearing_armor: bool`** (Brustpanzer) +
  **`order_equip_armor(requesting_peer_id)`** — **kein** `troop_type`-Filter
  (anders als Waffen): Rüstung ist passiver Schutz, nützt Feld- UND
  Bautrupps gleichermaßen (Zombies schädigen über Gegenschaden/eigene
  Angriffe unabhängig vom Trupp-Typ). Verbraucht 1× `armor` aus der eigenen
  Home-Base, kein Ablegen in dieser Stufe.
- **`has_helmet: bool`** (Helm) + **`order_equip_helmet(requesting_peer_id)`**
  — zweiter, komplett unabhängiger Slot, gleiche Struktur, verbraucht 1×
  `helmet`. Kleinere Schadensreduktion als der Brustpanzer, **kein**
  Speed-Malus (nur der Brustpanzer macht langsamer).
- **`ARMOR_DAMAGE_REDUCTION := 0.3`** (Brustpanzer),
  **`HELMET_DAMAGE_REDUCTION := 0.15`** (Helm) und seit Punkt 18 der
  Gesamtliste **`LEG_ARMOR_DAMAGE_REDUCTION := 0.15`** (Beinschutz, dritter
  Slot, siehe unten) wirken in `take_damage()` **multiplikativ** zusammen
  (`amount * (1 - Brustpanzer) * (1 - Helm) * (1 - Beinschutz)`, als
  `int(round(...))` Variant-Fallen-sicher gecastet) — können sich dadurch
  nie zu über 100% Reduktion aufsummieren, mit allen drei Slots zusammen
  aktuell ~49,4% weniger Schaden.
- **`ARMOR_SPEED_FACTOR := 0.85`**: `_current_move_speed()` multipliziert
  zusätzlich mit diesem Faktor, nur bei `is_wearing_armor` — kombiniert
  sich mit dem bestehenden Hunger-/Müdigkeits-Malus, falls mehrere
  zutreffen. Beinschutz (wie schon der Helm) hat bewusst KEINEN eigenen
  Speed-Malus.
- **Neue Ressourcen `"armor"`** (neunte Art) und **`"helmet"`** (zehnte)
  (siehe [`docs/base.md`](base.md)) — je 1 Startbestand (wie beim
  Waffen-Fix, sofort testbar) und fünfter/vierter möglicher Zombie-Loot-Typ
  neben ammo/medicine/weapon (siehe [`docs/zombies.md`](zombies.md),
  "Zombie-Loot-Drop") — verdünnt deren Drop-Rate weiter, bewusst in Kauf
  genommen statt einen zweiten, komplett neuen Drop-Mechanismus zu bauen.

### Dritter Rüstungs-Slot: Beinschutz (2026-08-02, Punkt 18 der Gesamtliste)

"Mehrere Rüstungsteile statt binärem 1-Slot-System" — der zweite Teil von
Punkt 18. **`has_leg_armor: bool`** +
**`order_equip_leg_armor(requesting_peer_id)`**: dritter, komplett
unabhängiger Slot, identische Struktur wie Brustpanzer/Helm (kein
`troop_type`-Filter, kein Ablegen), verbraucht 1× die NEUE Ressource
`"leg_armor"`. Gleiche Größenordnung wie der Helm (`LEG_ARMOR_
DAMAGE_REDUCTION := 0.15`, siehe oben), ebenfalls sechste/siebte
Zombie-Loot-Art neben ammo/medicine/weapon/armor/helmet/melee_weapon
(siehe [`zombies.md`](zombies.md)) und Teil des temporären
150er-Testbestands.

### Trupp-Detailfenster (Tab "Trupp" in `MainTabsUI`)

**Bis 2026-08-03** ein eigener, frei positionierter `CanvasLayer`
(`UnitDetailUI`, links mittig zwischen `HUD` und `MainTabsUI`) — Nutzer-
Report "die ui sind übereinander das truppen ui und alles andere": bei
kleineren Fensterhöhen überlappte das feste, oben-links verankerte Panel
sichtbar mit dem unten-links verankerten `MainTabsUI`-Panel (beide
Positionen waren in Bildschirm-Pixeln fest verdrahtet, nicht relativ
zueinander). **Fix:** komplett in einen fünften Tab ("Trupp") im
gemeinsamen `MainTabsUI`-TabContainer verschoben, neben
Bauen/Herstellen/Einheiten/Handel — dadurch strukturell keine Überlappung
mehr möglich (immer nur ein Tab-Inhalt gleichzeitig sichtbar).

`World._update_unit_detail_panel()` macht den Tab nur ANWÄHLBAR, wenn genau
ein eigener Survivor ausgewählt ist (`selected.size() == 1 and
selected[0].has_method("is_sheltered")` — gleiche Survivor-vs-Fahrzeug-
Unterscheidung wie in `Zombie.gd` etabliert), über `main_tabs.
set_tab_hidden()` (gleiches Muster wie beim "Herstellen"-Tab ohne eigene
Werkstatt, siehe [`building.md`](building.md)) — **kein** erzwungener
Tab-Wechsel, der Nutzer muss selbst hinklicken, genau wie bei den anderen
Tabs. Zeigt Trupp-ID/Typ/HP/Hunger/Müdigkeit/Moral/Loot ausführlicher als
die kompakte Liste, plus je eine Zeile für Hauptwaffe/Brustpanzer/Helm/
Sekundärwaffe/Beinschutz (fünf Zeilen seit Punkt 18 der Gesamtliste) mit je
einem Status-Label + Ausrüsten-Button (Button verschwindet, sobald
ausgerüstet — kein Unequip). Aktualisiert im selben gedrosselten Takt wie
`_refresh_units_ui()` (`WORKER_UI_REFRESH_INTERVAL := 0.5`, kein neuer
Timer). Die fest verdrahteten Buttons (kein Neu-Erzeugen pro Refresh)
merken sich den aktuell angezeigten Survivor über `World.
_unit_detail_survivor` statt gebundener Button-Argumente, da sie nicht wie
die Zeilen in `_refresh_units_ui()` bei jedem Refresh neu erzeugt werden.
Die kompakte Trupp-Liste (Einheiten-Tab) zeigt weiterhin `[W]`/`[R]`/`[H]`-
Kurztags für Waffe/Brustpanzer/Helm.

## Rucksack (2026-08-01, Punkt 9 der Gesamtliste — entschieden & zurückgebaut)

Kurzzeitig ein vierter Ausrüstungsgegenstand (eigener Slot,
`"backpack"`-Ressource, Zombie-Loot-Typ, wie Waffe/Rüstung/Helm) —
Nutzer-Feedback nach dem ersten Test: "ist ganz nett", aber die offene
Design-Frage (eigener Slot vs. automatisch für alle) war noch nicht
geklärt. **Entscheidung (2026-08-01):** "rucksack soll jeder ein haben
also rucksack kein item sonder ein fester bestand von den truppen" — kein
Ausrüstungsstück, sondern fester Bestand jedes Trupps.

**Umsetzung der Entscheidung:** die gesamte Ausrüstungs-Mechanik wurde
wieder entfernt (`has_backpack`, `order_equip_backpack()`,
`carry_capacity()`, die `"backpack"`-Ressource, `book_backpack`, der
Zombie-Loot-Typ, die Detailfenster-Zeile samt "Anlegen"-Button, der
`[B]`-Tag). Stattdessen wieder eine einzelne feste Konstante
**`CARRY_CAPACITY := 30`** in `Survivor.gd` — direkt auf den vorherigen
"mit Rucksack"-Wert gesetzt (statt zurück auf den alten Basiswert 20),
gilt automatisch für jeden Trupp, Feld- UND Bautrupps gleichermaßen.
Kein Balancing/keine Anzeige-Politur nötig, da keine Mechanik mehr
existiert, die das bräuchte.

## Trupp-Arten

Aus der größeren Vision (`Infos/01 Architektur.md`, "Zwei Trupp-Arten,
Survivor flexibel zuweisbar"): **Feldtrupp** (`TroopType.FIELD`, Standard)
kann suchen/claimen/angreifen (`order_search()`/`order_claim_building()`/
`order_attack()`), aber **nicht** abbauen. **Bautrupp** (`TroopType.BUILD`)
kann ausschließlich abbauen (`order_harvest()`, siehe unten) — **exklusiv,
nicht additiv**: alle drei Feldtrupp-Befehle prüfen server-seitig
`troop_type == TroopType.FIELD` und lehnen sonst mit `report_status()`-
Feedback ab (z. B. "Nur Feldtrupps können Gebäude durchsuchen."), statt
still nichts zu tun.

**So ursprünglich NICHT geplant** — beim ersten Test lief ein Bautrupp
nebenbei weiter normal Häuser durchsuchen (additive erste Fassung, siehe
unten). Nutzer-Feedback: "die sollen nur abbauen können" — auf exklusiv
umgestellt. Passiver Gegenschaden, wenn ein Zombie einen Bautrupp
angreift, bleibt davon unberührt (kein Befehl, sondern automatische
Selbstverteidigung, siehe [`docs/zombies.md`](zombies.md)).

Umschaltbar jederzeit über einen Button pro Trupp im Einheiten-Tab
(`World._refresh_units_ui()`/`_on_toggle_troop_type_pressed()`,
`Survivor.set_troop_type()`), auch mitten in einer laufenden Aktion —
Basis-Bewegung (`order_move()`/`order_stop()`) bleibt für beide Typen
uneingeschränkt.

**Farblich unterscheidbar:** `_update_color()` nutzt für Bautrupps einen
eigenen Grundton (Orange statt Weiß) statt des sonst festen
Weiß→Rot-Verlaufs — der HP-Verlauf Richtung Rot läuft für beide Typen
gleich, nur eben über den jeweiligen Grundton. Kein eigenes Sync-RPC
nötig, aktualisiert sich automatisch über die ohnehin laufende
`_sync_state()`-Replikation, sobald `set_troop_type()` den Typ ändert.
(Historischer Absatz — seit dem Pro-Einheit-Farbton vom 2026-08-03 ist
Trupp-Art nur noch ein Sättigung/Helligkeit-Zweitsignal, siehe
`_unit_base_color()` unten.)

**Dritter Typ seit 2026-08-04: `TroopType.UNASSIGNED`** ("Zivilisten-
Konzept") — Standardzustand jedes neuen Rekruten (nicht der Start-Trupps),
kann sich nicht bewegen/einsteigen/kämpfen/bauen, bis der Spieler ihn
manuell oder per Auto-Zuweisungs-Profil einem echten Typ zuweist. Volle
Details in [`docs/recruitment.md`](recruitment.md), "Zivilisten-Konzept".

### Ressourcen abbauen: Bäume, Autowracks, Stein-/Ziegelhaufen

Vier gleichwertige "harvestable"-Ressourcenquellen (gemeinsame Gruppe
`"harvestable"`, siehe unten), für `Survivor.gd` komplett ununterscheidbar:

- **`scenes/entities/tree/Tree.gd`** — `MAX_HP := 60`, `YIELD :=
  {"wood": 15}`. **Echtes Asset seit 2026-08-04**
  (`assets/tannenbaum.glb`) — ein zusammenhängendes Modell statt der
  vorherigen getrennten Stamm-/Kronen-Platzhalter, deshalb reagiert jetzt
  der GANZE Baum auf HP/Markierung (vorher nur die Krone, Stamm blieb
  konstant braun) — keine sinnvolle Trunk/Foliage-Trennung mehr im echten
  Modell möglich. Größe nicht extra vom Nutzer bestätigt (anders als beim
  Ziegelhaufen), am Platzhalter orientiert — bei Bedarf nachjustieren.
- **`scenes/entities/wreck/CarWreck.gd`** — `MAX_HP := 80`, `YIELD :=
  {"metal": 20}`, seltener als Bäume. Bewusst eine **eigene, separate
  Entität** statt die beiden fahrbaren `Vehicle`-Objekte abbaubar zu
  machen — das hätte deren Rolle als Transportmittel entwertet
  (Zielkonflikt), siehe [`docs/vehicle.md`](vehicle.md). Noch
  Platzhalter-Box.
- **`scenes/entities/pile/StonePile.gd`** — `MAX_HP := 50`, `YIELD :=
  {"stone": 15}`. **Echtes Asset seit 2026-08-04**
  (`assets/steinehaufen.glb`, mehrere Einzelstein-Meshes) — gleiches
  Muster wie beim Ziegelhaufen, `_update_color()` färbt jetzt alle
  Mesh-Kinder statt nur der zwei (jetzt unsichtbaren) Platzhalter-Kugeln.
- **`scenes/entities/pile/BrickPile.gd`** — `MAX_HP := 50`, `YIELD :=
  {"brick": 15}`. **Echtes Asset seit 2026-08-04**
  (`assets/ziegelhaufen.glb`, 1,4×0,5×1,4m, mehrere Einzelziegel-Meshes) —
  gleiches Vorrang-/Y-Ausgleich-Prinzip wie beim Wohnhaus
  (`docs/building.md`), `BrickPile._update_color()` färbt jetzt alle
  Mesh-Kinder statt nur der (jetzt unsichtbaren) Platzhalter-Box, damit
  Markierung (gelb) und HP-Abdunkeln weiterhin sichtbar bleiben.

**Skalierung angehoben (2026-08-04, Nutzerwunsch: "steine, bäume und
ziegel bisschen größer machen aber nicht viel"):** Baum/Steinhaufen/
Ziegelhaufen bekommen `scale = Vector3(1.2, 1.2, 1.2)` auf ihrem
`Model`-Node (+20 %) — reine `.tscn`-Änderung, keine neuen Assets nötig.
Funktioniert, weil das `Model` an seiner eigenen Basis verankert ist
(Blender-Konvention, siehe `docs/building.md`, "Wohnhaus") — Skalieren um
den eigenen Ursprung lässt die Bodenkontakt-Stelle unverändert, nur die
Geometrie darüber wird größer, kein Y-Ausgleich nötig. Kollisionsformen
proportional mitskaliert (Baum-Zylinder, Steinhaufen-Kugel, Ziegelhaufen-
Box). Feld bewusst NICHT mitskaliert (nicht Teil des Nutzerwunsches).

Stein-/Ziegelhaufen ersetzen das ursprüngliche Stein-/Ziegel-Loot aus den
acht Stadt-Gebäuden (siehe [`docs/scavenging.md`](scavenging.md)) —
Nutzer-Feedback: ein Bautrupp, der beim Fällen/Abbauen "nebenbei" auch
noch Häuser durchsuchte, fühlte sich falsch an. Bautrupp-Rohstoffe kommen
jetzt ausschließlich aus eigenen Ressourcenknoten, Häuser-Loot bleibt rein
Feldtrupp-Territorium (`food`/`medicine`/`ammo`, siehe
[`docs/scavenging.md`](scavenging.md)).

Alle vier folgen exakt demselben Muster wie `Wall.gd`: `take_damage()`/
`_die()` kein RPC nötig (host-seitig aufgerufen), `_die()` räumt sich per
`queue_free()` weg, plus `is_marked`/`toggle_marked()`/`_set_marked()` fürs
Markier-System (siehe unten).

- **Einmalige Anfangsstreuung** — `World._spawn_initial_resources()`,
  aufgerufen host-seitig in `_ready()` (gleiche Stelle wie
  `_spawn_zombies()`), verteilt `INITIAL_TREES := 10`/`INITIAL_CAR_WRECKS
  := 4`/`INITIAL_STONE_PILES := 5`/`INITIAL_BRICK_PILES := 5` zufällig über
  die ganze Karte (`_spaced_position()`, `INITIAL_RESOURCE_SPREAD :=
  60.0`) — Nutzerwunsch: Rohstoffe sollen von Spielbeginn an vorhanden
  sein. Ein zusätzliches Nachwachsen pro Zonen-Ereignis
  (`_spawn_trees_near()` & Co., bei jedem Claim/jeder Start-Basis-Wahl)
  gab es zeitweise auch, wurde aber auf Nutzerwunsch wieder entfernt — nur
  noch diese eine Anfangsstreuung, keine weiteren automatischen Spawns.
- **Feste Boden-Y statt Anker-Y:** ursprünglicher Bug — die frühere
  Platzierung übernahm `anchor_position.y` (die Y-Höhe des jeweiligen
  Gebäudes) direkt, was seit der Gebäudehöhen-Skalierung (siehe
  [`docs/world.md`](world.md), Gebäude jetzt 3–4,4 m statt 2–2,6 m) zu
  sichtbar schwebenden Ressourcenknoten geführt hätte. Jeder Typ hat
  jetzt eine eigene, feste Boden-Y-Konstante (`TREE_GROUND_Y := 1.2`,
  `CAR_WRECK_GROUND_Y := 0.45`, `STONE_PILE_GROUND_Y := 0.4`,
  `BRICK_PILE_GROUND_Y := 0.35`) — Werte aus der jeweiligen
  Mesh-Geometrie hergeleitet (Boden-Oberfläche 0.1 minus unterster
  Mesh-Punkt relativ zum Node-Ursprung, siehe `Tree.tscn`/
  `CarWreck.tscn`/`StonePile.tscn`/`BrickPile.tscn`).
- Eigene, parallele `MultiplayerSpawner`/`_create_*()` statt einer
  gemeinsamen Spawn-Funktion (Anzahl/Radius pro Art bleiben so unabhängig
  einstellbar), jeweils mit Catch-up für spät beitretende Peers.
- **Mindestabstand (`_spaced_position()`):** Nutzerwunsch — "alles was im
  Spiel spawnt soll ein bisschen Platz dazwischen haben". Probiert bis zu
  `SPACING_ATTEMPTS := 10` Zufallspositionen im jeweiligen Radius, bis eine
  gefunden ist, die `MIN_RESOURCE_SPACING := 3.0` von jedem bereits
  existierenden Gebäude/Fahrzeug/Zombie-Nest/anderen Ressourcenknoten
  entfernt ist (`_is_far_enough_from_others()`, durchsucht die Gruppen
  `"harvestable"`/`"searchable"`/`"vehicle"`/`"zombie_nest"`). Nach den
  Versuchen wird auch eine zu nahe Position akzeptiert, statt das Spawnen
  zu blockieren.
- **`Survivor.order_harvest(target_path, requesting_peer_id)`** —
  generischer Name (nicht `order_harvest_tree`), weil das Ziel eines der
  vier `"harvestable"`-Objekte sein kann. Prüft server-seitig `troop_type
  == TroopType.BUILD`, sonst `report_status()` ("Nur Bautrupps können das
  abbauen.") statt stiller Ablehnung. Ausgelöst per Klick auf ein
  `"harvestable"`-Ziel in `World._select_at()`, vor dem Boden-Fallback.
- **`_process_harvest(delta)`** spiegelt `_process_attack()` (siehe
  "Angriffsbefehl" oben) 1:1 im Ablauf (hinlaufen, im Cooldown-Takt
  draufschlagen, `HARVEST_RANGE`/`HARVEST_COOLDOWN`/`HARVEST_DAMAGE`
  identisch zu den `ATTACK_*`-Werten) — bewusst als eigene Funktion/eigener
  State (`_harvest_target`/`_harvest_timer`) statt Wiederverwendung, weil es
  thematisch eine andere Aktion ist und ein Trupp nicht gleichzeitig kämpfen
  und abbauen kann. Nach dem tödlichen Treffer (`_harvest_target.hp <= 0`)
  schreibt `_process_harvest()` `_harvest_target.YIELD` direkt der eigenen
  Home-Base gut — keine der vier Ressourcenquellen kennt (anders als eine
  Home-Base) einen Besitzer, dem sie etwas gutschreiben könnte.
- **`is_idle()`** prüft jetzt zusätzlich `not
  is_instance_valid(_harvest_target)`.
- **Korrektheits-Fix (2026-08-04): doppelter Ertrag verhindert** —
  `order_harvest()` hat (anders als das Markier-System unten) KEINEN
  "schon zugewiesen"-Check, mehrere Bautrupps können absichtlich oder
  versehentlich auf dasselbe Ziel angesetzt werden. `_process_harvest()`
  prüfte den Erfolg (`hp <= 0`) vorher erst NACH dem eigenen Schlag, ohne
  vorher zu prüfen, ob das Ziel im selben Frame schon von einem anderen
  Trupp gefällt wurde — ein zweiter Trupp hätte dadurch ein zweites Mal
  den vollen `YIELD` gutgeschrieben bekommen. Jetzt: Bail-out (Ziel wird
  freigegeben, kein Schlag/keine Gutschrift), sobald das Ziel beim
  eigenen Cooldown-Tick schon bei 0 HP steht.

### Markier-System

Nutzerwunsch nach dem ersten Test: statt jeden Bautrupp einzeln auf jedes
Ziel zu klicken, sollen Bautrupps sich markierte Arbeit **selbstständig**
holen können — bewusst **ohne** Zonen-Beschränkung ("Arbeiter können
potenziell überall Sachen abbauen").

- **Markieren:** Klick auf ein `"harvestable"`-Ziel **ohne Auswahl**
  (`selected.is_empty()` in `World._select_at()`) schaltet `is_marked` um
  (`World.request_toggle_harvest_mark()` → `toggle_marked()`/
  `_set_marked()`, broadcastet an alle Peers — jeder Spieler sieht
  dieselbe, geteilte Markierung, kein Besitz-Check). Nochmal klicken hebt
  sie wieder auf. Visuell: markiert, noch unberührt → gold statt der
  jeweiligen Grundfarbe (`_update_color()` in `Tree.gd`/`CarWreck.gd`/
  `StonePile.gd`/`BrickPile.gd`).
- **Direktbefehl bleibt bestehen:** mit ausgewähltem Bautrupp greift
  weiterhin der normale Klick-Branch (`order_harvest()`, siehe oben) —
  Markieren ist eine zusätzliche Option für den Fall, dass gerade nichts
  ausgewählt ist, kein Ersatz.
- **Automatische Zuweisung:** ein untätiger Bautrupp (`troop_type ==
  BUILD and is_idle()`) sucht sich jeden Frame in `_process()` über
  `_try_auto_assign_harvest()` das nächste markierte, noch nicht von einem
  ANDEREN Bautrupp bearbeitete `"harvestable"`-Ziel — **kartenweit über
  alle vier Ressourcenarten hinweg, kein Radius-/Zonen-Filter**.
  `_is_already_assigned()` fragt dafür jeden anderen lebenden Trupp über
  die öffentliche Methode `is_harvesting(target)` (Duck-Typing, gleiches
  Prinzip wie `has_method("is_sheltered")` in `Zombie.gd`), statt direkt
  auf dessen `_harvest_target` zuzugreifen — verhindert, dass zwei freie
  Bautrupps im selben Frame dasselbe Ziel wählen.
- **Selbstheilend bei Abbruch:** bricht ein Spieler einen laufenden
  Abbau-Auftrag ab (neuer Befehl, `_cancel_search()` setzt
  `_harvest_target = null`), bleibt das Ziel weiterhin markiert und
  unbearbeitet — der nächste untätige Bautrupp greift es beim nächsten
  `_process()`-Tick automatisch wieder auf, ganz ohne eigene
  Ziel-seitige Zuweisungs-Buchführung.

### Gebäude abreißen

Letzte Bautrupp-Aktion aus der ursprünglichen Vision-Idee (neben
Bäumen/Autos/Steinen/Ziegeln). Anders als die vier anderen
Ressourcenquellen läuft das **nicht** über die Gruppe `"harvestable"`/das
Markier-System, sondern direkt über den bestehenden Gebäude-Klick-Branch
in `World._select_at()` — Gebäude sind schon `"searchable"`, eine zweite
Gruppenzugehörigkeit wäre unnötig gewesen.

- **Nur geplünderte, noch niemandem gehörende Gebäude** sind abreißbar
  (`building.is_looted and building.owner_peer_id == 0`) — schützt Zonen-
  Anker (geclaimte Gebäude, Start-Basen) vor versehentlichem Abriss durch
  eigene oder fremde Bautrupps. Vom Nutzer explizit so gewählt (Alternative
  wäre "alle Gebäude, keine Ausnahme" gewesen).
- **Pro Einheit unterschiedlich, nicht mehr einmal für die ganze Auswahl:**
  der Gebäude-Klick-Branch bestimmt `order_method` jetzt für jede
  ausgewählte Einheit einzeln (`unit.troop_type` client-seitig lesbar) —
  bei einem bereits geplünderten, unbesetzten Gebäude claimt ein Feldtrupp
  es (`order_claim_building()`), ein Bautrupp reißt es stattdessen ab
  (`order_demolish_building()`). Bei gemischter Auswahl (Feld- und
  Bautrupps zusammen) kann das theoretisch zu einem Wettlauf führen (wer
  zuerst ankommt, gewinnt) — für ein Koop-Spiel unter Freunden akzeptiert,
  in der Praxis wählt man Bautrupp/Feldtrupp ohnehin meist gezielt aus.
- **`Survivor.order_demolish_building(target, building_path,
  requesting_peer_id)`** — `target` (Vector3) wird nur für dieselbe
  Signatur wie `order_search()`/`order_claim_building()` mitgeführt (siehe
  [`docs/zones.md`](zones.md), "Dynamischer RPC-Aufruf"), hier aber
  ungenutzt. Prüft server-seitig `troop_type == TroopType.BUILD` UND
  `is_looted`/`owner_peer_id == 0`, setzt danach direkt `_harvest_target =
  building` — läuft ab da **exakt** über denselben `_process_harvest()`-
  Ablauf wie beim Abbauen eines Baums/Wracks/Haufens (siehe oben).
- **`Building.gd`** implementiert dafür dasselbe `take_damage()`/`hp`/
  `YIELD`-Interface wie `Tree.gd`/`CarWreck.gd`/`StonePile.gd`/
  `BrickPile.gd` — ein Gebäude gibt beim Abreißen **beide** Arten
  gleichzeitig, `add_resources()` verarbeitet das transparent.
  `_update_visual()` dunkelt das bisherige Grau (geplündert, unbesetzt)
  zusätzlich Richtung Schwarz nach, je näher am Abriss — gleiches Prinzip
  wie bei den anderen Ressourcenquellen.
  **Größenabhängig seit 2026-08-04** (Systematik-Review, Fund 3): `max_hp`/
  `YIELD` waren vorher `Building.MAX_HP := 100`/`YIELD := {"stone": 20,
  "brick": 10}` als KONSTANTEN, für jede der 14 Vorlagen exakt gleich,
  unabhängig von der tatsächlichen Größe — bei den inzwischen sehr
  unterschiedlich großen echten Assets (Tankstelle ~90 m³ bis Supermarkt
  ~927 m³) fiel das auf. Jetzt Instanzfelder, `World._create_building()`
  berechnet beide aus dem echten Gebäude-Volumen
  (`BUILDING_HP_PER_VOLUME := 0.5`, `BUILDING_STONE_YIELD_PER_VOLUME :=
  0.2`, `BUILDING_BRICK_YIELD_PER_VOLUME := 0.1`, je mit einem
  `MIN_BUILDING_*`-Boden verankert an der kleinsten bekannten echten
  Gebäudegröße) — ein Tankstellen-Abriss bleibt ungefähr beim alten Gefühl
  (HP 50, 18 Stein/9 Ziegel), ein Supermarkt-Abriss gibt deutlich mehr
  (HP 464, 185 Stein/93 Ziegel). `Building.DEFAULT_MAX_HP`/`DEFAULT_YIELD`
  bleiben als Fallback-Konstanten für Aufrufer ohne Größenangabe (aktuell
  keiner). `YIELD` ist bewusst weiterhin groß geschrieben, obwohl jetzt
  `var` statt `const` — Survivor._process_harvest() liest
  `_harvest_target.YIELD` als Duck-Typing-Schnittstelle, ein Umbenennen
  hätte die gebrochen.

### Bekannte Grenzen (Trupp-Arten)

- **Keine harte Zonen-Bindung** — die Vision sagt, Bautrupps arbeiten NUR
  innerhalb der eigenen Zone; aktuell wird das nicht erzwungen, ein
  Bautrupp kann sich (nur per Bewegungsbefehl, siehe oben) frei über die
  ganze Karte bewegen. Bewusst **verstärkt** durch das Markier-System
  (kartenweite automatische Zuweisung), auf ausdrücklichen Nutzerwunsch
  ("Arbeiter können potenziell überall Sachen abbauen").
- **Gebäude-Abriss noch nicht ins Markier-System integriert** — nur
  Direktbefehl (Bautrupp auswählen + Gebäude anklicken), kein
  Markieren/automatisches Zuweisen wie bei Bäumen/Wracks/Haufen.
- **Kein Catch-up für spät beitretende Peers** beim Gebäude-Abriss — ein
  spät beitretender Peer sieht ein bereits abgerissenes Gebäude lokal
  weiterhin stehend (dasselbe bereits bestehende Problem wie bei
  `Building.is_looted`, siehe [`docs/scavenging.md`](scavenging.md)).
- **Ressourcen gehören niemandem** — jeder Bautrupp jedes Spielers kann
  jede Ressourcenquelle abbauen, auch eine, die ursprünglich für die Zone
  eines anderen Spielers gespawnt wurde.

## Replikation

Ein kombiniertes `_sync_state(position, hp, hunger, carried_loot)`
(`@rpc("authority", "call_local", "unreliable_ordered")`) pro
`_process()`-Frame statt einzelner Delta-RPCs — jedes Paket trägt den
kompletten aktuellen Stand, ein gelegentlich verlorenes Paket korrigiert
sich im nächsten Frame von selbst. `call_local` ist Pflicht, sonst sieht
der Host die eigene Farbänderung (`_update_color()`, HP-abhängiger
Weiß→Rot-Verlauf) nie — siehe
[`docs/networking.md`](networking.md#call_local).

## Bekannte Grenzen (noch nicht gelöst)

- **Keine Kollision zwischen Einheiten** — mehrere gleichzeitig befohlene
  Trupps können exakt übereinander laufen/clippen. Bei Gruppenbefehlen
  löst `World._formation_offset()` das (siehe
  [`docs/commander.md`](commander.md)), beim automatischen Rückweg reicht
  Zufallsstreuung (siehe [`docs/scavenging.md`](scavenging.md)) — für
  alle anderen Fälle (z. B. zwei unabhängige Einzelbefehle zum selben
  Punkt) bleibt es ungelöst.
- **Vereinfachte Vertrauensannahme:** alle `order_*`-RPCs prüfen nur
  `requesting_peer_id == owner_peer_id`, ohne echte Autorisierung auf
  Absenderseite (`multiplayer.get_remote_sender_id()` wird nicht
  gegengeprüft) — für ein Koop-Spiel unter befreundeten Spielern
  akzeptiert, kein Schutz gegen einen böswilligen Client.
- **Kein Pathfinding** — direkte Linie zum Ziel, Mauern blockieren
  vollständig statt umgangen zu werden. Betrifft jetzt auch den
  Angriffsbefehl: bleibt das Ziel dauerhaft hinter einer Mauer, kommt der
  Trupp nie ran und der Angriff läuft faktisch ins Leere.

## Testen

Debug → Customize Run Instances → 2 → F5, Host + Join, "Spiel starten".
Trupp bewegen, von einem Zombie angreifen lassen (Farbe sollte Richtung
Rot wandern), zur Basis zurückziehen und Heilung beobachten (Medizin im
HUD sollte sinken). Hunger über Zeit beobachten — bei niedrigem Hunger
sollte sich die Bewegung sichtbar verlangsamen, an der Basis stehend
sollte Food verbraucht und Hunger wieder steigen.

**Angriffsbefehl:** Trupp auswählen, auf einen Zombie klicken — sollte
hinlaufen und automatisch draufschlagen, Zombie-HP sollte sinken (Farbe
dunkelt nach), Trupp nimmt dabei Gegenschaden vom Zombie. Während des
Kampfes woandershin klicken (Bewegen) — Angriff sollte sofort abbrechen.
Auf das Zombie-Nest klicken — Trupp sollte hinlaufen und es angreifen, bis
es zerstört ist.

**Trupp-Arten:** Trupp per Button in der Einheiten-Liste auf "Bautrupp"
umschalten (Button-Text sollte auf "→ Feldtrupp" wechseln). Als Feldtrupp
versuchen, einen Baum anzuklicken — sollte "Nur Bautrupps können das
abbauen." zeigen, nichts passieren. Zurück auf Bautrupp umschalten, Baum
anklicken — sollte hinlaufen und fällen, Holz im Ressourcen-Panel sollte
nach dem Fällen steigen. Als Bautrupp versuchen, ein noch nicht
durchsuchtes Gebäude anzuklicken — sollte "Nur Feldtrupps können Gebäude
durchsuchen." zeigen, Trupp bleibt stehen. Ebenso mit einem Zombie
versuchen — sollte "Nur Feldtrupps können angreifen." zeigen.

**Gebäude abreißen:** ein Gebäude durchsuchen lassen, NICHT claimen. Mit
einem Feldtrupp draufklicken — sollte claimen (bläulich färben) wie
gewohnt. Bei einem anderen, ebenfalls schon durchsuchten Gebäude
stattdessen einen Bautrupp draufklicken — sollte hinlaufen und abreißen,
Gebäude verschwindet, Stein UND Ziegel im Ressourcen-Panel sollten je um
20/10 steigen. Als Bautrupp versuchen, ein noch nicht durchsuchtes oder
schon geclaimtes Gebäude abzureißen — sollte nichts tun bzw. schon vorher
über den normalen Klick-Branch abgefangen werden.

**Markier-System:** ohne Auswahl auf einen Baum oder ein Autowrack klicken
— Krone/Wrack sollte gold werden, kein Trupp läuft los. Einen untätigen
Bautrupp haben (oder einen gerade fertig gewordenen) — sollte von selbst
zum markierten Ziel laufen und abbauen beginnen, ganz ohne Klick auf den
Trupp. Mehrere Ziele (Bäume UND Wracks gemischt) markieren, mehrere
Bautrupps bereitstellen — jeder sollte sich ein anderes Ziel vornehmen,
keine zwei auf demselben. Abbau-Auftrag per neuem Bewegungsbefehl
abbrechen, während das Ziel noch markiert ist — ein anderer freier
Bautrupp sollte es automatisch übernehmen. Autowrack abbauen lassen —
Metall im Ressourcen-Panel sollte um 20 steigen (mehr als Holz bei einem
Baum, das nur 15 gibt). Steinhaufen und Ziegelhaufen ebenso abbauen lassen
— Stein bzw. Ziegel sollten um je 15 steigen. Ein Stadt-Gebäude durchsuchen
lassen — sollte NUR noch Nahrung/Medizin/Munition abwerfen, kein Stein/
Ziegel mehr.
