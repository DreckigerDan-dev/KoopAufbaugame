extends StaticBody3D
## Fällbarer Baum — neue Ressourcenquelle für Bautrupps (siehe
## docs/survivor.md, "Trupp-Arten"). Dynamisch über MultiplayerSpawner
## erzeugt (siehe World._spawn_trees_near()), in der Nähe jeder neu
## entstandenen/erweiterten Zone (Start-Basis-Wahl, Gebäude claimen).
## take_damage()/_die() folgen demselben Muster wie Wall.gd/ZombieNest.gd —
## kein RPC nötig, ausschließlich host-seitig aufgerufen (von
## Survivor._process_harvest()). Markier-System (siehe docs/survivor.md,
## "Trupp-Arten", "Markier-System"): is_marked steuert, ob sich freie
## Bautrupps diesen Baum selbstständig vornehmen.

const MAX_HP := 60
const YIELD := {"wood": 15}

var tree_id: int = 0
var hp: int = MAX_HP
var is_marked: bool = false


func _ready() -> void:
	_update_color()


func toggle_marked() -> void:
	# Aufgerufen von World.request_toggle_harvest_mark() (schon host-seitig).
	_set_marked.rpc(not is_marked)


@rpc("authority", "call_local", "reliable")
func _set_marked(marked: bool) -> void:
	is_marked = marked
	_update_color()


func take_damage(amount: int) -> void:
	var new_hp: int = max(hp - amount, 0)
	_sync_hp.rpc(new_hp)
	if new_hp <= 0:
		_die.rpc()


@rpc("authority", "call_local", "reliable")
func _sync_hp(new_hp: int) -> void:
	hp = new_hp
	_update_color()


@rpc("authority", "call_local", "reliable")
func _die() -> void:
	queue_free()


func _update_color() -> void:
	# Zwei getrennte Meshes (Stamm + Krone, siehe Tree.tscn) statt einem
	# einzelnen Zylinder — deutlich als Baum erkennbar statt als dünner
	# Pfosten (Nutzer-Feedback: kaum unterscheidbar). Nur die Krone
	# reagiert auf HP (Grün -> welkes Braun beim Fällen, gleiches Prinzip
	# wie Zombie/Wall/ZombieNest), der Stamm bleibt konstant braun.
	var trunk: MeshInstance3D = get_node_or_null("Trunk")
	if trunk != null:
		var trunk_mat := StandardMaterial3D.new()
		trunk_mat.albedo_color = Color(0.35, 0.24, 0.14)
		trunk.set_surface_override_material(0, trunk_mat)
	var foliage: MeshInstance3D = get_node_or_null("Foliage")
	if foliage == null:
		return
	var ratio: float = float(hp) / float(MAX_HP)
	# Markiert (noch unberührt) -> Gold statt Grün, klar sichtbares "steht
	# auf der Liste"-Signal. Läuft trotzdem weiter über denselben
	# HP-Verlauf Richtung welkem Braun, sobald tatsächlich gefällt wird.
	var foliage_base := Color(0.9, 0.75, 0.1) if is_marked else Color(0.15, 0.4, 0.1)
	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = foliage_base.lerp(Color(0.4, 0.32, 0.15), 1.0 - ratio)
	foliage.set_surface_override_material(0, foliage_mat)
