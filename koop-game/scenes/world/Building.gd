extends StaticBody3D
## Durchsuchbares Gebäude (Scavenging-Ziel), 3D — Loot ist endlich, einmal
## durchsucht bleibt es leer. Siehe docs/scavenging.md. Seit dem
## Zonen-System (siehe docs/zones.md) zusätzlich claimbar, sobald
## geplündert — erweitert dann die Bauzone des claimenden Spielers.
## Seit dem Kartenumbau (siehe docs/world.md, "Kartengröße") KEIN fester
## `.tscn`-Kind-Node mehr, sondern über `building_spawner`/
## `World._create_building()` dynamisch aus `BUILDING_TEMPLATES` erzeugt
## (gleiches Muster wie `Tree.gd`/`Zombie.gd`) — Größe/Loot/Farbe kommen
## jetzt aus Spawn-Daten statt individuell pro Node im `.tscn` hinterlegt
## zu sein.

# Abreißen (siehe docs/survivor.md, "Gebäude abreißen") — nur geplünderte,
# noch niemandem gehörende Gebäude sind abreißbar (schützt Zonen-Anker/
# Start-Basen vor versehentlichem Abriss). take_damage()/hp/YIELD folgen
# demselben Interface wie Tree.gd/CarWreck.gd/StonePile.gd/BrickPile.gd,
# damit Survivor._process_harvest() (über order_demolish_building()
# gestartet) es generisch mitbenutzen kann. Bewusst NICHT pro Vorlage
# unterschiedlich — schon vor dem Kartenumbau hatte jedes Gebäude
# dieselbe MAX_HP/YIELD, unabhängig von seiner Größe.
const MAX_HP := 100
const YIELD := {"stone": 20, "brick": 10}

var building_id: int = 0
var loot: Dictionary = {}
var has_survivor: bool = false
# Grundfarbe der Fassade (siehe World._create_building()) — pro Vorlage
# leicht unterschiedlich, rein kosmetisch. Als Feld gehalten (nicht nur
# einmalig beim Erzeugen verwendet), damit ein aus einem Spielstand
# wiederhergestelltes, noch unlooted/ungeclaimtes Gebäude dieselbe Farbe
# zurückbekommt statt grau zu wirken.
var default_color: Color = Color(0.45, 0.38, 0.3)
# Echtes Asset statt Platzhalter-Box (2026-08-04, siehe docs/building.md,
# "Wohnhaus") — leer = Platzhalter-Box wie bisher. Als Feld gehalten (nicht
# nur einmalig in World._create_building() verwendet), aus demselben Grund
# wie default_color: Catch-up/Spielstand-Laden müssen denselben Wert erneut
# an World._create_building() zurückgeben können, siehe World._spawn_for_peer()/
# _collect_save_data().
var model_path: String = ""
# Prozedural erzeugtes Modell statt echtem Asset ODER Platzhalter-Box
# (2026-08-04, Nutzerwunsch: "für die masse die häuser generieren, die
# spezial POI base krankenhaus etc mach ich") — leer = kein prozedurales
# Modell (Platzhalter-Box oder model_path greift stattdessen). Enthält
# "width"/"depth"/"wall_height"/"roof_height"/"wall_color"/"roof_color",
# siehe World._random_house_proc_params()/_build_procedural_house().
# Als Feld gehalten, gleicher Grund wie model_path/default_color oben.
var proc_params: Dictionary = {}
# Kartenansicht-Legende (siehe World.LOOT_CATEGORY_BY_RESOURCE/MapView.gd,
# LOOT_CATEGORY_COLORS) — "food"/"medicine"/"equipment"/"books", aus der
# BUILDING_TYPES-Vorlage abgeleitet, einmalig beim Spawn gesetzt.
var loot_category: String = "food"
# Zonen-Zentrum, zu dem dieses Gebäude gehört (siehe docs/zones.md,
# "Start-Basis wählen") — request_choose_start_base() braucht das, um die
# Home-Base von der ZONEN-Mitte weg zu platzieren statt vom Weltursprung
# (bricht sonst, sobald mehrere Stadt-Zonen über die Karte verteilt sind
# statt alle Gebäude nah am Ursprung, siehe docs/world.md).
var zone_center: Vector3 = Vector3.ZERO

var is_looted: bool = false
var owner_peer_id: int = 0  # 0 = nicht geclaimt
var hp: int = MAX_HP
# Schutzsuchende (2026-08-04, Rekrutierungs-Erweiterung, siehe
# docs/mechanics-review.md) — reine Wiederverwendung des bestehenden
# has_survivor-Mechanismus (Survivor._finish_search() ruft World.
# spawn_recruit() bei Erfolg auf), nur eigens periodisch in der Wildnis
# gespawnt statt fest in eine Stadt-Zone eingebaut. is_refugee
# unterscheidet den Kanal, damit World.gd den 2-pro-Spieler-Deckel NUR
# hier anwendet (das ursprüngliche feste Rekrutierungs-Gebäude bleibt
# ungedeckelt).
var is_refugee: bool = false

# Bau-Markier-Modus (Punkt 28 der Gesamtliste, siehe docs/building.md,
# "Baustellen") — Ziel-Ausbaustufe festlegen, ohne dass der Ausbau sofort
# passiert. World.request_start_construction() setzt die Felder unten,
# _process() (host-only wie GuardPost/Survivor) zählt den Baufortschritt
# hoch und meldet Fertigstellung an World.finish_construction().
const CONSTRUCTION_WORK_PER_TROOP := 1.0
const CONSTRUCTION_SYNC_INTERVAL := 0.5

var has_open_construction: bool = false
# BuildType-Wert als int gehalten statt typisiert (siehe World.BuildType) —
# Building.gd kennt World.gd bewusst nicht als Typ-Abhängigkeit, nur als
# Laufzeit-Vergleichswert.
var construction_target_type: int = 0
var construction_progress: float = 0.0
var construction_required: float = 0.0
var construction_worker_count: int = 0
var _construction_workers: Array = []
var _construction_sync_timer: float = 0.0
# Banditen-Restloot (Vision-Ideenbacklog, Punkt 23 der Gesamtliste,
# `Infos/01 Architektur.md`: "gelegentlich hinterlassen Banditen-Camps
# kleinen Restloot in bereits geplünderten Gebäuden — Grund für
# gelegentliches Zurückkehren, ohne vollen Loot-Respawn"). Komplett
# unabhängig vom ursprünglichen `loot` (der bleibt unverändert, aber
# irrelevant, sobald is_looted true ist) — World._spawn_bandit_restock()
# würfelt periodisch EIN bereits geplündertes, unbesetztes Gebäude aus und
# befüllt diese beiden Felder neu.
var has_bandit_loot: bool = false
var bandit_loot: Dictionary = {}


func _ready() -> void:
	# Erst seit dem Bau-Markier-Modus überhaupt nötig — vorher war Building.gd
	# komplett passiv, alle Mutationen liefen über von außen (World.gd/
	# Survivor.gd) aufgerufene RPCs. Gleiches host-only-_process()-Muster wie
	# GuardPost/Survivor.
	if not multiplayer.is_server():
		set_process(false)


func _process(delta: float) -> void:
	# Pause (siehe Zombie.gd für dieselbe Begründung/docs/mechanics-review.md).
	if get_tree().current_scene.is_paused():
		return
	if not has_open_construction:
		return
	construction_progress += _construction_workers.size() * CONSTRUCTION_WORK_PER_TROOP * delta
	_construction_sync_timer += delta
	if _construction_sync_timer >= CONSTRUCTION_SYNC_INTERVAL:
		_construction_sync_timer = 0.0
		_sync_construction_progress.rpc(construction_progress)
	if construction_progress >= construction_required:
		# Building.gd kennt seine World-Spawner nicht selbst (siehe
		# docs/building.md, "Bewusst dupliziert statt geteilt" für dasselbe
		# Cross-Node-Prinzip) — World.finish_construction() macht den
		# eigentlichen Umbau (take_damage()/Spawn der Zielstruktur).
		get_tree().current_scene.finish_construction(self)


func start_construction(target_type: int, required_work: float) -> void:
	has_open_construction = true
	construction_target_type = target_type
	construction_progress = 0.0
	construction_required = required_work
	construction_worker_count = 0
	_construction_workers.clear()
	_construction_sync_timer = 0.0
	_sync_construction_start.rpc(target_type, required_work)
	_update_visual()


func cancel_construction() -> void:
	has_open_construction = false
	construction_target_type = 0
	construction_progress = 0.0
	construction_required = 0.0
	construction_worker_count = 0
	_construction_workers.clear()
	_sync_construction_cancel.rpc()
	_update_visual()


func register_worker(trupp: Node3D) -> void:
	if trupp in _construction_workers:
		return
	_construction_workers.append(trupp)
	_sync_construction_worker_count.rpc(_construction_workers.size())


func unregister_worker(trupp: Node3D) -> void:
	_construction_workers.erase(trupp)
	_sync_construction_worker_count.rpc(_construction_workers.size())


func get_construction_workers() -> Array:
	# Öffentlicher Zugriff für World.finish_construction()/
	# request_cancel_construction() — die müssen beim Fertigstellen/
	# Stornieren alle zugewiesenen Trupps freigeben, sollen aber nicht
	# direkt das private _construction_workers-Array anfassen.
	return _construction_workers


@rpc("any_peer", "call_local", "reliable")
func request_recall_worker(requesting_peer_id: int) -> void:
	# Gegenstück zu GuardPost.request_recall_worker() (siehe dort) — zieht
	# einen zugewiesenen Bautrupp wieder ab, macht ihn dadurch wieder frei
	# bewegbar (order_stop() ruft schon _unstation() -> unregister_worker()).
	if not multiplayer.is_server() or requesting_peer_id != owner_peer_id:
		return
	if _construction_workers.is_empty():
		return
	var trupp: Node3D = _construction_workers[0]
	trupp.order_stop(requesting_peer_id)


@rpc("authority", "call_local", "reliable")
func _sync_construction_start(target_type: int, required_work: float) -> void:
	has_open_construction = true
	construction_target_type = target_type
	construction_progress = 0.0
	construction_required = required_work
	construction_worker_count = 0
	_update_visual()


@rpc("authority", "call_local", "reliable")
func _sync_construction_progress(progress: float) -> void:
	construction_progress = progress


@rpc("authority", "call_local", "reliable")
func _sync_construction_worker_count(count: int) -> void:
	construction_worker_count = count


@rpc("authority", "call_local", "reliable")
func _sync_construction_cancel() -> void:
	has_open_construction = false
	construction_target_type = 0
	construction_progress = 0.0
	construction_required = 0.0
	construction_worker_count = 0
	_update_visual()


@rpc("authority", "call_local", "reliable")
func mark_looted() -> void:
	# authority, weil nur der Host (der die Suche simuliert) das auslösen
	# darf; call_local, damit es auch beim Host selbst direkt greift.
	if is_looted:
		return
	is_looted = true
	_update_visual()


@rpc("authority", "call_local", "reliable")
func grant_bandit_loot(new_bandit_loot: Dictionary) -> void:
	# Von World._spawn_bandit_restock() aufgerufen (host-seitig, siehe dort)
	# — macht ein bereits geplündertes, unbesetztes Gebäude EINMALIG wieder
	# durchsuchbar (Survivor._finish_search() prüft has_bandit_loot als
	# Ausnahme vom sonst endgültigen is_looted-Gate). Parameter bewusst
	# NICHT `loot` genannt — würde das gleichnamige Member-Feld oben
	# (ursprünglicher, einmaliger Erst-Loot) verschatten.
	has_bandit_loot = true
	bandit_loot = new_bandit_loot
	_update_visual()


@rpc("authority", "call_local", "reliable")
func clear_bandit_loot() -> void:
	# Von Survivor._finish_search() aufgerufen, nachdem der Restloot
	# eingesammelt wurde — Gebäude fällt danach zurück auf den normalen
	# "geplündert, unbesetzt"-Zustand (claim-/abreißbar wie zuvor).
	has_bandit_loot = false
	bandit_loot = {}
	_update_visual()


func set_claimed_owner(peer_id: int) -> void:
	# Von World.claim_building() aufgerufen (schon host-seitig, siehe
	# docs/zones.md) — kapselt das Sync-RPC, damit World.gd nicht direkt
	# eine "_"-Methode eines fremden Nodes aufrufen muss.
	owner_peer_id = peer_id
	_sync_owner.rpc(peer_id)


@rpc("authority", "call_local", "reliable")
func _sync_owner(new_owner_peer_id: int) -> void:
	owner_peer_id = new_owner_peer_id
	_update_visual()


func take_damage(amount: int) -> void:
	# Kein RPC — ausschließlich host-seitig aufgerufen (von
	# Survivor._process_harvest(), siehe docs/survivor.md). Gleiches Muster
	# wie Wall.take_damage()/Tree.take_damage().
	var new_hp: int = max(hp - amount, 0)
	_sync_hp.rpc(new_hp)
	if new_hp <= 0:
		_demolish.rpc()


@rpc("authority", "call_local", "reliable")
func _sync_hp(new_hp: int) -> void:
	hp = new_hp
	_update_visual()


@rpc("authority", "call_local", "reliable")
func _demolish() -> void:
	queue_free()


func _update_visual() -> void:
	var mat := StandardMaterial3D.new()
	if has_open_construction:
		# Offener Bauauftrag (siehe "Bau-Markier-Modus" oben) — amberfarben,
		# geht dem "geclaimt"-Blau vor, weil ein Bauauftrag immer auch ein
		# geclaimtes Gebäude voraussetzt.
		mat.albedo_color = Color(0.9, 0.6, 0.15)
	elif owner_peer_id != 0:
		# Geclaimt — bläulicher Ton, deutlich unterscheidbar vom neutralen
		# Grau eines nur geplünderten, noch niemandem gehörenden Gebäudes.
		mat.albedo_color = Color(0.3, 0.5, 0.75)
	elif has_bandit_loot:
		# Banditen-Restloot verfügbar — goldener Ton, gleiche Farbsprache wie
		# ein markierter Baum/Autowrack (siehe Tree.gd/CarWreck.gd,
		# "Markier-System"), damit auf einen Blick klar ist: hier lohnt sich
		# nochmal ein Besuch.
		mat.albedo_color = Color(0.85, 0.7, 0.15)
	elif is_looted:
		# Dunkelt beim Abreißen zusätzlich nach (gleiches Prinzip wie
		# Tree/CarWreck/StonePile/BrickPile/ZombieNest) — bleibt bei vollem
		# hp beim bisherigen Grau, geht Richtung Schwarz.
		var ratio: float = float(hp) / float(MAX_HP)
		mat.albedo_color = Color(0.25, 0.25, 0.25).lerp(Color(0.05, 0.05, 0.05), 1.0 - ratio)
	else:
		# Weder geclaimt noch geplündert — Standard-Fassadenfarbe der
		# Vorlage bleibt bestehen (schon in World._create_building() als
		# surface_material_override gesetzt), hier nichts zu tun.
		return
	# "Model" (echtes GLB-Asset, siehe World._create_building()) hat Vorrang
	# vor der versteckten Platzhalter-"Mesh"-Box — gleiches Fallback-Prinzip
	# wie HomeBase.gd, bewusst dupliziert statt geteilt (siehe docs/building.md,
	# "Bewusst dupliziert statt geteilt").
	var model := get_node_or_null("Model")
	if model != null:
		for mesh_instance in _find_mesh_instances(model):
			mesh_instance.set_surface_override_material(0, mat)
		return
	var mesh: MeshInstance3D = get_node_or_null("Mesh")
	if mesh != null:
		mesh.set_surface_override_material(0, mat)


func _find_mesh_instances(node: Node) -> Array:
	# Rekursiv, siehe HomeBase.gd (dieselbe Begründung, bewusst dupliziert
	# statt geteilt).
	var result: Array = []
	if node == null:
		return result
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result
