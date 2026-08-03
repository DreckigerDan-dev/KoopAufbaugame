## Sechs Balance-Fixes aus dem Mechaniken-Bericht umgesetzt (2026-08-04)

Direkte Reaktion auf die Kernbefunde aus `docs/mechanics-review.md`
("kein Sieg-/Niederlage-Zustand", "Zombie-Bedrohung unbegrenzt vs.
Trupp-Kapazität strikt endlich"). Nutzer hat vorab per Rückfragen die
Details festgelegt (siehe `docs/base.md`, `docs/recruitment.md`,
`docs/zombies.md`, `docs/world.md`, `docs/survivor.md` für die einzelnen
Abschnitte):

1. **Home-Base zerstörbar** (`HomeBase.MAX_HP := 500`) + **Game-Over/
   Rettungsmechanik**: verlorener Spieler bekommt ein Panel ("Hilfe
   anfragen"/"Aufgeben"), Mitspieler kann einen eigenen Trupp zum
   golden eingefärbten **Base-Erstellen-Trupp** machen und schicken —
   schaltet `request_choose_start_base()` wieder frei (praktisch ein
   Neustart). Ohne Hilfe: echter Game-Over-Bildschirm (Neu starten/
   Hauptmenü). Ruine bleibt liegen, normal abreißbar. Neue Szene
   `GameOverUI.tscn`/`.gd`. Details: `docs/base.md`, "Zerstörbarkeit +
   Rettungsmechanik".
2. **Rekrutierung erweitert**: 15 % Zufallschance bei jedem normalen
   Gebäude-Durchsuchen (`Survivor.LOOT_RECRUIT_CHANCE`) + neues
   "Schutzsuchende"-Ereignis (periodisch, gedeckelt auf 2 Trupps/Spieler
   über diesen Kanal). Details: `docs/recruitment.md`, "Erweiterte
   Rekrutierung".
3. **Zombie-Bedrohung skaliert mit Spieleranzahl**: Horde-Größe ×
   Spieleranzahl, `MAX_ZOMBIES` 200→400. Details: `docs/zombies.md`,
   "Horde-Nächte".
4. **Pause (nur Host)**: `World._game_paused`, Button im Pause-Menü,
   "PAUSIERT"-Anzeige für alle. Jedes Entity-Script mit eigenem
   `_process()` fragt das selbst ab (kein zentraler `process_mode`-Umbau).
   Details: `docs/world.md`, "Pause".
5. **Mehr Start-Ressourcen** (Baurohstoffe/Überlebensgüter deutlich
   angehoben) + **Rohstoffe auch in Stadt-Zonen** (`RESOURCES_PER_CITY_ZONE
   := 6`, nicht mehr nur Wildnis). Details: `docs/base.md`/`docs/world.md`.
6. **Hunger-Verfall verlangsamt** (`HUNGER_DECAY_RATE` 1.5→0.3/s, analog
   zum Müdigkeit-/Moral-Fix vom selben Tag). Details: `docs/survivor.md`,
   "Hunger + Essen".

Nebenbei aufgeräumt: `docs/base.md`/`docs/recruitment.md` hatten stark
veraltete Abschnitte (alte 150er-Testwerte, "zwei Trupps am Start" statt
der längst aktuellen 5) — an den berührten Stellen korrigiert.

**Noch nicht vom Nutzer getestet — deutlich größerer Umfang als die
bisherigen Einzel-Fixes, braucht gründliches Gegentesten** (siehe
`docs/pending-tests.md`, neuer Abschnitt "Balance-Fixes").

## Mechaniken-/Balance-Bericht (2026-08-04)

Nutzerwunsch: nach dem Korrektheits-Durchgang einschätzen, ob die
Mechaniken als Ganzes Sinn ergeben, plus Bericht zu Spieldauer/Statistiken/
Spielablauf. Reine Code-Analyse (Konstanten/Formeln), kein echter
Spieltest. Kernbefund: **kein Sieg-/Niederlage-Zustand im Code**, UND die
Zombie-Bedrohung wächst zeitlich unbegrenzt (bis Deckel 200), während die
Trupp-Kapazität pro Spieler strikt endlich ist (Start 5, einmalig +1 auf
max. 6, Permadeath, keine laufende Rekrutierung) — strukturell eine
Abnutzungskurve statt eines stabilen Gleichgewichts. Volle Zahlen/
Zeitskala/Session-Hochrechnung in [`mechanics-review.md`](mechanics-review.md)
(neue Datei).

## Korrektheits-Durchgang, Runde 2: ganze Codebase (2026-08-04)

Fortsetzung des Korrektheits-Durchgangs (siehe unten) — nach den drei
neuesten Systemen jetzt der Rest: `Zombie.gd`, `Vehicle.gd`, `Wall.gd`,
Speicherstand-Rundlauf, Crafting/Forschung/Handel, Zonen/Claim. Zwei
weitere echte, wirtschaftlich relevante Bugs gefunden und behoben:

- **Doppelte Zombie-Loot-Vergabe möglich:** `Zombie.take_damage()` prüfte
  `hp <= 0` bei JEDEM Aufruf neu, ohne zu merken, ob der Tod schon
  verarbeitet wurde. Trifft z. B. ein Wachposten UND ein Survivor-
  Gegenschaden denselben Zombie im selben Frame tödlich (`queue_free()`
  entfernt die Node erst am Frame-Ende, nicht sofort), hätte
  `grant_zombie_loot()` zweimal gefeuert — doppelter Ressourcen-Ertrag für
  einen einzigen Kill. Neue `_dead`-Sperre verhindert das.
- **Doppelter Ernte-Ertrag möglich:** `order_harvest()` hat (anders als
  das automatische Markier-System) KEINEN "schon zugewiesen"-Check —
  mehrere Bautrupps können absichtlich oder versehentlich auf denselben
  Baum/dasselbe Autowrack angesetzt werden. `Survivor._process_harvest()`
  prüfte den Erfolg (`hp <= 0`) erst NACH dem eigenen Schlag, ohne vorher
  zu prüfen, ob das Ziel bereits (von einem anderen, im selben Frame
  früher verarbeiteten Trupp) gefällt wurde — ein zweiter Trupp hätte
  dadurch ein zweites Mal den vollen Ertrag gutgeschrieben bekommen.
  Jetzt: Bail-out, sobald das Ziel beim eigenen Cooldown-Tick schon bei
  0 HP steht.
- **`HomeBase.unlocked_recipes` fehlte komplett im Speicherstand** —
  `_collect_save_data()`/`_load_game_state()` haben Ressourcen und
  Lagerkapazität gesichert, aber nie die erforschten Rezepte/Ausbaustufen.
  Da Forschungsbücher beim Erforschen verbraucht werden, hätte ein
  Speichern+Laden jede schon erforschte Freischaltung DAUERHAFT
  rückgängig gemacht, ohne das Buch zurückzugeben — permanenter
  Fortschrittsverlust. Jetzt mitgespeichert/wiederhergestellt.

Sonst keine weiteren Funde — `Vehicle.gd`/`Wall.gd`/Crafting/Handel/
Zonen-Claim-Logik sind bereits korrekt gegen Mehrfachausführung
abgesichert (sequentielle RPC-Verarbeitung, Zustand wird vor dem
eigentlichen Effekt erneut geprüft).

## Korrektheits-Durchgang, Runde 1: drei neueste Systeme (2026-08-04)

Nutzer-Ziel: spielbare Version nächste Woche, Assets macht der Nutzer
selbst und liefert sie später (siehe persistentes Memory
`koopgame_playable_goal_next_week`) — Ordner-Cleanup/`World.gd`-
Aufsplitten explizit zurückgestellt, Priorität liegt auf Korrektheit.
Erster Durchgang über die drei neuesten Systeme (Bau-Markier-Modus,
Formation, Ladebildschirm):

- **`finish_construction()`-Fix:** `has_open_construction` wird jetzt
  sofort zurückgesetzt statt sich auf `queue_free()`-Timing zu verlassen
  — verhindert eine theoretische doppelte Zielstruktur-Erzeugung.
- **`GuardPost.built`-Catch-up-Lücke behoben** (war schon länger in
  `docs/building.md` als bekannte Grenze vermerkt, nie behoben):
  `_catch_up_guard_post()` schickt `built` nie mit — ein spät
  beitretender Peer sah jeden fertigen Wachposten dauerhaft im
  "noch im Bau"-Gelb. `_create_guard_post()` konnte das Feld schon
  (fürs Speicherstand-Laden), jetzt auch beim Catch-up verdrahtet.

## Punkt 27: Ladebildschirm (2026-08-04)

Letzter noch offener Punkt der festen Liste. `GameManager.change_state()`
schickt beim Wechsel zu `GameState.IN_GAME` jeden Peer jetzt erst zu einer
neuen `LoadingScreen.tscn` statt direkt zu `World.tscn` — die lädt die
Welt ASYNCHRON im Hintergrund (`ResourceLoader.load_threaded_request()`)
statt des vorherigen synchronen `change_scene_to_file()`, das für ein
kurzes Einfrieren sorgte. Fortschrittsbalken zeigt echten Ladefortschritt,
dazu ein zufälliger, rein kosmetischer Lade-Spruch (Nutzerwunsch: "paar
lustige sprüche sowas wie der hamster beeilt sich oder bitcoin mining
fast fertig oder heute schon genug getrunke") aus 16 festen Optionen.
Details in [`loading.md`](loading.md). Noch nicht vom Nutzer getestet.
Damit sind alle 29 Punkte der aktuellen Liste umgesetzt (siehe
persistentes Memory `koopgame_next_steps_plan`).

## Punkt 29, vierte Korrektur: Leere schwarze Box oben links (2026-08-04)

Nach dem bestätigten Ressourcen-Panel-Umbau fiel dem Nutzer eine leere
schwarze Box oben links auf ("nur ne leere schwarze box, kein text
drauf") — das bei der ersten Korrektur eingeführte `HUD/InfoPanel` war
dauerhaft sichtbar, obwohl der dahinterliegende `hud_label`-Text seit dem
HUD-Aufräumen vom 2026-08-03 die meiste Zeit komplett leer ist. Behoben:
Panel-Sichtbarkeit folgt jetzt, ob tatsächlich Inhalt da ist. Details in
[`world.md`](world.md), "UI-Überarbeitung Runde 2", "Vierte Korrektur".
**Vom Nutzer bestätigt:** "passt ist weg" — Punkt 29 damit komplett
abgeschlossen.

## Punkt 29, dritte Korrektur: Text lief aus dem Bildschirm (2026-08-04)

Nutzer: "wird besser die schrifft geht aber aus dem bildschirm raus" —
Kategorie-Zeilen ohne Zeilenumbruch liefen bei mehreren Ressourcen pro
Kategorie seitlich über den Bildschirmrand hinaus. Kapazität nicht mehr
pro Ressource wiederholt (kürzere Zeilen), plus `autowrap_mode = 3` auf
allen vier Kategorie-Labels als Absicherung, Panel/Tab-Höhe entsprechend
angepasst. Details in [`world.md`](world.md), "UI-Überarbeitung Runde 2",
"Dritte Korrektur". **Vom Nutzer bestätigt:** "deutlich besser als
vorher" — Ressourcen-Panel-Umbau (Punkt 29) damit abgeschlossen.

## Punkt 29, zweite Korrektur: Ressourcen-Panel entschlackt (2026-08-04)

Nutzer nach der Überlappungs-Korrektur: "wird besser aber zu viel
ressourcen am besten nur die bau materialien das mit waffen bücher etc.
soll dann in ein unter tab". Baurohstoffe bleiben dauerhaft sichtbar,
Überleben/Ausrüstung/Forschungsbücher wandern in einen kleinen
`TabContainer` darunter (nur eine Kategorie gleichzeitig sichtbar). Details
in [`world.md`](world.md), "UI-Überarbeitung Runde 2", "Zweite Korrektur".
Noch nicht getestet.

## Punkt 29 Korrektur: UI-Überlappung durch falsche Basis-Auflösung (2026-08-04)

Nutzer schickte Screenshot (`bilder/ui 1.PNG`) des ersten UI-Wurfs:
"irgendwie schaut das nicht so wie gewünscht aus" — Ressourcen-Text und
Bau-Buttons lagen sichtbar übereinander. Ursache: UI-Anker laufen im
projektweiten Basis-Viewport (Godot-Standard 648px Höhe, kein
`window/size/viewport_height` gesetzt), NICHT in der tatsächlichen
Fensterauflösung — das auf 620px vergrößerte `MainTabsUI`-Panel nahm damit
fast den ganzen Bildschirm ein und überlappte mit dem neu nach oben links
verschobenen Ressourcen-Panel. Korrektur: Ressourcen-Panel bleibt oben
RECHTS (wie ursprünglich), `MainTabsUI`-Panel-Höhe auf ein Maß reduziert,
das innerhalb 648px tatsächlich Platz lässt (404→454px statt 404→604px).
Details in [`world.md`](world.md), "UI-Überarbeitung Runde 2", Abschnitt
"Korrektur nach erstem Screenshot-Test". Noch nicht erneut vom Nutzer
getestet.

## Punkt 29: UI-Überarbeitung Runde 2 (2026-08-04)

Nutzer schickte Referenz-Screenshot (Infection Free Zone, `bilder/ui.PNG`)
mit "vielleicht paar stats vertauschen ... damit es nicht wie eine Kopie
aussieht" und danach "mach erstmal wie du meinst, wir müssen später eh hin
und her wechseln, nur damit man eine Richtung bekommt" — als erster,
bewusst nicht finaler Wurf umgesetzt: Ressourcen-Panel verliert die
Zwei-Tabs-Aufteilung (siehe Punkt 14-Nachbarabschnitt in `world.md`)
zugunsten kompakter Einzeiler pro Kategorie, wandert von oben rechts nach
oben LINKS (bewusst seitenverkehrt zur Referenz). Auswahl-/Status-Anzeige
bekommt erstmals einen Panel-Hintergrund, rutscht darunter. `MainTabsUI`-
Panel vergrößert (behebt das direkt zuvor gemeldete "Baustellen-Liste
nicht so sichtbar"). Details in [`world.md`](world.md), "UI-Überarbeitung
Runde 2". Noch nicht vom Nutzer gesehen/getestet — explizit als Richtung
angelegt, weitere Iterationsrunden erwartet.

## Map-Stresstest nochmal hochgeschraubt (2026-08-04)

Nutzerwunsch ("schraub einfach hoch ich teste dann") — weitere Runde
desselben Benchmark-Stresstests von 2026-08-03: `BUILDINGS_PER_LARGE_ZONE`/
`_SMALL_ZONE` 300/150→500/250 (Summe 1750 statt 1050),
`TREES_PER_FOREST_ZONE` 80→150, `TREES_TOTAL`/`CAR_WRECKS_TOTAL`/
`STONE_PILES_TOTAL`/`BRICK_PILES_TOTAL` jeweils verdoppelt
(800/320/400/400). Reiner Stresstest, keine Balancing-Entscheidung.
Diesmal zusätzlich relevant, weil seit dem Bau-Markier-Modus (Punkt 28)
JEDES Gebäude ein eigenes `_process()` hat (vorher komplett passiv) —
Performance noch nicht gemessen, Nutzer testet selbst. Details/offene
Fragen in [`benchmarks.md`](benchmarks.md).

## Balancing: Müdigkeit/Moral-Verfall verlangsamt (2026-08-04)

Direktes Nutzer-Feedback nach dem ersten Test von Punkt 28: "das mit müde
und moral geht zu schnell runter ich lauf zu einem gebäude und habe beides
auf 0 sollte langsamer ablaufen". `Survivor.FATIGUE_DECAY_RATE` 0.8→0.15/s,
`MORALE_DECAY_RATE` 0.4→0.075/s (gleiches 2:1-Verhältnis beibehalten) —
vorher beide schon nach 125s/250s komplett aufgebraucht (kürzer als ein
Erkundungslauf), jetzt ~11/~22 Minuten bis 0. Details in
[`survivor.md`](survivor.md), "Bedürfnisse: Müdigkeit + Moral". Zweites
Feedback aus demselben Test: die neue Baustellen-Liste im Bauen-Tab ist
"nicht so sichtbar" — laut Nutzer nicht dringend ("kann man später
anpassen"), vorgemerkt für Punkt 29 (UI-Überarbeitung Runde 2).

## Punkt 28: Bau-Markier-Modus mit zuweisbaren Bautrupps (2026-08-04)

Punkt 27 (Ladebildschirm) auf Nutzerwunsch übersprungen ("lassen wir
erstmal"), direkt weiter mit Punkt 28 — laut Nutzer der wichtigste
Feature-Kandidat aus der Planungssession. Umbau des bisherigen
Sofort-Ausbaus (`request_upgrade_building()`) zu einem echten
RTS-Bauauftrag: Gebäude claimen → Ziel-Ausbaustufe festlegen (Lager/
Krankenstation/Werkstatt/Schlafraum) → offener Bauauftrag statt sofortiger
Fertigstellung → beliebig viele Bautrupps zuweisen (Klick auf die
amberfarbene Baustelle mit ausgewählten Trupps ODER "Trupp zuweisen"-Button
in der neuen Baustellen-Liste im Bauen-Tab) → Baufortschritt läuft über
Zeit, Tempo skaliert linear mit Anzahl zugewiesener Trupps. Plus
Stornieren mit Rückerstattung und volle Speicherstand-/Catch-up-Persistenz
für Zieltyp+Fortschritt (nicht für die zugewiesenen Trupps selbst — die
gehen bei Rejoin/Laden verloren, müssen neu zugewiesen werden). Details in
[`building.md`](building.md), "Baustellen". Registrierung/Abziehen der
Bautrupps nutzt exakt das bestehende `GuardPost`-Wachposten-Worker-Muster
mit (`Survivor._stationed_at`/`_unstation()`), dadurch kein neuer Code fürs
Abziehen nötig. Noch nicht vom Nutzer getestet — siehe
`docs/pending-tests.md`. Weiter mit Punkt 29 (UI-Überarbeitung Runde 2)
oder zurück zu Punkt 27, je nach Nutzerwunsch.

## Punkt 26: Formation natürlicher (2026-08-04)

Erster Schritt der neuen Feature-Phase (Punkte 26-29, siehe Planungssession
vom 2026-08-03 Abend). Trupps liefen trotz Kreis-Formation im
Gleichschritt los ("truppen laufen auf einer linie sollen er natürlicher
laufen") — behoben über eine kleine, einmalig zufällige Geschwindigkeits-
Varianz pro Trupp (`Survivor.MOVE_SPEED_VARIANCE := 0.08`) plus einen
index-abhängigen, gestaffelten Bewegungsstart bei Gruppenbefehlen
(`World.MOVE_STAGGER_STEP := 0.15`, neuer `start_delay`-Parameter in
`order_move()`). Details in [`commander.md`](commander.md), "Formation
natürlicher". `Vehicle.order_move()` musste denselben Parameter
(ungenutzt) mitbekommen, weil derselbe generische RPC-Aufruf auch
Fahrzeuge trifft. Noch nicht vom Nutzer getestet. Weiter mit Punkt 27
(Ladebildschirm).

## UI-Überlappung behoben: Trupp-Detailfenster als fünfter Tab (2026-08-03)

Nutzer-Report: "die ui sind übereinander das truppen ui und alles andere",
danach explizit gewünschte Lösung: "am besten alles in eigene tabs". Das
bis dahin frei positionierte `UnitDetailUI`-Panel (unabhängig von
`MainTabsUI` verankert, konnte bei kleineren Fensterhöhen mit ihm
überlappen) ist jetzt komplett entfernt — sein Inhalt läuft als fünfter
Tab "Trupp" im gemeinsamen `MainTabsUI`-TabContainer, `set_tab_hidden()`
statt eigenem `visible`-Toggle (gleiches Muster wie der "Herstellen"-Tab).
Strukturell keine Überlappung mehr möglich. Ausführlich in
[`world.md`](world.md), "Fünfter Tab: Trupp-Detailfenster". **Noch nicht
vom Nutzer getestet.**

## Mehr Gebäude, weniger Startressourcen, 5 Start-Trupps, Ressourcen-Panel-Tabs (2026-08-03, Sammel-Feedback)

Vier kleinere Nutzerwünsche in einem Zug:

- **Mehr Gebäude:** `BUILDINGS_PER_LARGE_ZONE`/`BUILDINGS_PER_SMALL_ZONE`
  von 60/30 auf 100/50 angehoben (350 statt 210 Gebäude gesamt) — reine
  Erhöhung der aus den ohnehin vorhandenen Straßen-Raster-Plätzen
  ausgewählten Teilmenge, keine Geometrie-/Asset-Änderung nötig.
- **Startressourcen zurückgebaut:** die seit 2026-08-01 testhalber auf
  150/Art gesetzten Werte (siehe [[koopgame_temp_test_resources]]) sind
  wieder auf die echte Balance zurück (`HomeBase.START_RESOURCES`,
  `BASE_STORAGE_CAPACITY` 300 → 150).
- **5 Start-Trupps statt 2:** `World.START_SURVIVOR_COUNT := 5`,
  `request_choose_start_base()` spawnt jetzt eine ganze Reihe entlang der
  `sideways`-Achse statt nur zwei feste Positionen.
- **Ressourcen-Panel in zwei Tabs** ("Rohstoffe"/"Ausrüstung") statt vier
  Kategorien dauerhaft untereinander — der schon am 2026-08-01
  zurückgestellte Nutzerwunsch ist jetzt umgesetzt, siehe
  [`world.md`](world.md), "Ressourcen-Panel kategorisiert".

**Noch nicht vom Nutzer getestet.**

## Blutmond-Kalender-Eskalation (2026-08-03, Punkt 21 der Gesamtliste)

Vierter der vier Vision-Koop/Bedrohungs-Punkte dieser Arbeitsphase. Die
bestehenden Horde-Nächte feuern schon jede Nacht mit fester Stärke — jetzt
kommt die von der Vision zusätzlich beschriebene kalenderbasierte
STEIGERUNG dazu: jede 5. Nacht (`BLOOD_MOON_INTERVAL_DAYS`, alle ~25
Minuten Echtzeit) ist ein "Blutmond" mit 3× so vielen Zombies (30 statt 10)
und 5× so vielen Brutes (10 statt 2), eigener Vorwarnung, plus rötlich
getöntem Nachthimmel als visuellem Signal. `World._day_count` (läuft lokal
auf jedem Peer, catch-up-/speicherstand-fähig) trägt die Kalenderzählung.
Ausführlich in [`zombies.md`](zombies.md), "Blutmond-Kalender-Eskalation".
**Noch nicht vom Nutzer getestet** — Erst-Test dauert mindestens 25 Minuten
Echtzeit bis zur ersten Blutmond-Nacht.

## Gegenseitige Verteidigung/Hilfe (2026-08-03, Punkt 20 der Gesamtliste)

Dritter der vier Vision-Koop-Kanäle. Mechanisch ging Helfen bei einer
fremden Basis schon vorher (keine Zonen-/Besitzer-Sperre bei
`order_attack()`/`order_move()`) — es fehlte nur die Sichtbarkeit: jetzt
löst ein Zombie-Treffer auf einen Survivor/Vehicle/geclaimtes Gebäude/eine
Wand (gedrosselt, `SOS_COOLDOWN := 30.0` pro Opfer) einen Alarm an alle
ANDEREN Spieler aus — Statusmeldung + 20s pulsierender roter Ring auf
Minimap/Kartenansicht, sichtbar auch außerhalb des selbst erkundeten
Gebiets (Fog of War wird dafür bewusst überstrahlt). Ausführlich in
[`world.md`](world.md), "Gegenseitige Verteidigung/Hilfe". **Noch nicht
vom Nutzer getestet.**

## Differenzierte Fahrzeugtypen (2026-08-03, Punkt 19 der Gesamtliste)

Bisher ein einziger Fahrzeugtyp mit festen Werten — jetzt drei Archetypen
(Auto/Motorrad/LKW, `Vehicle.VEHICLE_STATS`) mit unterschiedlichem
HP/Tempo/Lärmradius/Größe/Farbe, zufällig pro Spawn-Slot gewählt. Bewusst
OHNE Trage-Kapazitäts-Bonus (passt nicht sauber in die aktuelle
Architektur — ein fahrender Trupp kann während der Fahrt gar nicht
looten). Ausführlich in [`vehicle.md`](vehicle.md), "Differenzierte
Fahrzeugtypen". **Noch nicht vom Nutzer getestet**, Checkliste in
[`pending-tests.md`](pending-tests.md).

# KoopGame — Session-Zusammenfassung (Stand: 2026-07-31)

Diese Datei ist ein Einstiegspunkt für eine neue Chat-Session — kurzer
Überblick, was steht, was offen ist, wo man weiterliest. Für Details immer
auf die verlinkte Einzeldoku verweisen, dort steht das jeweilige "wie und
warum" (siehe `ARCHITECTURE.md`, Abschnitt "Doku-Konvention" — für jedes
System gibt es eine eigene `docs/<system>.md`).

## Der 3D-Umstieg ist abgeschlossen

Das Spiel ist jetzt **komplett 3D** (`Node3D`/`Vector3`) — der schrittweise
Umstieg von der ursprünglichen 2D-Fassung ist fertig verkabelt. Der
vollständige Migrationsverlauf (jeder Zwischenschritt, jeder unterwegs
gefundene Bug samt Diagnose) steht in [`3d-migration.md`](3d-migration.md)
als historisches Protokoll; für den **aktuellen** Code-Stand sind die
System-Docs unten die richtige Quelle.

**Was sich strukturell geändert hat:**
- `scenes/world/World.tscn`/`World.gd` sind jetzt 3D (100×100 Karte, acht
  Platzhalter-Gebäude), ersetzen die alte 2D-Testkarte komplett.
- `Commander.gd`/`.tscn` sind entfallen — Kamera, Auswahl, Kontrollgruppen,
  Bewegungs-/Bau-Befehle laufen direkt in `World.gd` (Begründung:
  Kamera-Zustand muss nie über das Netzwerk repliziert werden, siehe
  [`commander.md`](commander.md), jetzt ein reiner Retirement-Hinweis).
- Alle Entities (`Survivor`, `Zombie`, `HomeBase`, `GuardPost`, `Building`)
  sind 3D (`StaticBody3D` + `Mesh`/`CollisionShape3D` statt
  `Node2D`/`ColorRect`).
- **Rekrutierung** (siehe [`recruitment.md`](recruitment.md)) war zunächst
  eine Regression aus dem Umstieg, ist inzwischen aber 1:1 nach dem
  2D-Original wieder eingebaut: `Building2` hat `has_survivor = true`, ein
  vollständig durchsuchter Fund spawnt einen zusätzlichen Survivor.
- **Kein Backup/Git** für diesen Umstieg angelegt (auf expliziten
  Nutzerwunsch) — der vorherige 2D-Stand ist nicht wiederherstellbar.

## Systeme

| System | Doku | Kurzfassung |
|---|---|---|
| Networking | [`networking.md`](networking.md) | Host-and-Play, ENet, Lobby mit Spielerliste (dimensionsunabhängig, unverändert) |
| World | [`world.md`](world.md) | 5000×5000-Karte, prozedurale Zonen-Generierung, Kamera/Auswahl/Kontrollgruppen (frühere Commander-Rolle), Spawning, Minimap + Vollbild-Kartenansicht |
| Home-Base + Ressourcen | [`base.md`](base.md) | Nahrung/Holz/Metall/Stein/Ziegel/Medizin/Munition pro Spieler, eigenes Ressourcen-Panel |
| Survivor | [`survivor.md`](survivor.md) | Bewegen (Wegpunkt-Schlange), HP/Permadeath, Heilung, Hunger, Stationieren, Waffen-/Rüstungssystem |
| Scavenging | [`scavenging.md`](scavenging.md) | Gebäude durchsuchen, Loot, endlicher Loot, Trage-Kapazität + automatischer ungeschützter Rückweg |
| Zombies | [`zombies.md`](zombies.md) | Wandern, Verfolgen, beidseitiger Kampf, Lärm-System |
| Bauen | [`building.md`](building.md) | Wachposten/Krankenstation/Werkstatt/Außenposten, Baumodus + Weltklick, Arbeiter-Zuweisung per UI, Platzierungs-Preview |
| Mauern + Tore | [`walls.md`](walls.md) | Zweiter/dritter Bautyp, blockieren echt (Mauer jeden, Tor nur Fremde/Zombies), Zombies durchbrechen sie |
| Rekrutierung | [`recruitment.md`](recruitment.md) | `Building2` gibt bei fertiger Suche einen zusätzlichen Survivor, 1:1 wie im 2D-Original |
| Fahrzeug | [`vehicle.md`](vehicle.md) | Zwei fest platzierte Fahrzeuge, einsteigen + fahren, schneller/lauter als ein Trupp, kein eigener Angriff |
| Zonen/Claiming | [`zones.md`](zones.md) | Geplünderte Gebäude claimen erweitert die Bauzone; Start-Basis-Wahl ersetzt feste Kartenecken |
| Commander | [`commander.md`](commander.md) | Retired — Rolle jetzt in `world.md` |
| 3D-Umstieg | [`3d-migration.md`](3d-migration.md) | Historisches Protokoll des gesamten Migrationsverlaufs |
| Speichern/Laden | [`save_load.md`](save_load.md) | Host-seitiger Spielstand, ein Slot, PauseMenu (Escape) als Ausstiegspunkt |
| Einstellungen | [`settings.md`](settings.md) | Vollbild + Master-Lautstärke, `SettingsMenu`-Overlay in Hauptmenü + PauseMenu |
| Performance-Benchmarks | [`benchmarks.md`](benchmarks.md) | Reines Messprotokoll (F9-Stresstest-Werte), Fix-Begründungen bleiben in `zombies.md`/`world.md` |
| Offene Tests | [`pending-tests.md`](pending-tests.md) | Abhakbare Checkliste pro Feature (Teilschritte statt einer pauschalen "noch nicht getestet"-Zeile) |

## Offene Punkte für den nächsten Chat

**Getestet und bestätigt:** kompletter echter Spielfluss (F5 → `MainMenu` →
Host/Join → `Lobby` → "Spiel starten" → 3D-`World.tscn`) funktioniert.
**Wichtiger Stolperstein dabei:** `World.tscn` ist anders als die frühere
`World3DTest.tscn` **nicht** mehr eigenständig per F6 testbar — F6 startet
immer nur die gerade fokussierte Szene, ohne `MainMenu`/`Lobby` davor,
`NetworkManager.players` bleibt dann leer und nichts Eigenes spawnt (sah
zunächst wie ein Bug aus: "keine eigenen Trupps", Zombies liefen trotzdem,
weil die unabhängig vom Host-Status spawnen). Immer **F5** benutzen.

**Drei Bugs beim Testen der Rekrutierung gefunden und behoben** (in
`World.gd`, `_select_at()`):
1. Such-Ziel lag auf `building.global_position` (Gebäude-Origin, mitten im
   Mesh) statt auf dem Raycast-Treffpunkt — Trupp war während der Suche
   unsichtbar.
2. Gruppenbefehle schickten alle ausgewählten Einheiten auf denselben
   Zielpunkt — sie clippten ineinander; behoben mit `_formation_offset()`
   (Raster, siehe `docs/survivor.md`, "Bekannte Grenzen"). **Bestätigt
   getestet:** Trupps laufen nicht mehr ineinander.
3. Nachdem Bug 1 behoben war: Y-Koordinate des Suchziels kam vom
   Raycast-Treffpunkt, der je nach getroffener Fläche (Seite vs. Dach)
   stark schwankt — Trupp lief sichtbar aufs Dach. Behoben mit fester
   `SURVIVOR_GROUND_Y` (siehe `docs/scavenging.md`). **Noch nicht erneut
   getestet** nach diesem dritten Fix.

Alle drei Bugs (unsichtbar im Gebäude, Gruppen-Clipping, Dach-Bug) vom
Nutzer nach dem Fix bestätigt getestet — keine offenen Punkte mehr dazu.

**Neues Feature ergänzt:** Trupps sind jetzt vor Zombies geschützt, sobald
sie an einem Gebäude ankommen und zu durchsuchen beginnen ("im Haus") —
`Survivor.is_sheltered()`/`_sheltered` + `Zombie._is_sheltered()`, siehe
`docs/zombies.md`, "Schutz beim Durchsuchen". Nur der Hinweg ist
ungeschützt; nach Suchende bleibt der Schutz bewusst bestehen, solange der
Trupp am Gebäude stehen bleibt, und endet erst mit dem nächsten Befehl
(Bewegen/Suchen/Stationieren/Stopp).

**Erster Durchlauf getestet und korrigiert:** Ursprünglich war der Schutz
an `_searching` gekoppelt und endete deshalb genau dann, wenn der Loot
fertig eingesammelt war — Zombies konnten den Trupp dann sofort wieder
angreifen, obwohl er sich nicht wegbewegt hatte. Auf Nutzerwunsch
entkoppelt: eigenes `_sheltered`-Flag, das über das Suchende hinaus
bestehen bleibt und erst mit dem nächsten Befehl endet. **Bestätigt
getestet:** Trupp bleibt nach dem Looten geschützt stehen, Zombie greift
erst wieder an, sobald der Trupp per neuem Bewegungsbefehl losläuft. Kein
offener Punkt mehr dazu.

**Platzierungs-Preview beim Bauen ergänzt:** `$BuildGhost` in `World.tscn`,
halbtransparenter Würfel folgt der Maus während `_build_mode` aktiv ist,
grün/rot je nach Gültigkeit — siehe `docs/building.md`, "Bau-Auslöser" +
"Prüfung + Bau". `_can_build_at()` aus `request_build_guard_post()`
ausgelagert, damit Preview und tatsächlicher Bauversuch dieselbe Regel
nutzen. **Bestätigt getestet.**

**Mauern + Tore ergänzt** (nächster selbst gewählter Schritt, siehe
"Wichtige Vereinbarungen" unten — Nutzerwunsch, dass Mauern Zombies
wirklich aufhalten): zweiter/dritter Bautyp neben dem Wachposten,
`scenes/entities/wall/Wall.gd` (ein Skript für beide, `is_gate`
unterscheidet). Mauern blockieren jeden, auch die eigenen Trupps — Tore
lassen nur den eigenen Besitzer durch, alle anderen (fremde Trupps,
Zombies) bleiben blockiert. Zombies durchbrechen sie aktiv (HP, Angriff
statt Hindurchlaufen), eigene Trupps bleiben einfach davor stehen.
`_can_build_at()`/Ghost-Preview auf drei Typen generalisiert
(`BuildType`-Enum, `cost`-Parameter), `GUARD_POST_BUILD_RADIUS` zu
`BUILD_RADIUS` umbenannt (gilt jetzt für alle drei). Ausführlich in
`docs/walls.md`.

**Erster Fehler nach dem Testen behoben:** `Wall.take_damage()` hatte
`var new_hp := max(hp - amount, 0)` — `max()` liefert in Godots
statischer Typprüfung `Variant`, `:=` konnte den Typ nicht inferieren
(Warnung als Fehler, Spiel startete nicht). Gleiche Fehlerklasse wie schon
einmal bei `result.position` in `World.gd` (siehe oben, Dach-Bug-Fix) —
Fix: `var new_hp: int = max(...)`. **Tor-Durchbrechen danach bestätigt
getestet** (Zombie hat ein Tor nach einer Weile zerstört). **Mauern selbst
noch nicht getestet.**

**Mauer-/Tor-Bauen von Einzelklick auf Ziehen umgestellt** (Nutzerwunsch:
"länger ziehen, nicht nur feste Modelle"): Klicken+Halten+Ziehen platziert
jetzt eine ganze Reihe von Segmenten statt eines einzelnen, mit Rotation
entlang der Zugrichtung (Diagonalen möglich) — Wachposten bleibt
Einzelklick. `request_build_wall` (Einzelsegment) ersetzt durch
`request_build_wall_line` (beliebig viele Segmente, bricht bei
Ressourcenmangel einfach ab statt Fehlermeldung). Live-Ghost-Vorschau für
die ganze Reihe während des Ziehens (`$BuildGhostLine`, gepoolte
Ghost-Meshes).

**Snap fürs Ziehen ergänzt** (Nutzerwunsch, direkt im Anschluss): drei
Snap-Schritte in Prioritätsreihenfolge — (1) Startpunkt magnetet zuerst
ans nächste Ende einer schon platzierten Mauer/eines Tors
(`_nearest_wall_endpoint()`, Umkreis 1 m, wichtig vor allem bei
diagonalen Segmenten), (2) sonst Fallback auf ein 2 m-Weltraster
(`_snap_to_grid()`), (3) Zugrichtung rastet zusätzlich auf 45°-Schritte
(8 Richtungen) ein. `_wall_line_positions()`/`_wall_line_rotation()` zu
einer Funktion `_compute_wall_line()` zusammengefasst, damit Position und
Rotation garantiert dieselbe gerasterte Richtung nutzen. Ausführlich in
`docs/walls.md`, "Ziehen" + "Snap".

**Zwei Fehler nach dem Testen behoben:** `round()` liefert wie `max()`
zuvor `Variant` in Godots statischer Typprüfung — zwei Stellen
(`_compute_wall_line()`, `_snap_to_grid()`) konnten den Typ nicht
inferieren (Warnung als Fehler, Spiel startete nicht). Fix: explizite
`: float`-Typen. Kompletten `scenes`-Ordner danach nach demselben Muster
durchsucht — keine weiteren Treffer.

**Komplettes Mauern+Tore-Feature (Bauen, Ziehen, Snap, Durchbrechen,
Blockade) vom Nutzer bestätigt getestet.** Kein offener Punkt mehr dazu.

**Fahrzeug ergänzt** (Nutzerwunsch: "in der Stadt ein Auto finden und
einsteigen können"): zwei fest platzierte Fahrzeuge (wie die
Platzhalter-Gebäude, kein Bautyp), `scenes/entities/vehicle/Vehicle.gd`.
Trupp muss hinlaufen und einsteigen (`order_enter_vehicle()`, analog zu
`order_search()`), wird dabei unsichtbar + aus `"selectable"`/`"living"`
entfernt — das Fahrzeug übernimmt seine Rolle: schneller (`MOVE_SPEED` 8
vs. 4), lauter (alarmiert Zombies allein durchs Fahren, nicht erst bei
Kampf), respektiert Mauern/Tore genauso wie ein Trupp, kein eigener
Angriff/Gegenschaden (Nutzerentscheidung: reiner Transport). F-Taste zum
Aussteigen, danach für jeden Spieler wieder frei nutzbar
(`owner_peer_id` zurück auf 0). Ausführlich in `docs/vehicle.md`.
**Ein Fehler beim Umsetzen selbst gefunden und vorab behoben** (bevor der
Nutzer ihn treffen musste): `Zombie._try_attack()`s Gegenschaden-Check
nutzte `has_method("order_move")`, das jetzt auch `Vehicle.gd` hat —
Zombies hätten fälschlich Gegenschaden von angegriffenen Fahrzeugen
bekommen. Fix: Check auf `has_method("is_sheltered")` umgestellt (nur
Survivor implementiert das).

**Echter Bug beim ersten Testen gefunden und behoben:** Nutzer meldete
"Charakter und alle Autos einfach weg" nach dem Einsteigen, kein
Fehler im Debugger. Diagnose (kein Crash, sondern Weltdesign-Fehler):
die beiden Fahrzeuge standen ursprünglich bei `(±12, ∓12)`, nur ~5,7
Weltmeter von einem der vier `ZOMBIE_SPAWN_POINTS` entfernt — deutlich
innerhalb `DETECT_RADIUS` (8). Zombies haben die Autos dadurch fast
garantiert kurz nach Spielstart entdeckt und zerstört (200 HP, aber
genug Zeit bis zum Erreichen), bevor jemand fahren konnte — Fahrer stirbt
beim Fahrzeug-Tod mit (Permadeath, siehe `docs/vehicle.md`), "Fahren
ging nicht" war schlicht `is_instance_valid()`, das auf ein schon
zerstörtes Fahrzeug `false` zurückgibt (kein Fehler, kein Feedback).
Fix: Fahrzeuge auf die Kardinalachse bei `(±20, 0)` verschoben, deutlicher
Sicherheitsabstand zu allen vier (diagonal liegenden) Zombie-Spawnpunkten.
**Bestätigt getestet:** hinlaufen, einsteigen, fahren, aussteigen
funktionieren. Kein offener Punkt mehr beim Fahrzeug-Feature.

**Fehlermeldungen ergänzt** (nächster selbst gewählter Schritt, siehe
"Wichtige Vereinbarungen" unten): fehlgeschlagene Bauversuche
(Wachposten/Mauer/Tor) und `request_worker()` ohne freien Trupp zeigen
jetzt den genauen Grund in `$HUD/StatusLabel` (blendet sich nach 2,5s
automatisch aus), statt stillschweigend zu verpuffen —
`World._report_build_failure()`/`report_status()`, siehe
`docs/building.md`, "Fehlermeldungen". Bewusst getrennt vom
Ghost-Preview-Check (`_can_build_at()` bleibt ein einfacher, jeden Frame
laufender Bool-Check).

**UI etwas aufgeräumt** (Nutzerwunsch, direkt im Anschluss): `BuildUI`-Panel
hat jetzt wie `UnitsUI` einen Titel ("Bauen") und eine Trennlinie zwischen
Bau-Buttons und Arbeiter-Liste, beide Panel-Titel einheitlich größer
formatiert. `docs/world.md`s Szenenbaum-Diagramm war seit Mauern/Fahrzeug/
Ghost-Preview veraltet (fehlende Nodes) — dabei aufgefrischt.

**Fehler beim ersten Testen gefunden und behoben:** Nutzer sah keine
Statusmeldung. Ursache: `_show_status_message` fehlte `call_local` — der
schon mehrfach in diesem Projekt dokumentierte Klassiker
("`rpc_id(1, ...)` beim Host zielt auf sich selbst, ohne `call_local`
kommt lokal nichts an"), diesmal selbst begangen statt nur vorgewarnt.
Betraf jeden Fall, in dem der anfragende Peer zufällig der Host selbst
war (z. B. Solo-/Lokal-Tests) — bei einem echten Remote-Client (Join)
wäre die Meldung angekommen. Fix: `call_local` ergänzt.

**"Arbeiter zurück in Units umwandeln" ergänzt** (Nutzerwunsch, direkt im
Anschluss): neuer "Arbeiter abziehen"-Button neben "Arbeiter schicken"
(nur sichtbar, wenn mindestens ein Arbeiter stationiert ist) —
`GuardPost.request_recall_worker()` ruft `order_stop()` auf den
stationierten Trupp auf (kein neuer Unstation-Code, macht `order_stop()`
schon). Der Trupp war technisch nie aus `"living"` entfernt (anders als
ein Fahrzeug-Fahrer, siehe `docs/vehicle.md`) — war also über die
Einheiten-Liste theoretisch schon vorher wählbar, jetzt gibt es dafür
zusätzlich einen direkten Weg am Wachposten selbst.

**Beides (Fehlermeldungen + Arbeiter abziehen) vom Nutzer bestätigt
getestet.** Kein offener Punkt mehr dazu.

## Nachtrag 2026-07-31: diese Datei war veraltet

Beim Einstieg in die neue Session stellte sich heraus, dass die vorherige
Session (2026-07-30) das Zonen-/Claiming-System (Roadmap-Punkt 3, siehe
unten) bereits **komplett fertig umgesetzt** hatte — Code + `docs/zones.md`
existierten schon, nur **diese Datei** (`status.md`) wurde danach nicht mehr
aktualisiert. Dadurch wirkte der Stand hier veraltet ("Punkt 3 noch offen"),
obwohl er es nicht mehr war. **Lektion:** `status.md` nach jedem
abgeschlossenen Feature aktualisieren, nicht nur die System-Doku — sonst
verlässt sich die nächste Session auf einen falschen Stand.

## Start-Basis-Wahl ergänzt (2026-07-31, Fortsetzung der größeren Idee)

Nutzer wollte direkt die größere, bisher zurückgestellte Idee angehen: statt
einer festen, automatisch gespawnten Home-Base in der Kartenecke wählt jetzt
jeder Peer beim Betreten von `World.tscn` selbst eines der acht
Stadt-Gebäude als Start-Basis (Klick auf ein noch niemandem gehörendes
Gebäude, kostenlos, kein vorheriges Durchsuchen nötig — man startet dort).
Home-Base + zwei Survivor spawnen danach relativ zu diesem Gebäude.
Ausführlich in [`zones.md`](zones.md), "Start-Basis wählen".

- `World._spawn_for_peer()` macht jetzt nur noch Catch-up für spät
  beitretende Peers, keine automatische eigene Home-Base mehr.
- Neue RPC `World.request_choose_start_base()`, neuer `_select_at()`-Branch
  (greift, solange `_find_own_home_base() == null`), neues HUD-Label
  `$HUD/BaseChoiceLabel` ("Wähle deine Start-Basis — klicke auf eines der
  Gebäude").
- `HOME_BASE_POSITIONS`/`START_POSITIONS` (feste Kartenecken) entfernt,
  ersetzt durch `BASE_CHOICE_HOME_OFFSET`/`BASE_CHOICE_SURVIVOR_OFFSET`
  (Abstand vom gewählten Gebäude, Richtung von der Kartenmitte weg).
- **Erster Test durch den Nutzer:** Grundfunktion (beide Peers wählen
  unterschiedliche Gebäude) funktioniert, das geclaimte Gebäude färbt sich
  wie erwartet hellblau (bestehendes Claiming-Verhalten, siehe oben) — vom
  Nutzer nachgefragt, war aber kein Bug, sondern erwartet.
- **Echter Bug gefunden:** zweiter Spieler hatte nur einen sichtbaren
  Trupp statt zwei. Ursache: fester Welt-Versatz `SECOND_SURVIVOR_OFFSET`
  (`+X`) für den zweiten Start-Trupp zeigte je nach Gebäuderichtung zurück
  ins Gebäude-Mesh hinein. Fix: Versatz jetzt senkrecht zur `away`-Richtung
  des Gebäudes statt fester Weltrichtung, siehe `docs/zones.md`. **Vom
  Nutzer bestätigt getestet.** Kein offener Punkt mehr zur Start-Basis-Wahl.
- Werkstatt-Rabatt-Retest (siehe vorheriger Punkt) bleibt auf Nutzerwunsch
  bewusst zurückgestellt, kein offener Blocker dafür.

## Nächste-Schritte-Liste (vom Nutzer bestätigt, Reihenfolge fix)

Nutzer wollte eine Liste von Kandidaten für die Weiterarbeit, hat sie so
bestätigt und explizit **Schritt für Schritt in dieser Reihenfolge**
angehen wollen lassen — bei jedem neuen Schritt nicht neu vorschlagen,
einfach mit dem nächsten offenen Punkt weitermachen:

1. ✅ **Trage-Kapazität + Rückweg beim Scavenging** — umgesetzt, vom
   Nutzer bestätigt getestet (HUD + Einheiten-Liste zeigen "trägt X/20").
   Nutzer-Idee für später notiert: ein Rucksack-Item o. Ä., um
   `CARRY_CAPACITY` zu erhöhen — noch nicht umgesetzt, kein konkreter
   Plan dafür.
2. 🔶 **Weitere Gebäudetypen** — Krankenstation + Werkstatt umgesetzt
   (siehe `docs/building.md`), Lager/Betten bewusst zurückgestellt (siehe
   dort, brauchen erst Ressourcen-Limit- bzw. Müdigkeits-System).
   **Krankenstation vom Nutzer bestätigt getestet.** Werkstatt-Rabatt beim
   ersten Test scheinbar wirkungslos gemeldet — Ursache: Nutzer hatte nur
   den (damals noch statischen) Button-Text angeschaut, nicht den
   tatsächlichen Ressourcen-Abzug. Fix: Button-Text ist jetzt live
   (`_update_build_button_texts()` zeigt den echten, ggf. rabattierten
   Preis, aktualisiert alle `WORKER_UI_REFRESH_INTERVAL`). **Werkstatt
   noch nicht erneut getestet.**

   **Nebenbei gemeldet:** Fahrzeuge "verschwinden immer", Nutzer konnte
   keinen Grund nennen, kein Fehler im Debugger. Wahrscheinlichste
   Ursache: Zombie-Zerstörung, bisher ganz ohne Feedback, sah aus wie
   spurloses Verschwinden. Erst Zerstörungs-Meldung ergänzt
   (`Vehicle.take_damage()` → `report_status()`), dann auf direkten
   Nutzerwunsch die eigentliche Ursache behoben statt nur sichtbar
   gemacht: **Zombies greifen ein Fahrzeug jetzt nur noch an, solange
   jemand drinsitzt** (`Vehicle.is_occupied()`,
   `Zombie._is_unoccupied_vehicle()`/`_is_untouchable()`, siehe
   `docs/vehicle.md`, "Nur besetzt angreifbar") — ein geparktes,
   unbesetztes Fahrzeug ist für Zombies kein Ziel mehr. Damit ist die
   frühere "Bekannte Grenze" (unbesetzte Fahrzeuge angreifbar) aufgelöst.
   **Vom Nutzer bestätigt getestet.**

   **Nutzer hat währenddessen eine größere Idee skizziert:** statt
   einzelner gebauter Boxen könnte man am Spielstart eines der acht
   Stadt-Gebäude als Basis wählen, umliegende Gebäude looten/claimen und
   zu Krankenhaus/Küche/Schlafplatz/etc. ausbauen, dabei den Radius
   erweitern — verschmilzt eigentlich Punkt 2 und Punkt 3 dieser Liste.
   Auf Nutzerwunsch **explizit zurückgestellt**: erst die kleine Lösung
   (aktueller Schritt) fertig, dann diese Idee als eigenen größeren
   Schritt angehen. Wachposten/Mauer-Bauweise bleibt in jedem Fall
   bestehen (Nutzer hat das explizit bestätigt).
3. ✅ **Zonen-/Claiming-System** — Grundsystem (Gebäude claimen erweitert
   die Bauzone) UND die größere Idee (Start-Basis-Wahl) sind umgesetzt und
   vom Nutzer bestätigt getestet (inkl. Fix für den zweiten Start-Trupp,
   siehe oben), siehe [`zones.md`](zones.md). Kein offener Punkt mehr.
4. ✅ **Nachspawnende Zombies / wachsende Population** — Zombie-Nest
   umgesetzt (siehe [`zombies.md`](zombies.md), "Zombie-Nest"): ein
   statisches Nest in der Kartenmitte spawnt alle 25s einen neuen Zombie
   ohne Obergrenze, zerstörbar (150 HP, aktuell nur über einen eigenen
   Wachposten in Reichweite erreichbar). **Vom Nutzer bestätigt getestet**
   (Zombiezahl steigt über Zeit). "Horde-Nächte" (periodische große Wellen,
   mehrere Nester) als größere Idee vom Nutzer skizziert, bewusst
   zurückgestellt.
5. 🔶 **Eigener Angriffsbefehl für Trupps** — umgesetzt: Klick auf einen
   Zombie oder ein Zombie-Nest löst `Survivor.order_attack()` aus, Trupp
   läuft hin und greift im Nahkampf an (gleiche Werte wie der bestehende
   Gegenschaden: 15 Schaden, 1s Cooldown), bis das Ziel tot ist oder ein
   neuer Befehl kommt. Siehe [`survivor.md`](survivor.md),
   "Angriffsbefehl". **Noch nicht vom Nutzer getestet.**

Nach Test-Bestätigung jeweils mit dem nächsten Punkt weitermachen, ohne
erneut nachzufragen "was jetzt" (siehe "Wichtige Vereinbarungen" unten,
Punkt 2 — hier aber zusätzlich vom Nutzer explizit als feste Liste
vorgegeben statt selbst gewählt). **Alle fünf Punkte der ursprünglichen
Liste sind jetzt umgesetzt.**

## Trupp-Arten ergänzt (2026-07-31, neue Idee nach der ursprünglichen Liste)

Nutzer wollte nach Abschluss der 5-Punkte-Liste die "zwei Trupp-Arten"-Idee
aus der größeren Vision angehen (`Infos/01 Architektur.md`: Feldtrupps vs.
Bautrupps, die nur innerhalb der eigenen Zone arbeiten). Als kleinsten
Einstieg auf Nutzerwunsch **Bäume fällen** gewählt (statt Autos abbauen
oder nur die reine Typ-Unterscheidung ohne neue Aktion). Ausführlich in
[`survivor.md`](survivor.md), "Trupp-Arten".

- `TroopType`-Enum (`FIELD`/`BUILD`) auf `Survivor`, umschaltbar per Button
  in der Einheiten-Liste, additiv (kein Fähigkeitsverlust).
- Neue `Tree`-Entität (`scenes/entities/tree/Tree.gd`), spawnt dynamisch
  bei jedem Zonen-Ereignis (Start-Basis-Wahl UND Gebäude claimen) in der
  Nähe des neuen Ankers — feste Positionen wären unpassend, weil eine Zone
  praktisch überall entstehen kann.
- Nur Bautrupps können abbauen (`order_harvest()`, server-seitige Prüfung
  + Feedback bei Ablehnung).
- **Farblich unterscheidbar:** Bautrupps sind seit Nutzer-Feedback orange
  eingefärbt statt weiß (`Survivor._update_color()`), Bäume haben Stamm +
  Krone statt eines dünnen Zylinders (Nutzer-Feedback: kaum erkennbar).
- **Markier-System ergänzt** (Nutzerwunsch, direkt im Anschluss): Bautrupps
  arbeiten explizit OHNE Zonen-Beschränkung ("können potenziell überall
  Sachen abbauen") — Klick auf einen Baum ohne Auswahl markiert ihn (Krone
  wird gold), jeder untätige Bautrupp holt sich automatisch den nächsten
  markierten Baum, kartenweit. Ausführlich in `survivor.md`,
  "Markier-System".
- **Erster echter Mehrspieler-Test über zwei getrennte Rechner im selben
  Netzwerk erfolgreich** (nicht nur "Customize Run Instances" lokal) —
  bestätigt, dass Host/Join über ENet auf Port 7777 im LAN ohne
  Portweiterleitung funktioniert. Ob speziell Trupp-Arten/Markier-System
  dabei mitgetestet wurden, ist nicht explizit bestätigt.
- **Autos abbauen ergänzt** (direkt im Anschluss, Selbst-priorisiert):
  zweite "harvestable"-Ressourcenquelle, `scenes/entities/wreck/CarWreck.gd`
  — eigene, separate Entität statt die beiden fahrbaren Vehicle-Objekte
  abbaubar zu machen (hätte deren Transport-Rolle entwertet). Dabei das
  Ernte-System generalisiert: `order_harvest_tree()` → `order_harvest()`,
  `request_toggle_tree_mark()` → `request_toggle_harvest_mark()`, Gruppe
  `"tree"` → gemeinsame Gruppe `"harvestable"` — Bäume und Wracks sind für
  `Survivor.gd` jetzt komplett ununterscheidbar. Ausführlich in
  `survivor.md`, "Ressourcen abbauen: Bäume + Autowracks".
- **Gebäude abreißen bleibt offen** — einzige noch nicht umgesetzte
  Bautrupp-Aktion aus der ursprünglichen Vision-Idee.
- **Korrektur nach weiterem Nutzer-Test:** Bautrupp durchsuchte weiterhin
ganz normal Gebäude (die Trupp-Arten-Unterscheidung war bis dahin additiv
— Bautrupp behielt alle Feldtrupp-Fähigkeiten dazu). Nutzer-Feedback:
"die sollen nur abbauen können" — auf **exklusiv** umgestellt:
`order_search()`/`order_claim_building()`/`order_attack()` prüfen jetzt
alle `troop_type == TroopType.FIELD`, lehnen sonst mit
`report_status()`-Feedback ab. Bautrupp kann seitdem wirklich nur noch
abbauen + sich bewegen. Passiver Gegenschaden bei Zombie-Angriff bleibt
unberührt (kein Befehl). Ausführlich in `survivor.md`, "Trupp-Arten".

**Noch nicht vom Nutzer getestet.**

## Erstes eigenes 3D-Asset + Maßstab/Karten-Anpassungen (2026-07-31)

Nutzer hat sein erstes eigenes Blender-Asset erstellt
(`assets/startbasetest.glb`, Barrikaden-Struktur) und probeweise als
`HomeBase`-Modell eingebaut (siehe `docs/base.md`, "Visueller Test") —
**vom Nutzer bestätigt, passt gut** (nach einmaliger Nachjustierung, siehe
unten).

**Maßstab-Kette angestoßen:** Survivor-Kapsel von 1,2 m auf **1,70 m**
vergrößert (Nutzerwunsch, als menschlicher Referenzwert), `World.
SURVIVOR_GROUND_Y` entsprechend von 0.6 auf 0.85 mit angehoben (halbe
Kapselhöhe, sonst würde der Trupp im Boden versinken). Daraufhin fiel auf,
dass die acht Stadt-Gebäude (2–2,6 m hoch) neben einer 1,70-m-Figur eher
wie Schuppen wirkten — Höhe (`size.y`) um Faktor ~1,7 auf 3–4,4 m
hochskaliert, Grundfläche unverändert (siehe `docs/world.md`).

**Karte + Kamera vergrößert** (Nutzerwunsch, im selben Zug): Bodenfläche
100×100 → 160×160 Weltmeter, `ZOOM_MAX` 25 → 40 (sonst passt die größere
Karte nie ganz ins Bild). Zombie-Spawnpunkte von `±8`/`±8` auf `±22`/`±22`
nach außen verschoben (Nutzerwunsch: mehr Abstand zu den Gebäuden).

**Noch nicht (erneut) vom Nutzer getestet** — Gebäudehöhen/Karte/Kamera/
Zombie-Spawnpunkte sind alle in derselben Änderung, noch kein Feedback
dazu.

## Gebäude abreißen (2026-07-31, letzte Bautrupp-Aktion aus der Vision)

Nutzer wollte als Nächstes selbst gewählt weitermachen — Vorschlag
"Gebäude abreißen" angenommen. Scope-Frage vorab geklärt: **nur
geplünderte, noch niemandem gehörende Gebäude sind abreißbar** (schützt
Zonen-Anker/Start-Basen vor versehentlichem Abriss durch eigene oder
fremde Bautrupps).

- `Building.gd` bekommt dasselbe `take_damage()`/`hp`/`YIELD`-Interface
  wie Tree/CarWreck/StonePile/BrickPile (`MAX_HP := 100`, `YIELD :=
  {"stone": 20, "brick": 10}` — beide Arten gleichzeitig beim Abreißen).
- Neue RPC `Survivor.order_demolish_building()`, setzt `_harvest_target`
  direkt — läuft danach über denselben `_process_harvest()`-Ablauf wie
  Baum/Wrack/Haufen.
- **Bewusst nicht über die Gruppe `"harvestable"`/das Markier-System**
  gelöst, sondern über den bestehenden Gebäude-Klick-Branch: der bestimmt
  `order_method` jetzt pro ausgewählter Einheit (Feldtrupp → claimen,
  Bautrupp → abreißen), statt einmal für die ganze Auswahl.
- Ausführlich in `survivor.md`, "Gebäude abreißen".

**Noch nicht vom Nutzer getestet.**

## Claim-Bug-Untersuchung + Baumenü-Umbau (2026-07-31)

Nutzer meldete: "konnte keine Gebäude claimen". Ursache nicht abschließend
gefunden — Code-Review von `order_claim_building()`/`claim_building()`/dem
Klick-Dispatch in `_select_at()` zeigte keinen offensichtlichen Bug.
Wahrscheinlichste Erklärungen: (a) ein **Bautrupp** war ausgewählt (seit
der Trupp-Arten-Exklusivität dürfen nur Feldtrupps claimen — kein Bug,
Absicht), oder (b) zu wenig **Stein** (`ZONE_CLAIM_COST`) durch die neue
Rohstoff-Aufteilung. Nutzer wusste den genauen Trupp-Typ nicht mehr —
falls das Problem nach dem folgenden Umbau weiter auftritt, genauer
nachfragen (Trupp-Typ, erscheint eine Statusmeldung?).

**Direkt im Anschluss großer Baumenü-Umbau** (Nutzerwunsch): nur noch
Mauer/Wachposten/Tor/**Feld** (neu) sind frei platzierbar. Krankenstation/
Werkstatt entstehen jetzt durchs **Ausbauen** eines bereits geplünderten
UND geclaimten eigenen Gebäudes statt durch freies Platzieren — Klick auf
ein eigenes Gebäude (ohne Trupp-Auswahl nötig) zeigt einen neuen
"Ausbauen"-Abschnitt im `BuildUI`-Panel. Lager als dritte Ausbau-Option
bewusst zurückgestellt (bräuchte erst ein Ressourcen-Limit-System).

- Neue Entität `scenes/entities/field/Field.gd` — produziert passiv alle
  8s 2 Nahrung.
- Neue RPC `World.request_upgrade_building()` — entfernt das Building
  netzwerksicher über den schon bestehenden Abriss-Pfad
  (`building.take_damage(building.hp)`, ohne Rohstoff-Auszahlung) und
  spawnt an derselben Stelle Krankenstation/Werkstatt.
- Gebäude-Klick-Branch in `_select_at()` läuft jetzt unabhängig davon, ob
  ein Trupp ausgewählt ist — nötig, damit "eigenes Gebäude anklicken zum
  Ausbauen" auch ohne Auswahl funktioniert.
- **Vier weitere Startgebäude ergänzt** (`Building9`–`Building12`,
  Nutzerwunsch "mehr Gebäude am Anfang") — insgesamt jetzt zwölf statt
  acht.
- Ausführlich in `building.md`, "Baumenü-Umbau"/"Felder"/"Ausbauen".

**Noch nicht vom Nutzer getestet — inklusive erneutem Test, ob Claimen
jetzt funktioniert.**

## Ressourcen von Spielbeginn an + Boden-Y-Bug behoben (2026-07-31)

Nutzerwunsch: Holz/Metall/Stein/Ziegel sollen schon direkt auf der Karte
liegen, nicht erst nachdem ein Gebäude geclaimt wurde. Neue
`World._spawn_initial_resources()` (host-seitig in `_ready()`, gleiche
Stelle wie `_spawn_zombies()`) verteilt 10 Bäume/4 Autowracks/5
Steinhaufen/5 Ziegelhaufen zufällig über die ganze Karte
(`INITIAL_RESOURCE_SPREAD := 60.0`). Das bisherige Nachwachsen pro
Zonen-Ereignis (`_spawn_*_near()`) bleibt **zusätzlich** bestehen.

**Dabei einen echten Bug gefunden und behoben** (noch bevor der Nutzer ihn
melden konnte): die `_spawn_*_near()`-Funktionen übernahmen bisher die
Y-Höhe des jeweiligen Anker-Gebäudes direkt — seit der Gebäudehöhen-
Skalierung von vorhin (Gebäude jetzt 3–4,4 m statt 2–2,6 m, `position.y`
entsprechend höher) hätte das zu sichtbar schwebenden Bäumen/Wracks/Haufen
in der Nähe geclaimter Gebäude geführt. Fix: eigene, feste
Boden-Y-Konstante pro Ressourcentyp statt der geerbten Anker-Höhe.
Ausführlich in `survivor.md`, "Ressourcen abbauen".

**Direkt im Anschluss (Nutzerwunsch):** "alles was im Spiel spawnt soll
ein bisschen Platz dazwischen haben" — neue `World._spaced_position()`
probiert bis zu 10 Zufallspositionen, bis eine mindestens 3 Weltmeter von
jedem bestehenden Gebäude/Fahrzeug/Zombie-Nest/anderen Ressourcenknoten
entfernt ist, statt rein zufällig zu platzieren. Gilt für Anfangsstreuung
UND Nachwachsen pro Zone. Betrifft nur dynamisch gespawnte Ressourcen —
Gebäude/Fahrzeuge/Zombie-Spawnpunkte sind schon von Hand ausreichend
verteilt platziert.

**Noch nicht vom Nutzer getestet.**

## Horde-Nächte + Lager (2026-07-31)

Nutzer wollte Horde-Nächte umsetzen und gleichzeitig das Lager (dritte
Ausbau-Option, bisher zurückgestellt) fertigstellen — mit der konkreten
Vorgabe, die Lagerkapazität an der Größe des ausgebauten Gebäudes zu
orientieren ("Einfamilienhaus vielleicht nur 500, Hochhaus/alte Schule
1000"). Dafür `Infos/03 Asset-Checkliste.md` konsultiert (Nutzer-Hinweis:
"schau in dem Info-Ordner, was es an Gebäuden gibt") für reale
Referenzgrößen.

**Horde-Nächte:** alle 5 Minuten (Echtzeit, `HORDE_INTERVAL`) 10 Zombies
gebündelt an den vier Kartenecken, sofort auf einen zufälligen lebenden
Trupp alarmiert statt normal zu wandern — Warnung an alle Spieler vorher.
Läuft unabhängig neben dem bestehenden Zombie-Nest, keine Eskalation über
die Zeit (bewusst einfach gehalten, kein Kalendertag-System). Ausführlich
in `zombies.md`, "Horde-Nächte".

**Lager:** löst die Voraussetzung "braucht erst ein Ressourcen-Limit-
System" gleich mit auf — `HomeBase.storage_capacity` (ein gemeinsamer
Deckel für alle sieben Ressourcenarten, `BASE_STORAGE_CAPACITY := 150`
ohne jedes Lager) wächst dauerhaft durchs Ausbauen von Gebäuden zu
Lagern. Kapazität = Gebäude-Volumen (`size.x×size.y×size.z` der
`BoxMesh`) × `STORAGE_CAPACITY_PER_VOLUME := 40.0`, kalibriert an den
Vision-Gebäudegrößen aus der Asset-Checkliste — da die aktuellen
Platzhalter-Gebäude viel kleiner sind als echte Gebäude-Assets, ist der
Faktor entsprechend hochskaliert (liefert aktuell ~550–920 pro Lager).
**Muss neu kalibriert werden**, sobald echte Gebäude-Assets die
Platzhalter-Boxen ersetzen. Ressourcen-Panel zeigt seitdem `Wert/Kapazität`
statt nur `Wert`. Ausführlich in `building.md`, "Lager".

**Noch nicht vom Nutzer getestet.**

## Wachturm + Holzmauer + Zombies greifen Gebäude an (2026-07-31)

Nutzer hat zwei weitere eigene 3D-Assets ergänzt: `assets/wachturmtest.glb`
(→ `GuardPost.tscn`) und `assets/holzmauertest.glb` (→ `Wall.tscn`, NUR
die Mauer, nicht das Tor). Gleiches Einbau-Muster wie bei der Home-Base
(`Model`-Node, alte Box unsichtbar für Kollision). Dabei musste das
Farb-Feedback (Baugelb/Fertig-Grau bzw. HP-Nachdunkeln) generalisiert
werden, weil die importierten Modelle viele verschachtelte Meshes statt
eines einzelnen `$Mesh` haben (`_find_mesh_instances()`, rekursiv). Noch
nicht vom Nutzer visuell bestätigt.

**Zusätzliche Frage beantwortet:** Zombies konnten bisher keine geclaimten
Gebäude angreifen (nur `"living"`-Ziele). Auf Nutzerwunsch umgestellt —
`Zombie._find_nearest_target()` durchsucht jetzt zusätzlich alle
geclaimten Gebäude. Kein Gegenschaden (Gebäude haben kein
`is_sheltered()`), funktioniert dank des bestehenden
`Building.take_damage()` (siehe "Gebäude abreißen") ohne weitere
Änderungen. Ausführlich in `zombies.md`, "Ziel-Erkennung".

**Rückfrage beantwortet:** Nutzer wollte das Nachwachsen pro Zonen-Ereignis
doch nicht — komplett entfernt (`_spawn_trees_near()`/
`_spawn_car_wrecks_near()`/`_spawn_stone_piles_near()`/
`_spawn_brick_piles_near()` samt zugehöriger Konstanten gelöscht, keine
tote/auskommentierte Funktion stehen gelassen). Nur noch die einmalige
Anfangsstreuung (`_spawn_initial_resources()`) bleibt — Claimen/Start-
Basis-Wahl lösen keine neuen Ressourcen-Spawns mehr aus.

**Noch nicht vom Nutzer getestet.**

## Vier Baurohstoffe + Ressourcen-Panel (2026-07-31, Nutzerwunsch)

Statt eines einzigen generischen `materials` jetzt vier eigene
Baurohstoffe: **Holz** (aus Bäumen), **Metall** (aus Autowracks),
**Stein**/**Ziegel** (aus Stadt-Gebäude-Loot). Jeder Bautyp braucht genau
eine thematisch passende Art (Wachposten=Holz, Mauer=Stein, Tor=Metall,
Krankenstation=Ziegel, Werkstatt=Metall, Zonen-Claim=Stein) — Beträge
unverändert zur alten `materials`-Fassung, nur umgehängt, keine
Balancing-Änderung. Ausführlich in `base.md`, "Vier Baurohstoffe".

**UI gleich mit überarbeitet** (Nutzerwunsch, gleicher Auftrag): sieben
Ressourcenarten (inkl. Nahrung/Medizin/Munition) in einer einzigen
HUD-Zeile wären kaum noch lesbar gewesen — eigenes `$ResourcesUI`-Panel
oben rechts ergänzt (eine Zeile pro Art), `hud_label` oben links zeigt
seitdem nur noch Trupp-Status. Bau-Buttons zeigen den Preis weiterhin live
inklusive Art (`_build_button_label()` generalisiert über die neue
`RESOURCE_DISPLAY_NAMES`-Tabelle statt fest auf "Baumaterial" verdrahtet).

**Korrektur nach Nutzer-Test:** Stein/Ziegel kamen zunächst aus
Stadt-Gebäude-Loot (Building3/4/7) — Nutzer-Feedback: "Bautrupp hat im
Haus normal gelootet, das sollen die nicht [tun]". Stattdessen zwei neue
`"harvestable"`-Entitäten ergänzt: `StonePile.gd`/`BrickPile.gd`
(`scenes/entities/pile/`), 1:1 dasselbe Muster wie Tree.gd/CarWreck.gd,
spawnen dynamisch bei jedem Zonen-Ereignis wie die anderen beiden.
Building3/4/7-Loot auf reine Feldtrupp-Ressourcen zurückgesetzt
(`food`/`medicine`/`ammo`). Damit sind Bautrupp-Rohstoffe jetzt
ausschließlich über eigene Ressourcenknoten erreichbar, nie über
Häuser-Loot. Ausführlich in `survivor.md`, "Ressourcen abbauen: Bäume,
Autowracks, Stein-/Ziegelhaufen".

**Noch nicht vom Nutzer getestet.**

## Zombie-Typen: Brute ergänzt (2026-07-31, eigene Wahl nach "mach weiter wo du für richtig hältst")

Nutzer hat nach der neuen Session-Datei explizit delegiert, den nächsten
Schritt selbst zu wählen — Brute-Zombies waren die zuvor selbst
empfohlene und nicht widersprochene Idee, jetzt umgesetzt. Gleiches
Flag-Muster wie `Wall.gd`/`is_gate`, aber als zwei getrennte Szenen
(`Zombie.tscn`/`ZombieBrute.tscn`) statt nur einem Export auf derselben
Szene, weil sich unterschiedliche Kapsel-Maße nicht per Export
umschalten lassen. Maße aus `Infos/03 Asset-Checkliste.md` übernommen
(Standard 1,7m×0,3m Radius, Brute 2,1m×0,4m Radius), Standard-Kapsel
dabei gleich mit von 1,2m auf 1,7m korrigiert (war seit dem
Survivor-Rescale noch nicht nachgezogen).

`@export var is_brute` steuert vier Instanzvariablen (`_max_hp`,
`_wander_speed`, `_chase_speed`, `_attack_damage`), berechnet in
`_ready()` — bekannte `@export`-Timing-Falle wieder beachtet (`var hp:
int = 0` statt `= MAX_HP`, echte Zuweisung erst in `_ready()`, gleiches
Muster wie bei `Wall.gd`/`is_gate`). Brute: 100 HP, langsamer
(Wander 1.2/Chase 3.5 statt 2.0/5.0), höherer Schaden (25 statt 10),
eigener dunklerer Grundton in `_update_color()`.

`World._create_zombie()` wählt anhand `data.get("is_brute", false)` die
passende Szene; `_trigger_horde_night()` mischt `HORDE_BRUTE_COUNT := 2`
Brutes in jede `HORDE_SIZE := 10`-Welle, mit eigener Ground-Y-Konstante
(`ZOMBIE_BRUTE_GROUND_Y := 1.05` statt `ZOMBIE_GROUND_Y := 0.85`, sonst
würde die größere Kapsel im Boden versinken). Late-Join-Catch-up
(`_catch_up_zombie()`) reicht `is_brute` mit durch, damit später
beitretende Peers existierende Brutes korrekt sehen. Die vier festen
Start-Zombies und alle Zombie-Nest-Spawns bleiben automatisch
Standard-Läufer (kein `is_brute`-Key → Default `false`).

Dabei nebenbei einen echten Bug gefunden und behoben:
`spawn_nest_zombie()` übernahm bisher die rohe `spawn_position` vom
Zombie-Nest (dessen eigene Y-Höhe 1,35), Nest-Zombies schwebten also
leicht über dem Boden — jetzt wird explizit auf `ZOMBIE_GROUND_Y`
gesetzt. Ausführlich in `zombies.md`, "Zombie-Typen".

**Noch nicht vom Nutzer getestet.**

## Tag/Nacht-Zyklus + Zombie-Loot-Drop (2026-07-31, Nutzerwunsch)

Nutzer wollte zwei Dinge gleichzeitig: "mach den tag nacht zyklus und
bei zombies ein drop aber nur munition, heil zeug, oder eine waffe mehr
nicht".

**Tag/Nacht-Zyklus:** `World._day_time` (läuft auf jedem Peer, nicht
nur Host — Beleuchtung muss lokal überall stimmen) zählt über einen
`DAY_LENGTH := 240.0` / `NIGHT_LENGTH := 60.0`-Zyklus (zusammen 300s,
bewusst derselbe Gesamtrhythmus wie das jetzt entfallene
`HORDE_INTERVAL`). Neuer `WorldEnvironment`-Node in `World.tscn` +
`_update_day_night_visuals()` blenden Licht/Himmel/Ambient weich
zwischen Tag- und Nachtwerten (`DUSK_LENGTH := 20.0`s Übergang, kein
harter Schnitt). Horde-Nächte (siehe oben) werden jetzt NICHT mehr über
ein unabhängiges Zeitintervall ausgelöst, sondern genau einmal pro
Nachteintritt (`_handle_day_night()`, nur host-seitig gegated) — direkte
Umsetzung der eigenen vorherigen Empfehlung, Horde-Nächte an einen
"echten Spieltag" zu koppeln. Späte Peers bekommen den aktuellen Stand
per neuer `_catch_up_day_time()`-RPC nachgeliefert (gleiches Muster wie
alle anderen `_catch_up_*`-Funktionen).

**Zombie-Loot-Drop:** Neue `World.grant_zombie_loot(peer_id, is_brute)`,
aufgerufen von `Zombie.take_damage()` beim Tod (gleiches Cross-Node-
Muster wie `spawn_recruit()`). Droppt mit `ZOMBIE_LOOT_DROP_CHANCE :=
0.5` einen zufälligen Typ aus genau den drei vom Nutzer genannten
Arten (`ammo`/`medicine`/`weapon`), Brutes droppen mehr. `take_damage()`
hat dafür einen neuen optionalen `source_peer_id`-Parameter bekommen,
den `Survivor._process_attack()` (Angriffsbefehl), `Zombie._try_attack()`
(Gegenschaden) und `GuardPost._try_fire()` (Wachposten-Beschuss) jetzt
alle mitgeben — nötig, damit der Loot dem richtigen Spieler gutgeschrieben
wird. `ZombieNest.take_damage()` musste denselben Parameter (ungenutzt)
bekommen, weil Wachposten dieselbe Methode auch auf Nester aufrufen.

**"weapon"** ist ein neuer, achter Ressourcentyp (`HomeBase.
START_RESOURCES`, `RESOURCE_DISPLAY_NAMES`) — wie Munition aktuell nur
gesammelt, noch ohne eigenes Waffensystem, das ihn verbraucht. Bewusst
kein physischer Pickup-Node — Drop geht direkt in die Home-Base des
Verursachers, konsistent mit dem Rest der Ressourcen-Ökonomie.

Ausführlich in `world.md`, "Tag/Nacht-Zyklus" und `zombies.md`,
"Zombie-Loot-Drop".

**Noch nicht vom Nutzer getestet.**

## Uhrzeit-Anzeige + Zombie-Nacht-Schadensbonus (2026-07-31, Nutzerwunsch)

Nutzer wollte zwei Ergänzungen zum gerade fertigen Tag/Nacht-Zyklus:
"kannst du noch eine uhrzeit eingfügen sowie das zombies ab 22 uhr bis 4
uhr morgens 20 proznet stärker machen".

**Uhrzeit:** Der bisherige Tag/Nacht-Zyklus rechnete nur mit
`DAY_LENGTH`/`NIGHT_LENGTH` in Sekunden, ganz ohne Bezug zu einer echten
Uhrzeit. Umgebaut: `CYCLE_LENGTH := 300.0` Sekunden entsprechen jetzt
explizit einem `HOURS_PER_DAY := 24.0`-Stunden-Spieltag,
`current_game_hour()`/`_clock_text()` leiten daraus `HH:MM` ab, neues
`ClockLabel` im Ressourcen-Panel zeigt es live an (+ "(Nacht)"-Suffix).
Das alte `DAY_LENGTH`/`NIGHT_LENGTH`-Schema ist komplett entfallen,
ersetzt durch `NIGHT_START_HOUR := 22.0`/`NIGHT_END_HOUR := 4.0` —
dieselben zwei Werte bestimmen jetzt sowohl `is_night()` (Beleuchtung +
Horde-Trigger) als auch den neuen Zombie-Nachtbonus, bewusst EIN
gemeinsames Zeitfenster statt zwei potenziell auseinanderlaufender.

**Zombie-Nachtbonus:** `Zombie._try_attack()` fragt vor jedem Angriff
`World.is_night()` ab und multipliziert den Schaden mit
`ZOMBIE_NIGHT_DAMAGE_MULTIPLIER := 1.2` (Standard-Zombies und Brutes
gleichermaßen, jeweils auf ihren eigenen `_attack_damage`). Bewusst nur
der Schaden, nicht HP/Geschwindigkeit — ein Max-HP-Sprung bei
Nachtbeginn hätte angeschlagenen Zombies unbeabsichtigt Gratis-HP
gegeben.

Ausführlich in `world.md`, "Tag/Nacht-Zyklus" und `zombies.md`,
"Nacht-Schadensbonus".

**Noch nicht vom Nutzer getestet.**

## Speichern/Laden + Hauptmenü-Überarbeitung (2026-07-31, Nutzerwunsch)

Nutzer hat nach der Kartengröße-/Performance-Diskussion (Zonen-Zufalls-
generierung, siehe persistentes Memory außerhalb dieser Datei) gefragt, was
als Nächstes sinnvoll wäre. Vorschlag **Speichern/Laden** angenommen
(Begründung: keinerlei Persistenz für 3–4h-Sessions bisher), Nutzer hat
direkt ergänzt: Titelbildschirm überarbeiten, Einstellungs-Knopf,
Solo-Start, Koop.

**Neu, host-seitig:** `SaveManager`-Autoload (ein Speicherstand,
`user://saves/savegame.sav`, `var_to_str()`/`str_to_var()`) +
`World._collect_save_data()`/`_load_game_state()`. Wiederverwendet
konsequent die bestehende Spawn-Infrastruktur (jede `_create_*()`-Funktion
+ `xxx_spawner.spawn()` repliziert ohnehin schon automatisch) — sieben
`_create_*()`-Funktionen bekamen dafür optionale `hp`/`is_marked`/`hunger`/
`carried_loot`/`troop_type`/`built`-Fallbacks, bestehende Aufrufer
unbeeinflusst. Zwölf feste Stadt-Gebäude/zwei Fahrzeuge/ein Zombie-Nest
(keine Spawner, feste Kind-Nodes in `World.tscn`) werden per `get_node()`
direkt überschrieben statt neu erzeugt. Bewusste Vereinfachungen: Mehr-
spieler-Wiederaufnahme läuft über ENet-Peer-ID-Reihenfolge (kein Accounts-
System), Wachposten-Arbeiter/Fahrzeug-Fahrer werden nicht wiederhergestellt.
Ausführlich in `docs/save_load.md`.

**Neu: Ausstiegspunkt aus dem Spiel** — vorher gab es keinen Weg,
`World.tscn` zu verlassen. `PauseMenu.tscn` (Escape-Taste, vorher komplett
ungenutzt), "Speichern" nur für den Host sichtbar (gleiches Muster wie
`Lobby.start_button`).

**Hauptmenü überarbeitet:** größerer Titel, **Solo** (Host + direkt ins
Spiel, überspringt die Lobby), **Koop** (unverändertes Host/Join, weiterhin
über die Lobby), **Laden** (deaktiviert ohne Speicherstand), **Einstellungen**.

**Neu: `SettingsManager`-Autoload + `SettingsMenu`-Overlay** — Vollbild +
Master-Lautstärke, persistiert über `ConfigFile`. Lautstärke-Regler hat
aktuell keine hörbare Wirkung (im Projekt wird bisher nirgends Sound
abgespielt) — bewusst trotzdem eingebaut, schon vorbereitet für später.
Ausführlich in `docs/settings.md`.

**Noch nicht vom Nutzer getestet** (kein laufender Godot-Editor in der
Entwicklungsumgebung — nur über statische Checks verifiziert).

## Minimap (2026-07-31, Nutzerwahl nach Rückfrage)

Nach Speichern/Laden gefragt, was als Nächstes sinnvoll wäre — Vorschlag
"Minimap/Fog of War" angenommen. Rückfrage zum Umfang: echtes Fog of War
(geteilte Kartenaufdeckung, siehe `ARCHITECTURE.md`, "Geteilte Aufklärung")
bräuchte neuen, netzwerk-replizierten Zustand und lohnt sich auf der
aktuellen 160×160-Karte kaum (Kamera zeigt mit `ZOOM_MAX := 40.0` ohnehin
fast alles) — Nutzer hat sich für **nur die Minimap** entschieden, Fog of
War bleibt zurückgestellt (relevanter, sobald die Karte mal größer wird,
siehe zurückgestellte Kartengrößen-Idee im persistenten Memory).

Neu: `scenes/world/Minimap.tscn`/`.gd`, unten rechts oberhalb des
`UnitsUI`-Panels. Zeichnet prozedural (`Control._draw()`, keine zweite
Kamera/kein `SubViewport`) Gebäude/Home-Bases/Trupps/Fahrzeuge/Zombies/
Zombie-Nest anhand derselben Gruppen-Abfragen, die auch sonst im Projekt
verwendet werden — komplett ohne neuen Netzwerk-Code, da alle gezeigten
Nodes über das bestehende Spawner+RPC-System längst lokal auf jedem Peer
vorliegen. Klick verschiebt die eigene Kamera dorthin. Neue Konstante
`World.MAP_SIZE := 160.0` (musste vorher nirgends benannt existieren, nur
im `.tscn`-Sub-Resource) für die Welt-zu-Pixel-Umrechnung. Dabei nebenbei
eine veraltete Doku-Stelle korrigiert (`world.md` sprach noch von acht statt
zwölf Stadt-Gebäuden, seit dem Baumenü-Umbau nicht nachgezogen). Ausführlich
in `world.md`, "Minimap".

**Noch nicht vom Nutzer getestet.**

## Waffensystem, Stufe 1 (2026-07-31, Nutzerwunsch)

Nach der Minimap gefragt, was als Nächstes sinnvoll wäre — Waffensystem
vorgeschlagen (Munition seit Spielbeginn, "weapon" seit dem Zombie-Loot-Drop
beide ungenutzt) und angenommen. **Wichtige Abgrenzung vorab geklärt:** Die
Vision-Doku (`Infos/02 Item-Liste.md`) beschreibt ein sehr viel größeres
System (Waffenstufen, typspezifische Munition, Rüstung, Forschungsbücher,
Crafting, Waffen-Mods, Slots) — das wird hier bewusst **nicht** gebaut,
das wäre ein eigenständiges Projekt für sich.

Umgesetzt: `Survivor.is_armed` + `order_equip_weapon()` (verbraucht 1×
`weapon` aus der eigenen Home-Base, nur Feldtrupps, kein Ablegen in dieser
Stufe). `_process_attack()` erweitert um einen Fernkampf-Zweig
(`RANGED_ATTACK_RANGE := 6.0`, wie `GuardPost.FIRE_RANGE`;
`RANGED_ATTACK_DAMAGE := 20`, mehr als Nahkampf) — nur aktiv, solange die
eigene Home-Base noch Munition hat, verbraucht 1× `ammo` pro Schuss, fällt
bei leerer Munition automatisch auf Nahkampf zurück statt untätig
stehenzubleiben. Neuer "Ausrüsten"-Button in der `UnitsUI`-Trupp-Zeile,
Label zeigt `" (bewaffnet)"` nach Ausrüstung. `is_armed` in
`_sync_state()` (Replikation) und in Speichern/Laden
(`_collect_save_data()`/`_load_game_state()`/`_create_survivor()`, siehe
`docs/save_load.md`) integriert — reine additive Erweiterung, bestehendes
Verhalten unverändert.

Ausführlich in `survivor.md`, "Waffensystem"; `docs/base.md` entsprechend
korrigiert (vorherige "nie verbraucht"-Aussage stimmte nicht mehr).

**Noch nicht vom Nutzer getestet.**

## Waffensystem-Nachbesserung: Startwaffe + kompaktere Trupp-UI (2026-07-31, Nutzer-Feedback)

Nutzer konnte nicht testen: keine Waffe verfügbar (kommt nur per Zombie-
Loot-Drop, ~50% Chance auf einen von drei Typen), Trupp starb im
unbewaffneten Nahkampf-Testversuch vorher. Zusätzlich: die Trupp-Zeile in
`UnitsUI` sei zu groß/unübersichtlich geworden (seit dem "Ausrüsten"-Button
lief eine `HBoxContainer`-Zeile über die Panel-Breite hinaus).

- **`HomeBase.START_RESOURCES["weapon"]`**: 0 → 1 — Waffensystem sofort
  testbar, ohne erst einen riskanten Nahkampf-Kill abzuwarten.
- **`World._refresh_units_ui()`** komplett auf zweizeilig umgestellt
  (Status-Label oben, Button-Zeile darunter, kleinere Schrift/kürzere
  Button-Texte: "Wählen"→"Wähl.", "→ Bautrupp"→"→Bau" usw.) — passt jetzt
  in die Panel-Breite statt drüberzulaufen.
- **`UnitsUI`-Panel verkleinert** (384×244 → 284×210), **Minimap**
  entsprechend nachgerückt (bleibt mit 8px Abstand direkt darüber).

**Noch nicht vom Nutzer getestet.**

## Schuss-Feedback + Startzeit 5 Uhr (2026-07-31, Nutzer-Feedback)

Nutzer war unsicher, ob ein Fernkampf-Schuss überhaupt stattfand ("hatte
Waffe aber glaub nicht geschossen, bin mir aber nicht sicher"). Ursache
nach Code-Durchsicht: die Angriffslogik selbst war korrekt, es gab aber
**keinerlei sichtbaren Unterschied** — ein bewaffneter Trupp sah genauso
aus wie ein unbewaffneter, und ein Schuss aus der Ferne zeigte sich nur als
"Trupp bleibt 6m entfernt stehen", ununterscheidbar von Nichtstun.

- `Survivor._update_color()`: bewaffneter Feldtrupp bekommt einen
  stahlblauen Grundton statt Weiß.
- Neue `Survivor._play_shot_effect(target_position)` (RPC, an alle Peers
  repliziert): kurzer Leuchtstreif zwischen Trupp und Ziel bei jedem
  Fernkampf-Schuss, 0,12s Lebensdauer, rein optisch.
- `HomeBase.START_RESOURCES["weapon"]`: 0 → 1 (siehe vorheriger Eintrag,
  war schon mal Thema, hier nochmal im Kontext relevant).

Zusätzlich: **Startzeit auf 05:00 Uhr** gesetzt (`World._day_time`
Feld-Default `0.0` → `62.5`) statt Mitternacht — nur für den Frisch-Start,
geladene Spielstände behalten ihren gespeicherten Stand.

Ausführlich in `survivor.md`, "Waffensystem" (neuer Unterpunkt); `world.md`,
"Tag/Nacht-Zyklus".

**Offen/noch nicht entschieden:** Nutzer wollte zusätzlich ein eigenes
Fenster pro Trupp mit Waffen-/Rüstungsslot + Stats — Rückfrage zum Umfang
läuft noch (ein Rüstungssystem existiert bisher gar nicht, siehe
"Wichtige Abgrenzung" beim Waffensystem-Eintrag oben).

**Noch nicht vom Nutzer getestet.**

## Rüstungssystem + Trupp-Detailfenster (2026-07-31, Nutzerwunsch)

Direkte Fortsetzung des Waffensystems: Nutzer wollte ein eigenes Fenster
pro Trupp mit Waffenslot/Rüstungsslot/Stats — Rückfrage (nur Fenster ohne
Rüstung vs. Fenster + echtes Rüstungssystem) → Nutzer wollte beides. Erst
komplett durchgeplant und auf Wunsch in die Session-Doku + persistentes
Memory gespeichert, danach ("weiter geht's") umgesetzt.

**Rüstungssystem, Stufe 1** (gleiche Schlankheit wie Waffensystem):
`Survivor.is_wearing_armor` + `order_equip_armor()` — **kein**
Trupp-Arten-Filter (anders als Waffen, Rüstung schützt Feld- UND
Bautrupps), verbraucht 1× `armor` aus der eigenen Home-Base. 30% weniger
eingehender Schaden (`ARMOR_DAMAGE_REDUCTION`), 15% langsamere Bewegung
(`ARMOR_SPEED_FACTOR`, kombiniert sich mit dem Hunger-Malus). Neue
Ressource `"armor"` (neunte Art), Startbestand 1 (wie beim Waffen-Fix),
vierter Zombie-Loot-Typ neben ammo/medicine/weapon (verdünnt deren
Drop-Rate leicht, bewusst in Kauf genommen).

**Neues Trupp-Detailfenster** (`UnitDetailUI`, inline in `World.tscn`):
sichtbar nur bei genau einem ausgewählten eigenen Trupp, links mittig
positioniert (freier Bereich zwischen `HUD` und `BuildUI`). Zeigt Stats
ausführlicher als die kompakte Liste, plus Waffen-/Rüstungs-Zeile mit
Ausrüsten-Buttons. Der bisherige "Ausrüsten"-Button ist dafür aus der
kompakten `UnitsUI`-Liste rausgewandert (Nutzer-Feedback von zuvor: die
sollte klein bleiben) — dort jetzt nur noch ein kurzes `[W]`/`[R]`-Tag im
Label. `is_wearing_armor` in `_sync_state()` (sechster Parameter) und
Speichern/Laden integriert, exakt wie `is_armed` behandelt.

Ausführlich in `survivor.md`, "Rüstungssystem" (inkl. Trupp-Detailfenster).

**Noch nicht vom Nutzer getestet.**

## Rüstung: zweiter Slot "Helm" (2026-07-31, Nutzerwunsch nach erstem Test)

Direkte Nachbesserung am gerade gebauten Rüstungssystem: Nutzer wollte
zwei getrennte Slots statt einem — Helm und Brustpanzer unabhängig
voneinander ausrüstbar. `Survivor.has_helmet` + `order_equip_helmet()`
(gleiches Muster wie `is_wearing_armor`/`order_equip_armor()`, kein
Trupp-Arten-Filter, verbraucht 1× neue Ressource `"helmet"`, zehnte Art).
`HELMET_DAMAGE_REDUCTION := 0.15` (kleiner als Brustpanzer, kein
Speed-Malus) — beide Reduktionen wirken in `take_damage()` jetzt
multiplikativ zusammen (`amount * (1-Brustpanzer) * (1-Helm)`), können
sich also nie zu über 100% aufsummieren. Zombie-Loot-Tabelle um `"helmet"`
als fünften Typ erweitert. Trupp-Detailfenster bekam eine dritte Zeile
(Helm), kompakte Liste ein zusätzliches `[H]`-Tag. `has_helmet` in
`_sync_state()` (siebter Parameter) und Speichern/Laden integriert, exakt
wie die anderen Status-Felder behandelt.

Ausführlich in `survivor.md`, "Rüstungssystem" (aktualisiert für zwei
Slots).

**Noch nicht vom Nutzer getestet.**

## Große Karte: Prozedurale Zonen-Generierung (2026-07-31, "Direkt die Karte angehen")

Nutzer wollte nach Abschluss von Waffen-/Rüstungssystem direkt die Karte
angehen (statt der zunächst empfohlenen Zombie-Cap/Despawn-Vorarbeit) —
und den gesamten Umbau in **einem Plan** statt in Phasen. Direkte
Umsetzung der lange zurückgestellten Kartengrößen-Diskussion
(persistentes Memory): 5000×5000 statt echtem Chunk-Streaming
(1.000.000×1.000.000, als zu großer Umbau verworfen), `MAP_SIZE`
parametrisch, Zonen-/Platzierungs-Zufallsgenerierung statt Terrain/Fog of
War (beides weiterhin bewusst zurückgestellt).

**Vorher: buchstäblich alles hartcodiert** — 12 feste `BuildingN`-Nodes,
2 feste `VehicleN`-Nodes, 1 festes `ZombieNest1`, 4 feste
`ZOMBIE_SPAWN_POINTS`, ein fester Ressourcen-Streuradius um den
Weltursprung, `MAP_SIZE` an drei Stellen dupliziert, keine
Kamera-Pan-Begrenzung.

**Jetzt:**
- `MAP_SIZE := 5000.0` (vorher 160), Boden prozedural aus einer einzigen
  Konstante erzeugt statt dreifach dupliziert, `ZOOM_MAX` moderat auf 60
  (nicht linear mitskaliert), neue Kamera-Pan-Klemmung.
- **Fünf Stadt-Zonen** (`_generate_world()`/`_generate_city_zone()`),
  Zentren mit Mindestabstand zufällig gewürfelt. Gebäude/Fahrzeuge/
  Zombie-Nest laufen jetzt alle über `MultiplayerSpawner`
  (`BUILDING_TEMPLATES` 1:1 aus den zwölf ursprünglichen Gebäuden
  übernommen) statt als feste `.tscn`-Kind-Nodes — **schließt nebenbei**
  eine zuvor bekannte Grenze: Late-Join-Catch-up für Gebäude/Fahrzeuge/
  Zombie-Nest gibt es jetzt (bei Vehicle weiterhin ohne `owner_peer_id`,
  siehe `docs/vehicle.md`).
- Wildnis-Ressourcen (Bäume/Autowracks/Stein-/Ziegelhaufen) über die ganze
  Karte verteilt, Gesamtzahlen bewusst nur moderat erhöht (200/80/100/100
  statt 10/4/5/5) statt proportional zur ~977× größeren Fläche — vermeidet
  das schon dokumentierte Performance-Risiko (Entity-Zahl statt Fläche ist
  der Flaschenhals).
- Start-Basis-Wahl-Richtungsbug proaktiv gefunden und behoben (vor jedem
  Testen): "weg von der Kartenmitte" war weltursprung-relativ, hätte mit
  verteilten Zonen gebrochen — jetzt zonen-relativ (`building.zone_center`).
- Speichern/Laden für Gebäude/Fahrzeuge/Zombie-Nest auf array-basiert
  umgestellt (identisches Muster wie Tree/Zombie) — echte Vereinfachung,
  der bisherige `"demolished"`/`"destroyed"`-Sentinel-Wert entfällt
  komplett.
- Horde-Nächte spawnen jetzt in der Nähe des gewählten Ziels statt an vier
  globalen Fixpunkten (die auf einer 5000×5000-Karte keinen Sinn mehr
  ergäben).
- **Bekannte, transparent kommunizierte Konsequenz:** 5 Nester statt 1
  bedeutet 5× so schnelles Zombie-Wachstum — macht die schon früher
  zurückgestellte Zombie-Obergrenze/Despawn-Idee relevanter, ist aber kein
  Teil dieses Umbaus.

Ausführlich in `world.md` ("Kartenlayout"), `zones.md`, `scavenging.md`,
`save_load.md`, `vehicle.md`, `zombies.md`.

Verifiziert über die etablierten statischen Checks (Trap-Muster-Grep,
`$NodePath`-Integrität, `load_steps`-Neuberechnung, Tab-Einrückung) — kein
laufender Godot-Editor in dieser Umgebung verfügbar.

**Vom Nutzer getestet — zwei echte Bugs gefunden und behoben:**
`Vehicle.tscn`/`ZombieNest.tscn` existierten als eigenständige
Szenendateien nie (Fahrzeug/Zombie-Nest waren vorher nur direkt in
`World.tscn` verankerte Nodes, keine eigene `.tscn`) — beim Umstellen auf
`preload()` dieser Pfade übersehen, dass die Dateien selbst fehlten (nur
`Building.tscn` war neu angelegt worden). Fix: beide Szenen nachgebaut,
1:1 gleiches Muster wie `Building.tscn`, mit den exakten
Original-Maßen/Gruppen aus dem alten `World.tscn`. **Danach bestätigt
getestet, funktioniert.**

**Direkt im Anschluss:** `BUILDINGS_PER_ZONE` von 12 auf 24 erhöht
(Nutzerwunsch "vielleicht mehr Gebäude", per Rückfrage auf "mehr Gebäude
pro Zone" konkretisiert) — `CITY_ZONE_RADIUS`/`BUILDING_MIN_SPACING`
bieten dafür reichlich Platz, keine weiteren Anpassungen nötig.

## Zombie-Obergrenze + Benchmark-Tooling (2026-07-31, Nutzerwunsch)

Nutzer fragte nach dem Kartenumbau, ob sich Biome lohnen — Empfehlung:
eher der schon länger als Risiko notierte Zombie-Deckel zuerst (5 Nester
statt 1 seit dem Kartenumbau bedeuten 5× schnelleres, unbegrenztes
Wachstum, siehe persistentes Memory `koopgame_map_scale_performance`).
Nutzer wollte einen konkreten, sinnvollen Cap-Wert UND eine Möglichkeit,
ihn zu testen/benchmarken.

- **`World.MAX_ZOMBIES := 200`** — bewusst ein Startwert zum empirischen
  Benchmarken (Flaschenhals ist die O(n)-Zielsuche pro Zombie pro Frame,
  hardwareabhängig), keine "berechnete" Zahl.
- **Nur das Zombie-Nest respektiert den Deckel** (`spawn_nest_zombie()`
  lässt den Spawn einfach aus, sobald erreicht) — kein Despawn nötig,
  sinkt von selbst durch Spielerkills. Horde-Nächte dürfen ihn bewusst
  kurz überschreiten (fester Ausschlag, keine Eskalation).
- **Benchmark-Tooling (Nutzerwunsch, beides gewählt):** Live-Zähler
  "Zombies: X/200" im Ressourcen-Panel (`ZombieCountLabel`, gedrosselt
  über `WORKER_UI_REFRESH_INTERVAL`) + Debug-Hotkey `F9`
  (`_debug_spawn_zombies()`), spawnt sofort 50 Zombies um die
  Kameraposition — bewusst ohne Cap-Prüfung, damit sich der Deckel gezielt
  und schnell überschreiten lässt, ohne auf reguläre Spawnintervalle zu
  warten. Reines Entwickler-Werkzeug, kein Spielfeature.

Ausführlich in `zombies.md`, "Zombie-Obergrenze".

**Vom Nutzer getestet, konkreter Messwert:** 500 Zombies (per F9 über den
Cap hinaus gespawnt) → **15 FPS**. Bestätigt, dass die Performance-Sorge
real ist. `MAX_ZOMBIES := 200` bleibt vorerst unverändert (deutlicher
Sicherheitsabstand), siehe unten für den daraus resultierenden
Optimierungs-Plan.

## Performance-Optimierung: Spatial Grid + AI-Throttling (geplant, noch nicht umgesetzt)

Direkte Reaktion auf den 500-Zombie/15-FPS-Messwert oben. Nutzer wollte
statt nur eines Caps die eigentliche Ursache angehen. Auf Nachfrage
("wie würde das genau laufen") wurden zwei vermutete, **getrennte**
Ursachen identifiziert (siehe auch persistentes Memory
`koopgame_map_scale_performance`):

1. **Echtes O(z²), aber nur während Kampf:**
   `Zombie._alert_nearby_zombies()` sowie
   `GuardPost._find_nearest_zombie()`/`_alert_nearby_zombies()`
   durchsuchen bei jedem Aufruf die komplette `"zombie"`-Gruppe (alle
   Zombies) statt nur die Nachbarschaft.
2. **Vermutlich der eigentliche Übeltäter im F9-Test** (Zombies stehen
   dabei erstmal nur rum, kämpfen nicht): `Zombie._update_chase_target()`
   ruft `_find_nearest_target()` **jeden Frame** für **jeden** wandernden
   Zombie auf, ganz ohne Throttling — bei 500 Zombies 500× pro Frame eine
   Schleife über `"living"` + `"searchable"` (~130 Einträge), dazu
   Instanz-/Physik-Overhead (`move_and_slide`) × 500. Linear statt
   quadratisch, aber mit hohem Overhead pro Instanz — ein Zombie-Grid
   (Punkt 1) behebt das NICHT, da hier gar nicht über andere Zombies
   gesucht wird.

**Geplanter Fix, beides zusammen:**

- **Spatial Grid in `World.gd`** (für Punkt 1): `Dictionary[Vector2i,
  Array]`, jeden Frame einmal neu befüllt (`get_tree().get_nodes_in_group
  ("zombie")` einmal durchlaufen, pro Zombie in eine Zelle einsortiert via
  `Vector2i(floor(pos.x/CELL_SIZE), floor(pos.z/CELL_SIZE))` — O(z),
  billig). Neue öffentliche `World.zombies_near(position, radius) ->
  Array`, schaut nur in die Zellen um den Zielpunkt (Zellgröße größer als
  `NOISE_RADIUS`/`FIRE_NOISE_RADIUS`, damit ein 3×3-Ausschnitt garantiert
  reicht), filtert danach exakt per Distanz. Ersetzt die volle
  Gruppenabfrage in `Zombie._alert_nearby_zombies()` und
  `GuardPost._find_nearest_zombie()`/`_alert_nearby_zombies()`.
- **Throttling der Zielsuche** (für Punkt 2): `_update_chase_target()`
  nicht mehr jeden Frame, sondern gedrosselt (z. B. alle 0.2s, gleiches
  Muster wie das bestehende `WORKER_UI_REFRESH_INTERVAL`) — für Wander-KI
  unbemerkbar, spart aber massiv Rechenzeit bei vielen Zombies.

**Vor dem Umbau:** Godot-Profiler bei 500 Zombies laufen lassen, um zu
bestätigen, welcher der beiden Kandidaten wirklich dominiert, statt am
falschen Ende zuerst zu optimieren — noch nicht gemacht, nächster Schritt
bei Fortsetzung.

## Spatial Grid + Zielsuche throttlen (2026-08-01, Punkt 2+3 der 21er-Liste)

Nutzer wollte den Godot-Profiler-Schritt (Punkt 1) überspringen — kein
GUI-Godot in dieser Umgebung verfügbar, und beide Fixes (Punkt 2+3) waren aus
der vorherigen Analyse ohnehin beide nötig, nur ihre Reihenfolge zueinander
war die eigentliche Profiler-Frage. Beides zusammen umgesetzt, siehe
[`zombies.md`](zombies.md), "Performance: Spatial Grid + Zielsuche
throttlen" für die Details.

- **Spatial Grid** (`World._zombie_grid`/`_rebuild_zombie_grid()`/
  `zombies_near()`): ersetzt die volle `"zombie"`-Gruppenabfrage in
  `Zombie._alert_nearby_zombies()` und
  `GuardPost._find_nearest_zombie()`/`_alert_nearby_zombies()`.
- **Zielsuche throttlen** (`Zombie.TARGET_SEARCH_INTERVAL := 0.2`):
  `_update_chase_target()` löst `_find_nearest_target()` nur noch alle 0.2s
  aus statt jeden Frame, mit zufälligem Start-Versatz pro Zombie.

**Noch nicht mit F9/500 Zombies nachgemessen** (kein laufender Godot-Editor
in dieser Umgebung — nur über statische Checks/Trap-Muster-Grep verifiziert).

**Fehler nach Nutzer-Test gefunden und behoben:** `GuardPost._find_nearest_zombie()`
hatte `var candidates := get_tree().current_scene.zombies_near(...)` — anders
als beim bekannten `max()`/`round()`-Trap-Muster lag es hier nicht an der
aufgerufenen Funktion selbst, sondern daran, dass `current_scene` als `Node`
typisiert ist; GDScript kennt `zombies_near()` darauf nicht statisch, der
Rückgabewert gilt als `Variant`, `:=` konnte den Typ nicht inferieren
(Warnung als Fehler, Spiel startete nicht). Fix: `var candidates: Array = ...`.
Die übrigen `zombies_near()`-Aufrufe (in `for`-Schleifen statt `var :=` in
`Zombie.gd`/`GuardPost._alert_nearby_zombies()`) sind von diesem Trap-Muster
nicht betroffen, per Grep geprüft.

**Nutzer-Nachtest:** 300 Zombies → 35–40 FPS, Ausschläge bis 40ms. Deutlich
besser als der alte 500-Zombie/15-FPS-Messwert, aber noch spürbar ruckelig.
Bei der Code-Durchsicht danach ein dritter, unabhängiger Kostenpunkt
gefunden und behoben: `Zombie._sync_state()`/`_update_color()` erzeugten
bisher jeden Frame für jeden Zombie ein neues `StandardMaterial3D`,
unabhängig davon, ob sich der HP-Wert geändert hatte — bei 300 Zombies 300
unnötige Material-Neuallokationen pro Frame. Fix: `_update_color()` nur noch
bei echter HP-Änderung aufgerufen, Material wird gecacht und nur noch
mutiert statt neu erzeugt. Ausführlich in [`zombies.md`](zombies.md),
"Performance: Material-Cache statt Neuallokation pro Frame".

**Vom Nutzer bestätigt nachgemessen:** 320 Zombies → 75 FPS, 17–20ms (vorher
bei nur 300 Zombies noch 35–40 FPS/bis 40ms). Alle drei Fixes (Spatial Grid,
Zielsuche-Throttling, Material-Cache) zusammen bestätigt wirksam — kein
offener Punkt mehr zu Punkt 2+3 der 21er-Liste.

## Zombie-Despawn (2026-08-01, Punkt 4 der 21er-Liste)

Direkte Fortsetzung nach dem bestätigten Performance-Erfolg (320 Zombies @
75 FPS) — nächster Punkt der Liste selbst gewählt, da der Deckel
(`MAX_ZOMBIES`) allein weiterhin nur durch Spielerkills sinkt, nie von
selbst. `World._despawn_far_zombies()` (host-seitig, alle 10s) despawnt
Wander-Zombies, die weiter als `ZOMBIE_DESPAWN_RADIUS` (300, bewusst groß
genug für eine ganze aktiv bespielte Stadt-Zone, siehe Herleitung in
zombies.md) von jeder lebenden Einheit/Home-Base/geclaimtem Gebäude entfernt
sind — kein echter Tod (kein Loot, `Zombie.despawn()` statt `take_damage()`).
Ausführlich in [`zombies.md`](zombies.md), "Zombie-Despawn".

**Noch nicht vom Nutzer getestet** — am ehesten sichtbar in einer nie
besuchten Stadt-Zone über mehrere Zombie-Nest-Spawnintervalle hinweg, in
einem kurzen Test kaum zu beobachten.

## Ressourcen-Nachwachsen + Städte größer (2026-08-01, Punkt 5 + Nutzerwunsch nebenbei)

Direkt im Anschluss an den Zombie-Despawn (Punkt 4) selbst weitergemacht mit
Punkt 5 der Liste, PLUS auf direkten Nutzerwunsch "die Städte größer machen"
im selben Zug (für den angekündigten nächsten FPS-Test).

**Ressourcen-Nachwachsen** (`World._regrow_resources()`, host-seitig, alle
`RESOURCE_REGROWTH_INTERVAL := 30.0`s): höchstens ein neuer Knoten pro
Ressourcentyp (Baum/Autowrack/Stein-/Ziegelhaufen), nie über die jeweilige
`*_TOTAL`-Konstante hinaus (dieselbe Obergrenze wie beim einmaligen
Anfangs-Spawn) — verhindert, dass lange Sessions die Karte komplett
leerernten, ohne unbegrenzt/explosiv nachzuwachsen. Bewusst NICHT dasselbe
Muster wie das früher entfernte Pro-Zonen-Ereignis-Nachwachsen (kein
Ereignis nötig, reiner Zeit-Tick). Ausführlich in [`world.md`](world.md),
"Kartenlayout".

**Städte größer:** `CITY_ZONE_RADIUS` 120→200 (+67%), `BUILDINGS_PER_ZONE`
24→40 (moderat mitskaliert, nicht quadratisch zur Fläche),
`ZOMBIE_SPAWN_RING_RADIUS` 180→260 (gleicher Randabstand wie vorher). Musste
`World.ZOMBIE_DESPAWN_RADIUS` (Punkt 4, gerade erst eingeführt) konsistent
mitziehen: 300→460, sonst hätte der Despawn-Fix Zombies in den jetzt
größeren Zonen fälschlich gelöscht. `CITY_ZONE_MIN_SPACING` (800) bleibt
unverändert, weiterhin deutlich über dem neuen Zonen-Durchmesser (400) —
keine Überlappungsgefahr zwischen Zonen.

**Nutzer-Nachtest (620 Zombies, größere Städte):** 37 FPS, 40–50ms.
Verglichen mit dem 320-Zombie-Messwert (75 FPS/17–20ms) jetzt näherungsweise
linear statt quadratisch — die drei vorherigen Fixes greifen, aber ein
vierter, unabhängiger Fund: `Zombie._sync_state.rpc()` lief weiterhin jeden
Frame für jeden Zombie, auch ganz ohne verbundenen Remote-Peer (Solo-Modus/
F9-Stresstest) — dort ist der komplette RPC-Dispatch reiner Leerlauf. Fix:
RPC wird jetzt übersprungen, solange `multiplayer.get_peers()` leer ist,
Farb-Update läuft dann direkt lokal bei echter HP-Änderung. Ausführlich in
[`zombies.md`](zombies.md), "Performance: RPC nur bei echten Remote-Peers".

**Nutzer-Nachtest:** 620 Zombies weiterhin 38–40 FPS/45–55ms, kaum
Veränderung ggü. dem Messwert vor diesem Fix. Auf Nutzerwunsch dafür jetzt
ein eigenes Messprotokoll angelegt (siehe [`benchmarks.md`](benchmarks.md))
statt weitere Einzelmessungen in diese Datei zu schreiben — künftige
Benchmark-Werte (Nutzer will "stichprobenartig" weitertesten, während an den
übrigen Listenpunkten weitergearbeitet wird) gehören dort hin, offene Fragen
zum RPC-Skip-Befund (Solo- vs. Multiplayer-Testaufbau) ebenfalls dort.

## Vehicle-Catch-up (2026-08-01, Punkt 6 der 21er-Liste)

Direkt weiter mit dem nächsten Listenpunkt: `_catch_up_vehicle()` sendete
bisher nur Position/HP an spät beitretende Peers, kein `owner_peer_id` —
ein schon besetztes Fahrzeug erschien beim neuen Peer zunächst als
unbesetzt. Jetzt behoben (`owner_peer_id` als vierter RPC-Parameter,
`_create_vehicle()` übernimmt ihn analog zu `Building.owner_peer_id`).
Ausführlich in [`vehicle.md`](vehicle.md), "Catch-up für owner_peer_id".

**Noch nicht vom Nutzer getestet.**

## Netzwerk-Sync bündeln (2026-08-01, Punkt 7 der 21er-Liste)

Nutzer wollte direkt weiter, hat vorab nachgefragt ob's "einfach oder mehr"
ist — Antwort: größerer Umbau als die vorherigen Punkte, deshalb bewusst
NUR für Zombies umgesetzt (höchste Entity-Zahl, größter Hebel), Survivor/
Vehicle behalten ihr eigenes Einzel-RPC unverändert (zu wenige Instanzen,
Bündeln würde sich dort nicht lohnen).

`Zombie.gd` verschickt kein eigenes RPC mehr — `World._sync_zombies_batch()`
sammelt einmal pro Frame `zombie_id`/`position`/`hp` aller Zombies in drei
`Packed*Array`s und verschickt sie gebündelt über
`World._apply_zombie_batch()` (`call_remote`, Solo weiterhin komplett
übersprungen). Zombies wenden empfangene Updates über die neue
`apply_synced_state()`-Methode an statt über ein eigenes RPC. Die
`"zombie"`-Gruppenabfrage in `World._process()` läuft dabei jetzt nur noch
einmal pro Frame (geteilt zwischen Spatial Grid und Batch-Sync statt zwei
getrennter Abfragen). Ausführlich in [`zombies.md`](zombies.md),
"Performance: Netzwerk-Sync bündeln statt Einzel-RPC pro Zombie".

**Wichtig für den nächsten Test:** dieser Fix wirkt sich nur im echten
Multiplayer-Fall aus (Solo profitiert schon vom vorherigen RPC-Skip-Fix) —
ein reiner Solo-F9-Test wird also keine Veränderung zeigen, siehe die offene
Frage in [`benchmarks.md`](benchmarks.md).

**Noch nicht vom Nutzer getestet.**

## Außenposten (2026-08-01, Punkt 8 der 21er-Liste)

Direkt weiter mit dem ersten Vision-Lücken-Punkt (aus `Infos/01
Architektur.md`, "Außenposten": "Kleine, unabhängige Bauten außerhalb der
Hauptzone, nur zum Rasten/Schlafen der Trupps — Ausnahme von der
Zusammenhang-Regel"). **Wichtige Abgrenzung vorab:** "Rasten/Schlafen"
bräuchte ein Müdigkeits-/Bedürfnissystem (Punkt 16, gibt's noch nicht) —
umgesetzt ist nur die zweite Vision-Funktion, ein kürzerer Rückweg beim
Scavenging ("Zwischenlagern" statt immer bis zur Basis).

Neuer Bautyp `BuildType.OUTPOST` + `scenes/entities/base/Outpost.gd`
(schlank wie `MedicalStation`, kein HP/Bautimer). Einziger Bautyp OHNE
Zonen-Prüfung (`_can_build_at()` bekam einen optionalen `type`-Parameter,
überspringt `is_within_own_zone()` nur für `OUTPOST`) — buchstäblich überall
platzierbar. Kein eigener Ressourcen-Pool: `Outpost.add_resources()` reicht
direkt an die Home-Base des Besitzers durch. `Survivor.
_find_nearest_drop_off_point()` läuft jetzt zum näheren von Home-Base/
eigenem Außenposten statt immer zur Basis. Ausführlich in
[`building.md`](building.md), "Außenposten", und
[`scavenging.md`](scavenging.md), "Rückweg + Ablieferung" (dort auch eine
veraltete Zeile zum längst gelösten Vehicle-Catch-up korrigiert).

**Testfortschritt:** siehe [`pending-tests.md`](pending-tests.md),
"Außenposten" — Bauen außerhalb der Zone vom Nutzer bestätigt (Punkt 1),
Rückweg/Ablieferung/Gegenprobe (Punkte 2-4) noch offen.

## Kartenansicht (2026-08-01, Punkt 11 der 21er-Liste, vorgezogen)

Nutzer wollte Punkt 11 (Vollbild-Kartenansicht) vorziehen, danach mit der
Liste normal weitermachen (Punkt 9 Rucksack-Item bleibt also noch offen).
Offene Design-Frage aus der ursprünglichen Planung (automatisch bei
`ZOOM_MAX` oder eigene Taste?) per Rückfrage geklärt: **eigene Taste**
(`KEY_M`).

Neue Szene `scenes/world/MapView.tscn`/`.gd` — strukturell wie die Minimap
(siehe [`world.md`](world.md), "Minimap"), aber deutlich größer (fast
Vollbild), per `M` ein-/ausblendbar, zusätzlich mit gelbem Rahmen um
Gebäude mit noch verfügbarem Loot (`is_looted == false`, aus der Vision:
"Icons... 'noch nicht geplündert' pro Gebäude"). Klick springt die Kamera
dorthin und schließt die Ansicht wieder ("Fast Travel"). Ausführlich in
[`world.md`](world.md), "Kartenansicht".

**Vom Nutzer bestätigt:** "passt das Grundmodel" — Backlog-Wunsch "später
sollten wir das schöner machen" vorgemerkt (siehe `world.md`, noch offen
was genau "schöner" heißen soll).

## Rucksack (2026-08-01, Punkt 9 der 21er-Liste)

Zurück zur normalen Reihenfolge nach der vorgezogenen Kartenansicht (Punkt
11). Vierter Ausrüstungsgegenstand nach Waffe/Rüstung/Helm, gleiches
schlankes Muster: `Survivor.has_backpack` + `order_equip_backpack()`,
verbraucht 1× neue Ressource `"backpack"` aus der Home-Base, kein Ablegen.
`carry_capacity()` (20 Basis + 10 Bonus mit Rucksack) ersetzt die frühere
feste `CARRY_CAPACITY`-Konstante als Quelle der Wahrheit — alle
Anzeigestellen in `World.gd` umgestellt. Neue Zeile im Trupp-Detailfenster,
`[B]`-Tag in der kompakten Liste, sechster möglicher Zombie-Loot-Typ.
Ausführlich in [`survivor.md`](survivor.md), "Rucksack".

**Nutzer-Feedback:** "ist ganz nett" — aber offene Design-Frage, ob ein
Rucksack wirklich ein knappes Ausrüstungsstück (aktueller Stand) oder
einfach eine automatische Basis-Erhöhung für alle Trupps sein soll, noch
nicht entschieden. Ausführlich in [`survivor.md`](survivor.md), "Rucksack",
"Offene Design-Frage" — bei der nächsten Session zuerst klären, bevor an
diesem Feature weitergebaut wird.

## Wald-Zonen (2026-08-01, Punkt 10 der 21er-Liste)

Nutzer wollte vorab meine Einschätzung, wie ich das umsetzen würde
("welche sind sinnvoll, wie würdest du das machen") — Vorschlag
(Wald-Zonen als zweiter Zonen-Typ, gleiches Cluster-Prinzip wie Stadt-
Zonen, dichtes Baumcluster + ein Jagdstand-Gebäude pro Zone, kein neues
Terrain) angenommen ("ja das passt so kannst machen").

Fünf Wald-Zonen (`FOREST_ZONE_COUNT`), platziert nach den Stadt-Zonen mit
gemeinsamem Mindestabstand-Check (`_is_far_from_zone_centers()`, ersetzt
die alte stadt-zonen-eigene Prüfung). Pro Zone 40 Bäume (~69× dichter als
die allgemeine Wildnis-Streuung) + ein Jagdstand (Munition/Waffen-Loot,
eigene feste Vorlage statt aus `BUILDING_TEMPLATES` gewürfelt). Ausführlich
in [`world.md`](world.md), "Kartenlayout".

**Direkt im Anschluss (Nutzerwunsch, "auf jeden Fall in die Notiz"):**
größeres offenes Vorhaben notiert — Nutzer will demnächst eine komplette
Kartenplanungs-Session machen (Weltgenerierung/Aufbau/Spawns/Aussehen als
Ganzes statt einzelner Ad-hoc-Schritte wie bisher). Siehe "Offenes großes
Vorhaben: komplette Kartenplanung" weiter unten in dieser Datei sowie
persistentes Memory `koopgame_map_planning_session`.

**Noch nicht vom Nutzer getestet.**

## Herstellen / Crafting-System, Stufe 1 (2026-08-01, Punkt 12 der 21er-Liste)

Erster Vision-Punkt jenseits der ursprünglichen 11er-Liste. Verwandelt die
bisher rein passive Werkstatt (nur Baurabatt) in eine echte Herstellungs-
Station: fünf feste Rezepte (`CRAFTING_RECIPES`), erzeugen genau die
Ausrüstungsgegenstände, die bisher nur über Zombie-Loot-RNG erreichbar
waren (Waffe/Rüstung/Helm/Rucksack/Munition) — kostet dafür Basis-Rohstoffe
(Holz/Metall/Stein). Kein Forschungsbücher-Gate (das ist Punkt 13). Neues
Panel `CraftingUI` (rechts, letzter freier Bildschirmbereich), sichtbar nur
mit eigener Werkstatt. Ausführlich in [`building.md`](building.md),
"Herstellen".

**Vom Nutzer bestätigt:** "crafting in der werkstatt hat soweit geklappt".

## Testkomfort: Start-Ressourcen temporär hochgesetzt (2026-08-01)

Nutzerwunsch: "am Anfang am besten von jeden 150, das ich bisschen testen
kann, später dann wieder ändern wenn wir richtung Ende kommen" —
`HomeBase.START_RESOURCES` alle elf Arten auf 150 (vorher food 30/wood 20/
metal 10/stone 20/brick 10/medicine 15/ammo 20/weapon,armor,helmet,
backpack je 1), `BASE_STORAGE_CAPACITY` dafür mit von 150 auf 300 angehoben
(sonst wäre der Lager-Deckel bei 150 Startbestand sofort erreicht gewesen).
**Explizit als temporär markiert, kein Balancing.** Ursprüngliche Werte
stehen als Kommentar in `HomeBase.gd`. Eigenes persistentes Memory
`koopgame_temp_test_resources` angelegt, damit der Rückbau vor Release
nicht vergessen wird — bitte aktiv ansprechen, sobald das Projekt Richtung
Fertigstellung/Balancing geht.

**Nachtrag, direkt im Anschluss an die Forschungsbücher (siehe unten):**
die fünf neuen `book_*`-Ressourcenarten wurden derselben temporären
Test-Regel unterworfen (ebenfalls 150 Startbestand) — normalerweise NUR
über seltenen Zombie-Loot erreichbar, hier zum bequemen Durchtesten des
kompletten Forschung→Freischaltung→Herstellen-Ablaufs ohne Zombie-Farmen.

## Forschungsbücher (2026-08-01, Punkt 13 der 21er-Liste)

Direkte Fortsetzung des Crafting-Systems (Punkt 12) — schließt die dort
schon angelegte Lücke ("Kein Forschungsbücher-Gate, das ist Punkt 13").
**Wichtige Abgrenzung:** nur das Vision-MVP (Bücher als seltener
Zombie-Loot), NICHT das dortige Endgame-Feature (Lesen am Survivor,
Buch-Kopieren über die Werkstatt).

- Fünf neue Ressourcenarten `book_weapon`/`book_armor`/`book_helmet`/
  `book_backpack`/`book_ammo`, eigener SELTENERER Drop-Wurf
  (`BOOK_DROP_CHANCE := 0.08`, unabhängig vom normalen Loot-Wurf) statt
  Teil der gleichgewichteten `ZOMBIE_LOOT_TABLE`.
- `HomeBase.unlocked_recipes` (dauerhaft) + `World.request_research()`
  (verbraucht 1× Buch, schaltet das passende Rezept frei, keine
  Werkstatt-Pflicht) + `request_craft()`-Erweiterung (prüft jetzt zuerst
  die Freischaltung).
- `CraftingUI`-Buttons haben jetzt drei Zustände: erforscht (normaler
  Herstellen-Button) / Buch vorhanden, noch nicht erforscht (Erforschen-
  Button) / weder noch (sichtbar, aber `disabled`).

Ausführlich in [`building.md`](building.md), "Forschungsbücher".

**Testkomfort-Ressourcen (siehe "Testkomfort" oben) um die fünf Bücher
erweitert** — alle testhalber schon im Startbestand, normalerweise nur
seltener Zombie-Loot.

**Noch nicht vom Nutzer getestet.**

## Kamera-Zoom-Bereich eingeschränkt (2026-08-01)

Nutzer hat einen Infection Free Zone-Screenshot verglichen — dort kommt
die Kamera nie so nah an einzelne Einheiten heran wie bei uns bisher
möglich war. `ZOOM_MIN` 4.0 → 10.0. Vorab geklärt: reine Stil-/Gameplay-
Entscheidung, KEINE Performance-Wirkung (kein LOD/keine Entfernungs-
basierte Simulationsdrosselung im Projekt, Zoom ist nur ein Kamera-Offset).
Nutzer bat explizit, "nah ran zoomen" im Hinterkopf zu behalten für später
— siehe persistentes Memory `koopgame_map_planning_session`. Ausführlich
in [`world.md`](world.md), "Kamera-Zoom-Bereich".

**Noch nicht vom Nutzer getestet.**

## UI-Overhaul, erste Stufe (2026-08-01)

Nutzerwunsch: "ein komplettes UI overhaul mit dropdown menu verschiedene
tabs etc bevor die koop handel oder rucksackslot oder sonstiges was ui
braucht" — auf die Liste gesetzt, VOR weiteren UI-lastigen Vision-Punkten
(Handel, Punkt 14). Design-Rückfrage gestellt (Tab-Panel unten + schlanke
Ressourcenleiste oben vs. andere Struktur) — Nutzer hat Tab-Panel bestätigt
("mach punkt 1 und ich sag dir dann was man ändern könnte").

Bauen/Herstellen/Einheiten (vorher drei separate `CanvasLayer`-Panels, je
eines pro Bildschirmecke) laufen jetzt als drei Tabs in einem gemeinsamen
Panel `MainTabsUI` (Godots `TabContainer`). Minimap in die dadurch freie
untere rechte Ecke nachgerückt. Ressourcen-Panel und Trupp-Detailfenster
bewusst UNVERÄNDERT gelassen (Ressourcen-Leiste wäre bei 16 Ressourcenarten
ein eigenes Layout-Problem, Detailfenster bleibt kontextabhängig, passt
nicht ins Tab-Schema). Noch kein "Handel"-Tab (Feature existiert noch
nicht, kein toter Platzhalter). Ausführlich in [`world.md`](world.md),
"UI-Overhaul".

**Erste Stufe — Nutzer wollte danach gezielt Detail-Feedback geben, noch
nicht final.** Noch nicht vom Nutzer getestet.

## Ressourcen-Panel kategorisiert (2026-08-01, erstes UI-Overhaul-Feedback)

Erstes konkretes Detail-Feedback nach dem UI-Overhaul: "rechts die
Ressourcen sind bisschen zu viele" — 16 Arten in einer Liste war
unübersichtlich. `RESOURCE_CATEGORIES` gruppiert sie in vier Labels:
Baurohstoffe, Überleben, Ausrüstung, Forschungsbücher. Panel dafür höher
und breiter. Ausführlich in [`world.md`](world.md), "Ressourcen-Panel
kategorisiert".

Nutzer hat dabei eine größere Idee angedacht (Holz → Holzplanken-
Veredelung über Crafting) — auf Rückfrage bewusst zurückgestellt, nur die
Panel-Gruppierung jetzt umgesetzt. Siehe persistentes Memory
`koopgame_resource_refinement_idea`.

**Nutzer bestätigt:** "ist besser". **Backlog-Wunsch für später:** lieber
zwei Tabs statt eines Dauer-Panels mit vier Kategorien — explizit "für
später", kein Auftrag jetzt. Noch nicht spezifiziert, welche zwei Gruppen.

## Notiz: Straßen/Fahrzeug-Pathing (2026-08-01)

Nutzer-Idee "Straßen für Autos als Pathing kann auch auf die Liste" —
Fahrzeuge fahren aktuell geradlinig zum Wegpunkt, keine Straßen-Geometrie/
kein Navigations-Mesh (siehe [`vehicle.md`](vehicle.md), "Bekannte
Grenzen"). Noch nicht spezifiziert, gehört thematisch zur Weltgenerierung
— bei der geplanten Gesamt-Kartenplanung mitbesprechen statt isoliert
vorher umsetzen. Siehe persistentes Memory `koopgame_map_planning_session`.

## Vision-Gap-Analyse: 4 neue Punkte 22-25 (2026-08-01)

Nutzerfrage: "was hab ich in der Vision noch was bei uns auf der Liste
fehlt" — kompletter Abgleich `Infos/01 Architektur.md`/`02 Item-Liste.md`
gegen die Gesamtliste. Vier Punkte bestätigt ("können sicher auf die
liste"), zwei niedriger priorisiert ("eher im Hinterkopf", kein fester
Listenplatz):

22. Geteilte Aufklärung (Fog of War zwischen Spielern) — einer der VIER
    von der Vision genannten Koop-Kanäle (Gemeinsame Gefahr ✓, Handel [14],
    Gegenseitige Verteidigung [20], Geteilte Aufklärung ✗) — bei der
    Minimap-Entscheidung (2026-07-31) zurückgestellt, nie wieder
    aufgegriffen.
23. Banditen-Fraktion (aus dem Vision-Ideen-Backlog) — kleine
    Restloot-Camps in bereits geplünderten Gebäuden.
24. Forschungsbücher erweitern: sollen laut Vision primär GEBÄUDE-
    Ausbaustufen freischalten (Stromgenerator, Wachturm-Beleuchtung,
    Garten-Anlage, Palisaden, erweiterte Krankenstation), nicht nur die
    aktuellen 4 Crafting-Rezepte (Punkt 13) — konzeptionelle Abweichung
    von der Vision, kein Bug.
25. Echter Wachturm mit Sichtweiten-Bonus — Vision trennt "Wachposten"
    (Kampf, = unser `GuardPost`) von "Wachturm" (Sicht/Früherkennung) als
    zwei separate Gebäude.

**Im Hinterkopf, kein fester Listenplatz:** Werkzeuge/Spezial-Ausrüstung
(Bohrmaschine, Sprengstoff, Nachtsichtgerät, Fernglas — eigene
Item-Kategorie mit Gameplay-Modifikatoren, komplett ungebaut) und
Stromgenerator als eigener Zonen-Bau.

Ausführlich im persistenten Memory `koopgame_next_steps_plan` (Punkte
22-25 + "Backlog im Hinterkopf"-Abschnitt).

## Rucksack-Design-Frage entschieden: kein Item, fester Bestand (2026-08-01)

Nutzerentscheidung zur offenen Design-Frage aus dem Rucksack-Abschnitt
oben (Punkt 9): "rucksack soll jeder ein haben also rucksack kein item
sonder ein fester bestand von den truppen" — die zweite der beiden
Optionen. Komplette Rückabwicklung der kurzzeitigen Slot-Item-Mechanik:

- `Survivor.gd`: `has_backpack`/`order_equip_backpack()`/
  `carry_capacity()` entfernt, wieder eine einzelne feste Konstante
  `CARRY_CAPACITY := 30` — direkt auf den vorherigen "mit Rucksack"-Wert
  gesetzt statt zurück auf 20, gilt automatisch für jeden Trupp.
- `World.gd`: `"backpack"` aus `ZOMBIE_LOOT_TABLE`/`ZOMBIE_LOOT_AMOUNT`/
  `BRUTE_LOOT_AMOUNT` entfernt (wieder fünf Loot-Typen), `"book_backpack"`
  aus `BOOK_TABLE` entfernt (wieder vier Bücher), Backpack-Rezept aus
  `CRAFTING_RECIPES` entfernt (wieder vier Rezepte), Backpack-Einträge aus
  `RESOURCE_DISPLAY_NAMES`/`RESOURCE_CATEGORIES` entfernt, Rucksack-Zeile +
  Anlegen-Button im Trupp-Detailfenster entfernt, alle
  `survivor.carry_capacity()`-Aufrufe zurück auf `survivor.CARRY_CAPACITY`.
- `HomeBase.gd`: `"backpack"`/`"book_backpack"` aus `START_RESOURCES`
  entfernt (wieder 14 Ressourcenarten).
- `World.tscn`: `BackpackRow`-Node-Block im Trupp-Detailfenster entfernt,
  Panel wieder auf die ursprüngliche Höhe geschrumpft.

Betrifft nur die Rucksack-Umsetzung, keine anderen Systeme. Dokumentation
([`survivor.md`](survivor.md), [`building.md`](building.md),
[`base.md`](base.md), [`zombies.md`](zombies.md), [`world.md`](world.md),
[`pending-tests.md`](pending-tests.md)) entsprechend nachgezogen.

## Punkt 15 zurückgestellt, Handel umgesetzt (2026-08-01)

Nutzerfrage zu Punkt 15 (Survivor-Rollen): "bin mir nicht sicher ob das
wirklich so sinnvoll ist bzw. was soll das dann bewirken". Erklärung laut
Vision (nur passive Boni, kein Zwang) gegeben, Einschätzung: bei aktuell
kleinen Truppzahlen eher kosmetisch als taktisch relevant, lohnt sich erst
bei deutlich mehr Survivor. Nutzer stimmte zu: Punkt 15 nach hinten
verschieben (nach Punkt 21), stattdessen direkt mit Punkt 14 (Handel)
weitermachen.

## Handel (2026-08-01, Punkt 14 der Gesamtliste)

Vision gibt nur eine kurze Vorgabe ("Spieler können Ressourcen
untereinander tauschen/geben"). Rückfrage: einseitiges Schenken oder
echtes Tausch-Angebot mit Bestätigung? Nutzer wollte **beides**. Neuer
vierter Tab "Handel" in `MainTabsUI` (der `TabContainer`-Umbau war laut
eigenem Kommentar von Anfang an im Hinblick auf Handel gemacht worden):

- **Schenken:** Ziel-Spieler + Ressource + Menge wählen, sofortige,
  einseitige Übergabe ohne Bestätigung (`request_gift_resources()`).
- **Tauschen:** "Ich gebe" gegen "Ich will" als Angebot an einen
  bestimmten Spieler senden (`request_create_trade_offer()`), der es
  annehmen (`request_accept_trade_offer()`, tauscht beide Seiten
  gleichzeitig, mit erneuter Bestandsprüfung zum Annahme-Zeitpunkt) oder
  ablehnen kann (`request_decline_trade_offer()`, auch vom Ersteller zum
  Zurückziehen nutzbar).
- **`World._trade_offers`**: nur auf dem Host die Quelle der Wahrheit, per
  Broadcast-RPC an alle Peers gespiegelt (gleiches Muster wie
  Status-Meldungen) — bewusst kein Catch-up für spät beitretende Peers,
  keine Speicherstand-Persistenz (kurzlebiger Zwischenzustand, gleiche
  Vereinfachung wie bei `HomeBase.unlocked_recipes`).

Ausführlich in [`trading.md`](trading.md). **Vom Nutzer bestätigt
getestet (2026-08-01):** "passt tauschen und schenken funktioniert" —
Detail-Teilschritte (Ablehnen, Sonderfälle bei zu wenig Ressourcen) siehe
[`pending-tests.md`](pending-tests.md).

## Gesamt-Liste: 25 Punkte, Performance + Vision-Lücken (2026-07-31 begonnen, 22-25 am 2026-08-01 aus der Vision-Gap-Analyse ergänzt)

Zwei Listen aus derselben Session zu einer Gesamt-Liste zusammengeführt
("pack die 20 Punkte auch auf die Liste"): Punkte 1–11 sind die
ursprüngliche, vom Nutzer bestätigte Performance-Liste (Reihenfolge fix,
sequenziell abarbeiten). Punkte 12–21 sind der anschließende
Vision-Abgleich (aus `vault/01 Architektur.md`/`02 Item-Liste.md`
abgeleitet) — Backlog-Vorschlag, Reihenfolge untereinander noch nicht
einzeln bestätigt, aber jetzt Teil derselben Liste. Ersetzt die vorherigen
zwei getrennten Abschnitte. Jeder Punkt hat einen Task (#30–#50, siehe
Task-Liste) zum Wiederaufnehmen.

1. ⬜ Godot-Profiler bei 500 Zombies (Task #30) — auf Nutzerwunsch
   übersprungen (kein GUI-Godot verfügbar), da Punkt 2+3 ohnehin beide nötig
   waren, siehe "Spatial Grid + Zielsuche throttlen" oben.
2. ✅ Spatial Grid für Zombie-Nachbarschaftssuche (Task #31) — umgesetzt UND
   vom Nutzer bestätigt getestet (320 Zombies @ 75 FPS, siehe "Spatial Grid +
   Zielsuche throttlen" oben).
3. ✅ Zielsuche throttlen (Task #32) — umgesetzt UND vom Nutzer bestätigt
   getestet, siehe oben. Beim Nachtest zusätzlich ein dritter Kostenpunkt
   gefunden+behoben (Material-Cache, siehe "Performance: Material-Cache"
   in zombies.md).
4. ✅ Zombie-Despawn für alte, weit entfernte Wander-Zombies (Task #33) —
   umgesetzt, siehe "Zombie-Despawn" oben. Noch nicht vom Nutzer getestet.
5. ✅ Gedeckeltes, langsames Ressourcen-Nachwachsen (Task #34) — umgesetzt,
   siehe "Ressourcen-Nachwachsen + Städte größer" oben. Noch nicht vom
   Nutzer getestet.
6. ✅ `Vehicle.owner_peer_id`-Catch-up für spät beitretende Peers
   (Task #35) — umgesetzt, siehe "Vehicle-Catch-up" oben. Noch nicht vom
   Nutzer getestet.
7. ✅ Netzwerk-Sync bündeln statt Einzel-RPC pro Entity (Task #36) — nur für
   Zombies umgesetzt (Umfang bewusst begrenzt, siehe "Netzwerk-Sync
   bündeln" oben). Vom Nutzer im echten Multiplayer getestet (670 Zombies,
   beide Clients, ~40 FPS/40-50ms, siehe `benchmarks.md` Zeile
   2026-08-01e) — funktioniert grundsätzlich, Frametime-Schwankung noch
   ungeklärt (siehe dort, "Offene Fragen").

**Alle 7 Performance-Punkte umgesetzt.** Weiter mit den Vision-Lücken
(Punkte 8-21).
8. ✅ Außenposten-System aus der Vision (Task #37) — umgesetzt (nur
   Rückweg-Funktion, "Rasten" braucht erst Punkt 16), siehe "Außenposten"
   oben. Testfortschritt siehe [`pending-tests.md`](pending-tests.md).
9. ✅ Rucksack/`CARRY_CAPACITY`-Erhöhung (Task #38) — zunächst als Item
   umgesetzt, dann per Nutzerentscheidung wieder zurückgebaut: fester
   Bestand jedes Trupps (`CARRY_CAPACITY := 30`), kein Ausrüstungsstück.
   Siehe "Rucksack-Design-Frage entschieden" oben.
10. ✅ Biome/Wald-Zonen (Task #39) — umgesetzt, siehe "Wald-Zonen" oben.
    Noch nicht vom Nutzer getestet.
11. ✅ Vollbild-Kartenansicht (Task #40, Vorbild: Infection Free Zone) —
    umgesetzt, eigene Taste (`M`) statt automatisch bei `ZOOM_MAX` (Design-
    Frage per Rückfrage geklärt), siehe "Kartenansicht" oben. Vorgezogen
    (vor Punkt 9/10) auf Nutzerwunsch. Noch nicht vom Nutzer getestet.
12. ✅ Crafting-System (Task #41) — Stufe 1 umgesetzt (5 feste Rezepte,
    kein Forschungs-Gate), siehe "Herstellen" oben. Vom Nutzer bestätigt
    getestet.
13. ✅ Forschungsbücher/Tech-Freischaltungen (Task #42) — umgesetzt (Gate
    fürs Crafting-System, Punkt 12), siehe "Forschungsbücher" oben. Noch
    nicht vom Nutzer getestet.
14. ✅ Handel zwischen Spielern (Task #43), 2026-08-01 — Schenken UND
    echtes Tausch-Angebot, siehe "Handel" unten. Vom Nutzer bestätigt
    getestet: "passt tauschen und schenken funktioniert".
15. ⬜ Survivor-Rollen (Sammler/Wache/Arzt/Baumeister) mit passiven Boni
    (Task #44). **Zurückgestellt** (Nutzer unsicher, ob bei aktuell
    kleinen Truppzahlen sinnvoll) — nach Punkt 21 einordnen.
16. ⬜ Bedürfnisse Müdigkeit + Moral (Task #45, aktuell nur Hunger), inkl.
    Betten-Mechanik.
17. ⬜ Differenzierte Gebäudetypen mit echten Loot-Tabellen (Task #46)
    statt generischer `BUILDING_TEMPLATES`.
18. ⬜ Erweitertes Waffen-/Rüstungs-Progressionssystem (Task #47,
    Haupt+Sekundärwaffe, mehrere Rüstungsteile) statt binärem
    1-Slot-System.
19. ⬜ Differenzierte Fahrzeugtypen (Task #48, Fahrrad/Motorrad/Jeep/Van/
    Pickup).
20. ⬜ Gegenseitige Verteidigung/Hilfe zwischen Spielern (Task #49).
21. ⬜ Blutmond-Kalender-Eskalation (Task #50, Horde-Nächte aktuell
    konstant groß).
22. ✅ Geteilte Aufklärung (Fog of War zwischen Spielern), 2026-08-01 —
    siehe "Fog of War" oben, einer der vier Vision-Koop-Kanäle, bei der
    Minimap-Entscheidung zurückgestellt, jetzt in der Kartenplanungs-
    Session nachgeholt. Vom Nutzer mit zwei Clients bestätigt getestet.
23. ⬜ Banditen-Fraktion — kleine Restloot-Camps in bereits geplünderten
    Gebäuden (aus dem Vision-Ideen-Backlog).
24. ⬜ Forschungsbücher erweitern: Gebäude-Ausbaustufen statt/zusätzlich zu
    den aktuellen Crafting-Rezepten (Punkt 13) freischalten.
25. ⬜ Echter Wachturm mit Sichtweiten-Bonus, getrennt vom kampforientierten
    `GuardPost`.

**Playable-Schätzung (ohne Assets/Playtesting):** Die 4 MVP-Säulen der
Vision selbst (Basis/Ressourcen, Zombies/Verteidigung, Scavenging,
Survivor-Rollen+Bedürfnisse) sind zu ~70–80% funktional abgedeckt — die
ersten drei Säulen sind sehr weit, die vierte (Rollen/Bedürfnisse, Punkte
15/16 oben) am schwächsten. Gemessen an der VOLLEN Vision (Item-/
Crafting-/Forschungs-/Handelssystem, Punkte 12–14/17–19) sind es eher
~20–30%. Alle 3D-Assets sind weiterhin Platzhalter-Boxen (0%).

**Vault synchronisiert:** `vault/Claude code/*.md` (manueller Spiegel von
`docs/*.md`, war seit mehreren Sessions veraltet) komplett neu kopiert;
`vault/00 Übersicht.md` und `vault/01 Architektur.md` hatten stark
veraltete "Stand"-Absätze (noch vom Projektstart 29.07.) — auf aktuellen
Stand gebracht bzw. auf `status.md` verwiesen. Ausführlich in
persistentem Memory `koopgame-vision-docs`/`koopgame-next-steps-plan`.

## Kartenplanungs-Session gestartet (2026-08-01)

Das seit Längerem vorgemerkte "eigene Session nur für die Karte als
Ganzes" (Weltgenerierung, Kartenaufbau, Spawns, Aussehen/Look) hat
begonnen, ausgelöst durch die Straßen/Gebäudereihen-Frage (Vergleich mit
Infection Free Zone). Drei Grundsatzfragen geklärt:

1. **Zonen-Verteilung:** statt fünf gleich großer Stadt-Zonen jetzt ZWEI
   Größen — 2 große + 3 kleine (Nutzerwunsch "statt eine große mehrere
   eine kleine da zwei große"). Umgesetzt, siehe "Straßen-Raster +
   Gebäudereihen" unten.
2. **Terrain-Relief:** bleibt vorerst flach (Nutzer: "erstml punkt 1
   machen") — Höhenrelief-Idee als Backlog-Punkt in persistentem Memory
   `koopgame_map_planning_session` vorgemerkt, kein aktueller Auftrag.
3. **Fog of War:** wird eingeführt (Punkt 22 der Gesamtliste, "Geteilte
   Aufklärung") — noch nicht umgesetzt, nächster Schritt dieser Session.

## Straßen-Raster + Gebäudereihen (2026-08-01, Kartenplanungs-Session)

Städte bekommen jetzt eine echte Blockstruktur statt Zufallsstreuen — 2
große Stadt-Zonen (Radius 260, 60 Gebäude) + 3 kleine (Radius 150, 30
Gebäude) statt fünf gleich großer (Radius 200, je 40). `_generate_city_
zone()` platziert Gebäude über ein neues Straßen-Raster
(`_generate_street_slots()`: quadratische Blöcke, 24m Kante, 10m
Straßenbreite dazwischen, Gebäude in Reihen entlang der Blockkanten) statt
über reines Zufallsstreuen (`_spaced_position()`) — liefert absichtlich
weit mehr Reihenplätze als gebraucht, davon wird nur die Ziel-Gebäudezahl
zufällig ausgewählt (Rest bleibt Lücke). Gesamt-Gebäudezahl bleibt nah am
vorherigen Wert (210 statt 200) — keine Mehrbelastung für Performance,
nur die Anordnung ist jetzt geordnet statt zufällig. `ZOMBIE_DESPAWN_
RADIUS` für den neuen größten Fall neu hergeleitet (460→580). Ausführlich
in [`world.md`](world.md), "Straßen-Raster + Gebäudereihen".

**Bewusst NICHT enthalten** (eigene Folgeschritte): sichtbare Straßen-
Geometrie (Asphalt-Look) und echtes Fahrzeug-Pathing entlang der Straßen
— reine Positions-/Layout-Änderung in dieser Stufe. **Vom Nutzer
bestätigt (2026-08-01):** "passt soweit häuser sind bischen zu weit
auseinander aber das kann man später ändern" — Dichte-Feinschliff als
Backlog vorgemerkt (`docs/pending-tests.md`), kein Auftrag jetzt.

## Fog of War (2026-08-01, Punkt 22 der Gesamtliste, Kartenplanungs-Session)

Direkte Fortsetzung der Kartenplanungs-Session — dritte der drei
Grundsatzfragen ("Einführen", siehe oben). Vision: "Geteilte Aufklärung —
entdeckte Kartenbereiche werden zwischen Spielern geteilt", einer der vier
Vision-Koop-Kanäle, bei der Minimap-Entscheidung (2026-07-31)
zurückgestellt, jetzt nachgeholt.

- **Kein neuer Netzwerk-Zustand:** `World._explored_cells` wird auf JEDEM
  Peer unabhängig lokal aus schon replizierten Positionen berechnet (alle
  `"living"`-Einheiten + Home-Bases, ALLER Spieler) — "geteilt" entsteht
  automatisch, weil alle Peers dieselben synchronisierten Positionen
  sehen, ganz ohne zusätzliche RPC.
- Rasterbasiert (`FOG_CELL_SIZE := 100.0`, 50×50 Zellen), Sichtradius
  `FOG_VISION_RADIUS := 130.0` um jede Einheit/Home-Base, dauerhaft
  aufgedeckt (kein Vergessen).
- Minimap + Kartenansicht zeichnen einen deckenden Nebel-Layer über allen
  Symbolen (außer dem Kamera-Marker, bleibt immer sichtbar).
- **Bewusst kein** Fog of War in der 3D-Kamera-Ansicht (nur Minimap/
  Kartenansicht — die begrenzte Zoom-Reichweite übernimmt dort schon eine
  ähnliche Funktion), kein Catch-up für spät beitretende Peers, keine
  Speicherstand-Persistenz (Nebel füllt sich schnell nach).

Ausführlich in [`world.md`](world.md), "Fog of War". **Vom Nutzer
bestätigt getestet (2026-08-01, mit zwei Clients):** "passt mit beiden
spielern".

## Straßen-Geometrie (2026-08-01, Kartenplanungs-Session, Fortsetzung)

Direkte Fortsetzung nach dem Straßen-Raster-Umbau (Gebäude standen zwar
in Reihen, aber die Straßen selbst waren noch unsichtbar). Neuer Broadcast
`World._sync_city_zones()` verteilt `_city_zone_centers` jetzt auch an
Clients (vorher nur host-intern bekannt) — jeder Peer baut daraus lokal,
aber deterministisch identisch dieselben Straßen-Meshes
(`_build_street_visuals()`/`_build_zone_streets()`/
`_add_street_segment()`): flache, dunkle `BoxMesh`-Streifen zwischen
benachbarten Blöcken des schon bestehenden Straßen-Rasters, ohne
Collision, ohne `MultiplayerSpawner` (deterministisch aus Zonen-Zentrum +
Radius, keine Zufallskomponente wie bei der Gebäude-Auswahl). Catch-up für
spät beitretende Peers über dieselbe RPC (`.rpc_id()` in
`_spawn_for_peer()`).

**Bewusst NICHT enthalten:** Kreuzungs-Füllstücke an 4-Wege-Ecken (kleine
kosmetische Lücke, akzeptiert) und echtes Fahrzeug-Pathing entlang der
Straßen (letzter noch offener Punkt der Kartenplanungs-Session).

**Bug + Fix (2026-08-01, Nutzer-Report):** "nur bei einem spieler werden
strasen angezeigt" — die ursprüngliche Umsetzung schickte
`_city_zone_centers` per Host-Broadcast (`.rpc()`) direkt in `_ready()`,
kam beim langsameren Client zu früh an (dessen `World`-Node existierte
noch nicht im Netzwerk-Baum, das RPC-Paket ging spurlos verloren — kein
Puffern beim High-Level-Multiplayer). **Fix:** umgedreht auf PULL —
Client fragt beim Host an, sobald sein eigenes `_ready()` läuft
(`request_city_zones.rpc_id(1)`), Host antwortet gezielt zurück. Deckt
Frisch-Start UND spätes Beitreten einheitlich ab. Ausführlich in
[`world.md`](world.md), "Straßen-Geometrie". **Vom Nutzer bestätigt
getestet (2026-08-01, nach dem Fix):** "passt geht bei beiden".

## Fahrzeug-Pathing (2026-08-01, Kartenplanungs-Session, letzter offener Punkt)

Der ursprüngliche Auslöser der ganzen Kartenplanungs-Session ("Straßen
für Autos als Pathing kann auch auf die Liste") ist damit umgesetzt.
Bewusst KEIN `NavigationServer3D`/gebackenes Navigationsmesh — stattdessen
ein simpler Wegpunkt-Graph aus denselben Blockraster-Daten, die schon für
die Straßen-Sicht-Geometrie existieren (`_compute_zone_blocks()`, aus
`_build_zone_streets()` herausgelöst).

- **`World.find_vehicle_path(from, to)`**: liegt das Ziel in einer
  Stadt-Zone, wird der kürzeste Weg über die Block-Mittelpunkte per BFS
  gesucht (jede Kante gleich lang, kein gewichtetes A* nötig) und als
  Wegpunkt-Liste zurückgegeben — sonst (Wildnis, keine Straßen-Daten)
  bleibt es bei der bisherigen Luftlinie.
- **`Vehicle.order_move()`** nutzt das jetzt statt den Zielpunkt direkt
  als einzigen Wegpunkt zu setzen — der bestehende `_waypoints`-
  Mechanismus selbst bleibt unverändert, bekommt nur mehr Zwischenpunkte.
- **Bewusst NICHT enthalten:** echtes Umfahren von Gebäuden (Fahrzeuge
  kollidieren weiterhin nur mit Mauern/Toren, letztes Wegstück zum Ziel
  bleibt Luftlinie), Pathing für Trupps zu Fuß, Verkehrsregeln.

Ausführlich in [`world.md`](world.md), "Fahrzeug-Pathing". **Noch nicht
vom Nutzer getestet**, siehe [`pending-tests.md`](pending-tests.md).

## Straßen-Kacheln: GridMap statt BoxMesh-Streifen (2026-08-02)

Direkte Fortsetzung von "Fahrzeug-Pathing" oben — Nutzer wollte statt der
prozeduralen `BoxMesh`-Straßenstreifen echte, selbst in Blender gebaute
Kachel-Assets über Godots `GridMap`-Node einsetzen ("dann bau ich die paar
tiles"). Plan im Plan-Modus erstellt und freigegeben, dauerhafte
Zusammenfassung im persistenten Memory
`koopgame_street_tiles_assets`/`koopgame_map_planning_session`.

Nutzer hat 5 Tiles gebaut (`grass`/`road_straight`/`road_corner`/`road_t`/
`road_cross`, je 12m×12m×0,2m, siehe `Infos/04 Straßen-Kacheln
Modellier-Referenz.md`). Eine zusätzliche `Straßeneinfahrt.glb` (späterer
Parkplatz-Baustein) existiert, ist aber bewusst NICHT Teil dieser
`MeshLibrary`.

**Code-Umbau umgesetzt** (siehe [`world.md`](world.md), "Straßen-Geometrie"
für Details):
- `World.STREET_TILE_SIZE`/`BLOCK_TILES` neue Basiskonstanten,
  `STREET_BLOCK_SIZE`/`STREET_WIDTH`/`STREET_CELL_SIZE` jetzt daraus
  abgeleitet (`STREET_CELL_SIZE` dadurch 36m statt vorher 34m).
- `$StreetGridMap` (`World.tscn`) ersetzt den früheren `Streets`-Node3D.
- `_pick_zone_center()` snappt jetzt aufs Kachelraster
  (`_snap_to_tile_grid()`), sonst würden Straßen-Kacheln nicht exakt auf
  die Gebäude-Reihen passen.
- `_build_zone_street_tiles()`/`_place_street_tile()` ersetzen
  `_build_zone_streets()`/`_add_street_segment()` — Nachbarschafts-Bitmaske
  pro Straßen-Kachel wählt automatisch die passende Form + Rotation, löst
  dabei nebenbei die früher akzeptierte Kreuzungs-Lücke auf.
- **Ein Fehler beim Implementieren selbst gefunden und behoben:** Code rief
  ursprünglich `MeshLibrary.find_item_by_name()` auf — diese Methode
  existiert in Godot 4 vermutlich gar nicht (nur `get_item_list()`/
  `get_item_name()` sind dokumentiert), hätte also einen stillen
  Skriptfehler verursacht. Ersetzt durch eigene `_find_mesh_library_item()`.

**Rotationsrichtung rechnerisch hergeleitet, noch NICHT in Godot
verifiziert** — falls beim Testen eine Kachel verdreht aussieht: welche
Form + welche Richtung falsch ist melden, Korrektur ist eine einzeilige
Änderung (siehe `world.md`), kein Neu-Modellieren.

**Lange MeshLibrary-Fehlersuche (2026-08-02, nachts):** "Szene → In
umwandeln → MeshLibrary" im Godot-Editor hat sich als Sackgasse erwiesen:
1. Erste Versuche lieferten `Cube`/`Cube_001`/... statt der gewünschten
   Namen — Ursache: die Kacheln bestanden in Blender noch aus mehreren
   einzelnen Objekten statt einem (Fix: pro Datei Strg+J zum Verschmelzen).
2. Godot übernimmt beim Konvertieren den Blender-**Mesh-Datenblock-Namen**
   (nicht Objekt-/Node-Namen) — stand bei allen noch auf Blenders Default
   `"Cube"` (Fix: in Blender im Objektdaten-Tab umbenannt).
3. Selbst danach hat die GUI-Konvertierung wiederholt Items verschluckt
   (`road_cross` fehlte zweimal in Folge) bzw. alte Items aus früheren
   Versuchen angesammelt statt ersetzt (bis zu 20+ Items in der Datei).
   Ursache nicht abschließend geklärt.
- **Fix:** eigenes Werkzeug-Skript `tools/fix_meshlib_names.gd`
  (`@tool extends EditorScript`) baut `street_tiles.meshlib` jetzt direkt
  aus den 5 `.glb`-Dateien zusammen (lädt jede, sucht das erste
  `MeshInstance3D`, vergibt die Item-Namen hart codiert) — komplett
  unabhängig von der fehleranfälligen GUI-Konvertierung. Behebt dabei
  nebenbei einen Tippfehler (`road_coner.glb`-Dateiname), weil der
  Item-Name im Skript fest steht statt vom Mesh übernommen zu werden.

**Update (2026-08-02, nach dem ersten echten F5-Test):** drei weitere
Bugs gefunden und behoben, siehe `world.md` ("Straßen-Geometrie") für die
Details — (1) `World.tscn` zeigte auf `street_tiles.meshlib`, erzeugt
wurde aber nur die falsch benannte `street_tails.meshlib`, `mesh_library`
blieb dadurch `null` und keine Straße erschien; (2) die vier `road_*.glb`
haben ihren Ursprung Y-mittig statt unten, dadurch versanken die Kacheln
unter der Boden-Ebene; (3) `road_straight`s Ost-West/Nord-Süd-Zuordnung
war (entgegen dem Bildvergleich vom Vortag) vertauscht, per Vertex-Daten
verifiziert und korrigiert. Vom Nutzer im echten Spiel bestätigt ("passt
perfekt"). Siehe persistentes Memory `koopgame_street_tiles_assets` für
die kompakte Lessons-Learned-Fassung.

**Noch nicht vom Nutzer getestet**, siehe
[`pending-tests.md`](pending-tests.md).

## Ecken/T-Stücke der Straßen-Kacheln korrigiert (2026-08-02, nach Nutzer-Screenshot)

Nutzer meldete per Screenshot (`bilder/ecken sind falsch.PNG`): Ecken
falsch ausgerichtet. Ursache: `road_corner`/`road_t` waren in
`_place_street_tile()` nur geraten, nie per Vertex-Daten verifiziert
(anders als `road_straight`, siehe oben). Neues Diagnose-Tool
`tools/inspect_road_shapes.gd` (Vertex-Schwerpunkt-Berechnung) zeigte:
beide Modelle sind nativ exakt 180° gegenüber der Code-Annahme verdreht.
Fix: `rotation_steps` in beiden Zweigen um 2 (mod 4) verschoben.
Ausführlich in [`world.md`](world.md), "Straßen-Geometrie". **Vom Nutzer
bestätigt getestet:** "passt sind jetzt richtig". Siehe
`docs/pending-tests.md` für den abgehakten Punkt.

## Fahrzeug-Pathing fuhr über Gras statt Straße (2026-08-02, Nutzer-Report)

Nutzer meldete direkt im Anschluss: "er fährt über das gras anstatt über
die straße". Ursache: `find_vehicle_path()` pathete seit dem
Kachel-Umbau (siehe oben) immer noch über die alten Block-MITTEN
(36m-Raster, aus `_compute_zone_blocks()`) statt über die tatsächlichen
12m-Straßen-Kacheln — ein Block ist nur 24m breit, die direkte Linie
zwischen zwei Block-Mitten verlief dadurch zu zwei Dritteln durchs
Blockinnere (Gras), nur zu einem Drittel auf der Straße. Fix: neue
`World._zone_street_tiles()` (aus `_build_zone_street_tiles()`
herausgelöst) liefert dieselben Kachel-Positionen wie die sichtbare
Straßen-Geometrie, `find_vehicle_path()`/`_nearest_street_tile()`/
`_bfs_grid_path()` pathen jetzt direkt über diese Kacheln. Ausführlich in
[`world.md`](world.md), "Fahrzeug-Pathing".

**Zweiter Fehler direkt danach:** Nutzer meldete "ein bisschen versetzt
ist er noch" — die neuen Wegpunkte hatten einen systematischen halben
Kachel-Versatz (6m) gegenüber der tatsächlich sichtbaren Kachel-Position,
weil `$StreetGridMap`s `cell_center_x`/`cell_center_z` (Godot-Standard
`true`) jede Kachel gegenüber der rohen `center + tile*STREET_TILE_SIZE`-
Rechnung verschieben, genau wie es `_zone_tile_cell()` für die
Sicht-Geometrie schon ausgleicht — die neuen Pathing-Funktionen taten das
zunächst nicht. Fix: neue gemeinsame `_street_tile_world_pos()`-Funktion
(exakt dieselbe Formel wie `_zone_tile_cell()`), von `_nearest_street_
tile()` und der Wegpunkt-Umrechnung gemeinsam genutzt. **Vom Nutzer
bestätigt getestet:** "passt fährt genau auf der straße" — damit ist die
komplette Kartenplanungs-Session (siehe `koopgame_map_planning_session`-
Memory) inklusive ihres Kachel-Nachtrags abgeschlossen. **Backlog, kein
Bugfix** (Nutzer: "parken ist bissle ungenau aber das kann man später
machen wenn die assets kommen"): Einparken am Zielpunkt ungenau, da das
letzte Wegstück bewusst Luftlinie bleibt — voraussichtlich gelöst, sobald
die zurückgestellte `Straßeneinfahrt.glb`/Parkplatz-Kachel eingebaut wird.

**Weiter mit Punkt 16 der Gesamt-Liste** (`koopgame_next_steps_plan`-
Memory): Bedürfnisse Müdigkeit + Moral, Betten-Mechanik (Task #45) — Punkt
15 (Survivor-Rollen) bleibt weiterhin auf Nutzerwunsch zurückgestellt.

## Bedürfnisse: Müdigkeit + Moral, Betten-Mechanik (2026-08-02, Punkt 16 der Gesamtliste)

**Überraschender Fund beim Einstieg:** ein Teil dieses Punkts lag schon
als angefangenes, aber unvollständiges Gerüst im Code (`Bed.gd`/
`Bed.tscn`, `BuildType.BED`, `BED_COST`, `upgrade_bed_button` in der UI,
Spawner/Container) — vermutlich aus einer früheren, nicht zu Ende
geführten Session, weder in `status.md` noch `koopgame_next_steps_plan`
vermerkt. Das Gebäude-Gerüst selbst war sauber und konsistent zum
bestehenden `MedicalStation.gd`-Muster, aber nirgends fertig verdrahtet:
`_cost_for_build_type()`/`request_upgrade_building()` kannten
`BuildType.BED` nicht (fielen auf Wachposten-Kosten UND das falsche
Gebäude zurück), kein Catch-up, kein Speicherstand-Eintrag — und auf
`Survivor.gd` gab es überhaupt keine Müdigkeits-/Moral-Variablen, das
eigentliche Bedürfnissystem fehlte komplett.

**Komplettiert statt neu gebaut:**
- Bett-Verdrahtung fertiggestellt: Kosten-Lookup, Ausbauen-Match,
  `_catch_up_bed()`, Speicherstand (Sammeln + Laden + `next_ids`),
  `_refresh_building_upgrade_ui()` zeigt den Button jetzt tatsächlich an.
- Neues Survivor-Bedürfnissystem: `fatigue`/`morale` (Start 100, fallen
  linear wie Hunger, aber langsamer), Regeneration NUR am eigenen
  Schlafraum (`_handle_resting()`, `BED_REST_RADIUS` 5.0) — bewusst KEINE
  Home-Base-Grundrate, das ist laut Vision der ganze Sinn der
  Betten-Mechanik. Niedrige Müdigkeit bremst die Bewegung
  (`FATIGUE_SPEED_FACTOR` 0.7, kombiniert sich mit Hunger-/
  Rüstungs-Malus), niedrige Moral schwächt den Angriffsschaden
  (`MORALE_DAMAGE_FACTOR` 0.7, nur der proaktive Angriffsbefehl, nicht
  der passive Zombie-Gegenschaden).
- Replikation (`_sync_state()`), Speichern/Laden (mit Fallback-Default
  100 für ältere Spielstände), UI (kompakte Trupp-Liste,
  Trupp-Detailfenster, HUD) — alle nach demselben Muster wie Hunger.

Ausführlich in [`survivor.md`](survivor.md), "Bedürfnisse: Müdigkeit +
Moral", und [`building.md`](building.md), "Betten".

**Noch nicht vom Nutzer getestet.**

## Differenzierte Gebäudetypen mit echten Loot-Tabellen (2026-08-02, Punkt 17 der Gesamtliste)

Direkt im Anschluss an Punkt 16 selbst gewählt weitergemacht (Nutzerwunsch
"mach schonmal weiter"). Ersetzt die zwölf ANONYMEN `BUILDING_TEMPLATES`
(gleiche Struktur, nur Größe/Loot/Farbe unterschiedlich) durch vier ECHTE,
aus der Vision benannte Gebäudetypen (`BUILDING_TYPES`): Wohnhaus,
Supermarkt, Apotheke, Waffenladen/Polizeistation. Jeder Typ hat jetzt eine
echte Loot-TABELLE (`main_loot` garantiert als Bereich + `secondary_loot`
unabhängige Chancen) statt eines einzigen festen Werts, gewürfelt bei
jedem Gebäude-Spawn (`_roll_building_loot()`/`_apply_loot_roll()`).

**Neu: Waffenladen/Polizeistation droppt jetzt auch Ausrüstung**
(Waffe garantiert, Munition/Rüstung/Helm als Chancen) — vorher kamen
Waffe/Rüstung/Helm ausschließlich aus Zombie-Loot oder Crafting.

**Bewusst NICHT übernommen:** der fünfte Vision-Typ "Werkstatt/Baumarkt"
(Loot wäre Baumaterial) — Holz/Metall/Stein/Ziegel kommen in diesem
System ausschließlich aus eigenen Ressourcenknoten, nie aus
Stadt-Gebäude-Loot (eine frühere, vom Nutzer bestätigte Korrektur genau
dieses Vermischens, siehe "Vier Baurohstoffe" oben — hier bewusst nicht
wieder aufgehoben). Jagdstand (Wald-Zonen) bleibt unverändert, nicht Teil
dieses Umbaus.

Ausführlich in [`scavenging.md`](scavenging.md), "Gebäude-Typen +
Loot-Tabellen".

**Noch nicht vom Nutzer getestet.**

## Erweitertes Waffen-/Rüstungssystem: Haupt-/Sekundärwaffe + Beinschutz (2026-08-02, Punkt 18 der Gesamtliste)

Direkt im Anschluss an Punkt 17 selbst gewählt weitergemacht
(Nutzerwunsch "weiter zu Punkt 18"). Löst genau die Abgrenzung auf, die
das ursprüngliche Waffen-/Rüstungssystem explizit offen gelassen hatte
("keine Haupt-/Sekundärwaffen-Slots", siehe `docs/survivor.md`,
"Waffensystem").

- **Sekundärwaffe:** `secondary_weapon: bool` +
  `order_equip_secondary_weapon()` — zweiter, unabhängiger Waffenslot
  neben der bestehenden Hauptwaffe (Fernkampf). Rüstet eine richtige
  Nahkampfwaffe aus (mehr Schaden + kürzerer Cooldown als der bloße
  Fäuste-Fallback), greift nur, solange kein Fernkampf möglich ist.
  Verbraucht die NEUE Ressource `melee_weapon`.
- **Dritter Rüstungs-Slot:** `has_leg_armor: bool` +
  `order_equip_leg_armor()` — Beinschutz, gleiche Struktur wie
  Brustpanzer/Helm, wirkt multiplikativ mit den bestehenden zwei
  (zusammen jetzt ~49,4% Schadensreduktion statt ~40,5%). Verbraucht die
  NEUE Ressource `leg_armor`.
- Beide neuen Ressourcen: Teil des temporären 150er-Testbestands, Teil
  der `ZOMBIE_LOOT_TABLE` (jetzt sieben statt fünf Typen) — bewusst OHNE
  eigenen Crafting-/Forschungsbücher-Pfad in dieser Stufe.
- UI (kompakte Liste `[S]`/`[B]`-Tags, Trupp-Detailfenster mit zwei
  weiteren Zeilen+Buttons, `UnitDetailUI`-Panel dafür vergrößert),
  Replikation, Speichern/Laden — alle nach demselben Muster wie die
  bestehenden Slots.

Ausführlich in [`survivor.md`](survivor.md), "Haupt-/Sekundärwaffe" +
"Dritter Rüstungs-Slot: Beinschutz".

**Noch nicht vom Nutzer getestet.**

## Wichtige Vereinbarungen für die Weiterarbeit

Diese gelten automatisch weiter (im persistenten Claude-Memory-System
gespeichert, nicht nur hier):

1. **Docs-Konvention:** zu jedem größeren System eine eigene
   `docs/<system>.md`, die erklärt was der Code macht und wie man ihn
   erweitert — nicht nur Inline-Kommentare.
2. **Selbst priorisieren:** nach Abschluss eines Features den nächsten
   sinnvollen Schritt selbst wählen statt zu fragen "was jetzt" — Umfangs-
   Rückfragen ("wie groß soll dieser eine Schritt sein") bleiben aber
   weiterhin normal.
3. **`status.md` live pflegen:** nach jedem abgeschlossenen Feature nicht
   nur die passende `docs/<system>.md` schreiben, sondern auch diese Datei
   aktualisieren (Roadmap-Haken, neuer Abschnitt) — sonst verlässt sich die
   nächste Session auf einen veralteten Stand (siehe "Nachtrag 2026-07-31"
   oben, genau das ist einmal passiert).

## Ordner-Hinweis

`scenes/entities/player/` und `scenes/ui/` sind jetzt leere Ordner (Commander
bzw. HUD.tscn entfernt, siehe oben) — bewusst nicht gelöscht, falls sie
später wieder gebraucht werden.
