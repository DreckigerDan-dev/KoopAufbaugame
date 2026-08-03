extends Control
## Ladebildschirm zwischen Lobby ("Spiel starten") und Welt (Punkt 27 der
## Gesamtliste, siehe docs/world.md) — GameManager.change_state() schickt
## jeden Peer beim Wechsel zu GameState.IN_GAME erst hierher statt direkt
## zu World.tscn. Lädt World.tscn ASYNCHRON im Hintergrund
## (ResourceLoader.load_threaded_request()) statt des vorherigen
## synchronen change_scene_to_file(), das für ein kurzes, unschönes
## Einfrieren sorgte (Nutzer-Beobachtung: "die map braucht kurz zum rein
## laden"). Zufälliger Lade-Spruch (Nutzerwunsch: "sowas wie der hamster
## beeilt sich") ist rein kosmetisch, hat keinen Bezug zum tatsächlichen
## Ladefortschritt.

const LOADING_TIPS: Array[String] = [
	"Der Hamster im Server-Rad wird gerade geölt ...",
	"Bitcoin-Mining fast fertig ...",
	"Hast du heute schon genug getrunken?",
	"Zombies werden liebevoll von Hand drapiert ...",
	"Die Straßen werden noch schnell geteert ...",
	"Wachposten üben Zielübungen im Hinterhof ...",
	"Der Kaffee für die Überlebenden kocht noch ...",
	"Bäume werden einzeln von Hand gepflanzt ...",
	"Der Bautrupp sucht noch seinen Helm ...",
	"Die Zombie-Statisten proben ihre Rolle ...",
	"Ladebalken wird poliert ...",
	"Loot-Tabellen werden gewürfelt ...",
	"Die Karte wird gebügelt, damit sie flach bleibt ...",
	"Wachtürme werden auf Wackelkontakt geprüft ...",
	"Rucksäcke werden auf blinde Passagiere untersucht ...",
	"Der Server-Hamster braucht kurz eine Pause ...",
]

@onready var tip_label: Label = $CenterContainer/VBoxContainer/TipLabel
@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar

# Aus GameManager.STATE_SCENES statt einer eigenen Pfad-Konstante — sonst
# müsste derselbe Pfad an zwei Stellen gepflegt werden.
var _world_scene_path: String = GameManager.STATE_SCENES[GameManager.GameState.IN_GAME]
var _progress: Array = []


func _ready() -> void:
	tip_label.text = LOADING_TIPS[randi() % LOADING_TIPS.size()]
	ResourceLoader.load_threaded_request(_world_scene_path)


func _process(_delta: float) -> void:
	var status := ResourceLoader.load_threaded_get_status(_world_scene_path, _progress)
	if not _progress.is_empty():
		progress_bar.value = _progress[0] * 100.0
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var world_scene: PackedScene = ResourceLoader.load_threaded_get(_world_scene_path)
			get_tree().change_scene_to_packed(world_scene)
		ResourceLoader.THREAD_LOAD_FAILED:
			# Kein bekannter Fehlerfall in der Praxis (World.tscn ist immer
			# vorhanden) — Fallback auf den alten synchronen Weg statt eines
			# Endlos-Ladebildschirms.
			get_tree().change_scene_to_file(_world_scene_path)
