extends CanvasLayer
## Blockiert Eingaben, bis ein Nicht-Host-Peer die initiale Welt-Replikation
## (Gebäude/Fahrzeuge/Bäume/Ressourcen aus World._generate_world() bzw.
## _load_game_state()) tatsächlich vollständig empfangen hat (Bugfix
## 2026-08-04, Nutzer-Testbericht: "zweiter Spieler hat lange
## Minimap-Ladezeiten und konnte keine Startbase wählen"). Ursache: bei
## aktuell 1750 Gebäuden + hunderten Bäumen/Ressourcen (siehe
## docs/benchmarks.md) läuft jede einzelne Entität über einen eigenen
## MultiplayerSpawner-Spawn — der Host hat alles sofort lokal, ein Client
## muss aber jede Nachricht erst über das Netzwerk empfangen. Der bisherige
## Ladebildschirm (siehe docs/loading.md) deckt nur das Laden der
## World.tscn-DATEI ab, nicht diese nachgelagerte Replikation — der Spieler
## landete vorher in einer noch halb-leeren Welt. Volle Steuerung/Logik in
## World.gd (_start_world_sync_wait()/_check_world_sync_complete()), dieses
## Script ist nur die reine Anzeige/Eingabesperre, gleiches Cross-Node-
## Muster wie GameOverUI.gd.

@onready var blocker: Control = $Blocker
@onready var progress_bar: ProgressBar = $Blocker/VBoxContainer/ProgressBar
@onready var label: Label = $Blocker/VBoxContainer/Label


func _ready() -> void:
	visible = false


func show_overlay() -> void:
	visible = true
	progress_bar.value = 0.0


func update_progress(received: int, total: int) -> void:
	progress_bar.value = 100.0 if total <= 0 else float(received) / float(total) * 100.0


func hide_overlay() -> void:
	visible = false
