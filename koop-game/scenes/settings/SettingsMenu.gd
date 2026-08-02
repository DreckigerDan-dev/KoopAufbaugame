extends CanvasLayer
## Einstellungs-Overlay — als Kind-Node sowohl in MainMenu.tscn als auch in
## PauseMenu.tscn eingehängt (ein Overlay, zwei Aufrufer, siehe
## docs/settings.md), statt die UI zu duplizieren. `open()`/`close()` statt
## eigener Szenenwechsel, da es rein lokale Client-UI ist (keine
## Netzwerk-Relevanz).

signal closed

@onready var fullscreen_check: CheckButton = $Panel/VBoxContainer/FullscreenCheck
@onready var volume_slider: HSlider = $Panel/VBoxContainer/VolumeSlider
@onready var back_button: Button = $Panel/VBoxContainer/BackButton


func _ready() -> void:
	visible = false
	fullscreen_check.button_pressed = SettingsManager.fullscreen
	volume_slider.value = SettingsManager.master_volume_db
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	back_button.pressed.connect(close)


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _on_fullscreen_toggled(enabled: bool) -> void:
	SettingsManager.set_fullscreen(enabled)


func _on_volume_changed(value: float) -> void:
	SettingsManager.apply_master_volume(value)
