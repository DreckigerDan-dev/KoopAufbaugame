extends StaticBody3D
## Baubares Gebäude: erweitert die Heilzone der eigenen Basis, siehe
## docs/survivor.md, "Heilung" — Trupps in der Nähe heilen schneller als
## nur an der Basis. Bewusst schlank: kein HP (wie GuardPost, siehe
## docs/building.md, "Bekannte Grenzen"), kein Bautimer (anders als
## GuardPost — hier gibt es kein "fertig gebaut"-Feedback wie Feuern, das
## eine Baufortschritts-Animation rechtfertigen würde). Gruppe
## "medical_station" wird über den `.tscn`-Node-Header gesetzt (siehe
## docs/3d-migration.md für den Grund).

var medical_station_id: int = 0
var owner_peer_id: int = 1
# Erweiterte Krankenstation (Punkt 24 der Gesamtliste, Forschungsbücher
# schalten jetzt auch Gebäude-Ausbaustufen frei, nicht nur Crafting-
# Rezepte — siehe docs/building.md, "Erweiterte Krankenstation"). Heilt
# schneller (siehe Survivor._handle_healing()), sonst funktional
# identisch — kein zweiter Gebäudetyp, nur ein Flag auf derselben Node.
var is_advanced: bool = false


@rpc("authority", "call_local", "reliable")
func upgrade_to_advanced() -> void:
	# Von World.request_upgrade_medical_station() aufgerufen (host-seitig,
	# schon geprüft: erforscht + bezahlt) — kein eigener RPC-Guard hier
	# nötig, gleiches Vertrauensmodell wie Building.set_claimed_owner().
	is_advanced = true
