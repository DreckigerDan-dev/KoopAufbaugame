extends StaticBody3D
## Banditen-Hideout — Spawner-Gebäude analog ZombieNest.gd, aber mit ZWEI
## bewussten Unterschieden (siehe docs/bandits.md):
## 1. Gekappt statt unbegrenzt (MAX_ACTIVE_BANDITS) — ein Camp soll sich wie
##    eine begrenzte Garnison anfühlen, kein endloser Nachschub wie beim
##    Zombie-Nest.
## 2. Bei Zerstörung gibt es einmaligen Bonus-Loot an den Verursacher, das
##    Hideout selbst verschwindet PERMANENT (kein Wiederaufbau) — passt zum
##    "Loot ist endlich"-Prinzip (Infos/01 Architektur.md, "Scavenging").

const MAX_HP := 200
const SPAWN_INTERVAL := 30.0
const SPAWN_SCATTER := 3.0
# Duplikat als World.BANDIT_HIDEOUT_MAX_ACTIVE_BANDITS (World.gd prüft die
# Kappung selbst in spawn_hideout_bandit(), kennt dieses Skript aber
# bewusst nicht als Typ) — bei Änderung BEIDE Stellen anpassen.
const MAX_ACTIVE_BANDITS := 3

var bandit_hideout_id: int = 0
var hp: int = MAX_HP
var _spawn_timer: float = SPAWN_INTERVAL


func _ready() -> void:
	_update_color()
	if not multiplayer.is_server():
		set_process(false)


func _process(delta: float) -> void:
	if get_tree().current_scene.is_paused():
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = SPAWN_INTERVAL
	var offset := Vector3(randf_range(-SPAWN_SCATTER, SPAWN_SCATTER), 0, randf_range(-SPAWN_SCATTER, SPAWN_SCATTER))
	get_tree().current_scene.spawn_hideout_bandit(bandit_hideout_id, global_position + offset)


func take_damage(amount: int, source_peer_id: int = 0) -> void:
	# Kein RPC — ausschließlich host-seitig aufgerufen (GuardPost._try_fire()
	# oder Survivor._process_attack(), siehe docs/survivor.md), gleiches
	# Muster wie ZombieNest.take_damage(). Anders als dort wird
	# source_peer_id hier tatsächlich gebraucht (Bonus-Loot beim Klären).
	var new_hp: int = max(hp - amount, 0)
	_sync_hp.rpc(new_hp)
	if new_hp <= 0:
		get_tree().current_scene.grant_bandit_hideout_cleared_loot(source_peer_id)
		_die.rpc()


@rpc("authority", "call_local", "reliable")
func _sync_hp(new_hp: int) -> void:
	hp = new_hp
	_update_color()


@rpc("authority", "call_local", "reliable")
func _die() -> void:
	queue_free()


func _update_color() -> void:
	var mesh: MeshInstance3D = get_node_or_null("Mesh")
	if mesh == null:
		return
	var ratio: float = float(hp) / float(MAX_HP)
	var mat := StandardMaterial3D.new()
	# Dunkles Ockerbraun statt ZombieNest-Rot — eigene, aber verwandte
	# "Bedrohungs-Bau"-Farbfamilie (siehe docs/bandits.md).
	mat.albedo_color = Color(0.4, 0.28, 0.1).lerp(Color(0.05, 0.05, 0.05), 1.0 - ratio)
	mesh.set_surface_override_material(0, mat)
