@tool
extends EditorScript

# Bestimmt die TATSÄCHLICHE native Ausrichtung von road_corner/road_t per
# Vertex-Schwerpunkt (gleiche Idee wie die Vertex-Analyse, die
# road_straights Nord-Süd-Ausrichtung verifiziert hat, siehe
# world.md "Straßen-Geometrie") — die Ecken/T-Rotation in
# _place_street_tile() war bisher nur angenommen, nicht bestätigt.
#
# Schwerpunkt-Logik: die Asphalt-/Markierungs-Geometrie sitzt bei einem
# Eck-Stück näher an den beiden OFFENEN Kanten (z. B. Nord+Ost), bei einem
# T-Stück näher an den DREI offenen Kanten, weg von der einen geschlossenen.
# Ein evtl. vorhandener symmetrischer Gras-Unterbau trägt kaum zur
# Richtung bei (liegt selbst zentriert bei 0), verfälscht das Vorzeichen
# also nicht.
#
# Ausführen über Godot-Skripteditor: diese Datei öffnen, dann
# Datei -> Ausführen (Strg+Shift+X). Ergebnis steht im Ausgabe-Panel.

const FILES := {
	"road_corner": "res://assets/road_corner.glb",
	"road_t": "res://assets/road_t.glb",
}


func _run() -> void:
	for item_name in FILES:
		var path: String = FILES[item_name]
		var packed: PackedScene = load(path)
		if packed == null:
			print("FEHLER: konnte ", path, " nicht laden.")
			continue
		var instance: Node = packed.instantiate()
		var mesh_instance: MeshInstance3D = _find_mesh_instance(instance)
		if mesh_instance == null:
			print("FEHLER: kein MeshInstance3D in ", path, " gefunden.")
			instance.free()
			continue
		var mesh: Mesh = mesh_instance.mesh
		var total_sum := Vector3.ZERO
		var total_count := 0
		print("--- ", item_name, " (", path, ") ---")
		for surface_idx in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(surface_idx)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var surf_sum := Vector3.ZERO
			for v in verts:
				surf_sum += v
			var surf_centroid: Vector3 = surf_sum / verts.size() if verts.size() > 0 else Vector3.ZERO
			print("  Surface ", surface_idx, ": ", verts.size(), " Vertices, Schwerpunkt = ", surf_centroid)
			total_sum += surf_sum
			total_count += verts.size()
		var centroid: Vector3 = total_sum / total_count if total_count > 0 else Vector3.ZERO
		var ns := "Nord (-Z)" if centroid.z < 0 else "Süd (+Z)"
		var ew := "Ost (+X)" if centroid.x > 0 else "West (-X)"
		print("  GESAMT-Schwerpunkt: ", centroid, " -> Masse liegt Richtung ", ns, " / ", ew)
		print("  (bei road_corner: die zwei offenen Kanten liegen in dieser Ecke;")
		print("   bei road_t: die geschlossene Kante liegt auf der GEGENÜBERLIEGENDEN Seite)")
		instance.free()


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh_instance(child)
		if found != null:
			return found
	return null
