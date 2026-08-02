extends Control
## Minimap (siehe docs/world.md, "Minimap") — reine lokale Anzeige, kein
## neuer Netzwerk-Zustand: liest nur Node-Instanzen, die über
## MultiplayerSpawner/RPC längst auf jedem Peer lokal repliziert vorliegen.
## Fog of War (2026-08-01, Kartenplanungs-Session, siehe docs/world.md,
## "Fog of War") — World._explored_cells ist die (lokal je Peer berechnete,
## aber dank identischer Eingabedaten zwischen Peers konsistente) Quelle
## der Wahrheit, hier nur als letzter Zeichen-Schritt ÜBER allen anderen
## Symbolen als deckender Nebel-Layer aufgetragen (verdeckt einfach alles
## darunter, kein Filtern einzelner Zeichen-Aufrufe nötig).

const OWN_COLOR := Color(1, 1, 1)
const ALLY_COLOR := Color(0.3, 0.85, 0.9)
const ZOMBIE_COLOR := Color(0.85, 0.2, 0.2)
const NEST_COLOR := Color(0.5, 0.05, 0.05)
const UNCLAIMED_BUILDING_COLOR := Color(0.6, 0.6, 0.6)
const VEHICLE_COLOR := Color(0.3, 0.4, 0.85)
const CAMERA_MARKER_COLOR := Color(1, 1, 0.3)
const FOG_COLOR := Color(0.02, 0.02, 0.02, 1.0)
const UNIT_RADIUS := 2.5
const ZOMBIE_RADIUS := 2.0
const NEST_RADIUS := 3.5
const BUILDING_HALF_SIZE := 3.0
const CAMERA_MARKER_SIZE := 6.0
# Gegenseitige Verteidigung/Hilfe (siehe docs/world.md, "Gegenseitige
# Verteidigung/Hilfe" — Punkt 20 der Gesamtliste) — pulsierender Ring statt
# gefülltem Kreis, deutlich von normalen Einheiten-Punkten unterscheidbar.
const SOS_COLOR := Color(1.0, 0.15, 0.15)
const SOS_RADIUS := 6.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.05, 0.85))
	var own_peer_id := multiplayer.get_unique_id()
	_draw_buildings(own_peer_id)
	_draw_home_bases(own_peer_id)
	_draw_living(own_peer_id)
	_draw_zombies()
	_draw_fog()
	_draw_sos_alerts()
	_draw_camera_marker()


func _draw_fog() -> void:
	# Läuft NACH allen Entity-Symbolen, VOR dem Kamera-Marker (siehe unten)
	# — die eigene Position soll immer sichtbar bleiben, auch in noch nicht
	# erkundeten Bereichen.
	var world: Node = get_tree().current_scene
	var cell_size: float = world.FOG_CELL_SIZE
	var map_size: float = world.MAP_SIZE
	var cell_count: int = ceili(map_size / cell_size)
	var half: float = map_size / 2.0
	for cx in cell_count:
		for cz in cell_count:
			var world_x: float = -half + (cx + 0.5) * cell_size
			var world_z: float = -half + (cz + 0.5) * cell_size
			if world.is_cell_explored(Vector3(world_x, 0.0, world_z)):
				continue
			var top_left := _to_minimap(Vector3(-half + cx * cell_size, 0.0, -half + cz * cell_size))
			var bottom_right := _to_minimap(Vector3(-half + (cx + 1) * cell_size, 0.0, -half + (cz + 1) * cell_size))
			draw_rect(Rect2(top_left, bottom_right - top_left), FOG_COLOR)


func _draw_buildings(own_peer_id: int) -> void:
	for building in get_tree().get_nodes_in_group("searchable"):
		if not is_instance_valid(building):
			continue
		var color := _owner_color(building.owner_peer_id, own_peer_id, UNCLAIMED_BUILDING_COLOR)
		_draw_square(_to_minimap(building.position), color)


func _draw_home_bases(own_peer_id: int) -> void:
	for base in get_tree().get_nodes_in_group("home_base"):
		if not is_instance_valid(base):
			continue
		var color := _owner_color(base.owner_peer_id, own_peer_id, ALLY_COLOR)
		_draw_square(_to_minimap(base.position), color)


func _draw_living(own_peer_id: int) -> void:
	# "living" enthält Survivor UND Fahrzeuge (Vehicle-Nodes sind zusätzlich
	# in "vehicle", siehe World.tscn) — darüber unterschieden statt über
	# eine eigene, engere Gruppenabfrage.
	for unit in get_tree().get_nodes_in_group("living"):
		if not is_instance_valid(unit):
			continue
		var pos := _to_minimap(unit.position)
		if unit.is_in_group("vehicle"):
			draw_circle(pos, UNIT_RADIUS, VEHICLE_COLOR)
		else:
			draw_circle(pos, UNIT_RADIUS, _owner_color(unit.owner_peer_id, own_peer_id, ALLY_COLOR))


func _draw_zombies() -> void:
	for zombie in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(zombie):
			draw_circle(_to_minimap(zombie.position), ZOMBIE_RADIUS, ZOMBIE_COLOR)
	for nest in get_tree().get_nodes_in_group("zombie_nest"):
		if is_instance_valid(nest):
			draw_circle(_to_minimap(nest.position), NEST_RADIUS, NEST_COLOR)


func _draw_sos_alerts() -> void:
	# NACH dem Nebel gezeichnet (wie der Kamera-Marker) — ein Hilferuf soll
	# gerade AUSSERHALB des selbst schon erkundeten Gebiets warnen, nicht
	# vom Nebel verdeckt werden.
	var world: Node = get_tree().current_scene
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	for alert_position in world.active_sos_alerts():
		draw_arc(_to_minimap(alert_position), SOS_RADIUS + pulse * 2.0, 0.0, TAU, 24, SOS_COLOR, 2.0)


func _draw_camera_marker() -> void:
	var pivot: Node3D = get_tree().current_scene.pivot
	var center := _to_minimap(pivot.position)
	# Kamera sitzt lokal bei (0, 10, 10) relativ zum Pivot (siehe
	# World.tscn, Camera3D) und blickt damit in Pivot-lokaler -Z-Richtung —
	# bei Rotation um Y (pivot.rotation.y) ergibt sich die Blickrichtung in
	# der XZ-Ebene als (-sin(yaw), -cos(yaw)).
	var yaw: float = pivot.rotation.y
	var forward := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(forward.y, -forward.x)
	var tip := center + forward * CAMERA_MARKER_SIZE
	var back_left := center - forward * CAMERA_MARKER_SIZE * 0.6 + right * CAMERA_MARKER_SIZE * 0.6
	var back_right := center - forward * CAMERA_MARKER_SIZE * 0.6 - right * CAMERA_MARKER_SIZE * 0.6
	draw_polygon(PackedVector2Array([tip, back_left, back_right]), PackedColorArray([CAMERA_MARKER_COLOR]))


func _owner_color(owner_peer_id: int, own_peer_id: int, neutral_color: Color) -> Color:
	if owner_peer_id == 0:
		return neutral_color
	if owner_peer_id == own_peer_id:
		return OWN_COLOR
	return ALLY_COLOR


func _draw_square(center: Vector2, color: Color) -> void:
	var half := Vector2(BUILDING_HALF_SIZE, BUILDING_HALF_SIZE)
	draw_rect(Rect2(center - half, half * 2.0), color)


func _to_minimap(world_position: Vector3) -> Vector2:
	var map_size: float = get_tree().current_scene.MAP_SIZE
	var half := map_size / 2.0
	var x := (world_position.x + half) / map_size * size.x
	var y := (world_position.z + half) / map_size * size.y
	return Vector2(clampf(x, 0.0, size.x), clampf(y, 0.0, size.y))


func _gui_input(event: InputEvent) -> void:
	# Linksklick verschiebt die eigene Kamera dorthin (Standard-RTS-
	# Minimap-Verhalten) — rein lokal, pivot wird nie über das Netzwerk
	# repliziert (siehe docs/world.md).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pan_to(event.position)


func _pan_to(local_position: Vector2) -> void:
	var map_size: float = get_tree().current_scene.MAP_SIZE
	var half := map_size / 2.0
	var world_x := local_position.x / size.x * map_size - half
	var world_z := local_position.y / size.y * map_size - half
	var pivot: Node3D = get_tree().current_scene.pivot
	pivot.position = Vector3(world_x, pivot.position.y, world_z)
