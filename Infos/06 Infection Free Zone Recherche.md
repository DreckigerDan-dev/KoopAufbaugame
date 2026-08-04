---
tags:
  - spiel
  - recherche
  - inspiration
  - infection-free-zone
status: aktiv
erstellt: 2026-08-04
---

# Infection Free Zone — Recherche

> [!info] Zweck dieser Notiz
> Ausführliche Recherche zum Spiel **Infection Free Zone** (Jutsu Games,
> Publisher Games Operators, Early Access seit 11.04.2024, Unity-Engine,
> Steam App-ID 1465460) als Inspirationsquelle für KoopGame. KoopGame ist
> laut [[00 Übersicht.md]] und [[01 Architektur.md]] explizit "im Stil von
> Infection Free Zone" konzipiert, fügt aber Koop-Multiplayer hinzu, den
> das Original **nicht** hat (siehe Abschnitt 1).
>
> **Quellenlage:** Infection Free Zone ist noch Early Access und wird
> laufend geändert/erweitert. Viele Detailzahlen stammen aus
> Community-Guides, Steam-Diskussionen und Wikis (Fandom + wiki.gg), nicht
> aus offiziellen Patch-Notes — manche Angaben widersprechen sich zwischen
> Quellen oder sind vom aktuellen Entwicklungsstand überholt. Wo das der
> Fall ist, steht das explizit dabei ("laut X", "nicht eindeutig belegt",
> "keine konkrete Zahl gefunden"). Erfundene Zahlen gibt es hier nicht —
> wenn eine Quelle nur qualitativ beschreibt, steht auch hier nur die
> qualitative Beschreibung.

---

## 1. Spielkonzept/Grundidee

**Setting:** Ein modernes post-apokalyptisches Szenario. Ein Virus namens
"Mad Virus" (auch als "The Mad Virus" bezeichnet) macht Infizierte
aggressiv und stark; die Zivilisation kollabiert laut Wikipedia-Artikel
innerhalb weniger Wochen. Die Spielhandlung beginnt im April 2030, nachdem
ein Teil der (genetisch immunen) Bevölkerung aus unterirdischen Bunkern
hervorkommt, weil die Infizierten-Population abnimmt. Der/die Protagonist:in
ist laut Story-Wiki ein:e "112-Operator" (europäischer Notrufdienst), der/die
aus einer überrannten Leitstelle geflohen ist. Ein Hinweis in der Story
deutet Nordeuropa als möglichen Ursprungsort des Ausbruchs an.

**Ziel/Loop:** Der Spieler wählt einen realen Ort auf der Weltkarte, baut
dort eine "Infection Free Zone" (daher der Titel) auf, indem er reale
Gebäude umfunktioniert/wiederherstellt, tagsüber Trupps zum Plündern
losschickt und nachts die Zone gegen Infizierten-Horden verteidigt. Die
Kern-Spielschleife wird von mehreren Quellen übereinstimmend beschrieben
als: **tagsüber plündern/bauen/vorbereiten → nachts verteidigen →
wiederholen, während die Bedrohung über die Zeit eskaliert.** Ein Reviewer
(Strategy & Wargaming) vergleicht die Mischung mit *Cities: Skylines*,
*Dying Light* und *Frostpunk*; Game8 zieht zusätzlich Parallelen zu
*Project Zomboid*.

**Solo vs. Koop — WICHTIG für KoopGame:**

> [!warning] Infection Free Zone hat KEINEN Multiplayer/Koop
> Mehrere unabhängige Quellen (Steam-Community-Diskussionen, gamepressure.com)
> stimmen überein: Das Spiel ist **reines Singleplayer**. Ein Entwickler
> wird zitiert mit "Sorry, IFZ is going to be single player only." Begründung
> laut Community-Berichten: Die Architektur des Spiels war nie auf
> Multiplayer ausgelegt, ein nachträglicher Koop-Support würde laut
> Entwickler-Aussagen mindestens ein zusätzliches volles Entwicklungsjahr
> kosten. Die Entwickler fokussieren sich stattdessen bewusst darauf, die
> Singleplayer-Erfahrung so gut wie möglich zu machen; für die absehbare
> Zukunft ist kein Multiplayer-Modus geplant.
>
> **Bedeutung für KoopGame:** Das Koop-Element (mehrere Spieler mit
> getrennten Basen auf derselben Karte, siehe [[01 Architektur.md]]) ist
> also tatsächlich ein **echtes Alleinstellungsmerkmal** gegenüber dem
> Original und keine Funktion, die man "wie im Original nachbauen" kann —
> hier muss KoopGame eigene Lösungen finden (Ressourcen-Trennung,
> gemeinsame Zombie-Population, Handel, gegenseitige Hilfe — wie in
> [[01 Architektur.md]] bereits skizziert).

---

## 2. Kartenstruktur/Maßstab

**Echte Karten via OpenStreetMap:** Bestätigt durch mehrere Quellen
(ScreenRant, OpenStreetMap-Community-Forum, offizielle Website
infection-free-zone.com): Das Spiel nutzt OpenStreetMap-Daten, um nahezu
jeden beliebigen Ort der Welt als Karte zu importieren — inklusive
Straßennamen und (semi-)genauer Gebäudepositionen. Spieler geben den
Namen einer Stadt/eines Orts ein, das Spiel lädt die Karte herunter und
generiert daraus die Spielwelt. Es gibt außerdem eine Liste
vordefinierter/vorgefertigter Orte zur schnellen Auswahl.

**Gebäudefunktion aus OSM-Metadaten abgeleitet:** Laut Recherche bestimmt
das Spiel anhand der OSM-Gebäude-Tags semi-genaue Funktionen — z. B.
erscheinen Arztpraxen/Krankenhäuser/Apotheken als Fundorte für
Medizin-Loot, Tankstellen/Kraftstoff-Einrichtungen liefern mehr
Treibstoff-Ressourcen als andere Gebäude.

**Kartengröße:** Beim Start wählbar zwischen Kartenraster **1×1, 3×3 und
5×5 Kacheln** ("tiles"); jede Kachel entspricht laut Fandom-Wiki etwa
**1,2 Quadratmeilen** (~3,1 km²) Fläche. Ein 5×5-Raster kann damit
potenziell eine ganze Stadt bzw. Region abdecken. Laut einer
Steam-Diskussion ist der tatsächlich **spielbare/explorierbare Bereich**
der zu Beginn gewählte Kachelbereich **plus 8 umliegende Kacheln**; alles
darüber hinaus ist nur für Expeditionen nach Bau einer Antenne erreichbar,
und laut Entwickleraussage (in derselben Diskussion wiedergegeben) ist eine
Erweiterung dieses Limits aus technischen Gründen nicht geplant.

**Zeit-/Kalendermaßstab:** Mehrfach übereinstimmend berichtet: **Ein
Spieltag entspricht ungefähr einem In-Game-Monat** — ein deutlich
komprimierterer Zeitmaßstab, als man intuitiv erwarten würde (nicht 1:1
Tag-zu-Tag). Genauer Umrechnungsfaktor nicht einheitlich belegt, aber die
Kernaussage "ein Tag ≈ ein Monat" taucht in mehreren Community-Threads auf.

**Kamera/Perspektive:** Aus den Screenshots/Reviews und der allgemeinen
Beschreibung als "Städtebau-/Strategiesimulation" lässt sich eine
Top-Down/Isometrische Übersichtskamera mit Zoom ableiten (ähnlich
Cities: Skylines-artigen Spielen) — **keine konkrete Zahl** zu
Zoomstufen/Kamerawinkeln in den gefundenen Quellen, daher hier nur
qualitativ vermerkt.

---

## 3. Gebäude/Loot-System

**Zwei Grundarten von Gebäuden:** Gebäude sind entweder vorhandene
("adaptierte") Stadtgebäude oder (nach Freischalten von "Advanced
Woodworks" im Tech-Baum) komplett neu gebaute Strukturen. Laut Wiki
werden Gebäude in Kategorien eingeteilt: **Basic, Food (Nahrung),
Production, Defense, Civilian, Other.**

**Plündern/Scavenging:**
- Trupps ("Squads") werden zu Gebäuden in der Stadt geschickt, durchsuchen
  sie und bringen Loot zurück.
- Mit Fahrzeugen laufen Trupps automatisch aus dem Fahrzeug zum Gebäude
  und wieder zurück; sie machen laut Guide bei Bedarf **mehrere Fahrten**,
  bis Fahrzeug und Hände voll sind.
- Steuerung: Shift+Linksklick sucht laut einem Guide automatisch den
  kürzesten Pfad zwischen mehreren Scavenging-Zielen.
- **Kampfhaltung/Stances** für Trupps: eine Einstellung lässt Trupps ohne
  Provokation auf Feinde feuern, eine andere hält das Feuer zurück und
  greift nur bei Provokation an.

**Gefahren beim Plündern:** In den gefundenen Quellen nicht als separates
"Lärm beim Plündern"-System beschrieben wie in KoopGames Konzept, sondern
eher über die generelle Anziehung von Infizierten durch **Lärm/Hitze**
der Zone insgesamt (siehe Abschnitt 6) sowie durch zufällig auf der Karte
patrouillierende Infizierten-Gruppen und Raider (Abschnitt 9), denen ein
Trupp beim Plündern begegnen kann.

**Beispielhafte Gebäudetypen aus dem Loot-/Umbau-System (Wiki-Liste,
"Buildings"-Seite, wiki.gg):**

*Basisstrukturen:* Headquarters (Kommandozentrale + Lager, Anzahl
Trupp-Slots skaliert mit Größe), Squad Quarters (mehr Trupp-Kapazität),
Warehouse (mehr Lagerkapazität als HQ), Shelter (Wohnraum/Unterkunft für
Zivilisten).

*Nahrungsproduktion:* Field/Feld (laut Wiki 4 Sack Getreide, mit
Dünger 7 — wetterabhängig), Barn/Scheune (wandelt 2 Sack Getreide in
2 rohes Fleisch + 1 Dünger um), Cookhouse/Kochhaus (verarbeitet
Getreide/Fleisch zu Essensrationen), Greenhouse/Gewächshaus
(wetterresistente Ernte), Cannery/Konservenfabrik (Dosennahrung aus
Essensrationen + Metall).

*Produktion:* Tool Factory (einfache Werkzeuge), Arms Factory
(Munition, Pistolen, Gewehre, schwere Waffen), Chemical Plant (Dünger +
Treibstoff), Protective Gear Factory (Schutzausrüstung/Rüstung).

*Verteidigung:* Barbed Wire/Stacheldraht (Schaden + Verlangsamung),
Wooden Palisade/Gate, Metal Fence/Gate, Brick Wall, Fortified Wall/Gate
(gestaffelte Materialstufen), Wooden/Metal/Fortified Towers (besetzbar
mit bewaffneten Wachen).

*Sonstiges/Zivil:* Antenna (ruft Trupps zurück / rekrutiert Überlebende),
Medbay (produziert Erste-Hilfe-Kits), Research Center (Forschung), Weather
Center (Wettervorhersage bis zu 9 Tage im Voraus), Kindergarten
(Kinderbetreuung, erfüllt Zivilisten-Bedürfnis), Bar (Getränke aus
Getreide), Vehicle Workshop (Fahrzeugbau/-reparatur).

**Wichtiges Mechanik-Detail:** Produktions- und Verteidigungsgebäude
brauchen zugewiesene **Worker**, sonst stoppen sie die Produktion; die
Worker-Effizienz hängt von Stimmung ("Mood") und Gebäudekapazität ab, und
Betrieb pausiert nachts. Gebäude haben Haltbarkeit/HP und werden durch
Angriffe beschädigt; Reparatur läuft manuell oder automatisch über
"Repairmen Shops" (manuelle Reparatur legt die Funktion des Gebäudes
währenddessen still).

**Rekrutierung neuer Bewohner:** Über die Antenne kann man einen
"Broadcast" senden, um Überlebende zu rekrutieren — diese spawnen laut
einem Guide aber nicht sofort an der Basis, sondern am Stadtrand oder in
nahen Gebäuden, wohin man einen Trupp schicken muss (oder sie kommen von
selbst). Rekrutierbare Überlebende sind auf der Karte laut einer Quelle
mit gelben Markierungen gekennzeichnet und bewegen sich nachts nicht.

---

## 4. Basis-/Kolonie-Aufbau

Siehe Gebäudeliste in Abschnitt 3 — Basisbau und Loot-Gebäude sind im
Original **dasselbe System** (adaptierte Stadtgebäude werden zu
Basis-Gebäuden), anders als in KoopGames aktuellem Konzept, das reine
Loot-Gebäude (in der Stadt) und eigene Zonen-Bauten (siehe
[[03 Asset-Checkliste.md]]) unterscheidet.

**Ressourcenarten** (Wiki "Resources"-Seite):
- **Nahrung:** Canned Food (Konservenfabrik), Food Rations (Kochhaus,
  laufen laut Wiki nach 3 Tagen ab, werden von Zivilisten bevorzugt vor
  Dosennahrung verbraucht), Grain (Getreide, vom Feld), Raw Meat
  (rohes Fleisch, von der Scheune).
- **Baumaterial:** Holz, Rohmetall, Ziegel — gewonnen durch "Deconstruction"
  (Abriss/Rückbau) von Umgebungsobjekten oder Ernten an bestimmten
  Fundorten (z. B. Bäume, Lehmgruben).
- **Treibstoff/Energie:** Holz dient doppelt als Bau- UND Brennmaterial;
  Treibstoffkanister kommen aus Chemiewerken oder werden bei Parkflächen
  geplündert, genutzt von Fahrzeugen.
- **Munition/Kampf:** Munitionskisten aus Waffenfabriken oder
  Uniform-Einrichtungen (Polizei/Militär) — laut Wiki entspricht eine
  Einheit 100 Schuss.
- **Medizin:** Erste-Hilfe-Kits aus der Medbay, Verbrauch abhängig vom
  Verletzungsgrad.
- **Landwirtschaft:** Dünger verbessert Feldertrag, kann auch zu
  Treibstoff weiterverarbeitet werden.

**Forschung/Tech-Baum:** Das Research Center ist das zentrale
Forschungsgebäude, produziert nebenbei auch "Tech Books". Forschung
verbraucht laut Wiki "Scientific Materials" und setzt erfüllte
Voraussetzungen voraus. Der Tech-Baum schaltet fortgeschrittene
Gebäude/Items frei — u. a. das oben erwähnte "Advanced Woodworks" für
Neubau statt reiner Gebäude-Adaption.

**Impftstoff-Forschung (Beispiel für Tech-Baum-Tiefe):** Laut mehreren
Steam-Diskussionen wird die Vaccine-Forschung freigeschaltet, sobald
Bewohner krank werden (meist vor Tag 25). Ein Kommentar nennt konkret:
Impfstoff muss **jährlich neu erforscht werden**, alle 12 Tage für 40
Forschungspunkte (Achtung: diese Zahl stammt aus einer einzelnen
Community-Antwort, nicht offiziell verifiziert). Nach Erforschung wird
zusätzlich ein Krankenhaus benötigt, um den Impfstoff zu produzieren, und
der Prozess muss regelmäßig mit einer "angepassten" Impfstoff-Version
wiederholt werden.

**Wetter:** Ein Weather Center sagt laut Wiki das Wetter bis zu 9 Tage im
Voraus vorher — Wetter beeinflusst z. B. Feldertrag (siehe oben). Ein
Community-Guide erwähnt außerdem das Überleben des ersten Winters als
eigenes Thema, was auf jahreszeitliche Effekte hindeutet (Details dazu
nicht genauer belegt).

---

## 5. Überlebende/Einheiten-Management

**Rekrutierung:** Siehe Abschnitt 3 (Antenne/Broadcast). Mehr Bewohner
insgesamt bedeuten laut Guide auch mehr verfügbare Worker.

**Trupps ("Squads"):** Zentrale Steuerungseinheit für Kampf/Scavenging.
Man kann Trupps zur Basis/Warehouse schicken und über einen
"Exchange"-Button Waffen aus dem Lagerbestand in die Trupp-Waffenslots
ziehen. Rechtsklick auf einen anderen Trupp tauscht Mitglieder aus;
Rechtsklick wird auch genutzt, um Trupps aufzuteilen. Es gibt eine
maximale Trupp-Kapazität, die sich laut einem Guide über Squad-Quarters-
Gebäude erhöhen lässt.

**Rollen/Jobs:** Die richtige Person dem richtigen Job zuzuweisen erhöht
laut Guide Effizienz und Stimmung. Scavenging gilt als effizientester Weg,
Nahrung/Ressourcen zu sammeln.

**Skills/Perks (per Update eingeführtes System):** Laut PCGamesN-Artikel
("Ambitious zombie game Infection Free Zone introduces new skill system")
wurde ein Skill-System nachgerüstet: Überlebende verdienen durch Aktionen
wie Scavenging, Fahren und Kämpfen zusätzliche Perks, die sie in Zukunft
kompetenter machen — z. B. höhere Trefferchancen bei wertvollen
Ressourcen oder verbesserte Waffengenauigkeit. Es gab laut
Community-Diskussionen ("Survivor Leveling, Skills, and RPG Class
system") auch Wünsche/Diskussionen nach einem tieferen RPG-Klassensystem
— nicht eindeutig belegt, ob/wie weit das umgesetzt wurde, da diese
Diskussion Community-Wunsch statt bestätigtes Feature sein könnte.

**Bedürfnisse:** Grundbedürfnisse umfassen laut Guide **Hunger, Durst,
Schlaf und medizinische Versorgung**; Vernachlässigung führt zu Krankheit,
niedriger Moral und im Extremfall zum Tod. **Stimmung/Mood** wird u. a.
durch Shelter-Gebäude und angemessene Nahrungsverteilung beeinflusst.

**Kein bestätigtes Permadeath-Detail gefunden:** Zu Verletzungs- vs.
Permadeath-Mechanik (im Gegensatz zu KoopGames explizitem
Permadeath-Konzept) wurde in der Recherche keine eindeutige, belastbare
Aussage gefunden — nur die allgemeine Aussage, dass vernachlässigte
Bedürfnisse "im Extremfall zum Tod" führen können. Hier keine Zahl/Detail
erfunden.

---

## 6. Zombies/Bedrohung

**Bezeichnung:** Die Entwickler nennen die Gegner bewusst "Infected"
(Infizierte), nicht "Zombies" — laut Game8-Review als bewusste
Begriffswahl vermerkt. Sie sind laut Wiki lichtscheu/photophob: bei Tag
verstecken sie sich (im Boden oder in Gebäuden) und nehmen bei
Sonnenlicht sogar Schaden, nachts kommen sie hervor und greifen an.

**Infizierten-Typen (7 laut wiki.gg "Infected"-Seite):**
- **Human** — Basis-Bedrohung, langsam und mäßig widerstandsfähig.
- **Dog** — schnell und stark, aber zerbrechlich (wenig HP).
- **Cattle** — mäßig widerstandsfähig, gefährlich im Nahkampf, spawnt in
  kleinen Gruppen.
- **Moose** — schnell und widerstandsfähig, kommt aber nicht in großer
  Zahl vor (solo/paarweise).
- **Bear** — mäßig schnell, im Nahkampf verheerend.
- **Alpha Male** — Elite-Variante, spawnt nur alleine, "enrages" (macht
  wütend) alle nahen Infizierten und erhöht damit deren Schaden pro
  Sekunde — ein Kraftmultiplikator für die ganze Horde.
- **Exploder** — ähnlich Human, aber weniger HP, verursacht beim Tod
  Flächenschaden (Explosion).

**Horden-Mechanik:** Infizierte spawnen laut Wiki in Gruppen von bis zu
20 Individuen, jede Horde hat einen einzigen "Dominant Type" — Horden
bestehen also aus **nur einem** Typ, keine Mischhorden.

**Nester/Lairs:** Bleiben Infizierte unkontrolliert, bilden sie mit der
Zeit "Lairs" (Nester), die als Zufluchtsort für Horden dienen und laut
Wiki Dutzende bis Hunderte Individuen beherbergen können — allerdings
laut Quelle nur von den Typen Human und Dog bewohnbar.

**Eskalation über Zeit/Lärm/Hitze:** Nachts skaliert die
Verteidigungs-Herausforderung laut mehreren Quellen mit dem
**"Heat"- und "Noise"-Level** der eigenen Basis — je mehr Zeit vergeht,
desto stärker "riecht"/"lärmt" die Basis (Geruch, Lärm, Spuren), was
umliegende, ansonsten frei umherziehende Infizierten-Gruppen anlockt.
Community-Berichte zur konkreten Zeitskala (nicht offiziell verifiziert,
aber mehrfach übereinstimmend genannt): grob bis Tag 40 relativ
entspannt, ab ca. Tag 45 spürbarer Schwierigkeitssprung mit
täglich mehreren Horden-Wellen; ein Bericht nennt konkret 6–7
Horden-Gruppen um Tag 30 versus 10–12 um Tag 40, mit weiter steigender
Tendenz danach. **Diese Zahlen sind Community-Erfahrungswerte, keine
offiziellen Werte, und können sich mit Patches geändert haben.**

**Verteidigung:** Mauern/Zäune/Palisaden verschiedener Materialstufen
(Holz → Metall → Fortified) blockieren Infizierten-Pfade, Türme
("Towers") können mit bewaffneten Wachen besetzt werden und feuern
automatisch. Stacheldraht fügt Schaden zu und verlangsamt.

**Schwierigkeitsgrad-Einstellungen:** Laut Game8-Review gibt es
Schwierigkeits-Slider, mit denen sich die Erfahrung von brutal bis
entspannt einstellen lässt (Custom-Difficulty-Optionen).

---

## 7. Fahrzeuge

Bestätigte Fahrzeugtypen laut Fandom/Community: **Sedan (PKW), Pickup
Truck, Van, Truck (LKW), Armored Vehicle (gepanzertes Fahrzeug).**

**Nutzung:** Primärer Zweck ist schnellerer Transport von Trupps über die
Karte, um weiter entfernte Ressourcenpunkte zu erreichen und
Scavenging-Runs effizienter zu machen (mehr Distanz pro Zeiteinheit,
größere Trage-Kapazität durch das Fahrzeug). Beim Scavenging steigen
Trupps automatisch aus dem Fahrzeug aus, durchsuchen das Gebäude und
kehren zurück — bei Bedarf über mehrere Fahrten, bis Fahrzeug **und**
Trupp voll beladen sind.

**Treibstoff:** Fahrzeuge brauchen Treibstoff, der in Gebäuden mit
Ölkanister-Symbol gefunden/geplündert wird; es gibt eine Option zum
automatischen Auftanken, wenn sich das Fahrzeug in Reichweite einer
Treibstoffquelle befindet.

**Geplantes Feature (zum Rechercheszeitpunkt laut Community teils schon
mit "Major Update 4" als Car Workshop eingeführt):** Ein Fahrzeug-
Werkstatt-System für Reparatur und ggf. Nachrüstung von Panzerung,
ähnlich dem Forschungs-/Bausystem für Waffen — laut einer Quelle mit
"Update 4" (Merchant, Car Workshop) bereits umgesetzt.

**Lärm durch Fahrzeuge:** In den durchsuchten Quellen wurde **keine
konkrete Aussage** zu einem expliziten "Fahrzeuge sind laut und ziehen
Zombies an"-Mechanismus gefunden (anders als in KoopGames Asset-Checkliste
vorgesehen) — möglich, dass das über das generelle Heat/Noise-System der
Zone mit abgedeckt wird, aber nicht als eigenständige, fahrzeugspezifische
Mechanik belegt.

---

## 8. UI/UX-Muster

**Fog of War:** Bestätigt vorhanden (es existiert sogar ein — inzwischen
unsupporteter — Nexus-Mod, der ihn deaktiviert). In noch nicht
aufgedeckten ("fogged") Bereichen ist laut einer Steam-Diskussion kein
Reinzoomen möglich; man sieht nur grob "Geister-Kacheln" beim Rauszoomen
und kann keine einzelnen Gebäude anwählen — geplündert werden können
solche Bereiche trotzdem, aber mit Einschränkungen.

**Explorierbarer Bereich:** Siehe Abschnitt 2 — Startkachel(n) + 8
umliegende Kacheln frei erkundbar, der Rest nur für Antennen-gestützte
Expeditionen (kein normales Fog-of-War-Aufdecken darüber hinaus geplant).

**Squad-/Klick-Interface:** RTS-artige Klick-Steuerung: Linksklick zum
Anwählen/Bewegen, Shift+Linksklick für automatische Pfadfindung zwischen
mehreren Scavenging-Zielen, Rechtsklick für Trupp-Mitglieder-Tausch bzw.
Trupp-Aufteilung. Zwei Kampf-Stances (offensiv/defensiv) steuerbar.
Waffenausrüstung läuft über ein Exchange-Interface zwischen
Warehouse-Inventar und Trupp-Slots (Drag & Drop).

**Kritikpunkte an der UI (aus Reviews, Game8):** Fehlende Tastenkürzel/
Quality-of-Life-Shortcuts werden als größte Schwäche genannt — bei über
100 Bewohnern wird das Management mühsam; ein gewünschtes Feature wäre
z. B. ein einfacher Toggle, um Trupps automatisch bestimmten
Scavenging-Zielen zuzuweisen. Ein neu eingeführtes Prioritäts-System
funktioniert laut Review nicht immer zuverlässig (Bewohner ignorieren
teils zugewiesene Prioritäten). Das allgemeine Spieltempo wird als
langsamer als beabsichtigt empfunden, ohne sinnvolle
Zeitraffer-/Fast-Forward-Optionen — Einstieg für Gelegenheitsspieler gilt
als steil (unzureichendes Onboarding für ein Hardcore-Management-Sim).

**Minimap:** In den durchsuchten Quellen keine eigenständige, detaillierte
Beschreibung einer separaten Minimap-Komponente gefunden (anders als bei
KoopGame, das laut [[00 Übersicht.md]] bereits Minimap + Vollbild-
Kartenansicht hat) — die Kartennavigation scheint primär über
Rauszoomen auf der Hauptkarte selbst zu laufen (siehe "Geister-Kacheln"
oben), nicht über eine separate Mini-Karte. **Nicht eindeutig belegt,
ob es zusätzlich eine klassische Minimap-Ecke im HUD gibt** — hier bewusst
keine Vermutung als Fakt hingeschrieben.

---

## 9. Meta-Progression/Enden/Ziele

**Story-Struktur:** Das Spiel hat einen mehrteiligen Story-Modus mit
Kapiteln (laut wiki.gg "Story"-Seite mindestens 5 Kapitel, Details zu
Kapitel 1–4 in der Recherche nicht im Detail verfügbar). Grober Bogen:
Ausbruch → Bunker-Zeit → Auftauchen und Zonen-Aufbau nach mysteriösen
Funksprüchen → Impfstoff-Erfolg der eigenen Zone → erneuter Funkspruch
führt in einen Hinterhalt, ein Saboteur versucht ein Attentat und wird
gestoppt → zwei parallele Bedrohungen: Infizierten-Horden UND die
**"Purifiers"** (eine Fraktion teilinfizierter Fanatiker, die alle
anderen auslöschen wollen) → der/die Operator:in verfolgt und eliminiert
den Anführer der Purifiers → nach dem Räumen verbleibender
Räuber-Verstecke verwaltet der/die Spieler:in die Zone noch eine Weile,
bevor am (aktuellen, Early-Access-)Ende eine **Convoy** gebildet wird und
die Zone Richtung Unbekanntem verlässt.

**Aktueller Stand = kein "echtes" finales Ende:** Mehrere
Steam-Diskussionen bestätigen, dass das derzeitige Story-Ende (Convoy-
Abreise) **nicht das finale, für die Vollversion geplante Ende** ist —
das eigentliche Endgame soll laut Community-Berichten erst mit einem
finalen Story-Update kommen. Das Spiel befindet sich damit in einer
ähnlichen Lage wie KoopGame laut `docs/mechanics-review.md`: Ziel-/
Endzustand ist noch unvollständig, wird aber als bewusste
Weiterentwicklung angekündigt statt als fehlendes Feature verschwiegen.

**Fraktionen/Bedrohungen abseits der Infizierten:** Drei Haupt-Bedrohungen
werden genannt: Ressourcenmangel, die Infizierten selbst, und **Raiders**
(Räuber) — kleine feindliche Menschengruppen (2–4 Personen, rote
Kartenmarkierung, meist mit Pistolen bewaffnet, Loot beim Tod). Raider
können "Hideouts" (Verstecke) als eigene Basis errichten, die
kontinuierlich neue Raider-Gruppen nachspawnen. Weitere erwähnte
Wiki-Kategorien für Inhalte/Threads: Tutorial, Raiders, Military,
Scientists, Lore (zur Infektion), Regional (kartenspezifische Features
wie Züge oder Flughäfen). Es gibt auch **freundliche** Überlebendengruppen
zum Handeln, mit denen laut einer Quelle sogar Bündnisse
("alliances with other IFZs"), Ressourcenaustausch und koordinierte
militärische Aktionen möglich sind — dieser Punkt ist allerdings nur in
einer einzelnen Quelle so ausführlich beschrieben und nicht
gegengeprüft, daher hier mit Vorsicht zu behandeln.

---

## 10. Weitere übertragbare Design-Ideen

- **Reale-Orte-Wahl als Kern-Verkaufsargument:** Der emotionale Reiz,
  die eigene Heimatstadt/einen bekannten Ort zu verteidigen, wird von
  mehreren Reviews als Alleinstellungsmerkmal hervorgehoben (ScreenRant-
  Titel: "Protect Your IRL Hometown"). Für KoopGame (fiktive/generische
  Stadtkarten) nicht 1:1 übertragbar, aber als Erklärung, *warum* dieses
  Feature bei IFZ so gut ankommt, relevant.
- **Größere Städte = mehr Loot, aber auch größere Horden:** Laut Game8-
  Review skaliert die Herausforderung organisch mit der gewählten
  Kartengröße/Stadtgröße — ein Balance-Prinzip, das sich unabhängig von
  echten Karten auch auf KoopGames prozedural generierte Stadt-Tiers
  (siehe [[00 Übersicht.md]], "Stadt-Zonen") übertragen ließe.
- **Gebäude-Adaption statt strikter Loot/Bau-Trennung:** IFZ nutzt
  dieselben Stadtgebäude sowohl zum Plündern als auch als spätere
  Produktionsgebäude (z. B. wird ein Bauernhof-Gebäude zum "Field").
  KoopGame trennt aktuell bewusst Loot-Gebäude (Stadt) und Zonen-Bauten
  (eigene Basis) — eine hybride Idee für später: bestimmte geplünderte
  Gebäudetypen könnten nach dem Claimen eine passende Funktion behalten
  (Werkstatt bleibt Werkstatt), statt komplett neutral zu werden.
- **Worker-Zuweisung mit Effizienz/Mood-Kopplung:** Produktionsgebäude
  ohne zugewiesene Worker stoppen komplett — ein einfaches, verständliches
  Feedback-System, das Leerlauf sichtbar macht. Für KoopGames
  Bautrupp-Konzept übertragbar.
- **Heat/Noise als kontinuierlicher Eskalationsdruck statt fester Wellen:**
  IFZ koppelt Horden-Attraktion an einen kontinuierlich wachsenden
  "Lärm/Hitze"-Wert der eigenen Basis statt (nur) an feste
  Kalender-Events. KoopGames Blutmond-Events (siehe [[01 Architektur.md]])
  sind eher IFZs Ansatz mit Chapter-Story-Antagonisten (Purifiers) ähnlich
  einem festen Ereignis — ein zusätzlicher, kontinuierlicher
  Lärm-/Aktivitäts-Druck (was KoopGame mit seinem eigenen Lärm-System
  teilweise schon vorsieht) ergänzt das gut.
- **Weather Center mit Vorhersage-Fenster (9 Tage):** Eine planbare,
  aber nicht sofort wirksame Vorhersage schafft taktische Vorbereitungszeit
  (z. B. Ernte vor Sturm einholen) — als Idee für spätere Wetter-/Jahreszeiten-
  Mechanik in KoopGame interessant.
- **Skill-Progression durch Tätigkeit statt Level-Ups durch XP-Punkte:**
  Überlebende werden durch das Ausüben einer Tätigkeit (Scavenging,
  Fahren, Kämpfen) darin besser — passt zu KoopGames Rollen-Konzept
  (Sammler/Wache/Arzt/Baumeister), könnte aber zusätzlich noch
  tätigkeitsbasierte Boni statt nur rollenbasierter Boni einführen.
  Vorsicht: passives, prozedurales Skill-Wachstum kann bei falscher
  Balance zum "immer nur den Erfahrensten schicken"-Problem führen,
  das die Individualität einzelner Survivor untergräbt.
- **Explizite Schwierigkeits-Slider statt nur ein Standard-Preset:**
  Für unterschiedliche Spielertypen (brutal vs. entspannt) — auch bei
  vier Koop-Spielern mit unterschiedlichem Skill-Level potenziell
  relevant, allerdings in KoopGames Kontext schwieriger, weil die
  Schwierigkeit von ALLEN gemeinsam getragenen Zombie-Population betrifft
  (siehe "geteilte Gefahr" in [[01 Architektur.md]]) — ein einzelner
  Spieler kann nicht einfach "seinen eigenen" Schwierigkeitsgrad wählen,
  ohne Mitspieler zu beeinflussen. Eher ein ungelöstes Spannungsfeld als
  eine direkt übertragbare Lösung.
- **Kritikpunkte ernst nehmen als Vermeidungsliste:** Reviews nennen
  wiederkehrend fehlende Klick-Shortcuts/Automatisierung bei großer
  Bewohnerzahl, ein unzuverlässiges Prioritätssystem, gefühlt zu
  langsames Tempo ohne Zeitraffer, und schlechtes Pathfinding (Einheiten
  laufen unlogische Umwege, z. B. um ganze Wohnblöcke herum nur um einen
  Gebäudeeingang zu erreichen) sowie spürbare Performance-Probleme bei
  vielen gleichzeitig simulierten Einheiten (ein Bericht nennt bis zu
  600+ gleichzeitig aktive Worker als Ursache für Spätspiel-Lags). Für
  KoopGame — das laut [[koopgame_map_scale_performance]]-Notiz Performance
  bereits im Blick hat — eine konkrete Warnliste, was bei wachsender
  Einheitenzahl frühzeitig zu adressieren ist (Pathfinding-Qualität,
  Klick-Automatisierung, Zeitraffer-Option).
- **KI-generierte Portraits/Assets als Kontroverse:** IFZ nutzt laut
  Review-Kritik KI-generierte Überlebenden-Portraits, was in der
  Spieler-Community umstritten diskutiert wird — für KoopGame (wo laut
  [[koopgame_asset_planning_session]] Assets von Hand in Blender gebaut
  werden) keine direkte Relevanz, aber als Hinweis, dass die eigene
  Handarbeits-Herangehensweise bei einem Teil der Zielgruppe positiv
  auffallen könnte.

---

## Direkte Inspirations-Ideen für KoopGame

Abgleich mit dem, was laut [[00 Übersicht.md]], [[01 Architektur.md]] und
[[koopgame_mechanics_review_findings]] in KoopGame bereits existiert bzw.
noch fehlt:

**Bereits vorhanden in KoopGame, IFZ-inspiriert und im Original ähnlich
bestätigt:**
- Stadt-Zonen mit Straßenraster, Fog of War, Minimap + Vollbild-Kartenansicht
  — IFZ hat Fog of War definitiv, eine klassische separate Minimap ist bei
  IFZ **nicht eindeutig belegt** (KoopGame geht hier evtl. schon über das
  Original hinaus).
- Gebäude-Loot-System mit Loot-Tabellen je Gebäudetyp und "kein Respawn nach
  Plündern" — passt zu IFZs Grundprinzip, auch wenn IFZ die geplünderten
  Gebäude zusätzlich zu Produktionsgebäuden umfunktioniert (KoopGame trennt
  das bewusst, siehe Punkt oben unter "Weitere Design-Ideen").
  KoopGames endliches Loot ohne Respawn erzeugt laut [[01 Architektur.md]]
  Wettbewerb zwischen Spielern — ein Effekt, den es in IFZ mangels
  Multiplayer naturgemäß nicht geben kann.
- Zombie-Horden/Nester — IFZs "Lairs" sind konzeptionell nah an KoopGames
  Nest-Idee.
- Trupp-/Einheiten-Management (Feldtrupps/Bautrupps) — ähnlich IFZs
  Squad-System, aber KoopGame hat die explizite Feld-/Bautrupp-Trennung,
  die IFZ so nicht hat (IFZ trennt eher nach Worker-Zuweisung pro Gebäude).
- Ressourcen-Wirtschaft, Basis-Bau, Fahrzeuge, Tag/Nacht-Zyklus — alles
  im Original in ähnlicher Form vorhanden, siehe Abschnitte 4, 7, 6.

**Fehlt in KoopGame (laut `docs/mechanics-review.md`), IFZ bietet dafür
Vorbilder:**
- **Enden/Ziele:** IFZ hat zumindest einen Story-Modus mit Kapiteln und
  einem (vorläufigen) Abschluss (Convoy-Abreise) — auch wenn das
  offizielle Endgame laut Community selbst bei IFZ noch aussteht. Für
  KoopGame könnte ein ähnliches "vorläufiges, aber spürbares Ziel"
  (z. B. Evakuierungs-Konvoi, Impfstoff-Fertigstellung als Meilenstein)
  eine schnell erreichbare Zwischenlösung sein, statt auf ein komplettes
  Story-System zu warten.
- **Forschung/Tech-Baum:** In KoopGames Ideen-Backlog als Post-MVP
  vermerkt ([[01 Architektur.md]]) — IFZ zeigt ein ausgearbeitetes
  Beispiel (Research Center + Scientific Materials + Tech Books als
  Whitelisting-Mechanik für fortgeschrittene Gebäude), das als
  Referenz-Architektur dienen kann, wenn KoopGame diesen Punkt angeht.
- **Fraktionen/Raider als dritte Bedrohungsart** (neben Ressourcenmangel
  und Zombies): IFZ hat mit "Raiders" eine eigene, von Zombies losgelöste
  Mensch-gegen-Mensch-Bedrohung mit eigenen Hideouts. KoopGame hat aktuell
  nur die Banditen-Idee im Backlog ([[01 Architektur.md]], "gelegentliche
  Restloot-Camps") — IFZ zeigt, dass eine vollwertige Raider-Fraktion mit
  eigener Basis/Eskalation ein spielbares, beliebtes Feature ist, falls
  KoopGame das später ausbauen will.
- **Skill-/Perk-Progression einzelner Survivor:** IFZ hat das per Update
  nachgerüstet (tätigkeitsbasierte Perks). KoopGame hat aktuell nur
  Rollen mit passiven Boni, keine individuelle Erfahrungs-Progression —
  mögliche spätere Ergänzung.
- **Wetter-/Jahreszeiten-System mit Vorhersage:** Komplett neu für
  KoopGame, in IFZ über das Weather-Center-Gebäude bereits umgesetzt.

**Bewusste Abweichungen, die KoopGame beibehalten sollte (nicht vom
Original übernehmen):**
- Die von Reviews kritisierten IFZ-Schwächen (fehlende Klick-Automatisierung
  bei großer Einheitenzahl, unzuverlässiges Prioritätssystem, schlechtes
  Pathfinding um Gebäude herum, kein Zeitraffer) sind eine explizite
  Vermeidungsliste, keine Inspirationsquelle — KoopGame sollte diese Punkte
  von Anfang an mitdenken, statt sie wie IFZ erst nach Early-Access-Kritik
  nachzubessern.
- Die Koop-Mechanik selbst (getrennte Basen, gemeinsame Zombie-Population,
  Handel, gegenseitige Hilfe, geteilte Aufklärung) hat **kein Vorbild in
  IFZ** — hier bleibt KoopGame auf eigenständiges Design-Denken angewiesen,
  da diese Fragen im Original nie gelöst werden mussten.

---

## Nachtrag: Kamera-/Maßstabs-Detailrecherche (2026-08-04)

> [!info] Anlass
> Gezielte Nachrecherche zu zwei in Abschnitt 2 offen gelassenen Lücken
> ("keine konkrete Zahl gefunden"): Kamera/Zoom-Werte und typische
> Gebäude-/Objekt-Maße. Für den Vergleich relevant: KoopGames eigene
> Kamera-Distanzwerte laut `koop-game/docs/world.md`
> (Abschnitt "Kamera-Zoom-Bereich") sind aktuell **`ZOOM_MIN = 26.0`,
> `ZOOM_MAX = 80.0`, Standard-Zoom `_zoom_distance = 40.0`** — reine
> Godot-Kamera-Distanz/Pivot-Offset-Werte, keine Meter-Einheit im
> eigentlichen Sinn, aber in der gleichen Größenordnung wie
> Godot-Welt-Meter gehalten. Referenz-Gebäude ist laut
> [[05 Assets im Spiel (aktueller Stand).md]] das Wohnhaus mit **9×8×9m**
> (Breite×Tiefe×Höhe).

### Kamera/Zoom

**Ein konkreter Zahlenwert gefunden, aber mit Einschränkung:** Mehrere
unabhängige Suchanfragen (u. a. zu Patch-Notes-Zusammenfassungen von
Steam-News/Community-Threads) nennen übereinstimmend denselben Wert: Ein
per Einstellungen umschaltbarer Kameramodus **"Free Tilt"** (Gegenstück:
"Fixed Tilt", entspricht dem bisherigen/alten Kameraverhalten) erlaubt es,
**weiter herauszuzoomen und den Kamerawinkel bis zu 45° zu verändern**
("change the angle of the camera as far as 45°"). Laut denselben Quellen
wurde vorher bereits mit **Bugfix Update #36** ("Free Camera, Building
Split Fix, Memory Leak Fix") ein "Free Camera"-Konsolenbefehl eingeführt,
der offizielle Fixed-Tilt/Free-Tilt-Einstellungsoption kam laut einer
Quelle mit einem späteren, nicht eindeutig benannten Major Update
("Major Update #6" wird in einer Suchzusammenfassung genannt, aber nicht
gegengeprüft). Die Entwickler weisen dabei selbst darauf hin, dass der
Free-Tilt-Modus **spürbar mehr Performance kosten kann**.

> [!warning] Einschränkung der Quellenlage bei diesem Punkt
> Die eigentlichen Steam-News-/Patch-Notes-Seiten sind clientseitig
> gerendert (JavaScript) und ließen sich mit dem verfügbaren Web-Fetch-
> Werkzeug nicht direkt als Volltext abrufen (nur Navigations-/Header-
> Reste kamen zurück) — der 45°-Wert stammt aus wiederholten,
> übereinstimmenden Suchmaschinen-Zusammenfassungen derselben
> Patch-Notes-Inhalte (Steam Community/Steam News, siehe Quellen unten),
> nicht aus einer selbst verifizierten Primärquelle im Volltext. Die
> Kernaussage (45°-Kamerawinkel-Obergrenze im "Free Tilt"-Modus) taucht
> aber konsistent genug auf mehreren unabhängigen Suchanfragen auf, um sie
> hier mit dieser Einschränkung festzuhalten statt sie zu verwerfen.
>
> **Was NICHT gefunden wurde, trotz mehrerer gezielter Suchanfragen:**
> keine Zoom-Distanz in Metern/Unity-Einheiten, keine Kamerahöhe, kein
> FOV-Wert, kein Zahlenwert für den Standard-/Basis-Kamerawinkel im
> "Fixed Tilt"-Modus (nur dass "Free Tilt" ihn bis 45° erweitert). Das ist
> für ein Early-Access-Indie-Spiel ohne offizielle technische
> Dokumentation plausibel — solche Werte werden typischerweise nicht
> veröffentlicht, außer im Rahmen von grob beschriebenen
> Feature-Ankündigungen wie hier.

**Vergleich zu KoopGame:** Ein direkter Zahlenvergleich ist wegen der
unterschiedlichen Einheiten (Godot-Kamera-Distanz vs. Grad-Kamerawinkel)
nur bedingt möglich. Qualitativ passt KoopGames aktuelle Konfiguration
(`ZOOM_MIN 26.0` bis `ZOOM_MAX 80.0`, Standard `40.0`, siehe oben) aber
zum gleichen Trend, den IFZ mit dem Free-Tilt-Update verfolgt hat:
**mehr Zoom-Spielraum nach außen freigeben, dabei bewusst nicht zu nah
heranzoomen lassen** (KoopGames `ZOOM_MIN` wurde laut `world.md` mehrfach
aus genau diesem Grund angehoben, 4.0 → 10.0 → 20.0 → 26.0). Ein
Kamerawinkel-Freiheitsgrad (wie IFZs "Free Tilt" bis 45°) existiert in
KoopGame aktuell nicht als recherchierte Vorlage, sondern nur als eigene,
unabhängig getroffene Design-Entscheidung.

### Gebäude-/Objekt-Maße

**Ein konkreter Zahlenwert gefunden, aber mit begrenzter Aussagekraft:**
Eine Steam-Community-Diskussion zur Shelter-Umwandlung ("How can i extend
capacity of a shelter?") nennt übereinstimmend (Threadersteller + eine
Antwort mit Beispiel) einen Grenzwert für das **Start-HQ-Gebäude**
(das beim Kartenstart wählbare erste Gebäude): Die **100%-Adaptierbarkeits-
Grenze liegt bei ca. 300–350 Quadratmetern Grundfläche** — ein Spieler
nennt konkret sein eigenes Start-Gebäude mit **312 m², vollständig (100%)
adaptierbar**. Größere Gebäude lassen sich laut Thread nicht mehr zu 100%
umfunktionieren. Das ist eine echte, konkrete Flächenangabe, aber sie
bezieht sich spezifisch auf die HQ-Adaptions-Obergrenze, **nicht** auf
eine "typische Hausgröße" allgemein — sie bestätigt eher indirekt, dass es
keine feste Standardgröße gibt (Gebäude bis ~300–350 m² gelten schon als
groß genug für eine Sonderregel).

**Explizit unzuverlässiger Datenpunkt (nur als Negativbeispiel
vermerkt):** In einer anderen Diskussion zu einem Höhen-Anzeige-Bug wird
ein Wolkenkratzer als "7 yards tall" und ein kleineres Gebäude als "37
yards tall" beschrieben — das ist ausdrücklich als **fehlerhafte
Höhenberechnung (Bug-Report)** gemeint, keine verlässliche Design-Zahl,
und wird hier bewusst NICHT als Referenzwert übernommen.

**Charaktergröße/Fahrzeuglänge: nichts Konkretes gefunden.** Trotz
gezielter Suchen (Unity-Skalierung, Modding-/Datamining-Communities,
Reddit) wurde keine bezifferte Angabe zur Spielfigur-Höhe oder
Fahrzeuglänge in Metern/Unity-Einheiten gefunden. Plausibler Grund: IFZ
bindet Gebäude/Terrain direkt an reale OSM-Koordinaten (siehe Abschnitt 2
der bestehenden Notiz), Charaktere/Fahrzeuge sind dagegen austauschbare
Asset-Instanzen ohne erkennbaren Anlass, ihre Maße öffentlich zu
dokumentieren oder zu diskutieren — anders als bei Gebäuden gibt es dafür
auch keine spielrelevante Debatte (z. B. um Adaptions-Grenzen), die
Community-Threads mit Zahlen erzeugen würde.

> [!note] Kernaussage bleibt bestehen, jetzt mit einem Beleg mehr
> Die bestehende Einschätzung in der Notiz — IFZ nutzt echte
> OSM-Gebäude-Footprints statt fester Templates, es gibt also **keine
> feste "Standard-Hausgröße"** — wird durch diese Nachrecherche bestätigt
> statt widerlegt. Der einzige gefundene konkrete Flächenwert (300–350 m²)
> ist eine **Obergrenze für eine Sonderregel** (HQ-Adaption), kein
> Standard-Template-Maß, und lässt sich daher nur eingeschränkt mit
> KoopGames Wohnhaus (9×8m Grundfläche = 72 m²) vergleichen — die
> Größenordnungen liegen aber grob im gleichen Feld (KoopGames Wohnhaus
> ist klar kleiner als die IFZ-HQ-Adaptionsgrenze, was angesichts der
> IFZ-Grenze als Obergrenze für ganze Häuserblocks/größere Gebäude auch
> zu erwarten ist).

---

## Quellen (Auswahl, nach Abschnitt referenziert)

- [Infection Free Zone auf Steam](https://store.steampowered.com/app/1465460/Infection_Free_Zone/)
- [Infection Free Zone – Wikipedia (englisch)](https://en.wikipedia.org/wiki/Infection_Free_Zone)
- [Infection Free Zone Wiki (wiki.gg) – Buildings](https://infectionfreezone.wiki.gg/wiki/Buildings)
- [Infection Free Zone Wiki (wiki.gg) – Resources](https://infectionfreezone.wiki.gg/wiki/Resources)
- [Infection Free Zone Wiki (wiki.gg) – Infected](https://infectionfreezone.wiki.gg/wiki/Infected)
- [Infection Free Zone Wiki (wiki.gg) – Story](https://infectionfreezone.wiki.gg/wiki/Story)
- [Infection Free Zone Wiki (Fandom) – Cities](https://infection-free-zone.fandom.com/wiki/Cities)
- [Infection Free Zone Wiki (Fandom) – Getting Started](https://infection-free-zone.fandom.com/wiki/Getting_Started)
- [Infection Free Zone Wiki (Fandom) – Gameplay](https://infection-free-zone.fandom.com/wiki/Gameplay)
- [Infection Free Zone Wiki (Fandom) – Squads](https://infection-free-zone.fandom.com/wiki/Squads)
- [Infection Free Zone Wiki (Fandom) – Multiplayer](https://infection-free-zone.fandom.com/wiki/Multiplayer)
- [Game8 – Infection Free Zone Review](https://game8.co/articles/reviews/infection-free-zone/infection-free-zone-review)
- [Strategy and Wargaming – Infection Free Zone Review](https://strategyandwargaming.com/2024/04/08/infection-free-zone-review-finally-an-interesting-strategy-zombie-game/)
- [ScreenRant – Protect Your IRL Hometown From Zombie Hordes](https://screenrant.com/infection-free-zone-steam-openstreetmap-irl-zombie-game/)
- [OpenStreetMap Community Forum – Game "Infection Free Zone" maps based on OSM](https://community.openstreetmap.org/t/game-infection-free-zone-maps-based-on-osm/8877)
- [gamepressure.com – Coop and Multiplayer Explained](https://www.gamepressure.com/newsroom/infection-free-zone-ifz-coop-and-multiplayer-explained/ze6c14)
- [gamepressure.com – How to Find, Use and Refuel Vehicles](https://www.gamepressure.com/newsroom/how-to-find-use-and-refuel-vehicles-in-infection-free-zone/z16c5c)
- [PCGamesN – Ambitious zombie game Infection Free Zone introduces new skill system](https://www.pcgamesn.com/infection-free-zone/update-skills)
- [TheGamer – Beginner Tips And Tricks For Infection Free Zone](https://www.thegamer.com/infection-free-zone-beginner-tips-tricks/)
- [TheGamer – How To Get And Assign Workers](https://www.thegamer.com/infection-free-zone-worker-assignments-guide/)
- [TheGamer – How To Adapt Buildings](https://www.thegamer.com/infection-free-zone-building-adaptation-guide/)
- [The Guide Hall – Major Update 4 Adds Merchant, Car Workshop, and More!](https://theguidehall.com/infection-free-zone-major-update-4-adds-merchant-car-workshop-and-more/)
- [Steam Community – Guide: Surviving combat, growing food, scavenging and building a base](https://steamcommunity.com/sharedfiles/filedetails/?id=3222175807)
- [Steam Community – diverse Diskussions-Threads zu Multiplayer, Difficulty, Fog of War, Endgame (siehe Fußnoten in den jeweiligen Abschnitten)](https://steamcommunity.com/app/1465460)
- [Steam Community – How can i extend capacty of a shelter? (Quelle für 300–350 m² HQ-Adaptionsgrenze)](https://steamcommunity.com/app/1465460/discussions/0/601901034049139675/)
- [Steam Community – Building height (Quelle für den verworfenen "7/37 yards"-Bug-Datenpunkt)](https://steamcommunity.com/app/1465460/discussions/0/595138951841335014/)
- [Steam News – Infection Free Zone: Bugfix Update #36 (Free Camera, Building Split Fix, Memory Leak Fix)](https://store.steampowered.com/news/app/1465460/view/490466921629615375)
- [Hard Drive – Infection Free Zone Update Patch Notes June 19 (Major Update #1: Zoom-in erhöht, Kamerawinkel beim Zoomen readjustiert)](https://hard-drive.net/infection-free-zone-update-patch-notes-june-19/)

---

Verwandt: [[00 Übersicht.md]] · [[01 Architektur.md]] ·
[[03 Asset-Checkliste.md]] · [[05 Assets im Spiel (aktueller Stand).md]]
