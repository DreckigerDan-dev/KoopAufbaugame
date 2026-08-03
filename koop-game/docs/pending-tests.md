# Offene Tests

## Balance-Fixes aus dem Mechaniken-Bericht (2026-08-04)

Größter Umfang seit dem Bau-Markier-Modus — 6 zusammenhängende Änderungen,
gründlich gegentesten.

**Home-Base zerstörbar + Rettung:**
1. ⬜ Eigene Home-Base von Zombies angreifen lassen (500 HP, dauert) —
   sollte sich sichtbar rot einfärben, bei 0 HP eine graue Ruine
   hinterlassen (normal abreißbar für Standard-Ressourcen).
2. ⬜ Nach Zerstörung: eigenes Panel "Hilfe anfragen"/"Aufgeben" sollte
   erscheinen. Bei ≥2 Spielern: "Hilfe anfragen" sichtbar, Mitspieler
   sieht die Anfrage im Einheiten-Tab (RescueList).
3. ⬜ Mitspieler wählt eigenen Trupp aus, drückt "Trupp senden" — Trupp
   sollte golden werden, Besitzer wechseln, verlorener Spieler sollte
   danach wieder eine Start-Basis wählen können (neue Trupps + Basis).
4. ⬜ "Aufgeben" (oder Solo) → echter Game-Over-Bildschirm, "Neu starten"
   und "Zurück zum Hauptmenü" sollten beide funktionieren.
5. ⬜ Speichern/Laden: Home-Base-HP bleibt erhalten (nicht auf 500
   zurückgesetzt, falls vorher beschädigt).

**Rekrutierung:**
6. ⬜ Mehrere Gebäude durchsuchen (ohne das feste Rekrutierungs-Gebäude)
   — ab und zu (grob 1 von 6-7) sollte ein neuer Trupp auftauchen.
7. ⬜ Nach einigen Minuten sollte irgendwo in der Wildnis ein
   Schutzsuchender (kleines, sandfarbenes Gebäude) auftauchen und normal
   durchsuchbar sein. Nach 2 erfolgreichen Rekrutierungen über diesen Weg
   sollte ein dritter Schutzsuchender KEINEN neuen Trupp mehr geben
   (Statusmeldung "zieht weiter").

**Zombie-Skalierung:**
8. ⬜ Mit 2 Spielern: Horde-Nächte sollten sichtbar größer sein als mit
   nur 1 Spieler (grob doppelt so viele Zombies).

**Pause:**
9. ⬜ Host: "Spiel pausieren" im Pause-Menü — Zombies/Trupps/Tag-Nacht-Uhr
   sollten komplett stehen bleiben, "PAUSIERT" oben sollte erscheinen
   (auch beim Mitspieler-Client). Kamera/UI sollten weiter bedienbar
   bleiben. "Spiel fortsetzen" macht alles wieder rückgängig.
10. ⬜ Mitspieler (nicht Host) sollte KEINEN Pause-Button sehen.

**Ressourcen/Bedürfnisse:**
11. ⬜ Neues Spiel starten — Start-Ressourcen sollten spürbar mehr sein
    als vorher (Zonen-Erweiterung + Wachposten sollten sofort möglich
    sein).
12. ⬜ In einer Stadt-Zone sollten jetzt auch ein paar Bäume/Steinhaufen/
    Ziegelhaufen/Autowracks stehen, nicht nur in der Wildnis.
13. ⬜ Hunger sollte spürbar langsamer sinken als vorher (vorher komplett
    leer in etwas über einer Minute, jetzt über mehrere Minuten).

## Korrektheits-Fixe aus dem Code-Review (2026-08-04)

Reine Bugfixes, kein neues Feature — trotzdem gezielt gegentesten, da sie
Ressourcen-Wirtschaft betreffen.

1. ⬜ Mehrere Bautrupps (2-3) gleichzeitig auf denselben Baum/dasselbe
   Autowrack ansetzen (einzeln nacheinander anklicken, nicht übers
   Markier-System) — sollte jetzt nur EINEN Ertrag beim Fällen geben,
   nicht mehrfach.
2. ⬜ Zombie gleichzeitig von Wachposten UND einem angreifenden Survivor
   (Gegenschaden) tödlich treffen lassen — sollte nur EINEN Loot-Drop
   geben, nicht zwei.
3. ⬜ Ein Rezept erforschen (Buch verbrauchen), speichern, zum Hauptmenü,
   laden — Crafting-Button sollte weiterhin "herstellen" zeigen, nicht
   wieder "erforschen" (siehe `save_load.md`).
4. ⬜ Spät beitretender Peer sieht einen schon fertigen Wachposten eines
   anderen Spielers sofort in der normalen (nicht "im Bau"-gelben) Farbe.

## Ladebildschirm (siehe `loading.md`, 2026-08-04)

**Vom Nutzer bestätigt (2026-08-04):** "passt hab paar mal getesten" —
Grundfunktion (Anzeige, Sprüche, kein Einfrieren mehr) läuft. Einzelne
Detailpunkte unten nicht explizit erwähnt, vermutlich im "passt"
mit eingeschlossen (kein Gegenteiliges berichtet).

1. ✅ "Spiel starten" in der Lobby (oder Solo/Laden im Hauptmenü) zeigt
   jetzt kurz den Ladebildschirm (dunkler Hintergrund, "Lädt ...",
   zufälliger Spruch, Fortschrittsbalken) statt eines Einfrierens, bevor
   die Welt erscheint.
2. ⬜ Fortschrittsbalken bewegt sich sichtbar von 0 auf 100, bleibt nicht
   bei 0 stehen und springt nicht sofort auf 100. (Nicht explizit erwähnt.)
3. ⬜ Bei zwei Clients (Debug → Customize Run Instances): beide sehen den
   Ladebildschirm unabhängig voneinander, kein Hängenbleiben, wenn ein
   Client langsamer lädt als der andere.
4. ⬜ Spät beitretender Peer (Host schon `IN_GAME`) durchläuft beim
   Beitritt ebenfalls kurz den Ladebildschirm, landet danach korrekt in
   der laufenden Welt (Catch-up funktioniert wie vorher).
5. ⬜ "Laden"-Button im Hauptmenü (Speicherstand) funktioniert weiterhin —
   `SaveManager.pending_load` wird trotz des zwischengeschalteten
   Ladebildschirms korrekt von `World._ready()` aufgegriffen.

## Bau-Markier-Modus mit zuweisbaren Bautrupps (siehe `building.md`, "Baustellen", 2026-08-04)

Größter Umbau der aktuellen Feature-Phase (Punkt 28) — mehrschrittiger
Flow, braucht gründliches Testen.

1. ⬜ Eigenes, geplündertes+geclaimtes Gebäude anklicken, "Zu
   Krankenstation ausbauen" (o. Ä.) drücken — Gebäude verschwindet NICHT
   sofort, färbt sich stattdessen amber, taucht in der neuen "Baustellen"-
   Liste im Bauen-Tab auf (0 Trupps, 0% Fortschritt). Ressourcen sofort
   abgezogen.
2. ⬜ Mehrere Bautrupps auswählen, auf die amberfarbene Baustelle klicken
   ODER "Trupp zuweisen" in der Liste drücken — alle ausgewählten Trupps
   laufen hin und werden als Arbeiter gezählt (Anzeige "X Trupps" in der
   Liste steigt).
3. ⬜ Fortschritt beschleunigt sich sichtbar mit mehr zugewiesenen Trupps
   (z. B. 1 vs. 3 Bautrupps auf derselben Baustelle vergleichen) — sollte
   ungefähr linear schneller gehen.
4. ⬜ Bei Fertigstellung: Gebäude wird durch die Zielstruktur ersetzt
   (Krankenstation/Werkstatt/Lager/Schlafraum), alle zugewiesenen Trupps
   werden automatisch wieder frei (nicht mehr stationiert).
5. ⬜ "Trupp abziehen" zieht einen zugewiesenen Trupp wieder ab, der dann
   wieder frei beweg-/auswählbar ist.
6. ⬜ "Stornieren" storniert den Bauauftrag, Ressourcen kommen zurück,
   Gebäude fällt zurück auf normal geclaimt (blau statt amber), alle
   zugewiesenen Trupps werden frei.
7. ⬜ Nur Bautrupps (nicht Feldtrupps) können einer Baustelle zugewiesen
   werden — Feldtrupp auswählen und auf eine Baustelle klicken sollte eine
   Fehlermeldung zeigen, keine Bewegung auslösen.
8. ⬜ Speichern + Laden (oder spät beitretender Peer): offener Bauauftrag
   inkl. Zieltyp und Fortschritt bleibt erhalten — ABER zugewiesene Trupps
   gehen bewusst verloren (siehe `docs/building.md`, "Baustellen",
   "Bewusste Lücke"), müssen manuell neu zugewiesen werden. Prüfen, ob das
   in der Praxis wie erwartet wirkt (kein Absturz, keine Geister-Trupps).
9. ⬜ Performance-Gegenprobe: `Building.gd` hat jetzt erstmals ein eigenes
   `_process()` (host-only) für ALLE Gebäude, nicht nur die mit offenem
   Bauauftrag — jetzt 1750 Gebäude im Stresstest (siehe `benchmarks.md`,
   2026-08-04 nochmal von 1050 hochgeschraubt, "schraub einfach hoch ich
   teste dann") — kurzer FPS-Vergleich, ob das spürbar reinschlägt (sollte
   durch den frühen `if not has_open_construction: return` sehr billig
   sein, aber noch nicht gemessen). Gleicher Test deckt auch die neue
   Bäume-/Ressourcen-Erhöhung (150/800/320/400/400) mit ab.

## Formation natürlicher: Geschwindigkeits-Varianz + gestaffelter Start (siehe `commander.md`, 2026-08-04)

Nutzer-Feedback nach dem Kreis-Formation-Update: "truppen laufen auf einer
linie sollen er natürlicher laufen".

1. ⬜ Mehrere eigene Trupps auswählen, gemeinsamen Bewegungsbefehl über
   eine längere Strecke geben (querfeldein, nicht nur wenige Meter) —
   die Gruppe sollte jetzt sichtbar NICHT mehr wie eine geschlossene Reihe
   im Gleichschritt loslaufen (Anführer sofort, Rest leicht zeitversetzt
   und mit leicht unterschiedlichem Tempo).
2. ⬜ Shift-Klick (zusätzlicher Wegpunkt an bestehende Schlange anhängen)
   löst den gestaffelten Start NICHT erneut aus — ein bereits laufender
   Trupp darf beim Anhängen nicht plötzlich stehen bleiben/verzögern.
3. ⬜ Fahrzeuge weiterhin normal steuerbar (Straßen-Pathing unverändert) —
   `Vehicle.order_move()` hat jetzt denselben zusätzlichen Parameter wie
   `Survivor.order_move()`, rein aus Signatur-Kompatibilität mit dem
   generischen Aufruf in `World._select_at()`.

## Formation: Anführer + Kreis statt Raster (siehe `commander.md`, 2026-08-03)

Nutzer-Feedback aus dem ersten echten Koop-Test: "truppen laufen immernoch
zu nah zusammen die sollten sich wie ein gruppe verhalten einer vorne die
ander um ihn rum bissle vereteilt".

1. ⬜ Mehrere eigene Trupps auswählen (Shift-Klick), gemeinsamen
   Bewegungsbefehl geben — der ZUERST ausgewählte Trupp läuft exakt zum
   Zielpunkt, alle weiteren verteilen sich sichtbar im Kreis darum, nicht
   mehr in einem engen Raster/Klumpen.
2. ⬜ Deutlich mehr Abstand zwischen den Trupps als vorher (`FORMATION_
   RADIUS := 2.0` statt der alten 1.2m-Rasterlücke) — Gegenprobe, ob das
   fürs Gefühl "nicht mehr zu nah zusammen" reicht oder noch mehr Abstand
   nötig ist.
3. ⬜ Funktioniert auch beim Gruppen-Angriffsbefehl (mehrere Trupps auf
   einen Zombie/Nest) und beim Bau-/Claim-Befehl auf ein Gebäude, nicht
   nur bei reiner Bodenbewegung — `_formation_offset()` wird an allen drei
   Stellen genutzt.

## Schnell-Check vor jedem tieferen Test (immer zuerst)

1. ✅ F5 (Solo reicht) — Konsole beim Start auf GDScript-Parse-/
   Laufzeitfehler prüfen (warnings-as-errors, siehe `ARCHITECTURE.md`).
   **Vom Nutzer getestet (2026-08-03, per Screenshot):** ein Parser-Fehler
   gefunden und behoben (`viewport_size`-Typinferenz in der
   Gamepad-Steuerung) — seitdem noch nicht erneut bestätigt, ob der
   gesamte 2026-08-03-Abend-Batch fehlerfrei startet.

## Gamepad-Steuerung (siehe `world.md`, "Gamepad-Steuerung")

**Braucht echte Controller-Hardware zum Testen** (ROG Ally/Steam Deck/
Xbox-Controller/o.ä.) — kann ohne angeschlossenes Gamepad NICHT
mitgetestet werden, per Design komplett inaktiv ohne eines.

0. ⬜ **(Neu nach dem Hauptmenü-Bugfix)** Mit angeschlossenem Controller
   OHNE Maus/Tastatur anzurühren: rechter Stick bewegt den Mauszeiger
   schon im Hauptmenü sichtbar, A-Taste klickt "Solo"/"Host"/"Join" —
   kompletter Flow MainMenu → Lobby ("Spiel starten" per Cursor+A) → Welt
   rein per Controller erreichbar (das war der ursprünglich gemeldete
   Bug: "konnte kein controller im hauptmenü benutzen").
1. ⬜ Linker Stick bewegt die Kamera (Pan), genau wie WASD.
2. ⬜ Rechter Stick bewegt den Mauszeiger sichtbar über den Bildschirm.
3. ⬜ A-Taste an einem eigenen Trupp klickt/wählt ihn aus, wie ein
   Linksklick.
4. ⬜ A-Taste auf leerem Boden mit ausgewähltem Trupp löst einen
   Bewegungsbefehl aus.
5. ⬜ Im Baumodus: A-Taste platziert ein Gebäude wie ein Linksklick;
   bei Mauer/Tor: A HALTEN + rechten Stick bewegen zieht eine Mauerlinie
   wie Klicken+Halten+Ziehen mit der Maus.
6. ⬜ B-Taste (kurz getippt) stoppt ausgewählte Einheiten.
7. ⬜ Linker Trigger HALTEN + rechter Stick dreht/neigt die Kamera statt
   den Cursor zu bewegen.
8. ⬜ LB/RB zoomen rein/raus, wiederholt beim Halten.
9. ⬜ UI-Buttons (Bauen-Tab, Tab-Wechsel Bauen/Herstellen/Einheiten/Trupp/
   Handel) lassen sich mit Cursor+A genauso anklicken wie mit der Maus.
10. ⬜ Start-Taste öffnet/schließt das Pause-Menü.
11. ⬜ Back/View-Taste öffnet/schließt die Kartenansicht; ein Klick
    (Cursor+A) darin springt die Kamera dorthin und schließt sie wieder.
12. ⬜ Y-Taste lässt einen gefahrenen Trupp aus dem Fahrzeug aussteigen.
13. ⬜ Maus/Tastatur funktionieren an einem NICHT angeschlossenen Gamepad
    weiterhin unverändert (Gegenprobe: kein Regressionsrisiko).
14. ⬜ Test auf dem ROG Ally des Freundes: Spiel startet, Fenster/UI
    skaliert vernünftig auf dem kleineren Handheld-Bildschirm.

## Kartenansicht-Legende + Gebäude-Farbcode (siehe `world.md`)

**Vom Nutzer bestätigt (2026-08-03):** "map legende passt auch".

## Kartenansicht zoombar (siehe `world.md`, "Kartenansicht zoombar", 2026-08-03)

**Vom Nutzer bestätigt (2026-08-03):** "map passt".

1. ✅ Mausrad in der Kartenansicht (`M`) zoomt rein/raus, Symbole
   (Gebäude/Einheiten/Zombies) bleiben dabei an ihrer korrekten relativen
   Position.
2. ✅ Beim Öffnen (`M`) ist die Karte immer wieder auf volle Übersicht UND
   auf die eigene aktuelle Position zentriert — kein alter Zoom-/Pan-Stand
   vom letzten Mal.
3. ✅ Rechtsklick verschiebt den Kartenausschnitt (ohne die 3D-Kamera zu
   bewegen, ohne die Karte zu schließen) — funktioniert auch beim
   Reingezoomt-Sein zur Navigation.
4. ✅ Linksklick reist weiterhin wie bisher zur geklickten Stelle UND
   schließt die Karte (unverändert, auch beim Reingezoomt-Sein — springt
   dann korrekt zur tatsächlich angeklickten Weltposition, nicht zur
   ungezoomten).
5. ✅ Symbole außerhalb des sichtbaren Kartenausschnitts (beim
   Reingezoomt-Sein) verschwinden sauber am Panelrand, keine
   Überzeichnung außerhalb des Kartenpanels.
6. ⬜ Mit Gamepad: LB/RB zoomen die Kartenansicht rein/raus, SOLANGE sie
   offen ist (nicht die 3D-Kamera); B (Rechtsklick) verschiebt den
   Ausschnitt, A (Linksklick) reist hin + schließt — alles ohne Maus
   bedienbar. Noch nicht explizit mit Controller bestätigt (nur "map
   passt" allgemein, unklar ob mit Maus oder Controller getestet).

## Benchmark: mehr Gebäude/Bäume/Ressourcen (siehe `status.md`, 2026-08-03)

**Vom Nutzer bestätigt (2026-08-03):** "fps gehen mit den häusern auch".

1. ✅ FPS/Frametime im normalen Spielverlauf (nicht F9-Zombie-Stresstest)
   mit den neuen, deutlich höheren Zahlen (1050 Gebäude, 400 Wald-Bäume,
   verdoppelte Wildnis-Ressourcen) — bestätigt unauffällig, kein genauer
   Messwert genannt (siehe `docs/benchmarks.md` für künftige konkrete
   Zahlen, falls der Nutzer welche nachreicht).
2. ✅ Karte wirkt spürbar dichter bebaut/bewaldet, keine sichtbaren
   Overlaps trotz der höheren Dichte (Straßen-Raster/Mindestabstand
   sollten das weiterhin verhindern).

1. ✅ In der Kartenansicht (`M`) zeigt ein neues Panel oben links vier
   Farbfelder (Nahrung orange, Medizin grün, Ausrüstung rot, Bücher lila)
   mit Beschriftung plus eine fünfte Zeile für den gelben "Loot
   verfügbar"-Rahmen.
2. ✅ Unbesetzte Gebäude zeigen die Farbe ihrer Loot-Kategorie statt des
   alten einheitlichen Grautons — z. B. Apotheke/Klinik grün, Bibliothek/
   Universität lila.
3. ⬜ Sobald ein Gebäude geclaimt ist, überschreibt die Besitzer-Farbe
   (eigen/verbündet) wieder die Kategorie-Farbe.
4. ✅ Minimap bleibt unverändert (kein Farbcode/keine Legende dort,
   bewusste Entscheidung wegen Platzmangel).

Abhakbare Checkliste für Features, die umgesetzt, aber noch nicht (oder nur
teilweise) vom Nutzer bestätigt getestet sind — Ergänzung zu
[`status.md`](status.md) (dort steht das ausführliche "was wurde gebaut und
warum", hier nur "was muss noch konkret geprüft werden", ein Punkt pro
Testschritt statt einer pauschalen "noch nicht getestet"-Zeile).

**Konvention:** Neue Punkte hier ergänzen, sobald ein Feature mit mehreren
prüfbaren Teilschritten fertig ist. ✅ nach Nutzer-Bestätigung, ⬜ offen.
Startet ab 2026-08-01 — ältere "noch nicht getestet"-Stellen aus der
Session-Historie stehen weiterhin nur in `status.md`, werden nicht
rückwirkend hierher migriert.

## Außenposten (siehe `building.md`, "Außenposten")

1. ✅ Bauen außerhalb der eigenen Zone — Ghost bleibt grün, Bau klappt,
   Kosten (15 Holz/10 Stein) werden abgezogen. **Vom Nutzer bestätigt.**
2. ⬜ Rückweg: Trupp läuft nach abgeschlossener Suche zum NÄHEREN
   Außenposten statt zur (weiter entfernten) Home-Base.
3. ⬜ Ressourcen-Gutschrift im Home-Base-Panel nach Ablieferung am
   Außenposten (Außenposten hat selbst keinen Speicher, siehe
   `Outpost.add_resources()`).
4. ⬜ Gegenprobe: ein Trupp, der näher an der Home-Base als an jedem
   Außenposten ist, läuft weiterhin ganz normal zur Home-Base.
5. ⬜ (optional, nur mit zweitem Client) Catch-up: ein spät beitretender
   Peer sieht einen schon gebauten Außenposten eines anderen Spielers
   korrekt.

## Vollbild-Kartenansicht (siehe `world.md`, "Kartenansicht")

**Grundmodell vom Nutzer bestätigt (2026-08-01)** — Funktion passt.
Detail-Teilschritte unten bleiben trotzdem stehen (keine explizite
Einzelbestätigung pro Punkt), zusätzlich ein neuer Backlog-Punkt für
später (kein Bug, reine Politur):

1. ⬜ `M` drücken öffnet die Kartenansicht (großes Panel, Gebäude/Home-Bases/
   Trupps/Zombies/Nest sichtbar, Kamera-Marker zeigt aktuelle Position).
2. ⬜ Gebäude mit noch verfügbarem Loot zeigen einen gelben Rahmen,
   geplünderte nicht.
3. ⬜ Klick auf die Karte verschiebt die Kamera dorthin UND schließt die
   Kartenansicht automatisch.
4. ⬜ `M` erneut drücken schließt die Kartenansicht auch ohne Klick.
5. ⬜ **(Backlog, kein Bugfix)** Visuelle Politur — Nutzerwunsch "später
   sollten wir das schöner machen", noch ganz offen was genau (Icons statt
   Farbrahmen? Layout? Beschriftungen?). Erst angehen, wenn der Nutzer
   konkretisiert, was "schöner" heißen soll.

## Rucksack (siehe `survivor.md`, "Rucksack") — Design-Frage entschieden, Item-Mechanik entfernt

**Entscheidung (2026-08-01):** Rucksack ist kein Ausrüstungsstück mehr,
sondern fester Bestand jedes Trupps (`CARRY_CAPACITY := 30`). Die
Slot-Item-Mechanik (Anlegen-Button, `[B]`-Tag, `"backpack"`-Ressource) ist
wieder entfernt — die alten Testpunkte dazu entfallen ersatzlos, nichts
mehr zu prüfen außer:

1. ⬜ Trage-Kapazität zeigt überall (HUD/kompakte Liste/Detailfenster) 30
   an, ohne dass irgendein Anlegen nötig ist — auch bei einem frisch
   rekrutierten Trupp direkt nach dem Spawn.

## Wald-Zonen (siehe `world.md`, "Kartenlayout")

**Vom Nutzer bestätigt (2026-08-01):** "wald passt soweit". Detail-
Teilschritte unten bleiben ohne explizite Einzelbestätigung stehen:

1. ✅ Auf der Karte sind erkennbar dichtere Baum-Cluster zu finden,
   getrennt von den Stadt-Zonen (nicht mit ihnen überlappend).
2. ⬜ Pro Wald-Zone steht ein zusätzliches Gebäude (Jagdstand) mit
   Munition/Waffen-Loot beim Durchsuchen.
3. ✅ Keine sichtbare Überlappung zwischen Wald- und Stadt-Zonen.
4. ⬜ (Nach einem Speichern/Laden-Durchlauf) Wald-Zonen-Bäume/-Gebäude
   bleiben nach dem Laden erhalten, keine doppelten/fehlenden Zonen.

## Herstellen / Crafting (siehe `building.md`, "Herstellen")

**Vom Nutzer bestätigt (2026-08-01, VOR den Forschungsbüchern unten):**
"crafting in der werkstatt hat soweit geklappt". **Wichtig für den
nächsten Test:** seitdem hat sich das Verhalten geändert (siehe
"Forschungsbücher" unten) — Rezepte sind jetzt ERST nach Erforschen
klickbar, nicht mehr sofort. Der vorherige Test lief noch ohne dieses
Gate, könnte beim erneuten Ausprobieren also anders aussehen als erwartet
(Buttons zeigen jetzt "X erforschen" statt direkt "X herstellen").

1. ✅ Mit eigener Werkstatt erscheint das Panel mit Rezept-Buttons,
   funktioniert grundsätzlich (Stand vor dem Forschungsbücher-Gate).
2. ⬜ Ohne eigene Werkstatt ist der "Herstellen"-Tab ausgeblendet (seit dem
   UI-Overhaul, siehe `world.md` — nicht explizit erwähnt).
3. ⬜ Klick ohne ausreichend Ressourcen: Statusmeldung "Nicht genug
   Ressourcen.", nichts wird abgezogen/gutgeschrieben.
4. ⬜ Gecraftete Waffe/Rüstung/Helm lässt sich danach ganz normal
   über das Trupp-Detailfenster ausrüsten (gleicher Ressourcen-Pool wie
   Zombie-Loot).

## Forschungsbücher (siehe `building.md`, "Forschungsbücher")

1. ⬜ Ohne erforschtes Rezept zeigt der Button "X erforschen (Buch: ...)"
   statt des Herstellen-Buttons.
2. ⬜ Mit Buch im Ressourcen-Pool ist der Erforschen-Button klickbar, ohne
   Buch `disabled` (ausgegraut).
3. ⬜ Klick auf Erforschen verbraucht 1× das Buch, Button wechselt danach
   zum normalen Herstellen-Button mit Kosten/Ertrag.
4. ⬜ Herstellen eines NICHT erforschten Rezepts (z. B. per schnellem
   Doppelklick vor dem UI-Refresh) lehnt server-seitig ab
   ("Rezept noch nicht erforscht.").
5. ⬜ Zombie-Tod droppt gelegentlich ein Buch (eigene, seltenere Chance
   als normaler Loot) — Statusmeldung "Zombie-Beute: Buch: ... gefunden!".

## UI-Overhaul, erste Stufe (siehe `world.md`, "UI-Overhaul")

**Erster Schritt, Nutzer wollte danach gezielt Detail-Feedback geben** —
diese Liste ist eher eine Grundfunktions-Checkliste als final abgehakte
Punkte. **Vom Nutzer pauschal bestätigt (2026-08-03):** "ui passt alles
soweit auch mit anzeige tab von ausrüstung etc., truppen ui passt auch" —
Detail-Teilschritte unten auf Basis dieser Aussage mit abgehakt:

1. ✅ Unten links ein Panel mit drei Reitern (Bauen/Herstellen/Einheiten)
   statt der früheren drei Einzel-Panels.
2. ✅ Reiter-Wechsel per Klick funktioniert, Inhalt tauscht korrekt (keine
   Buttons aus dem falschen Tab sichtbar/klickbar).
3. ✅ "Herstellen"-Reiter ist ohne eigene Werkstatt komplett ausgeblendet,
   erscheint sobald eine gebaut ist.
4. ✅ Minimap sitzt jetzt direkt in der unteren rechten Ecke (vorher mit
   Lücke darüber).
5. ✅ Ressourcen-Panel (oben rechts) funktioniert unverändert wie vorher,
   keine Überlappung mit dem Tab-Panel. (Das Trupp-Detailfenster war hier
   ursprünglich ein eigenes Panel links mittig — seit 2026-08-03 selbst ein
   Tab im selben `MainTabsUI`-Panel, siehe eigener Abschnitt "Trupp-
   Detailfenster als fünfter Tab" unten.)

## Ressourcen-Panel kategorisiert (siehe `world.md`, "Ressourcen-Panel kategorisiert")

**Nutzer-Feedback:** "ist besser" — Grundfunktion bestätigt. **Backlog-
Wunsch für später:** lieber zwei Tabs statt eines Dauer-Panels mit vier
Kategorien übereinander (noch nicht spezifiziert, welche zwei Gruppen).
Kein Auftrag für jetzt.

1. ✅ Vier sichtbare Gruppen im Ressourcen-Panel (Baurohstoffe/Überleben/
   Ausrüstung/Forschungsbücher) statt einer einzigen langen Liste — vom
   Nutzer bestätigt ("ist besser").
2. ⬜ Alle 16 Ressourcenarten tauchen in genau einer Gruppe auf (keine
   fehlt, keine doppelt) — inzwischen 16 statt der ursprünglichen 14
   (`melee_weapon`/`leg_armor` seit Punkt 18 der Gesamtliste dazu).
3. ⬜ Panel ist komplett sichtbar, kein Abschneiden am unteren Bildschirmrand
   (Panel wurde deutlich höher).
4. ⬜ **Zwei-Tabs-Umbau umgesetzt (2026-08-03)** — Panel zeigt jetzt zwei
   Tabs ("Rohstoffe"/"Ausrüstung") statt vier Kategorien dauerhaft
   untereinander. Zu prüfen: beide Tabs anklickbar, zeigen korrekte
   Ressourcenwerte (Rohstoffe: Baurohstoffe+Forschungsbücher, Ausrüstung:
   Überleben+Ausrüstung), Uhrzeit/Zombie-Zähler bleiben außerhalb der Tabs
   immer sichtbar, kein Abschneiden am unteren/rechten Panelrand.

## Handel (siehe `trading.md`)

**Vom Nutzer bestätigt (2026-08-01):** "passt tauschen und schenken
funktioniert". **Erneut vom Nutzer bestätigt (2026-08-03):** "handel
funktioniert komplett alles" — pauschale Bestätigung, verbleibende
Detail-Teilschritte (Edge Cases wie Ablehnen/Zurückziehen/Ressourcen-
Mangel beim Annehmen) auf Basis dieser Aussage mit abgehakt, keine
Einzelbestätigung pro Punkt:

1. ✅ Ziel-Spieler-Dropdown im "Handel"-Tab zeigt den jeweils anderen
   verbundenen Spieler (Name + Peer-ID), bleibt bei laufender Auswahl über
   mehrere UI-Refresh-Ticks stabil (kein Zurückspringen alle 0,5s).
2. ✅ Schenken: Ressource + Menge wählen, "Schenken" klicken — Absender
   verliert die Menge sofort, Empfänger bekommt sie sofort gutgeschrieben,
   beide sehen eine Status-Meldung.
3. ✅ Schenken ohne genug eigene Ressourcen: Status "Nicht genug Ressourcen
   zum Verschenken.", nichts wird abgezogen/gutgeschrieben.
4. ✅ Tauschen: Angebot ("Ich gebe"/"Ich will") erstellen und senden —
   erscheint beim Empfänger als eingehendes Angebot mit Annehmen/Ablehnen,
   beim Ersteller als gesendetes Angebot mit Zurückziehen.
5. ✅ Angebot annehmen: beide Seiten tauschen gleichzeitig (Anbieter
   verliert "Ich gebe"-Menge, bekommt "Ich will"-Menge; Empfänger
   umgekehrt), Angebot verschwindet danach bei beiden aus der Liste.
6. ✅ Angebot ablehnen (durch den Empfänger) UND zurückziehen (durch den
   Ersteller) — beide Fälle entfernen das Angebot bei beiden Seiten, ohne
   Ressourcen zu bewegen.
7. ✅ Annehmen, wenn der Anbieter zwischenzeitlich nicht mehr genug hat
   (z. B. inzwischen anderweitig verbraucht): Status-Meldung, kein Tausch,
   Angebot wird entfernt.
8. ✅ Annehmen, wenn der Empfänger selbst nicht genug für die "Ich will"-
   Gegenleistung hat: Status "Nicht genug eigene Ressourcen zum Annehmen.",
   Angebot bleibt bestehen (nicht entfernt, kann später erneut versucht
   werden).

**Neues Feedback (2026-08-03):** Handel-UI-Panel ist "ein bisschen zu
groß" — reine Politur, kein Bug, siehe neuer Abschnitt unten.

## Straßen-Raster + Gebäudereihen (siehe `world.md`, "Straßen-Raster + Gebäudereihen")

**Vom Nutzer bestätigt (2026-08-01):** "passt soweit". **Backlog-Wunsch
für später:** Gebäude stehen "bischen zu weit auseinander" — explizit
nicht jetzt, kann später angepasst werden (kleineres `STREET_BLOCK_SIZE`/
`BUILDING_MIN_SPACING` oder mehr Gebäude pro Zone). Detail-Teilschritte
unten bleiben ohne explizite Einzelbestätigung stehen:

1. ✅ Karte zeigt jetzt 2 sichtbar größere Stadt-Zonen (mehr Gebäude, mehr
   Fläche) und 3 kleinere statt fünf gleich großer.
2. ✅ Gebäude stehen erkennbar in Reihen entlang eines Raster-Musters
   (Blöcke mit Lücken dazwischen), nicht mehr rein zufällig verteilt —
   auch wenn noch keine sichtbare Straßen-Textur/-Farbe existiert.
3. ✅ Keine sichtbar überlappenden Gebäude trotz Reihen-Anordnung.
4. ✅ Start-Basis-Wahl funktioniert weiterhin normal (ein Rekrut-Gebäude
   pro Zone, anklickbar wie vorher).
5. ⬜ (Nach einem Speichern/Laden-Durchlauf) Stadt-Zonen bleiben nach dem
   Laden erhalten, keine doppelten/fehlenden/falsch positionierten
   Gebäude.
6. ✅ Performance unauffällig (keine spürbare FPS-Verschlechterung ggü.
   vorher trotz teils dichterer Reihen in den großen Zonen).
7. ⬜ **(Backlog, für später)** Gebäude-Dichte innerhalb der Reihen erhöhen
   (kleinerer Block/mehr Gebäude pro Zone) — Nutzerwunsch "bischen zu weit
   auseinander", explizit nicht jetzt.

## Fog of War (siehe `world.md`, "Fog of War")

**Vom Nutzer bestätigt (2026-08-01):** "passt mit beiden spielern" —
mit zwei Clients getestet, Grundfunktion inkl. geteiltem Aufdecken
bestätigt. Detail-Teilschritte unten bleiben ohne explizite
Einzelbestätigung stehen:

1. ✅ Minimap UND Kartenansicht (`M`) zeigen zu Beginn (bevor sich ein
   Trupp bewegt hat) fast überall Nebel, nur unmittelbar um die eigene
   Home-Base/den Start-Survivor herum aufgedeckt.
2. ✅ Nebel verschwindet sichtbar, während ein Trupp/Fahrzeug durch neues
   Gebiet läuft/fährt — bleibt danach dauerhaft aufgedeckt (kein erneutes
   Zunebeln, wenn die Einheit weiterzieht).
3. ✅ Geteilt zwischen Spielern: Gebiet, das SPIELER A aufgedeckt hat,
   ist auch für SPIELER B sofort ohne eigenes Hinlaufen sichtbar (auf
   dessen Minimap/Kartenansicht).
4. ✅ Kamera-Marker (eigene Position) bleibt immer sichtbar, auch mitten
   in unerkundetem Gebiet.
5. ✅ Keine spürbare FPS-Verschlechterung durch die zusätzliche Nebel-
   Zeichnung (Minimap läuft jeden Frame neu).

## Straßen-Geometrie (siehe `world.md`, "Straßen-Geometrie")

**Vom Nutzer bestätigt (2026-08-01, nach dem PULL-statt-PUSH-Bugfix):**
"passt geht bei beiden" — ursprünglicher Bug (nur ein Spieler sah
Straßen) behoben, mit beiden Clients erneut getestet. Detail-Teilschritte
unten bleiben ohne explizite Einzelbestätigung stehen:

1. ✅ Sichtbare dunkle Straßen-Streifen zwischen den Gebäude-Reihen in
   jeder Stadt-Zone (nicht mehr nur Lücken zwischen Gebäuden).
2. ✅ Straßen sind bei BEIDEN Clients an derselben Stelle sichtbar (kein
   Versatz zwischen Host und Client).
3. ⬜ (Mit einem später beitretenden dritten Client) Straßen erscheinen
   auch dort korrekt, ohne dass der Client selbst schon dort war.
4. ⬜ Keine sichtbaren Lücken/Versätze an Straßen-Kreuzungen, die störend
   auffallen (kleine Lücken an 4-Wege-Ecken sind bekannt/akzeptiert, siehe
   world.md).
5. ✅ Keine spürbare FPS-Verschlechterung durch die zusätzlichen
   Straßen-Meshes.

## Fahrzeug-Pathing (siehe `world.md`, "Fahrzeug-Pathing")

**Bug + Fix (2026-08-02, Nutzer-Report):** "fährt über das gras anstatt
über die straße" — ursprüngliche Fassung pathete über 36m-Block-Mitten
statt über die tatsächlichen 12m-Straßen-Kacheln, direkte Linie verlief
dadurch zu zwei Dritteln durchs Blockinnere. Fix: Pathing komplett auf
echte Straßen-Kacheln umgestellt (`_zone_street_tiles()`/
`_nearest_street_tile()`/`_bfs_grid_path()`). **Noch nicht erneut vom
Nutzer getestet** — Punkt 1 unten ist jetzt der entscheidende Retest.

1. ✅ Fahrzeug in eine Stadt-Zone befehligen (Ziel ein Gebäude/Punkt
   INNERHALB der Zone) — fährt sichtbar entlang der Straßen-Streifen,
   nicht mehr diagonal quer durch die Blöcke UND nicht mehr übers Gras.
   **Vom Nutzer bestätigt:** "passt fährt genau auf der straße". Zwei
   Nachbesserungen brauchte es dafür (Kachel- statt Block-Pathing, dann
   halber-Kachel-Versatz-Fix), siehe `status.md`/`world.md`.
2. ⬜ Fahrzeug aus einer Stadt-Zone heraus in die Wildnis befehligen —
   bleibt außerhalb der Zone bei der gewohnten Luftlinie (keine Straßen
   dort, kein komisches Verhalten).
3. ⬜ Rechtsklick zum Anhängen eines weiteren Wegpunkts (Warteschlange)
   funktioniert weiterhin normal, auch wenn der neue Abschnitt selbst
   durch eine Stadt-Zone führt.
4. ⬜ Fahrzeug bleibt wie gewohnt vor Mauern/Toren stehen (Kollision
   unverändert) — Pathing ändert nur die Route, nicht die
   Kollisionsprüfung.
5. ⬜ Keine spürbare Verzögerung/Ruckler beim Erteilen eines Fahrbefehls
   in eine große Stadt-Zone (BFS über mehrere hundert Blöcke).

## Straßen-Kacheln: GridMap statt BoxMesh (siehe `world.md`, "Straßen-Geometrie", Kachel-Umbau 2026-08-02)

Löst nebenbei Punkt 4 im "Straßen-Geometrie"-Abschnitt oben (Kreuzungs-
Lücke) — bei Bestätigung dort mit abhaken.

1. ✅ Straßen zeigen echte Kachel-Texturen/-Geometrie statt einfarbiger
   Streifen (Asphalt-Look) — nach Fix von drei Folge-Bugs bestätigt
   (falscher Meshlib-Dateiname, Y-Versatz unter den Boden, vertauschte
   Rotationsrichtung; siehe world.md, "Straßen-Geometrie").
2. ✅ Kreuzungen/T-Stücke/Ecken sehen an der jeweils richtigen Stelle
   passend aus — road_corner/road_t waren nach dem ersten Test 180°
   verdreht (Nutzer-Screenshot), per Vertex-Schwerpunkt-Tool
   (`tools/inspect_road_shapes.gd`) diagnostiziert und in
   `_place_street_tile()` korrigiert. **Vom Nutzer bestätigt: "passt sind
   jetzt richtig".**
3. ⬜ Keine sichtbare Stufe/kein Schweben zwischen Kachel-Oberfläche und
   normalem Boden (Höhen-Ausrichtung `$StreetGridMap.position.y`).
4. ⬜ Grass-Kacheln im Blockinneren sichtbar (falls nicht: kein Bug, rein
   optisch/optional, siehe world.md).
5. ⬜ Beide Clients sehen dieselben Kacheln an denselben Stellen (gleiches
   Bug-Risiko wie beim vorherigen Straßen-Geometrie-Fix).
6. ⬜ Fahrzeug-Pathing (siehe oben) funktioniert weiterhin unverändert —
   `STREET_CELL_SIZE` hat sich von 34m auf 36m verschoben.
7. ⬜ Keine spürbare FPS-Verschlechterung.

## Bedürfnisse: Müdigkeit + Moral, Betten-Mechanik (siehe `survivor.md`, "Bedürfnisse: Müdigkeit + Moral", `building.md`, "Betten")

Komplettiert ein zuvor unfertiges Gerüst (Bett-Gebäude war schon
angelegt, aber nicht verdrahtet, siehe `status.md`) — kompletter
Erst-Test nötig, nicht nur Detail-Nachtest.

1. ⬜ Müdigkeit + Moral fallen sichtbar über Zeit (kompakte Trupp-Liste
   `Mü%d Mo%d`, Trupp-Detailfenster, HUD-Text zeigen alle denselben Wert).
   **Nutzer-Feedback (2026-08-04):** "geht zu schnell runter, ich lauf zu
   einem gebäude und habe beides auf 0" — Verfallsraten daraufhin
   verlangsamt (`FATIGUE_DECAY_RATE` 0.8→0.15/s, `MORALE_DECAY_RATE`
   0.4→0.075/s, siehe `survivor.md`). Erneuter Test mit den neuen, viel
   langsameren Raten (~11/~22 Minuten bis 0 statt vorher ~2/~4 Minuten)
   noch offen.
2. ⬜ "Zu Schlafraum ausbauen"-Button erscheint beim Anklicken eines
   eigenen, geclaimten Gebäudes (Kosten 20 Holz), Ausbauen ersetzt das
   Gebäude durch einen Schlafraum an derselben Stelle.
3. ✅ Trupp in der Nähe (~5m) eines eigenen Schlafraums: Müdigkeit UND
   Moral steigen wieder (`REST_RATE` 10/s), OHNE Ressourcenverbrauch.
   **Vom Nutzer bestätigt (2026-08-03):** "müdigkeit und moral gingen beim
   schlafplatz hoch, passt".
4. ⬜ Trupp OHNE Schlafraum in der Nähe (nur an der Home-Base stehend):
   Müdigkeit/Moral erholen sich NICHT (bewusst kein Home-Base-Grundwert,
   anders als Hunger/Heilung — Gegenprobe zum vorigen Punkt).
5. ✅ Bei niedriger Müdigkeit (≤30): Bewegung sichtbar langsamer
   (`FATIGUE_SPEED_FACTOR` 0.7). **Vom Nutzer bestätigt (2026-08-03):**
   "minus stats bei müdigkeit ... ist auch [passt]".
6. ✅ Bei niedriger Moral (≤30): Angriffsschaden (Angriffsbefehl, Nah- UND
   Fernkampf) sichtbar geringer (Zombie-HP sinkt langsamer pro Treffer,
   `MORALE_DAMAGE_FACTOR` 0.7) — passiver Gegenschaden bei einem
   Zombie-Angriff bleibt davon unberührt. **Vom Nutzer bestätigt
   (2026-08-03):** "minus stats bei ... moral ist auch [passt]".
7. ⬜ Speichern/Laden: Müdigkeit/Moral bleiben nach einem Ladevorgang
   erhalten (nicht auf 100 zurückgesetzt).
8. ⬜ (Mit einem später beitretenden zweiten Client) Catch-up: ein schon
   gebauter Schlafraum eines anderen Spielers ist korrekt sichtbar.

## Differenzierte Gebäudetypen mit echten Loot-Tabellen (siehe `scavenging.md`, "Gebäude-Typen + Loot-Tabellen")

1. ⬜ Mehrere Gebäude in einer Stadt-Zone durchsuchen — Loot-Mengen
   variieren zwischen Durchgängen (RNG-Bereich statt fester Wert), auch
   bei zwei Durchsuchungen desselben Typs.
2. ⬜ Waffenladen/Polizeistation (größere, dunklere Gebäude) liefert beim
   Durchsuchen zuverlässig 1 Waffe, gelegentlich zusätzlich Munition/
   Rüstung/Helm.
3. ⬜ Wohnhaus/Supermarkt liefern nur Nahrung (+ gelegentlich Medizin/
   Buch), Apotheke nur Medizin (+ gelegentlich Buch) — nie Holz/Metall/
   Stein/Ziegel aus Stadt-Gebäude-Loot.
4. ⬜ Rekrutierung (Gebäude mit Survivor) funktioniert weiterhin normal,
   unabhängig vom gewürfelten Gebäudetyp.
5. ⬜ Speichern/Laden: das schon ausgewürfelte Loot eines Gebäudes bleibt
   nach dem Laden exakt erhalten (kein Neu-Würfeln).

## Zehn weitere Gebäudetypen (siehe `scavenging.md`, 2026-08-03)

1. ⬜ Beim Durchsuchen mehrerer Gebäude in einer Stadt-Zone tauchen jetzt
   sichtbar mehr unterschiedliche Fassadenfarben/-Größen auf als vorher
   (14 statt 4 Typen).
2. ⬜ Bibliothek/Universität liefern zuverlässig mindestens 1 Buch beim
   Durchsuchen (garantierter Hauptloot, nicht nur Nebenloot-Chance).
3. ⬜ Klinik liefert deutlich mehr Medizin als eine normale Apotheke.
4. ⬜ Militärbasis/Privatbunker liefern zuverlässig 1 Waffe + spürbar
   häufiger zusätzlich Munition/Rüstung als der normale Waffenladen.
5. ⬜ Garten-Center liefert eine Nahkampfwaffe, Camping-Laden Beinschutz —
   beide als garantierten Hauptloot.
6. ⬜ Feuerwehrstation liefert Rüstung als Hauptloot.
7. ⬜ Weiterhin NIE Holz/Metall/Stein/Ziegel aus irgendeinem der neuen
   Gebäudetypen (Gegenprobe zur bestehenden Regel).
8. ⬜ Rekrutierung (Gebäude mit Survivor) funktioniert bei allen neuen
   Typen genauso wie bei den ursprünglichen vier.

## Haupt-/Sekundärwaffe + Beinschutz (siehe `survivor.md`, "Haupt-/Sekundärwaffe", "Dritter Rüstungs-Slot: Beinschutz")

1. ⬜ Trupp-Detailfenster zeigt jetzt fünf Ausrüstungs-Zeilen (Hauptwaffe/
   Brustpanzer/Helm/Sekundärwaffe/Beinschutz), Panel komplett sichtbar
   (kein Abschneiden am unteren Rand, Panel wurde vergrößert).
2. ⬜ "Nahkampfwaffe ausrüsten" verbraucht 1× `melee_weapon`, danach
   kompakte Liste zeigt `[S]`-Tag.
3. ⬜ "Beinschutz anziehen" verbraucht 1× `leg_armor`, danach kompakte
   Liste zeigt `[B]`-Tag.
4. ⬜ Trupp OHNE Hauptwaffe/Munition, aber MIT Sekundärwaffe: Angriffs-
   befehl nutzt sichtbar den verbesserten Nahkampf (schnellere Treffer als
   ohne Sekundärwaffe, Zombie-HP sinkt schneller).
5. ⬜ Trupp MIT Hauptwaffe UND Munition bevorzugt weiterhin Fernkampf,
   auch wenn zusätzlich eine Sekundärwaffe ausgerüstet ist.
6. ⬜ Beinschutz reduziert Schaden zusätzlich zu Brustpanzer/Helm (mit
   allen dreien spürbar weniger HP-Verlust pro Zombie-Treffer als mit nur
   zweien).
7. ⬜ Sekundärwaffe/Beinschutz können nach dem Tod des Trupps normal neu
   ausgerüstet werden (kein Vererben an einen neuen Rekruten).
8. ⬜ Speichern/Laden: `secondary_weapon`/`has_leg_armor` bleiben nach dem
   Laden erhalten.
9. ⬜ Zombie-Tod droppt gelegentlich `melee_weapon`/`leg_armor`
   (Statusmeldung "Zombie-Beute: +1 Nahkampfwaffen"/"+1 Beinschutz").

## Differenzierte Fahrzeugtypen (siehe `vehicle.md`, "Differenzierte Fahrzeugtypen")

1. ⬜ In den Stadt-Zonen stehen sichtbar unterschiedlich aussehende
   Fahrzeuge (drei erkennbar verschiedene Farben/Größen: Auto/Motorrad/LKW).
2. ⬜ Einsteigen zeigt eine Statusmeldung mit dem konkreten Typnamen ("Auto
   bestiegen."/"Motorrad bestiegen."/"LKW bestiegen.").
3. ⬜ Motorrad fährt sichtbar schneller als das bisherige Auto, LKW sichtbar
   langsamer.
4. ⬜ LKW hält sichtbar mehr Zombie-Treffer aus als das Auto, Motorrad
   sichtbar weniger (schneller zerstört).
5. ⬜ Kein Fahrzeug steht sichtbar im Boden versenkt oder schwebt darüber
   (typspezifische Boden-Höhe).
6. ⬜ Speichern/Laden: Fahrzeugtyp bleibt nach dem Laden erhalten (Auto
   bleibt Auto, nicht wieder zufällig neu gewürfelt).
7. ⬜ (Mit einem später beitretenden zweiten Client) Catch-up zeigt den
   korrekten Fahrzeugtyp, nicht immer "Auto".

## Gegenseitige Verteidigung/Hilfe (siehe `world.md`, "Gegenseitige Verteidigung/Hilfe")

**Braucht zwei Clients zum Testen** — Spieler A wird angegriffen, Spieler B
soll den Alarm sehen.

1. ✅ Spieler A lässt sich von einem Zombie angreifen (z. B. Trupp
   ungeschützt stehen lassen) — Spieler B bekommt eine Statusmeldung
   ("... wird angegriffen! Hilfe gebraucht."), Spieler A selbst NICHT.
   **Vom Nutzer bestätigt (2026-08-03):** "signal wenn koop partner
   angegriffen wird geht auch".
2. ⬜ Bei Spieler B erscheint ein pulsierender roter Ring auf der Minimap
   UND in der Kartenansicht (`M`) an der ungefähren Angriffsposition.
3. ⬜ Der Ring bleibt ~20s sichtbar und verschwindet danach von selbst,
   auch wenn der Angriff weiterläuft (kein Dauer-Alarm).
4. ⬜ Wiederholte Treffer auf denselben Spieler innerhalb von 30s lösen
   KEINEN zweiten Alarm/keine zweite Statusmeldung aus (Cooldown).
5. ⬜ Nach Ablauf des Cooldowns löst ein neuer Angriff erneut einen Alarm
   aus.
6. ⬜ Der Ring ist auch in noch nicht selbst erkundetem (vernebeltem)
   Gebiet sichtbar, nicht vom Fog of War verdeckt.
7. ⬜ Spieler B kann tatsächlich mit einem eigenen Feldtrupp zur
   Alarm-Position laufen und dort mitkämpfen (Gegenprobe, dass die
   zugrunde liegende Mechanik — kein Zonen-/Besitzer-Filter — wirklich
   funktioniert).

## Blutmond-Kalender-Eskalation (siehe `zombies.md`, "Blutmond-Kalender-Eskalation")

**Dauert mindestens 25 Minuten Echtzeit bis zur ersten Blutmond-Nacht** —
für einen schnelleren Test `BLOOD_MOON_INTERVAL_DAYS` in `World.gd`
temporär auf 1 senken, nach dem Test wieder zurückstellen.

1. ⬜ An einer normalen (Nicht-Blutmond-)Nacht bleibt alles wie vorher:
   Standard-Warnung, 10 Zombies, normaler dunkelblauer Nachthimmel.
2. ⬜ An der 5. Nacht erscheint die Blutmond-Warnung ("BLUTMOND! Eine
   gewaltige Horde formiert sich!") statt der normalen Horde-Nacht-Meldung.
3. ⬜ Deutlich mehr Zombies als an einer normalen Nacht (spürbar dichtere
   Welle, ~30 statt ~10), auffällig mehr Brutes darunter.
4. ⬜ Der Nachthimmel/das Umgebungslicht ist an der Blutmond-Nacht sichtbar
   rötlich getönt statt der gewohnten dunkelblauen Nachtfarbe, blendet
   genauso weich ein/aus wie der normale Tag/Nacht-Übergang (kein harter
   Farbsprung).
5. ⬜ Nach der Blutmond-Nacht (nächste normale Nacht) ist der Himmel wieder
   normal dunkelblau, Hordengröße wieder normal.
6. ⬜ Beide Clients sehen dieselbe Blutmond-Nacht zur selben Spielzeit
   (kein Versatz zwischen Host und Client).
7. ⬜ Speichern/Laden: die Kalenderzählung (`day_count`) bleibt nach dem
   Laden erhalten, kein Zurückspringen auf "Nacht 1".

## Mehr Gebäude, weniger Startressourcen, 5 Start-Trupps, Ressourcen-Panel-Tabs (2026-08-03, Sammel-Feedback)

1. ⬜ Stadt-Zonen wirken sichtbar dichter bebaut als vorher (100/50 statt
   60/30 Gebäude pro großer/kleiner Zone) — keine sichtbaren Lücken/
   Overlaps, Straßen-Raster bleibt korrekt (Gebäude weiterhin nicht auf
   der Straße selbst).
2. ⬜ Keine spürbare FPS-Verschlechterung durch die zusätzlichen Gebäude.
3. ⬜ Nach der Start-Basis-Wahl stehen 5 eigene Trupps nebeneinander in
   einer Reihe neben dem gewählten Gebäude, keiner davon im Gebäude-Mesh
   versunken/unsichtbar (gleiche Bug-Klasse wie der frühere
   "zweiter Trupp fehlt"-Bug, siehe `zones.md`).
4. ⬜ Start-Ressourcen sind spürbar knapper als vorher (Holz 20/Metall 10/
   Stein 20/Ziegel 10/Nahrung 30/Medizin 15/Munition 20, Waffe/Rüstung/
   Helm/Nahkampfwaffe/Beinschutz je 1) — kein Startbestand an
   Forschungsbüchern mehr.
5. ⬜ Lagerkapazität liegt jetzt bei 150 statt 300 — Ressourcen-Panel zeigt
   das korrekt an (Wert/150), Ressourcen-Zugewinn wird bei 150 gedeckelt.

## Trupp-Detailfenster als fünfter Tab (siehe `world.md`, "Fünfter Tab: Trupp-Detailfenster")

**Vom Nutzer pauschal bestätigt (2026-08-03):** "ui passt alles soweit auch
mit anzeige tab von ausrüstung etc." — Detail-Teilschritte unten auf Basis
dieser Aussage mit abgehakt:

1. ✅ Kein separates, frei schwebendes Trupp-Panel mehr sichtbar — bei
   Trupp-Auswahl erscheint stattdessen ein fünfter Tab "Trupp" im
   MainTabsUI-Panel (neben Bauen/Herstellen/Einheiten/Handel).
2. ✅ Der "Trupp"-Tab ist NUR anwählbar, wenn genau ein eigener Survivor
   ausgewählt ist — bei keiner/mehrfacher Auswahl oder einem ausgewählten
   Fahrzeug verschwindet er wieder aus der Tab-Leiste.
3. ✅ Zeigt weiterhin alle fünf Ausrüstungszeilen (Hauptwaffe/Brustpanzer/
   Helm/Sekundärwaffe/Beinschutz) mit funktionierenden Ausrüsten-Buttons.
4. ✅ Kein automatischer Tab-Wechsel beim Auswählen eines Trupps — man
   muss selbst auf "Trupp" klicken, genau wie bei den anderen Tabs.
5. ✅ Keine Überlappung mehr mit irgendeinem anderen Panel, auch bei
   kleineren Fenstergrößen/Auflösungen (der ursprüngliche Bug-Auslöser).

## Nachjoinen-Fix (siehe `status.md`, 2026-08-03, "Nachjoinen + Laden im Multiplayer gefixt")

**Braucht zwei Clients zum Testen**, idealerweise beide Szenarien.
**Vom Nutzer bestätigt (2026-08-03):** "nachjoinen geht auch", "speicher
laden und dann rejoinen geht auch", "zweiter spieler kann units wechsel
das geht" — alle vier Punkte abgehakt.

1. ✅ Spieler B verbindet sich, WÄHREND Spieler A (Host) noch in der Lobby
   wartet (normaler Fall) — Spieler B landet wie bisher in der Lobby, sieht
   Spieler A in der Liste, Host kann normal starten.
2. ✅ Spieler B verbindet sich, NACHDEM Spieler A (Host) schon "Spiel
   starten" gedrückt hat (echtes Nachjoinen) — Spieler B landet direkt in
   `World.tscn`, sieht die schon existierende Welt (Zonen/Straßen/Gebäude/
   Zombies/ggf. schon existierende Trupps von Spieler A) statt einer leeren
   Karte, kann danach normal seine Start-Basis wählen.
3. ✅ Gleiches wie Punkt 2, aber Spieler A ist über "Laden" (nicht "Spiel
   starten") in `World.tscn` gekommen — Spieler B sieht den geladenen
   Spielstand korrekt (nicht nur eine frische Welt).
4. ✅ Spieler 2 kann nach dem Nachjoinen ganz normal Einheiten auswählen/
   wechseln (Retest des ursprünglich gemeldeten "konnte keine Units
   umwechseln" — Verdacht war, dass es am Nachjoin-Bug lag, kein eigener
   Fund im Code).

## Gruppen-Angriff verteilt sich (siehe `status.md`, 2026-08-03)

1. ⬜ Mehrere Einheiten auswählen, auf einen Zombie klicken, während
   mehrere Zombies in ca. 10m Umkreis stehen — die Einheiten greifen jetzt
   MEHRERE verschiedene Zombies an (den jeweils nächsten pro Einheit)
   statt sich alle auf denselben zu stürzen.
2. ⬜ Gegenprobe: nur EIN Zombie weit und breit — Verhalten bleibt wie
   vorher (alle ausgewählten Einheiten greifen ihn gemeinsam an).
3. ⬜ Klick auf ein Zombie-Nest mit mehreren Einheiten funktioniert
   weiterhin normal (Nest zählt als möglicher Verteil-Kandidat mit).

## Maus-Invertieren-Einstellung (siehe `status.md`, 2026-08-03)

1. ⬜ Neue Checkbox "Maus invertieren (Kamera-Neigung)" im
   Einstellungen-Overlay (Hauptmenü UND Pause-Menü), Zustand bleibt nach
   Neustart erhalten.
2. ⬜ Bei aktivierter Checkbox kehrt sich NUR die vertikale Kamera-Neigung
   (Rechtsklick-Ziehen hoch/runter) um — die horizontale Rotation bleibt
   unverändert.

## Handel-UI verkleinert (siehe `status.md`, 2026-08-03)

1. ⬜ Handel-Tab wirkt spürbar kompakter/weniger überladen als vorher,
   alle Dropdowns (Schenken/Ich gebe/Ich will) bleiben trotzdem gut
   lesbar und bedienbar (keine abgeschnittenen Ressourcennamen).

## Bauen ohne Zonen-Restriktion (siehe `status.md`/`zones.md`/`building.md`, 2026-08-03)

**Nutzerwunsch, komplett entfernt statt nur vergrößert (siehe Rückfrage
im Chat).** **Vom Nutzer bestätigt (2026-08-03):** "bau begrenzung ist
auch weg passt auch".

1. ✅ Ghost-Preview beim Bauen (Wachposten/Mauer/Tor/Feld) ist grün, egal
   wie weit weg von der eigenen Home-Base/einem geclaimten Gebäude man
   klickt — auch am gegenüberliegenden Kartenrand.
2. ✅ Tatsächlicher Bauversuch weit weg von der eigenen Zone gelingt
   (Ressourcen werden abgezogen, Gebäude entsteht), kein "Zu weit von der
   eigenen Zone entfernt."-Fehler mehr möglich.
3. ⬜ Fehlermeldung bei zu wenig Ressourcen ("Nicht genug Ressourcen.")
   erscheint weiterhin korrekt, unabhängig von der Bauposition.
4. ⬜ Claimen von Gebäuden (unverändert, hatte nie eine Abstandsprüfung)
   funktioniert weiterhin normal — keine Regression durch den Umbau.
5. ⬜ Ausbauen (Krankenstation/Werkstatt/Lager/Bett auf einem eigenen
   geclaimten Gebäude) funktioniert weiterhin normal (nutzt `_can_build_at()`
   nicht, sollte also ohnehin unberührt sein — Gegenprobe).

## Fahrzeug-Mitfahrer (siehe `status.md`/`vehicle.md`, 2026-08-03)

**Vom Nutzer bestätigt (2026-08-03):** "zwei truppen konnten einsteigen
und aussteigen".

1. ✅ Mehrere eigene Trupps auswählen (bis zur Sitzkapazität, z. B. 3 beim
   Auto), auf ein unbesetztes Fahrzeug klicken — ALLE steigen ein (nicht
   nur einer), Statusmeldung pro Trupp ("Auto bestiegen." mehrfach).
   Getestet mit zwei Trupps, volle Kapazität (3+) noch nicht ausprobiert.
2. ⬜ Mehr Trupps ausgewählt als Sitze frei sind — die ersten (bis zur
   Kapazität) steigen ein, der Rest bleibt sichtbar draußen stehen (kein
   Fehler/Crash).
3. ⬜ Motorrad: weiterhin nur 1 Sitz (kein Mitfahrer möglich), Auto 3,
   LKW 5 Sitze gesamt (inkl. Fahrer).
4. ✅ F-Taste (nur vom Fahrer/bei ausgewähltem Fahrzeug ausgelöst) lässt
   die GESAMTE Besatzung gleichzeitig aussteigen, alle sichtbar und
   einzeln wieder auswählbar, keiner davon im Fahrzeug-Mesh
   versunken/überlappend mit einem anderen.
5. ⬜ Fahrzeug wird von Zombies zerstört, während mehrere Trupps drinsitzen
   — Fahrer UND alle Mitfahrer sterben (Permadeath), nicht nur der Fahrer.
6. ⬜ Nur der Fahrer kann das Fahrzeug bewegen/stoppen — ein Mitfahrer hat
   keine Steuerungsmöglichkeit (kein eigener Test-Button dafür nötig,
   ergibt sich daraus, dass Mitfahrer nicht separat auswählbar sind).

## Trupp-Art umschalten für Nicht-Host-Spieler (siehe `status.md`, 2026-08-03)

**Braucht zwei Clients zum Testen** (Bug betraf nur Nicht-Host-Peers, beim
Host selbst sah es schon immer korrekt aus). **Vom Nutzer bestätigt
(2026-08-03):** "zweiter spieler kann units wechsel das geht".

1. ✅ Als NICHT-Host-Spieler (Client, nicht der Host) einen eigenen Trupp
   in der Einheiten-Liste auf "→Bau" klicken — Text wechselt sichtbar auf
   "Bau", Button-Beschriftung auf "→Feld", Einheiten-Farbe ändert sich
   (siehe "Sättigung/Helligkeit"-Zweitsignal, `Survivor._unit_base_color()`).
2. ✅ Zurück auf "→Feld" klicken — wechselt genauso sichtbar zurück.
3. ⬜ Umgeschalteter Bautrupp kann tatsächlich abbauen (Baum/Auto/Stein/
   Ziegel), nicht mehr suchen/claimen/angreifen (Gegenprobe, dass die
   serverseitige Fähigkeit schon vorher funktionierte, jetzt aber auch die
   UI korrekt mitzieht).
4. ⬜ Host selbst weiterhin unverändert funktionsfähig (keine Regression
   durch den Fix).

## Banditen-Restloot (siehe `scavenging.md`, 2026-08-03, Punkt 23 der Gesamtliste)

**Erst-Test dauert mindestens 3 Minuten Echtzeit** (`BANDIT_RESTOCK_INTERVAL`)
und braucht mindestens ein schon geplündertes, unbesetztes Gebäude zu
diesem Zeitpunkt.

1. ⬜ Nach genügend Wartezeit färbt sich ein bereits geplündertes,
   unbesetztes Gebäude golden (gleicher Ton wie ein markierter Baum).
2. ⬜ Klick mit einem Feldtrupp auf dieses golden gefärbte Gebäude löst
   erneut `order_search()` aus (Trupp läuft hin, sucht kurz) statt sofort
   zu claimen.
3. ⬜ Nach der Suche: kleine Menge (3-8) einer Ressource (Nahrung/Medizin/
   Munition) gutgeschrieben, Gebäude fällt zurück auf normales Grau —
   danach wieder normal claim-/abreißbar wie jedes andere geplünderte
   Gebäude.
4. ⬜ Vollmap-Ansicht (`M`) zeigt für ein golden gefärbtes Gebäude
   ebenfalls den gelben "Loot verfügbar"-Rahmen.
5. ⬜ Ein BEREITS geclaimtes Gebäude (`owner_peer_id != 0`) bekommt nie
   Banditen-Restloot (Gegenprobe — nur unbesetzte, geplünderte Gebäude
   sind Kandidaten).
6. ⬜ (Nach einem Speichern/Laden-Durchlauf) ein gerade aktiver
   Banditen-Restock bleibt nach dem Laden erhalten (golden, einsammelbar),
   kein stiller Reset auf normales Grau.

## Erweiterte Krankenstation (siehe `building.md`, 2026-08-03, Punkt 24 der Gesamtliste)

1. ⬜ Mit eigener, normaler Krankenstation erscheint im "Bauen"-Tab ein
   neuer Button "Erweiterte Krankenstation erforschen (Buch: Medizinische
   Praxis)" — disabled ohne das Buch im Ressourcen-Pool.
2. ⬜ Mit Buch im Pool ist der Button klickbar, Klick verbraucht 1× das
   Buch, Button wechselt danach zu "Krankenstation erweitern (15 Ziegel,
   3 Medizin)".
3. ⬜ Klick auf "erweitern" mit genug Ressourcen: Kosten werden abgezogen,
   Button verschwindet danach (keine eigene unerweiterte Krankenstation
   mehr übrig).
4. ⬜ Trupp in der Nähe der jetzt erweiterten Krankenstation heilt sichtbar
   schneller als vorher (HP steigt schneller pro Sekunde) — Gegenprobe:
   eine normale (nicht erweiterte) Krankenstation heilt weiterhin mit der
   alten Rate.
5. ⬜ Ohne genug Ressourcen beim Erweitern: Status "Nicht genug
   Ressourcen.", nichts abgezogen, Button bleibt in "erweitern"-Zustand.
6. ⬜ Das neue Buch "Medizinische Praxis" droppt gelegentlich bei
   Zombie-Tod UND als Sekundärloot in Stadt-Gebäuden (wie die anderen vier
   Bücher), zeigt sich korrekt im Ressourcen-Panel unter "Forschungsbücher".
7. ⬜ (Nach einem Speichern/Laden-Durchlauf) eine bereits erweiterte
   Krankenstation bleibt nach dem Laden erweitert (schnellere Heilung
   weiterhin aktiv) — bekannte Ausnahme: der Forschungs-Status selbst
   ("medical_upgrade" erforscht?) bleibt NICHT erhalten (bestehende Lücke,
   betrifft auch die vier ursprünglichen Rezepte gleichermaßen).

## Echter Wachturm (siehe `building.md`, 2026-08-03, Punkt 25 der Gesamtliste)

1. ⬜ Neuer Button "Wachturm bauen (30 Holz, 20 Metall)" im "Bauen"-Tab,
   Ghost-Preview beim Platzieren zeigt eine erkennbar hohe, schlanke Säule
   (nicht die 1,5³-Box der anderen Einzelklick-Typen), steht komplett auf
   dem Boden statt darin zu versinken.
2. ⬜ Nach dem Bauen steht der Wachturm sichtbar korrekt auf dem Boden
   (kein Versinken/Schweben), Kosten wurden abgezogen.
3. ⬜ Nach kurzer Zeit (nächster Fog-of-War-Takt, `FOG_UPDATE_INTERVAL`
   1s) ist auf Minimap UND Kartenansicht (`M`) ein deutlich größerer
   Bereich um den Wachturm dauerhaft aufgedeckt als um eine einzelne
   Einheit — spürbar mehr als der bisherige Aufdeck-Radius.
4. ⬜ Zombies, die vorher im Nebel unsichtbar wirkten (weil kein Terrain-
   Kontext erkennbar war), sind jetzt im neu aufgedeckten Bereich um den
   Turm klar im Kontext (Straßen/Gebäude) sichtbar — waren als reine
   Punkte technisch auch vorher schon da, wirken jetzt aber nutzbar.
5. ⬜ Wachturm hat keinerlei Kampf-/Worker-Funktion (kein "Arbeiter
   schicken"-Button wie beim Wachposten, greift keine Zombies an, wird
   von Zombies nicht als Ziel behandelt wie ein geclaimtes Gebäude).
6. ⬜ (Mit einem später beitretenden zweiten Client) Catch-up zeigt einen
   schon gebauten Wachturm eines anderen Spielers korrekt.
7. ⬜ (Nach einem Speichern/Laden-Durchlauf) ein gebauter Wachturm bleibt
   erhalten, liefert nach dem Laden weiterhin seinen Sichtbonus.

## Welt-Sync-Sperre (siehe `networking.md`, 2026-08-04 — Bugfix nach Nutzer-Testbericht)

**Update:** erste Testrunde deckte einen zweiten, schwereren Bug auf
(Verbindungsabbruch durch >4000 einzelne Catch-up-RPCs) — behoben durch
Bündel-RPCs + zurückgenommene Stresstest-Zahlen (350 Gebäude statt 1750),
siehe `networking.md`.

**Vom Nutzer bestätigt (2026-08-04):** "passt alles" — erneuter
Zwei-Spieler-Test nach beiden Fixes.

1. ✅ Zwei-Spieler-Test (Debug → Customize Run Instances → 2 → F5, Host
   startet die Partie): der NICHT-Host-Client sieht kurz nach dem
   Betreten von `World.tscn` einen Vollbild-Blocker ("Welt wird
   synchronisiert ...", Fortschrittsbalken) statt sofort in einer noch
   halb-leeren Welt zu landen.
2. ✅ Klicks auf die Welt (insbesondere auf ein Stadt-Gebäude zur
   Startbase-Wahl) haben während der Blocker sichtbar ist KEINE Wirkung.
3. ✅ Der Blocker verschwindet von selbst, sobald die Welt beim Client
   tatsächlich vollständig angekommen ist (Minimap zeigt danach direkt
   alle Gebäude, nicht nur einen Teil) — Klick auf ein Gebäude wählt
   danach korrekt die Startbase (das eigentlich gemeldete Problem).
4. ✅ Host selbst sieht den Blocker NIE (hat alles sofort lokal).
5. ⬜ (Mit einem dritten, später beitretenden Client) Blocker erscheint
   auch beim Spätbeitritt und verschwindet nach Catch-up korrekt —
   gleicher PULL-Mechanismus wie beim regulären Partie-Start.
