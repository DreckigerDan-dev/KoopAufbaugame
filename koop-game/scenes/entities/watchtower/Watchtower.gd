extends StaticBody3D
## Wachturm — frei platzierbares Gebäude mit reiner Sichtweiten-Funktion
## (Vision: "Erweiterte Sicht auf die Map, Zombie-Früherkennung"), Punkt 25
## der Gesamtliste. Vision unterscheidet den Wachturm (Sicht) explizit vom
## Wachposten/GuardPost.gd (Kampf, siehe docs/building.md) — bewusst KEIN
## Kampf, keine Waffe, kein Worker-Slot. Reine Fog-of-War-Quelle mit großem
## Radius (World.WATCHTOWER_VISION_RADIUS), siehe
## World._update_fog_of_war().
##
## "Zombie-Früherkennung" ist strukturell schon erfüllt, OHNE eigenen Code:
## Zombies werden auf Minimap/Kartenansicht IMMER gezeichnet, unabhängig
## vom Fog-of-War-Stand (siehe Minimap.gd/MapView.gd, `_draw_zombies()`) —
## der Wachturm liefert dafür einfach mehr aufgedecktes Terrain drumherum,
## in dem diese Zombie-Punkte überhaupt in Kontext (Straßen/Gebäude)
## sichtbar sind, statt im grauen Nebel zu schweben.
##
## Bewusst schlank wie Outpost.gd/MedicalStation.gd: kein HP, kein
## Bautimer, kein eigener Ressourcen-Pool.

var watchtower_id: int = 0
var owner_peer_id: int = 1
