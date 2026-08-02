extends StaticBody3D
## Abbaubares Autowrack — zweite Ressourcenquelle für Bautrupps neben Bäumen
## (siehe docs/survivor.md, "Trupp-Arten"). Bewusst eine EIGENE, statische
## Entität statt die beiden fahrbaren Vehicle-Objekte abbaubar zu machen —
## das hätte die Fahrzeuge als Transportmittel entwertet (Zielkonflikt).
## Dynamisch über MultiplayerSpawner erzeugt (siehe
## World._spawn_car_wrecks_near()), in der Nähe jeder neu entstandenen/
## erweiterten Zone. 1:1 dasselbe Muster wie Tree.gd (take_damage()/_die(),
## Markieren) — beide sind über die gemeinsame Gruppe "harvestable" für
## Survivor.gd ununterscheidbar (siehe docs/survivor.md, "Markier-System").

const MAX_HP := 80
const YIELD := {"metal": 20}

var wreck_id: int = 0
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
	var mesh: MeshInstance3D = get_node_or_null("Mesh")
	if mesh == null:
		return
	var ratio: float = float(hp) / float(MAX_HP)
	# Markiert (noch unberührt) -> Gold, gleiches Signal wie Tree.gd. Sonst
	# rostiges Orange-Braun, dunkelt beim Abbauen weiter nach.
	var base_color := Color(0.9, 0.75, 0.1) if is_marked else Color(0.45, 0.22, 0.08)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color.lerp(Color(0.1, 0.1, 0.1), 1.0 - ratio)
	mesh.set_surface_override_material(0, mat)
