---
tags:
  - spiel
  - godot
  - planung
  - backlog
  - assets
  - roadmap
status: aktiv
erstellt: 2026-08-04
---

# Weg zur 1.0 — Gesamtliste Code + Assets

> [!info] Zweck
> EINE zusammengeführte Liste: alles, was noch an Code gebaut/ausgebaut
> werden muss, UND alles, was an Asset-Arbeit (Blender) noch fehlt, um von
> heutigem Stand zu einer wirklich spielbaren "1.0"-Version zu kommen.
> Führt [[07 Backlog-Umsetzungspläne.md]] (Code-Details) und
> [[05 Assets im Spiel (aktueller Stand)]] (Asset-Details) zusammen, plus
> Ergänzungen, die in keiner der beiden Listen bisher auftauchen. Für das
> technische "wie genau" bei jedem Code-Punkt: siehe Verweis auf
> `07 Backlog-Umsetzungspläne.md`. Für Blender-Zielmaße: siehe Verweis auf
> `05 Assets im Spiel`.

---

## 1. Code — neue Features (Backlog)

Kurzfassung, volle Details + Datei-/Funktionsnamen in
[[07 Backlog-Umsetzungspläne.md]]:

- **Durst** — drittes Grundbedürfnis neben Hunger/Müdigkeit/Moral.
- **Krankheit als Zwischenstufe vor Permadeath** — braucht erst eine
  Design-Entscheidung (soll das wirklich tödlich sein können?).
- **Reparatur-Mechanik** für beschädigte Gebäude/Home-Base (aktuell nur
  Zerstörung → Ruine → Abriss).
- **Nahrungsproduktionskette** (Feld → Scheune → Kochhaus) — Grundstufe
  (passive Feld-Produktion) existiert schon, echte Kette fehlt.
- **Echter Tech-Baum** — Universal-Buch-Migration (5 Bücher → 1
  `book_research`) bereits erledigt (2026-08-04), der volle Baum mit
  Abhängigkeiten zwischen Freischaltungen ist ein separates, größeres
  Feature, noch offen.
- **Wetter-System mit Vorhersage** — hängt an der Nahrungskette.
- **Fahrzeug-Werkstatt** (Reparatur, Panzerung).
- **Aktiv auslösbare Rekrutierungs-Aktion** ("Ruf aussenden").
- **Gebäude-Adaption statt Loot/Bau-Trennung** — größte Architektur-
  Entscheidung im ganzen Backlog, eigene Planungssession nötig.
- **Treibstoff/Energie für Fahrzeuge.**
- **Skill-/Perk-Progression** durch Tätigkeit — sollte NACH dem
  Rollen-System (siehe Abschnitt 2) kommen, nicht parallel.
- **Kampf-Stances** (aggressiv/defensiv) — fraglicher Nutzen, solange
  Trupps nicht automatisch angreifen (Rückfrage nötig).
- **Waffen-Tausch-Interface** (Lager ↔ Trupp-Slots per Drag&Drop) — reiner
  UI-Zucker, keine neue Funktion.
- **Mehrpersonen-Trupps** (Trupp-Mitglieder-Tausch/Aufteilen) — sehr große
  Strukturänderung, aktuell ist 1 Trupp = 1 Survivor.
- **Mehr Zombie-Typen** — 2 existieren schon (Standard + Brute), Muster
  etabliert, leicht erweiterbar.
- **Lichtscheu-Verhalten** (Zombies tagsüber inaktiv) — würde bestehendes
  Verhalten spürbar verändern, erst Rückfrage.
- **Kontinuierlicher Lärm-/Aktivitäts-Druck** (ergänzend zur Blutmond-
  Kalender-Eskalation).
- **Schwierigkeitsgrad-Einstellung** — müsste als Host-Einstellung in der
  Lobby laufen (gemeinsame Zombie-Population).
- **Banditen-Fraktion als echte NPC-Gegner** — aktuell nur Loot-Mechanik,
  echte Gegner + Hideout-Gebäude fehlen (siehe auch Abschnitt 7, neue
  Assets nötig).
- **Freundliche KI-Überlebendengruppen** zum Handeln — komplett neu,
  geringe Priorität.
- **Mehrere Fahrten bei zu wenig Fahrzeug-Kapazität** — braucht erst ein
  Fahrzeug-Cargo-Konzept (existiert noch gar nicht).
- **Automatische Multi-Ziel-Pfadfindung** beim Plündern.

---

## 2. Code — angefangene/vereinfachte Systeme, die noch ausgebaut werden müssen

- **Survivor-Rollen (Sammler/Wache/Arzt/Baumeister)** — aus der
  ursprünglichen Vision (`01 Architektur.md`), bisher NIE umgesetzt, nur
  als Idee/Punkt 15 der alten festen Liste vermerkt. Passive Boni je
  Rolle, schränken aber nicht ein, was ein Survivor tun kann (anders als
  Trupp-Arten Feld/Bau/Zivilist, die es exklusiv einschränken).

- **Item-/Waffensystem — größte offene Entscheidung im ganzen Plan:**
  Aktuell gibt es nur 5 einfache Ausrüstungs-Slots (Hauptwaffe/
  Nahkampfwaffe/Brustpanzer/Helm/Beinschutz), alle als reine Text-Buttons
  im Trupp-Detailfenster, ohne Icons. Die eigentliche Vision
  (`02 Item-Liste.md`) beschreibt einen VIEL größeren Baum: 4
  Waffen-Progressionsstufen (Nahkampf → Einstiegs-Schusswaffen →
  fortgeschritten → Profi-Ausrüstung, je 3-4 Waffen mit eigenem
  Schaden/Munitionssorte/Slot-Zahl), mehrere Rüstungsvarianten mit
  gestaffelten Speed-/Ausdauer-Mali, eigene Werkzeuge (Bohrmaschine,
  Lockpick, Nachtsichtgerät, Fernglas, ...), tragbares Verbrauchsmaterial
  (Erste-Hilfe-Kit, Rucksack-Erweiterung, ...), Waffen-Mods
  (Schalldämpfer, Optik), UND ein Buch-Kopiersystem (Endgame: gelesenes
  Buch wird in der Werkstatt für halbe Ressourcen reproduzierbar statt
  nur einmal nutzbar).
  - **Muss VOR jedem Umsetzungsschritt entschieden werden:** bleibt das
    aktuelle, einfache 5-Slot-System für 1.0 (schneller spielbar, weniger
    Content-Arbeit), oder wird der volle Item-Baum aus der Vision gebaut
    (viel mehr Tiefe, aber deutlich mehr Code UND Asset-Arbeit)?
  - **Falls der volle Baum kommt: braucht eigene ICONS.** Aktuell läuft
    die GESAMTE UI ohne ein einziges Icon (reine Text-Buttons/Labels,
    `RESOURCE_DISPLAY_NAMES` sind nur Strings) — bei mehreren Dutzend
    unterschiedlichen Waffen/Rüstungen/Werkzeugen/Verbrauchsmaterialien
    wird reiner Text schnell unübersichtlich (z. B. eine Liste mit
    "Pistole (9mm)"/"Revolver (.38 SPL)"/"Karabiner (.308)" als Buttons
    nebeneinander). Das heißt: **für jedes neue Item braucht es zusätzlich
    zum Namen ein eigenes 2D-Icon** (kein 3D-Modell wie bei Gebäuden/
    Fahrzeugen — ein Icon reicht, z. B. als eigenes kleines Bild oder
    simple gezeichnete Grafik), PLUS im Code eine neue generische
    Icon-Anzeige-Infrastruktur (aktuell nirgends vorhanden, jeder Button
    ist reiner `Button.text`).
  - **Empfehlung:** erst grob entscheiden (einfaches System behalten vs.
    voller Baum), dann erst mit der Umsetzung anfangen — das ist keine
    Sache, die man "nebenbei" ausbauen kann, sie betrifft UI, Loot-Tabellen,
    Crafting UND Assets gleichzeitig.

- **Genauere Gebäude-Loot-Tabellen** — aktuell grobe Bereiche pro
  Gebäudetyp, die Vision (`02 Item-Liste.md`, "Loot-Wahrscheinlichkeiten
  pro Gebäude") hat feste Hauptloot-Garantien + prozentuale Nebenloot-
  Chancen pro Gebäudetyp. Nur relevant, falls der volle Item-Baum kommt.

---

## 3. Assets — Gebäude

Aus [[05 Assets im Spiel (aktueller Stand)]], konsolidiert:

**Loot-Gebäude (14 Typen, durchsuchbar in der Stadt):**

| # | Gebäude | Ziel-Grundfläche | Status |
|---|---|---|---|
| 1 | Wohnhaus | 9,1×8,2m | ✅ fertig |
| 2 | Supermarkt | 18×12m | ⬜ offen |
| 3 | Apotheke | 7×6m | ⬜ offen |
| 4 | Waffenladen/Polizeistation | 10×8m | ⬜ offen |
| 5 | Klinik | ~9×7m | ⬜ offen |
| 6 | Militärbasis | ~14×10m | ⬜ offen |
| 7 | Privatbunker | 8×6m | ⬜ offen |
| 8 | Feuerwehrstation | 12×8m | ⬜ offen |
| 9 | Restaurant/Kneipe | 8×7m | ⬜ offen |
| 10 | Tankstelle | 6×5m | ⬜ offen |
| 11 | Bibliothek | 10×8m | ⬜ offen |
| 12 | Universität | 12×10m | ⬜ offen |
| 13 | Garten-Center | 10×8m | ⬜ offen |
| 14 | Camping-Laden | 7×5m | ⬜ offen |
| — | Jagdstand (Wald-Zonen) | ~6×6m | ⬜ offen |
| — | Schutzsuchender (Rekrutierung) | ~2×2m, Zelt/Lager-Prop | ⬜ offen |

**Bau-Gebäude (selbst baubar):**

| Gebäude | Status |
|---|---|
| Wachposten | ✅ fertig |
| Mauer | ✅ fertig |
| Home-Base | ✅ fertig |
| Tor | ⬜ offen |
| Krankenstation | ⬜ offen |
| Werkstatt | ⬜ offen |
| Lager | ⬜ offen |
| Schlafraum/Bett | ⬜ offen |
| Feld | ✅ fertig |
| Außenposten | ⬜ offen |
| Wachturm (Sichtweite, NICHT der Wachposten!) | ⬜ offen |

Volle Zielmaße/Blender-Achsen-Hinweise in `05 Assets im Spiel`.

---

## 4. Assets — Fahrzeuge

| Typ | Ziel-Maße | Status |
|---|---|---|
| Auto (car) | ~4,5×1,8×1,5m | ⬜ offen |
| Motorrad (motorcycle) | 2×0,8×1,2m | ⬜ offen |
| LKW (truck) | 5,5×2×2m | ⬜ offen |

Alle drei aktuell reine Platzhalter-Boxen.

---

## 5. Assets — Einheiten/Gegner

| Einheit | Ziel-Maße | Status |
|---|---|---|
| Survivor | 1,7m Höhe, 0,3m Kapsel-Radius | ⬜ offen |
| Zombie Standard | 1,7m Höhe, 0,3m Kapsel-Radius | ⬜ offen |
| Zombie Brute | 2,1m Höhe, 0,4m Kapsel-Radius | ⬜ offen |

Alle drei aktuell reine Platzhalter-Kapseln.

---

## 6. Assets — Umgebungs-Props

**Zielmaße in `05 Assets im Spiel`, Abschnitt 5 dokumentiert** (2026-08-04,
aus den aktuellen Platzhalter-Collisions abgelesen). **Ziegelhaufen,
Steinhaufen, Baum erledigt** (`ziegelhaufen.glb`/`steinehaufen.glb`/
`tannenbaum.glb`). Noch offen:

- Autowracks (Ressourcenknoten Stadt/Wildnis)
- Zombie-Nest (eigene, sichtbare Struktur pro Stadt-Zone, noch keine
  Zielmaße definiert)

Straßenkacheln (Asphalt/Kreuzung/Ecke/T-Stück) sind bereits fertig
(GridMap-Meshlib), NICHT Teil dieser offenen Liste.

---

## 7. Falls Banditen-Fraktion gebaut wird: eigene neue Assets

Nur relevant, wenn Punkt "Banditen-Fraktion als echte NPC-Gegner" aus
Abschnitt 1 umgesetzt wird:

- **Bandit-Gegner** — eigenes Modell (Mensch-Silhouette, ähnlich Survivor/
  Zombie-Kapsel-Prinzip, aber erkennbar als bewaffneter Mensch statt
  Untoter), keine Zielmaße bisher definiert.
- **Hideout-Gebäude** — Banditen-Basis, die periodisch neue Banditen
  spawnt (analog Zombie-Nest), keine Zielmaße bisher definiert.

---

## 8. Zusammenfassende Prioritäten-Reihenfolge

Code UND Assets gemeinsam sortiert, damit möglichst schnell eine
spielbare Gesamtversion entsteht statt an allem gleichzeitig zu arbeiten:

1. **Entscheidung Item-System** (Abschnitt 2) — bestimmt, wie viel
   Asset-Arbeit (Icons!) überhaupt ansteht. Zuerst klären, sonst plant
   sich der Rest ins Blaue.
2. ~~**Universal-Buch-Migration**~~ — erledigt 2026-08-04.
3. **Restliche Gebäude-Assets** (Abschnitt 3) — größter Umfang an reiner
   Blender-Arbeit, aber unabhängig von Code-Entscheidungen sofort
   startbar, parallel zur Code-Arbeit möglich.
4. **Fahrzeug- + Einheiten-Assets** (Abschnitt 4/5) — kleinerer Umfang,
   ebenfalls parallel zur Code-Arbeit machbar.
5. **Kleine, sofort machbare Code-Punkte ohne Rückfrage** (Durst,
   Worker-Feedback, mehr Zombie-Typen, aktive Rekrutierung — siehe
   `07 Backlog-Umsetzungspläne.md`, "Grobe Reihenfolge-Empfehlung").
6. **Design-Rückfragen klären** (Krankheit, Reparatur-Ansatz, Kampf-
   Stances, Lichtscheu, Schwierigkeitsgrad) — dann erst einordnen.
7. **Umgebungs-Props** (Abschnitt 6) — Zielmaße noch nicht mal definiert,
   erst festlegen, dann modellieren.
8. **Größere, zusammenhängende Blöcke** (Nahrungskette + Dünger + Wetter +
   ablaufende Ressourcen als EIN Paket, nicht einzeln).
9. **Banditen-Fraktion** (Code + neue Assets aus Abschnitt 7) — mittlerer
   bis großer Umfang, aber gutes Vorbild (Zombie-Nest-Muster) vorhanden.
10. **Ganz große Strukturänderungen** (Gebäude-Adaption, Mehrpersonen-
    Trupps, voller Item-Baum falls in Punkt 1 gewählt) — jeweils eigene
    Planungssession, nicht nebenbei.

---

Verwandt: [[07 Backlog-Umsetzungspläne.md]] · [[05 Assets im Spiel (aktueller Stand)]] ·
[[03 Asset-Checkliste.md]] · [[02 Item-Liste.md]] · [[01 Architektur.md]] ·
[[06 Infection Free Zone Recherche.md]]
