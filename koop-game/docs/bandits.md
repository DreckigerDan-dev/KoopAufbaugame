# Banditen (echte NPC-Gegner)

Erklärt `scenes/entities/bandit/Bandit.gd` + `BanditHideout.gd` — echte
NPC-Fraktion statt der bisherigen reinen Loot-Mechanik ("Banditen-Restloot",
siehe [`scavenging.md`](scavenging.md), bleibt unverändert bestehen und ist
NICHT dasselbe Feature). Umgesetzt aus dem Ideen-Backlog
(`Infos/01 Architektur.md`, "Fraktionen") — Nutzerentscheidung 2026-08-04
nach Rückfrage, welches Backlog-Item als Nächstes dran ist.

Host-autoritativ, gleiches Grundmuster wie [`zombies.md`](zombies.md)
(`Zombie.gd`) — `Bandit._find_nearest_target()`/`_is_untouchable()` sind
bewusst 1:1 dupliziert statt geteilt (siehe [`building.md`](building.md),
"Bewusst dupliziert statt geteilt").

## Bewusste Unterschiede zu Zombies

- **Fernkampf statt Nahkampf** — `Bandit.ATTACK_RANGE := 6.0` (wie
  `Survivor.RANGED_ATTACK_RANGE`), bleibt auf Distanz stehen statt bis auf
  Nahkampf-Reichweite heranzulaufen. **Kein automatischer Gegenschaden** —
  anders als bei Zombie (das über `Survivor.is_sheltered()` den "wehrt sich
  automatisch"-Nahkampf auslöst) nimmt ein Bandit nur Schaden über aktives
  `order_attack()` oder Wachposten-Beschuss.
- **Keine Drei-Wege-Fraktion** — Bandits greifen nur Survivor/geclaimte
  Gebäude/Home-Bases an (`_find_nearest_target()`), genau wie Zombies.
  Bandits und Zombies ignorieren sich gegenseitig komplett (bewusst NICHT im
  Umfang dieser Stufe). Bandit ist deshalb NICHT in der Gruppe `"living"`
  (die Zombie-Zielsuche durchsucht) — sonst würden Zombies versehentlich
  Bandits angreifen.
- **`BanditHideout` ist gekappt, `ZombieNest` nicht** —
  `MAX_ACTIVE_BANDITS := 3` pro Hideout (World.gd prüft das selbst in
  `spawn_hideout_bandit()` über ein Duplikat
  `World.BANDIT_HIDEOUT_MAX_ACTIVE_BANDITS`, **bei Änderung beide Stellen
  anpassen**). Ein Camp soll sich wie eine begrenzte Garnison anfühlen,
  kein endloser Nachschub wie beim Zombie-Nest.
- **Hideout-Zerstörung ist permanent + gibt Bonus-Loot** — passt zum
  "Loot ist endlich"-Prinzip (`Infos/01 Architektur.md`, "Scavenging").
  Einzel-Kill droppt die kleinere `BANDIT_KILL_LOOT_TABLE`
  (ammo/weapon/armor/helmet, thematisch wie das Waffenladen-Gebäude), das
  Klären eines ganzen Hideouts gibt zusätzlich den deutlich größeren
  `BANDIT_HIDEOUT_CLEAR_LOOT`-Batzen direkt an den Verursacher (`World.
  grant_bandit_kill_loot()`/`grant_bandit_hideout_cleared_loot()`).

## Platzierung

`World.BANDIT_HIDEOUT_COUNT := 3` — bewusst klein (wenige, aber gefährliche
Camps statt einer flächendeckenden dritten Fraktion). Über
`_random_wilderness_position()` verteilt (gleiches Muster wie
Bäume/Autowracks/Steinhaufen), meidet Stadt-Zonen UND andere Hideouts
(`"bandit_hideout"` ist Teil der Gruppen-Liste in
`_is_far_enough_from_others()`). Läuft über den direkten
`bandit_hideout_spawner.spawn()` statt der `_local()`-Massen-Variante (siehe
`_create_building_local()`) — bei nur 3 Instanzen lohnt sich die
Netzwerklast-Optimierung nicht, gleiches Muster wie das Zombie-Nest
(`zombie_nest_spawner.spawn()` in `_generate_city_zone()`).

## Klick-Angriff + Wachposten-Autoverteidigung

`World._select_at()` behandelt Klicks auf `"bandit"`/`"bandit_hideout"`
genau wie `"zombie"`/`"zombie_nest"` (Angriffsbefehl, Gruppen-Ziel-
Verteilung über `_nearby_enemies()`/`_nearest_enemy()`, beide um Bandits
erweitert). `GuardPost._find_nearest_zombie()` durchsucht zusätzlich zu
Zombie-Gruppen auch `"bandit"`/`"bandit_hideout"` — reine lineare
Gruppenabfrage statt einer Erweiterung des Zombie-Spatial-Grids
(`World.zombies_near()`), weil die Bandit-Population klein bleibt und sich
das nicht lohnt.

## Netzwerk-Sync

Gebündeltes RPC (`World._sync_bandits_batch()`/`_apply_bandit_batch()`),
1:1 dasselbe Muster wie `_sync_zombies_batch()` — bei der kleinen
Bandit-Population kein Performance-Zwang, aber Konsistenz statt eines
zweiten, abweichenden Sync-Wegs.

## Karte/Minimap

`MapView.gd`/`Minimap.gd` zeichnen Bandits/Hideouts in einer eigenen
Braun/Ocker-Farbfamilie (`BANDIT_COLOR`/`BANDIT_HIDEOUT_COLOR`), auf den
ersten Blick von Zombie-Rot unterscheidbar.

## Bewusste Lücke: Bandits werden nicht gespeichert

`_collect_save_data()`/`_load_game_state()` sichern NUR die Hideouts selbst
(Position/HP), NICHT die einzelnen, aktuell lebenden Bandits — analog der
akzeptierten Lücke bei Baustellen-Trupps
([`building.md`](building.md), "Baustellen", "Bewusste Lücke"). Nach dem
Laden füllt sich ein Hideout einfach über `SPAWN_INTERVAL` (30s) wieder von
selbst auf — kein Fortschrittsverlust bei der Sache, um die es wirklich
geht (das Hideout klären), nur ein kurzzeitig leereres Camp direkt nach dem
Laden. Catch-up für spät beitretende Peers (schon laufende Partie) ist
davon NICHT betroffen — `_catch_up_bandit()` funktioniert normal, die
Lücke betrifft ausschließlich Speichern/Laden.

## Noch nicht vom Nutzer getestet

Komplettes Feature, siehe `docs/pending-tests.md`.
