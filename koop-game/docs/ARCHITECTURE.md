# KoopGame — Architektur

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

## Ideen-Backlog (Post-MVP, nicht jetzt umsetzen)

- Banditen-Fraktion: gelegentlich hinterlassen "Banditen-Camps" kleinen
  Restloot in bereits geplünderten Gebäuden — Grund für gelegentliches
  Zurückkehren, ohne vollen Loot-Respawn.
- Forschung/Tech-Baum für Ausbaustufen.
- Nahrungsproduktion (Farmen) als Alternative zu reinem Scavenging.

## Perspektive: 2D Top-Down → 3D (abgeschlossen)

Ursprüngliche Entscheidung für 2D statt 3D: einfacher zu bauen und
performanter bei vielen gleichzeitig simulierten Einheiten. Die im Projekt
aktivierten 3D-Einstellungen (Jolt Physics, Forward+-Renderer) waren dafür
zunächst nur ungenutzte Godot-4.7-Standardwerte.

**Update:** Wunsch nach echter 360°-Kamerarotation (in 2D mit `Camera2D`
nicht möglich) führte zum schrittweisen Umstieg auf 3D (Fundament zuerst,
dann Entity für Entity, isoliert in einer Testszene erprobt) — der komplette
Verlauf inklusive aller unterwegs gefundenen Bugs steht in
[`docs/3d-migration.md`](3d-migration.md). **Das ist jetzt abgeschlossen:**
`scenes/world/World.tscn` und alle Entities (`Survivor`, `Zombie`,
`HomeBase`, `GuardPost`, `Building`) sind 3D (`Node3D`/`Vector3`), das
2D-Fundament (`Node2D`/`Vector2`/`ColorRect`/`Camera2D`) ist komplett ersetzt.
`Commander.gd` als eigener gespawnter Node ist entfallen — Kamera + Auswahl +
Befehle laufen jetzt direkt in `World.gd`, weil Kamera-Zustand nie über das
Netzwerk repliziert werden muss (jeder Peer hat ohnehin nur seine eigene
lokale Szeneninstanz). Bekannte Regression: Rekrutierung (siehe
`docs/recruitment.md`) ist in der 3D-Fassung noch nicht nachgebaut.

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
│   ├── world/       # die Stadt/Karte (3D) + Building.gd
│   ├── entities/
│   │   ├── survivor/ # Survivor-Trupps, direkt steuerbar (RTS-Klick)
│   │   ├── zombie/
│   │   └── base/    # HomeBase, GuardPost
│   └── ui/          # aktuell leer — HUD/BuildUI/UnitsUI sind seit dem
│                    # 3D-Umstieg direkt in World.tscn eingebettet
├── assets/
│   ├── sprites/
│   ├── tilesets/
│   ├── audio/
│   └── fonts/
├── addons/
└── docs/
```

**Kein eigener `player/`-Ordner mehr:** Der frühere Commander-Node (Kamera,
Auswahl, Eingabe pro Spieler) ist seit dem 3D-Umstieg direkt in `World.gd`
gefaltet, siehe "Perspektive" oben.

## Autoloads

- **GameManager** — globaler Spielzustand (MainMenu/Lobby/InGame),
  `change_state()` wechselt Szene passend zum State und feuert `state_changed`.
- **NetworkManager** — Host/Join über `ENetMultiplayerPeer` (Listen-Server,
  Host = Peer-ID 1), Spielerliste (`players`) inkl. Namensaustausch per RPC,
  Signale für Connect/Disconnect/Fehler.

## Stand

Kompletter Flow MainMenu → Lobby → Welt ist spielbar, jetzt komplett in 3D
(siehe `docs/3d-migration.md` für den Migrationsverlauf): Host/Join
([`docs/networking.md`](networking.md)), Lobby mit Host-only "Spiel
starten"-Button, 100×100 große Platzhalter-Karte mit acht durchsuchbaren
Platzhalter-Gebäuden verschiedener Größe/Farbe, auf der pro Spieler
automatisch eine eigene Kamera (Pan/Zoom/Rotation/Neigung + Klick-Auswahl +
Bewegungsbefehl, direkt in `World.gd` statt einem eigenen Commander-Node —
siehe "Perspektive" oben), eine Home-Base mit eigenem Ressourcen-Datenmodell
([`docs/base.md`](base.md)) und zwei Survivor-Trupps
([`docs/survivor.md`](survivor.md), host-autoritativ simuliert) an einem
eigenen Startpunkt in einer eigenen Kartenecke gespawnt werden
([`docs/world.md`](world.md)). Linksklick auf ein Gebäude schickt einen
Trupp hin und lässt ihn automatisch durchsuchen (nach `SEARCH_DURATION`) —
Loot landet direkt in den eigenen Ressourcen, geplündert bleibt endgültig
leer ([`docs/scavenging.md`](scavenging.md)). Ein HUD zeigt die eigenen
Trupps + Ressourcen live an. Zombies wandern, erkennen nahe Survivor aber
und verfolgen/greifen sie an ([`docs/zombies.md`](zombies.md)) — Survivor
haben dafür HP, sterben unwiderruflich bei 0 (Permadeath) und heilen passiv
(kostet Medizin), wenn sie sich (nach kurzer Kampfpause) in der Nähe der
eigenen Home-Base aufhalten (siehe [`docs/survivor.md`](survivor.md)).
Zombies haben eigenes HP und nehmen automatisch Gegenschaden vom
angegriffenen Survivor — Kämpfe können in beide Richtungen tödlich enden.
Ein Lärm-System sorgt dafür, dass ein laufender Kampf auch weiter entfernte
Zombies anlockt ([`docs/zombies.md`](zombies.md)). Spieler können außerdem
Wachposten bauen (eigenes Baumenü-Panel: Button aktiviert Baumodus, nächster
Weltklick platziert, kostet Baumaterial + Bauzeit, feuert danach automatisch
auf Zombies in Reichweite und erzeugt dabei ebenfalls Lärm) — noch ohne
Zonen-/Claiming-System, nur mit Radius-Prüfung um die eigene Basis
([`docs/building.md`](building.md)) — der Wachposten feuert dabei nur,
solange mindestens ein per UI-Button zugewiesener Arbeiter dort stationiert
ist, ganz ohne Weltklick (Button sucht sich selbst einen freien Trupp).
Survivor haben außerdem Hunger, der über Zeit sinkt, bei niedrigem Stand die
Bewegungsgeschwindigkeit halbiert und durch Essen (verbraucht Nahrung) an
der eigenen Basis wieder steigt (siehe `docs/survivor.md`, "Hunger").
Kontrollgruppen (Strg+Zifferntaste oder UI-Panel) erlauben, mehrere Trupps
gemeinsam zu steuern; Shift+Klick hängt Wegpunkte an eine Bewegungs-Schlange
an, statt das Ziel zu ersetzen. Mauern und Tore (zweiter/dritter Bautyp
neben dem Wachposten) blockieren echt — Mauern jeden (auch die eigenen
Trupps), Tore nur Fremde/Zombies, Zombies müssen sie erst durchbrechen
(HP, siehe [`docs/walls.md`](walls.md)). **Rekrutierung** (siehe
`docs/recruitment.md`) ist inzwischen auch in der 3D-Fassung 1:1 nach dem
2D-Original nachgebaut: ein durchsuchtes Gebäude mit `has_survivor = true`
spawnt einen zusätzlichen Survivor. Zwei **Fahrzeuge** sind fest in der
Stadt platziert (kein Bautyp) — ein Trupp muss hinlaufen und einsteigen,
danach fährt es sich wie ein schnellerer, dafür lauterer Trupp-Ersatz ohne
eigenen Angriff (siehe [`docs/vehicle.md`](vehicle.md)). Scavenging hat
inzwischen eine echte Trage-Kapazität (20 Ressourcen gesamt) und einen
automatischen, ungeschützten Rückweg zur Basis (siehe
[`docs/scavenging.md`](scavenging.md), "Rückweg") — kein Sofort-Teleport
des Loots mehr. Noch offen: echtes Stadtlayout/Assets,
Zonen-Erweiterung/Claiming, weitere Gebäudetypen, eigener Angriffsbefehl,
Außenposten zum Zwischenlagern, Müdigkeit/Moral, Survivor-Rollen.

## Doku-Konvention

Für jedes größere System gibt es neben `ARCHITECTURE.md` (Gesamtüberblick,
Spielkonzept) eine eigene Doku unter `docs/<system>.md` — was der Code macht,
Funktion für Funktion, und wie man ihn für neue Features erweitert (siehe
`docs/networking.md` als Beispiel). Wird ein System um neue Dateien/Funktionen
ergänzt, wird die zugehörige Doku im selben Schritt mit aktualisiert.
