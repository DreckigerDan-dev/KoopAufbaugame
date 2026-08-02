extends Control
## Vollbild-Kartenansicht (siehe docs/world.md, "Kartenansicht" — Punkt 11
## der Gesamtliste, Vorbild Infection Free Zone). Ergänzt die Minimap
## (siehe Minimap.gd) um eine große, per Taste (M) ein-/ausblendbare Ansicht
## für Navigation über größere Distanzen UND einen Überblick, welche
## Gebäude noch Loot haben. Strukturell fast identisch zu Minimap.gd (reine
## lokale Anzeige, kein neuer Netzwerk-Zustand, liest nur längst replizierte
## Node-Instanzen) — eigenes Script statt Wiederverwendung, weil die
## Konstanten (Radien/Größen) für die deutlich größere Fläche anders
## skaliert sind und der Loot-Status-Rahmen dazukommt.

const OWN_COLOR := Color(1, 1, 1)
const ALLY_COLOR := Color(0.3, 0.85, 0.9)
const ZOMBIE_COLOR := Color(0.85, 0.2, 0.2)
const NEST_COLOR := Color(0.5, 0.05, 0.05)
const UNCLAIMED_BUILDING_COLOR := Color(0.6, 0.6, 0.6)
const VEHICLE_COLOR := Color(0.3, 0.4, 0.85)
const CAMERA_MARKER_COLOR := Color(1, 1, 0.3)
# Fog of War (2026-08-01, Kartenplanungs-Session, siehe docs/world.md,
# "Fog of War") — gleiches Prinzip wie Minimap.gd: World._explored_cells
# ist die Quelle der Wahrheit, hier nur als deckender Nebel-Layer NACH
# allen anderen Symbolen aufgetragen.
const FOG_COLOR := Color(0.02, 0.02, 0.02, 1.0)
# Loot-Hinweis (Vision: "Icons (u. a. 'noch nicht geplündert' pro
# Gebäude)") — bewusst ein farbiger Rahmen statt eines echten Icons (kein
# Icon-Set im Projekt, gleiches Prinzip wie überall sonst: Farbe/Form statt
# Textur, siehe z. B. Minimap.gd).
const LOOT_AVAILABLE_COLOR := Color(1, 0.85, 0.2)
const LOOT_OUTLINE_WIDTH := 2.0
const UNIT_RADIUS := 6.0
const ZOMBIE_RADIUS := 5.0
const NEST_RADIUS := 9.0
const BUILDING_HALF_SIZE := 7.0
const CAMERA_MARKER_SIZE := 16.0
# Gegenseitige Verteidigung/Hilfe (siehe docs/world.md, "Gegenseitige
# Verteidigung/Hilfe" — Punkt 20 der Gesamtliste), gleiches Prinzip wie
# Minimap.gd, nur größer skaliert für die Vollbild-Ansicht.
const SOS_COLOR := Color(1.0, 0.15, 0.15)
const SOS_RADIUS := 14.0


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.05, 0.95))
	var own_peer_id := multiplayer.get_unique_id()
	_draw_buildings(own_peer_id)
	_draw_home_bases(own_peer_id)
	_draw_living(own_peer_id)
	_draw_zombies()
	_draw_fog()
	_draw_sos_alerts()
	_draw_camera_marker()


func _draw_fog() -> void:
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
			var top_left := _to_map(Vector3(-half + cx * cell_size, 0.0, -half + cz * cell_size))
			var bottom_right := _to_map(Vector3(-half + (cx + 1) * cell_size, 0.0, -half + (cz + 1) * cell_size))
			draw_rect(Rect2(top_left, bottom_right - top_left), FOG_COLOR)


func _draw_buildings(own_peer_id: int) -> void:
	for building in get_tree().get_nodes_in_group("searchable"):
		if not is_instance_valid(building):
			continue
		var pos := _to_map(building.position)
		var color := _owner_color(building.owner_peer_id, own_peer_id, UNCLAIMED_BUILDING_COLOR)
		_draw_square(pos, color)
		if not building.is_looted:
			_draw_square_outline(pos, LOOT_AVAILABLE_COLOR)


func _draw_home_bases(own_peer_id: int) -> void:
	for base in get_tree().get_nodes_in_group("home_base"):
		if not is_instance_valid(base):
			continue
		var color := _owner_color(base.owner_peer_id, own_peer_id, ALLY_COLOR)
		_draw_square(_to_map(base.position), color)


func _draw_living(own_peer_id: int) -> void:
	for unit in get_tree().get_nodes_in_group("living"):
		if not is_instance_valid(unit):
			continue
		var pos := _to_map(unit.position)
		if unit.is_in_group("vehicle"):
			draw_circle(pos, UNIT_RADIUS, VEHICLE_COLOR)
		else:
			draw_circle(pos, UNIT_RADIUS, _owner_color(unit.owner_peer_id, own_peer_id, ALLY_COLOR))


func _draw_zombies() -> void:
	for zombie in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(zombie):
			draw_circle(_to_map(zombie.position), ZOMBIE_RADIUS, ZOMBIE_COLOR)
	for nest in get_tree().get_nodes_in_group("zombie_nest"):
		if is_instance_valid(nest):
			draw_circle(_to_map(nest.position), NEST_RADIUS, NEST_COLOR)


func _draw_sos_alerts() -> void:
	# NACH dem Nebel gezeichnet (wie der Kamera-Marker) — ein Hilferuf soll
	# gerade AUSSERHALB des selbst schon erkundeten Gebiets warnen.
	var world: Node = get_tree().current_scene
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	for alert_position in world.active_sos_alerts():
		draw_arc(_to_map(alert_position), SOS_RADIUS + pulse * 4.0, 0.0, TAU, 32, SOS_COLOR, 3.0)


func _draw_camera_marker() -> void:
	var pivot: Node3D = get_tree().current_scene.pivot
	var center := _to_map(pivot.position)
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


func _draw_square_outline(center: Vector2, color: Color) -> void:
	# Etwas größer als das gefüllte Quadrat selbst, damit der Rahmen sichtbar
	# um das Gebäude-Symbol herum liegt statt es zu überdecken.
	var half := Vector2(BUILDING_HALF_SIZE, BUILDING_HALF_SIZE) + Vector2(LOOT_OUTLINE_WIDTH, LOOT_OUTLINE_WIDTH)
	draw_rect(Rect2(center - half, half * 2.0), color, false, LOOT_OUTLINE_WIDTH)


func _to_map(world_position: Vector3) -> Vector2:
	var map_size: float = get_tree().current_scene.MAP_SIZE
	var half := map_size / 2.0
	var x := (world_position.x + half) / map_size * size.x
	var y := (world_position.z + half) / map_size * size.y
	return Vector2(clampf(x, 0.0, size.x), clampf(y, 0.0, size.y))


func _gui_input(event: InputEvent) -> void:
	# Klick springt die eigene Kamera dorthin (gleiches Verhalten wie die
	# Minimap) UND schließt die Kartenansicht direkt wieder — "Fast Travel"
	# statt einer Ansicht, die offen bleibt (Nutzerentscheidung für eine
	# eigene Taste statt Auto-Trigger galt fürs ÖFFNEN, nicht fürs
	# Offenbleiben nach der Navigation).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pan_to(event.position)
		get_tree().current_scene.toggle_map_view()


func _pan_to(local_position: Vector2) -> void:
	var map_size: float = get_tree().current_scene.MAP_SIZE
	var half := map_size / 2.0
	var world_x := local_position.x / size.x * map_size - half
	var world_z := local_position.y / size.y * map_size - half
	var pivot: Node3D = get_tree().current_scene.pivot
	pivot.position = Vector3(world_x, pivot.position.y, world_z)
