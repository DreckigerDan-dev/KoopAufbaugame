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

**Wichtig für die Reihenfolge:** Straßenraster/Bauplatz-Abstände werden
erst final ans erste gelieferte Gebäude angepasst (siehe Absprache
2026-08-04) — am besten mit **Wohnhaus** anfangen (kleinstes der
Loot-Gebäude, Checkliste selbst nennt es als Phase-1-Priorität).

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
| 1 | Wohnhaus | 9m × 8m | Checkliste | **HIGH — zuerst bauen** |
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
| **Feld** | ⬜ Noch kein Asset | 6m × 4m | Checkliste ("Farm/Garten-Anlage", gleiche Funktion: Nahrung-Produktion) |
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

## Nicht in dieser Liste (Vision, aber noch nicht im Code)

Aus `03 Asset-Checkliste.md`, aktuell NICHT implementiert, deshalb hier
bewusst weggelassen (nicht planlos mitbauen, erst wenn tatsächlich
gebraucht): Werkstatt/Baumarkt (Loot-Gebäude, bewusst ausgelassen —
Baumaterial soll nicht aus Stadt-Loot kommen), Elektronikgeschäft,
Auto-Werkstatt, Stromgenerator, Garten-Anlage/Palisaden (Zonen-Bauten aus
der Vision, zurückgestellt), Van/Kleinbus, Fahrrad, Schubkarre.

---

Verwandt: [[03 Asset-Checkliste.md]] · [[02 Assets mit Blender.md]] ·
[[04 Straßen-Kacheln Modellier-Referenz.md]]
