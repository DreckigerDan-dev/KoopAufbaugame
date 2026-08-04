# Mechaniken-/Balance-Bericht (2026-08-04)

Reine Code-Analyse (Konstanten/Formeln in `World.gd`/Entity-Scripts), kein
tatsächlicher Spieltest — Zahlen sind exakt aus dem aktuellen Code
abgelesen, die daraus abgeleiteten Einschätzungen (Session-Verlauf,
"spielbar bis wann") sind Hochrechnungen, keine Messwerte. Ziel: einschätzen,
ob die Mechaniken als Ganzes zusammenpassen, und wie lange eine Session
realistisch trägt.

## Kernaussage zuerst :

**Das Spiel hat kein Sieg-/Niederlage-Ziel und keine laufende Rekrutierung.**
Die Zombie-Bedrohung wächst bis zu einem festen Deckel (200) unbegrenzt
weiter, während die Spieler-Truppenzahl eine strikt endliche, nie
nachwachsende Ressource ist (Permadeath, genau eine einmalige
Rekrutierungsquelle). Strukturell läuft eine Session deshalb nicht auf ein
stabiles Gleichgewicht zu, sondern auf eine Abnutzungskurve — "spielbar"
heißt hier eher "wie lange hält die Gruppe durch", nicht "wie wird das
Spiel gewonnen".

## Zeitskala (Echtzeit): möglich anpaasung zeit stoppen und tage länger zu machen um besser managen zu können nur host kann pausieren erstmal

- **1 Spieltag = 5 Minuten Echtzeit** (`CYCLE_LENGTH := 300.0` Sekunden).
- **Nacht = 22:00–4:00 Spielzeit** (`NIGHT_START_HOUR`/`NIGHT_END_HOUR`) —
  6 von 24 Stunden = 25 % eines Tages = **75 Sekunden Echtzeit pro Nacht**.
- **Jede Nacht (alle 5 Minuten):** garantierte Horde, sofort auf einen
  zufällig gewählten Spieler alarmiert (`_trigger_horde_night()`,
  `HORDE_SIZE := 10`, davon `HORDE_BRUTE_COUNT := 2` zähe Brutes).
- **Jede 5. Nacht = Blutmond (alle 25 Minuten Echtzeit):**
  `BLOOD_MOON_HORDE_SIZE := 30`, `BLOOD_MOON_BRUTE_COUNT := 10` — 3×
  Zombies, 5× Brutes gegenüber einer normalen Nacht, plus 20 % mehr
  Zombie-Angriffsschaden generell nachts (`ZOMBIE_NIGHT_DAMAGE_MULTIPLIER
  := 1.2`).

## Zombie-Bedrohung über Zeit : skaliereung durch mehr spieler ja und zombie cap erhöhen 

- **Start:** 20 Zombies (`ZOMBIES_PER_ZONE := 4` × 5 Stadt-Zonen).
- **5 Zombie-Nester** spawnen kontinuierlich, ohne eigene Obergrenze
  (`SPAWN_INTERVAL := 25.0`s je Nest) — macht rechnerisch bis zu ~12
  zusätzliche Zombies/Minute kartenweit, solange der globale Deckel nicht
  erreicht ist.
- **Harter Deckel: `MAX_ZOMBIES := 200`** — Nester UND Horde-Spawns pausieren
  oberhalb (`_spawn_nest_zombie()`/`_trigger_horde_night()` prüfen das nicht
  direkt, aber `ZombieNest._process()` bricht ab, siehe Kommentar bei
  `MAX_ZOMBIES`-Prüfung).
- **Grobe Hochrechnung ohne aktives Kämpfen:** von 20 auf 200 (180 Zombies)
  bei ~12-14/Minute kombiniertem Nester+Horde-Zufluss → **ca. 13–15 Minuten**
  bis zum Deckel, wenn niemand einen einzigen Zombie tötet (in der Praxis
  länger, weil `ZOMBIE_DESPAWN_RADIUS`/`_DESPAWN_CHECK_INTERVAL` entfernte,
  untätige Wander-Zombies wieder abbaut).
- **Keine Skalierung mit Spieleranzahl** — `HORDE_SIZE` ist bei 1 Spieler
  genauso groß wie bei 4, und pro Nacht wird nur EIN zufälliger Spieler als
  Horde-Ziel gewählt. Mehr Mitspieler verteilen die Horde-Last also, statt
  dass sie mitwächst — Koop zu viert ist pro Kopf spürbar entspannter als
  Solo, nicht gleich schwer.

## Spieler-Kapazität (Trupps) — der auffälligste Befund:mehr start truppen und truppendurch haus plündern findest man welche oder es kommen welche die nach schutz suchen und die kannst du rekrtieren 

- **Start: `START_SURVIVOR_COUNT := 5`** Trupps pro Spieler.
- **Genau EINE zusätzliche Rekrutierungsquelle auf der GESAMTEN Karte**
  (ein fest platziertes durchsuchbares Gebäude, siehe `docs/recruitment.md`)
  — einmalig, +1 Trupp, danach keine weitere Quelle.
- **Maximal 6 Trupps pro Spieler für die komplette Session.** Keine
  laufende Rekrutierung, kein Nachwuchs-Mechanismus.
- **Permadeath** — kein Wiederbeleben, kein Ersatz.
- ⇒ Die Trupp-Anzahl ist eine **streng monoton fallende** Ressource, während
  die Zombie-Zahl **streng monoton steigt** (bis zum 200er-Deckel). Ohne
  einen laufenden Rekrutierungs-Mechanismus (aus der Vision zwar als "Kaserne"
  angedacht, siehe `docs/recruitment.md`, aber nicht gebaut) hat das Spiel
  kein stabiles Gleichgewicht eingebaut.

## Ressourcen-Wirtschaft:mehr start resouccen das man seine base gleich bischen ausbauen kann oder in den städten auch bäume steine etc. plazieren das mann schneler bauen kann

- **Start:** 20–30 Baurohstoffe je Art (Holz/Metall/Stein/Ziegel), 15–20
  Überlebensgüter (Medizin/Munition), je 1 Ausrüstungsgegenstand
  (`HomeBase.START_RESOURCES`).
- **Lagerkapazität:** `BASE_STORAGE_CAPACITY := 150` — EIN gemeinsamer
  Deckel für alle 16 Ressourcenarten, erhöhbar durch Lager-Ausbauten
  (volumenabhängig, `STORAGE_CAPACITY_PER_VOLUME := 40`).
- **Baukosten:** durchgehend günstig, 15–30 Einheiten EINER Rohstoffart pro
  Gebäude (z. B. Wachposten 30 Holz, Mauer 15 Stein, Tor 20 Metall).
- **Aktive Ernte-Rate** (ein Bautrupp direkt am Ziel, `HARVEST_DAMAGE := 15`
  alle `HARVEST_COOLDOWN := 1.0`s): Baum (60 HP) 4 Treffer/4s → 15 Holz;
  Autowrack (80 HP) 6 Treffer/6s → 20 Metall; Stein-/Ziegelhaufen (50 HP)
  4 Treffer/4s → 15 Stein/Ziegel. Größenordnung überall **~3,3–3,75
  Einheiten/Sekunde reine Erntezeit** (ohne Laufweg).
- **Nachwachsen:** höchstens 1 neuer Knoten pro Rohstoffart alle 30
  Sekunden, bis zum aktuellen Kartendeckel (nach dem letzten
  Stresstest-Hochschrauben: 800 Bäume/320 Autowracks/400 Stein/400 Ziegel,
  siehe `docs/benchmarks.md`).
- **Zombie-Loot:** 50 % Drop-Chance je Kill (`ZOMBIE_LOOT_DROP_CHANCE`),
  5–10 Einheiten je nach Ressourcenart; Forschungsbücher komplett separat
  gewürfelt, nur 8 % Chance je Kill (`BOOK_DROP_CHANCE`).

## Nahrungs-/Bedürfnisökonomie: alle bedrürfnisse sollten länger brauchen zum abblaufen das mann sich eher auf ander sachen fokosieren kann 

- **Hunger** sinkt mit `HUNGER_DECAY_RATE := 1.5`/Sekunde — von 100 auf 0 in
  ~67 Sekunden ohne Essen.
- **Essen nur in Basis-Nähe** (`HEAL_RADIUS`), kostet 1 Nahrung pro 15
  Hunger, alle `EAT_INTERVAL := 2.0`s ein Tick.
- Bei 5–6 im Leerlauf an der Basis geparkten Trupps summiert sich das
  spürbar — der Start-Bestand (30 Nahrung) reicht ohne aktives Sammeln nur
  wenige Minuten, wenn alle Trupps gleichzeitig an der Basis "auftanken".
- **Müdigkeit/Moral** (seit dem Fix vom 2026-08-04 deutlich langsamer:
  `FATIGUE_DECAY_RATE := 0.15`/s, `MORALE_DECAY_RATE := 0.075`/s, ~11 bzw.
  ~22 Minuten bis 0) regenerieren NUR am eigenen Schlafraum, keine
  Home-Base-Grundrate.

## Fehlende Enden/Ziele:pack ein game over mit neustart oder zurück zum hauptmnenü

Kein Sieg-/Niederlage-Zustand im gesamten Code gefunden (`grep` über
`game_over`/`victory`/"gewonnen"/"verloren" ohne Treffer). Das Spiel endet
nie formal — es läuft, bis alle Spieler aufhören, oder bis ein Spieler
handlungsunfähig ist (alle eigenen Trupps tot), was selbst kein "Game
Over"-Ereignis auslöst, nur stille Bewegungsunfähigkeit.

## Realistische Spielbarkeits-Einschätzung (Hochrechnung, kein Messwert)

Grober Session-Verlauf für eine durchschnittliche Gruppe ohne besonders
optimiertes Spiel:

| Phase | Echtzeit | Zustand |
|---|---|---|
| Frühphase | 0–15 Min | Gut spielbar, Zombie-Zahl unter Kontrolle, Start-Ressourcen reichen mit etwas Sammeln. |
| Bis 1. Blutmond | 15–25 Min | Merklich mehr Druck (mehrere normale Hordes bereits verkraftet), erste Trupp-Verluste wahrscheinlich, falls keine Verteidigung (Wachposten/Mauern) steht. |
| Bis 2. Blutmond | 25–50 Min | Ohne Wachtürme/Mauern/mehrere Wachposten schwer zu halten — Trupp-Kapazität beginnt zu schrumpfen, Zombie-Zahl nähert sich dem Deckel. |
| Ab 2.–3. Blutmond | ab ~50 Min | Strukturell zunehmend unspielbar: Trupps wachsen nicht nach, Zombies nehmen bis 200 weiter zu — Session läuft auf ein Attrition-Ende zu, kein Gleichgewicht. |

Mit aktivem Spiel (Wachposten bauen, Mauern ziehen, Zombies gezielt
abfarmen für Loot, Wachtürme für Sichtweite) verschiebt sich das nach
hinten, aber der grundsätzliche Trend (Bedrohung steigt schneller nach als
die Spieler-Kapazität) ändert sich nicht, solange keine laufende
Rekrutierung existiert.

## Beobachtungen (keine Empfehlung zur sofortigen Umsetzung, nur Befund)

- **Auffälligster Bruch:** laufende Rekrutierung fehlt komplett (nur
  einmalig +1 auf max. 6) — für ein Spiel mit unbegrenzt weiterlaufender
  Bedrohung ist das der Punkt, der am stärksten gegen eine lange,
  nachhaltige Session arbeitet.
- **Keine Horde-Skalierung mit Spieleranzahl** — Koop wird dadurch pro Kopf
  spürbar leichter statt gleich schwer.
- **Kein Sieg-Zustand — bewusst so gewollt, kein offener Punkt.** Nutzer
  hat das nach der Infection-Free-Zone-Recherche (siehe
  `Infos/06 Infection Free Zone Recherche.md`) explizit bestätigt: "das
  Spiel soll eher Sandbox sein, Endziel soll es nicht geben, vielleicht
  wenn das Spiel mal spielbar ist eine Kampagne oder so, aber erstmal
  unwichtig" (2026-08-04). Keine Victory-Condition bauen/vorschlagen — nur
  die Verlust-Seite (Home-Base-Zerstörung → Game Over, siehe oben) gilt.
