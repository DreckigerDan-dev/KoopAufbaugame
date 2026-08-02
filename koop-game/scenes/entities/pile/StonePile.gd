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
	# Zwei Felsbrocken-Meshes (siehe StonePile.tscn) statt einem einzelnen
	# — beide bekommen dieselbe Farbe (anders als Tree.gd, wo nur die
	# Krone reagiert, hier sind beide Teile gleichwertig "Stein").
	var ratio: float = float(hp) / float(MAX_HP)
	var base_color := Color(0.9, 0.75, 0.1) if is_marked else Color(0.5, 0.5, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color.lerp(Color(0.15, 0.15, 0.15), 1.0 - ratio)
	for mesh_name in ["RockBig", "RockSmall"]:
		var mesh: MeshInstance3D = get_node_or_null(mesh_name)
		if mesh != null:
			mesh.set_surface_override_material(0, mat)
