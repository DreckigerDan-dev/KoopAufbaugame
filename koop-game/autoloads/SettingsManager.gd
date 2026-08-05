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
const DEFAULT_INVERT_MOUSE_Y := false
# 2026-08-05, Nutzerwunsch "am besten über Einstellungen kann man das alles
# umstellen wie man will" — Kamera-Schwenk per Maus-Ziehen (World.gd
# MOUSE_BUTTON_MIDDLE + MapView.gd Rechtsklick-Ziehen, EIN gemeinsamer
# Schalter für beide) und Zoom-zur-Maus (World._zoom()) sind standardmäßig
# AN (neue Features, aber unauffällig genug für einen Opt-out statt
# Opt-in).
const DEFAULT_PAN_WITH_MOUSE := true
const DEFAULT_ZOOM_TO_CURSOR := true

var fullscreen: bool = DEFAULT_FULLSCREEN
var master_volume_db: float = DEFAULT_MASTER_VOLUME_DB
var invert_mouse_y: bool = DEFAULT_INVERT_MOUSE_Y
var pan_with_mouse: bool = DEFAULT_PAN_WITH_MOUSE
var zoom_to_cursor: bool = DEFAULT_ZOOM_TO_CURSOR


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


func set_invert_mouse_y(enabled: bool) -> void:
	invert_mouse_y = enabled
	_save_to_disk()


func set_pan_with_mouse(enabled: bool) -> void:
	pan_with_mouse = enabled
	_save_to_disk()


func set_zoom_to_cursor(enabled: bool) -> void:
	zoom_to_cursor = enabled
	_save_to_disk()


func _load_from_disk() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	fullscreen = config.get_value(SECTION, "fullscreen", DEFAULT_FULLSCREEN)
	master_volume_db = config.get_value(SECTION, "master_volume_db", DEFAULT_MASTER_VOLUME_DB)
	invert_mouse_y = config.get_value(SECTION, "invert_mouse_y", DEFAULT_INVERT_MOUSE_Y)
	pan_with_mouse = config.get_value(SECTION, "pan_with_mouse", DEFAULT_PAN_WITH_MOUSE)
	zoom_to_cursor = config.get_value(SECTION, "zoom_to_cursor", DEFAULT_ZOOM_TO_CURSOR)


func _save_to_disk() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "master_volume_db", master_volume_db)
	config.set_value(SECTION, "invert_mouse_y", invert_mouse_y)
	config.set_value(SECTION, "pan_with_mouse", pan_with_mouse)
	config.set_value(SECTION, "zoom_to_cursor", zoom_to_cursor)
	config.save(SETTINGS_PATH)
