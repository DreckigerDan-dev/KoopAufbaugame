extends StaticBody3D
## Fällbarer Baum — neue Ressourcenquelle für Bautrupps (siehe
## docs/survivor.md, "Trupp-Arten"). Dynamisch über MultiplayerSpawner
## erzeugt (siehe World._spawn_trees_near()), in der Nähe jeder neu
## entstandenen/erweiterten Zone (Start-Basis-Wahl, Gebäude claimen).
## take_damage()/_die() folgen demselben Muster wie Wall.gd/ZombieNest.gd —
## kein RPC nötig, ausschließlich host-seitig aufgerufen (von
## Survivor._process_harvest()). Markier-System (siehe docs/survivor.md,
## "Trupp-Arten", "Markier-System"): is_marked steuert, ob sich freie
## Bautrupps diesen Baum selbstständig vornehmen.

const MAX_HP := 60
const YIELD := {"wood": 15}

var tree_id: int = 0
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
	# abbauen") — ein zusammenhängendes Tannenbaum-Modell statt der
	# getrennten Stamm-/Kronen-Platzhalter, deshalb keine sinnvolle
	# Trunk/Foliage-Trennung mehr möglich. Der ganze Baum reagiert jetzt
	# auf HP/Markierung (gleiche Grün->welkes-Braun- bzw. Gold-Logik wie
	# vorher nur bei der Krone) — fällt ohne Model auf die alte
	# Trunk/Foliage-Zweiteilung zurück.
	var ratio: float = float(hp) / float(MAX_HP)
	var base_color := Color(0.9, 0.75, 0.1) if is_marked else Color(0.15, 0.4, 0.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color.lerp(Color(0.4, 0.32, 0.15), 1.0 - ratio)
	var meshes := _find_mesh_instances(get_node_or_null("Model"))
	if not meshes.is_empty():
		for mesh in meshes:
			mesh.set_surface_override_material(0, mat)
		return
	var trunk: MeshInstance3D = get_node_or_null("Trunk")
	if trunk != null:
		var trunk_mat := StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.35, 0.24, 0.14)
		trunk.set_surface_override_material(0, trunk_mat)
	var foliage: MeshInstance3D = get_node_or_null("Foliage")
	if foliage != null:
		foliage.set_surface_override_material(0, mat)


func _find_mesh_instances(node: Node) -> Array:
	var result: Array = []
	if node == null:
		return result
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result
