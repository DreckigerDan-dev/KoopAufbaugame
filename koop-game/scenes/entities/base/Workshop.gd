extends StaticBody3D
## Baubares Gebäude: verbilligt andere Bautypen (Wachposten/Mauer/Tor/
## Krankenstation) für den eigenen Besitzer, siehe World.gd,
## `_cost_for_build_type()`/`WORKSHOP_DISCOUNT`. Bewusst schlank: kein HP,
## kein Bautimer (siehe MedicalStation.gd für dieselbe Begründung). Gruppe
## "workshop" wird über den `.tscn`-Node-Header gesetzt (siehe
## docs/3d-migration.md für den Grund).

var workshop_id: int = 0
var owner_peer_id: int = 1
