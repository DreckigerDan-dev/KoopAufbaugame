---
tags:
  - spiel
  - godot
  - assets
  - blender
status: aktiv
erstellt: 2026-08-01
aktualisiert: 2026-08-02
---

# Straßen-Kacheln — genaue Modellier-Vorgaben

Konkrete Maße/Ausrichtung/Namensgebung für die 5 Tiles aus dem
Kartenplanungs-Anschluss-Auftrag (GridMap-Umbau, siehe Claude-Memory
`koopgame_street_tiles_assets`). Diese Datei ist die **verbindliche
Referenz** dafür, wie der Code die Tiles später erwartet — beim
Modellieren genau danach richten, sonst passt die spätere
Rotations-Logik nicht.

**Update 2026-08-02:** die erste Asset-Fassung hatte genau die Probleme,
vor denen Abschnitt 1 unten warnt (Maße nicht exakt 12×12, Höhe pro Kachel
unterschiedlich, Ursprung vermutlich nicht an der Unterseite) — sichtbar
als Clipping/Spalt zwischen Kacheln und als über dem Boden schwebende
Straße im Spiel. Abschnitt 1 jetzt mit den konkreten Arbeitsschritten
ergänzt, nicht nur der Anforderung.

---

## 1. Grundmaß & Ursprung (gilt für ALLE 5 Tiles) — Schritt für Schritt

**Reihenfolge einhalten, jeder Schritt setzt den vorherigen voraus:**

1. **Alle Teile zu einem Objekt verschmelzen** (falls die Kachel aus
   mehreren Meshes besteht): alle Teile auswählen, `Strg+J`.
2. **Transforms anwenden:** Objekt auswählen, `Strg+A` → "Alle
   Transformationen" (Position/Rotation/Skalierung auf 0°/0/1,0 zurück).
   **Muss VOR Schritt 3 passieren**, sonst verzerrt eine noch aktive
   Skalierung die gleich gesetzten Maße wieder.
3. **Exakte Maße setzen** — Seitenpanel (`N`) → Reiter "Element" →
   **Abmessungen**. Achtung, Achsen-Falle beim Ablesen: Blender ist
   Z-up, Godot ist Y-up, der `.glb`-Export rechnet das automatisch um:
   - Blender **X** und **Y** (Grundfläche, im Top-View das Bild) →
     werden zu Godot X/Z → beide auf exakt **12.000** tippen.
   - Blender **Z** (Höhe) → wird zu Godot Y → bei **allen 4
     Straßentypen denselben Wert** eintragen (z. B. `0.25`) — nicht nur
     "ungefähr ähnlich", exakt gleich, sonst gibt's an der gemeinsamen
     Kante zweier Straßentypen einen sichtbaren Mini-Stufen-Spalt
     (genau das Problem vom 2026-08-02-Test: 0.25 vs. 0.251817 vs.
     0.25 vs. 0.251817 zwischen den vier Typen). Gras darf eine andere
     Dicke haben (eigene Bodenebene, kein direkter Kanten-Kontakt zur
     Straßenmitte).
   - Nach dem Eintippen kurz nachprüfen, ob die Zahl wirklich stehen
     geblieben ist (Blender rundet manchmal sichtbar, rechnet aber intern
     mit der eingetippten Zahl weiter — im Zweifel nochmal reinklicken
     und exakten Wert ablesen).
4. **Ursprung auf die Unterseiten-Mitte legen** (behebt "Kachel schwebt
   über dem Boden"): Godots `GridMap` (`cell_center_y = false`) geht davon
   aus, dass der Objekt-Ursprung an der UNTERSEITE der Kachel liegt, nicht
   in der Mitte (was Blender nach dem Modellieren oft automatisch so
   gesetzt hat).
   - Edit Mode → Unterseiten-Fläche auswählen.
   - `Umschalt+S` → "Cursor zu Selektion" (3D-Cursor springt auf die
     Mitte der Unterseite).
   - Zurück in Object Mode → Objekt-Menü → "Ursprung festlegen" →
     "Ursprung auf 3D-Cursor".
   - Kontrolle: die Kachel erstreckt sich danach in Blender von Z=0
     (unten, = Ursprung) bis Z=Höhe (oben), und von X=-6 bis X=+6,
     Y=-6 bis Y=+6 (bei 12m Kante).
5. **Export** — Datei → Exportieren → glTF 2.0 (`.glb`), "+Y Up" aktiv
   (Standard, macht die Achsen-Umrechnung), nur das jeweilige Objekt
   ausgewählt exportieren, gleicher Dateiname wie vorher (überschreiben —
   Namen selbst sind unkritisch, das Godot-Skript `tools/
   fix_meshlib_names.gd` hat feste Pfade/Namen hinterlegt; falls ein
   Dateiname sich ändert, kurz Bescheid geben, dann pass ich die Pfade im
   Skript an).
- Referenzgröße zum Augenmaß: ein Survivor ist 1,70m hoch — die
  Kachelkante (12m) ist also ca. 7× so lang wie ein Survivor hoch ist.

### Danach in Godot prüfen

`tools/fix_meshlib_names.gd` im Skripteditor ausführen (Datei →
Ausführen). Das Skript gibt pro Kachel jetzt auch die tatsächlichen Maße
aus (`Item X: "..." <- ... — Maße: (x, y, z)`) — damit lässt sich sofort
gegenprüfen, ob alle 4 Straßentypen wirklich exakt `(12.0, <gleiche
Höhe>, 12.0)` melden, ohne in Blender nachmessen zu müssen. Falls die
Zahlen noch abweichen: zurück zu Schritt 2/3 oben.

---

## 2. Ausrichtung: Blender-Draufsicht = Landkarte

**Wichtigste Regel:** beim Modellieren die **Blender-Draufsicht von oben**
benutzen (Numpad 7 = Top View, man blickt die Z-Achse entlang nach
unten) und sich das wie eine Landkarte vorstellen:

| Im Bild (Top View) | Blender-Achse | Wird nach dem Export zu (Godot) |
|---|---|---|
| **Oben** im Bild = Norden | +Y | −Z |
| **Unten** im Bild = Süden | −Y | +Z |
| **Rechts** im Bild = Osten | +X | +X |
| **Links** im Bild = Westen | −X | −X |

(Der Export mit aktivem "+Y Up" — Standardeinstellung, siehe
`02 Assets mit Blender.md` — rechnet das automatisch um, das ist reine
Blender-interne Bedienung, ihr müsst euch beim Modellieren nur an
"oben=Norden, rechts=Osten" halten.)

**Warum das wichtig ist:** der Code dreht die Kacheln später automatisch
in 90°-Schritten, je nachdem wie viele Nachbar-Straßen an einer Zelle
hängen. Damit das stimmt, MUSS jede Kachel in genau EINER festgelegten
Grundausrichtung gebaut werden (unten beschrieben) — der Code geht davon
aus, dass "0° Drehung" exakt dieser Ausrichtung entspricht.

---

## 3. Die 5 Tiles — genaue Ausrichtung + Dateiname

Exportname **exakt so** (ohne `.glb`-Endung wird zum Namen in der
MeshLibrary, den der Code später per `find_item_by_name()` sucht):

### `grass.glb`
Keine Richtung nötig — reine Boden-/Gras-Textur, darf beliebig aussehen
(z. B. leichte Unebenheiten/Farbvariation für Bodendetail).

### `road_straight.glb`
Straße läuft **Nord-Süd** (oben-unten im Top-View) durch die Mitte der
Kachel, ca. 8m breit. Links und rechts (Ost/West-Kante) bleibt ca. 2m
Rand (Gras/Gehweg), dort führt KEINE Straße zur Kante.

### `road_corner.glb`
Straße verbindet **Norden und Osten** (kommt von oben ins Bild rein,
biegt nach rechts ab) — Süd- und West-Kante bleiben ohne Straße
(Gras/Gehweg). Bildlich: eine Straßen-Kurve oben-rechts im Bild.

### `road_t.glb`
Straße verbindet **Norden, Osten UND Westen** (durchgehende Ost-West-
Straße MIT einer Abzweigung nach oben/Norden) — nur die **Süd-Kante**
bleibt ohne Straße. Bildlich: ein "⊥"-Straßenkreuz mit der fehlenden
Richtung nach unten im Bild.

### `road_cross.glb`
Straße verbindet **alle 4 Himmelsrichtungen** (Norden, Osten, Süden,
Westen) — klassische 4-Wege-Kreuzung, in der Mitte ein Straßen-
"Plus"-Zeichen. Keine Rotation nötig (sieht aus allen 4 Seiten gleich
aus), aber trotzdem exakt zentriert modellieren wie die anderen.

---

## 4. Falls die Ausrichtung im Spiel doch nicht stimmt

Das ist kein Beinbruch — falls beim ersten Test eine Kachel um 90°
verdreht aussieht (z. B. eine Kurve öffnet sich zur falschen Seite),
ist das eine EINZEILIGE Korrektur im Code (eine Zahl in einer
Zuordnungs-Tabelle), kein erneutes Modellieren nötig. Also: nicht zu
sehr stressen lassen, wenn die Nord/Ost-Zuordnung mal nicht zu 100%
sitzt — einfach Bescheid geben, sobald es im Spiel sichtbar ist, dann
korrigiere ich das in Sekunden.

**Bereits passiert (2026-08-02):** `road_straight` sah im ersten Test um
90° verdreht aus (Fahrbahnmarkierung quer statt längs zur Straße). Fix war
genau das oben beschriebene — eine Zeile in `World.gd`
(`_place_street_tile()`, `rotation_steps` für `road_straight` umgedreht).
Corner/T/Cross waren beim selben Test schon korrekt, kein Korrekturbedarf
dort. Kein Grund, deswegen an dieser Doku oder am Modell etwas zu ändern —
der Code ist jetzt an das tatsächliche Modell angepasst.

---

Verwandt: [[Koop aufbaugame/02 Assets mit Blender.md]] ·
[[Koop aufbaugame/03 Asset-Checkliste.md]]
