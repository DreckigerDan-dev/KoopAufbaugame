extends Node
## Speichern/Laden — reine Datei-I/O + Serialisierung, siehe docs/save_load.md.
## Ein einzelner Speicherstand (kein Slot-System). Format ist ein
## verschachteltes Dictionary, über var_to_str()/str_to_var() geschrieben
## (Godot-natives Format, versteht Vector3/Dictionary direkt ohne manuelle
## Konvertierung). Reine Speicher-/Ladelogik hier — WAS gespeichert wird,
## kommt aus World._collect_save_data()/_load_game_state(), diese Klasse
## kennt den Inhalt nicht.

const SAVE_PATH := "user://saves/savegame.sav"

## Von MainMenu vor dem Szenenwechsel gesetzt, von World._ready() gelesen —
## einziger Weg, geladene Daten über den Szenenwechsel hinweg mitzugeben
## (Autoloads überleben change_scene_to_file(), lokale Szenen-Variablen nicht).
var pending_load: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_to_disk(data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(var_to_str(data))
	return true


func load_from_disk() -> Dictionary:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = str_to_var(file.get_as_text())
	if data is Dictionary:
		return data
	return {}
