extends StaticBody3D
## Mauer/Tor — blockiert Bewegung, siehe docs/walls.md. Ein Skript für
## beide (is_gate unterscheidet), weil sich nur Kosten/Blockier-Regel/Farbe
## unterscheiden, nicht die Grundmechanik (HP, Zerstörbarkeit). Baut auf dem
## Bau-Muster von GuardPost.gd auf (Baumodus + Weltklick, siehe
## docs/building.md), host-autoritativ wie Survivor/Zombie/GuardPost.
## `collision_layer = 2` im .tscn (statt Standard-Layer 1) — eigene
## Physik-Ebene, damit die Blockier-Raycasts in Survivor.gd/Zombie.gd
## gezielt nur Mauern/Tore treffen, nicht Boden/Gebäude/Einheiten.

const WALL_MAX_HP := 150
const GATE_MAX_HP := 100

@export var is_gate: bool = false
var wall_id: int = 0
var owner_peer_id: int = 1
var hp: int = 0


func _ready() -> void:
	hp = GATE_MAX_HP if is_gate else WALL_MAX_HP
	_update_color()


func blocks(requesting_peer_id: int) -> bool:
	# Mauern blockieren jeden, auch die eigenen Trupps (siehe docs/walls.md
	# — genau deshalb braucht es das Tor). Tore lassen nur Trupps mit
	# passender owner_peer_id durch; Zombies haben nie eine, werden also
	# immer blockiert (Zombie.gd ruft blocks() gar nicht erst auf, siehe
	# dort).
	if is_gate:
		return requesting_peer_id != owner_peer_id
	return true


func take_damage(amount: int) -> void:
	# Kein RPC — wird ausschließlich host-seitig aufgerufen (von Zombie beim
	# Durchbrechen, siehe docs/zombies.md). Kein eigenes _process() (Mauer
	# bewegt sich nicht), darum Sync nur bei tatsächlicher Änderung statt
	# jeden Frame — analog zu GuardPost._sync_worker_count().
	var new_hp: int = max(hp - amount, 0)
	_sync_hp.rpc(new_hp)
	if new_hp <= 0:
		_die.rpc()


@rpc("authority", "call_local", "reliable")
func _sync_hp(new_hp: int) -> void:
	hp = new_hp
	_update_color()


@rpc("authority", "call_local", "reliable")
func _die() -> void:
	queue_free()


func _update_color() -> void:
	# Seit dem Holzmauer-Asset (siehe docs/building.md) hat NUR Wall.tscn
	# ein "Model"-Kind (Gate.tscn bleibt bei der Platzhalter-Box, eigene,
	# separate Szene mit demselben Script) — Fallback auf die alte
	# Einzel-Mesh-Logik, falls kein Model existiert, damit Tore weiterhin
	# ihre HP-Farbe bekommen.
	var max_hp := GATE_MAX_HP if is_gate else WALL_MAX_HP
	var ratio: float = float(hp) / float(max_hp)
	var base_color := Color(0.55, 0.4, 0.22) if is_gate else Color(0.4, 0.38, 0.35)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color.lerp(Color(0.05, 0.05, 0.05), 1.0 - ratio)
	var model := get_node_or_null("Model")
	if model != null:
		for mesh in _find_mesh_instances(model):
			mesh.set_surface_override_material(0, mat)
		return
	var mesh: MeshInstance3D = get_node_or_null("Mesh")
	if mesh != null:
		mesh.set_surface_override_material(0, mat)


func _find_mesh_instances(node: Node) -> Array:
	# Rekursiv, siehe GuardPost.gd (dieselbe Begründung, bewusst dupliziert
	# statt geteilt — siehe docs/building.md, "Bewusst dupliziert statt
	# geteilt").
	var result: Array = []
	if node == null:
		return result
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result
