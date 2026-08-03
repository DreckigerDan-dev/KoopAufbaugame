extends Node
## Globaler Spielzustand und Szenenwechsel. Siehe docs/ARCHITECTURE.md.

signal state_changed(old_state: GameState, new_state: GameState)

enum GameState {
	MAIN_MENU,
	LOBBY,
	IN_GAME,
}

const STATE_SCENES := {
	GameState.MAIN_MENU: "res://scenes/main_menu/MainMenu.tscn",
	GameState.LOBBY: "res://scenes/lobby/Lobby.tscn",
	GameState.IN_GAME: "res://scenes/world/World.tscn",
}

var current_state: GameState = GameState.MAIN_MENU


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)


func _on_peer_connected(id: int) -> void:
	# Späteren Beitritt ermöglichen: der Host schickt jedem neu verbundenen
	# Peer gezielt seinen AKTUELLEN State (statt dass der Client lokal blind
	# LOBBY annimmt, siehe MainMenu._on_connection_succeeded()). Ist der Host
	# schon IN_GAME (egal ob per "Spiel starten", Solo oder Laden dorthin
	# gekommen), landet der neue Peer direkt in World.tscn und holt sich dort
	# über request_catch_up()/request_city_zones() den Rest (siehe World.gd,
	# _ready()).
	if not multiplayer.is_server():
		return
	_rpc_change_state.rpc_id(id, current_state)


func change_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	var old_state := current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)
	var scene_path: String = STATE_SCENES.get(new_state, "")
	if scene_path.is_empty():
		return
	get_tree().change_scene_to_file(scene_path)


func start_game() -> void:
	## Nur der Host darf das Spiel starten; wechselt bei allen Peers
	## gleichzeitig in den IN_GAME-State (siehe docs/world.md).
	if not multiplayer.is_server():
		return
	_rpc_change_state.rpc(GameState.IN_GAME)


@rpc("authority", "call_local", "reliable")
func _rpc_change_state(new_state: GameState) -> void:
	change_state(new_state)
