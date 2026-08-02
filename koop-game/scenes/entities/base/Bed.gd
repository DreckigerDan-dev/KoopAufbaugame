extends StaticBody3D
## Baubares Gebäude: erweitert die Rastzone der eigenen Basis, siehe
## docs/survivor.md, "Müdigkeit" — Trupps in der Nähe erholen sich von
## Müdigkeit schneller als nur an der Basis. Bewusst schlank, gleiches
## Muster wie MedicalStation.gd: kein HP, kein Bautimer. Gruppe "bed" wird
## über den `.tscn`-Node-Header gesetzt (siehe docs/3d-migration.md für
## den Grund).

var bed_id: int = 0
var owner_peer_id: int = 1
