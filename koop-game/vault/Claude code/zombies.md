# Zombies

Erklärt `scenes/entities/zombie/Zombie.gd`: Wandern, Erkennen/Verfolgen,
Angriff mit Survivor-Gegenschaden, Lärm-System, Mauer/Tor-Durchbrechen.
Host-autoritativ, gleiches Grundmuster wie
[`docs/survivor.md`](survivor.md). Blockierverhalten an Mauern/Toren
siehe [`docs/walls.md`](walls.md).

## Zustände

Kein State-Machine-Enum, sondern zwei einfache Modi, entschieden über
`_chase_target` (`null` = Wandern, sonst Verfolgen):

- **Wandern** (`_process_wander()`) — läuft zu einem zufälligen Punkt in
  `WANDER_RADIUS` (6.0) um die eigene Spawn-Position (`_home_position`),
  wartet dort `IDLE_TIME_MIN`–`IDLE_TIME_MAX` (1–3s), sucht sich dann ein
  neues Ziel. `WANDER_SPEED := 2.0`.
- **Verfolgen** (`_process_chase()`) — sobald ein Ziel erkannt/alarmiert
  wurde, mit `CHASE_SPEED := 5.0` (schneller als Wandern, aber langsamer
  als ein gesunder Survivor bei `MOVE_SPEED := 4.0`... genauer: schneller
  als der Survivor, daher gefährlich).

## Ziel-Erkennung (`_update_chase_target()`/`_find_nearest_target()`)

- **`DETECT_RADIUS := 8.0`** — Radius, in dem ein neues Ziel gewählt wird
  (nächster `"living"`-Node, der nicht "untouchable" ist, **plus** jedes
  geclaimte Gebäude, siehe direkt unten).
- **Geclaimte Gebäude sind ebenfalls Ziele** (Nutzerwunsch: "können
  Zombies geclaimte Gebäude angreifen? wenn nein, stell das um") —
  `_find_nearest_target()` durchsucht zusätzlich zu `"living"` auch die
  Gruppe `"searchable"`, gefiltert auf `owner_peer_id != 0`. Bewusst
  **nicht** in `"living"` selbst mit eingruppiert, um deren Bedeutung
  (tatsächlich lebende Einheiten/Fahrzeuge) nicht zu verwässern —
  stattdessen werden beide Listen vor der eigentlichen Auswahl
  zusammengeführt. `Building.gd` implementiert `take_damage()` bereits
  (siehe [`docs/survivor.md`](survivor.md), "Gebäude abreißen"), ein
  Zombie-Angriff funktioniert also ohne weitere Änderungen dort — kein
  Gegenschaden, da `Building.gd` kein `is_sheltered()` hat (siehe
  "Angriff + Gegenschaden" unten). Zerstört ein Zombie ein geclaimtes
  Gebäude vollständig, schrumpft die Bauzone des Besitzers entsprechend
  (siehe [`docs/zones.md`](zones.md)) — die eigentliche Home-Base mit den
  Ressourcen bleibt davon unberührt (separater Node, kein gültiges
  Zombie-Ziel, siehe "Horde-Nächte" oben).
- **`GIVE_UP_RADIUS := 14.0`** — deutlich größer als `DETECT_RADIUS`,
  damit ein einmal erkanntes Ziel nicht sofort wieder verloren geht,
  sobald es kurz aus dem Detect-Radius heraustritt.
- **`_is_untouchable(unit)`** = `_is_sheltered(unit) or
  _is_unoccupied_vehicle(unit)`:
  - `_is_sheltered()` — duck-typed `unit.has_method("is_sheltered") and
    unit.is_sheltered()`. Ein durchsuchender Trupp (siehe
    [`docs/scavenging.md`](scavenging.md)) ist weder als neues Ziel
    wählbar noch als laufendes Ziel haltbar — ersetzt echte
    Kollision/Pathfinding (die es bewusst nicht gibt) durch eine simple
    Zustandsabfrage.
  - `_is_unoccupied_vehicle()` — duck-typed `unit.has_method("is_occupied")
    and not unit.is_occupied()`. Nutzerentscheidung: ein geparktes,
    unbesetztes Fahrzeug ist kein Ziel, erst sobald jemand drinsitzt wird
    es angreifbar — siehe [`docs/vehicle.md`](vehicle.md).

## Angriff + Gegenschaden

- **`ATTACK_RANGE := 1.2`**, `ATTACK_COOLDOWN := 1.0`,
  `ATTACK_DAMAGE := 10`.
- Beidseitiger Kampf im selben Tick, kein RPC nötig (beide Seiten laufen
  schon host-seitig): `_try_attack(target)` ruft `target.take_damage(
  ATTACK_DAMAGE)` auf, und **nur falls** `target.has_method("is_sheltered")`
  (= ein echter Survivor, nicht Mauer/Tor/Fahrzeug) wehrt sich das Ziel
  automatisch mit `COUNTER_DAMAGE := 15` gegen den Zombie zurück. Mauern
  und Fahrzeuge haben keinen eigenen Gegenangriff.
- `has_method("is_sheltered")` dient hier bewusst als "ist das ein
  Survivor?"-Unterscheidung, weil aktuell nur `Survivor.gd` diese Methode
  implementiert (anders als `order_move()`, das inzwischen auch
  `Vehicle.gd` hat).

## Mauer/Tor-Durchbrechen

`_process_chase()` prüft per `_blocking_obstacle(from, to)` (Raycast auf
`OBSTACLE_LAYER`, Physik-Layer 2), ob eine Mauer/ein Tor auf der geraden
Linie zum eigentlichen Ziel steht. Falls ja, wird sie zum
**Zwischenziel** — der Zombie greift sie an, bis sie kaputt ist, statt
einfach hindurchzulaufen. Kein eigenes Navmesh/Pathfinding nötig, nutzt
dasselbe Verfolgen/Angreifen-Muster wie beim direkten Survivor-Kampf.
Anders als `Survivor._is_path_blocked()` prüft `_blocking_obstacle()`
**nicht** `Wall.blocks(owner_peer_id)` — ein Zombie hat nie eine passende
`owner_peer_id`, jedes Tor blockiert ihn also immer, unabhängig vom
Besitzer.

## Lärm-System

`_alert_nearby_zombies(target)` — nach jedem Angriff werden andere
Zombies in `NOISE_RADIUS := 11.0` (zwischen `DETECT_RADIUS` und
`GIVE_UP_RADIUS`) per `alert(target)` sofort auf dasselbe Ziel angesetzt,
auch wenn sie es selbst noch nicht im `DETECT_RADIUS` hatten. Greift Lärm
von einem Mauer-Zwischenziel aus, geht der Alarm trotzdem vom
**eigentlichen** Verfolgungsziel (`_chase_target`, meist der Survivor
dahinter) aus, nicht von der Mauer selbst — andere Zombies sollen weiter
Richtung Survivor gelenkt werden. `GuardPost._alert_nearby_zombies()`
dupliziert dieselbe Schleife bewusst statt einer geteilten Utility, siehe
[`docs/building.md`](building.md), "Bewusst dupliziert statt geteilt".

## HP + Tod

`MAX_HP := 40`. `take_damage(amount, source_peer_id := 0)` — kein RPC,
ausschließlich host-seitig aufgerufen (Gegenschaden aus `_try_attack()`,
Angriffsbefehl-Schaden aus `Survivor._process_attack()`, oder Beschuss
durch einen Wachposten). `_die()` (`@rpc("authority", "call_local",
"reliable")`) entfernt den Node einfach (`queue_free()`).

## Zombie-Loot-Drop

Nutzerwunsch: Zombies sollen bei ihrem Tod etwas droppen — ursprünglich
explizit **nur** Munition, Heilzeug, oder eine Waffe (kein Holz/Metall/
Stein/Ziegel/Nahrung). Später per explizitem Nutzerwunsch um Brustpanzer
und Helm (zwei getrennte Rüstungs-Slots) erweitert (siehe
[`docs/survivor.md`](survivor.md), "Rüstungssystem"), seit Punkt 18 der
Gesamtliste zusätzlich um Nahkampfwaffe und Beinschutz (siehe
[`docs/survivor.md`](survivor.md), "Haupt-/Sekundärwaffe"/"Dritter
Rüstungs-Slot").

- **`source_peer_id`** in `take_damage()` merkt sich in
  `_last_damage_source_peer_id`, welcher Spieler den Schaden verursacht
  hat — sowohl `Survivor._process_attack()` (`owner_peer_id` des
  angreifenden Trupps) als auch `GuardPost._try_fire()` (`owner_peer_id`
  des Wachpostens) geben das jetzt mit. `Zombie._try_attack()` gibt beim
  Gegenschaden ebenfalls `target.owner_peer_id` mit (der angegriffene
  Survivor "hat sich gewehrt"). Kein bekannter Verursacher (`0`, kommt
  in der Praxis nicht vor) → kein Drop.
- **Kein physischer Pickup-Node** — beim Sterben (`hp <= 0` in
  `take_damage()`) ruft der Zombie direkt
  `World.grant_zombie_loot(_last_damage_source_peer_id, is_brute)` auf
  (gleiches Cross-Node-Muster wie `spawn_recruit()`/
  `spawn_nest_zombie()`), die den Drop sofort in die Home-Base des
  Verursachers bucht (`add_resources.rpc()`).
- **`ZOMBIE_LOOT_DROP_CHANCE := 0.5`** — nicht jeder Kill droppt etwas.
  Bei Erfolg wird zufällig EIN Typ aus `ZOMBIE_LOOT_TABLE := ["ammo",
  "medicine", "weapon", "armor", "helmet", "melee_weapon", "leg_armor"]`
  gewählt, Menge aus `ZOMBIE_LOOT_AMOUNT` (Standard-Zombie) bzw.
  `BRUTE_LOOT_AMOUNT` (Brute droppt mehr: 10 Munition/8 Heilzeug/je 1 vom
  Rest statt 5/5/1×5). Sieben statt drei gleich gewichtete Typen verdünnen
  die Drop-Rate der ursprünglichen drei entsprechend weiter — bewusst in
  Kauf genommen statt einen zweiten, komplett neuen Drop-Mechanismus zu
  bauen. (War kurzzeitig sechs Typen mit "backpack" — Nutzerentscheidung
  2026-08-01: Rucksack ist kein Item mehr, siehe [`docs/survivor.md`](survivor.md),
  "Rucksack".)
- **"weapon"/"armor"/"helmet"** sind Ressourcentyp acht bis zehn
  (`HomeBase.START_RESOURCES`, `RESOURCE_DISPLAY_NAMES`) — alle drei werden
  mittlerweile verbraucht (Ausrüsten/Anlegen bzw. Fernkampf-Schuss), siehe
  [`docs/survivor.md`](survivor.md), "Waffensystem"/"Rüstungssystem".
- **Forschungsbücher (2026-08-01, siehe [`docs/building.md`](building.md),
  "Forschungsbücher"): eigener, SELTENERER Zusatz-Wurf**, bewusst NICHT
  Teil der obigen `ZOMBIE_LOOT_TABLE` (die Vision beschreibt Bücher
  explizit als "selten"/"sehr selten", ein gleichgewichteter Sieben-Typen-
  Pool wäre viel zu häufig dafür). `BOOK_DROP_CHANCE := 0.08`, unabhängig
  vom Haupt-Loot-Wurf ausgewürfelt (kann zusätzlich ODER ganz ohne
  normalen Loot auftreten) — bei Erfolg ein zufälliger Typ aus
  `BOOK_TABLE := ["book_weapon", "book_armor", "book_helmet",
  "book_ammo"]`, immer genau 1 Stück (kein Brute-Bonus).
- **`ZombieNest.take_damage()`** hat aus reiner Aufruf-Kompatibilität
  denselben optionalen `_source_peer_id`-Parameter bekommen (Wachposten
  feuern auf dieselbe Ziel-Liste wie auf normale Zombies, siehe
  `GuardPost._find_nearest_zombie()`) — ein Nest selbst droppt aber
  nichts, der Wert wird dort ignoriert.

## Nacht-Schadensbonus

Nutzerwunsch: "Zombies ab 22 Uhr bis 4 Uhr morgens 20% stärker" — direkt
an dieselbe Uhrzeit/dasselbe Nacht-Fenster gekoppelt, das auch die
Beleuchtung und den Horde-Trigger steuert (siehe
[`docs/world.md`](world.md), "Tag/Nacht-Zyklus",
`World.NIGHT_START_HOUR`/`NIGHT_END_HOUR` = 22:00–4:00).

- **`Zombie._try_attack()`** fragt vor jedem Angriff
  `get_tree().current_scene.is_night()` ab (Cross-Node-Aufruf auf
  `World.is_night()`, gleiches Muster wie `spawn_recruit()`) und
  multipliziert den Schaden mit `ZOMBIE_NIGHT_DAMAGE_MULTIPLIER := 1.2`,
  bevor `target.take_damage()` aufgerufen wird.
- Gilt für Standard-Zombies UND Brutes gleichermaßen — multipliziert den
  jeweils schon typ-abhängigen `_attack_damage` (10 bzw. 25), keine
  eigene Brute-Sonderbehandlung nötig.
- **Bewusst nur der Angriffsschaden**, nicht HP oder Geschwindigkeit —
  ein dynamischer Max-HP-Sprung bei Nachtbeginn hätte einem schon
  angeschlagenen Zombie unbeabsichtigt Gratis-HP zurückgegeben (aktuelle
  HP werden nirgends "neu skaliert").
- Wirkt sich nur auf Schaden AN Trupps/Gebäuden aus, nicht auf Schaden
  DURCH einen Wachposten/Trupp-Angriffsbefehl GEGEN Zombies (dafür gibt
  es keinen Nachtbonus — der Nutzerwunsch war ausdrücklich "Zombies
  stärker", nicht "Spieler schwächer").

## Replikation + Farbe

`_sync_state(position, hp)` (`unreliable_ordered`, analog zu
`Survivor._sync_state()`, siehe [`docs/survivor.md`](survivor.md)).
`_update_color()` dunkelt Grün mit sinkendem HP nach — bewusst anderer
Farbverlauf als beim Survivor (Weiß→Rot), damit beide auf den ersten
Blick unterscheidbar bleiben.

## Zombie-Typen

Zwei Typen, ein Script (`Zombie.gd`) — gleiches Muster wie
`Wall.gd`/`is_gate` (siehe [`docs/building.md`](building.md)), aber als
zwei getrennte Szenen statt nur einem Export-Flag auf derselben Szene
(unterschiedliche Kapsel-Maße lassen sich in `.tscn` nicht per Export
umschalten):

- **`Zombie.tscn`** — Standard-Läufer, Kapsel 1,7m × 0,3m (radius),
  `is_brute = false` (Default).
- **`ZombieBrute.tscn`** — zäher Brute, Kapsel 2,1m × 0,4m (radius),
  `is_brute = true`, Maße aus `Infos/03 Asset-Checkliste.md`
  ("Zombie Brute | 2,1m × 0,5m × 0,4m").

`@export var is_brute: bool` steuert in `_ready()` vier
Instanzvariablen (`_max_hp`, `_wander_speed`, `_chase_speed`,
`_attack_damage`), die überall dort verwendet werden, wo vorher direkt
die Konstanten standen:

| | Standard | Brute |
|---|---|---|
| HP | `MAX_HP := 40` | `BRUTE_MAX_HP := 100` |
| Wander-Speed | `WANDER_SPEED := 2.0` | `BRUTE_WANDER_SPEED := 1.2` |
| Chase-Speed | `CHASE_SPEED := 5.0` | `BRUTE_CHASE_SPEED := 3.5` |
| Angriffsschaden | `ATTACK_DAMAGE := 10` | `BRUTE_ATTACK_DAMAGE := 25` |

Bekannte `@export`-Timing-Falle beachtet (siehe auch `Wall.gd`): ein
Feld-Default wie `var hp: int = MAX_HP` würde vor der
Export-Übernahme ausgewertet und für Brute-Instanzen immer den
Nicht-Brute-Wert liefern. Deshalb `var hp: int = 0` und die echte
Zuweisung erst in `_ready()`, nachdem `is_brute` feststeht.

`_update_color()` gibt Brutes einen eigenen, dunkleren Grundton
(`Color(0.18, 0.22, 0.12)` statt `Color(0.2, 0.5, 0.2)`) — zusätzlich
zur größeren Kapsel auch farblich auf den ersten Blick unterscheidbar.

**Spawn-Integration:** `World._create_zombie(data)` liest
`data.get("is_brute", false)` und instanziert `ZOMBIE_BRUTE_SCENE`
statt `ZOMBIE_SCENE`, wenn gesetzt. Die vier festen Start-Zombies
(`_spawn_zombies()`) sind dadurch automatisch Standard-Läufer (kein
`is_brute`-Key im `data`-Dictionary → Default `false`). Horde-Nächte
(siehe unten) mischen `HORDE_BRUTE_COUNT := 2` Brutes in die
`HORDE_SIZE := 10` Zombies pro Welle. Getrennte Ground-Y-Konstanten
(`ZOMBIE_GROUND_Y := 0.85`, `ZOMBIE_BRUTE_GROUND_Y := 1.05`), da die
größere Kapsel sonst im Boden versinken würde. Late-Join-Catch-up
(`_catch_up_zombie()`) reicht `is_brute` als viertes RPC-Argument
durch, damit später beitretende Peers auch schon existierende Brutes
korrekt (mit der richtigen Szene/Optik) sehen.

## Zombie-Nest

Erklärt `scenes/entities/zombie/ZombieNest.gd` — löst die frühere
"kein Nachspawnen"-Grenze (siehe unten) auf. **Seit dem Kartenumbau**
(siehe [`docs/world.md`](world.md)) gibt es **ein Nest pro Stadt-Zone**
(fünf statt einem gesamt), erzeugt über `zombie_nest_spawner`/
`World._create_zombie_nest()` (gleiches Muster wie Tree/Zombie) statt
eines einzelnen festen `.tscn`-Kind-Nodes. Jedes Nest spawnt alle
`SPAWN_INTERVAL := 25.0` Sekunden einen neuen Zombie in seiner Nähe
(`SPAWN_SCATTER := 2.0`, leicht zufällig gestreut) — **ohne Obergrenze**,
solange es existiert. Die von ihm erzeugten Zombies selbst laufen über den
bestehenden `zombie_spawner` (`World.spawn_nest_zombie()`, gleiches
Cross-Node-Muster wie `spawn_recruit()`, eigener Namenszähler
`_next_nest_zombie_id` ab `CITY_ZONE_COUNT * ZOMBIES_PER_ZONE`, damit nie
eine Namenskollision mit den pro Zone gespawnten Start-Zombies entsteht).
**Fünf Nester statt einem bedeutet 5× so schnelles Zombie-Wachstum** wie
vorher — bewusst in Kauf genommen (siehe `docs/world.md`, "Kartenlayout"),
macht die bereits früher zurückgestellte Zombie-Obergrenze/Despawn-Idee
relevanter.

**Zerstörbar, HP wie eine Mauer:** `MAX_HP := 150`, `take_damage()`/`_die()`
folgen exakt demselben Muster wie `Wall.gd` (kein RPC, host-seitig
aufgerufen, `_die()` räumt sich per `queue_free()` selbst weg — danach
spawnt nichts mehr nach). Erreichbar über zwei Wege:

- **Wachposten in Reichweite** — `GuardPost._find_nearest_zombie()`
  durchsucht zusätzlich zur Gruppe `"zombie"` auch `"zombie_nest"`
  (dieselbe Ziel-Ermittlung, kein eigener Code-Pfad), feuert also
  automatisch auf ein Nest, sobald es in `FIRE_RANGE` (6.0) liegt — genau
  wie auf einen normalen Zombie. Ein beschossenes Nest löst dabei bewusst
  **keinen** Alarm bei anderen Zombies aus (`_try_fire()` prüft
  `target.is_in_group("zombie")` vor `_alert_nearby_zombies()`) — ein Nest
  hat kein bewegliches Ziel, das andere Zombies sinnvoll verfolgen
  könnten, und implementiert auch kein `alert()`.
- **Eigener Trupp-Angriffsbefehl** (siehe [`docs/survivor.md`](survivor.md),
  "Angriffsbefehl") — ein Trupp kann direkt auf ein Nest angesetzt werden,
  läuft hin und greift im Nahkampf an, bis es zerstört ist oder ein neuer
  Befehl kommt. Anders als der Wachposten ganz ohne Reichweiten-
  Einschränkung durch die eigene Bauzone.

**Konsequenz (Nutzerwunsch, bewusst so):** Population wächst unbegrenzt,
solange das Nest steht — zerstört man es rechtzeitig, kann man die Karte
theoretisch komplett zombiefrei bekommen. Lässt man es zu lange stehen,
kann die Zombiezahl entsprechend außer Kontrolle geraten.

## Horde-Nächte

Zweiter, unabhängiger Eskalations-Mechanismus neben dem Zombie-Nest (siehe
oben) — die aus der Zombie-Population-Session mehrfach zurückgestellte
größere Idee, jetzt umgesetzt: periodisch eine große, gebündelte Welle
statt nur des laufenden lokalen Lärm-Aggros oder des langsamen
Nest-Nachwachsens.

- **`World._handle_day_night(delta)`** (läuft auf jedem Peer, siehe
  [`docs/world.md`](world.md), "Tag/Nacht-Zyklus") löst — nur wenn
  `multiplayer.is_server()` — genau einmal pro Nacht (beim Übergang von
  Tag zu Nacht, `is_night() and not _horde_triggered_this_night`) eine
  `_trigger_horde_night()` aus. Nicht mehr an ein reines
  Echtzeit-Intervall gekoppelt, sondern an den echten Spieltag —
  Nutzerwunsch, ersetzt das frühere `HORDE_INTERVAL`.
- **`_trigger_horde_night()`:** warnt zuerst alle verbundenen Spieler
  (`report_status()` an jede `NetworkManager.players`-ID: "Eine Horde
  nähert sich!"), spawnt danach `HORDE_SIZE := 10` Zombies (mit etwas
  Streuung, `HORDE_SPAWN_SCATTER := 6.0`) und alarmiert sie SOFORT auf ein
  gemeinsames Ziel (`zombie.alert(target)`) statt sie normal wandern zu
  lassen — echter, gebündelter Druck statt nur mehr Wander-Zombies. **Seit
  dem Kartenumbau** (siehe [`docs/world.md`](world.md)) spawnt die Horde
  nicht mehr an vier festen, globalen `ZOMBIE_SPAWN_POINTS` (die es auf der
  neuen 5000×5000-Karte nicht mehr geben kann — ein Ziel könnte
  kilometerweit von jedem festen Punkt entfernt sein), sondern
  `HORDE_APPROACH_DISTANCE := 40.0` Weltmeter vom gewählten Ziel entfernt,
  in zufälliger Richtung (Fallback: eine zufällige Stadt-Zonen-Mitte, wenn
  kein Ziel existiert). Die ersten `HORDE_BRUTE_COUNT := 2` der 10 sind
  Brutes (siehe "Zombie-Typen" oben), der Rest Standard-Läufer — jeder
  Spawn nutzt die zu seinem Typ passende Ground-Y-Konstante.
- **`_random_horde_target()`** wählt einen zufälligen lebenden Trupp
  (Gruppe `"living"`) als gemeinsames Ziel für die ganze Horde — bewusst
  **kein** Gebäude/keine Home-Base, weil `Zombie._try_attack()`
  `target.take_damage()` aufruft und `HomeBase.gd` das (anders als
  Survivor/Wall/Building/Vehicle/ZombieNest) nicht implementiert — ein
  direktes Anvisieren der Home-Base hätte beim ersten Angriffsversuch
  einen Laufzeitfehler ausgelöst. Kein lebender Trupp vorhanden (ganz
  frühes Spiel) → `null`, Horde wandert dann einfach normal (kein Absturz,
  nur weniger dramatisch).
- Nutzt denselben `_next_nest_zombie_id`-Zähler wie das Zombie-Nest (siehe
  oben) — beide sind "zusätzliche" Zombies über die vier festen
  Start-Zombies hinaus, ein gemeinsamer Zähler reicht.

## Blutmond-Kalender-Eskalation (2026-08-03, Punkt 21 der Gesamtliste)

Vision (`Infos/01 Architektur.md`): "Blutmond-Events: Alle paar Tage
(kalenderbasiert) formiert sich eine große, gebündelte Horde und greift
gezielt an — zusätzlich zum laufenden lokalen Lärm-Aggro, nicht als Ersatz
dafür." Die bisherigen Horde-Nächte (oben) feuern schon JEDE Nacht mit
fester Stärke — deckt den "lokalen Lärm-Aggro"-Teil der Vision-Formulierung
ab, aber nicht die kalenderbasierte STEIGERUNG. Diese Ergänzung fügt genau
die fehlende Eskalation hinzu, ohne die bestehende nächtliche Logik zu
ersetzen.

- **`World._day_count`** zählt volle Spieltage, inkrementiert in
  `_handle_day_night()` bei jedem Zyklus-Wrap (`_day_time >= CYCLE_LENGTH`)
  — läuft wie `_day_time` selbst LOKAL auf JEDEM Peer (nicht host-gated),
  damit `is_blood_moon_night()` auf allen Peers identisch auswertet (auch
  für den Himmel-Ton unten gebraucht, nicht nur für den host-gateten
  Horde-Trigger). Catch-up über `_catch_up_day_time()` (zweiter Parameter),
  Spielstand-Persistenz über `_collect_save_data()`/`_load_game_state()`
  (`"day_count"`).
- **`is_blood_moon_night()`:** `(_day_count + 1) % BLOOD_MOON_INTERVAL_DAYS
  == 0` — jede 5. Nacht (1-indexiert: Nacht 5, 10, 15, ...) ist ein
  Blutmond. `BLOOD_MOON_INTERVAL_DAYS := 5` bei `CYCLE_LENGTH := 300s` pro
  Spieltag macht das alle 25 Minuten Echtzeit.
- **`_trigger_horde_night()` verzweigt intern** statt eine zweite Funktion
  zu duplizieren: an einer Blutmond-Nacht spawnt sie
  `BLOOD_MOON_HORDE_SIZE := 30` Zombies (statt `HORDE_SIZE := 10`), davon
  `BLOOD_MOON_BRUTE_COUNT := 10` Brutes (statt `HORDE_BRUTE_COUNT := 2`),
  mit eigener Vorwarnung ("BLUTMOND! Eine gewaltige Horde formiert sich!"
  statt der normalen Horde-Nacht-Meldung). Ziel-/Spawn-Logik (Ziel-Trupp,
  `HORDE_APPROACH_DISTANCE`, `HORDE_SPAWN_SCATTER`) bleibt unverändert —
  nur Größe/Zusammensetzung/Text unterscheiden sich.
- **`MAX_ZOMBIES`-Deckel gilt weiterhin nicht** für Horde-Nächte (siehe
  "Zombie-Obergrenze" unten) — an einer Blutmond-Nacht kann die
  Zombie-Zahl entsprechend deutlicher über 200 hinausschießen als an einer
  normalen Nacht.
- **Blutmond-Himmel:** `World._update_day_night_visuals()` mischt an einer
  Blutmond-Nacht zusätzlich `BLOOD_MOON_LIGHT_COLOR`/`BLOOD_MOON_SKY_COLOR`
  über dieselbe Dusk-Kurve (`_night_amount()`) wie den normalen Tag/Nacht-
  Übergang ein — ersetzt die Nachtfarbe nicht hart, sonst würde die
  Überblendung sichtbar springen statt weich zu verlaufen. Läuft auf jedem
  Peer lokal (siehe oben), keine zusätzliche RPC nötig.
- **Bewusst NICHT geändert:** `ZOMBIE_NIGHT_DAMAGE_MULTIPLIER` (der 20%-
  Nacht-Schadensbonus, siehe unten) gilt unverändert für JEDE Nacht,
  Blutmond oder nicht — die Eskalation kommt ausschließlich über Zahl/
  Zusammensetzung der Horde, kein zusätzlicher Schadens-Multiplikator.

**Noch nicht vom Nutzer getestet** — bei `CYCLE_LENGTH := 300s` dauert es
mindestens 25 Minuten Echtzeit bis zur ersten Blutmond-Nacht, für einen
schnellen Test ggf. `BLOOD_MOON_INTERVAL_DAYS` temporär auf 1 senken.

## Zombie-Obergrenze

Löst das mit dem Kartenumbau verschärfte Risiko unbegrenzten
Zombie-Wachstums (5 Nester statt 1, siehe "Zombie-Nest" oben und
persistentes Memory `koopgame_map_scale_performance`): Zielsuche
(`_find_nearest_target()`, Wachposten-Beschuss, Lärm-Alarm) läuft O(n) pro
Zombie pro Frame über flache Gruppen-Iteration ohne räumliche Struktur —
skaliert quadratisch mit der Zombie-Zahl.

- **`World.MAX_ZOMBIES := 200`** — bewusst ein Startwert zum empirischen
  Benchmarken, kein "richtig" berechneter Wert (hardwareabhängig).
- **Nur das Zombie-Nest respektiert den Deckel:**
  `World.spawn_nest_zombie()` prüft vor jedem Spawn
  `get_tree().get_nodes_in_group("zombie").size() >= MAX_ZOMBIES` und
  lässt den Spawn einfach aus, wenn erreicht — **kein Despawn** nötig,
  die Zahl sinkt von selbst, sobald Spieler welche töten. Nächster
  Versuch automatisch beim nächsten `SPAWN_INTERVAL`.
- **Horde-Nächte dürfen den Deckel bewusst kurz überschreiten** — fester,
  einmaliger Ausschlag von `HORDE_SIZE` (10), keine wiederkehrende
  Eskalation wie beim Nest, deshalb keine eigene Prüfung nötig.
- **Live-Anzeige:** `$ResourcesUI/Panel/VBoxContainer/ZombieCountLabel`
  zeigt `"Zombies: X/200"`, aktualisiert gedrosselt über
  `WORKER_UI_REFRESH_INTERVAL` (`World._update_zombie_count_label()`) —
  zum Beobachten der Population während des Testens/Benchmarkens.
- **Debug-Stresstest-Hotkey `F9`** (`World._debug_spawn_zombies()`, nur
  host-seitig wirksam): spawnt sofort `DEBUG_ZOMBIE_SPAWN_COUNT := 50`
  Zombies verteilt um die aktuelle Kameraposition (`pivot.position`,
  `DEBUG_ZOMBIE_SPAWN_SCATTER := 30.0`), bewusst **ohne**
  `MAX_ZOMBIES`-Prüfung — Stresstest soll den Deckel gezielt und schnell
  überschreiten können, ohne erst `SPAWN_INTERVAL`-Zyklen abzuwarten.
  Reines Entwickler-Werkzeug, kein Spielfeature, kein UI-Button.

## Performance: Spatial Grid + Zielsuche throttlen

Direkte Reaktion auf einen konkreten Messwert: 500 Zombies (per `F9` über
`MAX_ZOMBIES` hinaus gespawnt) → 15 FPS. Zwei getrennte Ursachen identifiziert
(siehe persistentes Memory `koopgame_map_scale_performance`), beide behoben:

1. **Echtes O(z²), aber nur während Kampf:** `Zombie._alert_nearby_zombies()`
   sowie `GuardPost._find_nearest_zombie()`/`_alert_nearby_zombies()`
   durchsuchten bei jedem Aufruf die komplette `"zombie"`-Gruppe statt nur
   die Nachbarschaft.
2. **Vermutlich der eigentliche Übeltäter im F9-Test** (Zombies stehen dabei
   erstmal nur rum, kämpfen nicht): `Zombie._update_chase_target()` rief
   `_find_nearest_target()` jeden Frame für jeden wandernden Zombie auf, ganz
   ohne Throttling.

**Fix 1, Spatial Grid** (`World.gd`): `_zombie_grid: Dictionary[Vector2i,
Array]`, jeden Frame einmal neu befüllt (`_rebuild_zombie_grid()`, nur
host-seitig, `_process()` vor allem anderen — World ist Vorfahre von
Zombie/GuardPost im Szenenbaum, Godot verarbeitet `_process()` in
Baum-Reihenfolge, Eltern vor Kindern, sonst würden sie mit dem
Grid-Stand vom Vorframe arbeiten). `World.ZOMBIE_GRID_CELL_SIZE := 15.0` —
bewusst größer als der größte gebrauchte Suchradius
(`Zombie.FIRE_NOISE_RADIUS`/`NOISE_RADIUS`, max. 13), damit `World.
zombies_near(pos, radius)` mit einem 3×3-Zellen-Ausschnitt um den Zielpunkt
garantiert jeden Kandidaten innerhalb des Radius trifft. Ersetzt die volle
Gruppenabfrage in `Zombie._alert_nearby_zombies()` und
`GuardPost._find_nearest_zombie()`/`_alert_nearby_zombies()`. Zombie-Nest
bleibt bei `_find_nearest_zombie()` weiterhin normale Gruppenabfrage (immer
nur wenige, eine pro Stadt-Zone, lohnt sich nicht).

**Fix 2, Zielsuche throtteln** (`Zombie.gd`): `TARGET_SEARCH_INTERVAL :=
0.2` — `_update_chase_target()` löst die teure `_find_nearest_target()`-Suche
nur noch alle 0.2s aus, statt jeden Frame. Die Give-up-Prüfung für ein schon
verfolgtes Ziel (Distanz > `GIVE_UP_RADIUS` oder `_is_untouchable()`) bleibt
bewusst unthrottled (reine Distanzprüfung, billig, soll ohne Verzögerung
reagieren) — nur die Neusuche selbst wird gedrosselt. Jeder Zombie startet
mit einem zufälligen Timer-Versatz (`randf_range(0.0, TARGET_SEARCH_INTERVAL)`
in `_ready()`), damit sich die Suchen über die Zeit verteilen statt alle im
selben Frame periodisch gemeinsam aufzuschlagen.

**Bewusst nicht Teil dieses Umbaus:** `Vehicle._handle_noise()` hat dieselbe
volle-Gruppenabfrage-Struktur, ist aber schon auf `NOISE_INTERVAL := 2.0`s
gedrosselt und betrifft nur zwei Fahrzeuge — kein Hotspot, außerhalb des
Scopes dieser beiden Punkte.

**Nutzer-Nachtest:** 300 Zombies (per F9 mehrfach über `MAX_ZOMBIES`
gespawnt) → 35–40 FPS, Ausschläge bis 40ms. Deutliche Verbesserung
gegenüber dem alten 500-Zombie/15-FPS-Messwert (66ms), aber immer noch
spürbar ruckelig — Anlass für die folgende dritte Ursache.

## Performance: Material-Cache statt Neuallokation pro Frame

Beim Nachtest der obigen zwei Fixes fiel ein dritter, unabhängiger Kostenpunkt
auf, rein durch Code-Durchsicht (kein Profiler verfügbar): `Zombie._process()`
rief `_sync_state.rpc(position, hp)` **jeden Frame für jeden Zombie**
auf — wegen `call_local` (siehe `@rpc`-Annotation) ruft das die Funktion auch
beim Host selbst synchron auf, für seinen eigenen, längst korrekten Zustand
(gleiche Grundursache wie beim throttling-Fix oben, aber ein zweiter,
unabhängiger Fundort). `_sync_state()` rief dabei bedingungslos
`_update_color()` auf, die **jedes Mal ein neues `StandardMaterial3D`
erzeugte** und per `set_surface_override_material()` neu zuwies — bei 300
Zombies 300 Material-Neuallokationen + GPU-Statewechsel pro Frame, komplett
unabhängig davon, ob sich der HP-Wert überhaupt geändert hatte (in den
allermeisten Frames für die allermeisten Zombies: nein).

**Fix** (`Zombie.gd`): zwei Teile.
- `_sync_state()` vergleicht `new_hp` jetzt mit dem aktuellen `hp` *bevor*
  es überschrieben wird und ruft `_update_color()` nur noch bei einer
  echten Änderung auf.
- `_update_color()` selbst legt das Material nur noch einmal an (`_material`,
  neues gecachtes Member-Feld) und mutiert danach nur noch dessen
  `albedo_color` statt bei jedem Aufruf ein neues Objekt zu erzeugen —
  greift auch dann, wenn sich HP wirklich ändert (z. B. während eines
  Kampfes mit mehreren Treffern kurz hintereinander).

**Vom Nutzer bestätigt getestet:** 320 Zombies → 75 FPS, 17–20ms (vorher 300
Zombies @ 35–40 FPS/bis 40ms, davor 500 Zombies @ 15 FPS ohne alle drei
Fixes).

## Performance: RPC nur bei echten Remote-Peers

Nutzer-Nachtest mit den jetzt größeren Städten (siehe `world.md`,
"Kartenlayout"): 620 Zombies → 37 FPS (Ausschläge bis 35), 40–50ms. Verglichen
mit dem 320-Zombie-Messwert (17–20ms) skaliert das jetzt näherungsweise
LINEAR statt quadratisch (620/320 ≈ 1,9×, 40–50ms/17–20ms ≈ 2,2–2,9×) — die
drei vorherigen Fixes greifen also, aber der verbleibende lineare
Grundaufwand pro Zombie war noch nicht ausgereizt.

**Vierter Fund** (wieder reine Code-Durchsicht, kein Profiler verfügbar):
`Zombie._process()` rief `_sync_state.rpc(position, hp)` weiterhin **jeden
Frame für jeden Zombie** auf, unabhängig davon, ob überhaupt ein
Remote-Peer verbunden ist. Beim F9-Stresstest (und beim neuen "Solo"-Modus,
siehe `docs/save_load.md`, Hauptmenü-Überarbeitung) gibt es **gar keinen**
Remote-Peer — der komplette RPC-Dispatch (Argument-Marshalling für
`Vector3`+`int`, Methoden-Lookup über die Netzwerk-RPC-Konfiguration) läuft
dann für niemanden: `position`/`hp` sind durch die direkte Zuweisung in
`_process_chase()`/`_process_wander()`/`take_damage()` beim Host lokal schon
korrekt, `call_local` würde nur genau diesen schon korrekten Zustand
redundant nochmal setzen.

**Fix** (`Zombie.gd`): `_process()` prüft jetzt `multiplayer.get_peers().
is_empty()` — ohne Remote-Peer wird die RPC komplett übersprungen, stattdessen
nur bei einer echten HP-Änderung direkt `_update_color()` aufgerufen
(`_last_synced_hp`, dieselbe "nur bei Änderung"-Idee wie beim
Material-Cache-Fix, nur lokal verglichen statt über die RPC-Parameter). Mit
verbundenem Remote-Peer läuft `_sync_state.rpc()` unverändert wie vorher —
reine Solo-/Stresstest-Optimierung, keine Verhaltensänderung im echten
Multiplayer.

**Bewusst nicht Teil dieses Fixes war damals die Sync-FREQUENZ selbst** —
siehe der folgende Abschnitt, das ist jetzt Punkt 7 der Performance-Liste.

Noch nicht erneut mit F9/620 Zombies nachgemessen (kein laufender
Godot-Editor in dieser Umgebung verfügbar).

## Performance: Netzwerk-Sync bündeln statt Einzel-RPC pro Zombie

Punkt 7 der Performance-Liste, direkte Fortsetzung des RPC-Skip-Fixes oben:
`Zombie._process()` rief weiterhin (mit verbundenem Remote-Peer)
`_sync_state.rpc(position, hp)` **einmal PRO Zombie PRO Frame** auf — bei
600+ Zombies also 600+ einzelne RPC-Dispatches (eigenes Argument-
Marshalling, eigener Methoden-Lookup, ein eigenes Netzwerkpaket) jeden
Frame, obwohl alle dieselbe Art von Daten an dieselben Empfänger schicken.

**Bewusst nur für Zombies umgesetzt, nicht für alle Entity-Typen** (Umfang
auf Nutzer-Rückfrage geklärt) — Survivor/Vehicle senden weiterhin ihr
eigenes `_sync_state.rpc()` unverändert. Zombies sind mit Abstand die
höchste Entity-Zahl (hunderte, siehe `MAX_ZOMBIES`/Benchmark-Werte), eine
Handvoll Survivor/Fahrzeuge pro Spieler bringt beim Bündeln keinen
nennenswerten Gewinn, aber genauso viel zusätzlichen Code (eigene
Batch-Struktur, eigenes Sammeln, eigenes Anwenden) — kein guter Tausch.

**Umsetzung:**
- `Zombie.gd` verschickt gar kein RPC mehr selbst. `_process()` aktualisiert
  nur noch lokal die eigene Farbe bei echter HP-Änderung (`_last_synced_hp`,
  läuft nicht mehr peer-abhängig verzweigt — der Host braucht seine eigene
  Farbe unabhängig davon, ob überhaupt jemand mitspielt). Das alte
  `@rpc _sync_state()` ist durch die einfache Methode
  `apply_synced_state(new_position, new_hp)` ersetzt — kein eigenes RPC
  mehr, wird von `World._apply_zombie_batch()` direkt aufgerufen.
- `World._sync_zombies_batch(zombies)` (host-seitig, `_process()`, gleiche
  Solo-Optimierung wie vorher: komplett übersprungen, wenn
  `multiplayer.get_peers()` leer ist) sammelt `zombie_id`/`position`/`hp`
  aller Zombies in drei parallelen `Packed*Array`s (kompakter zu
  serialisieren als eine `Array[Dictionary]`, weniger Overhead pro Eintrag)
  und verschickt sie in EINEM `_apply_zombie_batch.rpc(...)`-Aufruf.
- `World._apply_zombie_batch()` läuft mit `"call_remote"` (nicht
  `"call_local"`) — der Host braucht seine eigene Sendung nicht, sein
  Zustand ist über die direkten Feldzuweisungen in
  `Zombie._process_chase()`/`_process_wander()`/`take_damage()` längst
  aktuell. Findet jeden Zombie über denselben Namens-Pfad wie der Catch-up
  (`"zombie_%d" % id` in `zombies_container`, siehe `_create_zombie()`).
- Die `"zombie"`-Gruppenabfrage in `World._process()` läuft jetzt nur noch
  EINMAL pro Frame (`var zombies := get_tree().get_nodes_in_group("zombie")`)
  und wird sowohl an `_rebuild_zombie_grid()` (Spatial Grid, siehe oben) als
  auch an `_sync_zombies_batch()` durchgereicht, statt beide Funktionen
  jeweils ihre eigene Abfrage machen zu lassen.

**Bewusst nicht Teil dieses Fixes:** die Sync-FREQUENZ selbst (jeden Frame,
sobald Peers verbunden sind) bleibt unangetastet — eine niedrigere Rate
bräuchte Client-seitige Interpolation, damit Bewegung nicht sichtbar
ruckelt (aktuell setzt `apply_synced_state()` die Position hart, ohne
Zwischenschritte), das ist bewusst kein Teil dieses Umbaus.

Noch nicht vom Nutzer getestet — die offene Solo-vs-Multiplayer-Frage aus
`benchmarks.md` ist hier besonders relevant: dieser Fix wirkt sich NUR im
echten Multiplayer-Fall aus (Solo profitierte schon vom vorherigen
RPC-Skip-Fix), ein Solo-Benchmark wird also keine Veränderung zeigen.

## Zombie-Despawn

Löst eine andere Facette desselben Grundproblems: `MAX_ZOMBIES` und das
Zombie-Nest (siehe oben) begrenzen zwar die Gesamtzahl bzw. sinken durch
Spielerkills, aber **nie von selbst** — ein Wander-Zombie, der sich nie von
seinem Spawnpunkt entfernt (Standard-Verhalten, siehe `WANDER_RADIUS`), in
einer nie besuchten Stadt-Zone bleibt für den Rest der Session für niemanden
mehr relevant, zählt aber trotzdem dauerhaft gegen den Deckel.

- **`World._despawn_far_zombies()`**, host-seitig, alle
  `ZOMBIE_DESPAWN_CHECK_INTERVAL := 10.0`s (`_process()`, gleicher
  Timer-Takt wie die anderen gedrosselten Weltschritte). Baut einmal pro
  Check eine Präsenz-Liste (`"living"` + `"home_base"` + geclaimte
  `"searchable"`-Gebäude) und despawnt jeden Zombie, der von JEDEM Eintrag
  weiter als `ZOMBIE_DESPAWN_RADIUS` entfernt ist.
- **Bewusst rein distanzbasiert, keine eigene Alters-Verfolgung pro
  Zombie** — ein Zombie kann im gemeinten Sinn nur "alt und fern" sein, wenn
  seit längerem niemand in der Nähe war, ein einfacher Distanz-Check
  erfasst das ohne zusätzlichen Zustand pro Zombie.
- **`ZOMBIE_DESPAWN_RADIUS := 580.0`** — bewusst groß genug für eine GANZE
  aktiv bespielte Stadt-Zone, nicht nur die unmittelbare Nähe, berechnet
  für den schlimmsten Fall (die größere der zwei Zonengrößen seit der
  Kartenplanungs-Session 2026-08-01, siehe [`world.md`](world.md),
  "Kartenlayout"): die vier Start-Zombies einer großen Zone spawnen auf
  einem Ring bei `CITY_ZONE_RADIUS_LARGE (260) + ZOMBIE_SPAWN_RING_OFFSET
  (60) = 320` um das Zentrum, Gebäude liegen innerhalb der 260 verteilt —
  im Extremfall (Zombie und einziges geclaimtes Gebäude auf
  gegenüberliegenden Seiten der Zone) macht das 320+260=580 Weltmeter,
  obwohl die Zone eindeutig aktiv bespielt wird. Trotzdem deutlich kleiner
  als `CITY_ZONE_MIN_SPACING` (800), reicht also nie in eine benachbarte
  Zone hinein.
- **`Zombie.despawn()`** — öffentliche Methode, nutzt denselben replizierten
  Lösch-Pfad wie ein echter Tod (`_die.rpc()`), aber ohne Loot-Drop/
  `take_damage()` (kein echter Tod, nur Aufräumen).
- **Kein Referenzpunkt vorhanden → nichts despawnen** (`presence.is_empty()`
  in `_despawn_far_zombies()`) — verhindert, dass ein kurzzeitiger Zustand
  ganz ohne lebende Einheiten/Gebäude (z. B. unmittelbar nach einem Wipe)
  versehentlich die gesamte Zombie-Population löscht.

**Noch nicht vom Nutzer getestet** (kein laufender Godot-Editor in dieser
Umgebung verfügbar, nur über statische Checks verifiziert).

## Bekannte Grenzen (noch nicht gelöst)

- **Kein echtes Pathfinding** — Mauern werden zwar als Zwischenziel
  angegriffen, aber es gibt keinen Umweg um sie herum.
- **Kein Loot-Drop bei Zombie-Nest-Tod** (nur normale Zombies droppen,
  siehe "Zombie-Loot-Drop" oben — ein Nest hat keinen eigenen Loot).
- **Kein Wiederauftauchen eines zerstörten Nests an anderer Stelle** —
  fünf Nester (eines pro Stadt-Zone, siehe oben) entstehen einmalig bei
  Weltgenerierung, ein zerstörtes Nest kommt nicht zurück.
- **Horde-Nächte eskalieren nicht über die Spieldauer** — feste
  `HORDE_SIZE`/`HORDE_BRUTE_COUNT` jede Nacht, keine Steigerung mit der
  Zeit, wie in der ursprünglichen Vision ("Blutmond-Events alle paar
  Tage"). Der Tag/Nacht-Zyklus selbst ist seit diesem Feature umgesetzt
  (siehe [`docs/world.md`](world.md), "Tag/Nacht-Zyklus").
- **Catch-up für Zombie-Nest-Existenz/HP seit dem Kartenumbau gelöst**
  (`_catch_up_zombie_nest()`, siehe [`docs/world.md`](world.md)) — ein
  spät beitretender Peer sieht jetzt den korrekten HP-Stand jedes
  existierenden Nests. Ein bereits **zerstörtes** Nest bleibt aber
  weiterhin unsichtbar für den Catch-up-Mechanismus selbst (es existiert
  ja gar nicht mehr im Container, es gibt also nichts nachzuliefern) —
  kein offenes Problem, sondern der erwartete Zustand.

## Testen

Debug → Customize Run Instances → 2 → F5, Host + Join, "Spiel starten".
Trupp in die Nähe eines Zombies laufen lassen — sollte verfolgen und
angreifen, Trupp sollte automatisch zurückschlagen. Trupp in ein Gebäude
schicken (Suche startet) — Zombie sollte den Trupp währenddessen
ignorieren. Mauer zwischen Zombie und Trupp bauen — Zombie sollte die
Mauer statt des Trupps angreifen, bis sie zerstört ist.

**Zombie-Nest:** einige Minuten warten (`SPAWN_INTERVAL` 25s) — Zombiezahl
sollte langsam steigen. Wachposten nah genug am Nest (Kartenmitte) bauen
und mit Arbeiter besetzen — sollte automatisch auf das Nest feuern, dessen
Farbe sollte mit sinkendem HP dunkler werden, bei 0 HP verschwindet es
(`queue_free()`) und es spawnen keine neuen Zombies mehr.

**Horde-Nächte:** zum Testen `NIGHT_LENGTH`/`DAY_LENGTH` (`World.gd`)
temporär auf kleine Werte setzen (5 Minuten Echtzeit auf die erste Nacht
warten ist unpraktisch) — beim Nachteintritt sollte bei allen Spielern
"Die Nacht bricht an — eine Horde nähert sich!" erscheinen, kurz danach
zehn Zombies nahe am gewählten Ziel-Trupp auftauchen (nicht mehr an festen
Kartenecken, siehe oben) und geschlossen auf denselben Trupp zulaufen,
statt einzeln zu wandern. Licht/Himmel sollten sich dabei sichtbar zur
Nacht hin verdunkeln (siehe [`docs/world.md`](world.md),
"Tag/Nacht-Zyklus").
