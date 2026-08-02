@tool
extends EditorScript

# Baut street_tiles.meshlib direkt aus den 5 .glb-Dateien zusammen, statt
# sich auf "Szene -> In umwandeln -> MeshLibrary" zu verlassen — die hat
# wiederholt Items verschluckt (siehe Chat-Verlauf: road_cross fehlte
# zweimal) und nie zuverlässig die gewünschten Namen übernommen. Hier
# werden die Item-Namen explizit vergeben, unabhängig vom Datei-/Mesh-
# Namen in Blender (behebt nebenbei den "road_coner"-Tippfehler, ohne
# nochmal in Blender ran zu müssen).
#
# Ausführen über Godot-Skripteditor: diese Datei öffnen, dann
# Datei -> Ausführen (Strg+Shift+X). Ergebnis steht im Ausgabe-Panel.

const SOURCE_FILES := {
	"grass": "res://assets/gras.glb",
	"road_corner": "res://assets/road_corner.glb",
	"road_cross": "res://assets/road_cross.glb",
	"road_straight": "res://assets/road_straight.glb",
	"road_t": "res://assets/road_t.glb",
}
const MESHLIB_PATH := "res://assets/street_tiles.meshlib"


func _run() -> void:
	var mesh_library := MeshLibrary.new()
	var next_id := 0
	for item_name in SOURCE_FILES:
		var path: String = SOURCE_FILES[item_name]
		var packed: PackedScene = load(path)
		if packed == null:
			print("FEHLER: konnte ", path, " nicht laden — Dateiname prüfen.")
			continue
		var instance: Node = packed.instantiate()
		var mesh_instance: MeshInstance3D = _find_mesh_instance(instance)
		if mesh_instance == null:
			print("FEHLER: kein MeshInstance3D in ", path, " gefunden.")
			instance.free()
			continue
		mesh_library.create_item(next_id)
		mesh_library.set_item_name(next_id, item_name)
		mesh_library.set_item_mesh(next_id, mesh_instance.mesh)
		var aabb: AABB = mesh_instance.mesh.get_aabb()
		# aabb.position ist die "kleinste Ecke" relativ zum Objekt-Ursprung.
		# Bei korrektem Ursprung (Mitte unten) sollte das ungefähr
		# (-Maße.x/2, 0, -Maße.z/2) sein — x/z symmetrisch um 0 (Ursprung
		# horizontal mittig), y bei 0 (Ursprung sitzt auf der Unterseite,
		# nicht in der Höhen-Mitte).
		print("Item ", next_id, ": \"", item_name, "\" <- ", path, " — Maße: ", aabb.size, " — Ecke (sollte ~(-Maße.x/2, 0, -Maße.z/2) sein): ", aabb.position)
		if not is_zero_approx(aabb.position.y):
			# road_corner/road_cross/road_straight/road_t sind in Blender
			# Y-mittig statt unten verankert (Ecke.y ~ -0.14 statt 0) —
			# dadurch tauchen sie ~0.14m unter die Boden-/Gras-Ebene ab und
			# sind im Spiel unsichtbar (siehe Chat-Verlauf, "wo ist die
			# straße"). Statt jede Blender-Datei neu zu exportieren, wird
			# der Y-Versatz hier per Mesh-Transform pro Item ausgeglichen,
			# sodass die Unterkante IMMER bei y=0 landet, unabhängig vom
			# tatsächlichen Blender-Ursprung.
			var y_fix: float = -aabb.position.y
			mesh_library.set_item_mesh_transform(next_id, Transform3D(Basis(), Vector3(0, y_fix, 0)))
			print("   -> Y-Korrektur angewendet: +", y_fix)
		next_id += 1
		instance.free()

	if next_id != SOURCE_FILES.size():
		print("WARNUNG: nur ", next_id, " von ", SOURCE_FILES.size(), " Items erzeugt — Fehler oben prüfen, trotzdem gespeichert.")

	var err := ResourceSaver.save(mesh_library, MESHLIB_PATH)
	if err == OK:
		print("Gespeichert: ", MESHLIB_PATH, " mit ", next_id, " Items.")
	else:
		print("FEHLER beim Speichern, Code: ", err)


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh_instance(child)
		if found != null:
			return found
	return null
