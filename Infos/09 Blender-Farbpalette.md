---
tags:
  - spiel
  - godot
  - assets
  - blender
  - farben
status: aktiv
erstellt: 2026-08-04
---

# Blender-Farbpalette — für einen einheitlichen Look

Gedeckte, leicht verwitterte Töne (kein reines Weiß/Schwarz, keine
gesättigten "Comic"-Farben) — passt zum schon im Code verwendeten
Farbschema der Platzhalter-Boxen (`World.BUILDING_TYPES`, siehe Anker-Werte
unten) und zur allgemeinen "post-apokalyptische Vorstadt"-Stimmung. Als
Basis-Farbe im Blender-Material (Base Color, sRGB-Hex) einsetzen —
Rauheit/Metallic separat nach Material einstellen (Richtwerte in der
letzten Spalte).

## Wände (Putz/Verkleidung)

| Farbe | Hex | Rauheit | Metallic |
|---|---|---|---|
| Sandstein-Putz (hell) | `#C9B896` | 0.8 | 0 |
| Grauer Putz | `#A8A296` | 0.8 | 0 |
| Verwitterter Weißputz | `#D8D0BE` | 0.85 | 0 |
| Backstein, klassisch rot | `#A15C43` | 0.7 | 0 |
| Backstein, dunkel/verrußt | `#8C5A44` | 0.75 | 0 |
| Beton, hell | `#A8A399` | 0.75 | 0 |
| Beton, verwittert/fleckig | `#8C887C` | 0.8 | 0 |

## Holz (Bretter/Verkleidung/Zäune)

| Farbe | Hex | Rauheit | Metallic |
|---|---|---|---|
| Helles Holz (neu/frisch) | `#C9A66B` | 0.6 | 0 |
| Mittleres Holz (verwittert) | `#9C7A4E` | 0.65 | 0 |
| Dunkles Holz (alt/feucht) | `#5E4632` | 0.7 | 0 |
| Graues Altholz (unbehandelt) | `#7D7666` | 0.75 | 0 |
| Schwarzbraunes Holz (verkohlt) | `#3B2E22` | 0.8 | 0 |

## Dächer

| Farbe | Hex | Rauheit | Metallic |
|---|---|---|---|
| Dachziegel, rot | `#8C4A3B` | 0.7 | 0 |
| Dachziegel, verwittert/bräunlich | `#6E4A3C` | 0.75 | 0 |
| Schindeln/Schiefer, grau | `#5A5C5E` | 0.65 | 0 |
| Kupferdach, oxidiert/grün | `#4E6E5E` | 0.5 | 0,3 |
| Bitumen/Teerpappe, dunkel | `#2E2C2A` | 0.6 | 0 |

## Türen/Fenster/Rahmen

| Farbe | Hex | Rauheit | Metallic |
|---|---|---|---|
| Alte Holztür, braun | `#4A3826` | 0.6 | 0 |
| Abgeblätterte weiße Farbe | `#B8B5A8` | 0.7 | 0 |
| Dunkelgrüne Holztür (klassisch) | `#3E4A36` | 0.55 | 0 |
| Verrostetes Metalltor | `#5C4A3E` | 0.6 | 0,2 |
| Fensterglas, schmutzig (falls kein echtes Glas-Material) | `#6E7A78` | 0.3 | 0 |

## Metalle (sauber)

| Farbe | Hex | Rauheit | Metallic |
|---|---|---|---|
| Stahl/Zink, hell | `#9AA0A3` | 0.4 | 0,8 |
| Aluminium | `#B8BCBE` | 0.35 | 0,85 |
| Stahl, dunkel/brüniert | `#4E5254` | 0.45 | 0,7 |

## Metalle (Rost/verwittert)

| Farbe | Hex | Rauheit | Metallic |
|---|---|---|---|
| Hellrost | `#9C5A3C` | 0.75 | 0,15 |
| Mittlerer Rost | `#7A4A2E` | 0.8 | 0,1 |
| Dunkler Rost (fast schwarz) | `#4A3222` | 0.85 | 0,05 |
| Rost-Streifen (heller Akzent, für Verläufe) | `#B87249` | 0.7 | 0,1 |

## Boden/Umgebungs-Akzente

| Farbe | Hex | Rauheit | Metallic |
|---|---|---|---|
| Asphalt/Straße | `#4A4A48` | 0.8 | 0 |
| Moos/Algen (an Wänden/Dach) | `#5C6E4A` | 0.85 | 0 |
| Grünspan/Verwitterung (Akzent) | `#6E8C7A` | 0.8 | 0 |
| Erde/Dreck (Sockel-Verschmutzung) | `#4A3C2E` | 0.9 | 0 |

## Bereits im Spiel verwendete Anker-Farben (zum Abgleichen)

Diese Werte stecken schon als Platzhalter-Fassadenfarben im Code
(`World.BUILDING_TYPES`) — falls ein Gebäude farblich zum jetzigen
Platzhalter passen soll, bevor es ausgetauscht wird:

| Gebäude | Hex |
|---|---|
| Wohnhaus/Supermarkt | `#73614D` |
| Apotheke/Klinik | `#665947` |
| Waffenladen/Polizeistation | `#755C42` |
| Privatbunker | `#333338` |
| Feuerwehrstation | `#99261F` |
| Tankstelle | `#A68C26` |
| Garten-Center | `#4D8040` |

**Faustregel fürs Modellieren:** 2-3 Farben pro Gebäude reichen
(Hauptwand + Dach + Tür/Rahmen), plus optional EINEN Rost-/Moos-Akzent an
Kanten/Ecken für den "verwittert"-Look — nicht mehr, sonst wirkt es
unruhig statt einheitlich.
