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
# Zonen-Zentrum, zu dem dieses Gebäude gehört (siehe docs/zones.md,
# "Start-Basis wählen") — request_choose_start_base() braucht das, um die
# Home-Base von der ZONEN-Mitte weg zu platzieren statt vom Weltursprung
# (bricht sonst, sobald mehrere Stadt-Zonen über die Karte verteilt sind
# statt alle Gebäude nah am Ursprung, siehe docs/world.md).
var zone_center: Vector3 = Vector3.ZERO

var is_looted: bool = false
var owner_peer_id: int = 0  # 0 = nicht geclaimt
var hp: int = MAX_HP


@rpc("authority", "call_local", "reliable")
func mark_looted() -> void:
	# authority, weil nur der Host (der die Suche simuliert) das auslösen
	# darf; call_local, damit es auch beim Host selbst direkt greift.
	if is_looted:
		return
	is_looted = true
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
	var mesh: MeshInstance3D = get_node_or_null("Mesh")
	if mesh == null:
		return
	var mat := StandardMaterial3D.new()
	if owner_peer_id != 0:
		# Geclaimt — bläulicher Ton, deutlich unterscheidbar vom neutralen
		# Grau eines nur geplünderten, noch niemandem gehörenden Gebäudes.
		mat.albedo_color = Color(0.3, 0.5, 0.75)
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
	mesh.set_surface_override_material(0, mat)
