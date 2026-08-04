---
tags:
  - spiel
  - godot
  - planung
  - backlog
status: aktiv
erstellt: 2026-08-04
---

# Backlog-Umsetzungspläne

> [!info] Zweck
> Konkrete Umsetzungspläne für jeden Punkt aus dem "Ideen-Backlog" in
> [[01 Architektur.md]] (dort die Kurzfassung, hier das "wie genau" mit
> Datei-/Funktionsnamen aus dem aktuellen Code-Stand) — Ziel: eine neue
> Chat-Session kann direkt mit der Umsetzung loslegen, ohne den Code
> vorher erst wieder komplett zu erkunden. Erstellt nach der IFZ-Gap-
> Analyse ([[06 Infection Free Zone Recherche.md]]) und dem Zivilisten-
> Konzept-Umsetzungsabend, 2026-08-04.
>
> **Wichtig:** Das ist ein PLAN, keine fertige Entscheidung. Punkte mit
> "Offene Frage" brauchen erst eine Nutzer-Antwort, bevor programmiert
> wird — nicht einfach loslegen und raten. Punkte ohne offene Frage sind
> direkt umsetzbar.
>
> **Vor dem Start jedes Punkts:** kurz `git`/Datei-Stand gegenprüfen, ob
> sich seitdem was geändert hat (dieser Plan ist eine Momentaufnahme vom
> 2026-08-04, kein lebendes Dokument wie `docs/status.md`).

---

## Bedürfnisse/Überleben

### Durst (drittes Grundbedürfnis)

Spiegelt Hunger fast 1:1 — kein neues Architekturmuster, reine Kopie.

- `Survivor.gd`: `var thirst: float = 100.0`, `const THIRST_DECAY_RATE`
  (Startwert wie `HUNGER_DECAY_RATE := 0.3`, ggf. eigene Tarierung),
  `_handle_thirst(delta)` als Kopie von `_handle_hunger()` (Zeile ~845),
  Aufruf in `_process()` neben `_handle_hunger(delta)`.
- Trinken: `_handle_drinking(delta)` als Kopie von `_handle_eating()`
  (Zeile ~913) — verbraucht neue Ressource `"water"` aus der Home-Base
  statt `"food"`, eigene `DRINK_INTERVAL`/`DRINK_AMOUNT`-Konstanten.
- Neue Ressource `"water"`: `HomeBase.START_RESOURCES` (`docs/base.md`) +
  `RESOURCE_DISPLAY_NAMES` (World.gd, Zeile ~1024) + Kategorie-Zuordnung
  in der Ressourcen-Panel-Tab-Gruppe ("Überleben", neben `food`, Zeile
  ~1043). Loot-Quelle noch offen (siehe unten).
- Speed-Penalty analog `HUNGER_SPEED_FACTOR`/`HUNGER_LOW_THRESHOLD` — eigene
  Konstanten oder Wiederverwendung der Hunger-Schwelle?
- Sync: `_sync_state()`-RPC-Signatur (Survivor.gd, Zeile ~1276) um
  `new_thirst` erweitern — nur EINE Aufrufstelle (Zeile ~331, im selben
  Skript), also risikoarm.
- UI: `_refresh_units_ui()`-Label (World.gd) neuen Kurzcode ergänzen (z. B.
  `"Du%d"`), `_update_unit_detail_panel()`-Stats-String erweitern.
- Save/Load: `_collect_save_data()`/`_load_game_state()` (World.gd) —
  `"thirst": survivor.thirst` beim Speichern, `entry.get("thirst", 100.0)`
  beim Laden (Fallback-Pattern wie bei `fatigue`/`morale`, für alte
  Spielstände ohne dieses Feld).

**Offene Fragen an den Nutzer:** eigener Decay-Rate-Wert oder identisch zu
Hunger? Welches Gebäude liefert Wasser (Wohnhaus/Supermarkt-Loot
erweitern? Eigene Quelle wie ein Brunnen)?

**Aufwand:** klein-mittel.

### Krankheit als Zwischenstufe vor Permadeath

**Erst mit Nutzer klären, dann umsetzen** — führt einen NEUEN, passiven
Todesweg ein (Vernachlässigung statt Kampfschaden), der die bisherige
klare Permadeath-Regel ("nur durch Kampf/Zombie-Schaden") aufweicht. Das
ist eine echte Design-Entscheidung, keine technische Nebensächlichkeit.

- Konzept: neuer Zustand `var is_sick: bool = false`, ausgelöst wenn
  Hunger/Durst/Müdigkeit/Moral über eine Zeitspanne (neuer Timer
  `_time_at_zero_needs` in `_process()`) bei 0 verharren.
- Sick-Effekt (Vorschlag): passiver HP-Verlust über Zeit
  (`SICKNESS_HP_DRAIN_RATE`) bis geheilt oder tot, erhöhter
  Medizin-Verbrauch zum Heilen.

**Offene Frage an den Nutzer (vor JEDER Codezeile klären):** Soll
Krankheit wirklich zum Tod führen können (echtes Vernachlässigungs-
Risiko), oder nur ein Debuff sein, der nie tödlich endet? Aktuell nirgends
festgelegt.

**Aufwand:** mittel — aber Design-Klärung zuerst, nicht raten.

### Verletzungsgrad-abhängiger Medizinverbrauch

**Schon weitgehend erfüllt, vermutlich kein Umsetzungsaufwand nötig:**
`_handle_healing()` (Survivor.gd, ~Zeile 880–903) verbraucht bereits exakt
1 Medizin pro geheiltem HP-Punkt und läuft nur, solange `hp < MAX_HP` —
der Gesamtverbrauch skaliert dadurch automatisch mit dem tatsächlichen
Verletzungsgrad (mehr fehlende HP = länger + mehr Medizin bis voll).

**Empfehlung:** aus dem aktiven Backlog streichen, außer der Nutzer will
explizit eine GESTAFFELTE Heilrate (z. B. schneller bei sehr niedriger
HP) — das wäre die einzige noch offene Ergänzung.

---

## Gebäude/Basis

### Sichtbares "Produktion pausiert"-Feedback

**Erledigt (2026-08-04) für `GuardPost.gd`** — `Label3D`-Kind-Node
"Kein Arbeiter zugewiesen", `GuardPost._update_no_worker_label()`. Details
in `koop-game/docs/building.md`, "Arbeiter zuweisen". Noch nicht vom
Nutzer getestet, Label-Y-Position noch nicht feinjustiert.

Baustellen (Bau-Markier-Modus) haben durch die Baustellen-Liste im
Bauen-Tab ("X Trupps", 0 % Fortschritt bei 0 Trupps) schon ausreichendes
Feedback — dort kein Zusatzaufwand nötig/umgesetzt.

### Reparatur-Mechanik für beschädigte Gebäude/Home-Base

Aktuell: `take_damage()` (Building/HomeBase/GuardPost/Wall) reduziert HP,
keine Gegenrichtung außer Zerstörung → Ruine → Abriss.

Zwei Ansätze, **Rückfrage an Nutzer nötig, welcher gewünscht ist:**

1. **Sofort-Reparatur per Klick + Ressourcen**, proportional zu fehlender
   HP (einfach, kein neuer State, analog zur `_handle_healing()`-Rechnung:
   X Holz/Metall pro HP).
2. **Zeitbasiert mit zugewiesenem Bautrupp**, analog zum bestehenden
   Bau-Markier-Modus (`Building.has_open_construction`/
   `order_station_at_building()`, siehe `docs/building.md`,
   "Baustellen") — mehr Konsistenz mit der existierenden
   Bau-Infrastruktur (Progress/Worker-Zuweisung/UI-Liste fast 1:1
   wiederverwendbar), aber mehr Aufwand: im Kern ein zweiter
   `construction_target_type`-artiger Modus ("repair" statt "upgrade").

**Empfehlung:** Ansatz 2, weil die Infrastruktur schon fast komplett da
ist — aber erst fragen, ob der Nutzer die einfachere Variante 1 lieber
will.

**Aufwand:** mittel (Ansatz 1) bis mittel-groß (Ansatz 2).

### Nahrungsproduktionskette

**Grundstufe existiert schon:** `Field.gd`
(`scenes/entities/field/Field.gd`) produziert bereits passiv Nahrung
(`YIELD_AMOUNT := 2` alle `YIELD_INTERVAL := 8.0`s, kein Worker nötig).
Das Backlog-Item wäre eine ECHTE mehrstufige Kette obendrauf, kein Neubau
von Null.

- Vorschlag: neues Gebäude "Scheune" (Getreide → rohes Fleisch, analog
  IFZ), "Kochhaus" (Fleisch/Getreide → haltbare Rationen).
- Braucht neue Ressourcenarten (Getreide, rohes Fleisch, Rationen) —
  kollidiert mit der schon dichten Ressourcen-Panel-Struktur (16 Arten,
  zwei Tabs) — neue Kategorie-Überlegung nötig.

**Empfehlung:** eher Post-MVP-Post-MVP, nur angehen, falls
Nahrungsknappheit im Spielgefühl tatsächlich mal ein Problem wird
(aktuell laut `docs/mechanics-review.md` eher nicht der Fall, gerade nach
der Startressourcen-Erhöhung vom 2026-08-04).

**Aufwand:** groß.

### Forschungszentrum + echter Tech-Baum

**Universal-Buch-Migration erledigt (2026-08-04):** die vorherigen 5
Bücher (`book_weapon`/`book_armor`/`book_helmet`/`book_ammo`/
`book_medical_upgrade`) sind jetzt eine einzige `World.
RESEARCH_BOOK_RESOURCE := "book_research"`. Details in `koop-game/docs/
building.md`, "Universal-Buch-Migration". Noch nicht vom Nutzer getestet
(siehe `docs/pending-tests.md`).

**Echter Tech-Baum** (Abhängigkeiten zwischen Freischaltungen, eigenes
Forschungsgebäude statt "überall lernbar") bleibt offen — separates,
deutlich größeres Feature, unabhängig von der schon erledigten
Buch-Migration.

**Aufwand:** echter Tech-Baum groß.

### Wetter-System mit Vorhersage

Komplett neu, keine Vorarbeit im Code. Bräuchte einen neuen globalen State
(`World._weather`, ähnlich `_day_time`) + ein Vorhersage-Gebäude + Effekte
auf z. B. `Field`-Ertrag.

**Abhängigkeit:** nur sinnvoll, wenn die Nahrungsproduktionskette (siehe
oben) existiert — vorher gibt es nichts, worauf Wetter wirken würde.

**Aufwand:** groß, niedrige Priorität ohne Nahrungskette.

### Fahrzeug-Werkstatt

Neues Gebäude (analog `Workshop.gd`/`MedicalStation.gd`-Baumuster: eigene
Szene, `owner_peer_id`, `built`-Flag), Reparatur-Funktion für Fahrzeuge in
der Nähe (analog `_handle_healing()`-Pattern, aber auf `Vehicle.hp` statt
`Survivor.hp`).

"Panzerung nachrüsten" bräuchte einen neuen Vehicle-State (z. B.
`armor_level: int`), der HP/Schadensreduktion beeinflusst — ähnlich dem
bestehenden Rüstungssystem bei Survivor (`ARMOR_DAMAGE_REDUCTION`).

**Aufwand:** mittel.

### Aktiv auslösbare Rekrutierungs-Aktion ("Ruf aussenden")

**Erledigt (2026-08-04)** — `World.request_active_recruit_call()`,
90s-Cooldown pro Spieler, Button im Einheiten-Tab. Details in
`koop-game/docs/recruitment.md`, "Aktive Rekrutierungs-Aktion". Noch
nicht vom Nutzer getestet.

**Aufwand:** klein-mittel.

### Gebäude-Adaption statt strikter Loot/Bau-Trennung

**Größte Architektur-Entscheidung im ganzen Backlog** — würde
`Building.gd` (aktuell reine Loot-Node, wird nach Suche entweder Ruine
oder claimbar) mit den eigenen Zonen-Bau-Typen (GuardPost/Workshop/
MedicalStation/etc.) verschmelzen oder zumindest verzahnen.

**Nicht nebenbei anfangen** — würde wahrscheinlich eine eigene
Planungssession brauchen, ähnlich der Umstellung auf 3D
(`docs/3d-migration.md`). Nur aufnehmen, wenn wirklich explizit gewünscht.

**Aufwand:** sehr groß, eigene Session nötig.

---

## Ressourcen

### Treibstoff/Energie für Fahrzeuge

`Vehicle.gd` hat aktuell KEIN Treibstoff-Feld.

- `VEHICLE_STATS`-Dictionary (Zeile ~39, HP/Speed/Sitze/Farbe) um
  `fuel_capacity` erweitern, neues `var fuel: float` pro Instanz,
  Verbrauch proportional zu gefahrener Strecke oder Zeit in Bewegung.
- Tankstellen-Loot: neue Ressource `"fuel"` — die Tankstelle existiert
  bereits als Gebäudetyp (seit den zehn neuen Gebäudetypen, siehe
  `docs/scavenging.md`) und passt thematisch perfekt als Quelle.

**Aufwand:** mittel.

### Dünger

Hängt vollständig an der Nahrungsproduktionskette (siehe oben) — nicht
isoliert sinnvoll umsetzbar, gleiche Abhängigkeit.

### Ablaufende Ressourcen

Bräuchte einen Zeitstempel pro Ressourceneinheit — aktuell ist
`HomeBase.resources` ein simples `{art: menge}`-Dictionary ohne Chargen-/
Zeitverfolgung. Umbau auf z. B. eine Liste von `{amount, timestamp}`-
Einträgen pro Ressourcenart wäre ein spürbarer Strukturumbau des gesamten
Ressourcensystems (betrifft `add_resources()`, Speicherstand,
UI-Anzeige).

**Empfehlung:** eher NICHT isoliert umsetzen — hoher Aufwand für relativ
wenig Spieltiefe, außer im Rahmen der ohnehin größeren Nahrungskette.

**Aufwand:** groß, eher niedrige Priorität.

---

## Überlebende/Einheiten

### Skill-/Perk-Progression durch Tätigkeit

- Neues Feld pro Survivor, z. B. `var experience: Dictionary =
  {"scavenging": 0, "combat": 0, "driving": 0}`, hochgezählt bei
  entsprechenden Aktionen (`_finish_search()`, `_process_attack()`,
  Fahrbefehl in `Vehicle.gd`).
- Boni-Anwendung ähnlich den geplanten Rollen-Boni (Punkt 15 der alten
  festen Liste — noch nicht mal umgesetzt).

**Abhängigkeit/Reihenfolge:** Rollen-System (Punkt 15) sollte vermutlich
ZUERST kommen, bevor Skills obendrauf gebaut werden — sonst zwei
parallele, unkoordinierte Bonus-Systeme.

**Balance-Risiko** (siehe Recherche): "immer nur den erfahrensten Trupp
schicken" — bei KoopGames knapper Truppzahl (Permadeath!) potenziell noch
strenger spürbar als bei IFZ.

**Aufwand:** mittel, aber Rollen-System vorher klären.

### Kampf-Stances (aggressiv/defensiv)

Neues `var stance` pro Survivor. Aber: **fraglicher Nutzen im aktuellen
Kampfmodell** — Trupps greifen ohnehin nur auf expliziten `order_attack()`-
Befehl an (kein automatisches "greift jeden Zombie in der Nähe an"-
Verhalten). Der Unterschied zwischen "aggressiv"/"defensiv" wäre in
KoopGames aktuellem Modell kaum spürbar, weil es kein automatisches
Vorpreschen gibt.

**Offene Frage an den Nutzer, VOR Umsetzung:** Ist automatisches Feuern
auf nahe Zombies überhaupt gewünscht? Nur dann ergibt eine Stance-
Einstellung wirklich einen Unterschied.

**Aufwand:** klein — aber erst die Vorfrage klären.

### Waffen-Tausch-Interface (Lager ↔ Trupp-Slots)

Aktuell läuft Ausrüsten über einzelne Buttons im Trupp-Detailfenster
(`order_equip_weapon()` etc.), die direkt aus `HomeBase.resources`
verbrauchen — es gibt kein separates "Lager"-Konzept, das Lager IST der
Ressourcen-Pool.

Ein Drag&Drop-Interface wäre reiner UI-Zucker um dieselbe Funktion — kein
funktionaler Gewinn. Nur umsetzen, wenn der Nutzer die aktuelle
Klick-Bedienung konkret unbequem findet.

**Aufwand:** mittel (reine UI-Arbeit, keine neue Logik).

### Trupp-Mitglieder-Tausch/Trupp-Aufteilen

**Wichtiger struktureller Unterschied zu IFZ:** In KoopGame IST ein
"Trupp" bereits genau EIN Survivor (`trupp_id` pro Survivor-Instanz) — es
gibt keine Mehr-Personen-Gruppe wie IFZs "Squads". Dieser Punkt würde eine
komplett neue Strukturebene einführen (Trupp = Container mehrerer
Survivor), keine kleine Ergänzung.

**Nur angehen, wenn der Nutzer wirklich Mehrpersonen-Trupps will** (z. B.
für Fahrzeug-Besatzungen oder Kampfgruppen) — sonst eher nicht sinnvoll,
das aktuelle 1:1-Modell (1 Survivor = 1 auswählbare, befehligbare Einheit)
ist simpel und funktioniert.

**Aufwand:** sehr groß, strukturelle Änderung.

### Zivilisten-Konzept

**Bereits umgesetzt** (2026-08-04 Abend, siehe `docs/recruitment.md`,
"Zivilisten-Konzept") — leichte Variante: `Survivor.TroopType.UNASSIGNED`
+ Auto-Zuweisungs-Dropdown im Einheiten-Tab. Aus dem offenen Backlog
entfernt (siehe [[01 Architektur.md]]).

---

## Zombies/Bedrohung

### Mehrere Zombie-Typen/Varianten

**Erledigt (2026-08-04):** dritter Typ "Runner" (schnell, zerbrechlich)
ergänzt, `Zombie.gd` dabei von `@export var is_brute: bool` auf ein
echtes `enum ZombieType { NORMAL, BRUTE, RUNNER }` umgestellt (ab dem
dritten Typ sauberer als weitere Bool-Flags, wie hier schon vermerkt
war). Details in `koop-game/docs/zombies.md`, "Zombie-Typen". Noch nicht
vom Nutzer getestet.

Weitere Varianten (z. B. eine seltene Elite mit Gruppen-Buff, siehe
ursprüngliche Idee) folgen jetzt dem etablierten Enum-Muster 1:1: neuen
`ZombieType`-Wert + eigene Stufen für HP/Speed/Schaden + eigene Szene für
abweichende Optik (analog `ZombieRunner.tscn`).

**Aufwand:** klein pro zusätzlichem Typ (Muster ist etabliert).

### Lichtscheu-Verhalten (tagsüber inaktiv/versteckt)

Aktuell beeinflusst Tag/Nacht (`World.is_night()`) vermutlich nur
Spawn-Rate/Aggression (Horde-Nächte), kein "verstecken bei Tag"-
Verhalten. Echtes IFZ-Lichtscheu bräuchte Zombies, die tagsüber inaktiv
sind oder sich zurückziehen — ein invasiver Eingriff ins bestehende,
permanente Wander-/Verfolgungsverhalten.

**Empfehlung:** eher NICHT 1:1 übernehmen — würde das aktuelle,
funktionierende Tag/Nacht-Spannungsgefühl (Horde-Nächte als
Hauptspannungsquelle) eher verwässern als ergänzen.

**Offene Frage an den Nutzer:** überhaupt gewünscht, bevor man das
bestehende Zombie-Verhalten anfasst?

**Aufwand:** mittel, aber fraglicher Nutzen — erst Rückfrage.

### Kontinuierlicher Lärm-/Aktivitäts-Druck

Aktuell ist Lärm rein EVENT-basiert (Schuss/Kampf → Radius-Alarm im
Moment). Ein kontinuierlicher Wert bräuchte einen neuen Zustand (z. B.
`HomeBase._heat_level` oder pro Peer in `World`), der langsam über Zeit
UND Aktivität steigt und regelmäßig (nicht nur bei Blutmond) zusätzliche
Zombie-Aufmerksamkeit Richtung Basis lenkt.

Würde sich gut ERGÄNZEND zur bestehenden Blutmond-Kalender-Eskalation
einfügen (wie in der Recherche vermerkt, nicht als Ersatz) — technisch
eine neue, kontinuierliche Zombie-Anziehung statt eines Kalender-Ticks.

**Aufwand:** mittel.

### Schwierigkeitsgrad-Einstellung

Architektonisch nicht trivial bei geteilter Zombie-Population — ein
Slider würde ALLE Spieler gleichzeitig betreffen. Müsste als
Host-Einstellung VOR Spielstart (Lobby) gewählt werden, nicht pro Spieler
zur Laufzeit.

- Umsetzung: neuer Multiplikator (z. B. `World.DIFFICULTY_MULTIPLIER`)
  auf `MAX_ZOMBIES`/Horde-Größe/Schaden, gesetzt beim Host in der Lobby,
  an alle Peers repliziert (ähnlich dem `_catch_up_day_time()`-Muster).

**Aufwand:** mittel, aber Lobby-UI-Erweiterung nötig (aktuell nicht
vorhanden).

---

## Fraktionen

### Banditen-Fraktion als echte NPC-Gegner

Aktuell nur Loot-Mechanik (`Building.has_bandit_loot`, kein Gegner-Node).

- Echte Fraktion bräuchte ein neues `Bandit.gd` (ähnlich `Zombie.gd`,
  aber mit Fernkampf/Loot-beim-Tod statt Zombie-typischem Verhalten) + ein
  "Hideout"-Gebäude, das periodisch neue Banditen spawnt (analog dem
  bereits existierenden `ZombieNest.gd`-Muster).
- Guter Kandidat, weil das Spawner-Gebäude-Muster (periodischer
  Nachschub) schon 1:1 existiert und wiederverwendbar ist.

**Aufwand:** mittel-groß (neue Entity + neues Spawner-Gebäude, aber
etablierte Muster als Vorlage).

### Freundliche KI-Überlebendengruppen

Komplett neu, kein Vorbild im Code (Handel läuft aktuell nur zwischen
echten Spielern, `_trade_offers`-System). Bräuchte eine simulierte,
"virtuelle" Mitspieler-ähnliche Entität, die am Handelssystem teilnimmt,
ohne echter Peer zu sein.

**Empfehlung:** nischig, geringe Priorität — nur relevant, wenn Solo-/
wenig-Spieler-Sessions das Handelssystem sonst ungenutzt lassen.

**Aufwand:** groß.

---

## Fahrzeuge

### Mehrere Fahrten bei zu wenig Trage-Kapazität

Hängt am Treibstoff-Punkt vorgelagerten Fahrzeug-Frachtraum-Konzept, das
aktuell GAR NICHT existiert (Fahrzeuge haben nur Sitzplätze, keinen
zusätzlichen Frachtraum — Feldtrupps haben `CARRY_CAPACITY`, Fahrzeuge
nicht).

**Voraussetzung:** erst müsste ein Fahrzeug-Cargo-Konzept eingeführt
werden, bevor "mehrere Fahrten bis beides voll" überhaupt Sinn ergibt.

**Aufwand:** mittel, aber Vorarbeit nötig.

---

## UI/UX

### Zeitraffer/Fast-Forward

**Korrektur (2026-08-04, beim Umsetzen der prozeduralen Häuser entdeckt):
existiert bereits im Code**, entgegen der ursprünglichen Einschätzung
hier — `World._time_scale`, `request_set_time_scale()`/
`_sync_time_scale()` (an alle Peers repliziert, gleiches Muster wie
Pause), 1x/2x/3x-Buttons in `SpeedRow` (`$ResourcesUI/Panel/
VBoxContainer/SpeedRow`), nur für den Host sichtbar. Aus dem offenen
Backlog entfernt — nicht erneut bauen. Falls noch nicht getestet: siehe
`docs/pending-tests.md` (ggf. dort nachtragen, falls es fehlt).

### Automatische Multi-Ziel-Pfadfindung beim Plündern

Aktuell schickt `order_search()` (Survivor.gd) einen Trupp zu GENAU einem
Gebäude (`_pending_building_path`, Singular). Eine Mehrfach-Ziel-
Warteschlange bräuchte eine Erweiterung zu einer Liste offener
Suchziele, die nacheinander abgearbeitet wird — ähnlich der bestehenden
`_waypoints`-Queue für Bewegung, aber für Suchaufträge statt reiner
Bewegung.

**Aufwand:** mittel.

---

## Bewusst nicht in diesem Plan (siehe [[01 Architektur.md]])

Echte-Orte-Karten (OSM), Story-Modus/Sieg-Bedingung, KI-Portraits — alle
drei geprüft und explizit verworfen, siehe Backlog-Abschnitt "Bewusst
NICHT auf dieser Liste" in [[01 Architektur.md]]. Nicht erneut aufgreifen,
außer der Nutzer ändert seine Meinung explizit.

---

## Grobe Reihenfolge-Empfehlung, falls als Nächstes einfach weitergemacht wird

Sortiert nach (a) sofort ohne Rückfrage machbar, (b) Aufwand, (c)
Abhängigkeiten zwischen Punkten:

1. ~~**Universal-Buch-Migration**~~ — erledigt 2026-08-04.
2. **Durst** (klein-mittel, zwei offene Detailfragen, sonst reines
   Kopier-Pattern von Hunger).
3. ~~**Worker-Feedback "kein Arbeiter"**~~ — erledigt 2026-08-04.
4. ~~**Mehr Zombie-Typen**~~ — Runner (dritter Typ) erledigt 2026-08-04,
   siehe `koop-game/docs/zombies.md`. Weitere Varianten weiterhin klein
   pro Typ (Muster jetzt Enum-basiert, siehe dort).
5. ~~**Aktive Rekrutierungs-Aktion**~~ — erledigt 2026-08-04.
6. Alles mit "größere Design-Entscheidung"/"Rückfrage nötig" (Krankheit,
   Reparatur-Ansatz, Kampf-Stances, Lichtscheu) — erst per Rückfrage beim
   Nutzer klären, dann einordnen.
7. Alles mit Abhängigkeit auf die Nahrungsproduktionskette (Dünger,
   Wetter, ablaufende Ressourcen) — nur als zusammenhängender Block
   sinnvoll, nicht einzeln.
8. Große Strukturänderungen (Gebäude-Adaption, Mehrpersonen-Trupps) —
   eigene Planungssession, nicht nebenbei.

---

Verwandt: [[01 Architektur.md]] · [[06 Infection Free Zone Recherche.md]]
