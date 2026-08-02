extends StaticBody3D
## Baubares Verteidigungsgebäude: nach kurzer Bauzeit feuert es automatisch
## auf Zombies in Reichweite — aber nur, solange mindestens ein Arbeiter
## stationiert ist. Host-autoritativ, wie Survivor/Zombie. Siehe
## docs/building.md. 3D-Migration (siehe docs/3d-migration.md): ersetzt
## Node2D/ColorRect durch StaticBody3D/BoxMesh, Baumodus + Weltklick statt
## Weltklick+Taste B (siehe World.gd).

const BUILD_TIME := 5.0
const FIRE_RANGE := 6.0
const FIRE_COOLDOWN := 1.0
const FIRE_DAMAGE := 10
const FIRE_NOISE_RADIUS := 13.0

var guard_post_id: int = 0
var owner_peer_id: int = 1
var built: bool = false
var worker_count: int = 0

var _build_timer: float = BUILD_TIME
var _fire_timer: float = 0.0
var _stationed_workers: Array = []


func _ready() -> void:
	_update_color()
	if not multiplayer.is_server():
		set_process(false)


func _process(delta: float) -> void:
	if not built:
		_build_timer -= delta
		if _build_timer <= 0.0:
			_set_built_visual.rpc()
		return
	_try_fire(delta)


func _try_fire(delta: float) -> void:
	# Feuert nur, solange mindestens ein Arbeiter stationiert ist (siehe
	# docs/building.md, "Arbeiter zuweisen").
	if _stationed_workers.is_empty():
		return
	_fire_timer += delta
	if _fire_timer < FIRE_COOLDOWN:
		return
	_fire_timer = 0.0
	var target := _find_nearest_zombie()
	if target == null:
		return
	target.take_damage(FIRE_DAMAGE, owner_peer_id)
	if target.is_in_group("zombie"):
		# Nur echte Zombies lösen Alarm aus (siehe docs/zombies.md,
		# "Zombie-Nest") — ein beschossenes Nest hat kein bewegliches Ziel,
		# das andere Zombies sinnvoll verfolgen könnten, und implementiert
		# auch kein alert().
		_alert_nearby_zombies(target)


func _find_nearest_zombie() -> Node3D:
	# Seit dem Zombie-Nest (siehe docs/zombies.md) durchsucht dieselbe
	# Ziel-Ermittlung zusätzlich zur Gruppe "zombie" auch "zombie_nest" —
	# ein Wachposten feuert also automatisch auch auf ein Nest in
	# Reichweite, neben dem eigenen Trupp-Angriffsbefehl (siehe
	# docs/survivor.md, "Angriffsbefehl"). Zombie-Teil läuft über
	# World.zombies_near() (Spatial Grid, siehe World.ZOMBIE_GRID_CELL_SIZE)
	# statt der vollen "zombie"-Gruppenabfrage — Zombie-Nest bleibt normale
	# Gruppenabfrage (immer nur wenige, eine pro Stadt-Zone, lohnt sich nicht).
	var candidates: Array = get_tree().current_scene.zombies_near(global_position, FIRE_RANGE)
	candidates.append_array(get_tree().get_nodes_in_group("zombie_nest"))
	var nearest: Node3D = null
	var nearest_dist := FIRE_RANGE
	for candidate in candidates:
		if not is_instance_valid(candidate):
			continue
		var dist := global_position.distance_to(candidate.global_position)
		if dist <= nearest_dist:
			nearest = candidate
			nearest_dist = dist
	return nearest


func _alert_nearby_zombies(target: Node3D) -> void:
	# Schüsse sind laut — dupliziert bewusst Zombie._alert_nearby_zombies()
	# statt einer geteilten Utility-Funktion, siehe docs/building.md,
	# "Bewusst dupliziert statt geteilt". Läuft über World.zombies_near()
	# (Spatial Grid) statt der vollen "zombie"-Gruppenabfrage.
	for zombie in get_tree().current_scene.zombies_near(global_position, FIRE_NOISE_RADIUS):
		if is_instance_valid(zombie):
			zombie.alert(target)


@rpc("any_peer", "call_local", "reliable")
func request_worker(requesting_peer_id: int) -> void:
	# Vom HUD-Button ausgelöst — sucht selbst einen freien Trupp des
	# anfragenden Spielers und schickt ihn her, siehe docs/building.md.
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	var trupp := _find_idle_trupp(requesting_peer_id)
	if trupp == null:
		# Feedback statt stiller Ablehnung (siehe docs/building.md,
		# "Bekannte Grenzen") — World.report_status() ist öffentlich, gleiches
		# Cross-Node-Muster wie Survivor._finish_search() -> World.spawn_recruit().
		get_tree().current_scene.report_status(requesting_peer_id, "Kein freier Trupp verfügbar.")
		return
	trupp.order_station(self)


@rpc("any_peer", "call_local", "reliable")
func request_recall_worker(requesting_peer_id: int) -> void:
	# Gegenstück zu request_worker() — zieht einen stationierten Trupp
	# wieder ab und macht ihn dadurch wieder frei bewegbar/wählbar (siehe
	# docs/building.md, "Arbeiter zuweisen"). order_stop() ruft schon
	# _unstation() -> unregister_worker() auf, kein doppelter Code nötig.
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	if _stationed_workers.is_empty():
		return
	var trupp: Node3D = _stationed_workers[0]
	trupp.order_stop(requesting_peer_id)


func _find_idle_trupp(peer_id: int) -> Node3D:
	for trupp in get_tree().get_nodes_in_group("living"):
		if trupp.owner_peer_id == peer_id and trupp.is_idle():
			return trupp
	return null


func register_worker(trupp: Node3D) -> void:
	if trupp in _stationed_workers:
		return
	_stationed_workers.append(trupp)
	_sync_worker_count.rpc(_stationed_workers.size())


func unregister_worker(trupp: Node3D) -> void:
	_stationed_workers.erase(trupp)
	_sync_worker_count.rpc(_stationed_workers.size())


@rpc("authority", "call_local", "reliable")
func _sync_worker_count(count: int) -> void:
	worker_count = count


@rpc("authority", "call_local", "reliable")
func _set_built_visual() -> void:
	# call_local Pflicht, sonst sieht der Host den eigenen fertigen
	# Wachposten nie grau werden.
	built = true
	_update_color()


func _update_color() -> void:
	# Seit dem Wachturm-Asset (siehe docs/building.md) läuft die Bau-
	# Farbe (Baugelb -> Fertig-Grau) über alle Meshes im importierten
	# Modell statt der jetzt unsichtbaren Platzhalter-Box, siehe
	# _find_mesh_instances().
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.65, 0.2) if not built else Color(0.5, 0.5, 0.5)
	for mesh in _find_mesh_instances(get_node_or_null("Model")):
		mesh.set_surface_override_material(0, mat)


func _find_mesh_instances(node: Node) -> Array:
	# Rekursiv, weil importierte glTF-Modelle beliebig viele verschachtelte
	# MeshInstance3D-Kindknoten haben können (siehe docs/building.md,
	# "Wachturm/Holzmauer-Assets") — anders als die bisherigen Platzhalter-
	# Boxen mit genau einem "Mesh"-Node.
	var result: Array = []
	if node == null:
		return result
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result
