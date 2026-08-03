extends StaticBody3D
## Zombie-Spawner ("Nest") — erzeugt in festen Abständen einen neuen Zombie
## in seiner Nähe, OHNE Obergrenze, bis es zerstört wird. Siehe
## docs/zombies.md, "Zombie-Nest". Seit dem Kartenumbau (siehe
## docs/world.md, "Kartengröße") EIN Nest PRO Stadt-Zone statt einmalig auf
## der ganzen Karte, deshalb über `zombie_nest_spawner`/
## `World._create_zombie_nest()` erzeugt (gleiches Muster wie Tree.gd/
## Zombie.gd), vorher fester `.tscn`-Kind-Node. take_damage()/_die() folgen
## exakt demselben Muster wie Wall.gd (kein RPC nötig, ausschließlich
## host-seitig aufgerufen).

const MAX_HP := 150
const SPAWN_INTERVAL := 25.0
const SPAWN_SCATTER := 2.0

var zombie_nest_id: int = 0
var hp: int = MAX_HP
var _spawn_timer: float = SPAWN_INTERVAL


func _ready() -> void:
	_update_color()
	if not multiplayer.is_server():
		set_process(false)


func _process(delta: float) -> void:
	# Pause (siehe Zombie.gd für dieselbe Begründung/docs/mechanics-review.md).
	if get_tree().current_scene.is_paused():
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = SPAWN_INTERVAL
	var offset := Vector3(randf_range(-SPAWN_SCATTER, SPAWN_SCATTER), 0, randf_range(-SPAWN_SCATTER, SPAWN_SCATTER))
	# Cross-Node-Aufruf, gleiches Muster wie spawn_recruit()/report_status()
	# (siehe docs/recruitment.md, docs/world.md).
	get_tree().current_scene.spawn_nest_zombie(global_position + offset)


func take_damage(amount: int, _source_peer_id: int = 0) -> void:
	# Kein RPC — ausschließlich host-seitig aufgerufen (von
	# GuardPost._try_fire() oder Survivor._process_attack(), siehe
	# docs/building.md, docs/survivor.md). Gleiches Muster wie
	# Wall.take_damage(). _source_peer_id nur für Aufruf-Kompatibilität mit
	# Zombie.take_damage() (GuardPost._try_fire() ruft dieselbe Methode auf
	# Ziele aus "zombie" UND "zombie_nest" auf, siehe dort) — ein Nest
	# bekommt keinen eigenen Loot-Drop, der Wert wird hier ignoriert.
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
	var mat := StandardMaterial3D.new()
	# Dunkles Rot, dunkelt mit sinkendem HP weiter nach — bewusst anderer
	# Farbverlauf als Zombie (Grün) oder Wall (Braun/Grau), damit das Nest
	# auf den ersten Blick als eigene, bedrohliche Sache erkennbar ist.
	mat.albedo_color = Color(0.45, 0.08, 0.08).lerp(Color(0.05, 0.05, 0.05), 1.0 - ratio)
	mesh.set_surface_override_material(0, mat)
