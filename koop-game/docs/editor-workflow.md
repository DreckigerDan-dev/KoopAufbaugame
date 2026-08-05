# Editor-Workflow: Fixes von Claude sicher übernehmen + Werte selbst ändern

## Warum ein Fix manchmal "nicht wirkt", obwohl er in der Datei steht

Wenn `World.tscn` (oder eine andere Szene) gerade im Godot-Editor **offen**
ist, während Claude die Datei von außen (per Texteditor) ändert, merkt der
Editor das nicht automatisch. Der Editor spielt dann weiter mit seinem
eigenen, alten Stand im Arbeitsspeicher — man testet also die ALTE Version,
obwohl die Datei auf der Festplatte schon den Fix enthält. Speichert man
danach im Editor (Strg+S), wird sogar der alte Stand zurück auf die Platte
geschrieben und der Fix ist komplett weg (siehe die mehreren "vanished
parent"-Einträge in `status.md`).

**Faustregel, IMMER wenn Claude etwas an einer `.tscn`- oder `.gd`-Datei
geändert hat, die gerade offen ist:**

1. Den betroffenen Tab (z. B. `World.tscn`) im Godot-Editor **schließen**
   (Rechtsklick auf den Tab → "Schließen", oder Mittelklick auf den Tab).
2. Über die FileSystem-Liste links (oder Doppelklick in `scenes/world/`)
   die Datei **neu öffnen**.
3. Erst DANN testen (Play-Button bzw. F5/F6) oder weiter im Editor
   bearbeiten.

Wenn man stattdessen einfach nur erneut auf Play drückt, ohne den Tab neu
zu öffnen, läuft oft trotzdem noch der alte Stand.

## CanvasLayer-Reihenfolge ("Layer"-Wert) selbst prüfen/ändern

Konkretes Beispiel, Stand 2026-08-05: `HUD` (enthält u. a. die
"Wähle deine Start-Basis"-Meldung) soll IMMER hinter den anderen
UI-Ebenen liegen (`ResourcesUI`, `TopBarUI`, `TabColumnUI`, `MainTabsUI`,
`InfoBoxUI`), damit sein Text nicht durch offene Tab-Overlays durchscheint.
Gesteuert wird das über die `Layer`-Eigenschaft jedes `CanvasLayer`-Nodes
(kleinere Zahl = weiter hinten).

So prüft/ändert man das selbst im Editor:

1. `World.tscn` öffnen (siehe Regel oben, falls gerade extern geändert).
2. Im **Szenenbaum** (Scene-Dock, meist oben links) den Node `HUD`
   anklicken — er liegt direkt unter dem Wurzel-Node der Szene, gleiche
   Ebene wie `ResourcesUI`, `TopBarUI`, `TabColumnUI`, `MainTabsUI`,
   `InfoBoxUI`.
3. Im **Inspector** (rechts) nach unten scrollen zum Abschnitt
   **"CanvasLayer"** → Feld **"Layer"**.
4. Wert auf **`0`** setzen (Standard ist `1`).
5. Zur Kontrolle: `MainTabsUI` anklicken, im Inspector prüfen, dass dessen
   `Layer`-Feld **nicht** auf `0`, sondern auf `1` (oder höher) steht —
   damit malt es garantiert VOR (über) `HUD`.
6. Strg+S zum Speichern, dann testen.

Falls der Wert schon auf `0` steht (weil Claudes Fix schon in der Datei
war), reicht Schritt 1 (Tab schließen + neu öffnen) — dann ist der
vorhandene Wert automatisch aktiv, ohne dass man ihn nochmal von Hand
setzen muss.

## Allgemein: eine einzelne Eigenschaft eines Nodes im Inspector ändern

Dasselbe Muster funktioniert für so gut wie jede Eigenschaft, die Claude
in einer `.tscn`-Datei ändert (z. B. `visible`, `offset_left`,
`theme_override_font_sizes/font_size`, `tabs_visible`):

1. Node im Szenenbaum anklicken.
2. Im Inspector das passende Feld suchen (Suchleiste oben im Inspector
   hilft bei langen Listen — z. B. "layer" oder "font size" eintippen).
3. Wert eintragen, Enter drücken.
4. Strg+S.

So kann man kleine, von Claude beschriebene Korrekturen notfalls auch
ohne Textdatei-Bearbeitung selbst nachvollziehen oder gegenprüfen.
