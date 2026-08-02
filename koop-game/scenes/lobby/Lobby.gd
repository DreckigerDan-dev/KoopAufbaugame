extends Node2D
## Lobby: zeigt verbundene Spieler live an. Siehe docs/ARCHITECTURE.md.

@onready var player_list: ItemList = $CanvasLayer/Panel/VBoxContainer/PlayerList
@onready var start_button: Button = $CanvasLayer/Panel/VBoxContainer/StartButton
@onready var leave_button: Button = $CanvasLayer/Panel/VBoxContainer/LeaveButton


func _ready() -> void:
	start_button.visible = multiplayer.is_server()
	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	_refresh_player_list()


func _refresh_player_list() -> void:
	player_list.clear()
	for peer_id in NetworkManager.players:
		var info: Dictionary = NetworkManager.players[peer_id]
		var suffix := " (Host)" if peer_id == 1 else ""
		player_list.add_item("%s%s" % [info.get("name", "?"), suffix])


func _on_player_connected(_peer_id: int, _info: Dictionary) -> void:
	_refresh_player_list()


func _on_player_disconnected(_peer_id: int) -> void:
	_refresh_player_list()


func _on_start_pressed() -> void:
	GameManager.start_game()


func _on_leave_pressed() -> void:
	NetworkManager.leave_game()
	GameManager.change_state(GameManager.GameState.MAIN_MENU)


func _on_server_disconnected() -> void:
	GameManager.change_state(GameManager.GameState.MAIN_MENU)
