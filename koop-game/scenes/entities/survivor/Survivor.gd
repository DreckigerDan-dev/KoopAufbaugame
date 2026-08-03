extends StaticBody3D
## Auswählbare, bewegbare Trupp-Einheit, 3D — Grundgerüst + Scavenging
## (Gebäude durchsuchen) + HP/Permadeath + Hunger + Stationieren an einem
## GuardPost. Bewegung, Suche und Schaden laufen host-autoritativ. Siehe
## docs/survivor.md, docs/scavenging.md, docs/zombies.md, docs/building.md.
## 3D-Migration (siehe docs/3d-migration.md): ersetzt das vorherige
## Node2D/ColorRect durch StaticBody3D/CapsuleMesh/CollisionShape3D,
## Vector2 durch Vector3 (Bewegung auf der X/Z-Ebene), plus eine
## Wegpunkt-Schlange statt einem einzelnen Ziel.

signal died(unit: Node3D)

## Trupp-Arten (siehe docs/survivor.md, "Trupp-Arten") — jeder Survivor ist
## flexibel zwischen beiden umschaltbar (World.gd, UnitsUI-Zeile), keine
## feste Klasse pro Rekrut. **Exklusiv, nicht additiv** (Nutzerwunsch nach
## Test: "die sollen nur abbauen können"): FIELD darf suchen/claimen/
## angreifen (order_search()/order_claim_building()/order_attack()), aber
## NICHT abbauen; BUILD darf ausschließlich abbauen (order_harvest()) und
## verliert dabei alle drei Feldtrupp-Fähigkeiten. Jeweils server-seitig
## geprüft, mit `report_status()`-Feedback statt stiller Ablehnung. Basis-
## Bewegung (order_move()/order_stop()) bleibt für beide Typen uneingeschränkt.
enum TroopType { FIELD, BUILD }

const MAX_HP := 100
const MOVE_SPEED := 4.0
const ARRIVE_THRESHOLD := 0.05
const HEAL_DELAY_AFTER_DAMAGE := 4.0
const HEAL_RADIUS := 3.0
const HEAL_RATE := 5.0
# Krankenstation (siehe docs/building.md, "Werkstatt"-Nachbarabschnitt) —
# eigene, größere Heilzone mit höherer Rate als nur an der Basis.
const MEDICAL_STATION_HEAL_RADIUS := 5.0
const MEDICAL_STATION_HEAL_RATE := HEAL_RATE * 2.0
# Erweiterte Krankenstation (Punkt 24 der Gesamtliste, siehe
# docs/building.md) — gleicher Radius, nur schnellere Heilrate.
const ADVANCED_MEDICAL_STATION_HEAL_RATE := HEAL_RATE * 3.0
const HUNGER_DECAY_RATE := 1.5
const HUNGER_LOW_THRESHOLD := 30.0
const HUNGER_SPEED_FACTOR := 0.5
const EAT_INTERVAL := 2.0
const EAT_AMOUNT := 15.0
# Müdigkeit + Moral (siehe docs/survivor.md, "Bedürfnisse: Müdigkeit +
# Moral" — Punkt 16 der Gesamtliste). Anders als Hunger (Regeneration
# schon an der bloßen Home-Base) regenerieren beide NUR in der Nähe eines
# eigenen Schlafraums (siehe Bed.gd/docs/building.md, "Betten") — ohne
# Schlafraum sinken sie dauerhaft, das ist laut Vision-Dokument
# (Infos/02 Item-Liste.md) der ganze Sinn der Betten-Mechanik. Langsamerer
# Verfall als Hunger (weniger zeitkritisch, ergänzendes statt zentrales
# Bedürfnis), REST_RATE angelehnt an MEDICAL_STATION_HEAL_RATE.
const FATIGUE_DECAY_RATE := 0.8
const FATIGUE_LOW_THRESHOLD := 30.0
const FATIGUE_SPEED_FACTOR := 0.7
const MORALE_DECAY_RATE := 0.4
const MORALE_LOW_THRESHOLD := 30.0
# Niedrige Moral schwächt den Angriff statt die Bewegung (siehe
# _effective_attack_damage()) — Müdigkeit macht langsam, Moral macht
# kampfunwilliger, zwei unterscheidbare Effekte statt eines doppelten
# Speed-Mali.
const MORALE_DAMAGE_FACTOR := 0.7
const BED_REST_RADIUS := 5.0
const REST_RATE := 10.0
const SEARCH_DURATION := 3.0
# Angriffsbefehl (siehe docs/survivor.md, "Angriffsbefehl") — gleiche Werte
# wie Zombie.ATTACK_RANGE/ATTACK_COOLDOWN, ATTACK_DAMAGE wie
# Zombie.COUNTER_DAMAGE (bewusst dieselben Zahlen wie der bestehende
# Gegenschaden, kein neues Balancing).
const ATTACK_RANGE := 1.2
const ATTACK_COOLDOWN := 1.0
const ATTACK_DAMAGE := 15
# Waffensystem, Stufe 1 (siehe docs/survivor.md, "Waffensystem") — bewusst
# nur ein einziger Fernkampf-Modus statt der vollen Vision
# (Waffenstufen/-typen/Munitionssorten, siehe Infos/02 Item-Liste.md). Ein
# ausgerüsteter Trupp greift aus RANGED_ATTACK_RANGE an (wie
# GuardPost.FIRE_RANGE) statt in Nahkampf-Distanz laufen zu müssen, mit
# etwas mehr Schaden als Nahkampf als Anreiz fürs Ausrüsten. Gleicher
# ATTACK_COOLDOWN wie Nahkampf, kein eigener Fernkampf-Cooldown nötig.
const RANGED_ATTACK_RANGE := 6.0
const RANGED_ATTACK_DAMAGE := 20
# Rüstungssystem, Stufe 1 (siehe docs/survivor.md, "Rüstungssystem") —
# zwei Slots (Brustpanzer + Helm, Nutzerwunsch) statt der vollen Vision
# (Rüstungsteile für noch mehr Körperzonen, Kombinationen mit Gasmaske/
# Rucksack etc., siehe Infos/02 Item-Liste.md). Anders als Waffen kein
# Trupp-Arten-Filter beim Ausrüsten — Rüstung ist passiver Schutz, nützt
# Feld- UND Bautrupps gleichermaßen. Beide Reduktionen wirken
# multiplikativ zusammen (siehe take_damage()), können sich also nie zu
# über 100% aufsummieren.
const ARMOR_DAMAGE_REDUCTION := 0.3
const ARMOR_SPEED_FACTOR := 0.85
# Helm: kleinere zusätzliche Schadensreduktion, aber KEIN Speed-Malus
# (nur der Brustpanzer macht langsamer, siehe _current_move_speed()) —
# passt zur Vision-Doku-Idee, dass Kopfschutz leicht bleibt.
const HELMET_DAMAGE_REDUCTION := 0.15
# Dritter Rüstungs-Slot (siehe docs/survivor.md, "Rüstungssystem" —
# Punkt 18 der Gesamtliste, "mehrere Rüstungsteile"): Beinschutz, gleiche
# Größenordnung wie der Helm, ebenfalls KEIN Speed-Malus (nur der
# Brustpanzer macht langsamer, gleiche Begründung wie beim Helm).
const LEG_ARMOR_DAMAGE_REDUCTION := 0.15
# Sekundärwaffe (siehe docs/survivor.md, "Waffensystem", "Haupt-/
# Sekundärwaffe" — Punkt 18 der Gesamtliste): rüstet eine richtige
# Nahkampfwaffe aus (Vision-Stufe-1-Tools wie Machete/Axt) statt der
# bloßen Fäuste (ATTACK_DAMAGE/ATTACK_COOLDOWN) — mehr Schaden UND
# kürzerer Cooldown als der bisherige bloße Nahkampf-Fallback, greift nur,
# solange keine funktionierende Hauptwaffe (Fernkampf) verfügbar ist.
const SECONDARY_MELEE_DAMAGE := 22
const SECONDARY_MELEE_COOLDOWN := 0.8
# Bautrupp: Abbauen (Baum ODER Autowrack, siehe docs/survivor.md,
# "Trupp-Arten") — eigene Werte statt Wiederverwendung von ATTACK_*, weil es
# thematisch eine andere Aktion ist (Holzfällen/Schrotten, kein Kampf), auch
# wenn der Code-Ablauf identisch ist (_process_harvest() spiegelt
# _process_attack()).
const HARVEST_RANGE := 1.2
const HARVEST_COOLDOWN := 1.0
const HARVEST_DAMAGE := 15
# Trage-Kapazität (siehe docs/scavenging.md, "Rückweg") — Summe über alle
# Ressourcenarten hinweg, nicht pro Art. War kurzzeitig (Punkt 9 der
# Gesamtliste) ein knappes Rucksack-Ausrüstungsstück (BASE 20 +
# BACKPACK_CARRY_BONUS 10) — Nutzerentscheidung nach kurzem Test: Rucksack
# soll KEIN Item sein, sondern fester Bestand jedes Trupps. Deshalb wieder
# eine einzelne feste Konstante, direkt auf den vorherigen "mit Rucksack"-
# Wert (30) statt der alten 20, siehe docs/survivor.md, "Rucksack".
const CARRY_CAPACITY := 30
# Physik-Ebene 2 = Mauern/Tore (siehe scenes/entities/wall/Wall.tscn,
# `collision_layer = 2`) — bewusst dupliziert in Zombie.gd statt geteilt,
# gleiches Muster wie schon bei _alert_nearby_zombies() (siehe
# docs/building.md, "Bewusst dupliziert statt geteilt").
const OBSTACLE_LAYER := 2
# Anzeigenamen für Vehicle.vehicle_type (siehe dort, VEHICLE_STATS) — bewusst
# dupliziert statt geteilt, gleiches Muster wie OBSTACLE_LAYER oben (siehe
# docs/building.md, "Bewusst dupliziert statt geteilt"), nur für die
# Einstiegs-Statusmeldung in _enter_vehicle() gebraucht.
const VEHICLE_TYPE_LABELS := {"car": "Auto", "motorcycle": "Motorrad", "truck": "LKW"}

var trupp_id: int = 0
var owner_peer_id: int = 1
var troop_type: TroopType = TroopType.FIELD
var hp: int = MAX_HP
var hunger: float = 100.0
var fatigue: float = 100.0
var morale: float = 100.0
# Getragener Loot bis zum nächsten Kontakt mit der eigenen Basis (siehe
# docs/scavenging.md, "Rückweg") — öffentlich, damit World._update_hud()
# den aktuellen Tragestatus anzeigen kann.
var carried_loot: Dictionary = {}
# Waffensystem, Stufe 1 (siehe docs/survivor.md, "Waffensystem") — einmal
# ausgerüstet, kein Ablegen in dieser Stufe (bewusste Vereinfachung).
# is_armed = Hauptwaffe (Fernkampf), secondary_weapon = zweiter,
# unabhängiger Slot (Nahkampf-Upgrade, siehe "Haupt-/Sekundärwaffe" —
# Punkt 18 der Gesamtliste).
var is_armed: bool = false
var secondary_weapon: bool = false
# Rüstungssystem, Stufe 1 (siehe docs/survivor.md, "Rüstungssystem") —
# gleiche Vereinfachung, kein Ablegen. is_wearing_armor = Brustpanzer-Slot,
# has_helmet = zweiter, has_leg_armor = dritter, alle unabhängig
# voneinander (has_leg_armor seit Punkt 18 der Gesamtliste, "mehrere
# Rüstungsteile").
var is_wearing_armor: bool = false
var has_helmet: bool = false
var has_leg_armor: bool = false

## Wegpunkt-Schlange statt einem einzelnen festen Ziel — normaler
## Bewegungsbefehl ersetzt die Schlange, Shift+Klick hängt stattdessen
## hinten an (siehe World.gd, _select_at()).
var _waypoints: Array = []  # Array[Vector3]
var _time_since_damage: float = HEAL_DELAY_AFTER_DAMAGE
var _heal_accumulator: float = 0.0
var _eat_timer: float = 0.0

# Stationierung an einem GuardPost (siehe docs/building.md, "Arbeiter
# zuweisen") — _pending_station_target ist das Ziel, an dem sich der Trupp
# bei Ankunft registriert; _stationed_at ist erst gesetzt, sobald er
# tatsächlich angekommen und registriert ist.
var _stationed_at: Node3D = null
var _pending_station_target: Node3D = null

# Durchsuchen (siehe docs/scavenging.md) — _pending_building_path ist als
# NodePath statt Node3D-Referenz gespeichert, weil die Gebäude statisch in
# World.tscn verankert sind (kein MultiplayerSpawner) und derselbe Pfad auf
# jedem Peer auf denselben Node zeigt.
var _searching: bool = false
var _search_timer: float = 0.0
var _pending_building_path: NodePath = NodePath()

# "Im Haus" (siehe is_sheltered()) — bleibt bewusst über das Ende der Suche
# hinaus true, solange der Trupp am Gebäude stehen bleibt. Erst ein neuer
# Befehl (Bewegen/Suchen/Stationieren/Stopp, alle über _cancel_search())
# setzt es zurück.
var _sheltered: bool = false

# Fahrzeug einsteigen (siehe docs/vehicle.md) — _pending_vehicle_path als
# NodePath aus demselben Grund wie _pending_building_path: Fahrzeuge sind
# wie Gebäude statisch in World.tscn verankert (kein MultiplayerSpawner).
var _pending_vehicle_path: NodePath = NodePath()

# Gebäude claimen (siehe docs/zones.md) — _pending_claim_path aus demselben
# Grund wie _pending_building_path (NodePath statt Node3D-Referenz).
var _pending_claim_path: NodePath = NodePath()

# Angriffsbefehl (siehe docs/survivor.md, "Angriffsbefehl") — direkte
# Node3D-Referenz statt NodePath, weil Zombies über MultiplayerSpawner
# laufen und is_instance_valid() hier ohnehin jeden Frame geprüft werden
# muss (Ziel kann jederzeit sterben). Läuft NICHT über die Wegpunkt-
# Schlange wie order_move/order_search/etc. — _process() verzweigt
# stattdessen direkt in _process_attack(), solange _attack_target gültig
# ist (siehe Zombie._process_chase() für dasselbe Muster, nur passiv).
var _attack_target: Node3D = null
var _attack_timer: float = 0.0

# Bautrupp: Abbauen (Baum ODER Autowrack, siehe docs/survivor.md,
# "Trupp-Arten") — gleiches Muster wie _attack_target/_attack_timer, eigener
# State statt Wiederverwendung, weil beide gleichzeitig unabhängig
# voneinander null sein müssen (ein Trupp kann nicht gleichzeitig kämpfen
# und abbauen).
var _harvest_target: Node3D = null
var _harvest_timer: float = 0.0


func _ready() -> void:
	# Nur der Host simuliert — Clients bekommen den Zustand ausschließlich
	# über _sync_state() repliziert.
	if not multiplayer.is_server():
		set_process(false)


func _process(delta: float) -> void:
	_time_since_damage += delta
	if is_instance_valid(_attack_target):
		_process_attack(delta)
	elif is_instance_valid(_harvest_target):
		_process_harvest(delta)
	else:
		_attack_target = null
		_harvest_target = null
		# Markier-System (siehe docs/survivor.md, "Trupp-Arten", "Markier-
		# System") — ein untätiger Bautrupp sucht sich selbstständig den
		# nächsten markierten Baum, egal wo auf der Karte (bewusst ohne
		# Zonen-Beschränkung). Greift erst NACHDEM oben feststeht, dass
		# gerade kein anderer Befehl läuft (is_idle() prüft u. a.
		# _waypoints/_searching/_stationed_at).
		if troop_type == TroopType.BUILD and is_idle():
			_try_auto_assign_harvest()
		if is_instance_valid(_harvest_target):
			_process_harvest(delta)
		else:
			_handle_movement(delta)
	_handle_hunger(delta)
	_handle_fatigue(delta)
	_handle_morale(delta)
	_handle_healing(delta)
	_handle_eating(delta)
	_handle_resting(delta)
	_handle_carried_loot()
	_sync_state.rpc(position, hp, hunger, fatigue, morale, carried_loot, is_armed, is_wearing_armor, has_helmet, secondary_weapon, has_leg_armor, troop_type)


func _current_move_speed() -> float:
	var speed := MOVE_SPEED
	if hunger <= HUNGER_LOW_THRESHOLD:
		speed *= HUNGER_SPEED_FACTOR
	if fatigue <= FATIGUE_LOW_THRESHOLD:
		speed *= FATIGUE_SPEED_FACTOR
	if is_wearing_armor:
		# Rüstungssystem, Stufe 1 (siehe docs/survivor.md,
		# "Rüstungssystem") — kombiniert sich mit dem Hunger-/Müdigkeits-
		# Malus, falls mehrere gleichzeitig zutreffen.
		speed *= ARMOR_SPEED_FACTOR
	return speed


func _handle_movement(delta: float) -> void:
	if _searching:
		_process_search(delta)
		return
	if _waypoints.is_empty():
		return
	var target: Vector3 = _waypoints[0]
	var next_position := position.move_toward(target, _current_move_speed() * delta)
	if _is_path_blocked(next_position):
		# Mauer (oder fremdes Tor) direkt im Weg für DIESEN Schritt — der
		# Trupp bleibt einfach stehen, kein Ausweichen/Pathfinding (siehe
		# docs/walls.md). Kurzes Segment (aktuelle Position → nächster
		# Schritt, nicht bis zum Wegpunkt), damit der Trupp erst beim
		# tatsächlichen Anstoßen an die Mauer stehen bleibt, nicht schon von
		# weitem.
		return
	position = next_position
	if position.distance_to(target) < ARRIVE_THRESHOLD:
		_waypoints.pop_front()
		# Stationierung/Durchsuchen greifen erst am LETZTEN Wegpunkt —
		# order_station()/order_search() setzen dafür immer nur genau einen,
		# nie eine Schlange.
		if not _waypoints.is_empty():
			return
		if is_instance_valid(_pending_station_target):
			_stationed_at = _pending_station_target
			_stationed_at.register_worker(self)
			_pending_station_target = null
		elif not _pending_building_path.is_empty():
			_searching = true
			_sheltered = true
			_search_timer = SEARCH_DURATION
		elif not _pending_vehicle_path.is_empty():
			_enter_vehicle()
		elif not _pending_claim_path.is_empty():
			_claim_building()


func _is_path_blocked(next_position: Vector3) -> bool:
	# Eigene Mauern blockieren auch die eigenen Trupps (siehe docs/walls.md
	# — genau deshalb gibt es das Tor). Tore lassen nur Trupps mit
	# passender owner_peer_id durch (`Wall.blocks()`); Zombie.gd hat keinen
	# solchen Ausnahme-Check, weil Zombies nie einen passenden
	# owner_peer_id haben.
	var query := PhysicsRayQueryParameters3D.create(global_position, next_position, OBSTACLE_LAYER)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result:
		return false
	var obstacle: Node3D = result.collider
	if obstacle.has_method("blocks") and not obstacle.blocks(owner_peer_id):
		return false
	return true


func _process_attack(delta: float) -> void:
	# Gegenstück zu Zombie._process_chase(), aber trupp-initiiert statt
	# passiv — siehe docs/survivor.md, "Angriffsbefehl". Kein Mauer-
	# Durchbrechen (nur Zombies brechen Mauern durch, siehe docs/walls.md);
	# steht eine Mauer im Weg, bleibt der Trupp einfach stehen, wie bei
	# normaler Bewegung auch.
	# Waffensystem, Stufe 1 (siehe docs/survivor.md, "Waffensystem") — ein
	# bewaffneter Trupp mit Munition greift aus RANGED_ATTACK_RANGE an statt
	# in Nahkampf-Distanz laufen zu müssen; ist die Munition alle, fällt er
	# automatisch auf Nahkampf zurück (bleibt nützlich, kein Totalausfall).
	var ammo_base: Node3D = null
	var use_ranged := false
	if is_armed:
		ammo_base = _find_home_base()
		if ammo_base != null and ammo_base.resources.get("ammo", 0) > 0:
			use_ranged = true
	# Sekundärwaffe (siehe docs/survivor.md, "Waffensystem", "Haupt-/
	# Sekundärwaffe" — Punkt 18 der Gesamtliste): greift nur, solange kein
	# Fernkampf möglich ist (use_ranged false) — eine ausgerüstete
	# Nahkampfwaffe verbessert Schaden UND Cooldown gegenüber dem bloßen
	# Fäuste-Fallback, ändert aber nicht die Reichweite (bleibt Nahkampf).
	var melee_damage := SECONDARY_MELEE_DAMAGE if secondary_weapon else ATTACK_DAMAGE
	var melee_cooldown := SECONDARY_MELEE_COOLDOWN if secondary_weapon else ATTACK_COOLDOWN
	var attack_range := RANGED_ATTACK_RANGE if use_ranged else ATTACK_RANGE
	var cooldown := ATTACK_COOLDOWN if use_ranged else melee_cooldown
	var dist := global_position.distance_to(_attack_target.global_position)
	if dist <= attack_range:
		_attack_timer += delta
		if _attack_timer >= cooldown:
			_attack_timer = 0.0
			# owner_peer_id als Schaden-Quelle mitgeben (siehe
			# Zombie.take_damage()) — der eigentliche Weg, wie ein Spieler
			# einen Zombie gezielt tötet, muss auch für den Zombie-Loot-
			# Drop als "Verursacher" zählen (siehe docs/zombies.md,
			# "Zombie-Loot-Drop"), nicht nur passiver Gegenschaden.
			if use_ranged:
				ammo_base.add_resources.rpc({"ammo": -1})
				_attack_target.take_damage(_effective_attack_damage(RANGED_ATTACK_DAMAGE), owner_peer_id)
				# Nutzer-Feedback: ohne jede sichtbare Reaktion war nicht
				# erkennbar, ob ein Fernkampf-Schuss überhaupt stattfand (der
				# Trupp bleibt einfach 6m entfernt stehen, sonst identisch zum
				# Nichtstun) — kurzer Leuchtstreif als eindeutiges Signal,
				# repliziert an alle Peers (nur der Host führt
				# _process_attack() überhaupt aus, siehe _ready()).
				_play_shot_effect.rpc(_attack_target.global_position)
			else:
				_attack_target.take_damage(_effective_attack_damage(melee_damage), owner_peer_id)
		return
	var next_position := position.move_toward(_attack_target.position, _current_move_speed() * delta)
	if _is_path_blocked(next_position):
		return
	position = next_position


@rpc("authority", "call_local", "reliable")
func _play_shot_effect(target_position: Vector3) -> void:
	# Rein optisch, kein Gameplay-Effekt — siehe _process_attack(). Läuft auf
	# jedem Peer (call_local Pflicht, sonst sieht der Host den eigenen Schuss
	# nie), fügt einen kurzen Leuchtstreif als Kind der World-Szene ein
	# (nicht als eigenes Kind, damit er unabhängig von Trupp-Bewegung/-Tod
	# an Ort und Stelle bleibt und sich selbst wieder entfernt).
	var from := global_position
	var to := target_position
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, from.distance_to(to))
	tracer.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.3)
	tracer.set_surface_override_material(0, mat)
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = (from + to) / 2.0
	tracer.look_at(to, Vector3.UP)
	get_tree().create_timer(0.12).timeout.connect(tracer.queue_free)


func _process_harvest(delta: float) -> void:
	# Spiegelt _process_attack() (siehe dort) — läuft hin, schlägt im
	# Cooldown-Takt drauf, bis das Ziel (Baum ODER Autowrack, beide über
	# take_damage()/hp/YIELD ununterscheidbar) fällt (`hp <= 0`).
	# Ressourcen-Gutschrift erst NACH dem tödlichen Treffer, in derselben
	# Funktion statt im Ziel selbst — weder Tree.gd noch CarWreck.gd kennen
	# (anders als eine Home-Base) einen Besitzer, dem sie etwas gutschreiben
	# könnten, siehe docs/survivor.md, "Trupp-Arten".
	var dist := global_position.distance_to(_harvest_target.global_position)
	if dist <= HARVEST_RANGE:
		_harvest_timer += delta
		if _harvest_timer >= HARVEST_COOLDOWN:
			_harvest_timer = 0.0
			_harvest_target.take_damage(HARVEST_DAMAGE)
			if _harvest_target.hp <= 0:
				var base := _find_home_base()
				if base != null:
					base.add_resources.rpc(_harvest_target.YIELD)
				_harvest_target = null
		return
	var next_position := position.move_toward(_harvest_target.position, _current_move_speed() * delta)
	if _is_path_blocked(next_position):
		return
	position = next_position


func _try_auto_assign_harvest() -> void:
	# Markier-System (siehe docs/survivor.md, "Trupp-Arten") — sucht unter
	# allen markierten "harvestable"-Zielen (Baum ODER Autowrack, siehe
	# docs/survivor.md) das nächste, das nicht schon von einem ANDEREN
	# Bautrupp bearbeitet wird, und weist es sich selbst zu. Bewusst
	# kartenweit (kein Radius/Zonen-Filter) — Nutzerwunsch: Bautrupps
	# können potenziell überall Sachen abbauen. Gleiches Scan-Muster wie
	# Zombie._find_nearest_target(), nur für Ressourcen statt lebende Ziele.
	var nearest: Node3D = null
	var nearest_dist: float = INF
	for harvestable in get_tree().get_nodes_in_group("harvestable"):
		if not is_instance_valid(harvestable) or not harvestable.is_marked or _is_already_assigned(harvestable):
			continue
		var dist := global_position.distance_to(harvestable.global_position)
		if dist < nearest_dist:
			nearest = harvestable
			nearest_dist = dist
	if nearest != null:
		_harvest_target = nearest


func _is_already_assigned(target: Node3D) -> bool:
	# Verhindert, dass mehrere freie Bautrupps im selben Frame dasselbe
	# markierte Ziel wählen — fragt jeden anderen lebenden Trupp über
	# is_harvesting() statt direkt auf dessen _harvest_target zuzugreifen
	# (gleiches Duck-Typing-Prinzip wie has_method("is_sheltered") in
	# Zombie.gd).
	for other in get_tree().get_nodes_in_group("living"):
		if other != self and is_instance_valid(other) and other.has_method("is_harvesting") and other.is_harvesting(target):
			return true
	return false


func is_harvesting(target: Node3D) -> bool:
	return _harvest_target == target


func _process_search(delta: float) -> void:
	_search_timer -= delta
	if _search_timer <= 0.0:
		_finish_search()


func _finish_search() -> void:
	_searching = false
	var building := get_node_or_null(_pending_building_path)
	_pending_building_path = NodePath()
	if building == null:
		return
	if building.has_bandit_loot:
		# Banditen-Restloot (siehe docs/scavenging.md, "Banditen-Restloot") —
		# einzige Ausnahme vom sonst endgültigen is_looted-Gate unten, ein
		# schon geplündertes Gebäude ist NUR durchsuchbar, solange dieses
		# Flag gesetzt ist. Kein mark_looted() nötig (ist es schon), keine
		# erneute Rekrutierung (die passierte, falls überhaupt, beim ersten
		# Durchsuchen).
		_pick_up_loot(building.bandit_loot)
		building.clear_bandit_loot.rpc()
		_return_to_base()
		return
	if building.is_looted:
		return
	building.mark_looted.rpc()
	_pick_up_loot(building.loot)
	if building.has_survivor:
		# Rekrutierung (siehe docs/recruitment.md) — get_tree().current_scene
		# ist zuverlässig die World-Node, weil Survivor nur existiert, während
		# World.tscn die aktuell geladene Szene ist.
		get_tree().current_scene.spawn_recruit(owner_peer_id, position)
	_return_to_base()


func _pick_up_loot(loot: Dictionary) -> void:
	# Trage-Kapazität (siehe docs/scavenging.md, "Rückweg") — Loot über die
	# Grenze hinaus geht verloren, das Gebäude gilt trotzdem als komplett
	# geplündert (kein zweites Mal durchsuchbar, siehe is_looted oben).
	# Greedy statt proportional auf die Ressourcenarten verteilt: einfacher,
	# bei den kleinen Loot-Mengen dieses Spiels kein spürbarer Unterschied.
	var carried_total := 0
	for amount in carried_loot.values():
		carried_total += amount
	for key in loot:
		var remaining_capacity: int = CARRY_CAPACITY - carried_total
		if remaining_capacity <= 0:
			break
		var amount: int = min(loot[key], remaining_capacity)
		carried_loot[key] = carried_loot.get(key, 0) + amount
		carried_total += amount


func _return_to_base() -> void:
	# Automatischer Rückweg nach jeder abgeschlossenen Suche (siehe
	# docs/scavenging.md, "Rückweg") — kann wie jeder andere Wegpunkt
	# jederzeit durch einen neuen Befehl unterbrochen werden (z. B. direkt
	# das nächste Gebäude durchsuchen, statt erst zur Basis zu laufen).
	# _sheltered bewusst zurückgesetzt: der Rückweg ist genauso gefährlich
	# wie der Hinweg, kein Sicherheitsbonus fürs "eigentlich schon fertig"
	# (siehe ARCHITECTURE.md, "Risiko"). Läuft zum NÄHEREN von Home-Base/
	# eigenem Außenposten (siehe _find_nearest_drop_off_point(),
	# docs/building.md, "Außenposten") statt immer bis zur Basis.
	_sheltered = false
	var target := _find_nearest_drop_off_point()
	if target == null:
		return
	# Zufälliger Streuungs-Offset (statt exakt target.position) — sonst würden
	# mehrere gleichzeitig zurücklaufende Trupps exakt übereinander ankommen
	# und ineinander clippen (kein Kollisionssystem, siehe docs/survivor.md,
	# "Bekannte Grenzen" — dasselbe Problem wie bei Gruppenbefehlen, dort
	# löst World._formation_offset() es; hier reicht Zufallsstreuung, weil
	# es kein koordinierter Gruppenbefehl ist).
	var offset := Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	_waypoints = [target.position + offset]


func _handle_carried_loot() -> void:
	# Läuft jeden Frame wie _handle_healing()/_handle_eating() (gleicher
	# Näheradius zur eigenen Basis) statt einmalig bei Ankunft — dadurch
	# wird der Loot auch abgeliefert, wenn der Rückweg unterbrochen und der
	# Trupp später aus anderem Grund an der Basis (oder einem eigenen
	# Außenposten) vorbeikommt.
	if carried_loot.is_empty():
		return
	var target := _find_nearest_drop_off_point()
	if target == null or global_position.distance_to(target.global_position) > HEAL_RADIUS:
		return
	# Home-Base UND Outpost implementieren beide add_resources(), aber nur
	# HomeBase.add_resources() ist selbst ein @rpc (siehe HomeBase.gd) — nur
	# darauf ist die ".rpc()"-Aufrufsyntax gültig. Outpost.add_resources()
	# ist bewusst eine einfache Methode, die intern schon
	# base.add_resources.rpc() aufruft (siehe Outpost.gd) — ein normaler
	# Aufruf reicht hier, ein zweites äußeres .rpc() wäre nur verwirrend
	# doppelt und würde ohne @rpc-Annotation dort ohnehin einen Laufzeitfehler
	# auslösen.
	if target.is_in_group("home_base"):
		target.add_resources.rpc(carried_loot)
	else:
		target.add_resources(carried_loot)
	carried_loot.clear()


func _find_nearest_drop_off_point() -> Node3D:
	# Abgabepunkt für Loot/Rückweg-Ziel: die eigene Home-Base ODER ein
	# eigener Außenposten, je nachdem was näher liegt (siehe
	# docs/building.md, "Außenposten" — "Zwischenlagern" aus der Vision).
	var nearest: Node3D = _find_home_base()
	var nearest_dist: float = global_position.distance_to(nearest.global_position) if nearest != null else INF
	for outpost in get_tree().get_nodes_in_group("outpost"):
		if not is_instance_valid(outpost) or outpost.owner_peer_id != owner_peer_id:
			continue
		var dist := global_position.distance_to(outpost.global_position)
		if dist < nearest_dist:
			nearest = outpost
			nearest_dist = dist
	return nearest


func _enter_vehicle() -> void:
	# Letzter Wegpunkt erreicht, siehe _handle_movement(). Läuft schon
	# host-seitig (siehe docs/vehicle.md).
	var vehicle := get_node_or_null(_pending_vehicle_path)
	_pending_vehicle_path = NodePath()
	if vehicle == null or vehicle.is_full():
		# Inzwischen (von wem auch immer) schon voll besetzt — zu spät, kein
		# Feedback, gleiches Muster wie ein schon geplündertes Gebäude.
		return
	if not vehicle.enter(self, owner_peer_id):
		return
	_board.rpc(true)
	# Nutzer-Feedback (siehe docs/vehicle.md, "Differenzierte Fahrzeugtypen")
	# — sonst ist Motorrad/LKW/Auto nur an der Farbe/Größe im 3D-Blick
	# erkennbar, hier steht es explizit.
	var label: String = VEHICLE_TYPE_LABELS.get(vehicle.vehicle_type, "Fahrzeug")
	get_tree().current_scene.report_status(owner_peer_id, "%s bestiegen." % label)


func _claim_building() -> void:
	# Letzter Wegpunkt erreicht, siehe _handle_movement(). Läuft schon
	# host-seitig — World.claim_building() prüft Zone + Ressourcen erneut
	# (siehe docs/zones.md), falls sich der Zustand seit dem Loslaufen
	# geändert hat (z. B. jemand anderes war schneller).
	var building := get_node_or_null(_pending_claim_path)
	_pending_claim_path = NodePath()
	if building == null:
		return
	get_tree().current_scene.claim_building(owner_peer_id, building)


@rpc("authority", "call_local", "reliable")
func _board(boarded: bool) -> void:
	# Repliziert an alle Peers: unsichtbar + aus "selectable"/"living" raus,
	# solange man drinsitzt — Zombies können den Trupp dann nicht mehr als
	# Ziel finden (er ist ja im Auto, nicht auf offener Straße), und er ist
	# nicht mehr per Klick auswählbar (das Fahrzeug übernimmt seine Rolle).
	# add_to_group()/remove_from_group() zur Laufzeit sind unproblematisch
	# (anders als groups=[...] im .tscn-Header, siehe docs/3d-migration.md
	# — das betrifft nur die Erstzuweisung beim Laden der Szene).
	visible = not boarded
	if boarded:
		remove_from_group("selectable")
		remove_from_group("living")
	else:
		add_to_group("selectable")
		add_to_group("living")


func exit_vehicle(vehicle_position: Vector3) -> void:
	# Host-seitig von Vehicle.request_exit() aufgerufen.
	position = vehicle_position + Vector3(1.0, 0, 0)
	_board.rpc(false)


func vehicle_destroyed() -> void:
	# Host-seitig von Vehicle.take_damage() aufgerufen, wenn hp <= 0
	# während der Trupp noch drinsitzt — Permadeath wie im Konzept
	# (ARCHITECTURE.md), kein Rauswurf in letzter Sekunde.
	_die.rpc()


func is_idle() -> bool:
	return _waypoints.is_empty() and _stationed_at == null and not _searching and not is_instance_valid(_attack_target) and not is_instance_valid(_harvest_target)


func is_sheltered() -> bool:
	# "Im Haus" — sobald die aktive Suche beginnt, gilt der Trupp als in
	# Deckung, Zombies können ihn weder entdecken noch weiter
	# verfolgen/angreifen (siehe
	# Zombie._find_nearest_target()/_update_chase_target()). Bleibt bewusst
	# auch NACH Suchende bestehen, solange der Trupp dort stehen bleibt —
	# endet erst mit dem nächsten Befehl (siehe _cancel_search()). Auf dem
	# Hinweg zum Gebäude (noch nicht angekommen) ist der Trupp dagegen
	# weiterhin ungeschützt.
	return _sheltered


func order_station(post: Node3D) -> void:
	# Aufgerufen direkt von GuardPost.request_worker() (schon host-seitig) —
	# kein eigenes RPC nötig, anders als order_move/order_search, die vom
	# Commander-Code in World.gd (jedem Peer) aus aufgerufen werden. Ersetzt
	# immer die ganze Schlange, kein Anhängen.
	_unstation()
	_cancel_search()
	_waypoints = [post.position]
	_pending_station_target = post


func _unstation() -> void:
	if is_instance_valid(_stationed_at):
		_stationed_at.unregister_worker(self)
	_stationed_at = null
	_pending_station_target = null


func _cancel_search() -> void:
	# Ein neuer Befehl (Bewegen/Stationieren/Stopp) bricht eine laufende oder
	# noch nicht begonnene Suche UND einen noch nicht begonnenen
	# Fahrzeug-Einstieg/Gebäude-Claim/Angriff ab, statt das im Hintergrund
	# weiterlaufen zu lassen — und beendet damit auch den "im Haus"-Schutz
	# (siehe is_sheltered()), selbst wenn die Suche längst fertig war.
	_searching = false
	_sheltered = false
	_pending_building_path = NodePath()
	_pending_vehicle_path = NodePath()
	_pending_claim_path = NodePath()
	_attack_target = null
	_harvest_target = null


func _handle_hunger(delta: float) -> void:
	hunger = max(hunger - HUNGER_DECAY_RATE * delta, 0.0)


func _handle_fatigue(delta: float) -> void:
	fatigue = max(fatigue - FATIGUE_DECAY_RATE * delta, 0.0)


func _handle_morale(delta: float) -> void:
	morale = max(morale - MORALE_DECAY_RATE * delta, 0.0)


func _effective_attack_damage(base_damage: int) -> int:
	# Niedrige Moral schwächt den Angriff (siehe MORALE_DAMAGE_FACTOR oben)
	# — genutzt von _process_attack() für Nah- UND Fernkampf, nicht für
	# passiven Gegenschaden (der läuft in Zombie.gd, eigene Konstanten,
	# bewusst unberührt, siehe docs/zombies.md).
	if morale <= MORALE_LOW_THRESHOLD:
		return int(round(base_damage * MORALE_DAMAGE_FACTOR))
	return base_damage


func _find_home_base() -> Node3D:
	# Eine Home-Base pro Peer, nicht geteilt (siehe docs/base.md).
	for base in get_tree().get_nodes_in_group("home_base"):
		if base.owner_peer_id == owner_peer_id:
			return base
	return null


func _handle_healing(delta: float) -> void:
	# Passive Regeneration "an der eigenen Basis" (oder Krankenstation,
	# siehe unten) — kostet 1 Medizin pro geheiltem HP, siehe
	# docs/survivor.md, "Heilung". Medizin kommt immer aus dem Basis-Pool,
	# egal ob an der Basis selbst oder an einer Krankenstation geheilt wird
	# (kein eigenes Lager pro Gebäude, siehe docs/base.md).
	if hp >= MAX_HP or _time_since_damage < HEAL_DELAY_AFTER_DAMAGE:
		return
	var base := _find_home_base()
	if base == null:
		return
	var heal_rate := HEAL_RATE
	var in_range := global_position.distance_to(base.global_position) <= HEAL_RADIUS
	if not in_range:
		var station := _find_nearby_medical_station()
		if station == null:
			return
		in_range = true
		# Erweiterte Krankenstation (siehe docs/building.md, Punkt 24 der
		# Gesamtliste) heilt schneller — einziger funktionaler Unterschied
		# zur normalen Krankenstation.
		heal_rate = ADVANCED_MEDICAL_STATION_HEAL_RATE if station.is_advanced else MEDICAL_STATION_HEAL_RATE
	if base.resources.get("medicine", 0) <= 0:
		return
	_heal_accumulator += heal_rate * delta
	while _heal_accumulator >= 1.0 and hp < MAX_HP and base.resources.get("medicine", 0) > 0:
		hp += 1
		_heal_accumulator -= 1.0
		base.add_resources.rpc({"medicine": -1})


func _find_nearby_medical_station() -> Node3D:
	for station in get_tree().get_nodes_in_group("medical_station"):
		if station.owner_peer_id == owner_peer_id and global_position.distance_to(station.global_position) <= MEDICAL_STATION_HEAL_RADIUS:
			return station
	return null


func _handle_eating(delta: float) -> void:
	# Analog zur Heilung — siehe docs/survivor.md, "Hunger".
	var base := _find_home_base()
	if base == null or global_position.distance_to(base.global_position) > HEAL_RADIUS:
		return
	if hunger >= 100.0 or base.resources.get("food", 0) <= 0:
		return
	_eat_timer += delta
	if _eat_timer >= EAT_INTERVAL:
		_eat_timer -= EAT_INTERVAL
		base.add_resources.rpc({"food": -1})
		hunger = min(hunger + EAT_AMOUNT, 100.0)


func _find_nearby_bed() -> Node3D:
	for bed in get_tree().get_nodes_in_group("bed"):
		if bed.owner_peer_id == owner_peer_id and global_position.distance_to(bed.global_position) <= BED_REST_RADIUS:
			return bed
	return null


func _handle_resting(delta: float) -> void:
	# Müdigkeit + Moral regenerieren NUR in der Nähe eines eigenen
	# Schlafraums (siehe FATIGUE_DECAY_RATE-Kommentar oben) — anders als
	# Hunger/Heilung gibt es hier bewusst KEINE Home-Base-Grundrate, das ist
	# der ganze Sinn der Betten-Mechanik aus der Vision. Kein Ressourcen-
	# verbrauch (Vision nennt für die Regeneration selbst keine Kosten,
	# nur die Baukosten des Schlafraums, siehe docs/building.md, "Betten").
	if fatigue >= 100.0 and morale >= 100.0:
		return
	if _find_nearby_bed() == null:
		return
	fatigue = min(fatigue + REST_RATE * delta, 100.0)
	morale = min(morale + REST_RATE * delta, 100.0)


@rpc("any_peer", "call_local", "reliable")
func order_move(target: Vector3, requesting_peer_id: int, queue: bool) -> void:
	# Läuft nur host-seitig, requesting_peer_id muss zum Eigentümer passen
	# (vereinfachte Vertrauensannahme, siehe docs/survivor.md, "Bekannte
	# Grenzen"). `queue` (Shift+Klick) hängt hinten an die bestehende
	# Wegpunkt-Schlange an, statt sie zu ersetzen.
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	if not queue:
		_unstation()
		_cancel_search()
		_waypoints.clear()
	_waypoints.append(target)


@rpc("any_peer", "call_local", "reliable")
func order_search(target: Vector3, building_path: NodePath, requesting_peer_id: int) -> void:
	# building_path als NodePath, weil Gebäude statisch in World.tscn
	# verankert sind (siehe _pending_building_path oben). Ersetzt immer die
	# ganze Schlange — Durchsuchen ist ein einzelnes, unmittelbares Ziel.
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	if troop_type != TroopType.FIELD:
		# Trupp-Arten sind exklusiv, nicht additiv (siehe docs/survivor.md,
		# "Trupp-Arten") — Bautrupps dürfen keine Häuser durchsuchen,
		# Nutzerwunsch nach Test: "die sollen nur abbauen können".
		get_tree().current_scene.report_status(requesting_peer_id, "Nur Feldtrupps können Gebäude durchsuchen.")
		return
	_unstation()
	_searching = false
	_sheltered = false
	_pending_vehicle_path = NodePath()
	_waypoints = [target]
	_pending_building_path = building_path


@rpc("any_peer", "call_local", "reliable")
func order_enter_vehicle(target: Vector3, vehicle_path: NodePath, requesting_peer_id: int) -> void:
	# Analog zu order_search() — Fahrzeuge sind wie Gebäude statisch in
	# World.tscn verankert (kein wiederverwendbarer Szenentyp, siehe
	# docs/vehicle.md), derselbe NodePath-Grund wie bei
	# _pending_building_path funktioniert deshalb genauso zuverlässig.
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	_unstation()
	_cancel_search()
	_waypoints = [target]
	_pending_vehicle_path = vehicle_path


@rpc("any_peer", "call_local", "reliable")
func order_claim_building(target: Vector3, building_path: NodePath, requesting_peer_id: int) -> void:
	# Analog zu order_search()/order_enter_vehicle() — dasselbe
	# NodePath-Argument wie order_search() (siehe docs/zones.md), weil es
	# dasselbe Gebäude referenziert, nur eben schon geplündert.
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	if troop_type != TroopType.FIELD:
		# Gleiche Trupp-Arten-Exklusivität wie order_search(), siehe dort.
		get_tree().current_scene.report_status(requesting_peer_id, "Nur Feldtrupps können Gebäude claimen.")
		return
	_unstation()
	_cancel_search()
	_waypoints = [target]
	_pending_claim_path = building_path


@rpc("any_peer", "call_local", "reliable")
func order_attack(target_path: NodePath, requesting_peer_id: int) -> void:
	# Trupp-initiierter Angriff (siehe docs/survivor.md, "Angriffsbefehl") —
	# Ziel ist ein Zombie ODER ein Zombie-Nest (siehe docs/zombies.md),
	# beide über take_damage() erreichbar. Ersetzt immer Wegpunkt-Schlange
	# und jeden anderen laufenden Befehl, wie jeder andere order_*.
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	if troop_type != TroopType.FIELD:
		# Gleiche Trupp-Arten-Exklusivität wie order_search(), siehe dort —
		# Bautrupps kämpfen nicht proaktiv (passiver Gegenschaden bei einem
		# Zombie-Angriff bleibt davon unberührt, das ist kein Befehl).
		get_tree().current_scene.report_status(requesting_peer_id, "Nur Feldtrupps können angreifen.")
		return
	var target := get_node_or_null(target_path)
	if target == null:
		return
	_unstation()
	_cancel_search()
	_waypoints.clear()
	_attack_target = target


@rpc("any_peer", "call_local", "reliable")
func order_equip_weapon(requesting_peer_id: int) -> void:
	# Waffensystem, Stufe 1 (siehe docs/survivor.md, "Waffensystem") —
	# verbraucht 1× "weapon" aus der eigenen Home-Base, kein Ablegen in
	# dieser Stufe (bewusste Vereinfachung).
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	if troop_type != TroopType.FIELD:
		# Gleiche Trupp-Arten-Exklusivität wie order_attack() — Waffen sind
		# Feldtrupp-Werkzeug, kein Bautrupp-Feature.
		get_tree().current_scene.report_status(requesting_peer_id, "Nur Feldtrupps können sich bewaffnen.")
		return
	if is_armed:
		return
	var base := _find_home_base()
	if base == null or base.resources.get("weapon", 0) <= 0:
		get_tree().current_scene.report_status(requesting_peer_id, "Keine Waffe verfügbar.")
		return
	base.add_resources.rpc({"weapon": -1})
	is_armed = true


@rpc("any_peer", "call_local", "reliable")
func order_equip_armor(requesting_peer_id: int) -> void:
	# Rüstungssystem, Stufe 1 (siehe docs/survivor.md, "Rüstungssystem") —
	# kein troop_type-Filter (anders als order_equip_weapon()): Rüstung ist
	# passiver Schutz, nützt Feld- UND Bautrupps gleichermaßen. Verbraucht
	# 1× "armor" aus der eigenen Home-Base, kein Ablegen in dieser Stufe.
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	if is_wearing_armor:
		return
	var base := _find_home_base()
	if base == null or base.resources.get("armor", 0) <= 0:
		get_tree().current_scene.report_status(requesting_peer_id, "Keine Rüstung verfügbar.")
		return
	base.add_resources.rpc({"armor": -1})
	is_wearing_armor = true


@rpc("any_peer", "call_local", "reliable")
func order_equip_helmet(requesting_peer_id: int) -> void:
	# Zweiter Rüstungs-Slot (siehe docs/survivor.md, "Rüstungssystem") —
	# unabhängig vom Brustpanzer-Slot, gleiches Muster. Verbraucht 1×
	# "helmet" aus der eigenen Home-Base, kein Ablegen in dieser Stufe.
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	if has_helmet:
		return
	var base := _find_home_base()
	if base == null or base.resources.get("helmet", 0) <= 0:
		get_tree().current_scene.report_status(requesting_peer_id, "Kein Helm verfügbar.")
		return
	base.add_resources.rpc({"helmet": -1})
	has_helmet = true


@rpc("any_peer", "call_local", "reliable")
func order_equip_secondary_weapon(requesting_peer_id: int) -> void:
	# Waffensystem, Stufe 2 (siehe docs/survivor.md, "Waffensystem",
	# "Haupt-/Sekundärwaffe" — Punkt 18 der Gesamtliste): zweiter,
	# unabhängiger Waffenslot neben `is_armed` (Hauptwaffe/Fernkampf).
	# Gleicher Feldtrupp-Filter wie die Hauptwaffe. Verbraucht 1×
	# "melee_weapon" statt "weapon" — eigene Ressource, damit beide Slots
	# unabhängig ausgerüstet werden können.
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	if troop_type != TroopType.FIELD:
		get_tree().current_scene.report_status(requesting_peer_id, "Nur Feldtrupps können sich bewaffnen.")
		return
	if secondary_weapon:
		return
	var base := _find_home_base()
	if base == null or base.resources.get("melee_weapon", 0) <= 0:
		get_tree().current_scene.report_status(requesting_peer_id, "Keine Nahkampfwaffe verfügbar.")
		return
	base.add_resources.rpc({"melee_weapon": -1})
	secondary_weapon = true


@rpc("any_peer", "call_local", "reliable")
func order_equip_leg_armor(requesting_peer_id: int) -> void:
	# Rüstungssystem, dritter Slot (siehe docs/survivor.md,
	# "Rüstungssystem" — Punkt 18 der Gesamtliste): gleiche Struktur wie
	# Brustpanzer/Helm, kein troop_type-Filter (passiver Schutz). Verbraucht
	# 1× "leg_armor".
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	if has_leg_armor:
		return
	var base := _find_home_base()
	if base == null or base.resources.get("leg_armor", 0) <= 0:
		get_tree().current_scene.report_status(requesting_peer_id, "Kein Beinschutz verfügbar.")
		return
	base.add_resources.rpc({"leg_armor": -1})
	has_leg_armor = true


@rpc("any_peer", "call_local", "reliable")
func order_demolish_building(target: Vector3, building_path: NodePath, requesting_peer_id: int) -> void:
	# Bautrupp-Aktion (siehe docs/survivor.md, "Gebäude abreißen") — nur
	# geplünderte, noch niemandem gehörende Gebäude sind abreißbar (schützt
	# Zonen-Anker/Start-Basen vor versehentlichem Abriss). `target` (Vector3)
	# wird nur für dieselbe Signatur wie order_search()/order_claim_building()
	# mitgeführt (siehe docs/zones.md, "Dynamischer RPC-Aufruf") —
	# World._select_at() ruft alle drei generisch über denselben
	# rpc_id()-Aufruf auf, hier aber ungenutzt: läuft danach über denselben
	# _harvest_target-Ablauf wie order_harvest() (_process_harvest()), nicht
	# über die Wegpunkt-Schlange.
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	if troop_type != TroopType.BUILD:
		get_tree().current_scene.report_status(requesting_peer_id, "Nur Bautrupps können Gebäude abreißen.")
		return
	var building := get_node_or_null(building_path)
	if building == null or not building.is_looted or building.owner_peer_id != 0:
		return
	_unstation()
	_cancel_search()
	_waypoints.clear()
	_harvest_target = building


@rpc("any_peer", "call_local", "reliable")
func order_harvest(target_path: NodePath, requesting_peer_id: int) -> void:
	# Bautrupp-Aktion (siehe docs/survivor.md, "Trupp-Arten") — Ziel ist ein
	# Baum ODER ein Autowrack (gemeinsame Gruppe "harvestable", beide über
	# take_damage()/hp/YIELD/is_marked ununterscheidbar). Nur
	# TroopType.BUILD darf abbauen, sonst Feedback statt stiller Ablehnung
	# (gleiches Muster wie GuardPost.request_worker() ohne freien Trupp).
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	if troop_type != TroopType.BUILD:
		get_tree().current_scene.report_status(requesting_peer_id, "Nur Bautrupps können das abbauen.")
		return
	var target := get_node_or_null(target_path)
	if target == null:
		return
	_unstation()
	_cancel_search()
	_waypoints.clear()
	_harvest_target = target


@rpc("any_peer", "call_local", "reliable")
func set_troop_type(new_type: TroopType, requesting_peer_id: int) -> void:
	# Umschaltbar per UnitsUI-Button (World._refresh_units_ui()), siehe
	# docs/survivor.md, "Trupp-Arten" — jederzeit möglich, auch mitten in
	# einer laufenden Aktion (wechselt z. B. ein kämpfender Trupp auf BUILD,
	# bleibt der Angriff einfach unbeeinflusst weiterlaufen, bis ein neuer
	# Befehl kommt).
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	troop_type = new_type


@rpc("any_peer", "call_local", "reliable")
func order_stop(requesting_peer_id: int) -> void:
	# Reiner Rechtsklick (kein Ziehen, siehe World.gd) — hält die Einheit
	# sofort an, bricht Stationierung und eine laufende/vorgemerkte Suche ab.
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	_unstation()
	_cancel_search()
	_waypoints.clear()


func take_damage(amount: int) -> void:
	# Kein RPC — wird ausschließlich host-seitig aufgerufen (von Zombie beim
	# Nahkampf, siehe docs/zombies.md).
	# Rüstungssystem, Stufe 1 (siehe docs/survivor.md, "Rüstungssystem") —
	# Brustpanzer/Helm/Beinschutz wirken multiplikativ zusammen (nie über
	# 100% Reduktion aufsummierbar). int(round(...)) statt := round(...),
	# siehe GDScript-Variant-Falle.
	var multiplier := 1.0
	if is_wearing_armor:
		multiplier *= 1.0 - ARMOR_DAMAGE_REDUCTION
	if has_helmet:
		multiplier *= 1.0 - HELMET_DAMAGE_REDUCTION
	if has_leg_armor:
		multiplier *= 1.0 - LEG_ARMOR_DAMAGE_REDUCTION
	var actual_amount: int = int(round(amount * multiplier))
	hp = max(hp - actual_amount, 0)
	_time_since_damage = 0.0
	if hp <= 0:
		_die.rpc()


@rpc("authority", "call_local", "reliable")
func _die() -> void:
	# Permadeath wie im Konzept (ARCHITECTURE.md) — kein Wiederbeleben.
	_unstation()
	died.emit(self)
	queue_free()


@rpc("authority", "call_local", "unreliable_ordered")
func _sync_state(new_position: Vector3, new_hp: int, new_hunger: float, new_fatigue: float, new_morale: float, new_carried_loot: Dictionary, new_is_armed: bool, new_is_wearing_armor: bool, new_has_helmet: bool, new_secondary_weapon: bool, new_has_leg_armor: bool, new_troop_type: TroopType) -> void:
	# Kombiniert Position/HP/Hunger/Müdigkeit/Moral/Loot/Waffen-/Rüstungs-
	# Status in einem RPC (unreliable_ordered: gelegentlicher Verlust
	# unproblematisch, jeder Frame schickt ohnehin den kompletten aktuellen
	# Stand neu, kein Delta — ein verlorenes Paket korrigiert sich spätestens
	# im nächsten Frame von selbst, Reihenfolge muss trotzdem stimmen).
	# call_local Pflicht, sonst sieht der Host die eigene Farbänderung nie.
	# new_is_armed/new_is_wearing_armor/new_has_helmet/new_secondary_weapon/
	# new_has_leg_armor (siehe docs/survivor.md, "Waffensystem"/
	# "Rüstungssystem") sind der einzige Weg, wie andere Peers/die eigene UI
	# den aktuellen Status sehen. new_troop_type ebenso (Bugfix 2026-08-03,
	# Nutzer-Report "Spieler 2 kann Units nicht in Bautrupp umwandeln") —
	# set_troop_type() änderte troop_type bisher NUR auf der Host-Instanz,
	# ohne Broadcast an andere Peers; beim Host selbst fiel das nie auf,
	# weil seine eigene UI dieselbe Node-Instanz liest, die der Server
	# direkt mutiert.
	position = new_position
	hp = new_hp
	hunger = new_hunger
	fatigue = new_fatigue
	morale = new_morale
	carried_loot = new_carried_loot
	is_armed = new_is_armed
	is_wearing_armor = new_is_wearing_armor
	has_helmet = new_has_helmet
	secondary_weapon = new_secondary_weapon
	has_leg_armor = new_has_leg_armor
	troop_type = new_troop_type
	_update_color()


func _update_color() -> void:
	var mesh: MeshInstance3D = get_node_or_null("Mesh")
	if mesh == null:
		return
	var ratio: float = float(hp) / float(MAX_HP)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _unit_base_color().lerp(Color.RED, 1.0 - ratio)
	mesh.set_surface_override_material(0, mat)


func _unit_base_color() -> Color:
	# Jede Einheit bekommt eine eigene, aus trupp_id abgeleitete Farbe
	# (Nutzerwunsch 2026-08-03: "unterschiedliche Farben pro Unit", explizit
	# PRO EINHEIT statt pro Spieler gewählt) — rein deterministisch aus der
	# ohnehin schon netzwerksynchronen trupp_id berechnet, kein
	# zusätzlicher State/RPC nötig, auf allen Peers identisch. Schritt um
	# den goldenen Schnitt sorgt für gut verteilte, unterscheidbare
	# Farbtöne auch bei aufeinanderfolgenden IDs.
	var hue := fmod(trupp_id * 0.6180339887, 1.0)
	# Trupp-Art (Feld/Bau) ist ohnehin schon als Text in der Einheiten-Liste
	# und im Detailfenster sichtbar (siehe World.gd) — Farbe hier ersetzt
	# NICHT mehr die Trupp-Art-Unterscheidung, sondern macht zusätzlich
	# Sättigung/Helligkeit als schwaches Zweit-Signal (Bautrupp gedeckter,
	# bewaffneter Feldtrupp kräftiger), Haupt-Signal bleibt der Farbton
	# selbst zur Einheiten-Unterscheidung.
	var saturation := 0.55 if troop_type == TroopType.BUILD else 0.75
	var value := 0.75 if troop_type == TroopType.BUILD else 0.9
	if troop_type == TroopType.FIELD and is_armed:
		saturation = 0.85
		value = 1.0
	return Color.from_hsv(hue, saturation, value)
