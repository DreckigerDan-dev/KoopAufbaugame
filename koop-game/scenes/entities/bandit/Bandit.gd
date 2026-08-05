extends StaticBody3D
## Bandit — echter NPC-Gegner statt der bisherigen reinen Loot-Mechanik
## ("Banditen-Restloot", siehe Building.gd). Wandert um sein Hideout,
## verfolgt nahe Survivor/geclaimte Gebäude/Home-Bases wie Zombie.gd, greift
## aber per Fernkampf an (ATTACK_RANGE, kein Heranlaufen bis auf Nahkampf-
## Distanz, kein automatischer Gegenschaden — anders als Zombie, das über
## Survivor.is_sheltered() den "wehrt sich automatisch"-Nahkampf auslöst).
## Host-autoritativ, gleiches Grundmuster wie Zombie.gd (siehe docs/bandits.md).

const MAX_HP := 50
const WANDER_SPEED := 2.0
const CHASE_SPEED := 4.5
const WANDER_RADIUS := 8.0
const IDLE_TIME_MIN := 1.0
const IDLE_TIME_MAX := 3.0
const DETECT_RADIUS := 10.0
const NOISE_RADIUS := 13.0
const GIVE_UP_RADIUS := 16.0
const ATTACK_RANGE := 6.0
const ATTACK_COOLDOWN := 1.2
const ATTACK_DAMAGE := 12
# Mauern/Tore blockieren Bandits genau wie Zombies (siehe Zombie.
# OBSTACLE_LAYER) — bewusst dupliziert statt geteilt, gleiches Muster wie
# dort (docs/building.md, "Bewusst dupliziert statt geteilt").
const OBSTACLE_LAYER := 2

var bandit_id: int = 0
var hp: int = MAX_HP
# Welches Hideout diesen Bandit erzeugt hat (siehe BanditHideout._process())
# — nötig, damit das Hideout seine eigene MAX_ACTIVE_BANDITS-Kappung gegen
# NUR die eigenen Bandits zählen kann (mehrere Hideouts auf der Karte sollen
# sich nicht gegenseitig blockieren).
var home_hideout_id: int = -1

var _home_position: Vector3 = Vector3.ZERO
var _wander_target: Vector3 = Vector3.ZERO
var _idle_timer: float = 0.0
var _chase_target: Node3D = null
var _attack_timer: float = 0.0
# Korrektheits-Fix-Muster von Zombie.gd übernommen (siehe dort) — verhindert
# doppelte Loot-Vergabe, falls im selben Frame zwei Quellen tödlich treffen.
var _dead: bool = false
var _last_damage_source_peer_id: int = 0
var _material: StandardMaterial3D = null
var _last_synced_hp: int = 0


func _ready() -> void:
	_home_position = position
	_pick_new_wander_target()
	_update_color()
	if not multiplayer.is_server():
		set_process(false)


func _process(delta: float) -> void:
	if get_tree().current_scene.is_paused():
		return
	_update_chase_target(delta)
	if is_instance_valid(_chase_target):
		_process_chase(delta)
	else:
		_process_wander(delta)
	if hp != _last_synced_hp:
		_last_synced_hp = hp
		_update_color()


func _update_chase_target(delta: float) -> void:
	if is_instance_valid(_chase_target):
		if global_position.distance_to(_chase_target.global_position) > GIVE_UP_RADIUS or _is_untouchable(_chase_target):
			_chase_target = null
		else:
			return
	_chase_target = _find_nearest_target()


func _find_nearest_target() -> Node3D:
	# Gleiche Zielauswahl wie Zombie._find_nearest_target() (lebende
	# Einheiten + geclaimte Gebäude + Home-Bases) — bewusst dupliziert statt
	# geteilt, siehe docs/building.md. Bandits greifen NUR Survivor/
	# Spieler-Eigentum an, keine Zombies (bewusst keine Drei-Wege-Fraktion
	# in dieser Stufe, siehe docs/bandits.md).
	var candidates := get_tree().get_nodes_in_group("living")
	for building in get_tree().get_nodes_in_group("searchable"):
		if is_instance_valid(building) and building.owner_peer_id != 0:
			candidates.append(building)
	for base in get_tree().get_nodes_in_group("home_base"):
		if is_instance_valid(base):
			candidates.append(base)
	var nearest: Node3D = null
	var nearest_dist := DETECT_RADIUS
	for unit in candidates:
		if not is_instance_valid(unit) or _is_untouchable(unit):
			continue
		var dist := global_position.distance_to(unit.global_position)
		if dist <= nearest_dist:
			nearest = unit
			nearest_dist = dist
	return nearest


func _is_untouchable(unit: Node3D) -> bool:
	return _is_sheltered(unit) or _is_unoccupied_vehicle(unit)


func _is_sheltered(unit: Node3D) -> bool:
	return unit.has_method("is_sheltered") and unit.is_sheltered()


func _is_unoccupied_vehicle(unit: Node3D) -> bool:
	return unit.has_method("is_occupied") and not unit.is_occupied()


func _process_chase(delta: float) -> void:
	var obstacle := _blocking_obstacle(global_position, _chase_target.global_position)
	var effective_target: Node3D = obstacle if obstacle != null else _chase_target
	var dist := global_position.distance_to(effective_target.global_position)
	if dist <= ATTACK_RANGE:
		_attack_timer += delta
		if _attack_timer >= ATTACK_COOLDOWN:
			_attack_timer = 0.0
			_try_attack(effective_target)
		return
	position = position.move_toward(effective_target.position, CHASE_SPEED * delta)


func _blocking_obstacle(from: Vector3, to: Vector3) -> Node3D:
	var query := PhysicsRayQueryParameters3D.create(from, to, OBSTACLE_LAYER)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.collider if result else null


func _try_attack(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	target.take_damage(ATTACK_DAMAGE)
	get_tree().current_scene.maybe_alert_sos(target)
	_alert_nearby_bandits(_chase_target)
	# Kein automatischer Gegenschaden (anders als Zombie._try_attack()) —
	# ein Bandit greift aus Distanz an, ein Survivor "wehrt sich" dabei
	# nicht automatisch. Schaden am Bandit kommt ausschließlich über
	# aktives order_attack()/Wachposten-Beschuss.


func _alert_nearby_bandits(target: Node3D) -> void:
	# Lärm-System analog Zombie._alert_nearby_zombies(), aber linearer Scan
	# über die (kleine) "bandit"-Gruppe statt des Spatial Grids — Bandit-
	# Population bleibt pro Hideout stark gekappt (siehe BanditHideout.
	# MAX_ACTIVE_BANDITS), ein Grid lohnt sich hier nicht.
	for other in get_tree().get_nodes_in_group("bandit"):
		if other == self or not is_instance_valid(other):
			continue
		if global_position.distance_to(other.global_position) <= NOISE_RADIUS:
			other.alert(target)


func alert(target: Node3D) -> void:
	_chase_target = target


func _process_wander(delta: float) -> void:
	if position.distance_to(_wander_target) < 0.3:
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_pick_new_wander_target()
		return
	position = position.move_toward(_wander_target, WANDER_SPEED * delta)


func _pick_new_wander_target() -> void:
	var offset := Vector3(randf_range(-WANDER_RADIUS, WANDER_RADIUS), 0, randf_range(-WANDER_RADIUS, WANDER_RADIUS))
	_wander_target = _home_position + offset
	_idle_timer = randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)


func take_damage(amount: int, source_peer_id: int = 0) -> void:
	if _dead:
		return
	if source_peer_id != 0:
		_last_damage_source_peer_id = source_peer_id
	hp = max(hp - amount, 0)
	if hp <= 0:
		_dead = true
		get_tree().current_scene.grant_bandit_kill_loot(_last_damage_source_peer_id)
		_die.rpc()


@rpc("authority", "call_local", "reliable")
func _die() -> void:
	queue_free()


func apply_synced_state(new_position: Vector3, new_hp: int) -> void:
	position = new_position
	if new_hp != hp:
		hp = new_hp
		_update_color()


func _update_color() -> void:
	# Dunkles Rotbraun statt Zombie-Grün — auf den ersten Blick als andere
	# Bedrohungsart erkennbar (siehe docs/bandits.md).
	var mesh: MeshInstance3D = get_node_or_null("Mesh")
	if mesh == null:
		return
	var ratio: float = float(hp) / float(MAX_HP)
	var base_color := Color(0.45, 0.22, 0.12)
	if _material == null:
		_material = StandardMaterial3D.new()
		mesh.set_surface_override_material(0, _material)
	_material.albedo_color = base_color.lerp(Color(0.05, 0.05, 0.05), 1.0 - ratio)
