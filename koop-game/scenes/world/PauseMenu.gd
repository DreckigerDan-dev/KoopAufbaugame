extends CanvasLayer
## Pause-Menü im Spiel — Escape-Taste (siehe World._unhandled_input()).
## Einziger Weg, World.tscn wieder zu verlassen (vorher gab es keinen, siehe
## docs/save_load.md). "Speichern" nur für den Host sichtbar, gleiches
## Muster wie Lobby.start_button.visible = multiplayer.is_server().

@onready var panel: Control = $Panel
@onready var save_button: Button = $Panel/VBoxContainer/SaveButton
@onready var settings_button: Button = $Panel/VBoxContainer/SettingsButton
@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton
@onready var settings_menu: CanvasLayer = $SettingsMenu


func _ready() -> void:
	visible = false
	save_button.visible = multiplayer.is_server()
	save_button.pressed.connect(_on_save_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_menu.closed.connect(_on_settings_closed)
	resume_button.pressed.connect(close)
	main_menu_button.pressed.connect(_on_main_menu_pressed)


func toggle() -> void:
	# Bei offenen Einstellungen erst eine Ebene zurück statt die ganze
	# Pause-CanvasLayer umzuschalten — sonst könnte "visible" hier auf false
	# gehen, während panel.visible dank _on_settings_closed() später wieder
	# auf true gesetzt wird: Panel wäre "sichtbar", aber innerhalb einer
	# unsichtbaren CanvasLayer, also trotzdem nicht zu sehen.
	if settings_menu.visible:
		settings_menu.close()
		return
	visible = not visible


func close() -> void:
	visible = false


func _on_settings_pressed() -> void:
	# Eigenes Panel ausblenden, solange die Einstellungen offen sind (beide
	# liegen sonst sichtbar übereinander, siehe docs/settings.md) — die
	# CanvasLayer selbst bleibt sichtbar, damit $SettingsMenu (Kind-Node
	# davon) weiter gerendert wird.
	panel.visible = false
	settings_menu.open()


func _on_settings_closed() -> void:
	panel.visible = true


func _on_save_pressed() -> void:
	get_tree().current_scene.save_game()


func _on_main_menu_pressed() -> void:
	NetworkManager.leave_game()
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
