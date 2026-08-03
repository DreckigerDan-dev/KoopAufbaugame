# Ladebildschirm

Punkt 27 der Gesamtliste (siehe persistentes Memory
`koopgame_next_steps_plan`) — Nutzer-Beobachtung (2026-08-01): "die map
braucht kurz zum rein laden", beim Wechsel von der Lobby ("Spiel
starten") zu `World.tscn` gab es bis dahin keinerlei Ladeanzeige, nur ein
kurzes Einfrieren während `get_tree().change_scene_to_file()`
(synchron) lief. Seit den mehreren Stresstest-Runden (aktuell 1750
Gebäude statt ursprünglich 350, siehe `docs/benchmarks.md`) dürfte das
spürbarer geworden sein.

## Umsetzung

- **`GameManager.change_state()`** schickt beim Wechsel zu
  `GameState.IN_GAME` jeden Peer erst zu
  `res://scenes/loading/LoadingScreen.tscn` statt direkt zu `World.tscn` —
  gilt für JEDEN Peer gleich (Host, Mitspieler, spät Beitretende über
  `_on_peer_connected()`), weil alle über denselben `change_state()`-Pfad
  laufen. `STATE_SCENES[GameState.IN_GAME]` bleibt als einzige Quelle für
  den `World.tscn`-Pfad erhalten, wird aber nur noch von
  `LoadingScreen.gd` gelesen, nicht mehr direkt von `change_state()`.
- **`LoadingScreen.gd`** lädt `World.tscn` ASYNCHRON im Hintergrund über
  `ResourceLoader.load_threaded_request()`/`load_threaded_get_status()`
  statt des synchronen `change_scene_to_file()` — dadurch bleibt die
  Ladebildschirm-Szene selbst reaktionsfähig (Fortschrittsbalken/Text),
  während die eigentlich schwere Arbeit (Szenen-Instanziierung,
  `World._ready()`) im Hintergrund läuft. Wechselt selbst erst zu
  `World.tscn` (`get_tree().change_scene_to_packed()`), sobald
  `ResourceLoader.THREAD_LOAD_LOADED` erreicht ist.
- **`THREAD_LOAD_FAILED`-Fallback:** fällt auf den alten synchronen
  `change_scene_to_file()` zurück statt eines Endlos-Ladebildschirms — kein
  bekannter Fehlerfall in der Praxis (`World.tscn` existiert immer), reine
  Absicherung.
- **Fortschrittsbalken** (`ProgressBar`, Standard-Bereich 0-100) zeigt den
  von `load_threaded_get_status()` gemeldeten echten Ladefortschritt
  (0.0-1.0, ×100).
- **Lade-Sprüche (`LOADING_TIPS`):** Nutzerwunsch ("was du aber machen
  kannst statt das ladevorgang steht paar lustige sprüche sowas wie der
  hamster beeilt sich oder bitcoin mining fast fertig oder heute schon
  genug getrunke") — rein kosmetischer, zufällig gewählter Spruch beim
  Aufruf des Ladebildschirms, KEIN Bezug zum tatsächlichen Fortschritt.
  16 feste Sprüche, Mix aus klassischen Ladebildschirm-Gags (Hamster,
  Bitcoin-Mining, Trinkerinnerung) und spielthematischen Varianten
  (Zombies/Bautrupp/Wachtürme).

## Bekannte Grenzen

- **Kein Multiplayer-Sync des Ladefortschritts** — jeder Peer lädt/zeigt
  seinen eigenen Fortschritt unabhängig, kein "warte auf langsamsten
  Peer"-Mechanismus. Passt zum bestehenden Muster (Welt-Generierung selbst
  ist ohnehin schon pro Peer eigenständig, siehe `docs/world.md`).
- **Nur EIN Sprung nötig, kein rotierender Sprüche-Wechsel während des
  Ladens** — bei sehr kurzen Ladezeiten würde ein Wechsel ohnehin kaum
  auffallen; falls Ladezeiten sich als deutlich länger herausstellen,
  wäre ein Timer für Sprüche-Rotation eine mögliche spätere Ergänzung.
- **Noch nicht vom Nutzer getestet.**
