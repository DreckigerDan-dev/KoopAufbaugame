extends Node2D
## Startbildschirm: Name eingeben, Solo starten, Koop hosten/joinen, Laden,
## Einstellungen. Siehe docs/ARCHITECTURE.md, docs/save_load.md.

@onready var name_edit: LineEdit = $CanvasLayer/Panel/VBoxContainer/NameEdit
@onready var solo_button: Button = $CanvasLayer/Panel/VBoxContainer/SoloButton
@onready var host_button: Button = $CanvasLayer/Panel/VBoxContainer/HostButton
@onready var address_edit: LineEdit = $CanvasLayer/Panel/VBoxContainer/AddressEdit
@onready var join_button: Button = $CanvasLayer/Panel/VBoxContainer/JoinButton
@onready var load_button: Button = $CanvasLayer/Panel/VBoxContainer/LoadButton
@onready var settings_button: Button = $CanvasLayer/Panel/VBoxContainer/SettingsButton
@onready var status_label: Label = $CanvasLayer/Panel/VBoxContainer/StatusLabel
@onready var settings_menu: CanvasLayer = $SettingsMenu


func _ready() -> void:
	solo_button.pressed.connect(_on_solo_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(settings_menu.open)
	load_button.disabled = not SaveManager.has_save()
	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)


func _on_solo_pressed() -> void:
	# Direkt ins Spiel statt über die Lobby zu warten — bei nur einem
	# Spieler gibt es nichts, worauf man warten müsste. Andere Peers können
	# trotzdem noch beitreten, sobald der Host schon im Spiel ist (siehe
	# World._on_player_connected()).
	_apply_player_name()
	var err := NetworkManager.host_game()
	if err != OK:
		status_label.text = "Start fehlgeschlagen (Fehler %d)" % err
		return
	GameManager.change_state(GameManager.GameState.IN_GAME)


func _on_load_pressed() -> void:
	# Gleicher Solo-Sprung wie oben (siehe dort), zusätzlich mit
	# SaveManager.pending_load befüllt — World._ready() erkennt das und
	# stellt den gespeicherten Zustand wieder her statt frisch zu starten
	# (siehe docs/save_load.md).
	var data := SaveManager.load_from_disk()
	if data.is_empty():
		status_label.text = "Kein Speicherstand gefunden."
		return
	_apply_player_name()
	var err := NetworkManager.host_game()
	if err != OK:
		status_label.text = "Start fehlgeschlagen (Fehler %d)" % err
		return
	SaveManager.pending_load = data
	GameManager.change_state(GameManager.GameState.IN_GAME)


func _on_host_pressed() -> void:
	_apply_player_name()
	var err := NetworkManager.host_game()
	if err != OK:
		status_label.text = "Host fehlgeschlagen (Fehler %d)" % err
		return
	GameManager.change_state(GameManager.GameState.LOBBY)


func _on_join_pressed() -> void:
	_apply_player_name()
	var err := NetworkManager.join_game(address_edit.text)
	if err != OK:
		status_label.text = "Join fehlgeschlagen (Fehler %d)" % err
		return
	status_label.text = "Verbinde..."


func _on_connection_succeeded() -> void:
	# Kein lokaler Sprung mehr auf LOBBY hier — der Host schickt über
	# GameManager._on_peer_connected() gezielt seinen aktuellen State
	# (LOBBY, wenn er selbst noch wartet, oder direkt IN_GAME, wenn er schon
	# mittendrin ist — z.B. nach Solo-Start oder Laden eines Spielstands).
	# Ohne das landete ein später beitretender Peer immer in der Lobby und
	# wartete dort ergebnislos, selbst wenn der Host längst spielte.
	status_label.text = "Verbunden, warte auf Server..."


func _on_connection_failed() -> void:
	status_label.text = "Verbindung fehlgeschlagen."


func _apply_player_name() -> void:
	var player_name := name_edit.text.strip_edges()
	if not player_name.is_empty():
		NetworkManager.player_info["name"] = player_name
