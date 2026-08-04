extends StaticBody3D
## Abbaubarer Steinhaufen — Ressourcenquelle für Bautrupps (siehe
## docs/survivor.md, "Ressourcen abbauen"). Ersetzt das frühere Stein-Loot
## aus Stadt-Gebäuden (Nutzer-Feedback: Bautrupps sollen keine Häuser
## looten — Stein/Ziegel kommen jetzt ausschließlich aus eigenen
## Ressourcenknoten wie Baum/Autowrack, nicht mehr aus Building.loot).
## Dynamisch über MultiplayerSpawner erzeugt (siehe
## World._spawn_stone_piles_near()). 1:1 dasselbe Muster wie
## Tree.gd/CarWreck.gd — alle über die gemeinsame Gruppe "harvestable" für
## Survivor.gd ununterscheidbar.

const MAX_HP := 50
const YIELD := {"stone": 15}

var pile_id: int = 0
var hp: int = MAX_HP
var is_marked: bool = false


func _ready() -> void:
	_update_color()


func toggle_marked() -> void:
	# Aufgerufen von World.request_toggle_harvest_mark() (schon host-seitig).
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
	# Echtes Asset (2026-08-04, siehe docs/survivor.md, "Ressourcen
	# abbauen") hat mehrere Einzelstein-Meshes statt der zwei Platzhalter-
	# Kugeln — alle bekommen dieselbe Farbe (gleiches "alle Meshes
	# einfärben"-Muster wie GuardPost.gd/Wall.gd/BrickPile.gd, hier bewusst
	# dupliziert statt geteilt). Fällt ohne Model auf die alten
	# RockBig/RockSmall-Namen zurück.
	var ratio: float = float(hp) / float(MAX_HP)
	var base_color := Color(0.9, 0.75, 0.1) if is_marked else Color(0.5, 0.5, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color.lerp(Color(0.15, 0.15, 0.15), 1.0 - ratio)
	var meshes := _find_mesh_instances(get_node_or_null("Model"))
	if meshes.is_empty():
		for mesh_name in ["RockBig", "RockSmall"]:
			var mesh: MeshInstance3D = get_node_or_null(mesh_name)
			if mesh != null:
				meshes.append(mesh)
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
