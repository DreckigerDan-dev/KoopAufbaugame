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
# Bandits (siehe docs/bandits.md) — eigene Braun/Ocker-Farbfamilie statt des
# Zombie-Rots, auf der Karte auf den ersten Blick als andere Bedrohungsart
# erkennbar (gleiche Unterscheidung wie bei den 3D-Entity-Farben selbst).
const BANDIT_COLOR := Color(0.55, 0.3, 0.15)
const BANDIT_HIDEOUT_COLOR := Color(0.4, 0.28, 0.1)
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
# Gebäudetyp-Farbcode nach Loot-Kategorie (2026-08-03, Nutzerwunsch:
# "färbe die gebäude typen ein zu den jeweiligen lootarten, krankenhaus
# heilung grün etc.") — Kategorie kommt aus `Building.loot_category`
# (siehe World.LOOT_CATEGORY_BY_RESOURCE, aus `main_loot.resource`
# abgeleitet). Gilt NUR für unbesetzte Gebäude — sobald eines geclaimt ist,
# hat die Besitzer-Farbe (eigen/verbündet, siehe _owner_color()) Vorrang,
# das ist an dem Punkt die wichtigere Information.
const LOOT_CATEGORY_COLORS := {
	"food": Color(0.85, 0.55, 0.15),
	"medicine": Color(0.25, 0.75, 0.35),
	"equipment": Color(0.8, 0.25, 0.25),
	"books": Color(0.5, 0.4, 0.85),
}
const LOOT_CATEGORY_LABELS := {
	"food": "Nahrung",
	"medicine": "Medizin",
	"equipment": "Ausrüstung/Waffen",
	"books": "Forschungsbücher",
}
# Reihenfolge fix statt Dictionary-Iteration (Dictionary-Reihenfolge ist
# zwar in GDScript Insertions-stabil, aber explizit lesbarer für die
# Legende).
const LOOT_CATEGORY_ORDER := ["food", "medicine", "equipment", "books"]
const LEGEND_MARGIN := 12.0
const LEGEND_SWATCH_SIZE := 14.0
const LEGEND_ROW_HEIGHT := 20.0
const LEGEND_FONT_SIZE := 14
const UNIT_RADIUS := 6.0
const ZOMBIE_RADIUS := 5.0
const NEST_RADIUS := 9.0
const BANDIT_RADIUS := 5.0
const BANDIT_HIDEOUT_RADIUS := 9.0
const BUILDING_HALF_SIZE := 7.0
const CAMERA_MARKER_SIZE := 16.0
# Gegenseitige Verteidigung/Hilfe (siehe docs/world.md, "Gegenseitige
# Verteidigung/Hilfe" — Punkt 20 der Gesamtliste), gleiches Prinzip wie
# Minimap.gd, nur größer skaliert für die Vollbild-Ansicht.
const SOS_COLOR := Color(1.0, 0.15, 0.15)
const SOS_RADIUS := 14.0
# Zoom (2026-08-03, Nutzerwunsch: "die eine idee mit map reinzoomen das
# kann man jetzt machen") — 1.0 zeigt die komplette Karte (bisheriges
# Verhalten), höhere Werte zoomen um _view_center herum rein. Multiplikativ
# wie der 3D-Kamera-Zoom (siehe World._zoom()), gleiches Bediengefühl.
const MAP_ZOOM_MIN := 1.0
const MAP_ZOOM_MAX := 8.0
const MAP_ZOOM_STEP_FACTOR := 0.35
var _zoom_level: float = MAP_ZOOM_MIN
# Weltposition (X/Z), die in der Bildschirmmitte der Kartenansicht liegt —
# beim Öffnen auf die aktuelle Kameraposition gesetzt (siehe World.gd,
# toggle_map_view()), NICHT auf den Kartenmittelpunkt, sonst würde man
# reingezoomt erstmal woanders landen als da, wo man gerade ist.
var _view_center: Vector2 = Vector2.ZERO
# Maus-Halten+Ziehen zum Verschieben (2026-08-05, Nutzerwunsch "große Karte
# sollte man mit Maus halten bewegen") — ersetzt das vorherige
# Rechtsklick-springt-sofort-dahin-Verhalten durch echtes Ziehen ("wie eine
# Papierkarte greifen"), gleiche Maustaste (rechts), damit Linksklick
# weiterhin exklusiv fürs Hinreisen+Schließen bleibt.
var _drag_active: bool = false


func zoom_in() -> void:
	_zoom_level = clampf(_zoom_level * (1.0 + MAP_ZOOM_STEP_FACTOR), MAP_ZOOM_MIN, MAP_ZOOM_MAX)


func zoom_out() -> void:
	_zoom_level = clampf(_zoom_level / (1.0 + MAP_ZOOM_STEP_FACTOR), MAP_ZOOM_MIN, MAP_ZOOM_MAX)


func reset_view(world_center: Vector2) -> void:
	# Von World.toggle_map_view() beim Öffnen aufgerufen — jede Sitzung mit
	# der Kartenansicht startet wieder bei voller Übersicht, zentriert auf
	# die aktuelle Position, statt sich einen alten Zoom-/Pan-Stand von
	# vorhin zu merken (vorhersehbarer als "wo war ich beim letzten Mal").
	_zoom_level = MAP_ZOOM_MIN
	_view_center = world_center


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
	_draw_bandits()
	_draw_fog()
	_draw_sos_alerts()
	_draw_camera_marker()
	_draw_legend()


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
		# Unbesetzt: Farbe nach Loot-Kategorie (siehe LOOT_CATEGORY_COLORS),
		# damit man auf einen Blick sieht, welcher Gebäudetyp wo steht —
		# geclaimt: Besitzer-Farbe hat Vorrang (wichtigere Info an dem Punkt).
		var neutral_color: Color = LOOT_CATEGORY_COLORS.get(building.loot_category, UNCLAIMED_BUILDING_COLOR)
		var color := _owner_color(building.owner_peer_id, own_peer_id, neutral_color)
		_draw_square(pos, color)
		if not building.is_looted or building.has_bandit_loot:
			# Banditen-Restloot (siehe Building.gd/World._spawn_bandit_restock())
			# zählt genauso als "hier gibt's noch was zu holen" wie ein
			# frisches, noch nie durchsuchtes Gebäude — gleicher gelber Rahmen.
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


func _draw_bandits() -> void:
	for bandit in get_tree().get_nodes_in_group("bandit"):
		if is_instance_valid(bandit):
			draw_circle(_to_map(bandit.position), BANDIT_RADIUS, BANDIT_COLOR)
	for hideout in get_tree().get_nodes_in_group("bandit_hideout"):
		if is_instance_valid(hideout):
			draw_circle(_to_map(hideout.position), BANDIT_HIDEOUT_RADIUS, BANDIT_HIDEOUT_COLOR)


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


func _draw_legend() -> void:
	# Erklärt die Gebäude-Farbcodierung (siehe LOOT_CATEGORY_COLORS/
	# _draw_buildings()) UND den gelben "Loot verfügbar"-Rahmen — ohne das
	# wäre die Farbzuordnung reines Raten. Fester Text/Farb-Ansatz statt
	# Icons (kein Icon-Set im Projekt, gleiches Prinzip wie überall sonst).
	var font := get_theme_default_font()
	var row_count := LOOT_CATEGORY_ORDER.size() + 1
	var panel_size := Vector2(190.0, LEGEND_MARGIN * 2.0 + row_count * LEGEND_ROW_HEIGHT)
	draw_rect(Rect2(Vector2(LEGEND_MARGIN, LEGEND_MARGIN), panel_size), Color(0.05, 0.05, 0.05, 0.85))
	var y := LEGEND_MARGIN * 2.0
	for category in LOOT_CATEGORY_ORDER:
		var swatch_pos := Vector2(LEGEND_MARGIN * 2.0, y)
		draw_rect(Rect2(swatch_pos, Vector2(LEGEND_SWATCH_SIZE, LEGEND_SWATCH_SIZE)), LOOT_CATEGORY_COLORS[category])
		draw_string(font, swatch_pos + Vector2(LEGEND_SWATCH_SIZE + 8.0, LEGEND_SWATCH_SIZE - 2.0), LOOT_CATEGORY_LABELS[category], HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, Color.WHITE)
		y += LEGEND_ROW_HEIGHT
	var outline_pos := Vector2(LEGEND_MARGIN * 2.0, y)
	draw_rect(Rect2(outline_pos, Vector2(LEGEND_SWATCH_SIZE, LEGEND_SWATCH_SIZE)), LOOT_AVAILABLE_COLOR, false, LOOT_OUTLINE_WIDTH)
	draw_string(font, outline_pos + Vector2(LEGEND_SWATCH_SIZE + 8.0, LEGEND_SWATCH_SIZE - 2.0), "Loot verfügbar", HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, Color.WHITE)


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
	# Berücksichtigt seit dem Zoom (siehe MAP_ZOOM_*-Konstanten oben)
	# _zoom_level/_view_center statt immer die komplette Karte 1:1 auf die
	# Panelgröße zu skalieren. Bewusst KEIN Clamping mehr auf die
	# Panelgröße (früher hier, als der Maßstab noch immer fix war) — beim
	# Reingezoomt-Sein sollen Symbole außerhalb des sichtbaren Ausschnitts
	# einfach nicht mehr da erscheinen, nicht an den Rand "geklebt" werden.
	# `clip_contents` auf dem MapView-Node selbst (siehe MapView.tscn)
	# schneidet das sauber ab, statt über den Panel-Rand zu malen.
	var map_size: float = get_tree().current_scene.MAP_SIZE
	var visible_size := map_size / _zoom_level
	var half := visible_size / 2.0
	var x := (world_position.x - _view_center.x + half) / visible_size * size.x
	var y := (world_position.z - _view_center.y + half) / visible_size * size.y
	return Vector2(x, y)


func _from_map(local_position: Vector2) -> Vector2:
	# Umkehrung von _to_map() — Bildschirmposition (innerhalb des Panels)
	# zurück in Welt-X/Z, unter Berücksichtigung von Zoom/View-Center.
	var map_size: float = get_tree().current_scene.MAP_SIZE
	var visible_size := map_size / _zoom_level
	var half := visible_size / 2.0
	var world_x := local_position.x / size.x * visible_size - half + _view_center.x
	var world_z := local_position.y / size.y * visible_size - half + _view_center.y
	return Vector2(world_x, world_z)


func _gui_input(event: InputEvent) -> void:
	# Linksklick springt die eigene Kamera dorthin (gleiches Verhalten wie
	# die Minimap) UND schließt die Kartenansicht direkt wieder — "Fast
	# Travel" statt einer Ansicht, die offen bleibt (Nutzerentscheidung für
	# eine eigene Taste statt Auto-Trigger galt fürs ÖFFNEN, nicht fürs
	# Offenbleiben nach der Navigation). Rechtsklick HALTEN+ZIEHEN
	# verschiebt den Kartenausschnitt (kein Kamera-Sprung, kein Schließen)
	# — sonst könnte man beim Reingezoomt-Sein gar nicht navigieren, ohne
	# jedes Mal zu schließen. Mausrad zoomt. Funktioniert 1:1 auch per
	# Gamepad — GamepadCursor synthetisiert A/B als Links-/Rechtsklick,
	# LB/RB werden in World._handle_gamepad_input() auf zoom_in()/
	# zoom_out() umgeleitet, solange die Kartenansicht offen ist.
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_pan_to(event.position)
			get_tree().current_scene.toggle_map_view()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_drag_active = event.pressed and SettingsManager.pan_with_mouse
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_out()
	elif event is InputEventMouseMotion and _drag_active:
		# Gleiche Skalierung wie _to_map()/_from_map() (visible_size je
		# Zoomstufe) — Ziehen um X Bildschirm-Pixel soll denselben Weltpunkt
		# unter dem Cursor halten, unabhängig vom aktuellen Zoom.
		var visible_size: float = get_tree().current_scene.MAP_SIZE / _zoom_level
		_view_center -= Vector2(event.relative.x / size.x, event.relative.y / size.y) * visible_size


func _pan_to(local_position: Vector2) -> void:
	var world_pos := _from_map(local_position)
	var pivot: Node3D = get_tree().current_scene.pivot
	pivot.position = Vector3(world_pos.x, pivot.position.y, world_pos.y)
