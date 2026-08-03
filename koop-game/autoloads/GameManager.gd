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
	# Wird NICHT mehr direkt von change_state() angefahren (siehe dort) —
	# LoadingScreen.gd liest diesen Eintrag, um World.tscn asynchron im
	# Hintergrund zu laden. Einzige Quelle für den Pfad, damit er nicht an
	# zwei Stellen gepflegt werden muss.
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
	# gekommen), durchläuft der neue Peer denselben Ladebildschirm (siehe
	# change_state()) und holt sich in World.tscn danach über
	# request_catch_up()/request_city_zones() den Rest (siehe World.gd,
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
	if new_state == GameState.IN_GAME:
		# Ladebildschirm dazwischen (Punkt 27 der Gesamtliste, siehe
		# docs/world.md) statt direktem change_scene_to_file() zu
		# World.tscn — LoadingScreen.gd lädt die Welt asynchron im
		# Hintergrund und wechselt selbst erst um, sobald fertig. Gilt für
		# JEDEN Peer gleich (auch spät beitretende, siehe
		# _on_peer_connected() oben), weil change_state() dafür ebenfalls
		# durchläuft.
		get_tree().change_scene_to_file("res://scenes/loading/LoadingScreen.tscn")
		return
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
