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

- Banditen-Fraktion: gelegentlich hinterlassen "Banditen-Camps" kleinen
  Restloot in bereits geplünderten Gebäuden — Grund für gelegentliches
  Zurückkehren, ohne vollen Loot-Respawn.
- Fahrzeuge für Expeditionen/Transport (mehr Trage-Kapazität, schneller,
  aber lauter → zieht mehr Zombies an).
- Forschung/Tech-Baum für Ausbaustufen.
- Nahrungsproduktion (Farmen) als Alternative zu reinem Scavenging.

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

## Performance-Benchmarking (wenn's kritisch wird)

Kein Blick in die Glaskugel für "wie groß darf die Karte sein" — stattdessen
messen, sobald Movement/AI/Multiplayer stehen. Nicht die Terrain-Fläche ist
der Engpass, sondern **Anzahl gleichzeitig simulierter Einheiten** (Zombies
vor allem) und **Netzwerk-Sync** bei mehreren Spielern.

**Vorgehen:**

1. **Eigene Testszene** (`zombie_stress_test.tscn`), kein Blick ins echte
   Spiel nötig — Terrain-Plane + N Zombie-Instanzen mit echter AI/Pathfinding
   (kein Dummy, sonst ist die Messung wertlos). Script zählt die Anzahl in
   Zehnerschritten hoch (10 → 20 → 50 → 100 …).
2. **Godots eingebaute Werkzeuge nutzen:**
   - *Debugger → Monitors*: FPS, Physics/Process Frame Time als Graph
   - *Debugger → Profiler*: zeigt, ob Script/AI, Physics oder Rendering die
     Zeit frisst
   - *Debugger → Visual Profiler*: Draw Calls/Vertices, relevant fürs
     Low-Poly-Rendering
   - *Debugger → Network Profiler*: sobald Multiplayer läuft, Bandbreite pro
     `MultiplayerSynchronizer` — direkt relevant für den oben genannten
     State-Replikations-Engpass
3. **Ergebnis loggen statt nur zuschauen**, z. B.:
   ```gdscript
   func _process(delta):
       if Engine.get_frames_drawn() % 60 == 0:
           print("Zombies: %d | FPS: %.1f | Frame-Zeit: %.2fms" % [
               zombie_count, Engine.get_frames_per_second(), delta * 1000
           ])
   ```
   Werte (Zombie-Anzahl → FPS) irgendwo festhalten, um den Kipp-Punkt zu
   sehen (z. B. "ab 150 Zombies unter 30 FPS").
4. **Reihenfolge:** erst Zombies alleine hochskalieren (Baseline), dann
   Gebäude-Anzahl separat, dann kombiniert in Ziel-Kartengröße, **erst
   danach** Multiplayer/Netzwerk dazuschalten — sonst vermischt sich
   Rendering-/AI-Last mit Netzwerk-Last und der eigentliche Engpass bleibt
   unklar.

Noch nicht akut (siehe Perspektive-Hinweis oben), nur als Vorgehen für den
Zeitpunkt, wenn Movement/Multiplayer/Zombie-AI stehen und die Frage konkret
wird.

---

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

> [!warning] Veraltet — siehe [[Koop aufbaugame/00 Übersicht.md]]
> Dieser Absatz stammt vom Projektstart (29.07.2026, "nur Struktur +
> leeres Projekt") und wurde seither nicht mitgepflegt. Der tatsächlich
> laufend aktuelle Stand steht in **[[Koop aufbaugame/Claude code/status.md]]**
> bzw. der kurzen Momentaufnahme in `00 Übersicht.md`, "Stand
> (2026-07-31)" — dort auch die größten verbleibenden Lücken zu dieser
> Architektur-Vision (Crafting, Forschungsbücher, Handel, Survivor-Rollen/
> Bedürfnisse, differenzierte Gebäude-/Fahrzeugtypen, Blutmond-Eskalation).
