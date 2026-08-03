extends Node
## Globale Gamepad-Cursor-Steuerung (2026-08-03, Bugfix nach Nutzer-Report
## "konnte kein controller im hauptmenü benutzen") — bewegt den echten
## Fenster-Mauszeiger per rechtem Stick und synthetisiert A/B-Klicks als
## echte Maus-Events, UNABHÄNGIG von der aktuell geladenen Szene. Vorher
## saß dieser Code nur in scenes/world/World.gd — funktionierte also erst,
## NACHDEM man World.tscn schon erreicht hatte, was ohne Maus/Tastatur gar
## nicht ging (MainMenu/Lobby hatten keinerlei Gamepad-Handling). Als
## Autoload lebt dieser Code dauerhaft unter /root, unabhängig vom
## Szenenwechsel — MainMenu/Lobby/World profitieren automatisch gleich mit,
## kein Duplizieren pro Szene nötig.
##
## World.gd nutzt zusätzlich, weltspezifisch, den gehaltenen linken Trigger
## + rechten Stick für Kamera-Rotation/-Neigung — setzt dafür
## `cursor_suspended = true`, damit sich beide Systeme nicht gleichzeitig
## um denselben Stick streiten (siehe docs/world.md, "Gamepad-Steuerung").

const DEADZONE := 0.2
const CURSOR_SPEED := 1000.0  # Pixel/s bei vollem Stick-Ausschlag

var cursor_suspended: bool = false
var _button_state: Dictionary = {}


func _process(delta: float) -> void:
	if Input.get_connected_joypads().is_empty():
		return
	if not cursor_suspended:
		_move_cursor(delta)
	# Autoloads laufen VOR der aktuellen Szene (Godot verarbeitet _process()
	# in Baum-Reihenfolge, Autoloads sind die ersten Kinder von /root) —
	# hier auf false zurückgesetzt, World._handle_gamepad_input() setzt es
	# im selben Frame wieder auf true, solange der linke Trigger hält.
	# Verhindert, dass cursor_suspended "hängen bleibt", falls World.tscn
	# ausgerechnet bei gehaltenem Trigger verlassen wird (z. B. übers
	# Pause-Menü) — in jeder anderen Szene setzt niemand mehr true, der
	# Cursor bleibt dadurch garantiert wieder bedienbar.
	cursor_suspended = false
	_handle_button_transitions(JOY_BUTTON_A, _on_a_pressed, _on_a_released)
	_handle_button_transitions(JOY_BUTTON_B, _on_b_pressed, _on_b_released)


func _move_cursor(delta: float) -> void:
	var cursor_x := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var cursor_y := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(cursor_x) <= DEADZONE and absf(cursor_y) <= DEADZONE:
		return
	# Explizit typisiert statt `:=` — get_viewport().size ließ sich beim
	# ersten Versuch (damals noch in World.gd) nicht auf einen festen Typ
	# inferieren (Parser-Fehler, Spiel startete gar nicht erst), siehe
	# docs/ARCHITECTURE.md, bekannte Variant-Inferenz-Falle.
	var viewport_size: Vector2i = get_viewport().size
	var new_pos: Vector2 = get_viewport().get_mouse_position() + Vector2(cursor_x, cursor_y) * CURSOR_SPEED * delta
	new_pos.x = clampf(new_pos.x, 0.0, viewport_size.x)
	new_pos.y = clampf(new_pos.y, 0.0, viewport_size.y)
	Input.warp_mouse(new_pos)
	# Zusätzliches Motion-Event für UI-Hover-Highlighting (Buttons leuchten
	# beim "Drüberfahren" auf, wie bei echter Maus) — Input.warp_mouse()
	# allein löst das nicht aus.
	var motion := InputEventMouseMotion.new()
	motion.position = new_pos
	motion.global_position = new_pos
	Input.parse_input_event(motion)


func _synthesize_click(button_index: int, pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = button_index
	click.pressed = pressed
	click.position = get_viewport().get_mouse_position()
	click.global_position = click.position
	Input.parse_input_event(click)


func _handle_button_transitions(button: JoyButton, on_pressed: Callable, on_released: Callable) -> void:
	# "Gerade gedrückt"/"gerade losgelassen"-Erkennung ohne InputMap-Action
	# — Input.is_joy_button_pressed() allein ist Level-getriggert. Vorher/
	# Nachher-Zustand wird hier EINMAL pro Button pro Frame verglichen UND
	# aktualisiert (zwei getrennte Aufrufe für Press/Release würde denselben
	# Bug reproduzieren, der schon einmal in World.gd gefixt wurde: der
	# zweite Aufruf sähe den vom ersten schon aktualisierten Zustand statt
	# des tatsächlichen Vorframe-Werts).
	var was_pressed: bool = _button_state.get(button, false)
	var is_pressed := Input.is_joy_button_pressed(0, button)
	_button_state[button] = is_pressed
	if is_pressed and not was_pressed:
		on_pressed.call()
	elif not is_pressed and was_pressed and on_released.is_valid():
		on_released.call()


func _on_a_pressed() -> void:
	_synthesize_click(MOUSE_BUTTON_LEFT, true)


func _on_a_released() -> void:
	_synthesize_click(MOUSE_BUTTON_LEFT, false)


func _on_b_pressed() -> void:
	_synthesize_click(MOUSE_BUTTON_RIGHT, true)


func _on_b_released() -> void:
	_synthesize_click(MOUSE_BUTTON_RIGHT, false)
