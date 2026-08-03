extends StaticBody3D
## Sichtbarer Startpunkt pro Spieler + eigenes Ressourcen-Datenmodell.
## Siehe docs/base.md. 3D-Migration (siehe docs/3d-migration.md): ersetzt
## Node2D/ColorRect durch StaticBody3D/BoxMesh, sonst unverändert.

signal resources_changed(new_resources: Dictionary)

# Echte Balance-Werte (2026-08-03 zurückgebaut — waren seit 2026-08-01
# testhalber auf pauschal 150/Art gesetzt, siehe persistentes Memory
# `koopgame_temp_test_resources`, jetzt auf Nutzerwunsch "die reccourcen
# weniger zum starten" zurückgesetzt). Begründung dieser Werte
# (Rohstoff-Aufteilung, Waffen-/Rüstungs-Startbestand) siehe docs/base.md,
# "Vier Baurohstoffe". Kein "book_*" im Startbestand — Forschungsbücher
# sind normalerweise NUR seltener Zombie-Loot (siehe docs/zombies.md,
# "Zombie-Loot-Drop"), nicht von Anfang an verfügbar. Kein "backpack"
# (Nutzerentscheidung: Rucksack ist kein Item, siehe docs/survivor.md,
# "Rucksack"). Baurohstoffe/Überlebensgüter 2026-08-04 nochmal angehoben
# (Nutzerwunsch: "mehr start resourcen das man seine base gleich bischen
# ausbauen kann", siehe docs/mechanics-review.md, "Ressourcen-Wirtschaft")
# — reicht jetzt z. B. für eine Zonen-Erweiterung (15 Stein) PLUS einen
# Wachposten (30 Holz) direkt zu Spielbeginn. Ausrüstungs-Startbestand
# (weapon/armor/helmet/melee_weapon/leg_armor) bewusst bei 1 belassen —
# das sind Einzel-Slots, kein Grund die zu erhöhen.
const START_RESOURCES := {"food": 60, "wood": 50, "metal": 25, "stone": 40, "brick": 25, "medicine": 25, "ammo": 30, "weapon": 1, "armor": 1, "helmet": 1, "melee_weapon": 1, "leg_armor": 1}
# Lagerkapazität (siehe docs/building.md, "Lager") — EIN gemeinsamer
# Deckel für alle Ressourcenarten (kein separates Limit pro Art,
# einfacher zu verstehen/anzuzeigen). Gilt schon ohne jedes Lager,
# großzügig genug für den frühen Spielverlauf, bevor sich ein eigenes
# Lager überhaupt lohnt. 2026-08-03 zurückgebaut auf den ursprünglichen
# Wert (war testhalber auf 300 angehoben, siehe START_RESOURCES oben).
const BASE_STORAGE_CAPACITY := 150

# Zerstörbarkeit (2026-08-04, Punkt 6 des Mechaniken-Berichts, siehe
# docs/mechanics-review.md, "Fehlende Enden/Ziele") — Home-Base war vorher
# komplett unzerstörbar. Deutlich zäher als jedes andere Gebäude
# (Nutzerwunsch: "sehr zäh"), damit Zerstörung ein seltenes, dramatisches
# Ereignis bleibt statt eines beiläufigen Nebeneffekts eines schlechten
# Verteidigungsabends.
const MAX_HP := 500

var owner_peer_id: int = 1
var resources: Dictionary = START_RESOURCES.duplicate()
var storage_capacity: int = BASE_STORAGE_CAPACITY
var hp: int = MAX_HP
# Verhindert doppelte Zerstörungs-Verarbeitung, falls take_damage() nach
# hp<=0 nochmal aufgerufen wird, bevor die Node tatsächlich entfernt ist —
# gleiches Muster wie Zombie._dead (siehe docs/zombies.md, Korrektheits-Fix
# 2026-08-04).
var _destroyed: bool = false
# Forschungsbücher/Tech-Freischaltungen (siehe docs/building.md,
# "Forschungsbücher" — Punkt 13 der Gesamtliste). recipe_id (siehe
# World.CRAFTING_RECIPES) -> true, sobald ein Buch dafür gelesen wurde.
# Dauerhaft, kein Vergessen — "die Spieler-Kolonie behält das Wissen"
# (Infos/02 Item-Liste.md). Kein Catch-up für spät beitretende Peers
# (gleiche, schon bestehende Vereinfachung wie bei resources/
# storage_capacity, siehe docs/base.md, "Bekannte Grenzen").
var unlocked_recipes: Dictionary = {}


@rpc("authority", "call_local", "reliable")
func add_resources(delta: Dictionary) -> void:
	# Nur der Host darf aufrufen (er simuliert alles, was Ressourcen
	# verändert), repliziert per .rpc() an alle Peers. Kein
	# Datenschutz-Problem: jede Home-Base bleibt ein eigener, unabhängiger
	# Node (siehe docs/scavenging.md, "Ressourcen-Update"). Zuwachs wird an
	# storage_capacity gedeckelt (siehe docs/building.md, "Lager") — Verlust
	# (negatives Delta, z. B. Baukosten) bleibt immer uneingeschränkt
	# möglich, auch wenn ein Wert theoretisch schon über dem Deckel liegt.
	for key in delta:
		var new_value: int = resources.get(key, 0) + delta[key]
		if delta[key] > 0:
			new_value = min(new_value, storage_capacity)
		resources[key] = max(new_value, 0)
	resources_changed.emit(resources)


@rpc("authority", "call_local", "reliable")
func add_storage_capacity(amount: int) -> void:
	# Aufgerufen von Storage.gd bei Erstellung (siehe docs/building.md,
	# "Lager") — erhöht den gemeinsamen Deckel dauerhaft, kein eigenes
	# Zurücknehmen (Lager haben wie Krankenstation/Werkstatt kein HP/keine
	# Zerstörbarkeit).
	storage_capacity += amount


@rpc("authority", "call_local", "reliable")
func unlock_recipe(recipe_id: String) -> void:
	# Aufgerufen von World.request_research() (schon host-seitig geprüft,
	# siehe docs/building.md, "Forschungsbücher") — dauerhaft, kein eigenes
	# Signal nötig (CraftingUI liest unlocked_recipes im ohnehin
	# bestehenden gedrosselten UI-Refresh-Takt, kein Push-Update nötig).
	unlocked_recipes[recipe_id] = true


func take_damage(amount: int) -> void:
	# Kein eigenes RPC — wird ausschließlich host-seitig aufgerufen (von
	# Zombie._try_attack(), siehe docs/zombies.md), gleiches Muster wie
	# Building.take_damage()/Wall.take_damage(). Zombies erreichen die
	# Home-Base über dieselbe Ziel-Suche wie geclaimte Gebäude (siehe
	# Zombie._find_nearest_target(), Gruppe "home_base").
	if _destroyed:
		return
	var new_hp: int = max(hp - amount, 0)
	_sync_hp.rpc(new_hp)
	if new_hp <= 0:
		_destroyed = true
		# Cross-Node-Aufruf, gleiches Muster wie report_status()/
		# spawn_recruit() — World.gd macht den eigentlichen Umbau (Ruine
		# spawnen, "verlorenen" Spieler-Zustand auslösen, siehe
		# docs/mechanics-review.md, "Fehlende Enden/Ziele").
		get_tree().current_scene.home_base_destroyed(self)


@rpc("authority", "call_local", "reliable")
func _demolish() -> void:
	# Gleiches Muster wie Building._demolish()/Wall._demolish() — von
	# World.home_base_destroyed() aufgerufen, NACHDEM die Ruine gespawnt
	# wurde.
	queue_free()


@rpc("authority", "call_local", "reliable")
func _sync_hp(new_hp: int) -> void:
	hp = new_hp
	_update_visual()


func _update_visual() -> void:
	# "Model" (echtes GLB-Asset, siehe HomeBase.tscn) hat Vorrang vor der
	# versteckten Platzhalter-"Mesh"-Box — gleiches Fallback-Prinzip wie
	# Wall.gd, bewusst dupliziert statt geteilt (siehe docs/building.md,
	# "Bewusst dupliziert statt geteilt").
	var ratio: float = float(hp) / float(MAX_HP)
	if ratio >= 1.0:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1).lerp(Color(0.5, 0.05, 0.05), 1.0 - ratio)
	var model := get_node_or_null("Model")
	if model != null:
		for mesh in _find_mesh_instances(model):
			mesh.set_surface_override_material(0, mat)
		return
	var mesh: MeshInstance3D = get_node_or_null("Mesh")
	if mesh != null:
		mesh.set_surface_override_material(0, mat)


func _find_mesh_instances(node: Node) -> Array:
	# Rekursiv, siehe Wall.gd/GuardPost.gd (dieselbe Begründung, bewusst
	# dupliziert statt geteilt).
	var result: Array = []
	if node == null:
		return result
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result
