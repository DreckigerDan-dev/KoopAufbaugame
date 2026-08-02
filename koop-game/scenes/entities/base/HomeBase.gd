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
# "Rucksack").
const START_RESOURCES := {"food": 30, "wood": 20, "metal": 10, "stone": 20, "brick": 10, "medicine": 15, "ammo": 20, "weapon": 1, "armor": 1, "helmet": 1, "melee_weapon": 1, "leg_armor": 1}
# Lagerkapazität (siehe docs/building.md, "Lager") — EIN gemeinsamer
# Deckel für alle Ressourcenarten (kein separates Limit pro Art,
# einfacher zu verstehen/anzuzeigen). Gilt schon ohne jedes Lager,
# großzügig genug für den frühen Spielverlauf, bevor sich ein eigenes
# Lager überhaupt lohnt. 2026-08-03 zurückgebaut auf den ursprünglichen
# Wert (war testhalber auf 300 angehoben, siehe START_RESOURCES oben).
const BASE_STORAGE_CAPACITY := 150

var owner_peer_id: int = 1
var resources: Dictionary = START_RESOURCES.duplicate()
var storage_capacity: int = BASE_STORAGE_CAPACITY
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
