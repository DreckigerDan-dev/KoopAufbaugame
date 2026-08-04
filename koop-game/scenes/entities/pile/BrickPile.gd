extends StaticBody3D
## Abbaubarer Ziegelhaufen — Ressourcenquelle für Bautrupps, siehe
## StonePile.gd für die ausführliche Begründung (ersetzt das frühere
## Ziegel-Loot aus Stadt-Gebäuden). Identisches Muster, andere
## Farbe/Ertrag/Mesh (siehe docs/survivor.md, "Ressourcen abbauen").

const MAX_HP := 50
const YIELD := {"brick": 15}

var pile_id: int = 0
var hp: int = MAX_HP
var is_marked: bool = false


func _ready() -> void:
	_update_color()


func toggle_marked() -> void:
	_set_marked.rpc(not is_marked)


@rpc("authority", "call_local", "reliable")
func _set_marked(marked: bool) -> void:
	is_marked = marked
	_update_color()


func take_damage(amount: int) -> void:
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
	# Echtes Asset (2026-08-04, siehe docs/scavenging.md, "Ziegelhaufen")
	# hat mehrere MeshInstance3D-Kinder (Einzelziegel) statt der einen
	# Platzhalter-Box — gleiches "alle Meshes einfärben statt nur eines"-
	# Muster wie GuardPost.gd/Wall.gd (siehe docs/building.md, "Wachturm +
	# Holzmauer"), hier bewusst dupliziert statt geteilt.
	var ratio: float = float(hp) / float(MAX_HP)
	var base_color := Color(0.9, 0.75, 0.1) if is_marked else Color(0.55, 0.25, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color.lerp(Color(0.15, 0.1, 0.08), 1.0 - ratio)
	var meshes := _find_mesh_instances(get_node_or_null("Model"))
	if meshes.is_empty():
		var mesh: MeshInstance3D = get_node_or_null("Mesh")
		if mesh != null:
			meshes = [mesh]
	for mesh in meshes:
		mesh.set_surface_override_material(0, mat)


func _find_mesh_instances(node: Node) -> Array:
	var result: Array = []
	if node == null:
		return result
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result
