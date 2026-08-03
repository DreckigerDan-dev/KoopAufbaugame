extends CanvasLayer
## Rettungsmechanik + Game Over (2026-08-04, Punkt 6 des Mechaniken-
## Berichts, siehe docs/mechanics-review.md, "Fehlende Enden/Ziele").
## Zwei unabhängige Panels: LostPanel erscheint für einen Spieler, dessen
## Home-Base gerade zerstört wurde ("Hilfe anfragen" oder "Aufgeben"),
## GameOverPanel erst danach, falls er sich gegen Hilfe entscheidet (oder
## niemand hilft). World.gd steuert beide von außen (World.home_base_
## destroyed()/request_give_up()), gleiches Cross-Node-Muster wie
## PauseMenu.gd.

@onready var lost_panel: Panel = $LostPanel
@onready var help_button: Button = $LostPanel/VBoxContainer/HelpButton
@onready var give_up_button: Button = $LostPanel/VBoxContainer/GiveUpButton
@onready var game_over_panel: Panel = $GameOverPanel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $GameOverPanel/VBoxContainer/MainMenuButton


func _ready() -> void:
	lost_panel.visible = false
	game_over_panel.visible = false
	help_button.pressed.connect(_on_help_pressed)
	give_up_button.pressed.connect(_on_give_up_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)


func show_lost_panel() -> void:
	lost_panel.visible = true
	# Hilfe anfragen ergibt solo keinen Sinn — niemand da, der helfen könnte.
	help_button.visible = NetworkManager.players.size() > 1


func hide_lost_panel() -> void:
	lost_panel.visible = false


func show_game_over() -> void:
	lost_panel.visible = false
	game_over_panel.visible = true


func _on_help_pressed() -> void:
	get_tree().current_scene.request_help_offer.rpc_id(1, multiplayer.get_unique_id())
	help_button.disabled = true


func _on_give_up_pressed() -> void:
	get_tree().current_scene.request_give_up.rpc_id(1, multiplayer.get_unique_id())


func _on_restart_pressed() -> void:
	# Gleicher Sprung wie MainMenu._on_solo_pressed() — verlässt die
	# aktuelle (für diesen Spieler verlorene) Session und startet direkt
	# solo neu, ohne Umweg über das Hauptmenü.
	NetworkManager.leave_game()
	var err := NetworkManager.host_game()
	if err == OK:
		GameManager.change_state(GameManager.GameState.IN_GAME)


func _on_main_menu_pressed() -> void:
	NetworkManager.leave_game()
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
