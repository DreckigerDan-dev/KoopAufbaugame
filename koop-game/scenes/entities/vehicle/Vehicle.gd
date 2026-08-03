extends StaticBody3D
## Fahrzeug — in der Stadt vorgefunden, keinen eigenen Bautyp. Ein Trupp muss
## erst hinlaufen und einsteigen (`Survivor.order_enter_vehicle()`), danach
## fährt es sich wie ein schnellerer, lauterer Trupp — kein eigener Angriff,
## reiner Transport (Nutzerentscheidung). Siehe docs/vehicle.md. Seit dem
## Kartenumbau (siehe docs/world.md, "Kartengröße") pro Stadt-Zone über
## `vehicle_spawner`/`World._create_vehicle()` erzeugt (gleiches Muster wie
## Tree.gd/Zombie.gd), vorher zwei feste `.tscn`-Kind-Nodes.

const ARRIVE_THRESHOLD := 0.05
# "Lauter als ein Trupp" (siehe ARCHITECTURE.md, Ideen-Backlog) — reines
# Fahren (ohne Kampf) lockt Zombies an, nicht erst bei Kontakt.
const NOISE_INTERVAL := 2.0
# Physik-Ebene 2 = Mauern/Tore (siehe scenes/entities/wall/Wall.tscn,
# `collision_layer = 2`) — bewusst dupliziert aus Survivor.gd/Zombie.gd
# statt geteilt, gleiches Muster wie schon bei _alert_nearby_zombies()
# (siehe docs/building.md, "Bewusst dupliziert statt geteilt").
const OBSTACLE_LAYER := 2

# Differenzierte Fahrzeugtypen (Punkt 19 der Gesamtliste, Vorbild
# Infos/03 Asset-Checkliste.md, Abschnitt "FAHRZEUGE") — EIN Skript/EINE
# Szene für alle drei Typen (String-Key statt Enum, damit World.gd beim
# Spawnen keinen Cross-Script-Enum-Zugriff braucht, gleiches
# Vereinfachungsmotiv wie `Wall.gd`s `is_gate`-Bool). Drei bewusst simple
# Archetypen statt aller sechs Vision-Fahrzeuge: Auto (Basiswert, bisheriger
# einziger Typ), Motorrad (schnell/leise/wenig HP/wenig Kapazität), LKW
# (langsam/laut/viel HP/viel Kapazität) — deckt die Bandbreite der Vision-
# Tabelle ab, ohne für jede einzelne Fahrzeugklasse eine eigene Nische zu
# bauen. **Bewusst OHNE Trage-Kapazitäts-Bonus** (Vision nennt "+X Slots"):
# passt nicht sauber in die aktuelle Architektur, weil ein fahrender Trupp
# beim Einsteigen unsichtbar/aus "living" entfernt wird (Survivor._board())
# und dabei gar nicht looten kann — Kapazität ist ausschließlich
# Survivor.CARRY_CAPACITY, geloottet wird zu Fuß nach dem Aussteigen. Ein
# echter Kapazitäts-Bonus bräuchte ein eigenes Fahrzeug-Inventar-System,
# das hier bewusst nicht mitgebaut wird (kein Auftrag dafür).
# `seats` (Nutzerwunsch 2026-08-03, "autos mehr läute rein passen"): Sitze
# GESAMT inklusive Fahrer — Motorrad bleibt bewusst bei 1 (kein Soziussitz-
# Konzept), Auto/LKW bekommen Platz für Mitfahrer, siehe enter()/passengers.
const VEHICLE_STATS := {
	"car": {
		"max_hp": 200, "move_speed": 8.0, "noise_radius": 10.0,
		"size": Vector3(1.6, 1.2, 3.2), "color": Color(0.25, 0.3, 0.7), "seats": 3,
	},
	"motorcycle": {
		"max_hp": 80, "move_speed": 13.0, "noise_radius": 7.0,
		"size": Vector3(0.8, 1.0, 2.0), "color": Color(0.55, 0.4, 0.08), "seats": 1,
	},
	"truck": {
		"max_hp": 320, "move_speed": 6.0, "noise_radius": 15.0,
		"size": Vector3(2.0, 1.6, 4.2), "color": Color(0.2, 0.42, 0.22), "seats": 5,
	},
}

@export var vehicle_type: String = "car"

var vehicle_id: int = 0
var owner_peer_id: int = 0  # 0 = unbesetzt, gehört noch niemandem (= auch keine Passagiere)
# Wie bei Zombie.gd/is_brute NICHT hier auf einen Höchstwert vorbelegt —
# _ready() berechnet hp/_max_hp erst NACHDEM der Node dem Baum hinzugefügt
# wurde (@export-Timing, siehe dort), ein hier gesetzter Wert würde sofort
# überschrieben (siehe World._create_vehicle()/_load_game_state()).
var hp: int = 0
var driver: Node3D = null  # nur host-seitig aussagekräftig, siehe _sync_owner()
# Mitfahrer ohne Steuerungsrechte (können nicht order_move()/order_stop()
# aufrufen, das bleibt exklusiv beim Fahrer über owner_peer_id) — steigen
# zusammen mit dem Fahrer aus, wenn dieser request_exit() ruft (siehe dort),
# kein eigenständiges Aussteigen einzelner Mitfahrer (der Trupp ist ja
# ohnehin unsichtbar/nicht auswählbar, solange er drinsitzt, siehe
# Survivor._board()). Nur host-seitig aussagekräftig, wie driver.
var passengers: Array = []

var _max_hp: int = 0
var _move_speed: float = 0.0
var _noise_radius: float = 0.0

var _waypoints: Array = []
var _noise_timer: float = 0.0


func _ready() -> void:
	var stats: Dictionary = VEHICLE_STATS.get(vehicle_type, VEHICLE_STATS["car"])
	_max_hp = stats["max_hp"]
	_move_speed = stats["move_speed"]
	_noise_radius = stats["noise_radius"]
	hp = _max_hp
	# Mesh/Collision sind SubResources aus der .tscn, standardmäßig über
	# ALLE Instanzen der Szene geteilt — duplicate() nötig, sonst würde das
	# Resize der ersten Instanz jedes andere Fahrzeug gleich mit verzerren.
	var mesh_instance: MeshInstance3D = $Mesh
	var box_mesh: BoxMesh = (mesh_instance.mesh as BoxMesh).duplicate()
	box_mesh.size = stats["size"]
	mesh_instance.mesh = box_mesh
	var collision: CollisionShape3D = $Collision
	var box_shape: BoxShape3D = (collision.shape as BoxShape3D).duplicate()
	box_shape.size = stats["size"]
	collision.shape = box_shape
	_update_color()
	if not multiplayer.is_server():
		set_process(false)


func _process(delta: float) -> void:
	# Pause (siehe Zombie.gd für dieselbe Begründung/docs/mechanics-review.md).
	if get_tree().current_scene.is_paused():
		return
	if driver == null:
		# Unbesetzt/geparkt — nichts zu tun, kein unnötiger _sync_state-Spam.
		return
	_handle_movement(delta)
	_handle_noise(delta)
	_sync_state.rpc(position, hp)


func is_idle() -> bool:
	return _waypoints.is_empty()


func seat_count() -> int:
	return (1 if driver != null else 0) + passengers.size()


func is_full() -> bool:
	var seats: int = VEHICLE_STATS.get(vehicle_type, VEHICLE_STATS["car"])["seats"]
	return seat_count() >= seats


func is_occupied() -> bool:
	# Zombies greifen ein Fahrzeug nur an, solange jemand drinsitzt (siehe
	# Zombie._is_unoccupied_vehicle(), Nutzerwunsch) — owner_peer_id ist auf
	# allen Peers korrekt (repliziert über _sync_owner()), anders als
	# `driver` (nur host-seitig aussagekräftig), deshalb hier die
	# Grundlage statt driver != null.
	return owner_peer_id != 0


func _handle_movement(delta: float) -> void:
	if _waypoints.is_empty():
		return
	var target: Vector3 = _waypoints[0]
	var next_position := position.move_toward(target, _move_speed * delta)
	if _is_path_blocked(next_position):
		# Mauer/fremdes Tor im Weg — Fahrzeug bleibt stehen, kein
		# Durchbrechen wie beim Zombie, kein Ausweichen (siehe docs/walls.md).
		return
	position = next_position
	if position.distance_to(target) < ARRIVE_THRESHOLD:
		_waypoints.pop_front()


func _is_path_blocked(next_position: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position, next_position, OBSTACLE_LAYER)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result:
		return false
	var obstacle: Node3D = result.collider
	if obstacle.has_method("blocks") and not obstacle.blocks(owner_peer_id):
		return false
	return true


func _handle_noise(delta: float) -> void:
	if _waypoints.is_empty():
		_noise_timer = 0.0
		return
	_noise_timer += delta
	if _noise_timer < NOISE_INTERVAL:
		return
	_noise_timer = 0.0
	for zombie in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(zombie) and global_position.distance_to(zombie.global_position) <= _noise_radius:
			zombie.alert(self)


func enter(survivor: Node3D, requesting_peer_id: int) -> bool:
	# Host-seitig von Survivor._enter_vehicle() aufgerufen — kein eigenes
	# RPC nötig, gleiches Muster wie GuardPost.request_worker() ->
	# Survivor.order_station(). Erster Trupp wird Fahrer (bekommt die
	# Steuerungsrechte über owner_peer_id), jeder weitere bis zur
	# Sitzplatz-Kapazität wird Mitfahrer (siehe VEHICLE_STATS/seat_count()).
	# Gibt false zurück, wenn schon voll — Aufrufer (_enter_vehicle())
	# behandelt das wie ein schon besetztes Fahrzeug (kein Feedback, zu spät).
	if is_full():
		return false
	if driver == null:
		owner_peer_id = requesting_peer_id
		driver = survivor
		_sync_owner.rpc(requesting_peer_id)
	else:
		passengers.append(survivor)
	return true


@rpc("any_peer", "call_local", "reliable")
func order_move(target: Vector3, requesting_peer_id: int, queue: bool, _start_delay: float = 0.0) -> void:
	# _start_delay (siehe Survivor.order_move()) wird hier nur akzeptiert,
	# nicht genutzt — World._select_at() ruft order_move() generisch für
	# alle ausgewählten Einheiten auf, egal ob Trupp oder Fahrzeug. Fahrzeuge
	# haben eigenes Straßen-Pathing statt Formations-Kreis, gestaffelter
	# Loslauf ist hier nicht relevant.
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	if not queue:
		_waypoints.clear()
	# Straßen-Pathing (siehe docs/world.md, "Fahrzeug-Pathing") — folgt dem
	# Straßen-Raster einer Stadt-Zone statt Luftlinie, wenn das Ziel in
	# einer liegt (in der Wildnis bleibt es bei der Luftlinie, dort gibt es
	# keine Straßen-Daten). Bei einer bereits laufenden Warteschlange
	# (queue == true) startet der neue Pfad-Abschnitt am LETZTEN
	# Wegpunkt, nicht an der aktuellen Position — sonst würde ein
	# nachgeschobener Befehl den vorherigen Streckenabschnitt "abschneiden".
	var from_position: Vector3 = position if _waypoints.is_empty() else _waypoints[-1]
	var path: Array = get_tree().current_scene.find_vehicle_path(from_position, target)
	_waypoints.append_array(path)


@rpc("any_peer", "call_local", "reliable")
func order_stop(requesting_peer_id: int) -> void:
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	_waypoints.clear()


@rpc("any_peer", "call_local", "reliable")
func request_exit(requesting_peer_id: int) -> void:
	# Aussteigen (F-Taste, siehe World.gd) — kann von jedem Peer kommen,
	# deshalb any_peer statt eines direkten Funktionsaufrufs wie bei enter().
	# Nur der FAHRER kann das auslösen (owner_peer_id-Check) — steigt er aus,
	# steigt die ganze Besatzung mit aus (Mitfahrer haben keine eigene
	# Aussteige-Möglichkeit, siehe passengers-Deklaration oben). Jeder
	# Aussteigende bekommt einen eigenen kleinen Seitenversatz, damit nicht
	# alle exakt übereinanderstehen (gleiches Grundmotiv wie
	# World._formation_offset(), hier bewusst einfacher gehalten).
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	var exiting: Array = [driver] + passengers
	for i in exiting.size():
		var survivor: Node3D = exiting[i]
		if is_instance_valid(survivor):
			survivor.exit_vehicle(position + Vector3(i * 1.2, 0, 0))
	driver = null
	passengers.clear()
	owner_peer_id = 0
	_waypoints.clear()
	_sync_owner.rpc(0)


func take_damage(amount: int) -> void:
	# Kein RPC — wird ausschließlich host-seitig aufgerufen (von Zombie beim
	# Angriff, siehe docs/zombies.md).
	var new_hp: int = max(hp - amount, 0)
	_sync_hp.rpc(new_hp)
	if new_hp <= 0:
		if owner_peer_id != 0:
			# Sonst wirkt es wie spurloses Verschwinden — Fahrzeuge sind auch
			# unbesetzt/geparkt für Zombies angreifbar (siehe docs/vehicle.md,
			# "Bekannte Grenzen"), ohne dieses Feedback merkt man nur "das
			# Auto ist weg", ohne zu wissen warum. Nur an den aktuellen
			# Besitzer, wenn es einen gibt — ein längst unbesetztes Fahrzeug
			# hat niemanden, der informiert werden müsste.
			get_tree().current_scene.report_status(owner_peer_id, "Fahrzeug wurde von einem Zombie zerstört.")
		# Permadeath wie im Konzept (ARCHITECTURE.md) — kein Rauswurf in
		# letzter Sekunde, Fahrer UND alle Mitfahrer sterben mit dem
		# Fahrzeug.
		for survivor in [driver] + passengers:
			if is_instance_valid(survivor):
				survivor.vehicle_destroyed()
		_die.rpc()


@rpc("authority", "call_local", "reliable")
func _die() -> void:
	queue_free()


@rpc("authority", "call_local", "reliable")
func _sync_hp(new_hp: int) -> void:
	hp = new_hp
	_update_color()


@rpc("authority", "call_local", "reliable")
func _sync_owner(new_owner_peer_id: int) -> void:
	owner_peer_id = new_owner_peer_id


@rpc("authority", "call_local", "unreliable_ordered")
func _sync_state(new_position: Vector3, new_hp: int) -> void:
	position = new_position
	hp = new_hp
	_update_color()


func _update_color() -> void:
	var mesh: MeshInstance3D = get_node_or_null("Mesh")
	if mesh == null:
		return
	var ratio: float = float(hp) / float(_max_hp)
	var base_color: Color = VEHICLE_STATS.get(vehicle_type, VEHICLE_STATS["car"])["color"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base_color.lerp(Color(0.05, 0.05, 0.05), 1.0 - ratio)
	mesh.set_surface_override_material(0, mat)
