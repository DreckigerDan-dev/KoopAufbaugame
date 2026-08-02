extends StaticBody3D
## Baubares Feld — produziert passiv Nahrung für den Besitzer (siehe
## docs/building.md, "Felder"). Einer der wenigen direkt platzierbaren
## Bautypen nach dem Baumenü-Umbau (Nutzerwunsch: Krankenstation/Werkstatt
## kommen seitdem übers Ausbauen geclaimter Gebäude, siehe docs/building.md,
## "Ausbauen") — Mauer/Wachposten/Tor/Feld bleiben direkt bebaubar.
## Host-autoritativ wie GuardPost.

const YIELD_INTERVAL := 8.0
const YIELD_AMOUNT := 2

var field_id: int = 0
var owner_peer_id: int = 1

var _yield_timer: float = 0.0


func _ready() -> void:
	if not multiplayer.is_server():
		set_process(false)


func _process(delta: float) -> void:
	_yield_timer += delta
	if _yield_timer < YIELD_INTERVAL:
		return
	_yield_timer = 0.0
	var base := _find_home_base()
	if base != null:
		base.add_resources.rpc({"food": YIELD_AMOUNT})


func _find_home_base() -> Node3D:
	# Eine Home-Base pro Peer (siehe docs/base.md) — gleiches Muster wie
	# Survivor._find_home_base().
	for base in get_tree().get_nodes_in_group("home_base"):
		if base.owner_peer_id == owner_peer_id:
			return base
	return null
