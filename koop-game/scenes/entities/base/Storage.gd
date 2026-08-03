extends StaticBody3D
## Lager — erhöht einmalig die Speicherkapazität der eigenen Home-Base
## (siehe docs/building.md, "Lager"). Reiner Datenträger wie
## MedicalStation.gd/Workshop.gd, kein eigenes Verhalten außer der
## einmaligen Kapazitäts-Gutschrift bei Erstellung. capacity_bonus wird
## VOR dem eigentlichen Spawnen berechnet (World.finish_construction(),
## aus dem Volumen des ausgebauten Gebäudes) und hier nur noch angewendet.

var storage_id: int = 0
var owner_peer_id: int = 1
var capacity_bonus: int = 0


func _ready() -> void:
	# Nur der Host trägt die Kapazität ein — _ready() läuft auf JEDEM Peer
	# (der Node wird per MultiplayerSpawner überall erzeugt), ohne diesen
	# Guard würde add_storage_capacity() so oft aufgerufen wie es Peers
	# gibt.
	if not multiplayer.is_server():
		return
	var base := _find_home_base()
	if base != null:
		base.add_storage_capacity.rpc(capacity_bonus)


func _find_home_base() -> Node3D:
	# Eine Home-Base pro Peer (siehe docs/base.md) — gleiches Muster wie
	# Survivor._find_home_base()/Field._find_home_base().
	for base in get_tree().get_nodes_in_group("home_base"):
		if base.owner_peer_id == owner_peer_id:
			return base
	return null
