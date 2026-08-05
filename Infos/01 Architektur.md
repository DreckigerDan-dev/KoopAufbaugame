---
tags:
  - spiel
  - godot
  - architektur
status: aktiv
erstellt: 2026-07-29
aktualisiert: 2026-07-29
---

# KoopGame — Architektur

> [!warning] Ersetzt die alte Etappe-3-Planung
> Diese Notiz hieß vorher "Etappe 3 – Truppen und Plündern" und enthielt
> eine einfache Arbeiter/Truppen-Mechanik. Nach einer Architektur-Session
> mit Claude Code (29.07.2026) ist das Konzept deutlich ausgearbeitet und
> an mehreren Stellen **grundlegend anders**. Der alte Inhalt ist überholt
> und wurde hier vollständig ersetzt. Wichtigste Verschiebungen:
> - Keine einfache "Arbeiter sammeln / Truppen plündern"-Trennung mehr,
>   sondern **Bautrupps** (in der eigenen Zone) und **Feldtrupps**
>   (Expeditionen in die Stadt) — Survivor sind flexibel zuweisbar.
> - Neu dazugekommen: Zonen-Claiming, Survivor-Rollen und -Bedürfnisse,
>   Permadeath, Lärm-basiertes Zombie-Verhalten, Handel/Hilfe zwischen
>   Spielern, Host-and-Play-Netzwerk.
> - Keine feste Truppenzahl (6) oder Arbeiterzahl (30) mehr als Zielgröße —
>   Rekrutierung läuft über Expeditionen, nicht über Startwerte.

Verwandt: [[Koop aufbaugame/00 Übersicht.md]]

---

Koop-Multiplayer-Survival im Stil von *Infection Free Zone*: Basisbau,
Kolonie-/Survivor-Management, Zombie-Horden — nur eben gemeinsam mit
mehreren Spielern statt solo.

## Spielkonzept

- **Kein Spieler-Avatar.** Jeder Spieler ist reiner Kommandant von oben (wie
  im Original) — eigene Kamera + Klick-Auswahl + RTS-Befehle an die eigenen
  Trupps/Survivor. Kein Charakter mit eigener Bewegung/Kollision in der Welt.
- **Jeder Spieler hat seine eigene Basis/Kolonie**, nicht geteilt. Alle
  spielen aber gleichzeitig auf derselben Stadtkarte (Host-and-Play-Session).
- **Ressourcen sind pro Spieler getrennt.** Trupps sammeln Loot bei
  Expeditionen und bringen ihn zur eigenen Basis. Kein gemeinsamer
  Kolonie-Pool zwischen Spielern.
- **Kooperation trotz getrennter Basen** läuft über vier Kanäle:
  - *Gemeinsame Gefahr* — eine geteilte Zombie-Population/Weltzustand wirkt
    auf alle Spieler gleichzeitig.
  - *Handel* — Spieler können Ressourcen untereinander tauschen/geben.
  - *Gegenseitige Verteidigung/Hilfe* — Trupps eines Spielers können einem
    anderen Spieler beim Kämpfen/Verteidigen helfen, auch ohne gemeinsame Basis.
  - *Geteilte Aufklärung* — entdeckte Kartenbereiche (Fog of War) werden
    zwischen Spielern geteilt.

**MVP-Umfang** (alle vier fürs erste spielbare Ziel):
1. Basis/Territorium + Ressourcen
2. Zombies + einfache Verteidigung
3. Scavenging/Expeditionen
4. Survivor-Rollen + Bedürfnisse

---

## Mechanik: Basis/Territorium + Ressourcen

- **Home-Base:** Jeder Spieler startet mit einem kleinen, bereits gesicherten
  Gebäude. Startpunkte liegen automatisch weit genug auseinander.
- **Zone erweitern:** Muss zusammenhängend bleiben — nur an die bestehende
  Zone angrenzende Gebäude sind claimbar (erst säubern, dann claimen).
- **Außenposten:** Kleine, unabhängige Bauten außerhalb der Hauptzone, nur
  zum Rasten/Schlafen der Trupps — Ausnahme von der Zusammenhang-Regel.
- **Bauen:** Mauern/Barrikaden, Wachposten, Lager, Betten, Werkstatt,
  Krankenstation — kostet Baumaterial + Bauzeit.
- **Ressourcen:** Nahrung (verdirbt mit der Zeit), Baumaterial, Medizin,
  Munition. Lagerkapazität hängt von Lagergebäuden ab. Pro Spieler getrennt,
  kein gemeinsamer Pool.

## Mechanik: Trupps/Rollen + Bedürfnisse

- **Rekrutierung:** Survivor werden bei Expeditionen in der Stadt gefunden
  und befreit/überzeugt — kein automatisches Spawnen an der Basis.
- **Zwei Trupp-Arten, Survivor flexibel zuweisbar:**
  - *Feldtrupps* — kämpfen, looten, erkunden Häuser in der Stadt (verlassen die Zone)
  - *Bautrupps* (meist mehrere Personen) — arbeiten nur innerhalb der eigenen
    Zone: Bäume fällen, Autos abbauen, alte Gebäude abreißen für Rohstoffe
- **Rollen** (Sammler, Wache, Arzt, Baumeister) geben passive Boni, schränken
  aber nicht ein, was ein Survivor tun kann.
- **Bedürfnisse:** Hunger/Müdigkeit/Moral sinken über Zeit, senken bei
  niedrigem Stand die Leistung.
- **Permadeath:** Verletzungen sind nicht-tödlich und heilen mit
  Medizin/Rast. Erreicht ein Survivor 0 HP im Kampf, ist er unwiderruflich
  tot — kein Wiederbeleben.

## Mechanik: Zombies + Verteidigung

- **Lärm-System:** Laute Aktionen (Schüsse, Kämpfe, Bauen, Fahrzeuge)
  erzeugen einen Lärm-Radius; Zombies darin werden aufmerksam und laufen zur
  Quelle.
- **Normalverhalten:** Ohne Reiz wandern Zombies in kleinen Gruppen ziellos
  durch die Stadt. Tag/Nacht-Zyklus: nachts mehr/aggressivere Zombies.
- **Zombie-Typen (MVP):** zwei Typen — Standard-Läufer sowie ein zäher
  "Brute" (langsam, viel HP, hoher Schaden).
- **Blutmond-Events:** Alle paar Tage (kalenderbasiert) formiert sich eine
  große, gebündelte Horde und greift gezielt an — zusätzlich zum laufenden
  lokalen Lärm-Aggro, nicht als Ersatz dafür.
- **Verteidigung:** Mauern/Barrikaden blockieren Zombie-Pfade, Wachposten
  mit stationiertem Trupp feuern automatisch auf Zombies in Reichweite.
- **Geteilte Gefahr:** Eine Zombie-Population für die ganze Karte — Lärm
  eines Spielers kann Horden anlocken, die auch bei anderen Spielern
  auftauchen können.

## Mechanik: Scavenging/Expeditionen

- **Ablauf:** Feldtrupp auswählen, Zielgebäude in der Stadt anklicken, Trupp
  läuft hin (Pathfinding), kämpft sich ggf. durch Zombies (Lärm-System
  greift), durchsucht das Gebäude (dauert eine Weile), sammelt Loot.
- **Loot-Tabellen je Gebäudetyp:** Wohnhaus (Nahrung, wenig Medizin),
  Supermarkt (viel Nahrung), Apotheke (viel Medizin), Waffenladen/
  Polizeistation (Munition/Waffen), Werkstatt/Baumarkt (Baumaterial).
- **Trage-Kapazität:** Feldtrupps haben begrenzte Slots, die pro Run
  mitnehmbare Loot-Menge limitieren. Rückweg zur Basis (oder zum
  Außenposten zum Zwischenlagern) nötig, dort wird automatisch eingelagert.
- **Risiko:** Rückweg ist genauso gefährlich wie der Hinweg — kein
  Sicherheitsbonus.
- **Loot ist endlich:** Ein geplündertes Gebäude bleibt leer (kein
  Respawn). Erzeugt echten Wettbewerb zwischen Spielern um Gebäude auf der
  gemeinsamen Karte und treibt Expansion in neue Viertel voran.

---

## Forschungsbücher

Loot-Typ, sammelbar bei Expeditionen (auch in normalen Häusern). Zweck:
werden benötigt, um **erweiterte/fortgeschrittene Gebäude** zu errichten
(Ausbaustufen jenseits der Grundgebäude). Details zu welchen Gebäuden genau
und wie viele Bücher nötig sind: noch offen, wird bei Bedarf ergänzt.

## Ideen-Backlog (Post-MVP, nicht jetzt umsetzen)

Erweitert nach IFZ-Gap-Analyse (siehe [[06 Infection Free Zone Recherche.md]],
Abschnitt "Direkte Inspirations-Ideen für KoopGame" + Chat-Nachtrag
2026-08-04 Abend). Bereits umgesetzte Punkte (Banditen-Restloot,
Fahrzeugtypen, Wachturm, Zivilisten-Konzept) sind hier entfernt, siehe
`koop-game/docs/status.md` für den aktuellen Stand.

**Für jeden Punkt unten gibt es einen konkreten Umsetzungsplan mit
Datei-/Funktionsnamen in [[07 Backlog-Umsetzungspläne.md]]** — dort
zuerst nachschauen, bevor mit einem Punkt begonnen wird.

**Bedürfnisse/Überleben:**
- Durst als drittes Grundbedürfnis (neben Hunger/Müdigkeit/Moral), gleiches
  Decay-/Panel-Muster.
- Krankheit als Zwischenstufe vor Permadeath (vernachlässigte Bedürfnisse
  → Krankheit → im Extremfall Tod), statt nur direktem HP-Permadeath.
- Verletzungsgrad-abhängiger Medizinverbrauch statt pauschaler Heilrate.

**Gebäude/Basis:**
- Sichtbares "Produktion pausiert, kein Worker zugewiesen"-Feedback bei
  eigenen Zonenbauten.
- Reparatur-Mechanik für beschädigte Gebäude/Home-Base (aktuell nur
  Zerstörung → Ruine → Abriss, kein aktiver Reparaturweg).
- Nahrungsproduktionskette (Feld → Scheune → Kochhaus/Konservenfabrik)
  als Alternative zu reinem Scavenging.
- Forschungszentrum als eigenes Gebäude + echter Tech-Baum mit
  Abhängigkeiten (aktuell nur einzelne Buch-gated Rezepte/Ausbaustufen,
  eine Stufe, kein Baum).
  - **Wichtig:** dabei NICHT verschiedene Bücher pro Rezept/Ausbaustufe
    (wie aktuell `book_medical_upgrade` etc.), sondern EIN universelles
    Forschungsbuch, das für jede Freischaltung gleich verwendbar ist —
    einfacheres Ressourcenmodell, ein Loot-Typ statt vieler.
- Wetter-System mit Vorhersage-Gebäude (bis zu X Tage im Voraus planbar).
- Fahrzeug-Werkstatt (Reparatur, Panzerung/Ausbau nachrüsten).
- Aktiv auslösbare Rekrutierungs-Aktion (eigenes "Ruf aussenden"-Gebäude,
  zusätzlich zum passiven Schutzsuchenden-Event).
- Gebäude-Adaption statt strikter Loot/Bau-Trennung: bestimmte geplünderte
  Gebäudetypen behalten nach dem Claimen eine passende Funktion (Werkstatt
  bleibt Werkstatt) statt komplett neutral zu werden — größere
  Architektur-Entscheidung, nicht nebenbei umzusetzen.

**Ressourcen:**
- Treibstoff/Energie für Fahrzeuge (inkl. automatischem Auftanken in
  Reichweite einer Treibstoffquelle).
- Dünger (verbessert Feldertrag, alternativ zu Treibstoff verarbeitbar) —
  hängt an der Nahrungsproduktionskette.
- Ablaufende Ressourcen (z. B. frische Nahrung verdirbt nach X Tagen)
  statt zeitlos haltbarer Vorräte.

**Überlebende/Einheiten:**
- Skill-/Perk-Progression durch Tätigkeit (Scavenging/Fahren/Kämpfen macht
  einzelne Survivor mit der Zeit besser) — Vorsicht: kann zum
  "immer nur den Erfahrensten schicken"-Problem führen, siehe Recherche.
- Kampf-Stances pro Trupp (aggressiv = feuert ohne Provokation, defensiv =
  nur bei Provokation).
- Waffen-Tausch-Interface (Lager ↔ Trupp-Slots), statt nur Ausrüsten über
  das Trupp-Detailfenster.
- Trupp-Mitglieder-Tausch/Trupp-Aufteilen (aktuell sind Trupps atomar).

**Zombies/Bedrohung:**
- Mehrere Zombie-Typen/Varianten (schnell+schwach, langsam+zäh, seltene
  Elite-Variante mit Gruppen-Buff), statt eines einzigen Typs.
- Lichtscheu-Verhalten (Zombies tagsüber inaktiv/versteckt, nachts aktiv)
  als zusätzliche Tag/Nacht-Differenzierung über Horde-Nächte hinaus.
- Kontinuierlicher Lärm-/Aktivitäts-Druck der eigenen Basis (wächst mit
  Zeit/Aktivität), ergänzend zur kalenderbasierten Blutmond-Eskalation.
- Schwierigkeitsgrad-Einstellung (Slider/Preset) statt nur eines
  Standard-Balancings — bei Koop mit gemeinsamer Zombie-Population
  architektonisch nicht trivial (ein Spieler kann nicht einfach "seinen
  eigenen" Schwierigkeitsgrad wählen).

**Fraktionen:**
- Banditen-Fraktion als echte NPC-Gegner mit eigenen Lagern, die
  nachspawnen (aktuell nur "Banditen-Restloot", reine Loot-Mechanik ohne
  echte Gegner).
- Freundliche KI-Überlebendengruppen zum Handeln/Verbünden (unabhängig von
  echten Mitspielern).

**Fahrzeuge:**
- Mehrere Fahrten bei zu wenig Trage-Kapazität (Fahrzeug + Trupp beide bis
  voll beladen, automatisches Pendeln).

**UI/UX (unabhängig von IFZ sinnvoll, nicht nur Nachbau):**
- Automatische Multi-Ziel-Pfadfindung beim Plündern (ein Befehl, mehrere
  Ziele nacheinander).

**Netzwerk/Lobby (2026-08-05, Nutzerwunsch vor dem Freundes-Playtest):**
- Beitreten per Lobby-Code statt/zusätzlich zur rohen IP-Eingabe —
  einfacherer Einstieg für weniger technisch versierte Mitspieler. Wichtig:
  **Späteres Beitreten in eine schon laufende Partie funktioniert bereits**
  (Catch-up-Mechanismus, siehe `koop-game/docs/networking.md`) — hier
  geht's NUR um den Verbindungsweg selbst (Code statt IP), nicht um die
  Late-Join-Fähigkeit an sich.

**Karte/Welt (2026-08-05, nach Recherche-Session zu Performance/OSM):**
- Zonen-/Chunk-Streaming: Welt wird nicht mehr komplett vorab generiert UND
  komplett an jeden Peer gesynkt, sondern nach Spielernähe geladen/entladen
  (gleiches Distanzprinzip wie das bestehende `_despawn_far_zombies()`, nur
  zusätzlich für Gebäude/Ressourcen). Löst den aktuellen Gebäude-Deckel
  (`BUILDINGS_PER_LARGE_ZONE`/`_SMALL_ZONE`, siehe `docs/status.md`) UND
  macht Netzwerk-Catch-up bei vielen Peers/spätem Beitritt robuster.
  **Voraussetzung für den nächsten Punkt.**
- Echte Kartendaten via OpenStreetMap als ZWEITER Weltgenerierungs-Modus,
  wählbar in der Lobby (Zufalls-Sandbox bleibt Standard-Modus, kein
  Ersatz) — Overpass-API liefert Straßen/Gebäude-Umrisse/Tags für einen
  beliebigen Ort; daraus entstehen dieselben Building-Nodes wie im
  Zufallsmodus (Loot/Kampf/Claiming/Netzwerk-Code bleibt identisch, nur
  die Positions-/Typ-Quelle unterscheidet sich). Braucht: Overpass-Abfrage
  + Parsing, Lat/Lon-Projektion, Gebäude-Umriss auf Bounding-Box
  vereinfacht, OSM-Tag→`BUILDING_TYPES`-Mapping, UND eine Lösung für
  unregelmäßige echte Straßen (aktuelles Kachel-Raster ist fest an
  prozedural erzeugte Blöcke gebunden, siehe `_generate_street_slots()`/
  `find_vehicle_path()`). Größenordnung vergleichbar mit der
  ursprünglichen Kartenplanungs-Session. **Erst nach dem Zonen-Streaming
  oben**, sonst trifft ein reales Straßenviertel dieselbe Performance-Wand.
  Reverts die frühere "geprüft und verworfen"-Entscheidung unten (bewusste
  Kurskorrektur, 2026-08-05: als ZUSATZ-Modus statt Ersatz sinnvoll).

**Bewusst NICHT auf dieser Liste (geprüft und verworfen):**
- Story-Modus/Kapitel/Sieg-Bedingung — laut Nutzer explizit nie gewünscht
  (siehe `koopgame_mechanics_review_findings`-Memory), bewusste Abweichung.
- KI-generierte Survivor-Portraits — KoopGame baut Assets bewusst von Hand
  (Blender), keine Relevanz.

---

## Perspektive: Wechsel von 2D auf echtes 3D (Top-Down-Kamera, frei drehbar)

> [!warning] Architektur-Wechsel beschlossen (29.07.2026)
> Ursprüngliche Entscheidung war 2D Top-Down (einfacher zu bauen,
> performanter bei vielen gleichzeitig simulierten Einheiten). Grund für
> den Wechsel: **die Kamera soll sich frei drehen können** — mit
> vorgerenderten 2D-Sprites (3D-Modell aus festem Winkel als Bild
> "fotografiert") funktioniert das nicht, weil dem Sprite die
> Bildinformation für andere Blickwinkel fehlt. Frei drehbare Kamera
> braucht echte 3D-Geometrie in der Szene.
>
> **Konsequenz:** Die bereits fertig gebauten Systeme (Commander, Survivor,
> Home-Base, Zombies, World — siehe "Stand" in
> [[Koop aufbaugame/Claude code/ARCHITECTURE.md]]) laufen aktuell komplett
> auf `Node2D` + 2D-Positions-Sync + 2D-Klickauswahl. Der Umstieg auf
> `Node3D` + `Camera3D` (orthographisch, drehbar) ist kein reiner
> Kamera-Austausch, sondern betrifft Bewegungslogik, Multiplayer-Sync und
> Klickauswahl (Raycasting statt Distanz-Check) in **allen** genannten
> Systemen neu.
>
> **Performance-Punkt bleibt im Blick:** der ursprüngliche Grund für 2D
> (viele gleichzeitig simulierte Zombie-Horden) ist mit dem Wechsel nicht
> automatisch gelöst — bei Bedarf später mit Techniken wie Level-of-Detail,
> Culling oder Multi-Mesh-Instancing gegensteuern, falls es zum Problem
> wird. Noch nicht akut, nur als Merkposten für später.
>
> Die im Projekt von Anfang an aktivierten 3D-Einstellungen (Jolt Physics,
> Forward+-Renderer) waren Godot-4.7-Standardwerte bei der Projekterstellung
> — die werden jetzt tatsächlich gebraucht, statt ungenutzt zu bleiben.

## Netzwerk: Host-and-Play

Ein Spieler ist gleichzeitig Host und Server (Listen-Server), andere joinen
direkt per IP. Kein dedizierter Server. Umsetzung über Godots
High-Level-Multiplayer-API (`ENetMultiplayerPeer`), Host ist Autorität.

Wichtig für später: Bei vielen gleichzeitig simulierten Einheiten (Zombie-
Horden) ist volle State-Replikation jeder einzelnen Einheit teuer. Wenn das
zum Problem wird, eher auf ein command-basiertes Modell wechseln (Clients
schicken Befehle, Host simuliert und repliziert nur relevanten Zustand)
statt jede Transform per `MultiplayerSynchronizer` zu syncen. Noch nicht
gebaut, nur als Hinweis für die Netzwerk-Session.

## Ordnerkonvention

Script liegt jeweils neben seiner Szene im selben Ordner (kein globaler
`scripts/`-Ordner) — Standard-Godot-4-Konvention.

```
koop-game/
├── autoloads/       # Singletons (nur .gd, keine Szene)
├── core/            # reine Logik-/Datenklassen ohne eigene Szene
├── scenes/
│   ├── main_menu/
│   ├── lobby/       # Host/Join-Screen, Spielerliste
│   ├── world/       # die Stadt/Karte
│   ├── entities/
│   │   ├── player/  # kein Avatar — Commander-Node (Kamera, Auswahl, Eingabe) pro Spieler
│   │   ├── survivor/ # rekrutierte Trupps, direkt steuerbar (RTS-Klick)
│   │   └── zombie/
│   └── ui/          # HUD, wiederverwendbare UI-Komponenten
├── assets/
│   ├── sprites/
│   ├── tilesets/
│   ├── audio/
│   └── fonts/
├── addons/
└── docs/
```

## Autoloads

- **GameManager** — globaler Spielzustand (MainMenu/Lobby/InGame), Szenenwechsel.
- **NetworkManager** — Host/Join, Spielerliste, Verbindungsstatus. Aktuell
  nur Grundgerüst, ENet-Verkabelung folgt in der Multiplayer-Session.

## Stand

Aktuell nur Struktur + startbares leeres Projekt (`MainMenu`-Szene als
`run/main_scene`). Movement, Multiplayer-Verkabelung und Gameplay-Systeme
folgen in späteren Sessions.
