extends Node
## Persistente Grundeinstellungen (Vollbild + Master-Lautstärke). Siehe
## docs/settings.md. Bewusst schlank: im Projekt wird aktuell nirgends Sound
## abgespielt (kein AudioStreamPlayer, `assets/audio/` ist leer) — die
## Lautstärke wird trotzdem korrekt am Master-Bus verdrahtet, hat nur noch
## keine hörbare Wirkung, bis es echten Sound gibt.

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "settings"
const DEFAULT_FULLSCREEN := false
const DEFAULT_MASTER_VOLUME_DB := 0.0

var fullscreen: bool = DEFAULT_FULLSCREEN
var master_volume_db: float = DEFAULT_MASTER_VOLUME_DB


func _ready() -> void:
	_load_from_disk()
	set_fullscreen(fullscreen)
	apply_master_volume(master_volume_db)


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	_save_to_disk()


func apply_master_volume(db: float) -> void:
	master_volume_db = db
	var bus_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, db)
	_save_to_disk()


func _load_from_disk() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	fullscreen = config.get_value(SECTION, "fullscreen", DEFAULT_FULLSCREEN)
	master_volume_db = config.get_value(SECTION, "master_volume_db", DEFAULT_MASTER_VOLUME_DB)


func _save_to_disk() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "master_volume_db", master_volume_db)
	config.save(SETTINGS_PATH)
