---
tags:
  - spiel
  - godot
  - assets
  - blender
  - checkliste
status: aktiv
erstellt: 2026-07-30
---

# Asset-Checkliste für KoopGame

Alle 3D-Modelle, die mit Blender gebaut werden müssen. Größen in echten Metern.
Exportformat: **glTF 2.0 Binary (.glb)** — alle Assets in `assets/models/`.

---

## EINHEITEN (beweglich, häufig sichtbar)

| Asset | Maße (HxBxT) | Polys | Status | Priorität |
|-------|--------------|-------|--------|-----------|
| **Survivor** | 1,7m × 0,4m × 0,3m | ~800–1200 | ⬜ | HIGH |
| **Zombie Standard** | 1,7m × 0,4m × 0,3m | ~800–1200 | 🟨 In Arbeit | HIGH |
| **Zombie Brute** | 2,1m × 0,5m × 0,4m | ~1000–1500 | ⬜ | MEDIUM |

---

## GEBÄUDE - Plünderbar (Stadt)

> [!info] Item-Integration
> Diese Gebäude sind in der **[[Koop aufbaugame/02 Item-Liste.md]]** dokumentiert.
> Jedes Gebäude hat einen **Haupt-Loot** (garantiert/häufig) + **Nebenloot** (Chancen).
> Ein Gebäude bleibt nach dem Plündern leer (kein Respawn).

| Asset | Maße (HxBxT) | Polys | Haupt-Loot | Nebenloot | Priorität | Status |
|-------|--------------|-------|-----------|-----------|-----------|--------|
| **Wohnhaus** | 7m × 9m × 8m | ~3000–4000 | 1–2× Nahrung | Medizin (30%), Buch (10%), Werkzeuge (20%) | HIGH | ⬜ |
| **Supermarkt** | 4,5m × 18m × 12m | ~3500–5000 | 3–5× Nahrung | Wasser (40%), Getränke (30%) | MEDIUM | ⬜ |
| **Apotheke** | 4,5m × 7m × 6m | ~2500–3500 | 2–3× Medizin | Schmerzmittel (50%), Antibiotika (15%) | MEDIUM | ⬜ |
| **Waffenladen/Polizeistation** | 5m × 10m × 8m | ~3000–4000 | 1× Waffe *(60% Pistole, 30% Schrotflinte, 10% Karabiner)* | Munition (50%), Rüstung (40%), Helm (30%) | MEDIUM | ⬜ |
| **Werkstatt/Baumarkt** | 6m × 16m × 10m | ~3500–5000 | 2–3× Baumaterial | Werkzeuge (60%), Ersatzteile (30%), Sprengstoff (10%) | MEDIUM | ⬜ |
| **Jagdstand** | — (Map-abhängig) | ~2000–3000 | 1× Jagdgewehr *(80% .308, 20% Schrotflinte)* | Munition .308 (60%), Fernglas (30%) | MEDIUM | ⬜ |
| **Militärbasis** | — (Map-abhängig) | ~3500–5000 | 1× Gewehr *(70% AR-15, 30% Sniper)* | Munition 5.56 (80%), Rüstung (50%), Buch (20%) | LOW | ⬜ |
| **Elektronikgeschäft** | 4m × 8m × 6m | ~2000–3000 | 1× Elektronik *(50% Taschenlampe)* | Nachtsichtgerät (20%), Leitungs-Kit (10%) | LOW | ⬜ |
| **Feuerwehrstation** | 5m × 12m × 8m | ~2500–3500 | 1× Feuerwehr-Anzug | Medizin (50%), Ausrüstung (40%) | LOW | ⬜ |
| **Restaurant/Kneipe** | 4m × 8m × 7m | ~2000–3000 | 2–3× Nahrung | Getränke (70%), Medizin (20%) | LOW | ⬜ |
| **Tankstelle** | 3m × 6m × 5m | ~1500–2000 | 1–2× Getränke | Ersatzteile (40%), Wasser (50%) | LOW | ⬜ |
| **Bibliothek** | 6m × 10m × 8m | ~2500–3500 | 1–2× Bücher | weitere Bücher (40%), Medizin (20%) | MEDIUM | ⬜ |
| **Universitäts-Gebäude** | 7m × 12m × 10m | ~3000–4000 | 1–2× Bücher *(spezialisiert)* | weitere Bücher (40%) | LOW | ⬜ |
| **Privatbunker** | 5m × 8m × 6m | ~2500–3500 | 1× Rare Waffe | Munition (80%), Rüstung (60%), Buch (30%) | LOW | ⬜ |
| **Auto-Werkstatt** | 5m × 14m × 10m | ~3000–4000 | 2–3× Ersatzteile | Stahlrahmen (40%), Baumaterial (30%), Motorrad-Leder (15%) | MEDIUM | ⬜ |
| **Garten-Center** | 4m × 10m × 8m | ~2000–3000 | Werkzeuge (Axt, Machete) | Bücher (Landwirtschaft) (20%) | LOW | ⬜ |
| **Camping-Laden** | 3m × 7m × 5m | ~1500–2000 | 1× Rucksack oder Ausrüstung (60%) | Taschenlampe (40%), Wasser-Flasche (50%) | LOW | ⬜ |

---

## GEBÄUDE - Zonen-Bauten (selbst konstruierbar)

> [!info] Crafting & Konstruktion
> Diese Gebäude sind **nicht plünderbar**, sondern in deiner Basis selbst gebaut.
> Siehe **[[Koop aufbaugame/02 Item-Liste.md]]** für Crafting-Rezepte und Ressourcen-Kosten.

| Asset | Maße (HxBxT) | Polys | Funktion | Kosten | Priorität | Status |
|-------|--------------|-------|----------|--------|-----------|--------|
| **Mauern/Barrikaden** | 2,5m × variabel × 0,3m | ~500–800/Segment | Zombie-Sperrung | 5× Holz/Segment | HIGH | ⬜ |
| **Wachposten** | 3,5m × 3m × 3m | ~1500–2000 | Auto-Schießstand | 10× Holz + 5× Stahlrahmen | HIGH | ⬜ |
| **Lager** | 3m × 4m × 4m | ~1500–2000 | Ressourcen-Speicher | 8× Holz + 3× Stahlrahmen | MEDIUM | ⬜ |
| **Betten/Schlafraum** | 3m × 3m × 2m | ~1000–1500 | Survivor-Regeneration | 6× Holz + 2× Baumaterial | MEDIUM | ⬜ |
| **Werkstatt (Bauen)** | 3m × 5m × 4m | ~1500–2000 | Crafting-Station | 10× Holz + 5× Stahlrahmen + Buch | MEDIUM | ⬜ |
| **Krankenstation** | 4m × 6m × 5m | ~2000–2500 | Heilen & Medizin | 8× Holz + 4× Baumaterial + Buch | MEDIUM | ⬜ |
| **Farm/Garten-Anlage** | 4m × 6m × 4m | ~1500–2000 | Nahrung-Produktion | 3× Holz + 2× Baumaterial + Buch | MEDIUM | ⬜ |
| **Stromgenerator** | 2m × 2m × 2m | ~1000–1500 | Elektrik-Versorgung | 5× Baumaterial + 2× Elektronik + Buch | MEDIUM | ⬜ |
| **Wachturm** | 4m × 4m × 6m | ~2500–3000 | Erweiterte Sicht | 12× Holz + 8× Stahlrahmen + 2× Bücher | MEDIUM | ⬜ |
| **Außenposten** | 3m × 3m × 3m | ~1500–2000 | Raststelle für Feldtrupps | 5× Holz + 3× Baumaterial | LOW | ⬜ |

---

## FAHRZEUGE (Transport & Expeditionen)

> [!info] Fahrzeug-Mechanik
> Fahrzeuge erhöhen **Trage-Kapazität** und **Bewegungsgeschwindigkeit**, erzeugen aber **Lärm** 
> (zieht Zombies an). Siehe [[Koop aufbaugame/02 Item-Liste.md]] für Details zu Ersatzteilen & Motorrad-Leder.

| Asset | Maße (LxBxH) | Passagiere | Kapazität | Lärm | Polys | Priorität | Status |
|-------|--------------|-----------|-----------|------|-------|-----------|--------|
| **Pickup-Truck** | 5,5m × 2m × 2m | 2 | +10 Slots | Laut | ~3000–4000 | LOW | ⬜ |
| **Van/Kleinbus** | 5m × 2,2m × 2,5m | 3–4 | +8 Slots | Mittel | ~3500–4500 | LOW | ⬜ |
| **Jeep** | 4,5m × 1,8m × 1,8m | 3 | +6 Slots | Mittel | ~2500–3500 | LOW | ⬜ |
| **Motorrad** | 2m × 0,8m × 1,2m | 1–2 | +3 Slots | Mittel | ~1500–2000 | LOW | ⬜ |
| **Fahrrad** | 2m × 0,7m × 1m | 1 | +2 Slots | Leise ✓ | ~800–1200 | LOW | ⬜ |
| **Schubkarre/Handwagen** | 1,5m × 0,8m × 1m | 0 (manuell gezogen) | +4 Slots | Leise ✓ | ~600–1000 | MEDIUM | ⬜ |

---

## UMGEBUNG

| Asset | Beschreibung | Polys | Status | Priorität |
|-------|--------------|-------|--------|-----------|
| **Boden/Terrain** | Flache Fläche, texturiert (Gras/Pflaster) | ~1000–2000 | ⬜ | LOW |
| **Straßen/Pfade** | Optional, später | variabel | ⬜ | LOW |

---

## HOME-BASE (Start-Gebäude)

| Asset | Maße (HxBxT) | Polys | Status | Priorität |
|-------|--------------|-------|--------|-----------|
| **Starter-Bunker/Haus** | ~6m × 6m × 5m | ~2000–3000 | ⬜ | HIGH |

---

## Phase-Empfehlung

### **Phase 1 — MVP (spielbar + visueller Wow-Effekt)**
1. ✅ **Zombie Standard** (in Arbeit)
2. **Survivor**
3. **Wohnhaus** (1 Plünder-Gebäude zum Testen)
4. **Starter-Bunker** (Home-Base)

→ **Ziel:** Basis sieht gut aus, Zombie + Survivor bewegen sich, ein Gebäude zum Plündern

### **Phase 2 — Gameplay-Komplettierung**
5. **Zombie Brute**
6. Weitere Gebäudetypen (Supermarkt, Apotheke, Waffenladen, Werkstatt)
7. **Zonen-Bauten** (Mauern, Wachposten, Lager, etc.)

### **Phase 3 — Transport & Expansion**
8. **Fahrzeuge** (Fahrrad/Schubkarre zuerst für "leise Transport", später Pickup/Van)
9. Weitere Gebäudetypen (Jagdstand, Militärbasis, etc.)

### **Phase 4 — Polish**
10. **Boden/Umgebung** (Terrain, Straßen)
11. Detail-Varianten, Dekoration

---

## Export-Checklist (vor jedem Export als .glb)

- [ ] Modell hat **echte Maße** (siehe Tabelle oben)
- [ ] **Polygon-Count** unter Budget (siehe Tabelle)
- [ ] **Material/Farbe** zugewiesen (mindestens Base Color)
- [ ] **Rotation/Scale anwenden:** `Ctrl+A` → Apply All Transforms
- [ ] **Export als glTF Binary (.glb)**
  - Format: `glTF Binary (.glb)` ✓
  - Include → Selected Objects ✓
  - Transform → +Y Up ✓

---

## UI-Elemente (2D — separate Task)

Diese gehören **nicht** zu den 3D-Blender-Assets:
- Waffen-Icons (Gewehr, Pistole, Axt, etc.)
- Item-Icons (Nahrung, Medizin, Munition, Baumaterial)
- Trupp-Portraits

→ werden später als 2D-Grafiken/UI gemacht, nicht in Blender.

---

Verwandt: [[Koop aufbaugame/02 Assets mit Blender.md]] · [[Koop aufbaugame/01 Architektur.md]]
