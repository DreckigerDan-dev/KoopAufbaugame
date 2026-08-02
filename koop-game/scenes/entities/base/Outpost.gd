extends StaticBody3D
## Außenposten — kleine, frei platzierbare Raststelle für Feldtrupps AUSSERHALB
## der eigenen Bauzone (siehe Infos/01 Architektur.md, "Außenposten":
## "Ausnahme von der Zusammenhang-Regel" — einziger Bautyp ohne
## is_within_own_zone()-Prüfung, siehe World._can_build_at()). Einzige
## aktuell umgesetzte Funktion: kürzerer Rückweg beim Scavenging — ein Trupp
## mit Loot läuft zum NÄHEREN von Home-Base/eigenem Außenposten zurück statt
## immer bis zur Basis (siehe Survivor._find_nearest_drop_off_point()). Kein
## eigener Ressourcen-Pool: add_resources() reicht direkt an die Home-Base
## des Besitzers durch — "Zwischenlagern" bedeutet hier nur einen kürzeren
## Weg, keine zweite Lager-Instanz (das deckt schon Storage/"Lager" ab,
## siehe docs/building.md). "Rasten/Schlafen" aus der Vision ist NOCH NICHT
## umgesetzt — braucht erst ein Müdigkeits-/Bedürfnissystem (Punkt 16 der
## Gesamtliste, siehe docs/status.md). Bewusst schlank wie MedicalStation:
## kein HP, kein Bautimer (kein "fertig gebaut"-Feedback nötig).

var outpost_id: int = 0
var owner_peer_id: int = 1


func add_resources(delta: Dictionary) -> void:
	# Kein eigener Ressourcen-Pool — reicht direkt an die Home-Base des
	# Besitzers durch (siehe Klassenkommentar oben). Aufgerufen von
	# Survivor._handle_carried_loot(), läuft schon host-seitig.
	var base: Node3D = get_tree().current_scene._find_home_base_for_peer(owner_peer_id)
	if base != null:
		base.add_resources.rpc(delta)
