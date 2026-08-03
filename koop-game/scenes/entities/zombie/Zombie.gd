extends StaticBody3D
## Wandert ziellos, verfolgt aber nahe Survivor, greift sie an und nimmt
## dabei selbst Gegenschaden (Survivor "wehrt sich" automatisch bei
## Kontakt), plus Lärm-System (Kampf alarmiert nahe andere Zombies).
## Host-autoritativ simuliert (gleiches Muster wie Survivor). Siehe
## docs/zombies.md. 3D-Migration (siehe docs/3d-migration.md): ersetzt
## Node2D/ColorRect durch StaticBody3D/CapsuleMesh, Vector2 durch Vector3.

const MAX_HP := 40
const WANDER_SPEED := 2.0
const CHASE_SPEED := 5.0
const WANDER_RADIUS := 6.0
const IDLE_TIME_MIN := 1.0
const IDLE_TIME_MAX := 3.0
const DETECT_RADIUS := 8.0
const NOISE_RADIUS := 11.0
const GIVE_UP_RADIUS := 14.0
const ATTACK_RANGE := 1.2
const ATTACK_COOLDOWN := 1.0
const ATTACK_DAMAGE := 10
const COUNTER_DAMAGE := 15
# Performance: Zielsuche throttlen (siehe docs/zombies.md, "Performance:
# Zielsuche throttlen" — Punkt 3 der Performance-Liste, Reaktion auf den
# 500-Zombie/15-FPS-Benchmark, vermutlich der dominante Overhead). Vorher
# rief _update_chase_target() für JEDEN ziellosen Zombie JEDEN Frame
# _find_nearest_target() auf (Schleife über "living"+"searchable", ~130
# Einträge) — bei 500 Zombies 500× pro Frame. Jetzt gedrosselt; die
# Give-up-Prüfung für einen schon verfolgten Ziel bleibt bewusst unthrottled
# (reine Distanzprüfung, billig, soll ohne Verzögerung reagieren).
const TARGET_SEARCH_INTERVAL := 0.2
# Zombie-Typen (siehe docs/zombies.md, "Zombie-Typen") — aus
# Infos/01 Architektur.md: "zwei Typen — Standard-Läufer sowie ein zäher
# Brute (langsam, viel HP, hoher Schaden)". Gleiches Script wie der
# Standard-Zombie (nur Zahlenwerte unterscheiden sich, keine eigene
# Verhaltenslogik nötig) — analog zu Wall.gd/`is_gate`, aber als eigene
# Szene `ZombieBrute.tscn` (größere Kapsel) statt nur einem Export-Flag
# auf derselben Szene.
@export var is_brute: bool = false
const BRUTE_MAX_HP := 100
const BRUTE_WANDER_SPEED := 1.2
const BRUTE_CHASE_SPEED := 3.5
const BRUTE_ATTACK_DAMAGE := 25
# Nacht-Schadensbonus (Nutzerwunsch: "Zombies ab 22 Uhr bis 4 Uhr morgens
# 20% stärker", siehe World.NIGHT_START_HOUR/NIGHT_END_HOUR,
# World.is_night()) — gilt für Standard-Zombies UND Brutes gleichermaßen
# (multipliziert den jeweils schon typ-abhängigen _attack_damage in
# _try_attack(), nicht die HP, siehe docs/zombies.md,
# "Nacht-Schadensbonus").
const ZOMBIE_NIGHT_DAMAGE_MULTIPLIER := 1.2
# Physik-Ebene 2 = Mauern/Tore (siehe scenes/entities/wall/Wall.tscn,
# `collision_layer = 2`) — bewusst dupliziert in Survivor.gd statt geteilt,
# gleiches Muster wie schon bei _alert_nearby_zombies() (siehe
# docs/building.md, "Bewusst dupliziert statt geteilt").
const OBSTACLE_LAYER := 2

var zombie_id: int = 0
var hp: int = 0

var _home_position: Vector3 = Vector3.ZERO
var _wander_target: Vector3 = Vector3.ZERO
var _idle_timer: float = 0.0
var _chase_target: Node3D = null
var _attack_timer: float = 0.0
# In _ready() aus is_brute abgeleitet (siehe dort) — @export-Werte stehen
# erst NACH der Szenen-Deserialisierung fest, ein Feld-Standardwert wie
# `var hp: int = MAX_HP` würde also immer den Nicht-Brute-Wert nehmen,
# selbst für eine Brute-Instanz (gleiches Muster wie Wall.gd, `_ready()`
# setzt `hp` dort aus demselben Grund explizit statt per Feld-Default).
var _max_hp: int = 0
var _wander_speed: float = 0.0
var _chase_speed: float = 0.0
var _attack_damage: int = 0
# Wer diesem Zombie zuletzt Schaden zugefügt hat (siehe take_damage()) —
# entscheidet beim Tod, wer den Loot-Drop bekommt (siehe
# World.grant_zombie_loot(), docs/zombies.md, "Zombie-Loot-Drop"). 0 =
# noch kein bekannter Verursacher (kommt in der Praxis nicht vor, da
# jeder Schaden an einem Zombie schon von Survivor-Gegenschaden oder
# Wachposten-Beschuss kommt, beide mit bekanntem owner_peer_id).
var _last_damage_source_peer_id: int = 0
# Korrektheits-Fix (2026-08-04) — verhindert doppelte Loot-Vergabe: ohne
# diese Sperre könnte derselbe Zombie im selben Frame von zwei Quellen
# tödlich getroffen werden (z. B. GuardPost-Beschuss UND Survivor-
# Gegenschaden), BEVOR queue_free() ihn am Frame-Ende tatsächlich entfernt
# — beide take_damage()-Aufrufe sähen dann hp<=0 und würden je einmal
# grant_zombie_loot() auslösen (doppelter Loot-Drop für einen einzigen
# Kill). Survivor.take_damage() hat dasselbe hp<=0-Muster, aber keinen
# wirtschaftlichen Seiteneffekt beim Sterben, deshalb dort unproblematisch.
var _dead: bool = false
# Zufälliger Start-Versatz (siehe TARGET_SEARCH_INTERVAL) — verhindert, dass
# alle Zombies exakt im selben Frame ihre Zielsuche auslösen (wäre sonst nur
# eine Verschiebung des 500×-Spitzenlasts um ein festes Vielfaches von
# TARGET_SEARCH_INTERVAL statt einer echten Glättung über die Zeit).
var _target_search_timer: float = 0.0
# Performance: Material-Cache statt Neuallokation pro Frame (siehe
# docs/zombies.md, "Performance: Material-Cache" — echter Fund beim
# 300-Zombie/~37-FPS-Nachtest von Punkt 2+3). _sync_state() lief schon vorher
# unnötig jeden Frame (siehe TARGET_SEARCH_INTERVAL-Fix, gleiche Ursache:
# call_local ruft es auch beim Host selbst redundant für längst korrekten
# eigenen Zustand auf) UND _update_color() erzeugte dabei jedes Mal ein neues
# StandardMaterial3D + set_surface_override_material() — bei 300 Zombies
# 300 Material-Neuallokationen/GPU-Statewechsel pro Frame, unabhängig davon,
# ob sich am HP überhaupt etwas geändert hatte.
var _material: StandardMaterial3D = null
# Performance: Netzwerk-Sync gebündelt über World statt Einzel-RPC pro
# Zombie (siehe docs/zombies.md, "Performance: Netzwerk-Sync bündeln" —
# Punkt 7 der Performance-Liste). Zombie.gd sendet selbst gar kein RPC mehr
# — World._sync_zombies_batch() liest position/hp aller Zombies einmal pro
# Frame direkt aus (kein Getter nötig, beide Felder sind schon public) und
# verschickt sie gebündelt. _last_synced_hp bleibt trotzdem hier: der Host
# selbst braucht seine eigene Farbe unabhängig vom Netzwerk-Sync, nur bei
# echter HP-Änderung neu berechnet (siehe _process()).
var _last_synced_hp: int = 0


func _ready() -> void:
	_max_hp = BRUTE_MAX_HP if is_brute else MAX_HP
	hp = _max_hp
	_last_synced_hp = hp
	_wander_speed = BRUTE_WANDER_SPEED if is_brute else WANDER_SPEED
	_chase_speed = BRUTE_CHASE_SPEED if is_brute else CHASE_SPEED
	_attack_damage = BRUTE_ATTACK_DAMAGE if is_brute else ATTACK_DAMAGE
	_home_position = position
	_target_search_timer = randf_range(0.0, TARGET_SEARCH_INTERVAL)
	_pick_new_wander_target()
	_update_color()
	if not multiplayer.is_server():
		set_process(false)


func _process(delta: float) -> void:
	# Pause (2026-08-04, nur Host, siehe docs/mechanics-review.md,
	# "Zeitskala") — jedes Entity-Script fragt das selbst ab statt eines
	# zentralen process_mode-Umbaus über den ganzen Szenenbaum.
	if get_tree().current_scene.is_paused():
		return
	_update_chase_target(delta)
	if is_instance_valid(_chase_target):
		_process_chase(delta)
	else:
		_process_wander(delta)
	# Kein RPC mehr hier — siehe _last_synced_hp oben. Läuft unconditional
	# (nicht mehr peer-abhängig verzweigt wie vorher), weil der Host seine
	# eigene Farbe so oder so braucht, unabhängig davon, ob überhaupt
	# jemand mitspielt.
	if hp != _last_synced_hp:
		_last_synced_hp = hp
		_update_color()


func _update_chase_target(delta: float) -> void:
	# GIVE_UP_RADIUS deutlich größer als DETECT_RADIUS, damit ein einmal
	# erkanntes/alarmiertes Ziel nicht sofort wieder verloren geht. Diese
	# Prüfung bleibt unthrottled (siehe TARGET_SEARCH_INTERVAL oben) — nur
	# die teure Neusuche unten wird gedrosselt.
	if is_instance_valid(_chase_target):
		if global_position.distance_to(_chase_target.global_position) > GIVE_UP_RADIUS or _is_untouchable(_chase_target):
			_chase_target = null
		else:
			return
	_target_search_timer -= delta
	if _target_search_timer > 0.0:
		return
	_target_search_timer = TARGET_SEARCH_INTERVAL
	_chase_target = _find_nearest_target()


func _find_nearest_target() -> Node3D:
	# Seit Nutzerwunsch ("können Zombies geclaimte Gebäude angreifen? wenn
	# nein, stell das um") zusätzlich zu "living" auch geclaimte Gebäude
	# (Gruppe "searchable", owner_peer_id != 0) — Building.gd implementiert
	# take_damage() bereits (siehe docs/survivor.md, "Gebäude abreißen"),
	# ein Zombie-Angriff funktioniert also ohne weitere Änderungen dort.
	# Nicht in "living" selbst eingruppiert, um die Bedeutung dieser Gruppe
	# (tatsächlich lebende Einheiten/Fahrzeuge) nicht zu verwässern.
	var candidates := get_tree().get_nodes_in_group("living")
	for building in get_tree().get_nodes_in_group("searchable"):
		if is_instance_valid(building) and building.owner_peer_id != 0:
			candidates.append(building)
	# Home-Base zerstörbar (2026-08-04, siehe docs/mechanics-review.md,
	# "Fehlende Enden/Ziele") — dieselbe Erweiterung wie oben bei geclaimten
	# Gebäuden, eigene Gruppe statt "searchable" (Home-Base ist kein
	# durchsuchbares Scavenging-Ziel).
	for base in get_tree().get_nodes_in_group("home_base"):
		if is_instance_valid(base):
			candidates.append(base)
	var nearest: Node3D = null
	var nearest_dist := DETECT_RADIUS
	for unit in candidates:
		if not is_instance_valid(unit) or _is_untouchable(unit):
			continue
		var dist := global_position.distance_to(unit.global_position)
		if dist <= nearest_dist:
			nearest = unit
			nearest_dist = dist
	return nearest


func _is_untouchable(unit: Node3D) -> bool:
	return _is_sheltered(unit) or _is_unoccupied_vehicle(unit)


func _is_sheltered(unit: Node3D) -> bool:
	# "Im Haus" (siehe Survivor.is_sheltered()) — ein durchsuchender Trupp
	# ist für Zombies weder als neues Ziel wählbar noch als laufendes Ziel
	# haltbar. Ersetzt echte Kollision/Pathfinding (die es hier bewusst
	# nicht gibt, siehe docs/survivor.md) durch eine einfache
	# Zustandsabfrage statt Geometrie.
	return unit.has_method("is_sheltered") and unit.is_sheltered()


func _is_unoccupied_vehicle(unit: Node3D) -> bool:
	# Nutzerwunsch: Zombies greifen ein Fahrzeug erst an, sobald jemand
	# drinsitzt — ein geparktes, unbesetztes Fahrzeug ist kein Ziel (siehe
	# docs/vehicle.md). Ein besetztes Fahrzeug (`is_occupied() == true`)
	# bleibt dagegen ganz normal angreifbar.
	return unit.has_method("is_occupied") and not unit.is_occupied()


func _process_chase(delta: float) -> void:
	# Steht eine Mauer/ein Tor auf der geraden Linie zum eigentlichen Ziel,
	# wird sie zum Zwischenziel — der Zombie greift sie an, bis sie kaputt
	# ist, statt einfach hindurchzulaufen (siehe docs/walls.md,
	# "Durchbrechen"). Kein Navmesh/Pathfinding nötig, nutzt dasselbe
	# Verfolgen/Angreifen-Muster wie beim Survivor-Kampf.
	var obstacle := _blocking_obstacle(global_position, _chase_target.global_position)
	var effective_target: Node3D = obstacle if obstacle != null else _chase_target
	var dist := global_position.distance_to(effective_target.global_position)
	if dist <= ATTACK_RANGE:
		_attack_timer += delta
		if _attack_timer >= ATTACK_COOLDOWN:
			_attack_timer = 0.0
			_try_attack(effective_target)
		return
	position = position.move_toward(effective_target.position, _chase_speed * delta)


func _blocking_obstacle(from: Vector3, to: Vector3) -> Node3D:
	# Mauern/Tore blockieren Zombies immer (anders als Survivor.gd, das
	# Tore für den eigenen Besitzer durchlässt — ein Zombie hat nie eine
	# passende owner_peer_id, deshalb hier kein Wall.blocks()-Aufruf nötig).
	var query := PhysicsRayQueryParameters3D.create(from, to, OBSTACLE_LAYER)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.collider if result else null


func _try_attack(target: Node3D) -> void:
	# Beidseitiger Kampf im selben Tick — kein RPC nötig, beide Seiten
	# laufen schon host-seitig. `target` ist meist `_chase_target` selbst,
	# kann aber auch eine blockierende Mauer/ein Tor sein (siehe
	# _process_chase()).
	if not is_instance_valid(target):
		return
	var damage: int = _attack_damage
	if get_tree().current_scene.is_night():
		# Nutzerwunsch: "Zombies ab 22 Uhr bis 4 Uhr morgens 20% stärker"
		# — nur der Angriffsschaden wird erhöht, nicht HP/Geschwindigkeit
		# (siehe docs/zombies.md, "Nacht-Schadensbonus"). HP absichtlich
		# unangetastet: ein dynamischer Max-HP-Sprung bei Nachtbeginn
		# würde einem schon angeschlagenen Zombie unbeabsichtigt Gratis-HP
		# zurückgeben.
		damage = int(round(damage * ZOMBIE_NIGHT_DAMAGE_MULTIPLIER))
	target.take_damage(damage)
	# Gegenseitige Verteidigung/Hilfe (siehe docs/world.md, "Gegenseitige
	# Verteidigung/Hilfe" — Punkt 20 der Gesamtliste) — alarmiert (gedrosselt)
	# alle ANDEREN Spieler, dass hier gerade jemand angegriffen wird.
	get_tree().current_scene.maybe_alert_sos(target)
	# Lärm geht vom eigentlichen Verfolgungsziel aus, nicht von der Mauer
	# davor — andere Zombies sollen weiterhin Richtung Survivor alarmiert
	# werden (der die Mauer beim eigenen Vorrücken ohnehin selbst entdeckt).
	_alert_nearby_zombies(_chase_target)
	# Nur ein Survivor persönlich wehrt sich mit Gegenschaden — Mauern/Tore
	# sind reine Bauten ohne eigenen Angriff, Fahrzeuge reiner Transport ohne
	# Waffe (siehe docs/vehicle.md, Nutzerentscheidung). has_method(
	# "is_sheltered") als "ist das ein Survivor?"-Unterscheidung — nur
	# Survivor.gd implementiert diese Methode, anders als order_move(), das
	# jetzt auch Vehicle.gd hat.
	if is_instance_valid(target) and target.has_method("is_sheltered"):
		take_damage(COUNTER_DAMAGE, target.owner_peer_id)


func _alert_nearby_zombies(target: Node3D) -> void:
	# Lärm-System (docs/zombies.md): Kampf ist laut, alarmiert andere
	# Zombies in NOISE_RADIUS, auch wenn die den Survivor selbst noch nicht
	# bemerkt haben (NOISE_RADIUS zwischen DETECT_RADIUS und GIVE_UP_RADIUS).
	# Läuft über World.zombies_near() (Spatial Grid) statt der vollen
	# "zombie"-Gruppenabfrage — siehe World.ZOMBIE_GRID_CELL_SIZE.
	for other in get_tree().current_scene.zombies_near(global_position, NOISE_RADIUS):
		if other == self or not is_instance_valid(other):
			continue
		other.alert(target)


func alert(target: Node3D) -> void:
	# Öffentliche Methode statt direktem Zugriff auf _chase_target eines
	# anderen Zombies.
	_chase_target = target


func _process_wander(delta: float) -> void:
	if position.distance_to(_wander_target) < 0.3:
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_pick_new_wander_target()
		return
	position = position.move_toward(_wander_target, _wander_speed * delta)


func _pick_new_wander_target() -> void:
	var offset := Vector3(randf_range(-WANDER_RADIUS, WANDER_RADIUS), 0, randf_range(-WANDER_RADIUS, WANDER_RADIUS))
	_wander_target = _home_position + offset
	_idle_timer = randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)


func take_damage(amount: int, source_peer_id: int = 0) -> void:
	# Kein RPC — wird ausschließlich host-seitig aufgerufen (aus
	# _try_attack() als Gegenschaden, oder von GuardPost beim Feuern).
	# source_peer_id merkt sich, wer den Schaden verursacht hat (siehe
	# _last_damage_source_peer_id) — beim Tod entscheidet das, wer den
	# Loot-Drop bekommt (siehe World.grant_zombie_loot()).
	if _dead:
		return
	if source_peer_id != 0:
		_last_damage_source_peer_id = source_peer_id
	hp = max(hp - amount, 0)
	if hp <= 0:
		_dead = true
		get_tree().current_scene.grant_zombie_loot(_last_damage_source_peer_id, is_brute)
		_die.rpc()


@rpc("authority", "call_local", "reliable")
func _die() -> void:
	queue_free()


func despawn() -> void:
	# Von World._despawn_far_zombies() aufgerufen (siehe docs/zombies.md,
	# "Zombie-Despawn") — kein echter Tod (kein Loot-Drop, kein
	# take_damage()), nur Aufräumen eines für niemanden mehr relevanten
	# Wander-Zombies. Nutzt denselben replizierten Lösch-Pfad wie ein
	# echter Tod (_die()).
	_die.rpc()


func apply_synced_state(new_position: Vector3, new_hp: int) -> void:
	# Von World._apply_zombie_batch() aufgerufen (siehe docs/zombies.md,
	# "Performance: Netzwerk-Sync bündeln") — ersetzt das frühere eigene
	# @rpc _sync_state() pro Zombie. Läuft NUR auf Remote-Clients (World
	# verschickt das gebündelte RPC mit "call_remote", der Host braucht
	# das nicht, sein Zustand ist über die direkten Feldzuweisungen längst
	# aktuell). Kein eigenes @rpc mehr hier — reine lokale Methode, vom
	# schon replizierten World-RPC aufgerufen.
	position = new_position
	# Nur neu einfärben, wenn sich der HP-Wert tatsächlich geändert hat
	# (siehe _material oben).
	if new_hp != hp:
		hp = new_hp
		_update_color()


func _update_color() -> void:
	# Grün, dunkelt mit sinkendem HP nach (unterscheidbar von Survivor, der
	# weiß-zu-rot wird). Brute bekommt einen eigenen, dunkleren
	# Grundton (siehe docs/zombies.md, "Zombie-Typen") — zusätzlich zur
	# größeren Kapsel auch farblich auf den ersten Blick unterscheidbar.
	var mesh: MeshInstance3D = get_node_or_null("Mesh")
	if mesh == null:
		return
	var ratio: float = float(hp) / float(_max_hp)
	var base_color := Color(0.18, 0.22, 0.12) if is_brute else Color(0.2, 0.5, 0.2)
	# Material einmal anlegen und danach nur noch mutieren statt jedes Mal
	# neu zu allozieren (siehe _material oben) — set_surface_override_material()
	# muss trotzdem nur einmal aufgerufen werden, ein bereits gesetztes
	# Material-Objekt zu ändern reicht danach aus.
	if _material == null:
		_material = StandardMaterial3D.new()
		mesh.set_surface_override_material(0, _material)
	_material.albedo_color = base_color.lerp(Color(0.05, 0.05, 0.05), 1.0 - ratio)
