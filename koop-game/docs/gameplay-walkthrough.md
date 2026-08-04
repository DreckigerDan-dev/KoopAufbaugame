# Spielablauf-Walkthrough: alle Mechaniken im Zusammenhang

Diese Datei ist anders als die übrigen `docs/<system>.md`-Dateien — dort
steht pro System das technische "wie und warum" für die Entwicklung, hier
steht der komplette **Spielablauf aus Spielersicht**: was passiert wann,
was sollte ein Spieler in welcher Reihenfolge tun, wie hängen die Systeme
zusammen. Gedacht als Einstieg für einen neuen Mitspieler ODER als
Gesamtüberblick, wenn man den Wald vor lauter Einzeldokus nicht mehr sieht.

Für das technische Detail zu jedem Punkt: Verweis auf die jeweilige
`docs/<system>.md`-Datei. Stand: 2026-08-04, nach dem Zivilisten-Konzept-
Abend. Vieles unten ist **noch nicht vom Nutzer getestet** (siehe
`docs/pending-tests.md`) — dieser Walkthrough beschreibt den
KONZEPTIONELLEN Ablauf laut Code, nicht zwingend den bereits bestätigten.

---

## 1. Bevor es losgeht: Hauptmenü → Lobby → Ladebildschirm

- **Hauptmenü** (`MainMenu.tscn`): Solo, Host oder Join (IP eingeben), plus
  "Laden" für einen bestehenden Spielstand, plus Einstellungen (siehe
  Abschnitt 16).
- **Host-and-Play, kein dedizierter Server** — wer hostet, ist gleichzeitig
  Server und ganz normaler Mitspieler (`docs/networking.md`). Andere joinen
  direkt per IP.
- **Lobby:** Spielerliste, Host drückt "Spiel starten". Ein später
  beitretender Spieler (nach Spielstart) landet automatisch direkt in der
  laufenden Welt statt in der Lobby festzuhängen (Catch-up-Mechanismus,
  `docs/networking.md`).
- **Ladebildschirm:** kurzer Zwischenschritt beim Wechsel in die Welt
  (asynchrones Laden, Fortschrittsbalken, ein zufälliger kosmetischer
  Spruch) statt eines Einfrierens — betrifft Host, Join UND spät
  Beitretende gleichermaßen (`docs/loading.md`).

**Praktisch:** Zum gemeinsamen Testen: Godot-Editor → Debug → Customize Run
Instances → 2 Instanzen → F5. Eine hostet, eine joint über `127.0.0.1`.
**Wichtig:** F6 (einzelne Szene starten) funktioniert NICHT für `World.tscn`
selbst — immer über F5/MainMenu starten, sonst bleibt `NetworkManager.
players` leer und nichts Eigenes spawnt.

## 2. Die erste Entscheidung: Start-Basis wählen

Nach dem Laden der Welt sieht jeder Spieler die Meldung "Wähle deine
Start-Basis — klicke auf eines der Gebäude". Es gibt **fünf Stadt-Zonen**
verteilt auf einer 5000×5000m-Karte (zwei große, drei kleine) plus fünf
Wald-Zonen dazwischen — man klickt auf irgendein noch unbesetztes Gebäude
in irgendeiner Stadt-Zone.

- Das gewählte Gebäude wird **kostenlos und sofort** die eigene Basis
  (keine Suche nötig, gilt als von Anfang an gesichert) — färbt sich
  bläulich wie jedes andere geclaimte Gebäude.
- Die eigentliche `HomeBase` (Ressourcen-Datenmodell) entsteht als
  **eigener, unsichtbarer Node** direkt daneben.
- **Fünf Start-Trupps** spawnen in einer Reihe daneben, alle vom Typ
  Feldtrupp.
- Zwei Spieler können theoretisch gleichzeitig dasselbe Gebäude wählen —
  der erste bekommt den Zuschlag, der zweite muss ein anderes wählen.

Details: `docs/zones.md`, "Start-Basis wählen".

## 3. Steuerung: Kamera, Auswahl, Kontrollgruppen

Reine RTS-Draufsicht, **kein eigener Spieler-Avatar** — jeder Spieler ist
nur Kommandant von oben.

- **Linksklick** wählt einen eigenen Trupp/ein Fahrzeug aus, **Shift-Klick**
  erweitert die Auswahl um weitere.
- **Linksklick auf leeren Boden** mit Auswahl → Bewegungsbefehl,
  **Shift-Klick** hängt einen weiteren Wegpunkt an die bestehende
  Wegpunkt-Schlange an (nicht ersetzen).
- **Rechtsklick+Ziehen** dreht/neigt die Kamera, Mausrad zoomt (`ZOOM_MIN
  26` bis `ZOOM_MAX 80`).
- **Kontrollgruppen 1-9**: Trupps einer Gruppe zuweisen/später per
  Zifferntaste erneut auswählen (Button pro Trupp in der Einheiten-Liste).
- **Formation bei Gruppenbefehlen:** der zuerst ausgewählte Trupp läuft
  exakt zum Klickpunkt, alle weiteren verteilen sich im Kreis darum
  (`FORMATION_RADIUS := 2.0`), mit leicht zeitversetztem Start und
  zufälliger Geschwindigkeits-Varianz — läuft NICHT mehr wie eine
  geschlossene Reihe im Gleichschritt.
- **`M`** öffnet die Vollbild-Kartenansicht (zoombar per Mausrad,
  Rechtsklick verschiebt den Ausschnitt, Linksklick reist hin + schließt),
  **Minimap** unten rechts dauerhaft sichtbar.
- **Gamepad optional:** rechter Stick bewegt einen virtuellen Cursor
  (funktioniert dadurch überall, wo auch die Maus geht — inkl. Hauptmenü),
  A = Linksklick, B = Stopp, linker Stick = Kamera-Pan, LB/RB = Zoom,
  Start = Pause-Menü. Komplett inaktiv ohne angeschlossenen Controller.

Details: `docs/world.md` ("Gamepad-Steuerung", "Kartenansicht",
"Kamera-Zoom-Bereich").

## 4. Trupp-Arten: Feld, Bau, Zivilist

Jeder Survivor ist **ein einzelner Trupp** (kein Mehrpersonen-Squad) und
flexibel zwischen zwei einsetzbaren Typen umschaltbar, plus einem dritten
Zwischenzustand für frische Rekruten:

- **Feldtrupp** (Standard bei Start-Trupps) — kann Gebäude durchsuchen,
  claimen, angreifen. Kann NICHT abbauen (exklusiv, nicht additiv).
- **Bautrupp** — kann ausschließlich abbauen (Bäume fällen, Autowracks/
  Stein-/Ziegelhaufen zerlegen) UND Baustellen-Arbeit leisten (siehe
  Abschnitt 7). Kann NICHT suchen/claimen/angreifen.
- **Zivilist (unzugewiesen)** — Standardzustand JEDES neu rekrutierten
  Trupps (nicht der Start-Trupps). Kann sich nicht bewegen, nicht ins
  Fahrzeug steigen, keine der obigen Aktionen — muss erst manuell (zwei
  Buttons "→Feld"/"→Bau" in der Einheiten-Liste) oder automatisch (siehe
  Abschnitt 12, Auto-Zuweisungs-Dropdown) zugewiesen werden.

Umschalten (Feld↔Bau) geht jederzeit über einen Button pro Trupp in der
Einheiten-Liste, auch mitten in einer laufenden Aktion. Farblich sind
Trupps außerdem individuell unterscheidbar (je Trupp ein eigener,
deterministischer Farbton), Zivilisten deutlich blasser/grauer.

Details: `docs/survivor.md` ("Trupp-Arten"), `docs/recruitment.md`
("Zivilisten-Konzept").

## 5. Ressourcen & Home-Base

Jeder Spieler hat eine **eigene** Home-Base mit eigenem Ressourcen-Pool —
kein gemeinsamer Kolonie-Topf, auch nicht zwischen Koop-Mitspielern.

- **16 Ressourcenarten:** Nahrung, Holz, Metall, Stein, Ziegel, Medizin,
  Munition + fünf Ausrüstungs-Slots (Waffe/Rüstung/Helm/Nahkampfwaffe/
  Beinschutz) + fünf Forschungsbücher.
- **Start-Ressourcen** reichen für eine Zonen-Erweiterung (15 Stein) PLUS
  einen Wachposten (30 Holz) direkt zu Beginn.
- **Vier Baurohstoffe für vier unterschiedliche Bautypen** — Holz
  (Wachposten/Feld), Stein (Mauer/Zonen-Claim), Metall (Tor/Werkstatt),
  Ziegel (Krankenstation).
- **Lagerkapazität** (`storage_capacity`, Standard 150 für ALLE Arten
  gemeinsam) wird durch das "Lager"-Gebäude erhöht (siehe Abschnitt 7) —
  ohne genug Kapazität geht kein weiterer Zuwachs rein, Verluste (Bauen
  etc.) sind immer uneingeschränkt möglich.
- **Ressourcen-Panel** oben rechts, zwei Tabs ("Rohstoffe"/"Ausrüstung"),
  Uhrzeit + Zombie-Zähler bleiben immer sichtbar außerhalb der Tabs.

Details: `docs/base.md`.

## 6. Scavenging: Gebäude plündern

Der Hauptweg an neue Ressourcen/Ausrüstung: Feldtrupp auf ein Gebäude in
einer Stadt-Zone schicken.

- Klick auf ein noch nicht durchsuchtes Gebäude → Trupp läuft hin, kämpft
  sich ggf. durch Zombies (Lärm-System greift), durchsucht es (dauert eine
  Weile), sammelt Loot automatisch ein.
- **14 verschiedene Gebäudetypen**, jeweils eigene Loot-Tabelle (z. B.
  Wohnhaus → Nahrung, Apotheke → Medizin, Waffenladen/Militärbasis →
  Waffen/Munition, Bibliothek/Universität → garantiertes Buch) — NIE
  Baurohstoffe aus Stadt-Loot.
- **Trage-Kapazität begrenzt**, wie viel EIN Run mitbringt — Rückweg zur
  näheren von Home-Base ODER einem eigenen Außenposten (falls vorhanden),
  automatisch eingelagert bei Ankunft.
- **Rückweg ist genauso gefährlich wie der Hinweg** — kein
  Sicherheitsbonus, Zombies können jederzeit angreifen.
- **Loot ist endlich** — ein geplündertes Gebäude bleibt leer (Ausnahme:
  gelegentlicher, goldener "Banditen-Restloot" an schon geplünderten
  Gebäuden, alle drei Minuten Echtzeit-Chance, einmalig).
- **Danach claimen** (15 Stein) macht das Gebäude zum eigenen Bauzonen-
  Anker UND schaltet es fürs Ausbauen frei (siehe Abschnitt 7) — derselbe
  Klick auf ein bereits geplündertes, noch unbesetztes Gebäude löst das
  Claimen aus.
- **Bauen selbst ist inzwischen überall auf der Karte möglich**, nicht nur
  in der eigenen Zone (frühere Abstandsregel wurde entfernt).

Details: `docs/scavenging.md`, `docs/zones.md`.

## 7. Bauen: drei verschiedene Wege

Drei unterschiedliche Bau-Flüsse, je nach Bautyp:

**a) Direkt platzierbar** (Ein-Klick, Baumodus mit Ghost-Vorschau):
Wachposten (30 Holz), Mauer (15 Stein, Ziehen statt Einzelklick), Tor
(20 Metall, ebenfalls gezogen), Feld (20 Holz, produziert passiv 2 Nahrung
alle 8s), Außenposten (15 Holz + 10 Stein, kürzerer Rückweg beim
Plündern), Wachturm (30 Holz + 20 Metall, reine Sichtweite, kein Kampf,
deutlich größerer Fog-of-War-Aufdeckungsradius als eine normale Einheit).

**b) Ausbauen** (nur an einem eigenen, bereits geplünderten UND geclaimten
Gebäude): Krankenstation (25 Ziegel, heilt Trupps in der Nähe doppelt so
schnell wie an der Home-Base), Werkstatt (25 Metall, schaltet Crafting
frei + 20 % Rabatt auf ALLE anderen Baukosten), Lager (Kapazität hängt von
der Gebäudegröße ab), Schlafraum/Bett (20 Holz, regeneriert Müdigkeit +
Moral in der Nähe).

**c) Baustellen (Bau-Markier-Modus)** — seit Punkt 28 läuft (b) nicht mehr
sofort, sondern als echter Bauauftrag: Gebäude claimen → Ziel-Ausbaustufe
festlegen → Gebäude färbt sich amber, Ressourcen sofort abgezogen, aber
NICHTS ersetzt sich sofort → beliebig viele Bautrupps zuweisen (Klick auf
die amberfarbene Baustelle mit ausgewählten Bautrupps, ODER
"Trupp zuweisen"-Button in der Baustellen-Liste im Bauen-Tab) →
Baufortschritt läuft über Zeit, **Tempo skaliert linear mit Anzahl
zugewiesener Trupps**. "Trupp abziehen" macht einen Arbeiter wieder frei,
"Stornieren" storniert mit voller Rückerstattung.

Zusätzlich: **erweiterte Krankenstation** (Forschungsbuch nötig, heilt
dann dreifach statt doppelt), **Werkstatt-Rabatt** gilt für alle Bautypen
außer sich selbst.

Details: `docs/building.md` (alle Unterabschnitte), `docs/walls.md`.

## 8. Bedürfnisse: Hunger, Müdigkeit, Moral

Jeder Survivor hat drei Werte, die über Zeit sinken:

- **Hunger** — sinkt langsam (`0.3`/s, ~über mehrere Minuten leer), unter
  30 % läuft der Trupp merklich langsamer. Steigt wieder, solange der
  Trupp in Home-Base-Nähe steht UND Nahrung im Pool ist (verbraucht 1
  Nahrung pro Tick).
- **Müdigkeit** — sinkt ebenfalls langsam (~11 Minuten bis 0), unter 30 %
  zusätzlicher Tempo-Malus. Regeneriert NUR in der Nähe eines eigenen
  Schlafraums (nicht an der Home-Base selbst), ohne Ressourcenverbrauch.
- **Moral** — sinkt am langsamsten (~22 Minuten bis 0), unter 30 % geringerer
  Angriffsschaden (Nah- UND Fernkampf). Regeneriert genau wie Müdigkeit am
  Schlafraum.

**Praktischer Rat:** früh einen Schlafraum bauen, sonst pendeln Trupps bei
längeren Sessions dauerhaft im Debuff-Bereich.

Details: `docs/survivor.md` ("Bedürfnisse: Müdigkeit + Moral", "Hunger").

## 9. Ausrüstung: Waffen, Rüstung, Crafting, Forschung

- **Fünf Ausrüstungs-Slots pro Trupp:** Hauptwaffe (Fernkampf, braucht
  Munition), Nahkampfwaffe (Sekundärwaffe, greift bei fehlender Haupt-
  waffe/Munition automatisch), Brustpanzer, Helm, Beinschutz — alle drei
  Rüstungsteile reduzieren Schaden multiplikativ zusammen.
- **Zwei Wege, an Ausrüstung zu kommen:** Zombie-Loot-Drop (Zufall, 50 %
  Chance pro Kill, 1 von 7 Typen) ODER Crafting in der eigenen Werkstatt
  (verlässlich, kostet Basis-Rohstoffe: z. B. Waffe = 15 Metall + 10 Holz).
- **Vier Crafting-Rezepte sind Forschungsbuch-gated** — ohne das passende
  Buch (seltener Zombie-Zusatzdrop, 8 % Chance) zeigt der Button nur
  "X erforschen", ausgegraut ohne Buch. Einmal erforscht, dauerhaft
  freigeschaltet für die ganze Kolonie.
- **Ausrüsten/Anlegen** läuft über das Trupp-Detailfenster (fünfter Tab
  "Trupp", erscheint bei Auswahl genau eines eigenen Trupps).

Details: `docs/survivor.md` ("Waffensystem", "Rüstungssystem", "Haupt-/
Sekundärwaffe"), `docs/building.md` ("Herstellen", "Forschungsbücher").

## 10. Zombies & Verteidigung

- **Zwei Zombie-Typen:** Standard-Läufer (40 HP, mäßig schnell) und der
  zähere, langsamere Brute (100 HP, mehr Schaden) — optisch unterscheidbar
  (Größe + Farbton).
- **Normalverhalten:** wandern ziellos in ihrem `WANDER_RADIUS`, erkennen
  Ziele in der Nähe (Trupps, Fahrzeuge mit Insassen, geclaimte Gebäude —
  NICHT ein durchsuchender Trupp im Gebäude, der ist "unsichtbar").
- **Lärm-System:** jeder Angriff alarmiert weitere Zombies im Umkreis auf
  dasselbe Ziel — laute Aktionen (Schüsse, Kämpfe) ziehen also mehr an,
  als nur der unmittelbare Angreifer sieht.
- **Zombie-Nest, eines pro Stadt-Zone:** spawnt alle 25s einen neuen
  Zombie, OHNE Obergrenze, solange es steht — zerstörbar (150 HP) per
  Wachposten-Beschuss oder direktem Trupp-Angriff. Rechtzeitig zerstören
  hält die Population im Griff, stehen lassen lässt sie wachsen.
- **Verteidigung:** Mauern/Tore blockieren Zombie-Pfade (werden als
  Zwischenziel angegriffen, bis kaputt), Wachposten mit mindestens einem
  stationierten Trupp feuern automatisch auf Zombies UND Nester in
  Reichweite.
- **Gegenschaden:** Survivor wehren sich automatisch, wenn sie angegriffen
  werden (kein eigener Befehl nötig) — Mauern/Fahrzeuge haben keinen
  eigenen Gegenangriff.

Details: `docs/zombies.md`.

## 11. Tag/Nacht, Horde-Nächte, Blutmond

- **Ein Spieltag = 5 Minuten Echtzeit** (`CYCLE_LENGTH := 300s`), Nacht von
  22:00 bis 4:00 Spielzeit — sichtbar an der Uhrzeit im Ressourcen-Panel
  und am Licht/Himmel.
- **Nachts 20 % mehr Zombie-Schaden**, unabhängig von Horden.
- **Jede Nacht eine Horde:** genau beim Nachteintritt spawnt eine
  gebündelte Welle (10 Zombies × Spieleranzahl, 2 davon Brutes), warnt
  vorher alle Spieler, läuft geschlossen auf ein zufälliges Ziel zu (kein
  normales Wandern).
- **Jede 5. Nacht: Blutmond** — dieselbe Mechanik, aber 30 Zombies × Spieler-
  anzahl, 10 Brutes, rötlich getönter Himmel, eigene Vorwarnung.
- **Zombie-Obergrenze `MAX_ZOMBIES := 400`** — nur das Nachspawnen aus
  Nestern wird gedeckelt, Horde-Nächte dürfen den Deckel kurz
  überschreiten. Weit entfernte, lange ungestörte Zombies despawnen nach
  einer Weile automatisch (Performance).
- **Pause (nur Host):** hält Zombies/Trupps/Uhr komplett an, für alle
  Spieler sichtbar ("PAUSIERT"), Kamera/UI bleiben bedienbar.

Details: `docs/world.md` ("Tag/Nacht-Zyklus", "Pause"), `docs/zombies.md`
("Horde-Nächte", "Blutmond-Kalender-Eskalation").

## 12. Rekrutierung: neue Trupps bekommen

Drei parallele Kanäle, alle über denselben Mechanismus (`has_survivor`
beim Durchsuchen):

1. **Festes Rekrutierungs-Gebäude** — ein Gebäude pro Stadt-Zone hat
   garantiert einen Survivor zum Befreien, einmalig.
2. **Plünder-Zufallschance** — 15 % Chance bei JEDEM normal durchsuchten
   Gebäude, ungedeckelt.
3. **Schutzsuchende** — alle drei Minuten Echtzeit-Chance (40 %), dass ein
   kleines, sandfarbenes Gebäude irgendwo in der Wildnis auftaucht,
   normal durchsuchbar, gedeckelt auf 2 pro Spieler über diesen Kanal.

**Jeder neue Rekrut startet als unzugewiesener Zivilist** (siehe Abschnitt
4), außer der Spieler hat ein **Auto-Zuweisungs-Profil** gewählt (Dropdown
im Einheiten-Tab): automatisch Feldtrupp, automatisch Baueinheit, oder
automatisch zum ersten eigenen Wachposten schicken (existiert keiner,
bleibt der Rekrut lieber unzugewiesen als still zum Feldtrupp zu werden).

Details: `docs/recruitment.md`.

## 13. Fahrzeuge

- **Drei Typen** (zufällig pro Spawn-Slot, zwei pro Stadt-Zone): Auto (3
  Sitze), Motorrad (1 Sitz, kein Soziussitz, am schnellsten), LKW (5
  Sitze, am langsamsten, hält am meisten aus).
- **Einsteigen:** Klick auf ein unbesetztes Fahrzeug mit ausgewählten
  eigenen Trupps — erster Einsteigender wird Fahrer, weitere bis zur
  Kapazität Mitfahrer.
- **Fahren:** schneller als zu Fuß, folgt in Stadt-Zonen dem echten
  Straßenraster (kein Diagonal-Cut durch Blöcke), außerhalb normale
  Luftlinie.
- **Aussteigen** über eigene Taste (F bzw. Gamepad Y) — betrifft Fahrer
  UND alle Mitfahrer gleichzeitig, kein einzelnes Aussteigen.
- **Unbesetzte Fahrzeuge sind für Zombies keine gültigen Ziele.**

Details: `docs/vehicle.md`.

## 14. Koop-Mechaniken zwischen Spielern

Vier Kanäle, die Zusammenarbeit trotz komplett getrennter Basen
ermöglichen:

- **Geteilte Gefahr** — eine gemeinsame Zombie-Population für die ganze
  Karte, Lärm eines Spielers kann Horden anlocken, die auch bei anderen
  auftauchen.
- **Handel** (Handel-Tab): Schenken (sofort, ohne Gegenleistung) oder
  Tauschangebote (Anbieten/Annehmen/Ablehnen/Zurückziehen) zwischen
  verbundenen Spielern.
- **Gegenseitige Hilfe:** wird ein Trupp/Fahrzeug/geclaimtes Gebäude/eine
  Mauer eines Spielers angegriffen, sehen alle ANDEREN Spieler eine
  Statusmeldung + einen 20s pulsierenden roten Ring auf Minimap/Karte
  (auch in unerkundetem Gebiet sichtbar, Fog of War wird dafür bewusst
  überstrahlt) — 30s Cooldown pro Opfer, kein Dauer-Alarm. Es gibt keine
  Zonen-/Besitzer-Sperre, ein Trupp kann jederzeit einem fremden Spieler
  zu Hilfe eilen.
- **Geteilte Aufklärung (Fog of War):** von EINEM Spieler aufgedecktes
  Gebiet ist sofort auch für alle anderen sichtbar, ohne selbst hinlaufen
  zu müssen.

Details: `docs/trading.md`, `docs/world.md` ("Fog of War", "Gegenseitige
Verteidigung/Hilfe").

## 15. Krise: Home-Base verloren

Seit dem Mechaniken-Bericht (2026-08-04) ist die Home-Base zerstörbar (500
HP, sehr zäh — seltenes, dramatisches Ereignis):

- Bei 0 HP bleibt eine Ruine (normal abreißbar), der betroffene Spieler
  sieht ein Panel mit "Hilfe anfragen" oder "Aufgeben".
- **Solo oder "Aufgeben":** echter Game-Over-Bildschirm ("Neu starten"
  oder "Zurück zum Hauptmenü").
- **Bei ≥2 Spielern, "Hilfe anfragen":** ein Mitspieler sieht die Anfrage
  in der Einheiten-Liste, kann einen eigenen Trupp als
  "Base-Erstellen-Trupp" schicken (golden eingefärbt, kostet den Helfer
  dauerhaft diesen einen Trupp) — der Trupp wechselt den Besitzer, der
  verlorene Spieler kann danach erneut eine Start-Basis wählen (praktisch
  ein Neustart innerhalb derselben Session, neue Start-Trupps inklusive).
- Trupps, die zum Zeitpunkt der Zerstörung unterwegs waren, überleben,
  gelten aber bis zur Rettung als "heimatlos".

Details: `docs/base.md` ("Zerstörbarkeit + Rettungsmechanik").

## 16. Speichern/Laden, Pause, Einstellungen

- **Speichern:** über das Pause-Menü (Escape), host-seitig, ein Slot.
  Praktisch alles Relevante bleibt erhalten (Ressourcen, Trupps inkl.
  Bedürfnisse/Ausrüstung/Trupp-Art, Gebäude inkl. offener Bauaufträge,
  Fahrzeuge, Zombie-Nester, Uhrzeit/Tageszähler) — **bewusste Ausnahme:**
  zugewiesene Bautrupps an einer Baustelle gehen verloren, müssen nach dem
  Laden neu zugewiesen werden.
- **Laden:** über den Hauptmenü-Button.
- **Pause:** siehe Abschnitt 11, nur Host.
- **Einstellungen:** Vollbild, Master-Lautstärke, Maus-Y-Invertieren —
  Overlay sowohl im Hauptmenü als auch im Pause-Menü erreichbar.

Details: `docs/save_load.md`, `docs/settings.md`.

---

## 17. Beispielhafter Spielablauf (Zusammenfassung)

So könnte eine typische Session chronologisch aussehen:

1. Host startet, Mitspieler joint, beide wählen eine Start-Basis in
   unterschiedlichen (oder derselben) Stadt-Zone.
2. Erste Minuten: Feldtrupps in nahegelegene Gebäude schicken, Loot
   sammeln, erstes Gebäude claimen.
3. Sobald genug Ressourcen da sind: Wachposten in Home-Base-Nähe bauen,
   einen Trupp (temporär zum Bautrupp umgeschaltet oder einen freien
   Feldtrupp) als Arbeiter zuweisen — erste Verteidigung steht.
4. Ein geclaimtes Gebäude zur Werkstatt ausbauen (Baustelle → Bautrupps
   zuweisen, warten) — schaltet Crafting + 20 % Rabatt auf alles Weitere
   frei.
5. Ein zweites Gebäude zum Schlafraum ausbauen, sobald Müdigkeit/Moral
   spürbar sinken.
6. Erste Nacht kommt (nach 5 Minuten Echtzeit) — Horde-Warnung, Trupps
   zurückziehen oder am Wachposten verteidigen lassen.
7. Weiter expandieren: mehr Gebäude claimen, Feld für passive Nahrung
   bauen, Krankenstation ausbauen, neue Rekruten (jetzt als Zivilisten)
   den Trupps zuweisen oder Auto-Zuweisung aktivieren.
8. Fahrzeug requirieren für schnellere/weiter entfernte Expeditionen.
9. Mit dem Mitspieler handeln (überschüssige Ressourcen gegen Fehlendes
   tauschen), bei Zombie-Angriffen gegenseitig aushelfen (SOS-Ring).
10. Nach ~25 Minuten die erste Blutmond-Nacht — deutlich größere
    Verteidigung nötig als an normalen Nächten.
11. Falls eine Home-Base fällt: Rettung durch den Mitspieler oder
    Neustart dieses einen Spielers.
12. Laufend: Forschungsbücher sammeln, Waffen/Rüstung craften statt nur
    auf Zombie-Loot zu hoffen, Lager ausbauen, sobald die Kapazität knapp
    wird.

---

## Kurzfassung: worum geht's überhaupt

KoopGame ist ein **Koop-Multiplayer-Survival-Aufbauspiel im Zombie-Setting**
(Stil von *Infection Free Zone*, aber mit 2-4 Spielern statt Solo). Jeder
Spieler baut auf einer gemeinsamen Stadtkarte seine **eigene** Basis auf,
schickt Trupps zum Plündern in verlassene Gebäude, verteidigt sich gegen
täglich stärker werdende Zombie-Horden und kann mit den Mitspielern
handeln oder sich gegenseitig zur Hilfe eilen — trotz komplett getrennter
Ressourcen und Basen. Tagsüber sammeln und ausbauen, nachts verteidigen,
alle paar Tage ein "Blutmond" mit einer besonders großen Horde. Kein
festes Spielziel/Sieg — reines Sandbox-Überleben, das über Zeit
schwieriger wird.

---

Verwandt: alle `docs/<system>.md`-Dateien (siehe `docs/status.md`,
Abschnitt "Systeme", für die vollständige Übersicht), `Infos/00 Übersicht.md`,
`Infos/01 Architektur.md`.
