---
tags:
  - spiel
  - godot
  - assets
  - blender
status: aktiv
erstellt: 2026-07-30
---

# Assets mit Blender erstellen

Workflow-Notiz: wie eigene 3D-Assets für KoopGame entstehen, von Blender bis
ins Godot-Projekt. Hintergrund/Architektur-Entscheidung (3D statt 2D wegen
drehbarer Kamera) siehe [[Koop aufbaugame/01 Architektur.md]].

---

## Warum Blender

- Kostenlos, Industriestandard, riesige Tutorial-Basis für Low-Poly-Assets
- Exportiert direkt nach **glTF 2.0** — das Format, das Godot 4 nativ und
  am saubersten importiert (Materialien, Texturen, mehrere Objekte in einer
  Datei kommen mit)
- Download: [blender.org](https://www.blender.org)

---

## Stilrichtung: Low-Poly

Passend zum Genre (Top-Down/Isometric-Strategie, viele gleichzeitig
sichtbare Einheiten): **wenig Polygone, klare Formen, flache Farbflächen
statt Fototexturen.** Das ist nicht nur einfacher zu modellieren als
Realismus, sondern auch performanter — wichtig, weil ihr laut
[[Koop aufbaugame/01 Architektur.md]] den Performance-Punkt bei vielen
gleichzeitigen Zombie-Horden im Blick behalten müsst.

**Faustregel für den Einstieg:** ein Gebäude oder eine Figur sollte sich mit
Grundformen (Würfel, Zylinder, einfache Extrusionen) bauen lassen, ganz ohne
Sculpting oder komplexe Modifier. Details entstehen eher über Farbe/kleine
Formvariation als über Geometrie-Feinheiten.

---

## Grundlegender Workflow (pro Asset)

1. **Modellieren** in Blender — Grundformen, wenig Polygone
2. **Material/Farbe zuweisen** — einfache Flächenfarben reichen für den Start,
   keine UV-gemalten Texturen nötig
3. **Maßstab prüfen** — siehe Abschnitt "Skalierung" unten, wichtig bevor's
   nach Godot geht
4. **Export als `.glb`** (glTF Binary, eine Datei statt glTF + separate
   Texturen — einfacher zu handhaben)
5. **Import in Godot** — `.glb`-Datei einfach in `assets/models/` ziehen,
   Godot erstellt automatisch eine importierbare Szene daraus
6. **In der Godot-Szene einsetzen** — als `MeshInstance3D` oder ganze
   importierte Szene unter den jeweiligen Entity-Node hängen (z. B. unter
   `Survivor`, `HomeBase`, `Zombie` — siehe die jeweiligen Docs in
   [[Koop aufbaugame/Claude code/ARCHITECTURE.md]])

---

## Skalierung: Blender ↔ Godot

Beide nutzen Meter als Grundeinheit, aber **stimmt das nicht automatisch
überein**, wenn man drauflos modelliert. Praktischer Ansatz:

- In Blender vor dem Modellieren grob festlegen: 1 Godot-Einheit = 1 Meter
- Referenzobjekt anlegen (z. B. ein 1×1×2m-Würfel als Platzhalter für "ein
  Survivor steht hier"), daran alle anderen Assets ausrichten
- Bei Export/Import in Godot einmal die Größe im Editor gegenchecken, bevor
  ihr fünf Assets in der falschen Größe baut

---

## Export-Einstellungen (Blender → glTF)

Beim Export (`File → Export → glTF 2.0`):

- **Format:** `glTF Binary (.glb)`
- **Include → Selected Objects** aktivieren, wenn nur ein Teil der Szene
  exportiert werden soll (sonst landet alles im Blender-File in der Datei)
- **Transform → +Y Up** sollte aktiv sein — Godot erwartet Y-Up, Blender
  arbeitet intern mit Z-Up, der Exporter rechnet das automatisch um, wenn
  die Option aktiv ist (Standardeinstellung, nur zur Kontrolle erwähnt)

---

## Asset-Liste (abgeleitet aus dem aktuellen Spielstand)

Orientierung, was aktuell als Platzhalter (`ColorRect`/einfache Primitives)
existiert und nach und nach ersetzt werden könnte — siehe "Stand" in
[[Koop aufbaugame/Claude code/ARCHITECTURE.md]] für den genauen
Implementierungsstand:

- [ ] Survivor (aktuell: helles Rechteck)
- [ ] Zombie-Standardtyp (aktuell: grünes Rechteck)
- [ ] Zombie "Brute" (laut Konzept: langsam, viel HP — noch nicht gebaut)
- [ ] Home-Base (aktuell: gelbes Rechteck)
- [ ] Plünderbare Gebäude, mehrere Typen (aktuell: braune Platzhalter) —
  Wohnhaus, Supermarkt, Apotheke, Waffenladen/Polizeistation, Werkstatt/
  Baumarkt (siehe Loot-Tabellen in [[Koop aufbaugame/01 Architektur.md]])
- [ ] Zonen-Bauten: Mauern/Barrikaden, Wachposten, Lager, Betten, Werkstatt,
  Krankenstation
- [ ] Boden/Untergrund (aktuell: einfarbige Fläche)

**Empfehlung für die Reihenfolge:** erst die Objekte, die man am häufigsten
sieht und die am meisten zum "es sieht jetzt nach echtem Spiel aus"-Gefühl
beitragen — vermutlich Survivor + ein bis zwei Gebäudetypen zuerst, Rest
folgt iterativ.

---

## Alternative/Ergänzung: fertige Assets nutzen

Nicht alles muss selbst gebaut werden. Für den Einstieg oder um Lücken zu
füllen:

- **Kenney** (kostenlos, CC0, direkt als glTF/OBJ nutzbar): Building Kit,
  City Kit (Roads), Modular Buildings, Retro Urban Kit, Survival PSX —
  [kenney.nl/assets](https://kenney.nl/assets)
- **Synty Studios "POLYGON"-Reihe** (kostenpflichtig, ~20$ pro Pack bis
  Abo ab 30$/Monat): u. a. "Apocalypse", "Apocalypse Wasteland", "City
  Zombies" — sehr passender Stil fürs Setting, FBX-Format (in Godot
  ebenfalls importierbar) — [syntystore.com](https://syntystore.com)

Guter Mittelweg: fertige Assets für Umgebung/Gebäude nutzen, Survivor/Zombie
(die am meisten Identität brauchen) später selbst bauen oder anpassen.

---

## Offene Fragen

- Wer macht die Assets — Lucas selbst, oder bleibt es vorerst bei fertigen
  Packs? Noch nicht festgelegt.
- Soll es einen einheitlichen Farb-/Stil-Leitfaden geben (z. B. bestimmte
  Farbpalette für "eigene Zone" vs. "neutrale Stadt"), oder wird das
  iterativ entschieden?

---

Verwandt: [[Koop aufbaugame/01 Architektur.md]] ·
[[Koop aufbaugame/00 Übersicht.md]]
