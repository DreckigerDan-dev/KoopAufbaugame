# Offene Tests

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
Punkte.

1. ⬜ Unten links ein Panel mit drei Reitern (Bauen/Herstellen/Einheiten)
   statt der früheren drei Einzel-Panels.
2. ⬜ Reiter-Wechsel per Klick funktioniert, Inhalt tauscht korrekt (keine
   Buttons aus dem falschen Tab sichtbar/klickbar).
3. ⬜ "Herstellen"-Reiter ist ohne eigene Werkstatt komplett ausgeblendet,
   erscheint sobald eine gebaut ist.
4. ⬜ Minimap sitzt jetzt direkt in der unteren rechten Ecke (vorher mit
   Lücke darüber).
5. ⬜ Ressourcen-Panel (oben rechts) funktioniert unverändert wie vorher,
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
funktioniert". Detail-Teilschritte unten bleiben ohne explizite
Einzelbestätigung stehen:

1. ✅ Ziel-Spieler-Dropdown im "Handel"-Tab zeigt den jeweils anderen
   verbundenen Spieler (Name + Peer-ID), bleibt bei laufender Auswahl über
   mehrere UI-Refresh-Ticks stabil (kein Zurückspringen alle 0,5s).
2. ✅ Schenken: Ressource + Menge wählen, "Schenken" klicken — Absender
   verliert die Menge sofort, Empfänger bekommt sie sofort gutgeschrieben,
   beide sehen eine Status-Meldung.
3. ⬜ Schenken ohne genug eigene Ressourcen: Status "Nicht genug Ressourcen
   zum Verschenken.", nichts wird abgezogen/gutgeschrieben.
4. ✅ Tauschen: Angebot ("Ich gebe"/"Ich will") erstellen und senden —
   erscheint beim Empfänger als eingehendes Angebot mit Annehmen/Ablehnen,
   beim Ersteller als gesendetes Angebot mit Zurückziehen.
5. ✅ Angebot annehmen: beide Seiten tauschen gleichzeitig (Anbieter
   verliert "Ich gebe"-Menge, bekommt "Ich will"-Menge; Empfänger
   umgekehrt), Angebot verschwindet danach bei beiden aus der Liste.
6. ⬜ Angebot ablehnen (durch den Empfänger) UND zurückziehen (durch den
   Ersteller) — beide Fälle entfernen das Angebot bei beiden Seiten, ohne
   Ressourcen zu bewegen.
7. ⬜ Annehmen, wenn der Anbieter zwischenzeitlich nicht mehr genug hat
   (z. B. inzwischen anderweitig verbraucht): Status-Meldung, kein Tausch,
   Angebot wird entfernt.
8. ⬜ Annehmen, wenn der Empfänger selbst nicht genug für die "Ich will"-
   Gegenleistung hat: Status "Nicht genug eigene Ressourcen zum Annehmen.",
   Angebot bleibt bestehen (nicht entfernt, kann später erneut versucht
   werden).

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
2. ⬜ "Zu Schlafraum ausbauen"-Button erscheint beim Anklicken eines
   eigenen, geclaimten Gebäudes (Kosten 20 Holz), Ausbauen ersetzt das
   Gebäude durch einen Schlafraum an derselben Stelle.
3. ⬜ Trupp in der Nähe (~5m) eines eigenen Schlafraums: Müdigkeit UND
   Moral steigen wieder (`REST_RATE` 10/s), OHNE Ressourcenverbrauch.
4. ⬜ Trupp OHNE Schlafraum in der Nähe (nur an der Home-Base stehend):
   Müdigkeit/Moral erholen sich NICHT (bewusst kein Home-Base-Grundwert,
   anders als Hunger/Heilung — Gegenprobe zum vorigen Punkt).
5. ⬜ Bei niedriger Müdigkeit (≤30): Bewegung sichtbar langsamer
   (`FATIGUE_SPEED_FACTOR` 0.7).
6. ⬜ Bei niedriger Moral (≤30): Angriffsschaden (Angriffsbefehl, Nah- UND
   Fernkampf) sichtbar geringer (Zombie-HP sinkt langsamer pro Treffer,
   `MORALE_DAMAGE_FACTOR` 0.7) — passiver Gegenschaden bei einem
   Zombie-Angriff bleibt davon unberührt.
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

1. ⬜ Spieler A lässt sich von einem Zombie angreifen (z. B. Trupp
   ungeschützt stehen lassen) — Spieler B bekommt eine Statusmeldung
   ("... wird angegriffen! Hilfe gebraucht."), Spieler A selbst NICHT.
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

1. ⬜ Kein separates, frei schwebendes Trupp-Panel mehr sichtbar — bei
   Trupp-Auswahl erscheint stattdessen ein fünfter Tab "Trupp" im
   MainTabsUI-Panel (neben Bauen/Herstellen/Einheiten/Handel).
2. ⬜ Der "Trupp"-Tab ist NUR anwählbar, wenn genau ein eigener Survivor
   ausgewählt ist — bei keiner/mehrfacher Auswahl oder einem ausgewählten
   Fahrzeug verschwindet er wieder aus der Tab-Leiste.
3. ⬜ Zeigt weiterhin alle fünf Ausrüstungszeilen (Hauptwaffe/Brustpanzer/
   Helm/Sekundärwaffe/Beinschutz) mit funktionierenden Ausrüsten-Buttons.
4. ⬜ Kein automatischer Tab-Wechsel beim Auswählen eines Trupps — man
   muss selbst auf "Trupp" klicken, genau wie bei den anderen Tabs.
5. ⬜ Keine Überlappung mehr mit irgendeinem anderen Panel, auch bei
   kleineren Fenstergrößen/Auflösungen (der ursprüngliche Bug-Auslöser).
