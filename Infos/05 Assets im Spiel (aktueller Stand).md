---
tags:
  - spiel
  - godot
  - assets
  - blender
  - checkliste
status: aktiv
erstellt: 2026-08-04
---

# Assets im Spiel — aktueller Stand (was WIRKLICH gebraucht wird)

Ergänzt `03 Asset-Checkliste.md` — die ist die volle Vision (17 Loot-
Gebäude, Zonen-Bauten, 6 Fahrzeugtypen), aber nicht alles davon ist
aktuell im Code implementiert. Diese Liste hier zeigt **nur das, was
JETZT im Spiel existiert und einen echten Asset braucht** — direkt aus
dem Code abgelesen (`World.gd`/`Vehicle.gd`/die jeweiligen `.tscn`),
2026-08-04. Zielgrößen sind wo möglich 1:1 aus der Checkliste übernommen
(Format dort: H×B×T, hier nur Breite×Tiefe = die für Straßenraster/
Bauplatz relevante Grundfläche); wo die Checkliste keinen Eintrag hat,
steht ein eigener Vorschlag mit Begründung.

**Erledigt (2026-08-04):** Straßenraster/Bauplatz-Abstände sind jetzt ans
erste gelieferte Gebäude (Wohnhaus) angepasst — `BUILDING_MIN_SPACING`
6→10m, `BUILDING_ROW_INSET` 2→5m (siehe `docs/building.md`, "Wohnhaus").
Gilt vorerst EINHEITLICH für alle Typen, auch die noch kleinen
Platzhalter — größere Typen wie Supermarkt (18m) brauchen bei ihrer
eigenen Asset-Lieferung vermutlich eine eigene, breitere Slot-Reservierung
statt der einheitlichen Reihen-Abstände, noch nicht umgesetzt.

---

## Blender-Achsen-Konvention (welche Achse ist was)

Nutzerwunsch 2026-08-04: bei jedem Asset direkt dazuschreiben, welche
Blender-Achse welchem Maß entspricht, damit beim Modellieren klar ist, wo
was einzutragen ist. Grundlage: `02 Assets mit Blender.md`, Export-
Einstellung **+Y Up** (Standard) — Blenders Z-Up wird beim `.glb`-Export
automatisch zu Godots Y-Up umgerechnet. Gilt EINMAL für alle Tabellen
unten (jede Spalte "B×T"/"L×B×H"/"Höhe" nennt die passende Blender-Achse
in Klammern, keine Wiederholung dieser Erklärung pro Zeile nötig):

| Maß | Blender-Achse | wird in Godot zu | Bedeutung |
|---|---|---|---|
| **Breite (B)** | X | X | Seitliche Ausdehnung, quer zur Blickrichtung |
| **Tiefe (T)** | Y | Z | Ausdehnung in Blickrichtung (Blender Front-Ansicht = Blick entlang -Y) |
| **Höhe (H)** | Z | Y | Vertikale Ausdehnung (nach oben) |

Bei **Fahrzeugen** (Tabelle 3) kommt zusätzlich **Länge (L)** vor —
Fahrtrichtung, entspricht derselben Achse wie "Tiefe" oben: **Blender Y**
(wird Godot Z). Bei **Einheiten** (Tabelle 4) ist der Kapsel-Durchmesser
radial (kreisförmiger Querschnitt) und deckt beide horizontalen
Blender-Achsen (X UND Y) gleichermaßen ab, keine einzelne Achse nötig.

**Praktisch beim Modellieren:** Location/Rotation/Scale bleiben bei einem
frisch importierten Asset auf 0/0/1 (siehe Screenshot `bilder/blender
masße.PNG`, Default-Würfel) — nur die **Dimensions**-Werte (X/Y/Z im
Transform-Panel) müssen den Ziel-Maßen aus den Tabellen unten entsprechen.
"Norden" in der Karte (siehe `Minimap.gd`/`MapView.gd`) liegt in Richtung
**-Z in Godot** — das ist exakt die Blender-Front-Ansicht (Blick entlang
-Y, Numpad 1), passt also ohne manuelle Extra-Rotation.

---

## 1. Loot-Gebäude (Stadt, durchsuchbar)

Alle 14 aktuell im Code (`World.BUILDING_TYPES`) + Jagdstand (eigene,
separate Vorlage für Wald-Zonen) + Schutzsuchende (neu seit 2026-08-04,
siehe `docs/mechanics-review.md`). Alle bisher reine Platzhalter-Boxen,
**kein einziges hat schon ein echtes Asset**.

| # | Name | Ziel-Grundfläche (B=Blender X × T=Blender Y) | Quelle | Priorität |
|---|------|------------------------|--------|-----------|
| 1 | Wohnhaus | ✅ **Echtes Asset im Spiel** (`wohnhaustest.glb`, 2026-08-04) — tatsächliche Maße 9,1m × 8,2m × 9,0m Höhe (etwas höher als der 7m-Zielwert im Prompt) | Checkliste (Ziel war 9m × 8m) | ~~HIGH~~ erledigt |
| 2 | Supermarkt | 18m × 12m | Checkliste | MEDIUM |
| 3 | Apotheke | 7m × 6m | Checkliste | MEDIUM |
| 4 | Waffenladen/Polizeistation | 10m × 8m | Checkliste | MEDIUM |
| 5 | Klinik | ~9m × 7m | Eigener Vorschlag (kein Checklisten-Eintrag — größer als Apotheke, eigenständiges Gebäude) | LOW |
| 6 | Militärbasis | ~14m × 10m | Eigener Vorschlag (Checkliste nennt nur "Map-abhängig", kein festes Maß) | LOW |
| 7 | Privatbunker | 8m × 6m | Checkliste | LOW |
| 8 | Feuerwehrstation | 12m × 8m | Checkliste | LOW |
| 9 | Restaurant/Kneipe | 8m × 7m | Checkliste | LOW |
| 10 | Tankstelle | 6m × 5m | Checkliste | LOW |
| 11 | Bibliothek | 10m × 8m | Checkliste | MEDIUM |
| 12 | Universität | 12m × 10m | Checkliste | LOW |
| 13 | Garten-Center | 10m × 8m | Checkliste | LOW |
| 14 | Camping-Laden | 7m × 5m | Checkliste | LOW |
| — | Jagdstand (nur Wald-Zonen) | ~6m × 6m | Eigener Vorschlag (Checkliste nennt nur "Map-abhängig") | LOW |
| — | Schutzsuchender (Rekrutierungs-Ereignis) | ~2m × 2m, klein/schlicht | Eigener Vorschlag — bewusst KEIN echtes Gebäude, eher Zelt/Lagerplatz-Prop, muss nicht an Straßenraster-Maße gebunden sein | LOW |

---

## 2. Bau-Gebäude (selbst baubar)

| Name | Status | Ziel-Grundfläche (B=Blender X × T=Blender Y) | Quelle |
|------|--------|------------------------|--------|
| **Wachposten** | ✅ Asset vorhanden (`wachturmtest.glb`) | — | fertig |
| **Mauer** | ✅ Asset vorhanden (`holzmauertest.glb`) | — (2,5m Segment, variable Länge) | fertig |
| **Home-Base** | ✅ Asset vorhanden (`startbasetest.glb`) | — | fertig |
| **Tor** | ⬜ Noch kein Asset | ~2m × 0,4m (Mauer-Segment mit Durchgang) | Checkliste hat keinen eigenen Tor-Eintrag, an Mauer-Optik anlehnen |
| **Krankenstation** | ⬜ Noch kein Asset | 6m × 5m | Checkliste |
| **Werkstatt** | ⬜ Noch kein Asset | 5m × 4m | Checkliste |
| **Lager** | ⬜ Noch kein Asset | 4m × 4m | Checkliste |
| **Schlafraum/Bett** | ⬜ Noch kein Asset | 3m × 2m | Checkliste |
| **Feld** | ✅ Asset vorhanden (`feld.glb`, 2026-08-04) | — (Platzhalter war 2,5×2,5m) | fertig |
| **Außenposten** | ⬜ Noch kein Asset | 3m × 3m | Checkliste |
| **Wachturm** (eigene Struktur, NICHT derselbe wie "Wachposten" oben!) | ⬜ Noch kein Asset | ~1,5m × 1,5m Grundfläche, ~6m hoch (schmaler Turm) | **Achtung:** Checkliste listet "4m×4m×6m", das wirkt aber vertauscht (ein Turm sollte schmal+hoch sein, nicht 4×4 breit) — der aktuelle Platzhalter im Code ist bereits schmal+hoch (1,2×1,2m Grundfläche, 5m hoch), daran orientieren statt an der Checklisten-Zahl |

---

## 3. Fahrzeuge

| Typ (Code-Name) | Ziel-Maße (L=Blender Y × B=Blender X × H=Blender Z) | Quelle |
|---|---|---|
| **car** | ~4,5m × 1,8m × 1,5m | Eigener Vorschlag (normaler PKW, zwischen Checkliste "Jeep" 4,5×1,8×1,8 und "Van" 5×2,2×2,5) |
| **motorcycle** | 2m × 0,8m × 1,2m | Checkliste ("Motorrad", exakte Übereinstimmung) |
| **truck** | 5,5m × 2m × 2m | Checkliste ("Pickup-Truck") |

Nur diese drei Typen existieren aktuell im Code (`Vehicle.VEHICLE_STATS`).
Alle anderen Checklisten-Fahrzeuge (Van, Fahrrad, Schubkarre) sind NICHT
implementiert, aktuell nicht gebraucht.

---

## 4. Einheiten

| Einheit | Ziel-Maße (Höhe=Blender Z × Kapsel-Ø=Blender X/Y) | Quelle | Status |
|---|---|---|---|
| **Survivor** | 1,7m × 0,3m Radius (0,6m Ø) | Checkliste (exakte Übereinstimmung mit aktuellem Platzhalter) | ⬜ |
| **Zombie Standard** | 1,7m × 0,3m Radius | Checkliste (exakte Übereinstimmung) | 🟨 laut Checkliste in Arbeit |
| **Zombie Brute** | 2,1m × 0,4m Radius | Checkliste (exakte Übereinstimmung) | ⬜ |

Bei den Einheiten UND Fahrzeugen passt die Checkliste schon gut zu den
aktuellen Platzhalter-Maßen — nur bei den GEBÄUDEN klafft die Lücke
(Platzhalter oft 4-9× kleiner als die Checkliste), siehe Absprache
2026-08-04.

---

## 5. Umgebungs-Props (Ressourcenknoten)

Bisher in keiner Checkliste erfasst (2026-08-04 ergänzt, siehe
`Infos/08 Weg zur 1.0.md`, Abschnitt 6) — Zielmaße direkt aus den
aktuellen Platzhalter-`.tscn`-Dateien abgelesen (`BoxShape3D`/
`SphereShape3D`/`CylinderShape3D`-Größe), da es keine Vision-Vorgabe
dazu gibt. Empfehlung: möglichst nah an diesen Maßen bleiben, sonst
müssen Collision/Boden-Y-Konstanten (`World.TREE_GROUND_Y`/
`CAR_WRECK_GROUND_Y`/`STONE_PILE_GROUND_Y`/`BRICK_PILE_GROUND_Y`) beim
Einbauen angepasst werden (gleiches Vorgehen wie beim Wohnhaus, wenn die
tatsächlichen Maße abweichen).

| Prop | Ziel-Maße (B=Blender X × T=Blender Y × H=Blender Z) | Status |
|---|---|---|
| Ziegelhaufen | 1,4m × 1,4m × 0,5m | ✅ **Echtes Asset im Spiel** (`ziegelhaufen.glb`, 2026-08-04, Maße passten fast exakt) |
| Steinhaufen | ~1,2m Durchmesser × 0,6-0,8m hoch | ✅ **Echtes Asset im Spiel** (`steinehaufen.glb`, 2026-08-04, Größe nicht extra bestätigt) |
| Autowrack | 1,6m × 3,0m × 0,7m | ⬜ Platzhalter (Box) |
| Baum | ~1,8m Durchmesser (Krone) × 2,6m hoch | ✅ **Echtes Asset im Spiel** (`tannenbaum.glb`, 2026-08-04, Größe nicht extra bestätigt) |

Ziegel-/Steinhaufen sind bewusst klein/kniehoch (Ressourcen-Prop zum
Abbauen, kein Blickfang), Autowrack liegt quer (lang in der Tiefe, wie
ein geparktes/verunfalltes Fahrzeug).

## Nicht in dieser Liste (Vision, aber noch nicht im Code)

Aus `03 Asset-Checkliste.md`, aktuell NICHT implementiert, deshalb hier
bewusst weggelassen (nicht planlos mitbauen, erst wenn tatsächlich
gebraucht): Werkstatt/Baumarkt (Loot-Gebäude, bewusst ausgelassen —
Baumaterial soll nicht aus Stadt-Loot kommen), Elektronikgeschäft,
Auto-Werkstatt, Stromgenerator, Garten-Anlage/Palisaden (Zonen-Bauten aus
der Vision, zurückgestellt), Van/Kleinbus, Fahrrad, Schubkarre.

---

## Modellier-Prompt: Wohnhaus (zuerst zu bauen)

Beschreibung als Vorlage für Blender — kein KI-Bild-Prompt, sondern ein
Design-Briefing für dich selbst beim Modellieren, siehe "Empfehlung für
die Reihenfolge" ganz oben.

**Ziel-Maße (siehe Blender-Achsen-Konvention oben):**
Dimensions X=9m (Breite) × Y=8m (Tiefe) × Z=7m (Höhe). Polybudget
~3000–4000 Tris (Checkliste). Location/Rotation bei 0/0/0, Scale bei 1
lassen — nur Dimensions anpassen.

**Gebäudetyp:** Freistehendes, einfaches Vorstadt-Einfamilienhaus,
ein bis eineinhalb Stockwerke wirkend (die 7m Höhe kommen realistisch
eher aus Erdgeschoss + Satteldach als aus zwei vollen Stockwerken —
ein Vollgeschoss ist üblich ~2,5–3m, der Rest ist Dachfirst).

**Form/Silhouette:** Rechteckiger Baukörper, Satteldach (Giebeldach) als
markanteste Form — WICHTIG für die Top-Down/Isometrie-Kamera (siehe
`01 Architektur.md`): die Dachform ist aus der Vogelperspektive das
Erste, was man vom Gebäude sieht, sollte also klar als "Haus" erkennbar
sein, nicht als flache Box. Ein kleiner Vorbau/Vordach über der Haustür
ist ein günstiger Low-Poly-Blickfang, sonst keine weiteren Anbauten
(Balkon, Garage etc. — bleibt Low-Poly und im Polybudget).

**Öffnungen:** Eine Haustür (Front), 2–4 einfache rechteckige Fenster
verteilt auf die Fassaden — reine Grundformen (Extrusion/Boolean einer
Box), keine Fenstersprossen oder Beschläge im Detail.

**Farbe/Material:** Passend zum Low-Poly-Stil (siehe
`02 Assets mit Blender.md`, "Stilrichtung") — flache Vertex-/Material-
Farben, keine Fototexturen. Gedeckte, leicht verblasste Töne (z. B.
verwittertes Beige/Grau-Braun für die Fassade, dunkleres Rot-Braun oder
Grau fürs Dach) — soll nach Jahren ohne Instandhaltung aussehen (Setting:
verlassene Stadt nach dem Ausbruch), aber KEINE zusätzliche Verfalls-
Geometrie (keine kaputten Fenster/Löcher als eigene Meshes — das
Alters-Gefühl kommt rein über die Farbwahl, nicht über zusätzliche Polys).

**Referenz:** grober Stilvergleich Kenney "Suburban House"/"Building Kit"
(siehe `02 Assets mit Blender.md`, "Alternative/Ergänzung") — falls eine
visuelle Orientierung hilft, ohne selbst danach zu modellieren.

---

Verwandt: [[03 Asset-Checkliste.md]] · [[02 Assets mit Blender.md]] ·
[[04 Straßen-Kacheln Modellier-Referenz.md]]
