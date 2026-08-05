## Überleben/Ausrüstung/Bücher in die linke Tab-Spalte verschoben (2026-08-05)

Nutzerwunsch nach dem Verschieben nach oben: Panel soll schmäler werden,
und "Überleben"/"Ausrüstung" (Nutzer nannte diese zwei, das dritte
eingebettete Unter-Tab "Bücher" gehört zur selben Gruppe und wurde aus
Konsistenzgründen gleich mit verschoben — bitte melden falls das nicht so
gewollt war) sollen als eigene Tabs in die linke Spalte wandern statt als
Unter-Reiter im Ressourcen-Panel zu leben. Umbau:

- **`ResourcesUI/Panel`**: schmäler (304px → 220px) und deutlich kürzer
  (248px → 130px) — zeigt jetzt nur noch `Baurohstoffe` (dauerhaft) +
  `Zombies: X/Y`, keine eingebetteten Tabs mehr.
- **`ResourcesUI/Panel/VBoxContainer`**: von absoluten `layout_mode = 0`-
  Offsets (`offset_top = 185`, stammte erkennbar aus einer viel älteren,
  größeren Panel-Fassung und war seit mehreren Runden nie nachgezogen
  worden) auf selbst-anpassendes `layout_mode = 1` mit `anchors_preset =
  15` (Full-Rect-Füllung) umgestellt — behebt die Ursache dieser Art von
  Veraltung strukturell, statt nur den aktuellen Zahlenwert zu korrigieren.
- **Drei neue Buttons** in `TabColumnUI/Panel/TabButtonList`:
  `SurvivalTabButton`/`GearTabButton`/`BooksTabButton` ("Überleben"/
  "Ausrüstung"/"Bücher"), gleiches Muster wie die neun bestehenden.
- **Drei neue Tabs** in `MainTabsUI/Panel/TabContainer` (`_tab_index` 9-11),
  je ein `VBoxContainer` mit dem jeweils dorthin verschobenen Label
  (`SurvivalResourcesLabel`/`GearResourcesLabel`/`BooksResourcesLabel`,
  vorher unter `ResourcesUI/Panel/VBoxContainer/TabContainer/...`).
- **`World.gd`**: neue `@onready`-Refs für alle sechs neuen Nodes, `_tab_
  buttons`/`_tab_controls`-Arrays (siehe `_on_tab_button_pressed()`) um die
  drei neuen Paare erweitert, `resource_category_labels`-Array-Pfade auf
  die neue `MainTabsUI`-Position aktualisiert. Die Text-Befüllungslogik
  selbst (`RESOURCE_CATEGORIES`-Schleife) war schon index-generisch,
  brauchte keine Änderung.

**Noch nicht getestet.**

## Ressourcen-Panel nach oben verschoben, Minimap-Überlappung (2026-08-05)

Nutzer-Screenshot (`bilder/rechts eck.PNG`): Ressourcen-Panel oben rechts
(`Baurohstoffe`/`Überleben`/`Ausrüstung`-Tabs/`Zombies`-Zeile) reichte zu
weit nach unten, überlappte mit der Minimap (unten rechts). Nutzerwunsch:
Panel soll stattdessen ganz oben sitzen, auf gleicher Höhe wie die
Zeit-/Pause-Leiste (`TopBarUI`, y=8–48). `ResourcesUI/Panel`s `offset_top`/
`offset_bottom` von `141`/`389` auf `8`/`256` gesetzt (Höhe unverändert
248px, nur nach oben verschoben) — praktisch wieder der Stand von vor
Runde 4 (Backup hatte `offset_top = 8`). **Noch nicht getestet.**

## Einheiten-Tab: linker Rand, Nachbesserung (2026-08-05)

Nutzer-Retest (`bilder/einheiten.PNG`, 22:27) nach dem ersten Puffer-Fix
(offset_left 4→16): "Gruppe 1"/"Neue Rekruten:"/"Wähl." jetzt vollständig
sichtbar — Fix wirkt also grundsätzlich. Aber: die dynamisch per Code
erzeugte Trupp-Zeile (`_refresh_units_ui()`, `label.text = "T%d %s
HP%d..."`) zeigt weiterhin "0 Feld HP100..." statt "T0 Feld HP100...",
genau ein Buchstabe fehlt. Erklärung für den Unterschied: `Button`-Nodes
(wie "Wähl.") haben von Godot aus einen eigenen kleinen Innenabstand in
ihrer StyleBox, zusätzlich zum gemeinsamen Panel-Puffer — reicht schon bei
+12px. Ein reines `Label` (wie diese Trupp-Zeile) hat KEINEN eigenen
Innenabstand, Text beginnt exakt an der Container-Kante — bei +12px reicht
das knapp nicht, um den einzelnen "T"-Buchstaben (~8-10px breit) komplett
freizulegen. Bestätigt die grundsätzliche Diagnose (Versatz zwischen
Panel-Clip-Bereich und Inhalt), nur die Puffergröße war noch knapp zu
klein. Fix: `offset_left` von 16 auf 28 erhöht. **Noch nicht erneut
getestet.**

## Einheiten-Tab: linker Rand abgeschnitten, Verdachts-Fix (2026-08-05)

Nutzer-Screenshot (`bilder/einheiten.PNG`, nach Rückfrage bestätigt: kein
Zuschnitt-Artefakt, tritt im echten Fenster auf) zeigt konsequent den
ERSTEN Buchstaben jeder Zeile abgeschnitten ("Gruppe 1" → "ruppe 1", "Neue
Rekruten" → "eue Rekruten", "Wähl." → "ähl."). Wichtiges Unterscheidungs-
merkmal: abgeschnitten wird der ANFANG, nicht das Ende der Texte — normales
"Text zu lang für die Box"-Clipping (clip_text) schneidet immer am Ende,
nie am Anfang. Spricht für einen kleinen Versatz zwischen dem sichtbaren
Bereich von `MainTabsUI/Panel` (`clip_contents = true`) und seinem
tatsächlichen Inhalt, nicht für zu wenig Breite insgesamt. **Kann ohne
Editor-Zugriff nicht zweifelsfrei bestätigt werden** — Verdachts-Fix statt
gesicherter Diagnose: `TabContainer`s `offset_left` (Innenabstand zum
Panel-Rand) von 4 auf 16 erhöht, als Sicherheitspuffer gegen genau diesen
Versatz. **Nutzer bitte explizit um Rückmeldung, ob das den Effekt
tatsächlich behebt** — falls nicht, ist die eigentliche Ursache woanders zu
suchen.

## Home-Base ersetzt gewähltes Gebäude statt daneben zu stehen (2026-08-05)

Nutzerwunsch nach drei gesammelten Punkten ("start gebäude muss versetzt
werden ... startbase die sitzt auf der straße ... soll die startbase das
gebäude ersetzen"), Priorität 1 von dreien (siehe zwei Einträge weiter
unten für die anderen beiden, noch offen). Ursache: `request_choose_start_
base()` platzierte die Home-Base bisher NEBEN dem gewählten Gebäude
(`away`-Richtung von der Zonen-Mitte, `BASE_CHOICE_HOME_OFFSET` + halbe
Gebäude-Diagonale) — landete je nach Gebäude-/Straßen-Lage sichtbar auf der
Straße. Fix: Home-Base spawnt jetzt exakt an der Gebäude-Position, das
Gebäude wird direkt danach abgerissen (`building._demolish.rpc()`, ersetzt
es also wirklich statt daneben zu stehen). Trupp-Startversatz nutzt jetzt
die neue Konstante `HOME_BASE_HALF_DIAGONAL` (aus `HomeBase.tscn`s eigener,
einheitlicher Boxgröße) statt der gebäudespezifischen Diagonale, da das
Gebäude danach nicht mehr existiert. `BASE_CHOICE_HOME_OFFSET`-Konstante
entfernt (nicht mehr gebraucht). Details in [`zones.md`](zones.md),
"Start-Basis wählen". **Noch nicht getestet** — als Nächstes: Punkt 2
(Trupps spawnen im Haus statt davor) und Punkt 3 (Einheiten-Tab-Inhalte
teilweise außerhalb des sichtbaren Bereichs).

## Editor-Workflow-Anleitung ergänzt (2026-08-05)

Nutzer meldet, der `HUD.layer = 0`-Fix (siehe Eintrag direkt unten) wirkt
immer noch nicht — Datei-Check bestätigt: der Wert steht nach wie vor
korrekt in `World.tscn`. Wahrscheinlichste Erklärung: `World.tscn` war
beim externen Schreiben durch Claude im Editor offen, der Editor testet
dann weiter seinen alten Stand im Speicher (gleiches Prinzip wie die
"vanished parent"-Fälle, nur umgekehrt — nicht der externe Fix geht
verloren, sondern er wird schlicht nicht geladen, bis die Szene neu
geöffnet wird). Nutzerwunsch: eine Anleitung, um solche kleinen
Eigenschaften-Fixes künftig selbst im Editor nachvollziehen/setzen zu
können, statt auf Textdatei-Bearbeitung angewiesen zu sein. Neu:
[`editor-workflow.md`](editor-workflow.md) — Faustregel zum sicheren
Neuladen extern geänderter Szenen, plus konkrete Schritt-für-Schritt-
Anleitung für den `HUD`/`Layer`-Fall (Inspector → CanvasLayer → Layer),
plus allgemeines Muster für beliebige andere Node-Eigenschaften.

## HUD-Text scheint durchs Tab-Overlay durch (2026-08-05)

Nutzer bestätigt vorherigen Fix ("deutlich besser"), neuer Screenshot
(`bilder/einheiten.PNG`) zeigt: im "Einheiten"-Tab (weitgehend leer, da
noch keine Einheiten rekrutiert) scheint `HUD/BaseChoiceLabel` ("...deine
Start-Basis — klicke auf eines der Geb...") direkt durch das
`MainTabsUI/Panel`-Overlay durch, kaum lesbar. Ursache: alle `CanvasLayer`-
Nodes (`HUD`, `ResourcesUI`, `TopBarUI`, `TabColumnUI`, `MainTabsUI`,
`InfoBoxUI`) hatten nie einen expliziten `layer`-Wert, liefen also alle auf
dem Godot-Default — die Zeichenreihenfolge zwischen gleichrangigen
CanvasLayers ist dann nicht zuverlässig garantiert. Fix: `HUD` bekommt
`layer = 0` (alle anderen bleiben auf Default/1), damit Hintergrund-HUD-
Texte immer HINTER den übrigen UI-Layern liegen, nie davor. **Noch nicht
getestet.**

## Doppelte Tab-Kopfzeile + zu große Schrift im Overlay behoben (2026-08-05)

Nutzer-Screenshot (`bilder/kompakt.PNG`) nach dem Balken-Fix: Balken war
weg, aber zwei neue Probleme sichtbar. (1) Über dem Tab-Inhalt erschien
eine zweite, eingebaute Tab-Kopfzeile ("Einheiten Handel Wetter
Forschung") zusätzlich zur linken Tab-Spalte (`TabColumnUI`) — Ursache:
`TabContainer.tabs_visible = false` (ursprünglich extra gesetzt, um genau
das zu verhindern, siehe Eintrag "IFZ-Stil-Overlay" weiter unten) fehlte
komplett in `World.tscn`, wieder dieselbe Editor-Speicher-Falle wie schon
zweimal zuvor in dieser Session. (2) Schrift im ganzen Overlay zu groß
(Godot-Standard 16 statt kompakt) — Ursache: das gemeinsame Kompakt-Theme
wurde vor zwei Runden komplett entfernt (hatte einen Ladefehler
verursacht), seitdem hat der Tab-Inhalt keine Schriftgrößen-Vorgabe mehr.
Fix für beides: `tabs_visible = false` am `TabContainer` wieder ergänzt;
für die Schrift diesmal KEIN gemeinsames `Theme`-Sub-Resource (Ursache des
früheren Ladefehlers), sondern ein einfacher
`theme_override_font_sizes/font_size = 13`-Eigenschaftswert direkt am
`MainTabsUI/Panel`-Node (kaskadiert auf alle Kind-Controls ohne eigene
Font-Size, keine separate Theme-Resource, gleiches risikoarme Muster wie
schon bei einzelnen Labels im Ressourcen-Panel verwendet). **Noch nicht
getestet.**

## Loot-Ziel-Linie: Ankunfts-Distanz größenabhängig gemacht (2026-08-06)

Nutzer-Bestätigung "ist besser" fürs Schweben, direkt danach neuer Report:
bei 3 per Shift-Klick angehängten Häusern rückt die Loot-Ziel-Linie nie
zum nächsten Ziel vor. Ursache: die "angekommen"-Prüfung maß gegen den
GEBÄUDE-MITTELPUNKT mit einer festen 4m-Schwelle — ein Trupp durchsucht
ein Gebäude aber von dessen Rand aus, bei großen Gebäuden (Supermarkt
~18m) blieb er dadurch dauerhaft weiter als 4m vom Mittelpunkt entfernt.
Neue `World._loot_arrival_distance(building)` berechnet die Schwelle jetzt
aus der halben Gebäude-Diagonale + Puffer statt eines festen Werts.
Details in [`scavenging.md`](scavenging.md). **Noch nicht getestet.**

## Schweben-Bug, zweiter Teil: der zentrale Wegpunkt-Folger (2026-08-06)

Code-Review-Runde ("geh nochmal den ganzen Code durch") deckte auf: der
erste Schweben-Fix (2026-08-05) deckte nur `_process_attack()`/
`_process_harvest()` ab. Nutzer-Report direkt danach ("loot ein Haus, komm
raus, bin in der Luft, laufe so zur Startbase, auf die Straße geschickt
gehen sie wieder auf den Boden") zeigte den ECHTEN Kern: der von JEDEM
Bewegungsbefehl genutzte `Survivor._handle_movement()` hatte dieselbe
Bugklasse. `_return_to_base()` (automatischer Rückweg nach jeder Suche)
setzt `_waypoints` direkt aus `home_base.position`/`outpost.position` —
beide sitzen wie Gebäude auf halber Höhe, nicht am Boden. Der Nutzer-
Hinweis "schickt man sie auf die Straße, gehen sie wieder auf den Boden"
erklärt sich genau daraus: `order_move()`-Ziele sind schon korrekt
bodennah, das Hinlaufen dorthin zieht die Y-Höhe over move_toward() also
wieder runter.

Fix diesmal EINMAL zentral in `_handle_movement()` (nicht mehr pro
Aufrufstelle) — die Y-Höhe jedes Wegpunkt-Ziels wird für Bewegung UND
Ankunfts-Prüfung komplett ignoriert, eigene Höhe bleibt immer bestehen.
Deckt dadurch automatisch auch `order_station()` und die Baustellen-
Zuweisung ab (beide setzen `_waypoints` ebenfalls teils direkt aus einer
Gebäude-Position), ohne dass die dortigen Bugs überhaupt einzeln gemeldet
werden mussten. Details in [`survivor.md`](survivor.md). **Noch nicht
getestet.**

## Nachbesserungen nach erstem Retest (2026-08-06)

Nutzer-Retest der letzten Runde: Maus-Zoom, Maus-Ziehen und die Loot-Ziel-
Anzeige bestätigt funktionierend, aber drei Nachbesserungen nötig:

1. **Horde kam trotz doppelter Tageslänge wieder an Tag 1.** Die
   CYCLE_LENGTH-Verdopplung (siehe unten) schiebt zwar JEDE Nacht später,
   ändert aber nichts daran, dass laut Design jede Nacht (auch die erste)
   eine Horde auslöst. Fix: `_handle_day_night()` löst die Horde jetzt erst
   ab `_day_count > 0` aus — die allererste Nacht bleibt garantiert ruhig,
   ab der zweiten Nacht wieder wie gehabt jede Nacht.
2. **Loot-Ziel-Linie zeigte bei Shift-Klick-Mehrfachzielen nur das
   ZULETZT geklickte Gebäude** — `_loot_routes` speicherte pro Trupp nur
   einen einzelnen Wert, jeder weitere Shift-Klick überschrieb ihn. Jetzt
   eine Liste pro Trupp (spiegelt `Survivor._search_queue`, rein lokal
   nachgebildet), additive Klicks hängen an, `_update_loot_route_lines()`
   zeigt/verarbeitet immer nur den vordersten (aktuellen) Eintrag und
   rückt beim Ankommen automatisch zum nächsten vor.
3. **Linie verschwand nicht, wenn der Trupp einen ANDEREN Befehl bekam**
   (Bewegen, Stoppen, Angreifen, Einsteigen, Claimen/Abreißen) — vorher
   nur über die Ankunfts-Distanz entfernt. Neue `_clear_loot_route(unit)`
   jetzt an jeder befehlsgebenden Stelle aufgerufen, die NICHT Teil einer
   Such-Route ist.

Details in [`scavenging.md`](scavenging.md), "Loot-Ziel-Anzeige". Alle
drei **noch nicht erneut getestet**.

## Kamera-/Karten-Steuerung erweitert + Einstellungen (2026-08-05)

Restliche vier Punkte aus [`bugliste.md`](bugliste.md):

1. **Kartenansicht (Taste M) per Maus-Halten+Ziehen verschiebbar** —
   `MapView.gd`s Rechtsklick-Verhalten von "Klick springt Ausschnitt
   sofort dahin" auf echtes Ziehen umgebaut.
2. **Kamera im Hauptspiel zusätzlich zu WASD per Maus-Ziehen schwenkbar**
   — neue mittlere Maustaste (links/rechts schon belegt), "Karte greifen"-
   Gefühl (Cursor-Weltpunkt bleibt unterm Cursor), ergänzt WASD statt es
   zu ersetzen.
3. **Zoom zur Mausposition** — `World._zoom()` verschiebt beim Zoomen den
   Pivot zusätzlich so, dass der Weltpunkt unter dem Cursor ungefähr dort
   bleibt (Vorher/Nachher-Raycast-Vergleich), statt immer nur um den
   festen Pivot-Punkt herum zu zoomen.
4. **Beides über Einstellungen umschaltbar** — zwei neue Häkchen im
   `SettingsMenu` ("Kamera per Maus ziehen", "Zoom zur Mausposition"),
   beide standardmäßig an. Details in [`settings.md`](settings.md).

Alle vier **noch nicht getestet**.

## Erste drei Punkte der Bugliste abgearbeitet (2026-08-05)

Aus [`bugliste.md`](bugliste.md), Nutzerwunsch "kannst sonst anfangen":

1. **Loot-Ziel-Anzeige** — dünne gelbe Linie vom Trupp zum Zielgebäude
   während der Anlauf-Phase, rein lokal/kosmetisch. Details in
   [`scavenging.md`](scavenging.md), "Loot-Ziel-Anzeige".
2. **Zeit lief zu schnell:** `CYCLE_LENGTH` 300s → 600s (Tag-Länge
   verdoppelt) — schiebt Nachteintritt UND jede Horde proportional mit
   nach hinten, behebt damit direkt auch "Horde kam an Tag 1" mit.
3. **Forschungs-Tab zeigte nur "noch nicht erforscht" ohne Details:**
   `_add_research_status_row()` zeigt jetzt zusätzlich Herstellungskosten
   (Crafting-Rezepte) bzw. eine Kurzbeschreibung (Gebäude-Ausbaustufen,
   neues `"desc"`-Feld bei `BUILDING_RESEARCH`).

Alle drei **noch nicht getestet**. Als Nächstes: Kamera-/Karten-Steuerung
(Maus-Ziehen, Zoom-zur-Maus, Einstellungen) — größerer, noch offener Block.

## Bugliste angelegt (2026-08-05)

Nutzer sammelt beim Freundes-Playtest laufend Bugs/Wünsche, bevor im Detail
einzeln darauf eingegangen wird — neue Datei
[`bugliste.md`](bugliste.md) dafür angelegt (getrennt von
`pending-tests.md`, das sind Checklisten zu SCHON umgesetzten Features,
hier stehen NEU gemeldete, noch nicht angegangene Punkte). Aktueller
Stand: 8 offene Punkte (Loot-Ziel-Anzeige, Zeittempo, Horde an Tag 1,
Karten-/Kamera-Steuerung, Forschungs-Tab zeigt keine Rezepte), 5 bestätigt
funktionierende Punkte aus derselben Runde.

## Einheiten schwebten nach Gebäude-Angriff/-Abriss in der Luft (2026-08-05)

Nutzer-Report ("erster Bug beim Test"): bestehende Einheiten schweben nach
einem Haus-Abriss in der Luft. Ursache gefunden: `World._create_building()`
positioniert Gebäude mit `position.y = size.y / 2` (Box-Mittelpunkt, nicht
Boden — oft mehrere Meter hoch bei echten Assets). `Survivor._process_
attack()`/`_process_harvest()` (und identisch `Zombie._process_chase()`/
`Bandit._process_chase()`) bewegten sich per `position.move_toward(target.
position, ...)` auf die VOLLE 3D-Position des Ziels zu — eine Einheit, die
sich einem hohen Gebäude näherte, "kletterte" dabei sichtbar Richtung
Gebäude-Mittelhöhe und blieb nach dessen Zerstörung (`queue_free()`) genau
dort hängen, weil nichts die Y-Position danach zurücksetzt.

Fix in allen vier Funktionen: Bewegung nutzt jetzt nur noch die
horizontale (X/Z) Distanz zum Ziel, eigene Y-Höhe bleibt unverändert.
**Wichtiger Nebenfix, ohne den der Hauptfix Gebäude-Angriffe/-Abriss vollständig
gebrochen hätte:** die Reichweiten-Prüfung (`dist <= HARVEST_RANGE`/
`ATTACK_RANGE`) nutzte ebenfalls volle 3D-Distanz — vorher "funktionierte"
das nur, WEIL die Einheit in Y mitkletterte und sich so überhaupt der vollen
3D-Position annähern konnte (`HARVEST_RANGE` ist mit 1,2m kleiner als die
Höhendifferenz zu praktisch jedem echten Gebäude). Ohne das Mitklettern
hätte keine Einheit mehr nah genug "rangekommen", um überhaupt anzugreifen/
abzureißen. Beide Distanzberechnungen ebenfalls auf reine X/Z-Distanz
umgestellt. Details in [`survivor.md`](survivor.md). **Noch nicht
getestet** — bitte gezielt einen Bautrupp ein Gebäude abreißen lassen UND
einen Zombie ein geclaimtes Gebäude angreifen lassen, beides sollte wie
gehabt funktionieren, nur ohne das Schweben danach.

## Trupp-Farben: fest pro Spieler + Trupp-Art (2026-08-05)

Nutzerwunsch vor dem geplanten Freundes-Test: Trupps sollen nicht mehr pro
EINZELNER Einheit zufällig eingefärbt sein (Stand seit 2026-08-03), sondern
klar zeigen WEM ein Trupp gehört und OB er Feld- oder Bautrupp ist —
"eigene Trupps weiß, Bautrupps orange, bei anderen Spielern z. B. blau/gelb,
für jeden Spieler eine eigene Farbe". `Survivor._unit_base_color()`
komplett umgebaut: feste `Color`-Paare (`PLAYER_FIELD_COLORS`/
`PLAYER_BUILD_COLORS`) statt der bisherigen `trupp_id`-Hash-Farbe. Index 0
(Weiß/Orange) ist immer der EIGENE Spieler, Index 1-3 gehen an Mitspieler,
zugeordnet über die nach Peer-ID sortierte Liste aller anderen bekannten
`NetworkManager.players` (deckt `MAX_PLAYERS := 4` komplett ab). Zivilisten
(`UNASSIGNED`) bleiben unabhängig davon einheitlich grau. Details +
bekannte Einschränkung (Mitspieler-Zuordnung ist nicht zwingend auf jedem
Bildschirm identisch, reiner Kosmetik-Fix) in [`survivor.md`](survivor.md).
**Noch nicht getestet.**

## Schwarzer Balken über den ganzen Bildschirm behoben (2026-08-05)

Nutzer-Screenshots (`bilder/balken.PNG`, `bilder/schwrzerbalken.PNG`) zeigten
einen dunklen Balken quer über die volle Bildschirmbreite, genau über der
"Wähle deine Start-Basis"-Meldung. Ursache: `ResourcesUI/Panel` (das
Ressourcen-Panel oben rechts) hatte seit der UI-Redesign-Runde 4
`anchors_preset = 10` ("Top Wide", volle Breite) statt `1` ("Top Right",
Ecke oben rechts) — `anchor_left = 1.0` fehlte, war beim Umbau
verlorengegangen (gleiche Fehlerklasse wie die bereits dokumentierten
"vanished parent"-Probleme dieser Runde). Vergleich mit dem Stand vor
Runde 4 (`koop-game-backup-2026-08-04.tar.gz`) bestätigte: dort war
`anchor_left = 1.0` UND `anchor_right = 1.0` gesetzt (rechts angepinnt).
Fix: `anchors_preset = 1`, `anchor_left = 1.0` ergänzt, `offset_left`/
`offset_right` auf einen 304px breiten, rechts angepinnten Bereich
korrigiert (`-312`/`-8`), `offset_top`/`offset_bottom` unverändert vom
Nutzer-Stand übernommen. **Achtung:** Datei wurde beim Bearbeiten zwischen
Lesen und Schreiben bereits einmal von außen verändert (vermutlich Godot-
Editor offen) — falls `World.tscn` gerade im Editor offen ist, vor dem
nächsten Speichern dort neu öffnen, sonst geht dieser Fix wieder verloren
(bekannte Falle, siehe Eintrag weiter unten). **Noch nicht getestet.**

## Start-Haus schwebte über der Kollisionsbox (2026-08-05)

Nutzer-Report "das Start-Haus ist verschoben und in der Luft". Ursache im
glTF selbst geprüft (Python-Skript liest die POSITION-Accessor-Min/Max-
Werte direkt aus `startbasetest.glb`): der Modell-Ursprung liegt an der
BASIS (lokale Y läuft 0 bis 6,928), nicht in der Mitte. `HomeBase.tscn`s
`Model`-Kind hatte aber nie den bei allen anderen Gebäuden längst
etablierten Ausgleich (`_model_min_y()`-Pattern aus `_create_building()`,
siehe Apotheke/Wohnhaus/Supermarkt) — HomeBase läuft nicht über
`_create_building()`, wurde beim Verallgemeinern übersehen. Die
unsichtbare Mesh/Collision-Box (`BoxMesh_homebase`/`BoxShape3D_homebase`,
zentriert) blieb dadurch korrekt am Boden (`HOME_BASE_GROUND_Y := 3.464`
hebt die zentrierte Box exakt auf 0–6,928), aber das sichtbare `Model`
erbte dieselbe +3,464-Verschiebung zusätzlich zu seinem eigenen
Basis-Ursprung — schwebte dadurch komplett über der eigentlichen
(unsichtbaren) Kollisionsbox. Fix: `Model`-Node in `HomeBase.tscn`
bekommt `position = Vector3(0, -3.464, 0)`, exakt das Gegenstück zur
`HOME_BASE_GROUND_Y`-Anhebung des Elternknotens. Noch nicht getestet.

## UI-Redesign Runde 4: großes leeres Overlay-Panel behoben (2026-08-05)

Nutzer-Screenshot (`bilder/ui überarbeitung.PNG`) nach dem ersten Test von
Runde 4: linke Tab-Spalte sitzt korrekt, aber ein großes dunkles,
leeres Rechteck in der Bildschirmmitte darunter. Ursache: `MainTabsUI/
Panel` fehlte in `World.tscn` das `visible = false` — Godot-Default für
neue Panel-Nodes ist `visible = true`, das Overlay (soll laut
`_on_tab_button_pressed()` in `World.gd:5505` nur bei Tab-Klick
erscheinen) war dadurch von Anfang an sichtbar, nur ohne aktiven Tab
also leer. Fix: `visible = false` beim Panel-Node ergänzt. **Achtung
beim nächsten Editor-Speichern:** genau dieses Attribut ging in einer
früheren Runde schon mal durchs Editor-Speichern verloren (siehe
Eintrag "Zweiter Nachtrag" weiter unten) — `World.tscn` vor dem
nächsten Speichern im Editor neu öffnen. Noch nicht erneut getestet.

## AKTUELL OFFEN: UI-Redesign Runde 4 — neues Layout, noch nicht getestet (2026-08-05)

**Für die nächste Session, falls der Chat geleert wurde:** Statt den
leeren Diagnose-Minimalstand aus der vorherigen Runde (siehe Eintrag
direkt unten) erst wiederherzustellen und dann nochmal umzubauen, kam der
Nutzerwunsch nach einem neuen Layout ("oben mittig ein kleiner Balken,
links ein paar Tabs von oben nach unten", angelehnt an IFZ) — beides in
einem Schritt erledigt.

**Neue Struktur:**
- `$TopBarUI/Panel`: schmal, horizontal zentriert (statt voller Breite),
  enthält nur noch Kalender/Uhr/Zeitraffer/Pause (`HBoxContainer` direkt
  mit den vier Elementen, keine `TimeBox`-Zwischenebene mehr).
- **Neu:** `$TabColumnUI/Panel` — eigene linke Spalte (x=8–60, oben bei
  y=60 bis unten y=-8), `VBoxContainer` mit den 9 Tab-Buttons
  (Wetter/Forschung/Herstellen/Bauen/Einheiten/Trupp/Karte/Ereignisse/
  Handel), von oben nach unten statt der vorherigen horizontalen
  `TabButtonsRow`. Gleiche `_on_tab_button_pressed()`-Logik in
  `World.gd`, nur die Pfade zeigen jetzt hierhin.
- `$MainTabsUI/Panel` (Overlay-Inhalt): Position von x=16–456 auf
  x=68–456 verschoben, damit es neben der neuen linken Spalte aufklappt
  statt sie zu überdecken.
- `World.gd`: alle betroffenen `@onready var`s zeigen jetzt auf die neuen
  Pfade. `get_node_or_null()` + `if`-Guards bewusst BEIBEHALTEN (nicht
  zurück auf strikte `$Pfad`e) — der genaue Auslöser des ursprünglichen
  Absturzes wurde nie zweifelsfrei bestätigt, der leere Minimalstand kam
  nie zum tatsächlichen Testen (siehe Eintrag unten). Sicherheitsnetz
  bleibt also vorerst drin, kann nach einem bestätigt erfolgreichen Test
  zurückgebaut werden.

**Nutzer sollte als Nächstes testen:** Lädt `World.tscn` jetzt ohne
Absturz? Falls ja: sieht das neue Layout wie erwartet aus (schmaler
Balken oben mittig, Tab-Spalte links, Overlay klappt daneben auf, kein
Überlappen mit dem Ressourcen-Panel oben rechts)? Falls der Absturz
IMMER NOCH auftritt, lag die Ursache nie in `TopBarUI` selbst (siehe
"Falls der Minimalstand IMMER NOCH abstürzt" im Eintrag direkt unten für
die nächsten Verdächtigen).

**Zweiter Nachtrag — eigentliche Ursache gefunden (2026-08-05):** Die
Godot-Log-Datei (`%APPDATA%/Godot/app_userdata/KoopGame/logs/godot.log`,
lässt sich direkt einsehen statt auf Screenshots angewiesen zu sein!)
zeigte: ALLE per Texteditor neu eingefügten Knoten (nicht nur die
`VBoxContainer`-Umbenennung von eben) hatten "vanished parent". Nutzer
hat `World.tscn` daraufhin im Godot-Editor selbst geöffnet und mit
Strg+S gespeichert — dabei hat Godot die komplette Datei ins neue
Format migriert (`unique_id=`-Attribut pro Node, `uid=` bei
Ressourcen, `load_steps` entfällt). Diagnose danach: meine per Hand
eingefügten `Panel`-Nodes (unter `TopBarUI`/`TabColumnUI`) waren dabei
tatsächlich verloren gegangen — Godot hat ihre Kind-Knoten als
Rettungsmaßnahme direkt an die Wurzel gehängt, mit kryptischen Namen wie
`TopBarUI_Panel#HBoxContainer`. **Ursache: von außen eingefügte Nodes
ohne `unique_id`-Attribut werden von dieser Godot-Version offenbar nicht
zuverlässig verarbeitet.** Fix: komplette `TopBarUI`/`TabColumnUI`-Struktur
neu aufgebaut, diesmal mit eigenen `unique_id`-Werten UND `layout_mode`
(Godot setzt das automatisch auf Kind-Controls von Containern — hatte in
der vorherigen Fassung gefehlt, wahrscheinlich Teil desselben Problems).
**Wichtige Lektion fürs weitere Vorgehen:** Sobald `World.tscn` im
Editor offen ist, gehen externe Datei-Änderungen (auch von mir) beim
nächsten Editor-Speichern verloren, wenn die Datei zwischenzeitlich nicht
neu geöffnet wurde — ist genau so passiert (`visible = false` bei
`InfoBoxUI/Panel` ging beim Speichern wieder verloren, musste ein
zweites Mal gesetzt werden). Am saubersten: Datei nach jeder Session-
Änderung von mir im Editor neu öffnen (oder Editor kurz schließen/neu
starten), bevor im Editor gespeichert wird. **Noch nicht erneut
getestet.**

**Nachtrag — echter Fehler gefunden (2026-08-05):** Godot-Ausgabe zeigte
`Parent path './TabColumnUI/Panel/VBoxContainer' for node 'X' has
vanished when instantiating` für mehrere Tab-Buttons. Ursache: der Name
"VBoxContainer" wurde doppelt im Baum vergeben (schon vorher bei
`ResourcesUI/Panel/VBoxContainer`, jetzt zusätzlich neu bei
`TabColumnUI/Panel`) — Godots Pfadauflösung kam damit offenbar
durcheinander, obwohl beide unter verschiedenen Eltern liegen. Zum
Vergleich: das neue `TopBarUI/Panel/HBoxContainer` (einziges seiner Art
im Baum) hatte laut Fehlerausgabe keine Probleme — stützt die Diagnose.
Fix: `TabColumnUI/Panel/VBoxContainer` in `TabButtonList` umbenannt
(Node in `World.tscn` + alle neun `@onready`-Pfade in `World.gd`).
**Noch nicht erneut getestet.**

**Bekannter, bewusst nicht behobener Nebenpunkt:** `HUD/InfoPanel`,
`HUD/Label` (Auswahl-Info) und `HUD/StatusLabel` stehen weiterhin bei
x=352+ (aus einer älteren Runde, als die linke Spalte noch bis x=336
ging) — überlappen sich jetzt teilweise mit dem aufgeklappten
`MainTabsUI/Panel`-Overlay (endet bei x=456). Bestand schon vor dieser
Runde in ähnlicher Form (keine neue Regression), aber jetzt sichtbarer,
weil die Tab-Spalte selbst viel schmaler geworden ist. Bei Bedarf im
nächsten Schritt mit nachjustieren.

---

## VORHERIGE RUNDE: UI-Redesign-Absturz, mitten in der Diagnose (2026-08-05)

**Für die nächste Session, falls der Chat geleert wurde — hier steht,
woran wir hängen:**

Großes UI-Redesign (obere Leiste mit Kalender/Zeit-Steuerung + 9 Tabs
als IFZ-Stil-Overlay, siehe die mehreren "UI-Redesign"-Einträge weiter
unten in dieser Datei für die volle Historie) lädt seit der `TopBarUI`-
Einführung nicht mehr — `World.tscn` stürzt beim Start ab
("Invalid assignment of property or key 'visible' ... on a base object
of type 'null instance'" bei `speed_row.visible = ...`, 48-49 Fehler
insgesamt). Zwei Reparatur-Versuche (Theme-Sub-Resource entfernt) haben
NICHT geholfen — der Fehler bleibt exakt gleich. Statische Prüfung
(Eltern-Ketten/Duplikate/Resource-Referenzen per Skript über die ganze
`.tscn`) findet keine strukturelle Ursache. **Ohne laufenden Godot-
Editor in dieser Entwicklungsumgebung lässt sich das nicht selbst
nachstellen/debuggen.**

**Aktueller Zwischenstand (zuletzt umgesetzter Schritt):** `TopBarUI/
Panel` in `World.tscn` komplett leer geräumt (nur die Panel-Hülle ohne
Kinder), alle zugehörigen `@onready var`s in `World.gd` (day_label,
clock_label, speed_row, speed_1x/2x/3x_button, pause_button,
weather_tab_button, research_tab_button, crafting_tab_button,
build_tab_button, units_tab_button, unit_detail_tab_button,
map_tab_button, event_tab_button, trade_tab_button) auf
`get_node_or_null()` umgestellt, jede Verwendungsstelle mit `if`-Guards
abgesichert (`_ready()`, `_update_clock_label()`,
`_update_speed_buttons()`, `_refresh_crafting_ui()`,
`_update_unit_detail_panel()`). **Nutzer sollte als Nächstes genau
DIESEN Minimalstand testen** (Absturz weg oder nicht?) — Ergebnis stand
beim Schreiben dieses Eintrags noch aus.

**Falls der Minimalstand LÄDT:** schrittweise wieder Kinder in
`TopBarUI/Panel` einfügen (zuerst nur die leere `HBoxContainer`, dann
`TimeBox` mit den Labels, dann `SpeedRow`, dann `TabButtonsRow` mit den
9 Buttons), nach JEDEM Schritt neu testen lassen, bis der genaue
Baustein gefunden ist, der abstürzt — dann NUR den anders lösen (z. B.
ohne `layout_mode`, oder mit absoluter Positionierung statt
HBoxContainer, siehe Verdachtsliste unten).

**Falls der Minimalstand IMMER NOCH abstürzt:** Ursache liegt NICHT in
`TopBarUI` selbst, sondern irgendwo anders in den heutigen Änderungen
(z. B. `ResourcesUI`-Verschiebung, `InfoBoxUI`, `MainTabsUI`-Overlay-
Umbau, oder eine der `World.gd`-Änderungen wie `_on_tab_button_pressed()`/
`_tab_buttons`-Arrays) — als Nächstes DIESE Bereiche genauso isolieren.

**Bereits ausgeschlossene Verdächtige:** gemeinsames `Theme`-Sub-Resource
(entfernt, Fehler blieb), doppelte Node-Namen (keine gefunden), fehlende
Sub-/Ext-Resource-Referenzen (keine gefunden), gebrochene Eltern-Ketten
in der `.tscn`-Textstruktur (alle Pfade lösen textuell korrekt auf).

**Noch nicht behoben, aber niedrige Priorität:** die vielen "UI-Redesign"-
Einträge unten in dieser Datei liegen aus Versehen NICHT chronologisch
ganz oben (Anker-Punkt beim Einfügen war nicht mehr aktuell) — rein
kosmetisches Ordnungsproblem in dieser Doku-Datei selbst, keine
Auswirkung aufs Spiel.

## Grüner Boden flackert (Z-Fighting) behoben (2026-08-04)

Nutzer-Report nach dem SSAO/Grime-Test: "der grüne Boden flakert das
asset muss man vielleicht ganz minimal hochsetzen". Ursache: Die
`Ground`-Box-Oberkante (`size.y/2 = 0.1`) lag HÖHER als
`$StreetGridMap.position.y` (`-0.1`) — Boden-Box und Straßen-/Gras-
Kachel-Geometrie überschnitten sich knapp in der Tiefe, SSAO macht so
etwas als sichtbares Flackern erkennbar (vorher unauffällig ohne SSAO).
Fix: `Ground`-Node auf `position.y = -0.3` gesetzt statt die Straßen-
Assets selbst zu verschieben (isolierter, unkritischer Fix — nur die
Boden-Box bewegt sich, keine andere Systemlogik hängt an ihrer exakten
Position, nur an ihrer über `MAP_SIZE` gesetzten Größe).

**Nachtrag — Fix reichte nicht:** Nutzer bestätigt "flackert nur in der
Nähe von Straßen/Kacheln" — das ist NICHT die Ground-Box gegen
StreetGridMap, sondern vermutlich ein winziger Höhen-Mismatch zwischen
einzelnen Straßen-Kachel-Assets selbst (Asphalt- vs. Gras-Kachel,
sub-mm-Ungenauigkeit aus dem Blender-Export) — kann ohne Editor-Zugriff
nicht exakt vermessen werden. Pragmatische Abmilderung statt Geometrie-
Fix: SSAO deutlich sanfter (`ssao_intensity` 2.5→1.0, `ssao_power`
1.8→1.0, `ssao_radius` 1.5→1.0, neu `ssao_sharpness` 0.5 für mehr
Weichzeichnung), damit es solche Mini-Überschneidungen nicht mehr so
hart als Flackern zeigt. Kein garantierter Fix, nur eine Abmilderung —
laut Nutzer immer noch da.

**Zweiter Nachtrag — Screenshot zeigt fleckige/facettierte Grasfläche**
(`bilder/fehler in grünen feld.PNG`): sichtbare gerade Kanten zwischen
einzelnen Gras-Kacheln, typisches Muster für SSAO-Verschattung an
Kachel-Rändern (jede Kachel wird einzeln verschattet statt als
zusammenhängende Fläche). `ssao_enabled` komplett auf `false` gesetzt zum Test — **Nutzer
bestätigt: flackert trotzdem**, also unabhängig von SSAO. Damit war die
Ursache nie SSAO selbst, sondern echte Geometrie-Überschneidung
zwischen einzelnen Gras-Kacheln (Blender-Export-Ungenauigkeit an den
Kachel-Rändern, ohne Editor-Zugriff nicht exakt vermessbar).

**Pragmatischer Fix (Nutzerwunsch "kann man das Feld vorerst raus
nehmen"):** `_build_zone_street_tiles()` platziert die separate
"grass"-GridMap-Kachel-Ebene in Stadt-Zonen jetzt gar nicht mehr — die
ohnehin grüne `Ground`-Box scheint stattdessen einfach durch.
`_place_grid_tile()` war schon defensiv für ein fehlendes "grass"-Item
ausgelegt, das Weglassen bricht nichts. Straßen-Kacheln (Asphalt)
selbst sind unverändert. SSAO wieder auf die ursprünglichen, kräftigeren
Werte zurückgesetzt (Grund für die Abschwächung ist mit den
Gras-Kacheln entfallen). Noch nicht vom Nutzer im Spiel gesichtet.

## Gebäudezahl moderat angehoben (2026-08-04)

Nutzerwunsch "paar mehr Gebäude zum Testen" nach dem Größen-Vorziehen.
`BUILDINGS_PER_LARGE_ZONE`/`_SMALL_ZONE` 100/50 → 130/65 (Summe 350→455).
Die ursprüngliche Rücknahme auf 100/50 war wegen eines strukturellen
Netzwerk-Absturzes bei 1750 Gebäuden — der ist seitdem unabhängig von der
Gebäudezahl behoben (siehe `networking.md`, Bündel-RPCs +
`_create_building_local()`), 455 bleibt weit darunter. Faustregel aus
`networking.md` sagt, jede Erhöhung nochmal echt zu zweit/mehreren zu
testen — passiert mit dem geplanten Freundes-Test ohnehin.

## Platzhalter-Boxen auf echte Zielmaße vorgezogen (2026-08-04)

Nutzerwunsch, um schon jetzt mit Freunden testen zu können, während
weiter an echten Blender-Assets gearbeitet wird — zehn Loot-Gebäude
+ vier Ausbauten + Außenposten von winzigen Platzhaltern (~1,5-3m) auf
die echten Checklisten-Zielmaße (bis zu 14m) vergrößert. Dabei einen
echten Bug gefunden+behoben: die vier Ausbauten (Krankenstation/
Werkstatt/Lager/Bett) übernahmen bisher die Y-Position des vorherigen,
geplünderten Gebäudes 1:1 — bei größeren Gebäuden/Strukturen wäre das
sichtbar daneben gewesen, jetzt eigene Boden-Y-Konstanten pro Typ.
Details in [`building.md`](building.md), "Platzhalter-Boxen auf echte
Zielmaße vorgezogen". Noch nicht vom Nutzer im Spiel gesichtet.

## UI-Redesign: Absturz-Diagnose per Rückbau (2026-08-05)

Theme-Entfernung hat den Absturz NICHT behoben (Nutzer bestätigt, gleicher
Fehler nach Neustart). Statische Prüfung (Eltern-Ketten-Check, Duplikat-
Check, Resource-Referenz-Check per Python-Skript über die ganze
`World.tscn`) findet keine strukturelle Ursache. Da kein Godot-Editor in
dieser Entwicklungsumgebung verfügbar ist (kann nicht selbst starten/
testen), jetzt methodisches Eingrenzen statt weiterem Raten: `TopBarUI/
Panel` komplett leer geräumt (nur die Panel-Hülle bleibt), alle
betroffenen `@onready var`s auf `get_node_or_null()` umgestellt (liefert
`null` statt Ladefehler) und jede Verwendungsstelle in `World.gd` mit
`if`-Guards abgesichert (`_ready()`, `_update_clock_label()`,
`_update_speed_buttons()`, `_refresh_crafting_ui()`,
`_update_unit_detail_panel()`). Sobald DIESE Minimalversion lädt, kommt
der Leisten-Inhalt schrittweise zurück, bis der genaue Baustein
gefunden ist, der abstürzt.

## UI-Redesign: Ladefehler durch geteiltes Theme behoben (2026-08-05)

Nutzer-Report: World lud nicht mehr, `speed_row.visible = ...` schlug mit
"null instance" fehl, 48 Fehler insgesamt, Ausgabe-Panel aber leer (kein
Parse-Fehler). Ursache vermutlich das neu eingeführte, gemeinsame
`Theme`-Sub-Resource (`Theme_compact_tabs`, `default_font_size = 13`),
angewendet auf drei Panels (`TopBarUI`/`MainTabsUI`/`ResourcesUI`) —
einzige wirklich neue, in diesem Projekt bisher ungetestete .tscn-
Technik dieser Runde, alles andere folgt bewährten Mustern. Komplett
entfernt (Deklaration + alle drei Anwendungsstellen). Kompaktere Schrift
bleibt dort erhalten, wo sie schon einzeln pro Label gesetzt war
(Wetter/Forschung/Event-Log/Ressourcen), nur die Tab-Buttons ohne
eigene Font-Size-Override sind wieder auf Godot-Standardgröße (16) —
unkritisch, da das Overlay jetzt nicht mehr dauerhaft mit anderen
Panels um Platz konkurriert.

## UI-Redesign: IFZ-Stil-Overlay statt dauerhafter Fläche (2026-08-05)

Nutzer verwies auf `bilder/ui.PNG` (Infection Free Zone) — dort sind die
Tab-Icons oben links kompakt in der Ecke, der Inhalt klappt erst bei
Klick auf. Kompletter Umbau der letzten beiden Runden: neue, dünne
`TopBarUI` (44px) mit Kalender/Uhr/Zeitraffer/Pause links + 9 kompakten
Tab-Buttons rechts daneben, alle in EINER Reihe. `MainTabsUI/Panel` ist
jetzt nur noch ein unsichtbares Overlay (`visible=false` default),
`TabContainer.tabs_visible=false` blendet die eingebaute Kopfzeile aus —
ein Button-Klick setzt `current_tab` + blendet das Panel ein, erneuter
Klick auf den schon offenen Tab blendet es wieder aus
(`_on_tab_button_pressed()`). Löst nebenbei das 648px-Höhenproblem der
letzten beiden Runden komplett — das Overlay muss sich mit nichts mehr
dauerhaft den Platz teilen. "Karte"-Button ruft `toggle_map_view()`
direkt auf (kein Overlay nötig). `ResourcesUI` wieder oben rechts, wie
ursprünglich. `crafting_tab_button`/`unit_detail_tab_button` folgen
jetzt derselben Sichtbarkeits-Logik wie ihre Tabs (`_refresh_crafting_
ui()`/`_update_unit_detail_panel()`), inkl. Auto-Schließen des Overlays,
falls es gerade den jetzt versteckten Tab zeigt.

## UI-Redesign: linke Spalte statt oberer Leiste (2026-08-05)

Nutzerwunsch nach dem zweiten Screenshot-Test ("der Balken in der Mitte
soll nach links, von Wetter bis Bücher alles links schmal an die Seite
nach unten"): `MainTabsUI/Panel` UND `ResourcesUI/Panel` jetzt beide in
derselben schmalen linken Spalte (x=16–336) statt der vollen Breite oben
bzw. oben rechts — `ResourcesUI/Panel` direkt unter `MainTabsUI/Panel`
angeschlossen (8px Abstand), wirkt wie ein durchgehender Streifen.
`TimeBox` (Kalender/Uhr/Zeitraffer/Pause) jetzt ÜBER statt NEBEN dem
`TabContainer` (beide bleiben Geschwister-Controls im selben `Panel`,
keine der vielen bestehenden Tab-Pfade geändert). Auf Nutzerwunsch
("Tab-Inhalt kompakter/kleiner, alles reinquetschen") überall auf
Schriftgröße 12–13 reduziert. `HUD/InfoPanel`/`Label`/`StatusLabel`
(Auswahl-Info/Status-Meldungen) mussten dafür ein drittes Mal umziehen —
jetzt rechts von der neuen (jetzt viel höheren) linken Spalte statt
darüber/darunter.

**Bekannter Kompromiss:** 9 Tab-Kopfzeilen passen nicht mehr nebeneinander
in die schmale Spalte — Godots `TabContainer` zeigt dafür automatisch
kleine Scroll-Pfeile im Kopf, alle Tabs bleiben erreichbar, nur nicht
mehr alle gleichzeitig sichtbar.

## UI-Redesign: Nachtrag nach Screenshot-Test (2026-08-04, `bilder/ui falsch positioniert.PNG`)

Erster echter Screenshot zeigte zwei Probleme: (1) der Bauen-Tab-Inhalt
lief komplett unbegrenzt über den Bildschirm und überlappte das
Ressourcen-Panel — `MainTabsUI/Panel` clippte nicht (Godot-Container
clippen NICHT automatisch), jetzt `clip_contents = true` gesetzt, dazu
ein kompaktes `Theme` (`default_font_size = 13` statt Godot-Standard 16)
auf das ganze Panel angewendet (kaskadiert auf alle Buttons/Labels ohne
eigene Font-Size-Override, spart zusätzlich Platz). (2) `BaseChoiceLabel`
("Wähle deine Start-Basis") + `HUD/InfoPanel`/`HUD/Label` (Auswahl-Info)
+ `HUD/StatusLabel` lagen alle noch an ihren ALTEN Positionen im
Top-Bereich, der jetzt von der neuen Leiste belegt ist — alle vier nach
unten verschoben (deutlich unter `MainTabsUI/Panel`s neues Ende bei
y=160). **Weiterhin unbehoben:** Clipping versteckt überschüssigen
Bauen-Inhalt nur, macht ihn nicht erreichbar — ein `ScrollContainer`
bleibt der eigentliche nächste Schritt, falls das stört.

## UI-Redesign: obere Leiste + Wetter-System + Forschung + Event-Log (2026-08-04)

Große Runde nach Nutzer-Skizze (`bilder/ui skizze.jpg`), geplant über
`/plan`-Modus (Plandatei `floating-shimmying-stonebraker.md`). Kalender/
Zeit-Steuerung + alle 9 Tabs (bestehende 5 + neue Wetter/Forschung/Karte/
Ereignisse) jetzt in einer oberen Leiste, plus ein echtes neues Gameplay-
System (Regen reduziert Fog-of-War-Sichtweite) und ein neues Event-Log +
kompakte Info-Box (füllt sich automatisch über den bestehenden
`report_status()`-Weg). Details in [`world.md`](world.md), "UI-Redesign
Runde 3". **Bekannte Einschränkung:** wegen der 648px-UI-Basishöhe musste
die neue obere Leiste deutlich flacher werden als die alte Bauen-Tab-
Box — Tab-Inhalte mit vielen Einträgen (v. a. Bauen) passen jetzt
sichtbar nicht mehr vollständig hinein, ein `ScrollContainer`-Umbau
bleibt offen (siehe `pending-tests.md`). Noch nicht vom Nutzer im Spiel
gesichtet.

## Nebel-Schleier ergänzt (2026-08-04)

Nutzerwunsch direkt nach dem bestätigten Grime/SSAO-Test: "nebel fehlt
dann noch ... ein ganz leichten nebel schleier". Einfacher, günstiger
Distanz-Nebel über `Environment.fog_enabled` in `World.tscn`
(`fog_density = 0.006`, neutrales Grau statt bläulichem Himmel-Ton) —
kein `FogVolume`. Details in [`building.md`](building.md), "Nebel-
Schleier". **Vom Nutzer bestätigt: "ja nebel schaut gut aus."**

## Grime-Overlay-Bugfix: World.gd lud nicht mehr (2026-08-04)

Nutzer-Report "konnte nicht starten kam ein Fehler" (Screenshot). Ursache:
`_apply_grime_overlay()`s `var base_material := node.get_surface_override_
material(...)` löste die schon bekannte GDScript-Variant-Inferenz-Falle
aus (`node` ist als generischer `Node` deklariert, `:=` kann den Rückgabe-
typ darüber nicht ableiten) — `World.gd` lud dadurch komplett nicht,
`World.tscn`s Root-Node fiel auf den nackten `Node3D`-Basistyp zurück
(Folgefehler: `_draw_fog()`s `FOG_CELL_SIZE`-Zugriff schlug fehl, weil
die eigene Konstante ohne Skript nicht existiert). Fix: `base_material`
explizit als `Material` typisiert. **Vom Nutzer bestätigt, danach lief
es:** "besser so schaut ganz gut aus" (Grime-Overlay + SSAO zusammen).

## Grime-Overlay-Shader + SSAO als A/B-Vergleich gebaut (2026-08-04)

Nutzerfrage nach den ersten flach eingefärbten Blender-Modellen: reicht
ein Shader, oder braucht es mehr Mesh-Detail? Zwei Optionen gebaut statt
sich für eine zu entscheiden — Details in [`building.md`](building.md),
"Grime-Overlay-Experiment". Noch nichts final, User soll im Editor
vergleichen und sagen, welches (wenn überhaupt) bleibt.

## Systematik-Review abgeschlossen (2026-08-04)

Vollständiger Durchgang durch alle `docs/<system>.md`-Dateien (Nutzerwunsch
nach Frust über den bisherigen Screenshot-für-Screenshot-Bugfixing-Takt:
"einmal alles klären ... systematisch durch was weg kann was geändert
werden muss"), vorher Backup des ganzen `koop-game`-Ordners angelegt
(`koop-game-backup-2026-08-04.tar.gz`). Reihenfolge: World → Building →
Survivor → Zombies/Bandits → Vehicle → Recruitment/Scavenging → Trading →
Zones → Walls → Base → Networking → Save/Load → Loading → Commander →
Mechanics-Review (bewusst unangetastet, historischer Snapshot) →
Settings/Gameplay-Walkthrough. Zwei echte Code-Fixe gefunden (Fahrzeug-
Lärm bei leerem Tank, Mauer-HP bei Catch-up/Speicherstand), der Rest
waren veraltete Doku-Stellen (Bekannte-Grenzen-Bullets, die ein längst
behobenes Problem noch als offen listeten, oder Zahlen/Aufzählungen, die
nach der Treibstoff- bzw. Universal-Buch-Migration nicht mitaktualisiert
wurden) — jeweils einzeln mit dem Nutzer abgestimmt, bevor etwas geändert
wurde. `commander.md` bekam zusätzlich einen fehlenden Fallunterschei-
dungs-Schritt (Start-Basis-Wahl) in der `_select_at()`-Reihenfolge
nachgetragen, `gameplay-walkthrough.md` seine Ressourcenzahl/-liste
korrigiert.

## Systematik-Review: base.md Ressourcenzahl/Lagerkapazität korrigiert (2026-08-04)

Drei veraltete Zahlen in `base.md` gefunden: fehlendes `"fuel": 20` im
`START_RESOURCES`-Codeschnipsel (Treibstoffsystem kam heute dazu, `base.md`
wurde dabei nicht mitaktualisiert), Ressourcenarten-Zahl entsprechend
falsch (13/16 statt korrekt 14), und die "Bekannte Grenzen"-Zeile behauptete
noch `BASE_STORAGE_CAPACITY` sei "temporär auf 300", obwohl der Code das
schon am 2026-08-03 auf 150 zurückgebaut hatte. Alle drei nur Doku, kein
Code betroffen.

## Mauer-HP bei Catch-up + Spielstand behoben (2026-08-04, Systematik-Review)

`_catch_up_wall()` und `_collect_save_data()`/`_load_game_state()` haben
`Wall.hp` bisher nie mitgenommen — bei jedem Laden eines Spielstands
wurden dadurch ALLE beschädigten Mauern/Tore stillschweigend komplett
geheilt (nicht nur, wie ursprünglich in `walls.md` vermerkt, eine reine
Catch-up-Lücke für spät beitretende Peers). `Wall.hp` jetzt in beiden
Pfaden enthalten, `Wall._ready()` überschreibt einen von außen
gesetzten Wert nicht mehr (neuer Sentinel `hp == -1` statt vorherigem
unconditional Reset). Details in [`walls.md`](walls.md). Noch nicht vom
Nutzer getestet.

## Systematik-Review: veraltete "Bekannte Grenzen"-Bullets bereinigt (2026-08-04)

Drei Doku-Stellen gefunden und korrigiert, alle vom selben Muster —
ein "Bekannte Grenzen"-Bullet behauptete weiterhin eine Einschränkung,
die durch einen späteren Fix im selben oder verlinkten Dokument längst
behoben war, nur nie nachträglich gestrichen. Kein Code betroffen.

- **`recruitment.md`**: "genau ein rekrutierbares Gebäude, kein
  Zufallsmechanismus" widersprach der direkt darüberstehenden
  "Erweiterten Rekrutierung" (Plünder-Zufallschance + Schutzsuchende).
- **`zones.md`**: "Kein Außenposten-Sonderfall — noch nicht umgesetzt"
  war von vor 2026-08-01, Außenposten existieren seitdem als eigener
  Bautyp.
- **`building.md`**: "Außenposten: 'Rasten/Schlafen' nicht umgesetzt"
  widersprach dem im selben Dokument beschriebenen Fund-5-Fix
  (`Survivor._handle_resting()` akzeptiert seit 2026-08-04 auch einen
  Außenposten als Rastpunkt).

## Fahrzeug-Lärm bei leerem Tank behoben (2026-08-04, Systematik-Review)

`Vehicle._handle_noise()` prüfte nur, ob noch Wegpunkte offen sind, nicht
ob sich das Fahrzeug tatsächlich bewegt — bei leerem Tank bleibt die
Warteschlange bewusst gefüllt (fährt automatisch weiter, sobald wieder
Treibstoff da ist), wodurch ein liegengebliebenes, komplett stehendes
Fahrzeug trotzdem weiter alle 2s Zombies alarmiert hätte. Jetzt
zusätzlich `fuel > 0.0` geprüft. Details in [`vehicle.md`](vehicle.md),
"Treibstoff". Noch nicht vom Nutzer getestet.

## Home-Base: Kollisionsbox an echtes Modell angepasst (2026-08-04)

Nutzer-Screenshot ("base versetzt.PNG") — "Modell vs. Kollision stimmt
nicht". Ursache gefunden: `HomeBase.tscn`s Platzhalter-Box (`Vector3(3,
1.5, 3)`) war nie an das echte `startbasetest.glb`-Modell angepasst
worden — die reale glTF-Bounding-Box ist `6,4×6,93×6,4m`, mehr als
doppelt so groß in jeder Achse. Die frühere "Größenkorrektur" (siehe
[`base.md`](base.md)) betraf nur den visuellen Maßstab, nie die
Kollisionsbox selbst. `BoxMesh`/`BoxShape3D` in `HomeBase.tscn` jetzt auf
die echten Maße gesetzt, neue `World.HOME_BASE_GROUND_Y := 3.464`
ersetzt den alten festen Wert `0.75` beim Spawnen einer neuen Home-Base
(behebt nebenbei ein leichtes Schweben). Details in [`base.md`](base.md).
Noch nicht vom Nutzer getestet.

## Apotheke: echtes Asset + genereller Y-Ausgleich-Fix (2026-08-04)

Drittes vom Nutzer geliefertes Gebäude-Asset (`assets/Ahpoteke.glb`).
Maße aus der glTF-Bounding-Box (7,1×8,2×6,1m) — Grundfläche trifft den
Checklisten-Wert fast exakt, Höhe deutlich drüber (gleiches Muster wie
Wohnhaus). Wichtiger Nebenfund: der Modell-Ursprung dieses Assets liegt
NICHT nahe der Basis (Y≈−7,17 relativ zur Unterkante, verglichen mit
Wohnhaus/Supermarkt nahe 0) — die bisherige Y-Ausgleich-Formel hätte das
Gebäude über 7m im Boden versenkt. Neue `World._model_min_y()` liest die
tatsächliche Unterkante jedes Modells aus der Mesh-AABB aus, statt einen
Ursprung an der Basis anzunehmen — funktioniert jetzt für JEDEN
Modell-Ursprung, Wohnhaus/Supermarkt profitieren automatisch mit (der
Supermarkt hatte denselben, nur viel kleineren Effekt — 22cm statt 7m —
und ist damit nebenbei mitbehoben). Details in [`building.md`](building.md),
"Apotheke". Noch nicht vom Nutzer im Spiel gesichtet.

## Bildlook: Entsättigung für Apokalypse-Stil (2026-08-04)

Nutzerfrage nach Shader-Möglichkeiten für mehr "Apokalypsen-Style" —
erste, günstigste Stufe: Godots eingebaute `Environment`-Adjustments
(Sättigung 0.55, Kontrast 1.15, Helligkeit 0.95) auf der globalen
Environment-Resource aktiviert, kein eigener Shader-Code nötig. Details +
weitere mögliche Ausbaustufen (Nebel, Grime-Shader, Postprocessing) in
[`world.md`](world.md), "Bildlook". Noch nicht vom Nutzer gesichtet.

## Erste Gebäude-Varianten eingebaut (2026-08-04)

Nutzer hat drei Wohnhaus-Varianten (`wohnhausVar2.glb`/`wohnhausVar3.glb`/
`wohnhausVar3kleinesdach.glb`, reine Farb-/Dach-Unterschiede) und zwei
Supermarkt-Varianten (`supermarkVar1.glb`/`supermarkVar2.glb`) geliefert —
erste echte Nutzung der bereits am 2026-08-04 gebauten `"model_paths"`-
Infrastruktur (siehe `docs/building.md`, "Gebäude-Varianten pro Typ").
Beide `BUILDING_TYPES`-Einträge entsprechend umgestellt, Wohnhaus-
`procedural_chance` 0.5→0.3 gesenkt (bei vier echten Varianten würde ein
weiterhin hoher Prozedural-Anteil die neue Abwechslung verwässern). Noch
nicht vom Nutzer im Spiel gesichtet.

## Außenposten als Rastpunkt (Fund 5 der Systematik-Review, 2026-08-04)

Aus der Survivor-Review: die Vision nennt Außenposten explizit als
Rastpunkt ("nur zum Rasten/Schlafen der Trupps"), umgesetzt wurde beim
ursprünglichen Außenposten-Bau (2026-08-01) aber nur das Zwischenlagern —
mit dem expliziten Vorbehalt, Rasten bräuchte erst ein Müdigkeits-/
Bedürfnissystem, das es damals noch nicht gab. Dieses System kam einen
Tag später (Betten), der Außenposten wurde dabei nie nachgerüstet, bis
jetzt. `Survivor._handle_resting()` akzeptiert seitdem auch einen eigenen
Außenposten (`_find_nearby_rest_point()`, gleicher Radius/gleiche Rate wie
ein Bett). Details in [`survivor.md`](survivor.md), "Bedürfnisse:
Müdigkeit + Moral". Noch nicht vom Nutzer getestet.

## Gebäude-HP/Abriss-Ertrag größenabhängig + Start-Basis-Loot gutgeschrieben (2026-08-04)

Fund 3+4 aus der Systematik-Review abgeschlossen. Fund 3: `Building.
MAX_HP`/`YIELD` (100 HP, 20 Stein/10 Ziegel) waren für JEDE Vorlage
gleich, unabhängig von der Größe — jetzt aus dem tatsächlichen
Gebäude-Volumen berechnet (`max_hp`/`YIELD` als Instanzfelder statt
Konstanten, an der kleinsten echten Gebäudegröße/Tankstelle verankert,
größere Gebäude skalieren linear hoch). Fund 4: das als Start-Basis
gewählte Gebäude verlor seinen eigenen, längst gewürfelten Loot einfach
beim Markieren als geplündert — wird jetzt direkt der neuen Home-Base
gutgeschrieben. Details in [`building.md`](building.md), "Abreißen", und
[`zones.md`](zones.md), "Start-Basis wählen". Noch nicht vom Nutzer
getestet.

## Lager-Kapazität + Ausbau-Bauzeit rekalibriert (2026-08-04)

Fund aus der systematischen Review (Ausbauten/`building.md`): `STORAGE_
CAPACITY_PER_VOLUME` (40.0) und `STORAGE_CONSTRUCTION_WORK_PER_VOLUME`
(1.5) waren noch auf die alten Platzhalter-Boxen (~14-23 m³) kalibriert —
der eigene Code-Kommentar von damals sagte explizit "muss neu kalibriert
werden, sobald echte Assets die Platzhalter ersetzen". Beim echten
Supermarkt (927 m³) hätte das ein Lager mit 37.080 Kapazität ergeben
(Home-Base-Basiskapazität: 150) — kompletter Balance-Bruch. Zurück auf
~1:1 (m³ ≈ Kapazität), `40.0 → 1.0`. Gleichzeitig (Nutzerwunsch, "kann man
skalieren"): Krankenstation/Werkstatt/Bett hatten bisher eine FESTE
Bauzeit unabhängig von der Gebäudegröße, nur das Lager skalierte — jetzt
skalieren alle vier mit dem Gebäude-Volumen (neue `BED_/MEDICAL_STATION_/
WORKSHOP_CONSTRUCTION_WORK_PER_VOLUME`-Konstanten, Lager-Bauzeit ebenfalls
neu kalibriert 1.5→0.05). Nur die Bauzeit skaliert, nicht die
Ressourcenkosten. Details in [`building.md`](building.md), "Lager"/
"Ausbauen". Noch nicht vom Nutzer getestet.

## Zwei Bugs nach Backup behoben: Gebäude-Rotation + Start-Base-Abstand (2026-08-04)

Nutzer-Screenshots (`bilder/falsche ausrichtung.PNG`,
`bilder/startbasevfehler.PNG`) nach dem Supermarkt-Einbau, dann
Backup (`KoopGame/koop-game-backup-2026-08-04.tar.gz`) und systematischer
Review-Einstieg (siehe `Infos/05 Assets im Spiel...`, "GRÖSSEN-FRAGE
ENDGÜLTIG GEKLÄRT" für die parallel geklärte Größen-Diskussion).

1. **Gebäude-Rotation:** Gebäude bekamen nie eine `rotation.y`, dieselbe
   Modell-Ausrichtung landete auf jeder Blockkante gleich. Jetzt pro Slot
   aus der Blender-Achsen-Konvention abgeleitet (0°/180°/±90° je nach
   Süd/Nord/West/Ost-Kante), dreht Mesh+Collision+Model gemeinsam auf dem
   Building-Node. Details in [`world.md`](world.md), "Gebäude-Rotation".
2. **Start-Base-Abstand:** `BASE_CHOICE_HOME_OFFSET`/`_SURVIVOR_OFFSET`
   waren feste 4,5m/2,0m ab Gebäude-Mittelpunkt — bei einem großen Gebäude
   (Supermarkt, 9m halbe Breite) landete die Home-Base buchstäblich im
   Gebäude drin. Jetzt zusätzlich um die halbe Gebäude-DIAGONALE erweitert
   (`request_choose_start_base()`, liest die Mesh-Box-Größe aus) —
   funktioniert unabhängig von der tatsächlichen Gebäudegröße und davon,
   in welche Richtung "away" zeigt.

Beide **noch nicht vom Nutzer getestet**, insbesondere die genaue
Rotationsrichtung (West/Ost könnten vertauscht sein, siehe `world.md`).

## Straßenabstand tiefenabhängig + kompaktere Stadt (2026-08-04)

Direkte Reaktion auf den Supermarkt-Screenshot (Front stand fast auf der
Straße) UND das Nutzer-Feedback "das Spiel ist 3x größer als IFZ" —
Nutzer-Entscheidung nach Rückfrage: Gebäude bleiben bei ihren echten
Maßen, Stadt wird stattdessen INSGESAMT kompakter gepackt (nicht: Assets
neu skalieren). `BUILDING_ROW_INSET` (fest, 5.0) ersetzt durch
tiefenabhängiges `BUILDING_STREET_MARGIN` (1.5, plus halbe Gebäudetiefe) —
behebt das Supermarkt-Problem UND passt sich automatisch an jede künftige
Gebäudetiefe an. `BUILDING_MIN_SPACING` 10m→5m halbiert (Abstand
INNERHALB einer Reihe, Straßenbreite selbst bleibt unverändert — an echte
Straßen-Kachel-Assets gebunden). `MAX_BUILDING_SLOT_SPAN` von 3 auf 5
angehoben, damit der Supermarkt bei der kleineren Spacing weiterhin
korrekt (nicht zu knapp) reserviert wird. Gebäudezahl pro Zone bewusst
NICHT erhöht (siehe eigener Kommentar im Code — frühere Netzwerk-
Absturzursache bei 1750 Gebäuden, separates Risiko). Details in
[`world.md`](world.md), "Straßenabstand tiefenabhängig + kompaktere
Stadt". Noch nicht vom Nutzer getestet.

## Supermarkt: echtes Asset (2026-08-04)

Zweites vom Nutzer geliefertes Gebäude-Asset (`assets/supermarkttest.glb`,
noch früher Entwurf ohne Material/Farbe, "nur mal grob Fenster Türen zum
angucken"). Datei lag zunächst wieder im Workspace-Root statt
`koop-game/assets/`, verschoben (wie schon bei Ziegelhaufen/Steinhaufen/
Baum/Feld). Maße aus der echten glTF-Bounding-Box (18,1×4,2×12,2m) treffen
die Vision-Zielwerte praktisch exakt — genau der Größenbereich, für den
das direkt zuvor gebaute Mehrfach-Reihenplätze-System gedacht ist. Eine
kleine, noch offene Unsauberkeit: Modell-Ursprung liegt nicht exakt an der
Unterkante (ca. 22cm Versinken), bei einem finalen Modell in Blender zu
beheben statt im Code. Details in [`building.md`](building.md),
"Supermarkt". Noch nicht vom Nutzer im Spiel gesichtet.

## Mehrfach-Reihenplätze für breite Gebäudetypen (2026-08-04)

Nutzerfrage beim Blender-Modellieren: Supermarkt ist laut Vision-
Checkliste 18×12m, aber ein Straßen-Reihenplatz hat nur 10m Abstand zum
nächsten (`BUILDING_MIN_SPACING`) — bekannte, bisher bewusst offen
gelassene Lücke (siehe `Infos/05 Assets im Spiel (aktueller Stand).md`).
Statt den Nutzer das Asset kleiner modellieren zu lassen: `World.
_generate_street_slots()` liefert jetzt strukturierte Slots mit
Reihen-Zugehörigkeit (`row_id`/`row_index`/`along_x`), `_generate_city_
zone()` reserviert für Typen, deren Breite entlang der Reihe
`BUILDING_MIN_SPACING` überschreitet, automatisch mehrere direkt
benachbarte Slots (`span`, aus der Template-`size` abgeleitet, kein
manuelles Flag pro Typ nötig). Supermarkt-Platzhalter schon jetzt auf die
echten 18×4,5×12m gesetzt, damit der Mechanismus am Platzhalter testbar
ist, bevor das echte Modell da ist. Details in [`world.md`](world.md),
"Mehrfach-Reihenplätze". Noch nicht vom Nutzer getestet.

## Multi-Ziel-Pfadfindung beim Plündern (2026-08-04)

Zweites ohne-Rückfrage-machbares Item aus derselben Reihenfolge-Empfehlung.
Shift-Klick auf weitere durchsuchbare Gebäude hängt sie als Route an, statt
den laufenden Suchauftrag zu ersetzen — `Survivor.order_search()` bekommt
einen `additive`-Parameter (gleiches Konzept wie bei `order_move()`), neue
`_search_queue`, `_finish_search()` läuft über eine neue
`_advance_search_queue_or_return_to_base()` direkt zum nächsten Ziel
weiter statt immer erst zur Basis zurückzukehren. Details in
[`scavenging.md`](scavenging.md), "Multi-Ziel-Pfadfindung". Noch nicht vom
Nutzer getestet.

## Treibstoff für Fahrzeuge (2026-08-04)

Nutzerwunsch ("mach das fertig wo du dir sicher bist das soll rein") — aus
der Reihenfolge-Empfehlung in `Infos/07 Backlog-Umsetzungspläne.md` als
nächstes ohne-Rückfrage-machbares Item umgesetzt. `Vehicle.gd` bekommt eine
neue Ressource `"fuel"` (float, pro Typ unterschiedliche Kapazität/
Verbrauch, siehe `VEHICLE_STATS`), Verbrauch proportional zur gefahrenen
Strecke, automatisches Auftanken in Reichweite der eigenen Home-Base
(exakt das `_handle_eating()`-Intervall-Muster). Tankstelle liefert jetzt
`fuel` statt `food` als Hauptloot. Details in [`vehicle.md`](vehicle.md),
"Treibstoff". Noch nicht vom Nutzer getestet.

## Banditen als echte NPC-Gegner (2026-08-04)

Nutzerentscheidung nach Rückfrage, welches offene Backlog-Item als Nächstes
dran ist (Alternative wäre Durst als drittes Grundbedürfnis gewesen —
bewusst verworfen, siehe unten). Aus dem Ideen-Backlog
(`Infos/01 Architektur.md`, "Fraktionen"): "Banditen-Fraktion als echte
NPC-Gegner mit eigenen Lagern, die nachspawnen" — bisher gab es nur das
"Banditen-Restloot" (reine Loot-Mechanik an bestehenden Gebäuden, bleibt
unverändert bestehen).

Neue Entities `Bandit.gd`/`BanditHideout.gd`
(`scenes/entities/bandit/`), gleiches Grundmuster wie Zombie/Zombie-Nest,
aber mit bewussten Unterschieden: Fernkampf statt Nahkampf, kein
automatischer Gegenschaden, Hideout gekappt auf 3 gleichzeitig lebende
Bandits (statt unbegrenzt wie das Zombie-Nest), Hideout-Zerstörung ist
permanent + gibt einmaligen Bonus-Loot. Drei Hideouts in der Wildnis
verteilt (`BANDIT_HIDEOUT_COUNT`). Klick-Angriff, Wachposten-
Autoverteidigung, Karten-/Minimap-Anzeige alle um Bandits erweitert. Volle
Details, Konstanten und die eine bewusste Lücke (Bandits selbst werden
nicht gespeichert, nur die Hideouts) in [`bandits.md`](bandits.md). Noch
nicht vom Nutzer getestet.

**Verworfen: Durst als drittes Grundbedürfnis.** Nächster Punkt der
Reihenfolge-Empfehlung (`Infos/07 Backlog-Umsetzungspläne.md`) wäre Durst
gewesen — Nutzer-Einwand ("aber lohnt sich durst") direkt eingesehen: wäre
mechanisch praktisch identisch zu Hunger gewesen (gleicher Decay-/
Regenerations-Loop, nur ein anderes Label), hätte nur eine 17. Ressourcenart
in ein laut Nutzer-Feedback schon "zu volles" Panel gebracht, ohne neue
Entscheidung fürs Spiel. Bleibt vorerst nicht umgesetzt.

## Feld-Ghost-Fix + Skalierung Baum/Stein/Ziegel (2026-08-04)

Zwei kleine Nutzer-Nachbesserungen direkt nach dem Asset-Einbau:

- **"Vorschau vom Feld ist zu klein"** — Feld nutzte beim Platzieren
  bisher generisch die kleine 1,5³-Wachposten-Ghost-Box. Neue, passend
  große `World._field_ghost_mesh` (`FIELD_GHOST_SIZE := Vector3(2.5, 0.2,
  2.5)`), gleiches Muster wie beim Wachturm. Details in
  [`building.md`](building.md), "Felder".
- **"Steine, Bäume, Ziegel bisschen größer machen aber nicht viel"** —
  `scale = Vector3(1.2, 1.2, 1.2)` (+20 %) auf dem jeweiligen `Model`-
  Node, Kollisionsformen proportional mitskaliert. Funktioniert ohne
  Y-Ausgleich, weil die Modelle an ihrer Basis verankert sind (Skalieren
  um den eigenen Ursprung lässt den Bodenkontakt unverändert). Feld
  bewusst nicht mitskaliert. Details in [`survivor.md`](survivor.md),
  "Ressourcen abbauen".

Beides noch nicht vom Nutzer im Spiel gesichtet.

## Steinhaufen, Baum, Feld: echte Assets (2026-08-04)

Drei weitere vom Nutzer gelieferte Assets, gleiches Muster wie beim
Ziegelhaufen (Model-Kind-Node + Y-Ausgleich, Platzhalter unsichtbar für
Kollision):

- **Steinhaufen** (`assets/steinehaufen.glb`) — mehrere Einzelstein-
  Meshes, `StonePile._update_color()` färbt jetzt alle statt nur
  `RockBig`/`RockSmall`.
- **Baum** (`assets/tannenbaum.glb`) — ein zusammenhängendes Modell statt
  der vorherigen Stamm-/Kronen-Trennung, deshalb reagiert jetzt der GANZE
  Baum auf HP/Markierung (vorher nur die Krone). `Tree._update_color()`
  entsprechend umgebaut, mit Fallback auf die alte Trunk/Foliage-Logik
  ohne Model.
- **Feld** (`assets/feld.glb`) — ersetzt die Platzhalter-Box, keine
  Skript-Änderung nötig (Field hat keine Farb-/HP-Logik). Datei lag
  zunächst wieder im falschen Ordner (Workspace-Root), verschoben.

Größen bei allen drei NICHT extra vom Nutzer bestätigt (anders als beim
Ziegelhaufen, wo ein Referenzwürfel verglichen wurde) — am jeweiligen
Platzhalter orientiert, bei Bedarf im Spiel nachjustieren. Details in
[`survivor.md`](survivor.md), "Ressourcen abbauen", und
[`building.md`](building.md), "Felder". Noch nicht im Editor gesichtet.

## Ziegelhaufen: echtes Asset (2026-08-04)

Erstes vom Nutzer geliefertes Umgebungs-Prop-Asset (`assets/
ziegelhaufen.glb`, mehrere Einzelziegel-Meshes, 1,4×0,5×1,4m — passt fast
exakt zur bisherigen Platzhalter-Box, keine Code-Anpassung an Maßen
nötig). `BrickPile.tscn` bekommt das Modell (gleiches Vorrang-/Y-
Ausgleich-Muster wie beim Wohnhaus), `BrickPile.gd._update_color()` färbt
jetzt alle Mesh-Kinder statt nur der Platzhalter-Box (Markierung/HP-
Abdunkeln bleiben sichtbar). Datei lag zunächst im falschen Ordner
(Workspace-Root statt `koop-game/assets/`), verschoben. Details in
[`survivor.md`](survivor.md), "Ressourcen abbauen". Noch nicht im Editor
gesichtet/bestätigt.

## Aktive Rekrutierungs-Aktion: "Ruf aussenden" (2026-08-04)

Ergänzung zum passiven Schutzsuchenden-Timer — neuer Button im
Einheiten-Tab, `World.request_active_recruit_call()` erzwingt einen
Schutzsuchenden-Spawn-Versuch (überspringt nur den Zufalls-Würfel,
`REFUGEE_MAX_ACTIVE`-Deckel gilt weiterhin), eigener 90s-Cooldown PRO
SPIELER (`_active_recruit_call_cooldowns`, rein host-seitig, kein
UI-Countdown — Klick während Cooldown gibt Statusmeldung statt stiller
Ablehnung). `_maybe_spawn_refugee()` hat dafür einen neuen `force`-
Parameter bekommen. Details in [`recruitment.md`](recruitment.md),
"Aktive Rekrutierungs-Aktion". Noch nicht vom Nutzer getestet.

## Dritter Zombie-Typ: Runner (2026-08-04)

Nutzerwunsch ("mach weiter" nach dem Wachposten-Label, Vorschlag "mehr
Zombie-Typen" angenommen) — schneller, zerbrechlicher dritter Typ neben
Standard/Brute: `RUNNER_MAX_HP := 20`, `RUNNER_CHASE_SPEED := 7.5`
(deutlich über `Survivor.MOVE_SPEED := 4.0`, gefährlich trotz wenig HP),
`RUNNER_ATTACK_DAMAGE := 6`. Neue Szene `ZombieRunner.tscn` (Kapsel 1,5m
× 0,25m), blasses Gelbgrün. Beim Umsetzen `Zombie.is_brute: bool` auf ein
echtes `ZombieType`-Enum umgestellt (NORMAL/BRUTE/RUNNER) — ab dem
dritten Typ sauberer als ein zweiter Bool-Flag, betrifft `Zombie.gd`
sowie alle Spawn-/Catch-up-/Speicherstand-Stellen in `World.gd`. Runner
mischt sich wie Brute nur in Horde-Nächte (`HORDE_RUNNER_COUNT := 2`,
`BLOOD_MOON_RUNNER_COUNT := 6`), nicht ins normale Wandern/Nest-
Nachspawnen. Details in [`zombies.md`](zombies.md), "Zombie-Typen".
Speicherstand-Fallback für alte `is_brute`-Spielstände eingebaut
(`.get("zombie_type", 0)`). Noch nicht vom Nutzer getestet.

## "Kein Arbeiter zugewiesen"-Label am Wachposten (2026-08-04)

Sichtbares Feedback statt nur des unauffälligen Nicht-Feuerns — neuer
`Label3D`-Kind-Node in `GuardPost.tscn`, sichtbar über
`GuardPost._update_no_worker_label()` (`built and worker_count <= 0`),
aufgerufen aus `_sync_worker_count()` (erreicht alle Peers) und
`_set_built_visual()`. Erbt die bestehende, akzeptierte
`worker_count`-Catch-up-Lücke (spät beitretender Peer sieht es u. U. kurz
falsch). Details in [`building.md`](building.md), "Kein Arbeiter
zugewiesen'-Label". Label-Position über dem Wachturm-Modell ist eine
Schätzung, noch nicht visuell bestätigt.

## Universal-Buch-Migration (2026-08-04)

Nutzer-Entscheidung aus der IFZ-Gap-Analyse umgesetzt: fünf getrennte
`book_<id>`-Ressourcen (eine pro Crafting-Rezept/Gebäude-Ausbaustufe)
ersetzt durch eine einzige `World.RESEARCH_BOOK_RESOURCE :=
"book_research"` — schaltet jede Freischaltung gleichermaßen frei.
Betroffen: `RESOURCE_DISPLAY_NAMES`/`RESOURCE_CATEGORIES` (13 statt 17
Ressourcenarten insgesamt), Zombie-Buch-Drop, Gebäude-Nebenloot,
Crafting-/Erweiterte-Krankenstation-UI, `request_research()`. Details in
[`building.md`](building.md), "Universal-Buch-Migration". Keine
Rückwärtskompatibilität für alte Spielstände mit den fünf alten Buch-
Ressourcen eingebaut (Prototyp-Stand). Noch nicht vom Nutzer getestet.

## Prozedurale Wohnhäuser für die "Masse" (2026-08-04)

Nutzer-Entscheidung nach der IFZ-Icons-Recherche: Blender-Arbeit
aufteilen — Nutzer modelliert die speziellen POI-Gebäude von Hand, die
zahlreiche "Masse" (Wohnhäuser) wird stattdessen prozedural generiert
(Box-Körper + `PrismMesh`-Satteldach, zufällige Maße/Farbtöne). Neues
`"procedural_chance"`-Feld in `BUILDING_TYPES` (Wohnhaus: 0.5 — halb
echtes `wohnhaustest.glb`, halb generiert), `World._random_house_proc_
params()`/`_build_procedural_house()`, neues `Building.proc_params`-Feld
(voll Speicherstand-/Catch-up-fähig, gleiches Muster wie `model_path`).
Details in [`building.md`](building.md), "Prozedurale 'Masse'-Häuser".
Noch nicht vom Nutzer getestet.

## Gebäude-Varianten-Infrastruktur (2026-08-04)

Nutzerwunsch ("brauchen die wohnhäuser variationen von den gebäuden für
mehr abwechslung wie bei IFZ") — `World._pick_model_path()` neu:
`BUILDING_TYPES`-Einträge können jetzt optional `"model_paths"` (Array)
statt nur `"model_path"` (String) haben, pro Instanz wird dann zufällig
eine Variante gewählt. Rein additive Infrastruktur, aktuell nutzt noch
kein Eintrag es (Wohnhaus hat weiterhin nur ein Modell) — für den Nutzer
beim nächsten Blender-Export bereit, ohne weitere Code-Änderung. Details
in [`building.md`](building.md), "Gebäude-Varianten pro Typ". Empfehlung:
erst alle 14 Gebäudetypen einmal abdecken, dann Varianten ergänzen.

## Zivilisten-Konzept: neue Rekruten starten unzugewiesen (2026-08-04)

Nutzerwunsch nach der IFZ-Gap-Analyse (siehe `Infos/06 Infection Free Zone
Recherche.md`, `Infos/01 Architektur.md` "Ideen-Backlog") — leichte Variante
des dort diskutierten Zivilisten-Konzepts, ohne eigene Housing-Kapazität.
Neue `Survivor.TroopType.UNASSIGNED`: jeder neue Rekrut (alle drei
Rekrutierungs-Kanäle, NICHT die Start-Trupps) startet damit — kann sich
nicht bewegen/einsteigen/kämpfen/bauen (`order_move()`/
`order_enter_vehicle()` lehnen explizit ab, die übrigen Befehle schon über
ihre bestehenden FIELD-/BUILD-exklusiven Prüfungen), steht deutlich blasser
eingefärbt in der Einheiten-Liste, bis der Spieler ihn per "→Feld"/"→Bau"
manuell zuweist. Zusätzlich ein neues Auto-Zuweisungs-Profil-Dropdown im
Einheiten-Tab (`World.RECRUIT_POLICIES`) pro Spieler: Manuell (Standard),
automatisch Feldtrupp, automatisch Baueinheit, oder automatisch zum ersten
eigenen Wachposten schicken (`Survivor.order_station()`, kein Wachposten
vorhanden → bleibt lieber unzugewiesen statt still zum Feldtrupp zu
werden). `GuardPost._find_idle_trupp()` (manueller "Trupp anfordern"-
Button) überspringt UNASSIGNED-Trupps jetzt ebenfalls. Details in
[`recruitment.md`](recruitment.md), "Zivilisten-Konzept". Noch nicht vom
Nutzer getestet.

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

## Weitere Nutzerwünsche direkt im Anschluss (2026-08-03)

Vier kleinere Punkte im selben Zug nach dem Koop-Testdurchlauf:

- **HUD-Zeile oben links entfernt** ("das mit trupp 1 hp 100 kann weg")
  — die Pro-Trupp-Statuszeile in `_update_hud()` war redundant zur
  Einheiten-Liste/zum Trupp-Detailfenster. Fahrzeug-Ausstiegs-Hinweis
  ("F: Aussteigen") bleibt, steht nirgendwo sonst.
- **Deutlich mehr Gebäude/Bäume/Ressourcen für Benchmark-Zwecke**
  ("in die stadt viel mehr gebäude zum benchmark und mehr bäume im wald
  und allgemein mehr ressourcen") — `BUILDINGS_PER_LARGE_ZONE`/`_SMALL_ZONE`
  100/50 → 300/150 (Summe 1050 statt 350), `TREES_PER_FOREST_ZONE` 40 → 80,
  `TREES_TOTAL`/`CAR_WRECKS_TOTAL`/`STONE_PILES_TOTAL`/`BRICK_PILES_TOTAL`
  jeweils verdoppelt (400/160/200/200). Reiner Stresstest, keine
  Balancing-Entscheidung — Performance danach noch nicht gemessen (siehe
  [`benchmarks.md`](benchmarks.md) für künftige Messwerte).
- **Kamera-Zoom nachjustiert** ("auf standard machen und bisschen mehr
  rauszoomen") — `ZOOM_MAX` 60→80, Start-`_zoom_distance` 12→25. Details
  in [`world.md`](world.md), "Kamera-Zoom-Bereich".
- **Kartenansicht zoombar** — siehe [`world.md`](world.md), "Kartenansicht
  zoombar", inkl. vollem Controller-Support (LB/RB zoomen die Karte statt
  der 3D-Kamera, solange sie offen ist).

**Vom Nutzer bestätigt (2026-08-03):** "map passt, fps gehen mit den
häusern auch, hud passt auch sehr gut" — Kartenzoom, Benchmark-Zahlen
(FPS unauffällig trotz 1050 Gebäude) und die entfernte HUD-Zeile sind
damit alle drei bestätigt. Gamepad-Bedienung der Kartenansicht (LB/RB/A/B)
dabei nicht explizit erwähnt, bleibt offen (siehe `pending-tests.md`).
Kamera-Zoom-Nachjustierung nicht separat erwähnt, vermutlich im "map
passt" mit eingeschlossen.

## Erster echter Koop-Testdurchlauf: großteils bestätigt, ein Fix (2026-08-03)

Nutzer hat den kompletten 2026-08-03-Abend-Batch zu zweit im Koop
getestet. Bestätigt (Details in `pending-tests.md`, jeweiliger Abschnitt):
Nachjoinen, Speichern/Laden+Rejoin, Trupp-Art-Wechsel als Nicht-Host-
Spieler, Fahrzeug-Mitfahrer (zwei Trupps ein-/ausgestiegen), Bauen ohne
Zonen-Restriktion, Kartenansicht-Legende. Banditen-Restloot und die zehn
neuen Gebäudetypen noch nicht mitgetestet (brauchen Zeit/Zufall).

**Ein echter Fund:** Formation bei Gruppenbefehlen wirkte "zu nah
zusammen" — auf Anführer-plus-Kreis-Formation umgestellt (siehe
[`commander.md`](commander.md), "Formation").

**Zwei Ideen für später notiert** (nicht umgesetzt, siehe Roadmap-Memory):
Markier-Baumodus mit skalierender Bauzeit je nach Anzahl Bautrupps, und
eine zoombare Kartenansicht.

## Gamepad-Bugfixes nach erstem echten Test (2026-08-03, Nutzer-Report mit Screenshot + PS5-Controller)

Erster echter Test der neuen Gamepad-Steuerung (siehe unten) — zwei echte
Probleme gefunden und behoben:

1. **Spiel startete gar nicht** — `var viewport_size := get_viewport().size`
   ließ sich nicht typisieren (bekannte GDScript-Variant-Inferenz-Falle,
   siehe `docs/ARCHITECTURE.md`), Parser-Fehler blockierte den kompletten
   Start. Fix: explizit `Vector2i` typisiert.
2. **"Konnte den Controller im Hauptmenü nicht benutzen"** — die
   Gamepad-Logik lebte komplett in `World.gd`, funktionierte also erst
   NACH dem Hauptmenü/der Lobby, die man ohne Maus/Tastatur nie erreichen
   konnte. Fix: Cursor-Bewegung + A/B-Klicks in ein neues Autoload
   `autoloads/GamepadCursor.gd` ausgelagert (dauerhaft unter `/root`,
   unabhängig vom Szenenwechsel) — MainMenu/Lobby/World funktionieren
   dadurch jetzt alle automatisch mit Controller. `World.gd` behält nur
   noch den weltspezifischen Teil (Kamera-Rotation/-Zoom, Pause/
   Kartenansicht/Fahrzeug-Ausstieg).

Details im Bugfix-Kasten in [`world.md`](world.md), "Gamepad-Steuerung".
**Noch nicht erneut vom Nutzer getestet.**

## Gamepad-Steuerung + Kartenansicht-Legende ergänzt (2026-08-03)

Zwei weitere Nutzerwünsche im selben Zug: **volle Gamepad-Steuerung**
("controller und steamdeck support... das können wir jetzt machen", Freund
mit ROG Ally soll mittesten können) — Kern-Trick ist ein virtueller Cursor
über `Input.warp_mouse()` + synthetisierte Maus-Klicks über
`Input.parse_input_event()`, dadurch reagieren ALLE bestehenden
mausbasierten Systeme (Welt-Auswahl, Bauen, UI-Buttons/Tabs) unverändert,
ganz ohne eigene Gamepad-Menünavigation. Komplett additiv, nur aktiv mit
angeschlossenem Gamepad. Kontrollgruppen (1-9) bewusst nicht per Gamepad
belegt (zu wenig Tasten). Details in [`world.md`](world.md),
"Gamepad-Steuerung".

**Kartenansicht-Legende + Gebäude-Farbcode** ("färbe die gebäude typen ein
zu den jeweiligen lootarten, krankenhaus heilung grün etc.") — unbesetzte
Gebäude zeigen jetzt eine von vier Loot-Kategorie-Farben (Nahrung/Medizin/
Ausrüstung/Bücher) statt eines einheitlichen Grautons, neues Legende-Panel
in der großen Kartenansicht erklärt die Farben. Bewusst nur in der großen
Ansicht, nicht auf der Minimap (zu wenig Platz). Details ebenfalls in
[`world.md`](world.md).

**Beides noch nicht vom Nutzer getestet** — Gamepad-Test braucht echte
Controller-Hardware.

## Zehn weitere Gebäudetypen ergänzt (2026-08-03, Vision-Gap-Analyse-Nachtrag)

Nutzerwunsch nach der Vision-Gap-Analyse: "die 10 gebäude können auf
jeden Fall rein". `World.BUILDING_TYPES` von 4 auf 14 Einträge erweitert
— Klinik, Militärbasis, Privatbunker, Feuerwehrstation, Restaurant/Kneipe,
Tankstelle, Bibliothek, Universität, Garten-Center, Camping-Laden, alle
mit `main_loot`/`secondary_loot` aus ausschließlich schon existierenden
Ressourcenarten (kein neuer Ressourcentyp nötig). Bibliothek/Universität
sind der erste Gebäudetyp mit garantiertem Buch als Hauptloot. Bewusst
weiterhin NICHT übernommen: Baumarkt/Werkstatt/Auto-Werkstatt/
Elektronikgeschäft (bräuchten Ressourcenarten, die es hier nicht gibt,
oder würden die Baurohstoff-Regel verletzen). Details in
[`scavenging.md`](scavenging.md). **Noch nicht vom Nutzer getestet.**

## Echter Wachturm ergänzt (2026-08-03, Punkt 25 der Gesamtliste — LETZTER Punkt der 25er-Liste)

Neue, eigene Entität `Watchtower.gd`/`Watchtower.tscn` — rein Sichtweiten-
Funktion, kein Kampf (Vision unterscheidet das explizit vom bestehenden
`GuardPost.gd`/"Wachposten", das zufällig ein Asset namens
`wachturmtest.glb` nutzt, siehe `building.md` für die Begriffs-Klärung).
Frei platzierbar wie Wachposten/Feld/Außenposten (30 Holz + 20 Metall,
bewusst ohne Forschungsbuch-Gate). Kern-Effekt: `World._reveal_around()`
bekommt einen `radius`-Parameter, Wachtürme decken mit
`WATCHTOWER_VISION_RADIUS := 350.0` (vs. 130 für Einheiten) dauerhaft
einen deutlich größeren Kartenbereich auf. "Zombie-Früherkennung" ist
strukturell schon erfüllt (Zombies werden auf Minimap/Karte ohnehin immer
gezeichnet, unabhängig vom Fog-Stand) — der Turm liefert einfach den
Terrain-Kontext drumherum. Catch-up + Speichern/Laden vollständig, gleiches
Muster wie Außenposten. Details in [`building.md`](building.md), "Echter
Wachturm". **Noch nicht vom Nutzer getestet.**

**Damit sind alle 25 Punkte der festen Gesamtliste umgesetzt** (siehe
Roadmap-Memory) — als Nächstes braucht es entweder neues Nutzer-Feedback
(z. B. aus einem erneuten Testdurchlauf) oder eine explizite Entscheidung,
welchen der zurückgestellten Punkte (15: Survivor-Rollen; Vision-Backlog:
Stromgenerator/Garten-Anlage/Palisaden/Werkzeuge) man als Nächstes angeht.

## Erweiterte Krankenstation ergänzt (2026-08-03, Punkt 24 der Gesamtliste)

Forschungsbücher erweitert: schalten jetzt auch Gebäude-Ausbaustufen frei,
nicht mehr nur die vier Crafting-Rezepte aus Punkt 13. Neues Buch
"Medizinische Praxis" (`book_medical_upgrade`, droppt wie die anderen vier)
schaltet über dasselbe `HomeBase.unlocked_recipes`-Dictionary eine
Erweiterte-Krankenstation-Ausbaustufe frei (`MedicalStation.is_advanced`,
kein neuer Gebäudetyp) — kostet danach 15 Ziegel + 3 Medizin, heilt
Trupps in der Nähe mit `HEAL_RATE * 3.0` statt `* 2.0`. Eigene UI-Sektion
im "Bauen"-Tab (nicht an eine Gebäude-Auswahl gebunden, anders als die
bestehenden Ausbauen-Buttons). Bewusst NUR diese eine Ausbaustufe umgesetzt
— Stromgenerator/Garten-Anlage/Palisaden aus der Vision zurückgestellt,
Wachturm ist eigener Listenpunkt (25). Details in
[`building.md`](building.md), "Erweiterte Krankenstation". **Noch nicht
vom Nutzer getestet.**

## Banditen-Restloot ergänzt (2026-08-03, Punkt 23 der Gesamtliste)

Nächster Schritt der festen 25-Punkte-Roadmap nach dem `test.txt`-
Bugfixing-Batch: aus dem Vision-Ideenbacklog (`Infos/01 Architektur.md`)
— bereits geplünderte, unbesetzte Gebäude bekommen alle 3 Minuten
Echtzeit-Chance auf einen kleinen Restloot (Nahrung/Medizin/Munition,
3-8), golden eingefärbt, einmalig durchsuchbar, danach zurück auf normal.
Reine Loot-Mechanik, keine echten Banditen-NPCs. Details in
[`scavenging.md`](scavenging.md), "Banditen-Restloot". **Noch nicht vom
Nutzer getestet** (Erst-Test dauert mind. 3 Minuten).

## Test-Feedback-Sammlung vom Nutzer (2026-08-03 Abend, `test.txt`)

Nutzer hat einen kompletten Testdurchlauf (2 Spieler) in einer `test.txt`
zusammengefasst statt einzelner Chat-Nachrichten. Bestätigungen daraus sind
oben in den jeweiligen Abschnitten bzw. in
[`pending-tests.md`](pending-tests.md) einsortiert (Handel komplett ✅,
UI-Overhaul + Trupp-Tab ✅, Fog of War weiterhin ✅, SOS-Signal ✅,
Bett-Erholung + Fatigue/Moral-Malus ✅). Folgende **neue Bugs/Wünsche**
sind NEU und noch nicht bearbeitet:

- **Bug: Speichern/Laden geht nicht im Multiplayer** — bisher nur solo
  getestet bestätigt (siehe `save_load.md`). Noch nicht diagnostiziert.
- **Bug: Spieler können nicht nachjoinen** — späterer Beitritt (nach
  Host-Start) funktioniert nicht. Noch nicht diagnostiziert.
- **Bug: Spieler 2 konnte keine Einheiten umschalten/wechseln** — Ursache
  noch offen, evtl. Selektionslogik hart auf einen Peer verdrahtet.
- **Bug/Feature: keine unterschiedlichen Farben pro Einheit/Spieler** —
  aktuell nur Farbcodierung nach Trupp-Art (Feld/Bau), keine Spieler-Farbe.
  Nicht klar, ob "pro Spieler" oder "pro Einheit" gemeint ist — vor
  Umsetzung beim Nutzer nachfragen.
- **Bug: Einheiten in einer Gruppe greifen nur einen Zombie an** —
  Formation/Gruppen-Angriffslogik prüfen.
- **Feature-Wunsch: mehr Sitzplätze pro Fahrzeug** — aktuell strukturell
  nur ein Insasse (`owner_peer_id`).
- **Feature-Wunsch: Maus-Invertieren-Option** in den Einstellungen.
- **Design-Frage: überall bauen können** — widerspricht der bisherigen
  bewussten Zonen-Restriktion (siehe `zones.md`), vor Umsetzung mit dem
  Nutzer klären, wie weit das gehen soll.
- **Politur: Handel-UI-Panel etwas zu groß.**
- **Wunsch (evtl. schon erledigt):** "mehr Häuser in den Städten" — am
  selben Tag wurde `BUILDINGS_PER_LARGE_ZONE`/`BUILDINGS_PER_SMALL_ZONE`
  bereits von 60/30 auf 100/50 erhöht (siehe Abschnitt "Mehr Gebäude..."
  unten) — unklar ob `test.txt` vor oder nach diesem Fix geschrieben
  wurde, beim Nutzer nachfragen statt weiter zu erhöhen.

**Direkt im Anschluss bearbeitet (2026-08-03, gleiche Session):**

- **Nachjoinen + Laden im Multiplayer gefixt (gleiche Ursache):**
  `MainMenu._on_connection_succeeded()` schickte JEDEN frisch verbundenen
  Client bedingungslos nach `LOBBY`, unabhängig davon, ob der Host schon
  `IN_GAME` war — ein RPC-Broadcast beim Spielstart erreicht nur die zu dem
  Zeitpunkt schon verbundenen Peers, ein später Beitretender bekam ihn nie
  und hing für immer in der Lobby fest (Kommentar in `MainMenu.gd` bei
  `_on_solo_pressed()` behauptete fälschlich, das funktioniere schon).
  Fix: `GameManager._on_peer_connected()` (neu, `autoloads/GameManager.gd`)
  schickt jedem neu verbundenen Peer gezielt (`rpc_id`) den AKTUELLEN
  State — Client wartet jetzt in `MainMenu.gd` einfach ab, statt selbst zu
  raten. Damit landet ein später Beitretender direkt in `World.tscn`, egal
  ob der Host über "Spiel starten", Solo oder Laden dorthin kam. Zusätzlich
  einen zweiten, latenten Bug vorab gefixt: der bestehende Catch-up-Push
  (`World._spawn_for_peer()`, ausgelöst über `NetworkManager.player_connected`)
  hätte bei einem späten Beitritt genau dieselbe PUSH-vor-Node-existiert-
  Race gehabt wie der frühere Straßen-Geometrie-Bug (siehe "Straßen-
  Geometrie" oben) — als Fix zusätzlich `World.request_catch_up()` als
  PULL ergänzt (Client fragt selbst an, sobald sein eigenes `_ready()`
  läuft, gleiches Muster wie `request_city_zones()`). **Noch nicht vom
  Nutzer mit zwei Clients erneut getestet.**
- **Gruppen-Angriff verteilt sich jetzt auf mehrere Zombies:** Klick auf
  einen Zombie mit mehreren ausgewählten Einheiten gab bisher ALLEN
  Einheiten exakt dasselbe Ziel (bewusstes altes Design, "Nahkampf-
  Cluster"). Nutzer-Feedback: sollen sich aufteilen. Neue
  `World._nearby_enemies()`/`_nearest_enemy()` sammeln alle Zombies/Nester
  im 10m-Umkreis um den angeklickten Feind, jede Einheit greift jetzt den
  ihr jeweils nächsten davon an (bei nur einem Zombie in der Nähe
  unverändertes Verhalten). **Noch nicht vom Nutzer getestet.**
- **Maus-Invertieren-Einstellung ergänzt:** neue Checkbox in
  `SettingsMenu`, `SettingsManager.invert_mouse_y` (persistiert), kehrt das
  Vorzeichen der vertikalen Kamera-Neigung (Rechtsklick-Ziehen) in
  `World._unhandled_input()` um. Nur die Neigung (Y), nicht die horizontale
  Rotation — Nutzerwunsch war unspezifisch ("Maus invertieren oder selber
  was einstellen"), Standard-FPS/RTS-Interpretation gewählt. **Noch nicht
  vom Nutzer getestet.**
- **Handel-UI-Panel verkleinert:** `custom_minimum_size` der drei
  Ressourcen-Dropdowns im Handel-Tab (`GiftResourceOption` 140→110,
  `TradeOfferResourceOption`/`TradeWantResourceOption` 120→100) reduziert —
  das gemeinsame `MainTabsUI/Panel` selbst (gilt für alle fünf Tabs, laut
  Nutzer sonst überall "passt") bleibt unverändert. **Noch nicht vom
  Nutzer getestet.**
- **"Spieler 2 konnte keine Einheiten umschalten"** — erste Code-Recherche
  ergab keinen eigenen Bug in der Selektionslogik (generisch, nicht hart
  auf einen Peer verdrahtet, nur keine "nächste Einheit"-Funktion). Nutzer
  hat danach präzisiert: gemeint war **Trupp-ART umschalten (Feld↔Bau)**,
  nicht Einheiten-Selektion — siehe eigener Fund unten, echter Bug
  gefunden und behoben.
- **ECHTER BUG gefunden + behoben: Trupp-Art-Umschalten (Feld↔Bau)
  funktionierte für Nicht-Host-Spieler nie sichtbar** (Nutzer-Präzisierung:
  "spieler 2 kann die units nicht umwandeln in bau truppen").
  `Survivor.set_troop_type()` (`@rpc("any_peer", "call_local", "reliable")`)
  setzte `troop_type` bisher NUR innerhalb des `if not
  multiplayer.is_server(): return`-Gates, also ausschließlich auf der
  Host-Instanz — ohne jeden Broadcast an andere Peers. Beim Host selbst
  fiel das nie auf, weil seine eigene UI dieselbe Node-Instanz liest, die
  der Server direkt mutiert (Sonderfall: Host = Server = lokaler Spieler).
  Bei jedem NICHT-Host-Spieler blieb die eigene, lokal repräsentierte
  Kopie des Trupps für immer auf dem alten `troop_type` stehen — der
  Button-Klick änderte den Wert zwar tatsächlich serverseitig (Bautrupp-
  Fähigkeiten hätten server-seitig sogar funktioniert), aber weder Text
  ("Feld"/"Bau") noch Button-Beschriftung noch (seit dem Farb-Fix weiter
  oben) die Einheiten-Farbe aktualisierten sich je lokal — sah aus wie
  "Umschalten geht nicht". **Fix:** `Survivor._sync_state()` (der
  periodische Voll-Sync-RPC, der ohnehin schon Position/HP/Ausrüstung an
  alle Peers verteilt) überträgt jetzt zusätzlich `troop_type` als
  weiteren Parameter, self-korrigiert sich dadurch jeden Frame wie alle
  anderen Felder auch. **Noch nicht vom Nutzer mit zwei Clients erneut
  getestet.**
**Rückfrage beim Nutzer beantwortet, direkt umgesetzt:**

- **Farbe pro Einheit (nicht pro Spieler):** `Survivor._update_color()`/
  neue `_unit_base_color()` leiten den Farbton jetzt deterministisch aus
  `trupp_id` ab (goldener Schnitt für gute Verteilung, kein neuer
  Netzwerk-State nötig — auf allen Peers identisch berechenbar). Die
  bisherige Weiß/Orange-Unterscheidung nach Trupp-Art entfällt als
  PRIMÄRES Farbsignal (Trupp-Art steht ohnehin schon als Text in
  Einheiten-Liste/Detailfenster), bleibt aber als schwächeres
  Sättigung/Helligkeit-Signal erhalten (Bautrupp gedeckter, bewaffneter
  Feldtrupp kräftiger). **Noch nicht vom Nutzer getestet.**
- **Zonen-Restriktion beim Bauen komplett entfernt** (nicht nur
  vergrößert, siehe Rückfrage): `_can_build_at()` prüft nur noch
  Bezahlbarkeit, `is_within_own_zone()`/`BUILD_RADIUS` sind komplett aus
  `World.gd` gelöscht (keine tote Funktion stehen gelassen), inkl.
  Aufräumen der Kommentare/Fehlermeldungen in `_report_build_failure()`
  und der betroffenen Doku (`zones.md`, `building.md`). Claimen war davon
  nie betroffen (hatte nie eine Abstandsprüfung). **Noch nicht vom Nutzer
  getestet.**
- **Mehr Sitzplätze in Fahrzeugen umgesetzt** (Nutzer wollte das sofort,
  nicht zurückgestellt): `Vehicle.gd` bekommt `passengers: Array` neben
  dem bisherigen `driver`, `VEHICLE_STATS[...]["seats"]` (Auto 3, Motorrad
  1 — bewusst kein Soziussitz, LKW 5) definiert die Kapazität pro Typ.
  `enter()` gibt jetzt `bool` zurück (Fahrer wird der erste Einsteigende,
  jeder weitere bis zur Kapazität Mitfahrer, `false` wenn voll).
  `World._select_at()` schickt beim Klick auf ein unbesetztes Fahrzeug
  jetzt ALLE ausgewählten eigenen Trupps als Einsteige-Versuch (vorher nur
  `selected[0]`). `request_exit()`/Permadeath (`take_damage()`) wirken
  jetzt auf Fahrer UND alle Mitfahrer gleichzeitig — Mitfahrer können
  nicht einzeln aussteigen, das ganze Kapitel Cross-Peer-Mitfahren
  (bei einem fremden, schon besetzten Fahrzeug zusteigen) bewusst NICHT
  umgesetzt, siehe `vehicle.md`, "Bekannte Grenzen". **Noch nicht vom
  Nutzer getestet.**

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

## Welt-Sync-Sperre + Verbindungsabbruch-Fix (2026-08-04)

Echter Zwei-Spieler-Test deckte zwei Bugs auf: der zweite (Nicht-Host-)
Peer hatte lange Minimap-Ladezeiten und konnte keine Startbase wählen,
und in einer zweiten Testrunde stellte sich heraus, dass die Ursache ein
kompletter **Verbindungsabbruch** war — `_spawn_for_peer()` feuerte beim
Beitritt über 4000 einzelne Catch-up-RPCs (Gebäude/Bäume/Wracks/Steine/
Ziegel) synchron ab und überlastete damit die ENet-Verbindung.

- **`WorldSyncOverlay`** (neue Szene, in `World.tscn` eingebunden):
  Vollbild-Blocker, verhindert Klicks/zeigt Fortschritt, bis der Client
  die Welt tatsächlich vollständig empfangen hat — zählt über
  `child_entered_tree` der Entity-Container (deckt sowohl direkte
  Spawner-Replikation als auch die Catch-up-RPCs ab).
- **Bündel-RPCs:** `_catch_up_buildings_bulk()`/`_catch_up_trees_bulk()`/
  `_catch_up_car_wrecks_bulk()`/`_catch_up_stone_piles_bulk()`/
  `_catch_up_brick_piles_bulk()` ersetzen die fünf schwersten
  Einzel-Catch-up-Funktionen — ein RPC-Aufruf pro Typ statt tausender.
- **Stresstest-Zahlen zurückgenommen** auf den ursprünglichen
  Ausgangswert (Gebäude 1750→350, Bäume/Ressourcen entsprechend runter).
- Nebenbei behoben: `_spawn_for_peer()` rief sich beim Partie-Start auch
  für die eigene Host-Peer-ID auf und krachte beim Tag/Nacht-Catch-up
  ("RPC ... on yourself is not allowed").

Ausführlich in [`networking.md`](networking.md), "Welt-Sync-Sperre".

**Vom Nutzer bestätigt: "passt alles".**

**Nachtrag, noch am selben Tag:** Nutzerfrage "was ist der Plan für
später, wenn mehr Gebäude/große Waldlandschaften dazukommen" deckte eine
verbliebene Redundanz auf — `_generate_world()` replizierte dieselben
Anfangs-Gebäude/-Bäume/etc. WEITERHIN zusätzlich einzeln über die
MultiplayerSpawner (obendrauf zu den jetzt gebündelten Catch-up-RPCs).
Behoben durch `_create_building_local()`/`_create_tree_local()`/etc. —
Host baut die Anfangswelt jetzt rein lokal, jeder Peer bekommt sie
ausschließlich über den ohnehin bestehenden gebündelten Catch-up-Pull.
**Vom Nutzer erneut bestätigt: "beide Spieler laden und haben beide keine
Fehler, das passt soweit."**

## Erstes echtes Gebäude-Asset: Wohnhaus (2026-08-04)

`assets/wohnhaustest.glb` (Nutzer-Modell: Dach, Tür, zwei Fenster) ist im
Spiel verdrahtet — `World._create_building()` baut es dynamisch als
`Model`-Kind ein, wenn `BUILDING_TYPES` den Typ "Wohnhaus" würfelt (neues
`model_path`-Feld, nur bei diesem einen Typ gesetzt, alle anderen 13
Typen bleiben Platzhalter-Boxen). Farb-Feedback (claimen/plündern/
Baustelle) funktioniert am echten Modell über dieselbe rekursive
`_find_mesh_instances()`-Technik wie bei Wachturm/Mauer/Home-Base.

Echte Maße aus der glTF-Bounding-Box ausgelesen: 9,1m × 8,2m Grundfläche,
9,0m Höhe (Prompt sah 7m vor, kam höher raus) — deutlich größer als jeder
bisherige Platzhalter. Zwei Folge-Bugs beim ersten Test gefunden und
behoben:
- **Haus schwebte über dem Boden** — Ursprungspunkt-Mismatch (Modell an
  der Basis verankert, Code ging von zentriertem Ursprung wie bei der
  Platzhalter-Box aus), behoben durch lokalen Y-Versatz nur am `Model`-Kind.
- **Straßenraster zu eng** — `BUILDING_MIN_SPACING` 6→10m,
  `BUILDING_ROW_INSET` 2→5m, sonst hätten sich Wohnhäuser in einer Reihe
  überlappt (Nutzerfrage: "Supermarkt 18×12, unsere Tiles nur 12×12").
- **Kamera zu nah** (Vergleich mit echtem Infection Free Zone-Screenshot):
  Standard-Zoom 25→40, `ZOOM_MIN` 10→20→26 — bewusst eine Kamera-Anpassung
  statt das Gebäude kleiner zu skalieren (Maße entsprechen dem
  Checkliste-Ziel).

Ausführlich in [`building.md`](building.md), "Wohnhaus".

**Vom Nutzer bestätigt: "bis jetzt passt so, vielleicht später bisschen
Fein-Tuning."** Noch offen: Rotation je nach Straßenkante (Haustür zeigt
aktuell immer in dieselbe Weltrichtung), Farb-Feedback am echten Modell
noch nicht separat getestet.

## Ordner-Hinweis

`scenes/entities/player/` und `scenes/ui/` sind jetzt leere Ordner (Commander
bzw. HUD.tscn entfernt, siehe oben) — bewusst nicht gelöscht, falls sie
später wieder gebraucht werden.
