extends Node3D
## Die Stadt/Karte, 3D — komplette Migration von der ursprünglichen
## 2D-Testkarte (siehe docs/3d-migration.md für den vollständigen Verlauf).
## Übernimmt zusätzlich die frühere Commander-Rolle (Kamera, Auswahl,
## Bewegungs-/Bau-Befehle) direkt hier statt über einen eigenen gespawnten
## Commander-Node — Kamera braucht keine Netzwerk-Replikation, jeder Peer
## hat ohnehin nur seine eigene lokale Instanz dieser Szene. Siehe
## docs/world.md, docs/commander.md (jetzt hier gefaltet), docs/survivor.md,
## docs/zombies.md, docs/base.md, docs/building.md, docs/scavenging.md.

const SURVIVOR_SCENE := preload("res://scenes/entities/survivor/Survivor.tscn")
const HOME_BASE_SCENE := preload("res://scenes/entities/base/HomeBase.tscn")
const BUILDING_SCENE := preload("res://scenes/world/Building.tscn")
const VEHICLE_SCENE := preload("res://scenes/entities/vehicle/Vehicle.tscn")
const ZOMBIE_NEST_SCENE := preload("res://scenes/entities/zombie/ZombieNest.tscn")
const ZOMBIE_SCENE := preload("res://scenes/entities/zombie/Zombie.tscn")
const ZOMBIE_BRUTE_SCENE := preload("res://scenes/entities/zombie/ZombieBrute.tscn")
const GUARD_POST_SCENE := preload("res://scenes/entities/base/GuardPost.tscn")
const WALL_SCENE := preload("res://scenes/entities/wall/Wall.tscn")
const GATE_SCENE := preload("res://scenes/entities/wall/Gate.tscn")
const MEDICAL_STATION_SCENE := preload("res://scenes/entities/base/MedicalStation.tscn")
const BED_SCENE := preload("res://scenes/entities/base/Bed.tscn")
const WORKSHOP_SCENE := preload("res://scenes/entities/base/Workshop.tscn")
const STORAGE_SCENE := preload("res://scenes/entities/base/Storage.tscn")
const FIELD_SCENE := preload("res://scenes/entities/field/Field.tscn")
const OUTPOST_SCENE := preload("res://scenes/entities/base/Outpost.tscn")
const TREE_SCENE := preload("res://scenes/entities/tree/Tree.tscn")
const CAR_WRECK_SCENE := preload("res://scenes/entities/wreck/CarWreck.tscn")
const STONE_PILE_SCENE := preload("res://scenes/entities/pile/StonePile.tscn")
const BRICK_PILE_SCENE := preload("res://scenes/entities/pile/BrickPile.tscn")

const PAN_SPEED := 20.0
const MOUSE_ROTATE_SENSITIVITY := 0.006
const MOUSE_TILT_SENSITIVITY := 0.006
const TILT_MIN := 0.26  # ~15°, flacher Blickwinkel, kurz vorm Durchblicken am Boden
const TILT_MAX := 1.4  # ~80°, fast senkrecht von oben
const ZOOM_STEP_FACTOR := 0.15
# 4.0 → 10.0 (2026-08-01, Nutzerwunsch nach Vergleich mit einem Infection
# Free Zone-Screenshot, siehe docs/world.md, "Kamera-Zoom-Bereich") — dort
# kommt die Kamera nie so nah an einzelne Einheiten heran wie es bei uns
# mit 4.0 möglich war. Rein optisch/Stil-Entscheidung, KEINE Performance-
# Wirkung (siehe docs/world.md, "Kamera-Zoom-Bereich" für die Begründung,
# warum Zoom die Simulationslast nicht beeinflusst). Bleibt unter dem
# Default-Start-Zoom (_zoom_distance := 12.0), sonst wäre der Startwert
# beim ersten Frame außerhalb des gültigen Bereichs.
const ZOOM_MIN := 10.0
# Bewusst NICHT linear mit MAP_SIZE mitskaliert (siehe docs/world.md,
# "Kartengröße") — bei 5000 wäre "die ganze Karte ins Bild passen" völlig
# unnütz (einzelne Einheiten wären unsichtbar klein). Moderater Anstieg
# gegenüber der alten 40 (die selbst schon mal von 25 hochgesetzt wurde,
# damals noch für die 160er-Karte) für etwas mehr Übersicht — Navigation
# über größere Distanzen läuft über die Minimap (siehe Minimap.gd), nicht
# übers Rauszoomen.
const ZOOM_MAX := 60.0
const RAY_LENGTH := 1000.0
# Kartengröße (siehe docs/world.md, "Kartengröße") — EINZIGE Quelle der
# Wahrheit für die Bodenfläche: Ground/Mesh und Ground/Collision in
# World.tscn haben nur noch einen trivialen Platzhalter-Wert, ihre echte
# Größe wird in _ready() aus MAP_SIZE gesetzt (ground_mesh_instance.mesh.size/
# ground_collision.shape.size). Vorher stand die Kartengröße an DREI
# Stellen dupliziert (Konstante + zwei .tscn-Sub-Resources), musste
# manuell synchron gehalten werden. Auch von Minimap._to_minimap()/
# _pan_to() über get_tree().current_scene.MAP_SIZE gelesen — skaliert
# dort automatisch mit, keine Code-Änderung nötig.
const MAP_SIZE := 5000.0
# Fog of War (2026-08-01, Kartenplanungs-Session, Punkt 22 der Gesamtliste
# "Geteilte Aufklärung" — einer der vier Vision-Koop-Kanäle: entdeckte
# Kartenbereiche werden zwischen ALLEN Spielern geteilt, siehe docs/
# world.md, "Fog of War"). Bewusst KEIN neuer Netzwerk-Zustand — jeder Peer
# berechnet _explored_cells lokal aus den ohnehin schon replizierten
# Positionen aller "living"-Einheiten/Home-Bases ALLER Spieler (nicht nur
# der eigenen), dadurch bleibt der Nebel automatisch geteilt/konsistent
# zwischen Peers, ohne eine einzige zusätzliche RPC. Grober Raster statt
# Pixel-genauer Sicht (FOG_CELL_SIZE 100 bei MAP_SIZE 5000 = 50×50 Zellen)
# reicht für die Minimap-/Kartenansicht-Auflösung völlig, hält
# _explored_cells klein.
const FOG_CELL_SIZE := 100.0
const FOG_VISION_RADIUS := 130.0
const FOG_UPDATE_INTERVAL := 1.0
var _explored_cells: Dictionary = {}
var _fog_update_timer: float = 0.0
# Gegenseitige Verteidigung/Hilfe (Punkt 20 der Gesamtliste, vierter
# Vision-Koop-Kanal, siehe Infos/01 Architektur.md: "Trupps eines Spielers
# können einem anderen Spieler beim Kämpfen/Verteidigen helfen, auch ohne
# gemeinsame Basis") — mechanisch geht das schon: order_attack()/order_move()
# haben keinen Zonen-/Besitzer-Filter, ein Feldtrupp kann jederzeit zu einer
# fremden Basis laufen und dort mitkämpfen. Es fehlte nur die SICHTBARKEIT:
# ohne aktiv hinzuschauen merkt kein anderer Spieler, dass gerade jemand
# angegriffen wird. SOS_COOLDOWN drosselt PRO OPFER-PEER (nicht pro Treffer,
# sonst Spam bei jedem Zombie-Schlag alle ATTACK_COOLDOWN-Sekunden).
const SOS_COOLDOWN := 30.0
const SOS_MARKER_DURATION := 20.0
var _last_sos_broadcast: Dictionary = {}  # peer_id (Opfer) -> Time.get_ticks_msec()/1000.0 beim letzten Alarm
# Repliziert an ALLE Peers (siehe _sync_sos_alert()) — Minimap.gd/MapView.gd
# lesen das über get_tree().current_scene, gleiches Zugriffsmuster wie
# is_cell_explored(). Key = Opfer-Peer-ID, überschrieben bei jedem neuen
# Alarm (bleibt dadurch auf max. Spieleranzahl Einträge begrenzt).
var _sos_alerts: Dictionary = {}  # peer_id -> {"position": Vector3, "expires_at": float}
# Feste Bewegungshöhe für alle Bewegungs-/Suchziele — Hälfte der
# Survivor-Kapselhöhe (siehe Survivor.tscn, CapsuleMesh height := 1.7),
# damit die Kapsel mit der Unterkante auf dem Boden steht statt zu
# versinken/schweben. War 0.6 bei der alten 1,2m-Kapsel, jetzt auf 1,70m
# Trupp-Größe (Nutzerwunsch) entsprechend mit angehoben. Bewusst fest statt
# vom Raycast-Treffpunkt übernommen, siehe _select_at(), Gebäude-Fall.
const SURVIVOR_GROUND_Y := 0.85

# Eigene, getrennte Home-Base pro Peer (ARCHITECTURE.md: "Jeder Spieler hat
# seine eigene Basis/Kolonie, nicht geteilt") — seit der Start-Basis-Wahl
# (siehe docs/zones.md, "Start-Basis wählen") keine festen Kartenecken mehr,
# stattdessen wird Home-Base/Survivor-Start relativ zum gewählten Gebäude
# platziert: BASE_CHOICE_HOME_OFFSET/BASE_CHOICE_SURVIVOR_OFFSET geben den
# Abstand vom Gebäude-Mittelpunkt an, in Richtung von der Kartenmitte weg
# (damit die Home-Base nicht mit dem Gebäude selbst überlappt).
const BASE_CHOICE_HOME_OFFSET := 4.5
const BASE_CHOICE_SURVIVOR_OFFSET := 2.0

# Die früheren vier fest hinterlegten ZOMBIE_SPAWN_POINTS (Weltursprung-
# relativ) sind mit dem Kartenumbau entfallen (siehe docs/world.md,
# "Kartengröße") — Zombie-Spawnpunkte entstehen jetzt PRO Stadt-Zone auf
# einem Ring um deren Zentrum (siehe ZOMBIE_SPAWN_RING_OFFSET,
# _generate_city_zone()), nicht mehr einmalig um den Weltursprung.
# Feste Boden-Y pro Zombie-Typ (gleiches Prinzip wie TREE_GROUND_Y & Co.,
# siehe docs/survivor.md) — halbe Kapselhöhe (Standard 1.7m, Brute 2.1m).
const ZOMBIE_GROUND_Y := 0.85
const ZOMBIE_BRUTE_GROUND_Y := 1.05
# Feste Boden-Y für Fahrzeuge/Zombie-Nest (siehe _generate_city_zone()) —
# 1:1 aus den früheren festen Vehicle1/Vehicle2/ZombieNest1-Nodes
# übernommen (Vehicle-Mesh-Mitte 0.6, Nest-Mesh-Mitte 1.35).
const VEHICLE_GROUND_Y := 0.6
# Differenzierte Fahrzeugtypen (Punkt 19 der Gesamtliste) haben
# unterschiedliche Mesh-Höhen (siehe Vehicle.VEHICLE_STATS, "size") — halbe
# Höhe pro Typ, sonst würde z. B. der LKW sichtbar im Boden versinken
# (gleiche Falle wie ZOMBIE_BRUTE_GROUND_Y oben). VEHICLE_GROUND_Y bleibt als
# Fallback für unbekannte Typen/ältere Spielstände.
const VEHICLE_GROUND_Y_BY_TYPE := {"car": 0.6, "motorcycle": 0.5, "truck": 0.8}
const ZOMBIE_NEST_GROUND_Y := 1.35
# Globaler Zombie-Deckel (siehe docs/zombies.md, "Zombie-Obergrenze") —
# löst das seit dem Kartenumbau (5 Nester statt 1) verschärfte
# unbegrenzte-Wachstum-Risiko (persistentes Memory
# "koopgame_map_scale_performance": Entity-Zahl, nicht Fläche, ist der
# Flaschenhals — O(n) Zielsuche pro Zombie pro Frame über flache
# Gruppen-Iteration ohne Spatial-Struktur). 200 als Startwert zum
# Benchmarken gewählt (bewusst kein "richtiger" Wert, da hardwareabhängig
# — siehe DEBUG_ZOMBIE_SPAWN_COUNT unten für den Stresstest-Hotkey, mit
# dem sich das schnell empirisch nachjustieren lässt). Nur das Zombie-Nest
# respektiert den Deckel (spawn_nest_zombie() lässt einfach aus, kein
# Despawn nötig — sinkt von selbst, sobald Spieler welche töten);
# Horde-Nächte dürfen ihn bewusst kurz überschreiten (einmaliger Ausschlag
# von HORDE_SIZE bzw. an Blutmond-Nächten BLOOD_MOON_HORDE_SIZE, siehe dort
# — anders als beim Zombie-Nest keine kontinuierliche Nachspawn-Quelle).
const MAX_ZOMBIES := 200
# Spatial Grid für Zombie-Nachbarschaftssuche (siehe docs/zombies.md,
# "Performance: Spatial Grid" — Punkt 2 der Performance-Liste, Reaktion auf
# den 500-Zombie/15-FPS-Benchmark). Behebt den echten O(z²)-Kampf-Hotspot:
# Zombie._alert_nearby_zombies()/GuardPost._find_nearest_zombie()/
# _alert_nearby_zombies() durchsuchten bisher bei JEDEM Aufruf die komplette
# "zombie"-Gruppe statt nur die Nachbarschaft. Zellgröße bewusst größer als
# der größte gebrauchte Suchradius (Zombie.FIRE_NOISE_RADIUS/NOISE_RADIUS,
# max. 13) gewählt, damit ein 3×3-Zellen-Ausschnitt um den Zielpunkt
# garantiert jeden Kandidaten innerhalb des Radius trifft (siehe
# zombies_near()). Nur host-seitig befüllt (_process() unten,
# multiplayer.is_server()-gated) — nur der Host simuliert Zombies/Wachposten
# überhaupt (siehe Zombie._ready()/GuardPost._ready(), set_process(false) auf
# Clients).
const ZOMBIE_GRID_CELL_SIZE := 15.0
var _zombie_grid: Dictionary = {}  # Vector2i -> Array[Node3D]
# Zielsuche throttlen (siehe docs/zombies.md, "Performance: Zielsuche
# throttlen" — Punkt 3 der Performance-Liste, vermutlich der dominante
# Overhead im 500-Zombie-Benchmark): Zombie._update_chase_target() rief
# bisher _find_nearest_target() jeden Frame für jeden ziellosen Zombie auf
# (500× pro Frame eine Schleife über "living"+"searchable", ~130 Einträge).
# Jetzt gedrosselt, siehe Zombie.gd, TARGET_SEARCH_INTERVAL.
# Zombie-Despawn (siehe docs/zombies.md, "Zombie-Despawn" — Punkt 4 der
# Performance-Liste): MAX_ZOMBIES/das Zombie-Nest allein sinken nur durch
# Spielerkills, nie von selbst — ein Wander-Zombie, der sich von jeder
# lebenden Einheit/geclaimten Gebäude wegbewegt (z. B. in eine nie besuchte
# Stadt-Zone), bleibt für den Rest der Session für niemanden mehr relevant
# und zählt trotzdem gegen den Deckel. Bewusst rein distanzbasiert statt mit
# eigener Alters-Verfolgung pro Zombie (siehe ZOMBIE_DESPAWN_RADIUS) — ein
# Zombie kann nur "alt UND fern" im gemeinten Sinn sein, wenn er seit
# längerem niemanden mehr in der Nähe hat, ein einfacher Distanz-Check
# erfasst das schon ohne zusätzlichen Zustand pro Zombie.
# Radius bewusst groß genug für eine GANZE aktiv bespielte Stadt-Zone
# gewählt, nicht nur für die unmittelbare Nähe: am schlimmsten Fall (größte
# Zone, CITY_ZONE_RADIUS_LARGE=260) spawnen die Start-Zombies auf einem
# Ring bei 260+ZOMBIE_SPAWN_RING_OFFSET(60)=320, Gebäude liegen innerhalb
# der 260 verteilt — im Extremfall (Zombie und einziges geclaimtes Gebäude
# auf gegenüberliegenden Seiten der Zone) macht das 320+260=580 Weltmeter
# Abstand, obwohl die Zone eindeutig aktiv bespielt wird. Muss mit
# CITY_ZONE_RADIUS_LARGE/ZOMBIE_SPAWN_RING_OFFSET mitgepflegt werden (seit
# der Kartenplanungs-Session 2026-08-01 zwei Zonengrößen statt einer, hier
# immer der größte Fall) — trotzdem deutlich kleiner als
# CITY_ZONE_MIN_SPACING (800), reicht also nie in eine benachbarte Zone
# hinein.
const ZOMBIE_DESPAWN_RADIUS := 580.0
const ZOMBIE_DESPAWN_CHECK_INTERVAL := 10.0
var _zombie_despawn_timer: float = 0.0
# Debug-Stresstest-Hotkey (siehe _unhandled_input()) — spawnt sofort
# DEBUG_ZOMBIE_SPAWN_COUNT Zombies verteilt um die Kamera, ohne auf die
# 25s-Nest-Spawnintervalle zu warten. Nur zum Benchmarken/Testen des
# MAX_ZOMBIES-Werts, kein Spielfeature.
const DEBUG_ZOMBIE_SPAWN_COUNT := 50
const DEBUG_ZOMBIE_SPAWN_SCATTER := 30.0
# Horde-Nächte (siehe docs/zombies.md, "Horde-Nächte") — periodische große
# Zombie-Wellen, zusätzlich zum laufenden lokalen Lärm-Aggro und dem
# Zombie-Nest (siehe docs/zombies.md, "Zombie-Nest"), nicht als Ersatz
# dafür. Löst seit dem Tag/Nacht-Zyklus (siehe unten) nicht mehr per
# reinem Echtzeit-Intervall aus, sondern genau einmal bei jedem
# Nachteintritt (_handle_day_night()). HORDE_BRUTE_COUNT von HORDE_SIZE
# sind Brutes statt Standard-Zombies (siehe docs/zombies.md,
# "Zombie-Typen") — macht Horde-Nächte spürbar bedrohlicher als nur mehr
# vom Gleichen.
const HORDE_SIZE := 10
const HORDE_BRUTE_COUNT := 2
const HORDE_SPAWN_SCATTER := 6.0
# Seit dem Kartenumbau (siehe docs/world.md, "Kartengröße") spawnt eine
# Horde nicht mehr an einem festen, ggf. weit entfernten Punkt, sondern
# aus HORDE_APPROACH_DISTANCE Entfernung um das gewählte Ziel selbst
# (siehe _trigger_horde_night()) — sonst müsste eine Horde auf der
# 5000×5000-Karte unter Umständen kilometerweit zum eigentlichen Ziel
# laufen, bevor überhaupt Druck entsteht.
const HORDE_APPROACH_DISTANCE := 40.0
# Blutmond-Kalender-Eskalation (Punkt 21 der Gesamtliste, Vorbild
# Infos/01 Architektur.md: "Alle paar Tage [kalenderbasiert] formiert sich
# eine große, gebündelte Horde und greift gezielt an — zusätzlich zum
# laufenden lokalen Lärm-Aggro, nicht als Ersatz dafür.") Bisherige
# Horde-Nächte (siehe oben) feuern schon JEDE Nacht mit fester Stärke —
# das deckt den "lokalen Lärm-Aggro"-Teil der Vision-Formulierung ab, aber
# nicht die kalenderbasierte STEIGERUNG. Jede BLOOD_MOON_INTERVAL_DAYS-te
# Nacht wird deshalb zu einem "Blutmond": deutlich größere, brute-lastigere
# Welle mit eigener Vorwarnung, on top of der normalen Horde-Nacht-Logik
# (_trigger_horde_night() bleibt EINE Funktion, verzweigt nur intern).
const BLOOD_MOON_INTERVAL_DAYS := 5
const BLOOD_MOON_HORDE_SIZE := 30
const BLOOD_MOON_BRUTE_COUNT := 10
# _day_count zählt volle Spieltage (siehe _handle_day_night(), inkrementiert
# bei jedem Zyklus-Wrap) — läuft wie _day_time lokal auf JEDEM Peer (nicht
# host-gated), damit is_blood_moon_night() auf allen Peers identisch
# auswertet (gebraucht für den Blutmond-Himmel-Ton in
# _update_day_night_visuals(), nicht nur für den host-gateden Horde-
# Trigger). Catch-up über _catch_up_day_time() (zweiter Parameter),
# Spielstand-Persistenz über _collect_save_data()/_load_game_state().
var _day_count: int = 0

# Tag/Nacht-Zyklus (Nutzerwunsch: Horde-Nächte an einen echten Spieltag
# koppeln statt an ein reines Echtzeit-Intervall, später ergänzt um eine
# echte Uhrzeit-Anzeige + Nutzerwunsch "Zombies ab 22 Uhr bis 4 Uhr
# morgens 20% stärker"). Ein voller Zyklus (CYCLE_LENGTH := 300s
# Echtzeit, bewusst derselbe Gesamtrhythmus wie das frühere
# HORDE_INTERVAL) entspricht genau einem 24-Stunden-Spieltag
# (HOURS_PER_DAY) — _day_time (Sekunden) und die angezeigte Uhrzeit
# (current_game_hour(), _clock_text()) sind also zwei Ansichten
# desselben Werts. NIGHT_START_HOUR/NIGHT_END_HOUR (22:00–4:00, 6
# Spielstunden) sind DER EINE Ort, der sowohl bestimmt, wann es optisch
# Nacht ist (_night_amount(), Horde-Trigger) als auch wann Zombies den
# ZOMBIE_NIGHT_DAMAGE_MULTIPLIER (siehe Zombie.gd) bekommen — ein
# einziges Zeitfenster für beides, keine zwei getrennten Werte, die
# auseinanderlaufen könnten. DUSK_LENGTH sorgt für sanftes Ab-/Aufdunkeln
# statt eines harten Umschaltens, siehe _night_amount(). Läuft lokal auf
# JEDEM Peer (nicht nur Host) für Beleuchtung/Anzeige, nur der
# Horde-Trigger selbst ist host-gated (siehe _handle_day_night()). Späte
# Peers bekommen den aktuellen Stand per _catch_up_day_time()
# nachgeliefert (siehe _spawn_for_peer()), sonst würden sie bei 0 (=00:00)
# neu starten.
const CYCLE_LENGTH := 300.0
const HOURS_PER_DAY := 24.0
const NIGHT_START_HOUR := 22.0
const NIGHT_END_HOUR := 4.0
# In Sekunden umgerechnet (22/24*300 = 275, 4/24*300 = 50) — _day_time
# rechnet intern in Sekunden, die Uhrzeit ist nur eine Anzeige-Ableitung
# davon (siehe current_game_hour()).
const NIGHT_START_TIME := NIGHT_START_HOUR / HOURS_PER_DAY * CYCLE_LENGTH
const NIGHT_END_TIME := NIGHT_END_HOUR / HOURS_PER_DAY * CYCLE_LENGTH
const DUSK_LENGTH := 20.0
const DAY_LIGHT_ENERGY := 1.0
const NIGHT_LIGHT_ENERGY := 0.15
const DAY_LIGHT_COLOR := Color(1.0, 0.98, 0.9)
const NIGHT_LIGHT_COLOR := Color(0.4, 0.45, 0.75)
const DAY_SKY_COLOR := Color(0.55, 0.75, 0.95)
const NIGHT_SKY_COLOR := Color(0.02, 0.02, 0.1)
const DAY_AMBIENT_ENERGY := 0.6
const NIGHT_AMBIENT_ENERGY := 0.05
# Blutmond-Himmel-Ton (siehe BLOOD_MOON_INTERVAL_DAYS oben) — mischt sich
# über dieselbe Dusk-Kurve (_night_amount()) wie der normale Tag/Nacht-
# Übergang ein, ERSETZT die Nachtfarbe nicht hart, sonst würde die
# Dusk-Überblendung an einer Blutmond-Nacht sichtbar springen statt weich
# zu verlaufen.
const BLOOD_MOON_LIGHT_COLOR := Color(0.9, 0.25, 0.2)
const BLOOD_MOON_SKY_COLOR := Color(0.25, 0.02, 0.02)

# Zombie-Loot-Drop (ursprünglich Nutzerwunsch: "nur Munition, Heilzeug,
# oder eine Waffe, mehr nicht") — kein physischer Pickup-Node, geht bei Tod
# direkt an die Home-Base des Spielers, der den Kill verursacht hat (siehe
# Zombie._last_damage_source_peer_id, grant_zombie_loot()). "weapon"
# (achte Ressourcenart), "armor" (neunte, Brustpanzer-Slot) und "helmet"
# (zehnte, zweiter Rüstungs-Slot) wurden später per explizitem
# Nutzerwunsch ergänzt (siehe docs/survivor.md, "Rüstungssystem") — fünf
# statt drei gleich gewichtete Typen verdünnen die Drop-Rate der
# ursprünglichen drei entsprechend weiter, bewusst in Kauf genommen statt
# einen zweiten, komplett neuen Drop-Mechanismus nur für Rüstung/Helm zu
# bauen.
const ZOMBIE_LOOT_DROP_CHANCE := 0.5
# "backpack" war kurzzeitig (Punkt 9 der Gesamtliste) ein sechster Loot-Typ
# hier — Nutzerentscheidung: Rucksack ist kein Item mehr, sondern fester
# Bestand jedes Trupps (siehe docs/survivor.md, "Rucksack"), deshalb wieder
# zurückgebaut auf die ursprünglichen fünf Typen. Seit Punkt 18 der
# Gesamtliste ("Haupt-/Sekundärwaffe"/"mehrere Rüstungsteile") um
# "melee_weapon"/"leg_armor" auf sieben Typen erweitert — verdünnt jede
# einzelne Drop-Chance weiter, bewusst in Kauf genommen (gleiches Muster
# wie beim Hinzufügen von armor/helmet, siehe docs/survivor.md,
# "Rüstungssystem").
const ZOMBIE_LOOT_TABLE := ["ammo", "medicine", "weapon", "armor", "helmet", "melee_weapon", "leg_armor"]
const ZOMBIE_LOOT_AMOUNT := {"ammo": 5, "medicine": 5, "weapon": 1, "armor": 1, "helmet": 1, "melee_weapon": 1, "leg_armor": 1}
const BRUTE_LOOT_AMOUNT := {"ammo": 10, "medicine": 8, "weapon": 1, "armor": 1, "helmet": 1, "melee_weapon": 1, "leg_armor": 1}
# Forschungsbücher (Punkt 13 der Gesamtliste, siehe docs/building.md,
# "Forschungsbücher") — BEWUSST NICHT Teil der obigen ZOMBIE_LOOT_TABLE
# (das gleichgewichtete 1/6-Poolprinzip passt hier nicht: die Vision
# beschreibt Bücher explizit als "selten"/"sehr selten", ein sechs- oder
# elfgeteilter gleichgewichteter Pool wäre viel zu häufig). Stattdessen ein
# unabhängiger, deutlich selteneren Zusatz-Wurf bei jedem Zombie-Tod, egal
# ob der Haupt-Loot-Wurf (ZOMBIE_LOOT_DROP_CHANCE) überhaupt trifft.
const BOOK_DROP_CHANCE := 0.08
const BOOK_TABLE := ["book_weapon", "book_armor", "book_helmet", "book_ammo"]

# Start-Trupps pro Peer (2026-08-03 von 2 auf 5 angehoben, Nutzerwunsch
# "5 truppen start") — bewusster Kompromiss von vor der In-Game-
# Rekrutierung (siehe docs/recruitment.md) — sonst gäbe es nie einen freien
# Trupp für einen GuardPost, sobald der einzige stationiert ist. Beide
# Mechanismen koexistieren weiterhin, siehe docs/recruitment.md. Alle
# START_SURVIVOR_COUNT Trupps entstehen auf einer Linie entlang der
# `sideways`-Achse (siehe request_choose_start_base()), NICHT über den
# world-absoluten _formation_offset() — der würde bei ungünstiger
# Gebäude-Ausrichtung einzelne Trupps wieder Richtung/in das Gebäude-Mesh
# zurückschieben (derselbe Bug wie beim früheren festen
# Welt-Vektor-Offset, siehe docs/zones.md, "Start-Basis wählen").
const START_SURVIVOR_COUNT := 5
const START_SURVIVOR_SPACING := 1.5

## Baumenü-Umbau (Nutzerwunsch): direkt platzierbar sind nur noch
## GUARD_POST/WALL/GATE/FIELD. MEDICAL_STATION/WORKSHOP bleiben als Werte
## erhalten (weiterhin für Kosten-Lookup und request_upgrade_building()
## gebraucht), sind aber über kein Bau-Button/_build_type mehr erreichbar —
## sie entstehen jetzt ausschließlich durchs Ausbauen eines bereits
## geplünderten UND geclaimten eigenen Gebäudes, siehe docs/building.md,
## "Ausbauen".
enum BuildType { GUARD_POST, WALL, GATE, MEDICAL_STATION, WORKSHOP, FIELD, STORAGE, OUTPOST, BED }

# Gilt für alle Bautypen (Wachposten/Mauer/Tor/Krankenstation/Werkstatt)
# UND fürs Claimen von Gebäuden (siehe docs/zones.md) — derselbe Radius um
# die eigene Home-Base ODER um jedes bereits geclaimte Gebäude definiert
# die eigene Bauzone, siehe is_within_own_zone().
const BUILD_RADIUS := 8.0
# Feste Boden-Y statt der Y-Koordinate eines Anker-Gebäudes zu übernehmen
# (Bug, gefunden bei der Ressourcenknoten-Überarbeitung) — seit der
# Gebäudehöhen-Skalierung (siehe docs/world.md) liegt building.position.y
# je nach Gebäude zwischen 1,55 und 2,2, deutlich über dem tatsächlichen
# Boden. Jeder Ressourcentyp braucht eine eigene Y, weil die Mesh-Geometrie
# unterschiedlich zentriert ist (siehe Tree.tscn/CarWreck.tscn/
# StonePile.tscn/BrickPile.tscn) — Wert = Boden-Oberfläche (0.1) minus
# unterster Mesh-Punkt relativ zum jeweiligen Node-Ursprung.
const TREE_GROUND_Y := 1.2
const CAR_WRECK_GROUND_Y := 0.45
const STONE_PILE_GROUND_Y := 0.4
const BRICK_PILE_GROUND_Y := 0.35

# Gebäude-Typen (siehe docs/world.md, "Kartengröße" + docs/building.md,
# "Gebäude-Typen + Loot-Tabellen" — Punkt 17 der Gesamtliste). Ersetzen die
# früheren zwölf ANONYMEN Vorlagen (gleiche Struktur, nur Größe/Loot/Farbe
# unterschiedlich) durch vier ECHTE, aus der Vision benannte Gebäudetypen
# (Infos/01 Architektur.md, "Loot-Tabellen je Gebäudetyp") mit einer echten
# Loot-TABELLE statt eines einzigen festen Werts: `main_loot` (garantiert,
# Betrag als Bereich) + `secondary_loot` (unabhängige Chancen), ausgerollt
# bei jedem Gebäude-Spawn (siehe _roll_building_loot()). Wichtige
# Abgrenzung: nur Ressourcen, die es in diesem System gibt (siehe
# docs/base.md, "Vier Baurohstoffe") — Vision-Unterkategorien wie
# "Werkzeuge"/"Ersatzteile"/Waffen-Untertypen (Pistole/Schrotflinte/...)
# existieren hier nicht. "Werkstatt/Baumarkt" (fünfter Vision-Typ, Loot
# wäre Baumaterial) bewusst NICHT übernommen — Holz/Metall/Stein/Ziegel
# kommen in diesem System ausschließlich aus eigenen Ressourcenknoten
# (Baum/Autowrack/Stein-/Ziegelhaufen), nie aus Stadt-Gebäude-Loot (siehe
# docs/survivor.md, "Ressourcen abbauen" — eine frühere, vom Nutzer
# bestätigte Korrektur genau dieses Vermischens, nicht wieder aufgehoben).
# Größenspanne bewusst im bisherigen Platzhalter-Rahmen belassen statt der
# echten Vision-Maße (z. B. "18m Supermarkt") — Neukalibrierung erst mit
# echten Assets (gleiche Einschränkung wie beim Lager, siehe
# docs/building.md). Index 1 ("Wohnhaus") war früher das einzige Gebäude
# mit `has_survivor` — das ist weiterhin eine vom gewürfelten Typ
# UNABHÄNGIGE Eigenschaft (siehe _generate_city_zone()): pro Zone bekommt
# GENAU einer der dort platzierten Plätze `has_survivor = true`, egal
# welcher Typ dort gezogen wurde.
const BOOK_LOOT_TYPES := ["book_weapon", "book_armor", "book_helmet", "book_ammo"]
const BUILDING_TYPES: Array[Dictionary] = [
	{
		"name": "Wohnhaus",
		"size": Vector3(2, 3.4, 2),
		"default_color": Color(0.45, 0.38, 0.3),
		"main_loot": {"resource": "food", "amount": Vector2i(1, 2)},
		"secondary_loot": [
			{"resource": "medicine", "chance": 0.3, "amount": Vector2i(3, 6)},
			{"resource": "book", "chance": 0.1, "amount": Vector2i(1, 1)},
		],
	},
	{
		"name": "Supermarkt",
		"size": Vector3(3.2, 3.7, 2.6),
		"default_color": Color(0.5, 0.42, 0.32),
		"main_loot": {"resource": "food", "amount": Vector2i(12, 20)},
		"secondary_loot": [
			{"resource": "medicine", "chance": 0.2, "amount": Vector2i(3, 6)},
		],
	},
	{
		"name": "Apotheke",
		"size": Vector3(1.8, 3.4, 2),
		"default_color": Color(0.4, 0.35, 0.28),
		"main_loot": {"resource": "medicine", "amount": Vector2i(10, 18)},
		"secondary_loot": [
			{"resource": "medicine", "chance": 0.5, "amount": Vector2i(3, 6)},
			{"resource": "book", "chance": 0.1, "amount": Vector2i(1, 1)},
		],
	},
	{
		"name": "Waffenladen/Polizeistation",
		"size": Vector3(2.4, 3.7, 2.6),
		"default_color": Color(0.46, 0.36, 0.26),
		"main_loot": {"resource": "weapon", "amount": Vector2i(1, 1)},
		"secondary_loot": [
			{"resource": "ammo", "chance": 0.5, "amount": Vector2i(10, 20)},
			{"resource": "armor", "chance": 0.4, "amount": Vector2i(1, 1)},
			{"resource": "helmet", "chance": 0.3, "amount": Vector2i(1, 1)},
		],
	},
]


func _roll_building_loot(template: Dictionary) -> Dictionary:
	# Baut die konkrete Loot-Dictionary EINMALIG beim Gebäude-Spawn aus
	# main_loot (garantiert)/secondary_loot (je unabhängig gewürfelt) einer
	# BUILDING_TYPES-Vorlage — läuft nur host-seitig (_generate_city_zone()
	# läuft nur in _ready() auf dem Host, wie der Rest der Weltgenerierung),
	# das fertige Ergebnis wird als normale Spawn-Daten repliziert, kein
	# eigener Zufall auf dem Client nötig.
	var loot: Dictionary = {}
	_apply_loot_roll(loot, template["main_loot"])
	for secondary in template.get("secondary_loot", []):
		if randf() < secondary["chance"]:
			_apply_loot_roll(loot, secondary)
	return loot


func _apply_loot_roll(loot: Dictionary, spec: Dictionary) -> void:
	var resource: String = spec["resource"]
	if resource == "book":
		# "Buch" steht stellvertretend für einen zufälligen der vier
		# book_*-Typen (siehe docs/building.md, "Forschungsbücher") — Vision
		# nennt Bücher nur allgemein als Nebenloot, ohne Typ-Bezug.
		resource = BOOK_LOOT_TYPES[randi() % BOOK_LOOT_TYPES.size()]
	var amount_range: Vector2i = spec["amount"]
	var amount: int = amount_range.x if amount_range.x == amount_range.y else randi_range(amount_range.x, amount_range.y)
	loot[resource] = loot.get(resource, 0) + amount

# Stadt-Zonen-Generierung (siehe docs/world.md, "Kartengröße"/"Kartenplanung
# 2026-08-01") — ersetzt die früheren zwölf/zwei/eine fest platzierten
# Gebäude/Fahrzeuge/das eine Zombie-Nest. Host würfelt beim Welt-Start
# CITY_ZONE_COUNT Zentren mit Mindestabstand, pro Zentrum entsteht eine
# komplette Mini-Stadt (Gebäude/Fahrzeuge/Nest/Zombie-Spawnpunkte) — kein
# Noise-basiertes Biom-Blending, kein Terrain (bleibt flach, siehe
# persistentes Memory "koopgame_map_planning_session" für die
# Höhenrelief-Idee als spätere Backlog-Option), analog zum bestehenden
# _is_far_enough_from_others()-Muster.
# ZWEI Zonen-Größen (2026-08-01, Kartenplanungs-Session, Nutzerwunsch
# "statt eine große mehrere eine kleine da zwei große" — zwei deutlich
# größere Städte + drei kleinere statt fünf gleich großer) statt einer
# einzigen Größe. Gesamtzahl bewusst weiterhin 5 (Performance-Rücksicht,
# siehe persistentes Memory "koopgame_map_scale_performance") —
# CITY_ZONE_LARGE_COUNT + CITY_ZONE_SMALL_COUNT statt eines einzigen
# CITY_ZONE_COUNT-Werts.
const CITY_ZONE_LARGE_COUNT := 2
const CITY_ZONE_SMALL_COUNT := 3
const CITY_ZONE_COUNT := CITY_ZONE_LARGE_COUNT + CITY_ZONE_SMALL_COUNT
const CITY_ZONE_MIN_SPACING := 800.0
# Große Zone deutlich über der vorherigen einheitlichen Größe (200), kleine
# darunter — CITY_ZONE_MIN_SPACING (800) bleibt weit über dem größten
# möglichen Zonen-Durchmesser (2×260=520), Zonen können also weiterhin
# nicht überlappen, auch nicht zwei benachbarte große.
const CITY_ZONE_RADIUS_LARGE := 260.0
const CITY_ZONE_RADIUS_SMALL := 150.0
# Gebäudezahl grob proportional zur Fläche gestuft (große Zone ≈ 2× Fläche
# einer kleinen bei diesen Radien). 2026-08-03 auf Nutzerwunsch ("pack noch
# paar mehr häuser rein") von 60/30 auf 100/50 angehoben (Summe 350 statt
# 210) — reine Erhöhung der ausgewählten Teilmenge, keine Geometrie-/
# Asset-Änderung nötig: _generate_street_slots() erzeugt pro Zone ohnehin
# schon ein Vielfaches an Reihenplätzen (mehrere Tausend bei der großen
# Zone), es wird nur ein größerer Anteil davon tatsächlich bebaut. Keine
# spürbare Mehrbelastung für die Zombie-Zielsuche — die durchsucht nur
# GECLAIMTE Gebäude (`owner_peer_id != 0`, siehe Zombie._find_nearest_
# target()), unclaimte Gebäude kosten dort praktisch nichts zusätzlich.
const BUILDINGS_PER_LARGE_ZONE := 100
const BUILDINGS_PER_SMALL_ZONE := 50
const VEHICLES_PER_ZONE := 2
# Differenzierte Fahrzeugtypen (Punkt 19 der Gesamtliste) — String-Keys aus
# Vehicle.VEHICLE_STATS, siehe dort für Werte/Begründung. Zufällig pro
# Spawn gewählt (siehe _generate_city_zone()), kein fester Typ pro Slot.
const VEHICLE_TYPES := ["car", "motorcycle", "truck"]
const ZOMBIES_PER_ZONE := 4
# Abstand der vier Zombie-Ring-Spawnpunkte ÜBER den jeweiligen Zonenrand
# hinaus (vorher fest in ZOMBIE_SPAWN_RING_RADIUS verrechnet, jetzt pro
# Zone aus dem jeweiligen Radius + diesem Offset hergeleitet, siehe
# _generate_city_zone() — nötig, weil es jetzt zwei verschiedene
# Zonen-Radien gibt statt eines einzigen).
const ZOMBIE_SPAWN_RING_OFFSET := 60.0
# Eigener, größerer Mindestabstand nur für Gebäude-/Fahrzeug-/Nest-
# Platzierung (siehe _is_far_enough_from_others()) — MIN_RESOURCE_SPACING
# (3.0, siehe unten) ist für kleine Ressourcenknoten gedacht, Gebäude sind
# mit 2-4m Kantenlänge spürbar größer und würden sich sonst sichtbar
# überlappen können. Dient seit der Straßen-Raster-Umstellung (siehe
# _generate_street_slots()) zusätzlich als Abstand der Gebäude INNERHALB
# einer Reihe.
const BUILDING_MIN_SPACING := 6.0
# Straßen-Raster (2026-08-01, Kartenplanungs-Session — Vorbild Infection
# Free Zone: echte Häuserreihen entlang klarer Straßen statt Zufallsstreuen,
# siehe docs/world.md, "Straßen-Raster"). STREET_BLOCK_SIZE ist die
# Kantenlänge eines quadratischen Baublocks, STREET_WIDTH die Straßenbreite
# dazwischen — beide Werte gelten für JEDE Zonengröße gleich (eine größere
# Stadt hat mehr Blöcke, nicht größere), das hält die Optik konsistent.
# _generate_street_slots() erzeugt absichtlich MEHR Reihenplätze als
# gebraucht (siehe dort) — _generate_city_zone() wählt per Zufall nur
# BUILDINGS_PER_*_ZONE davon aus, dadurch bleibt die Gesamt-Gebäudezahl
# (und damit die Performance) unverändert, nur ihre GEOMETRIE folgt jetzt
# echten Reihen statt reinem Zufall.
# Seit der Straßen-Geometrie-Kachel-Umstellung (2026-08-02, siehe
# _build_zone_street_tiles()) sind STREET_BLOCK_SIZE/STREET_WIDTH aus der
# Kachelgröße der vom Nutzer gebauten Blender-Assets hergeleitet
# (STREET_TILE_SIZE, siehe Infos/04 Straßen-Kacheln Modellier-Referenz.md)
# statt eigener freier Zahlen — GridMap braucht eine echte Zelle pro
# Kachel, ein Block ist BLOCK_TILES Kacheln breit, danach folgt GENAU EINE
# Straßen-Kachel-Reihe/-Spalte (Periode BLOCK_TILES+1 Kacheln).
const STREET_TILE_SIZE := 12.0
const BLOCK_TILES := 2
const STREET_BLOCK_SIZE := float(BLOCK_TILES) * STREET_TILE_SIZE
const STREET_WIDTH := STREET_TILE_SIZE
const STREET_CELL_SIZE := STREET_BLOCK_SIZE + STREET_WIDTH
# Wie weit eine Gebäude-Reihe von der Blockkante (= Straßenrand) nach innen
# versetzt ist, damit Gebäude nicht auf der Straße selbst stehen.
const BUILDING_ROW_INSET := 2.0
# Sichtbare Straßen-Geometrie: seit 2026-08-02 echte Kachel-Meshes über
# $StreetGridMap statt eigener BoxMesh-Streifen (siehe
# _build_zone_street_tiles()), deshalb hier keine STREET_GROUND_Y/
# STREET_COLOR-Konstanten mehr — Höhe/Optik kommen aus World.tscn
# ($StreetGridMap.position.y) bzw. direkt aus den Blender-Assets.

# Wald-Zonen (siehe docs/world.md, "Wald-Zonen" — Punkt 10 der Gesamtliste,
# "Biome/Wald-Zonen": visuelle/thematische Vielfalt jenseits reiner
# Stadt-Zonen). Zweiter Zonen-Typ, gleiches Cluster-Prinzip wie Stadt-Zonen
# (kein Noise/Terrain, siehe oben) — Mindestabstand zu Stadt- UND
# Wald-Zonen über denselben CITY_ZONE_MIN_SPACING-Wert (siehe
# _is_far_from_zone_centers()), damit sich keine zwei Zonen (egal welchen
# Typs) überlappen können.
const FOREST_ZONE_COUNT := 5
const FOREST_ZONE_RADIUS := 150.0
# Deutlich dichter als die allgemeine Wildnis-Streuung (siehe
# TREES_TOTAL/MAP_SIZE unten — ca. 1 Baum pro 1.767 m² hier gegen ca. 1 Baum
# pro 121.860 m² in der Wildnis,~69× dichter) — das ist der eigentliche
# visuelle Unterschied zu einem "hier stehen halt ein paar Bäume"-Gebiet.
const TREES_PER_FOREST_ZONE := 40
# Ein Jagdstand pro Wald-Zone (Vision: Infos/02 Item-Liste.md, "Waldrand"-
# Loot: Munition/Waffen/Fernglas — Fernglas hat keinen eigenen Ressourcen-
# Typ, deshalb nur Munition+Waffe). Bewusst NICHT Teil von
# BUILDING_TYPES (würde sonst zufällig auch in einer Stadt-Zone
# auftauchen können) — eigene, feste Vorlage, nur von
# _generate_forest_zone() verwendet.
const FOREST_BUILDING_TEMPLATE := {"size": Vector3(2.2, 3.2, 2.4), "loot": {"ammo": 20, "weapon": 1}, "default_color": Color(0.32, 0.26, 0.16)}
var _forest_zone_centers: Array[Vector3] = []

# Ressourcen-Verteilung über die GANZE Karte statt nur um die Kartenmitte
# (Nutzerwunsch: Rohstoffe schon von Spielbeginn an vorhanden, jetzt über
# mehrere, weit verteilte Stadt-Zonen hinweg). Bewusst NICHT proportional
# zur Fläche hochskaliert: 5000×5000 hat ~977× die Fläche der früheren
# 160×160-Karte — dieselbe Dichte wie bisher (24 Ressourcenknoten auf
# einem 120×120-Fleck) hätte zehntausende Knoten zur Folge und liefe
# direkt in das schon bekannte Performance-Risiko (siehe persistentes
# Memory "koopgame_map_scale_performance": Entity-Zahl, nicht Fläche, ist
# der Flaschenhals). Stattdessen feste, moderat erhöhte Gesamtzahlen
# (vorher 10/4/5/5).
const TREES_TOTAL := 200
const CAR_WRECKS_TOTAL := 80
const STONE_PILES_TOTAL := 100
const BRICK_PILES_TOTAL := 100
# Mindestabstand zwischen neu gespawnten Ressourcenknoten und
# Gebäuden/Fahrzeugen/Zombie-Nest/anderen Ressourcenknoten (Nutzerwunsch:
# "alles was im Spiel spawnt soll ein bisschen Platz dazwischen haben"),
# siehe _spaced_position(). SPACING_ATTEMPTS begrenzt die Versuche, damit
# das Spawnen nie hängen bleibt, falls in einem Bereich schon alles voll ist.
const MIN_RESOURCE_SPACING := 3.0
const SPACING_ATTEMPTS := 10
# Gedeckeltes, langsames Ressourcen-Nachwachsen (siehe docs/world.md,
# "Ressourcen-Nachwachsen" — Punkt 5 der Performance-Liste): Trupps können
# TREES_TOTAL/CAR_WRECKS_TOTAL/STONE_PILES_TOTAL/BRICK_PILES_TOTAL über eine
# lange Session hinweg komplett leer ernten, danach gibt es diesen Rohstoff
# nie wieder. Bewusst NICHT dasselbe Muster wie das frühere, explizit wieder
# entfernte Pro-Zonen-Ereignis-Nachwachsen (siehe "Rückfrage beantwortet",
# `docs/status.md`, wollte der Nutzer nicht) — hier gibt es KEIN Ereignis,
# das das Nachwachsen auslöst, sondern ein reiner Zeit-Tick, und die
# jeweilige TOTAL-Konstante ist zugleich die Obergrenze: höchstens ein neuer
# Knoten pro Typ pro Intervall, nie mehr insgesamt als beim einmaligen
# Anfangs-Spawn.
const RESOURCE_REGROWTH_INTERVAL := 30.0
var _resource_regrowth_timer: float = 0.0
# Vier Baurohstoffe statt eines generischen "materials" (siehe
# docs/base.md, "Vier Baurohstoffe") — jeder Bautyp braucht genau eine
# thematisch passende Art: Wachposten (Holzturm), Mauer (Steinwall), Tor
# (Metallbeschlag/-scharniere), Krankenstation (Ziegelbau), Werkstatt
# (Maschinen/Werkzeug aus Metall). Zonen-Claim bleibt bei Stein (deckt sich
# mit der alten Mauer-Preisklasse). Beträge unverändert zur alten
# "materials"-Fassung, nur auf die passende Art umgehängt.
const ZONE_CLAIM_COST := {"stone": 15}
const GUARD_POST_COST := {"wood": 30}
const WALL_COST := {"stone": 15}
const GATE_COST := {"metal": 20}
const MEDICAL_STATION_COST := {"brick": 25}
const WORKSHOP_COST := {"metal": 25}
# Schlafraum/Betten (siehe docs/survivor.md, "Müdigkeit" — Punkt 16 der
# Gesamtliste) — gleiches Muster wie Krankenstation/Werkstatt, ein
# thematisch passender Rohstoff (Holz statt der Vision-Angabe "Holz +
# Baumaterial", da es "Baumaterial" als generische Ressource in diesem
# System nicht mehr gibt, siehe docs/base.md, "Vier Baurohstoffe").
const BED_COST := {"wood": 20}
# Feld (siehe docs/building.md, "Felder") — produziert passiv Nahrung,
# Kosten in Holz statt Stein/Metall/Ziegel (keiner der drei Bau-Rohstoffe
# ist thematisch treffend für ein Feld, Holz für den Zaun/die Umrandung).
const FIELD_COST := {"wood": 20}
# Lager (siehe docs/building.md, "Lager") — Holz als Hauptmaterial laut
# Vision-Dokument (Infos/03 Asset-Checkliste.md: "8× Holz + 3×
# Stahlrahmen"), Stahlrahmen gibt's in diesem Ressourcensystem nicht,
# deshalb vereinfacht rein Holz.
const STORAGE_COST := {"wood": 30}
# Außenposten (siehe Infos/01 Architektur.md, "Außenposten": "5× Holz + 3×
# Baumaterial", Infos/02 Item-Liste.md) — "Baumaterial" gibt es in diesem
# Ressourcensystem nicht als eigene Art, auf Stein umgehängt (gleiche
# Preisklasse wie Mauer/Zonen-Claim, die auch schon "Baumaterial" auf Stein
# abbilden). Betrag moderat verdoppelt (statt 5/3 direkt zu übernehmen) —
# die Vision-Beträge sind für das dortige größere Ressourcensystem
# kalibriert, nicht 1:1 auf dieses schlankere übertragbar.
const OUTPOST_COST := {"wood": 15, "stone": 10}
# Lager-Kapazität aus dem Volumen (Breite×Höhe×Tiefe) des ausgebauten
# Gebäudes berechnet (siehe docs/building.md, "Lager") — an
# Infos/03 Asset-Checkliste.md kalibriert: ein "Wohnhaus" (~500 m³) soll
# grob 500 Kapazität geben, ein "Hochhaus"/eine "alte Schule" (~1000 m³)
# grob 1000. Die aktuellen Platzhalter-Gebäude sind mit ~14–23 m³ VIEL
# kleiner als echte Gebäude aus der Vision (reine Platzhalter-Boxen), der
# Faktor ist deshalb entsprechend hochskaliert, damit einzelne Lager schon
# jetzt sinnvolle Werte (~550–920) liefern. Sobald echte, größenmäßig
# unterschiedliche Gebäude-Assets die Platzhalter ersetzen, MUSS dieser
# Faktor neu kalibriert werden.
const STORAGE_CAPACITY_PER_VOLUME := 40.0
# Rabatt auf ALLE anderen Bautypen, solange der Spieler eine eigene
# Werkstatt besitzt (siehe docs/building.md, "Werkstatt") — gilt nicht auf
# die Werkstatt selbst (keine Kettenreaktion beim Bau der ersten).
const WORKSHOP_DISCOUNT := 0.8
# Crafting-System, Stufe 1 (siehe docs/building.md, "Herstellen" — Punkt 12
# der Gesamtliste). Wichtige Abgrenzung wie beim Waffen-/Rüstungssystem:
# nicht die volle Vision (Infos/02 Item-Liste.md: viele Rezeptstufen,
# Waffen-Mods, Slots), sondern fünf feste Rezepte, alle sofort verfügbar
# (kein Forschungsbücher-Gate, das ist Punkt 13, ein eigener Listenpunkt).
# Verwandelt die bisher rein passive Werkstatt (nur WORKSHOP_DISCOUNT) in
# eine echte Herstellungs-Station — kostet Basis-Rohstoffe (Holz/Metall/
# Stein), erzeugt genau die Ausrüstungsgegenstände, die bisher NUR über
# Zombie-Loot-RNG erreichbar waren (Waffe/Rüstung/Helm/Munition), als
# verlässliche Alternative zum Glück beim Zombie-Kill. Beträge grob an den
# jeweiligen Zombie-Loot-Mengen orientiert, keine echte Balancing-Analyse
# (wie bei den meisten anderen Kosten in diesem Projekt). Rucksack-Rezept
# wieder entfernt (siehe docs/survivor.md, "Rucksack") — kein Item mehr.
const CRAFTING_RECIPES: Array[Dictionary] = [
	{"id": "weapon", "name": "Waffe", "cost": {"metal": 15, "wood": 10}, "yield": {"weapon": 1}},
	{"id": "armor", "name": "Rüstung", "cost": {"metal": 20, "stone": 10}, "yield": {"armor": 1}},
	{"id": "helmet", "name": "Helm", "cost": {"metal": 10, "stone": 5}, "yield": {"helmet": 1}},
	{"id": "ammo", "name": "Munition", "cost": {"metal": 10}, "yield": {"ammo": 15}},
]
const BUILD_MODE_ACTIVE_TEXT := "Baumodus aktiv — in die Welt klicken"
# Deutsche Anzeigenamen für HUD/Ressourcen-Panel/Bau-Buttons — ein Ort für
# alle Ressourcenarten statt verstreuter Einzel-Strings, siehe
# docs/base.md, "Vier Baurohstoffe". Reihenfolge = Anzeigereihenfolge im
# Ressourcen-Panel (_update_resources_label()).
const RESOURCE_DISPLAY_NAMES := {
	"food": "Nahrung",
	"wood": "Holz",
	"metal": "Metall",
	"stone": "Stein",
	"brick": "Ziegel",
	"medicine": "Medizin",
	"ammo": "Munition",
	"weapon": "Waffen",
	"armor": "Rüstung",
	"helmet": "Helm",
	"melee_weapon": "Nahkampfwaffen",
	"leg_armor": "Beinschutz",
	"book_weapon": "Buch: Waffenbau",
	"book_armor": "Buch: Rüstungsbau",
	"book_helmet": "Buch: Helmbau",
	"book_ammo": "Buch: Munitionsherstellung",
}
# Ressourcen-Panel in Kategorien unterteilt (2026-08-01, Nutzerwunsch nach
# dem UI-Overhaul: "rechts die Ressourcen sind ein bisschen zu viele") —
# 16 Arten in einer einzigen Liste war unübersichtlich geworden. Reine
# Anzeige-Gruppierung, keine neue Spielmechanik (siehe docs/world.md,
# "Ressourcen-Panel kategorisiert" — Nutzer wollte eine mögliche Holz→
# Holzplanken-Veredelungsstufe bewusst separat/später besprechen, nicht
# Teil hiervon). Jede Kategorie bekommt ein eigenes Label
# (_update_resources_label()), Reihenfolge der Keys = Anzeigereihenfolge
# innerhalb der Kategorie.
const RESOURCE_CATEGORIES: Array[Dictionary] = [
	{"name": "Baurohstoffe", "keys": ["wood", "metal", "stone", "brick"]},
	{"name": "Überleben", "keys": ["food", "medicine", "ammo"]},
	{"name": "Ausrüstung", "keys": ["weapon", "armor", "helmet", "melee_weapon", "leg_armor"]},
	{"name": "Forschungsbücher", "keys": ["book_weapon", "book_armor", "book_helmet", "book_ammo"]},
]
# Farben fürs Platzierungs-Preview (BuildGhost) — grün bei gültigem
# Bauplatz (Radius + Ressourcen reichen), sonst rot. Alpha < 1, damit
# darunterliegender Boden/Gebäude durchscheint.
const BUILD_GHOST_VALID_COLOR := Color(0.2, 0.9, 0.2, 0.45)
const BUILD_GHOST_INVALID_COLOR := Color(0.9, 0.2, 0.2, 0.45)
# Geometrie für Mauer/Tor-Ghost — deckt sich mit Wall.tscn/Gate.tscn
# (BoxMesh 2×2×0.4). Wachposten-Ghost nutzt stattdessen die schon in
# World.tscn hinterlegte BoxMesh (1.5³, siehe $BuildGhost), wird in
# _ready() übernommen statt hier dupliziert.
const WALL_GHOST_SIZE := Vector3(2, 2, 0.4)
# Deckt sich mit WALL_GHOST_SIZE.x — Abstand zwischen gezogenen
# Mauer-/Tor-Segmenten, damit sie lückenlos aneinander anschließen (siehe
# docs/walls.md, "Ziehen").
const WALL_SEGMENT_LENGTH := 2.0
# Snap fürs Mauer-/Tor-Ziehen (siehe docs/walls.md, "Snap"): Zugrichtung
# rastet auf 45°-Schritte (8 Richtungen) ein, der Startpunkt entweder ans
# nächste Ende einer bestehenden Mauer (Umkreis WALL_SNAP_ENDPOINT_RADIUS)
# oder, falls keins in der Nähe, auf ein WALL_SEGMENT_LENGTH-Raster.
const WALL_SNAP_ANGLE := PI / 4.0
# Radius, in dem ein Mauerende den Startpunkt eines neuen Zugs magnetisch
# anzieht — die Hälfte von WALL_SEGMENT_LENGTH, damit nur "wirklich nah
# dran" snappt, nicht schon der ganze Weg zum Nachbarsegment.
const WALL_SNAP_ENDPOINT_RADIUS := 1.0

@onready var pivot: Node3D = $Pivot
@onready var camera: Camera3D = $Pivot/Camera3D
@onready var ground_mesh_instance: MeshInstance3D = $Ground/Mesh
@onready var ground_collision: CollisionShape3D = $Ground/Collision
@onready var directional_light: DirectionalLight3D = $DirectionalLight3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var hud_label: Label = $HUD/Label
@onready var status_label: Label = $HUD/StatusLabel
@onready var base_choice_label: Label = $HUD/BaseChoiceLabel
# Kategorisiertes Ressourcen-Panel (siehe RESOURCE_CATEGORIES oben) — ein
# Label pro Kategorie statt einer einzigen Liste mit allen 16 Arten.
# UI-Übersichtlichkeit (2026-08-03, Nutzerwunsch "UI überarbeiten... dass
# es übersichtlicher ist") — die vier Kategorien liefen vorher als ein
# Dauer-Block untereinander, jetzt in zwei Tabs aufgeteilt
# ("Rohstoffe" = Baurohstoffe+Forschungsbücher, "Ausrüstung" = Überleben+
# Ausrüstung), genau der schon länger zurückgestellte Nutzerwunsch aus
# `docs/world.md`, "Ressourcen-Panel kategorisiert" ("sinnvoller wäre in
# zwei unterschiedliche tabs"). Reihenfolge hier bleibt 1:1 zu
# RESOURCE_CATEGORIES, nur die .tscn-Pfade zeigen jetzt in die
# TabContainer-Unterordner statt direkt in die VBoxContainer.
@onready var resource_category_labels: Array = [
	$ResourcesUI/Panel/VBoxContainer/TabContainer/Rohstoffe/BuildResourcesLabel,
	$ResourcesUI/Panel/VBoxContainer/TabContainer/Ausrüstung/SurvivalResourcesLabel,
	$ResourcesUI/Panel/VBoxContainer/TabContainer/Ausrüstung/GearResourcesLabel,
	$ResourcesUI/Panel/VBoxContainer/TabContainer/Rohstoffe/BooksResourcesLabel,
]
@onready var clock_label: Label = $ResourcesUI/Panel/VBoxContainer/ClockLabel
@onready var zombie_count_label: Label = $ResourcesUI/Panel/VBoxContainer/ZombieCountLabel
@onready var survivor_spawner: MultiplayerSpawner = $SurvivorSpawner
@onready var survivors_container: Node3D = $Survivors
@onready var home_base_spawner: MultiplayerSpawner = $HomeBaseSpawner
@onready var home_bases_container: Node3D = $HomeBases
@onready var zombie_spawner: MultiplayerSpawner = $ZombieSpawner
@onready var zombies_container: Node3D = $Zombies
@onready var guard_post_spawner: MultiplayerSpawner = $GuardPostSpawner
@onready var guard_posts_container: Node3D = $GuardPosts
@onready var wall_spawner: MultiplayerSpawner = $WallSpawner
@onready var walls_container: Node3D = $Walls
@onready var medical_station_spawner: MultiplayerSpawner = $MedicalStationSpawner
@onready var medical_stations_container: Node3D = $MedicalStations
@onready var bed_spawner: MultiplayerSpawner = $BedSpawner
@onready var beds_container: Node3D = $Beds
@onready var workshop_spawner: MultiplayerSpawner = $WorkshopSpawner
@onready var workshops_container: Node3D = $Workshops
@onready var storage_spawner: MultiplayerSpawner = $StorageSpawner
@onready var storages_container: Node3D = $Storages
@onready var tree_spawner: MultiplayerSpawner = $TreeSpawner
@onready var trees_container: Node3D = $Trees
@onready var car_wreck_spawner: MultiplayerSpawner = $CarWreckSpawner
@onready var car_wrecks_container: Node3D = $CarWrecks
@onready var stone_pile_spawner: MultiplayerSpawner = $StonePileSpawner
@onready var stone_piles_container: Node3D = $StonePiles
@onready var brick_pile_spawner: MultiplayerSpawner = $BrickPileSpawner
@onready var brick_piles_container: Node3D = $BrickPiles
@onready var field_spawner: MultiplayerSpawner = $FieldSpawner
@onready var fields_container: Node3D = $Fields
@onready var outpost_spawner: MultiplayerSpawner = $OutpostSpawner
@onready var outposts_container: Node3D = $Outposts
# Seit dem Kartenumbau (siehe docs/world.md, "Kartengröße") sind Gebäude/
# Fahrzeuge/Zombie-Nester Spawner-Entities wie alles andere, keine festen
# .tscn-Kind-Nodes mehr.
@onready var building_spawner: MultiplayerSpawner = $BuildingSpawner
@onready var buildings_container: Node3D = $Buildings
# Straßen-Geometrie (siehe docs/world.md, "Straßen-Geometrie") — bewusst
# KEIN MultiplayerSpawner: rein lokale, deterministische Sicht-Meshes ohne
# Collision, jeder Peer baut sie selbst aus den (per RPC verteilten)
# Zonen-Zentren nach, siehe _build_street_visuals().
@onready var street_grid_map: GridMap = $StreetGridMap
@onready var vehicle_spawner: MultiplayerSpawner = $VehicleSpawner
@onready var vehicles_container: Node3D = $Vehicles
@onready var zombie_nest_spawner: MultiplayerSpawner = $ZombieNestSpawner
@onready var zombie_nests_container: Node3D = $ZombieNests
# UI-Overhaul (2026-08-01) — Bauen/Herstellen/Einheiten liefen vorher als
# drei separate CanvasLayer-Panels in je einer eigenen Bildschirmecke
# ("alle vier Bildschirmecken sind schon belegt" war an mehreren Stellen
# im Code kommentiert, siehe docs/world.md, "UI-Overhaul"). Jetzt EIN
# Panel (`MainTabsUI`) mit `TabContainer` — jeder alte Panel-Inhalt ist
# jetzt ein Tab (`Bauen`/`Herstellen`/`Einheiten`) statt eines eigenen
# Panels. Macht auch für künftige UI-lastige Features (Handel etc.) sofort
# einen Platz frei, ohne wieder eine neue Ecke suchen zu müssen.
@onready var main_tabs: TabContainer = $MainTabsUI/Panel/TabContainer
@onready var build_button: Button = $MainTabsUI/Panel/TabContainer/Bauen/BuildButton
@onready var wall_button: Button = $MainTabsUI/Panel/TabContainer/Bauen/WallButton
@onready var gate_button: Button = $MainTabsUI/Panel/TabContainer/Bauen/GateButton
@onready var field_button: Button = $MainTabsUI/Panel/TabContainer/Bauen/FieldButton
@onready var outpost_button: Button = $MainTabsUI/Panel/TabContainer/Bauen/OutpostButton
@onready var build_ghost: MeshInstance3D = $BuildGhost
@onready var build_ghost_line: Node3D = $BuildGhostLine
@onready var workers_list: VBoxContainer = $MainTabsUI/Panel/TabContainer/Bauen/WorkersList
# Ausbauen (siehe docs/building.md, "Ausbauen") — eigener Abschnitt im
# "Bauen"-Tab statt eines eigenen Panels, sichtbar nur wenn eine eigene
# geclaimte Gebäude-Zone ausgewählt ist (_selected_claimed_building).
@onready var upgrade_separator: HSeparator = $MainTabsUI/Panel/TabContainer/Bauen/UpgradeSeparator
@onready var upgrade_label: Label = $MainTabsUI/Panel/TabContainer/Bauen/UpgradeLabel
@onready var upgrade_medical_button: Button = $MainTabsUI/Panel/TabContainer/Bauen/UpgradeMedicalButton
@onready var upgrade_workshop_button: Button = $MainTabsUI/Panel/TabContainer/Bauen/UpgradeWorkshopButton
@onready var upgrade_storage_button: Button = $MainTabsUI/Panel/TabContainer/Bauen/UpgradeStorageButton
@onready var upgrade_bed_button: Button = $MainTabsUI/Panel/TabContainer/Bauen/UpgradeBedButton
@onready var units_list: VBoxContainer = $MainTabsUI/Panel/TabContainer/Einheiten/UnitsList
# Herstellen (siehe docs/building.md, "Herstellen" — Punkt 12 der
# Gesamtliste) — jetzt der "Herstellen"-Tab statt eines eigenen Panels.
# Sichtbar/unsichtbar heißt hier: der TAB wird bei fehlender Werkstatt
# ausgeblendet (siehe _refresh_crafting_ui(), TabContainer.set_tab_hidden()),
# nicht mehr ein ganzes CanvasLayer.
@onready var crafting_tab: Control = $MainTabsUI/Panel/TabContainer/Herstellen
@onready var crafting_recipe_list: VBoxContainer = $MainTabsUI/Panel/TabContainer/Herstellen/RecipeList
# Handel (siehe docs/trading.md — Punkt 14 der Gesamtliste): Schenken
# (sofortige einseitige Übergabe) UND echtes Tausch-Angebot (Annehmen/
# Ablehnen nötig) in einem gemeinsamen Tab, ein einziges Ziel-Spieler-
# Dropdown für beide Abschnitte.
@onready var trade_peer_option: OptionButton = $MainTabsUI/Panel/TabContainer/Handel/PeerOption
@onready var trade_gift_resource_option: OptionButton = $MainTabsUI/Panel/TabContainer/Handel/GiftRow/GiftResourceOption
@onready var trade_gift_amount_spinbox: SpinBox = $MainTabsUI/Panel/TabContainer/Handel/GiftRow/GiftAmountSpinBox
@onready var trade_gift_button: Button = $MainTabsUI/Panel/TabContainer/Handel/GiftRow/GiftButton
@onready var trade_offer_resource_option: OptionButton = $MainTabsUI/Panel/TabContainer/Handel/TradeOfferRow/TradeOfferResourceOption
@onready var trade_offer_amount_spinbox: SpinBox = $MainTabsUI/Panel/TabContainer/Handel/TradeOfferRow/TradeOfferAmountSpinBox
@onready var trade_want_resource_option: OptionButton = $MainTabsUI/Panel/TabContainer/Handel/TradeWantRow/TradeWantResourceOption
@onready var trade_want_amount_spinbox: SpinBox = $MainTabsUI/Panel/TabContainer/Handel/TradeWantRow/TradeWantAmountSpinBox
@onready var trade_offer_button: Button = $MainTabsUI/Panel/TabContainer/Handel/TradeOfferButton
@onready var trade_offers_list: VBoxContainer = $MainTabsUI/Panel/TabContainer/Handel/OffersList
@onready var pause_menu: Node = $PauseMenu
# Vollbild-Kartenansicht (siehe docs/world.md, "Kartenansicht" — Punkt 11
# der Gesamtliste), eigene Taste (KEY_M) statt automatisch bei ZOOM_MAX.
@onready var map_view_ui: CanvasLayer = $MapViewUI
# Trupp-Detailfenster (siehe docs/survivor.md, "Rüstungssystem") — seit
# 2026-08-03 ein Tab ("Trupp") im gemeinsamen MainTabsUI-TabContainer statt
# eines eigenen, frei positionierten CanvasLayer (Nutzer-Report: "die ui
# sind übereinander das truppen ui und alles andere" — bei kleineren
# Fensterhöhen überlappte das feste, oben-links verankerte Panel mit dem
# unten-links verankerten MainTabsUI-Panel; als Tab im selben TabContainer
# ist Überlappung strukturell ausgeschlossen). Gleiches Ausblend-Muster wie
# `crafting_tab`/`set_tab_hidden()` statt eines eigenen `visible`-Togglens
# auf CanvasLayer-Ebene.
@onready var unit_detail_tab: Control = $MainTabsUI/Panel/TabContainer/Trupp
@onready var unit_detail_stats_label: Label = $MainTabsUI/Panel/TabContainer/Trupp/StatsLabel
@onready var unit_detail_weapon_label: Label = $MainTabsUI/Panel/TabContainer/Trupp/WeaponRow/WeaponStatusLabel
@onready var unit_detail_weapon_button: Button = $MainTabsUI/Panel/TabContainer/Trupp/WeaponRow/WeaponButton
@onready var unit_detail_armor_label: Label = $MainTabsUI/Panel/TabContainer/Trupp/ArmorRow/ArmorStatusLabel
@onready var unit_detail_armor_button: Button = $MainTabsUI/Panel/TabContainer/Trupp/ArmorRow/ArmorButton
@onready var unit_detail_helmet_label: Label = $MainTabsUI/Panel/TabContainer/Trupp/HelmetRow/HelmetStatusLabel
@onready var unit_detail_helmet_button: Button = $MainTabsUI/Panel/TabContainer/Trupp/HelmetRow/HelmetButton
@onready var unit_detail_secondary_weapon_label: Label = $MainTabsUI/Panel/TabContainer/Trupp/SecondaryWeaponRow/SecondaryWeaponStatusLabel
@onready var unit_detail_secondary_weapon_button: Button = $MainTabsUI/Panel/TabContainer/Trupp/SecondaryWeaponRow/SecondaryWeaponButton
@onready var unit_detail_leg_armor_label: Label = $MainTabsUI/Panel/TabContainer/Trupp/LegArmorRow/LegArmorStatusLabel
@onready var unit_detail_leg_armor_button: Button = $MainTabsUI/Panel/TabContainer/Trupp/LegArmorRow/LegArmorButton
@onready var select_group_buttons: Array = [
	$MainTabsUI/Panel/TabContainer/Einheiten/GroupRow/SelectGroup1Button,
	$MainTabsUI/Panel/TabContainer/Einheiten/GroupRow/SelectGroup2Button,
	$MainTabsUI/Panel/TabContainer/Einheiten/GroupRow/SelectGroup3Button,
]

var _zoom_distance: float = 12.0
var _tilt_angle: float = 0.5404
var _rotating: bool = false
var _right_click_dragged: bool = false
var selected: Array = []
# Ausbauen (siehe docs/building.md, "Ausbauen") — Klick auf ein eigenes,
# bereits geclaimtes Gebäude setzt das statt eines Trupp-Befehls; steuert
# Sichtbarkeit/Inhalt des Ausbauen-Abschnitts im "Bauen"-Tab.
var _selected_claimed_building: Node3D = null
# Trupp-Detailfenster (siehe docs/survivor.md, "Rüstungssystem") — welcher
# Survivor gerade im "Trupp"-Tab angezeigt wird, damit die dort fest
# verdrahteten Buttons (kein Neu-Erzeugen pro Refresh) wissen, wen sie
# betreffen, statt bei jedem Refresh neu verbunden werden zu müssen.
var _unit_detail_survivor: Node3D = null
var _control_groups: Dictionary = {}  # int (1-9) -> Array eigener Einheiten
var _next_survivor_id: int = 0
# Eigener Zähler für vom Zombie-Nest nachgespawnte Zombies (siehe
# docs/zombies.md, "Zombie-Nest") — startet hinter CITY_ZONE_COUNT *
# ZOMBIES_PER_ZONE, damit Namen nie mit den initial pro Zone gespawnten
# Start-Zombies kollidieren.
var _next_nest_zombie_id: int = CITY_ZONE_COUNT * ZOMBIES_PER_ZONE
# Zonen-Zentren aus der Welt-Generierung (siehe _generate_world()) —
# gebraucht für den Horde-Nacht-Fallback ohne lebendes Ziel (siehe
# _trigger_horde_night()) und die Wildnis-Ressourcenverteilung (siehe
# _spawn_wilderness_resources(), Abstand zu Stadt-Zonen).
var _city_zone_centers: Array[Vector3] = []
var _next_tree_id: int = 0
var _next_car_wreck_id: int = 0
var _next_stone_pile_id: int = 0
var _next_brick_pile_id: int = 0
var _next_guard_post_id: int = 0
var _next_wall_id: int = 0
var _next_medical_station_id: int = 0
var _next_bed_id: int = 0
var _next_workshop_id: int = 0
var _next_storage_id: int = 0
var _next_field_id: int = 0
var _next_outpost_id: int = 0
# Seit dem Kartenumbau (siehe docs/world.md, "Kartengröße") sind Gebäude/
# Fahrzeuge/Zombie-Nester Spawner-Entities wie alles andere (vorher feste
# .tscn-Kind-Nodes, keine eigene ID nötig).
var _next_building_id: int = 0
var _next_vehicle_id: int = 0
var _next_zombie_nest_id: int = 0
# Handel (siehe docs/trading.md) — nur der Host führt Buch (_trade_offers
# ist die Quelle der Wahrheit dort), an alle Peers per _sync_trade_offers()
# gespiegelt, gleiches Broadcast-Muster wie andere geteilte, aber nicht an
# einen einzelnen gespawnten Node gebundene Zustände. Bewusst KEIN
# Catch-up für spät beitretende Peers und KEINE Persistenz in
# _collect_save_data()/_load_game_state() — offene Angebote sind ein
# kurzlebiger Zwischenzustand, gleiche Vereinfachung wie bei
# HomeBase.unlocked_recipes' fehlendem Catch-up (siehe docs/base.md,
# "Bekannte Grenzen").
var _trade_offers: Array = []
var _next_trade_offer_id: int = 1
# Nur neu aufbauen, wenn sich NetworkManager.players wirklich geändert hat
# (sonst würde die laufende Dropdown-Auswahl des Nutzers alle
# WORKER_UI_REFRESH_INTERVAL Sekunden zurückgesetzt).
var _trade_peer_ids_cache: Array = []
var _build_mode: bool = false
var _build_type: BuildType = BuildType.GUARD_POST
var _worker_ui_timer: float = 0.0
# Tag/Nacht-Zyklus (siehe NIGHT_START_HOUR/NIGHT_END_HOUR oben) — läuft lokal auf
# jedem Peer, siehe _handle_day_night(). Startet bei 62.5s = 05:00 Uhr
# (5/24*CYCLE_LENGTH, Nutzerwunsch) statt 00:00 — gilt nur für den
# Frisch-Start, ein geladener Spielstand überschreibt das ohnehin sofort
# mit dem gespeicherten Wert (siehe _load_game_state()).
var _day_time: float = 62.5
var _horde_triggered_this_night: bool = false
const WORKER_UI_REFRESH_INTERVAL := 0.5
const GROUP_UI_COUNT := 3
# Feedback bei fehlgeschlagenen Aktionen (Bauen/Arbeiter anfordern, siehe
# _report_build_failure()) — kurze Einblendung statt stiller Ablehnung.
const STATUS_MESSAGE_DURATION := 2.5
var _status_message_timer: float = 0.0
var _guard_post_ghost_mesh: BoxMesh
var _wall_ghost_mesh: BoxMesh
# Ziehen mehrerer Mauer-/Tor-Segmente in einem Zug statt Einzelklicks (siehe
# docs/walls.md, "Ziehen") — _wall_drag_start ist der Weltpunkt vom
# Maus-Runterdrücken, _ghost_line_meshes ein wiederverwendeter Pool von
# Ghost-Würfeln (Anzahl schwankt live während des Ziehens).
var _wall_drag_active: bool = false
var _wall_drag_start: Vector3 = Vector3.ZERO
var _ghost_line_meshes: Array = []


func _ready() -> void:
	_apply_zoom()
	# Einzige Quelle der Wahrheit für die Kartengröße (siehe MAP_SIZE oben) —
	# setzt die tatsächliche Boden-Mesh-/Collision-Größe aus der Konstante,
	# statt sie zusätzlich fest im .tscn zu duplizieren.
	(ground_mesh_instance.mesh as BoxMesh).size = Vector3(MAP_SIZE, 0.2, MAP_SIZE)
	(ground_collision.shape as BoxShape3D).size = Vector3(MAP_SIZE, 0.2, MAP_SIZE)
	survivor_spawner.spawn_function = _create_survivor
	home_base_spawner.spawn_function = _create_home_base
	zombie_spawner.spawn_function = _create_zombie
	guard_post_spawner.spawn_function = _create_guard_post
	wall_spawner.spawn_function = _create_wall
	medical_station_spawner.spawn_function = _create_medical_station
	bed_spawner.spawn_function = _create_bed
	workshop_spawner.spawn_function = _create_workshop
	storage_spawner.spawn_function = _create_storage
	tree_spawner.spawn_function = _create_tree
	car_wreck_spawner.spawn_function = _create_car_wreck
	stone_pile_spawner.spawn_function = _create_stone_pile
	brick_pile_spawner.spawn_function = _create_brick_pile
	field_spawner.spawn_function = _create_field
	outpost_spawner.spawn_function = _create_outpost
	building_spawner.spawn_function = _create_building
	vehicle_spawner.spawn_function = _create_vehicle
	zombie_nest_spawner.spawn_function = _create_zombie_nest
	build_button.pressed.connect(_on_toggle_build_mode_pressed.bind(BuildType.GUARD_POST))
	wall_button.pressed.connect(_on_toggle_build_mode_pressed.bind(BuildType.WALL))
	gate_button.pressed.connect(_on_toggle_build_mode_pressed.bind(BuildType.GATE))
	field_button.pressed.connect(_on_toggle_build_mode_pressed.bind(BuildType.FIELD))
	outpost_button.pressed.connect(_on_toggle_build_mode_pressed.bind(BuildType.OUTPOST))
	upgrade_medical_button.pressed.connect(_on_upgrade_building_pressed.bind(BuildType.MEDICAL_STATION))
	upgrade_workshop_button.pressed.connect(_on_upgrade_building_pressed.bind(BuildType.WORKSHOP))
	upgrade_storage_button.pressed.connect(_on_upgrade_building_pressed.bind(BuildType.STORAGE))
	upgrade_bed_button.pressed.connect(_on_upgrade_building_pressed.bind(BuildType.BED))
	unit_detail_weapon_button.pressed.connect(_on_detail_equip_weapon_pressed)
	unit_detail_armor_button.pressed.connect(_on_detail_equip_armor_pressed)
	unit_detail_helmet_button.pressed.connect(_on_detail_equip_helmet_pressed)
	unit_detail_secondary_weapon_button.pressed.connect(_on_detail_equip_secondary_weapon_pressed)
	unit_detail_leg_armor_button.pressed.connect(_on_detail_equip_leg_armor_pressed)
	trade_gift_button.pressed.connect(_on_gift_pressed)
	trade_offer_button.pressed.connect(_on_trade_offer_pressed)
	# Ressourcenarten ändern sich nie zur Laufzeit (RESOURCE_DISPLAY_NAMES ist
	# eine const) — einmalig befüllen statt bei jedem UI-Refresh neu, anders
	# als das Ziel-Spieler-Dropdown (siehe _refresh_trade_ui()).
	_populate_resource_option(trade_gift_resource_option)
	_populate_resource_option(trade_offer_resource_option)
	_populate_resource_option(trade_want_resource_option)
	# Wachposten-Ghost übernimmt die schon in World.tscn hinterlegte BoxMesh
	# (1.5³) von $BuildGhost, Mauer/Tor-Ghost wird dynamisch erzeugt (siehe
	# WALL_GHOST_SIZE) — beide werden in _update_build_ghost() je nach
	# _build_type eingesetzt.
	_guard_post_ghost_mesh = build_ghost.mesh
	_wall_ghost_mesh = BoxMesh.new()
	_wall_ghost_mesh.size = WALL_GHOST_SIZE
	for i in select_group_buttons.size():
		select_group_buttons[i].pressed.connect(_handle_control_group_key.bind(i + 1, false))
	# Kein eigener Lobby-Flow hier — Host/Join/Spielerliste/Start laufen
	# schon vorher über die echte scenes/lobby/Lobby.tscn (docs/networking.md).
	# Diese Szene wird erst betreten, NACHDEM der Host dort "Spiel starten"
	# gedrückt hat, also sind zu diesem Zeitpunkt alle mitspielenden Peers
	# schon in NetworkManager.players bekannt.
	NetworkManager.player_connected.connect(_on_player_connected)
	if multiplayer.is_server():
		# Geladener Spielstand (siehe docs/save_load.md, MainMenu._on_load_pressed())
		# ersetzt den normalen Frisch-Start komplett — beide Zweige erzeugen
		# Home-Bases/Survivor/Zombies/Ressourcen, nur einmal frisch generiert,
		# einmal aus der Save-Datei rekonstruiert.
		if not SaveManager.pending_load.is_empty():
			_load_game_state(SaveManager.pending_load)
			SaveManager.pending_load = {}
		else:
			_spawn_all_players()
			_generate_world()
		# Host hat _city_zone_centers jetzt garantiert vollständig — baut die
		# eigenen Straßen-Meshes direkt, kein RPC-Umweg nötig (siehe unten,
		# request_city_zones() für den Client-Weg).
		_build_street_visuals()
	else:
		# PULL statt PUSH (Bugfix 2026-08-01: ein reiner Host-seitiger Push
		# direkt in _ready() kam bei einem Client zu früh an — dessen
		# World-Node existierte zu dem Zeitpunkt im Netzwerk-Baum noch nicht,
		# das RPC-Paket ging spurlos verloren, siehe docs/world.md,
		# "Straßen-Geometrie"). Der Client fragt stattdessen selbst beim
		# Host an, garantiert erst NACHDEM sein eigenes _ready() läuft —
		# funktioniert dadurch gleichermaßen beim normalen Partie-Start UND
		# bei einem spät beitretenden Peer, ganz ohne eigenen Sonderfall.
		request_city_zones.rpc_id(1)


func _spawn_all_players() -> void:
	for peer_id in NetworkManager.players.keys():
		_spawn_for_peer(peer_id)


func _handle_day_night(delta: float) -> void:
	# Läuft auf JEDEM Peer (Beleuchtung/Anzeige müssen lokal überall
	# stimmen) — nur der Horde-Trigger selbst ist host-gated, siehe unten.
	_day_time += delta
	if _day_time >= CYCLE_LENGTH:
		_day_time -= CYCLE_LENGTH
		_horde_triggered_this_night = false
		_day_count += 1
	_update_day_night_visuals()
	_update_clock_label()
	if multiplayer.is_server() and is_night() and not _horde_triggered_this_night:
		_horde_triggered_this_night = true
		_trigger_horde_night()


func is_night() -> bool:
	# Öffentlich (nicht nur für Beleuchtung/Horde) — Zombie.gd fragt das
	# ebenfalls ab, um nachts stärker zuzuschlagen (siehe
	# ZOMBIE_NIGHT_DAMAGE_MULTIPLIER dort, docs/zombies.md).
	return _day_time >= NIGHT_START_TIME or _day_time < NIGHT_END_TIME


func is_blood_moon_night() -> bool:
	# _day_count + 1 = 1-indexierte Nacht-Nummer (Nacht des allerersten
	# Tages fällt auf _day_count == 0, also Nacht 1) — jede
	# BLOOD_MOON_INTERVAL_DAYS-te Nacht (5, 10, 15, ...) ist ein Blutmond.
	# Öffentlich, gleiches Zugriffsmuster wie is_night() — Zombie.gd könnte
	# das später ebenfalls abfragen, aktuell nur von hier
	# (_trigger_horde_night()/_update_day_night_visuals()) genutzt.
	return (_day_count + 1) % BLOOD_MOON_INTERVAL_DAYS == 0


func current_game_hour() -> float:
	# 0.0–24.0, reine Anzeige-Ableitung von _day_time (siehe
	# _clock_text()) — ein voller Zyklus (CYCLE_LENGTH) entspricht genau
	# einem 24-Stunden-Spieltag.
	return _day_time / CYCLE_LENGTH * HOURS_PER_DAY


func _clock_text() -> String:
	var total_minutes: int = int(current_game_hour() * 60.0)
	var h: int = (total_minutes / 60) % 24
	var m: int = total_minutes % 60
	var suffix: String = " (Nacht)" if is_night() else ""
	return "%02d:%02d%s" % [h, m, suffix]


func _update_clock_label() -> void:
	clock_label.text = _clock_text()


func _update_fog_of_war() -> void:
	# Läuft auf JEDEM Peer (nicht host-gated) — reiner Lese-Zugriff auf
	# ohnehin schon lokal replizierte Positionen, siehe FOG_*-Konstanten
	# oben. ALLE "living"-Einheiten (Survivor+Fahrzeuge, siehe Zombie.gd-
	# Gruppen-Konvention) UND alle Home-Bases zählen, nicht nur die eigenen
	# — "geteilte Aufklärung" heißt: was IRGENDEIN Spieler aufgedeckt hat,
	# ist für alle aufgedeckt.
	for revealer in get_tree().get_nodes_in_group("living"):
		if is_instance_valid(revealer):
			_reveal_around(revealer.position)
	for base in get_tree().get_nodes_in_group("home_base"):
		if is_instance_valid(base):
			_reveal_around(base.position)


func _reveal_around(world_pos: Vector3) -> void:
	var cell_radius: int = ceili(FOG_VISION_RADIUS / FOG_CELL_SIZE)
	var center_cell := Vector2i(floori(world_pos.x / FOG_CELL_SIZE), floori(world_pos.z / FOG_CELL_SIZE))
	for dx in range(-cell_radius, cell_radius + 1):
		for dz in range(-cell_radius, cell_radius + 1):
			var cell := center_cell + Vector2i(dx, dz)
			if _explored_cells.has(cell):
				continue
			var cell_center := Vector2((cell.x + 0.5) * FOG_CELL_SIZE, (cell.y + 0.5) * FOG_CELL_SIZE)
			if cell_center.distance_to(Vector2(world_pos.x, world_pos.z)) <= FOG_VISION_RADIUS:
				_explored_cells[cell] = true


func is_cell_explored(world_pos: Vector3) -> bool:
	# Öffentlich (kein Unterstrich-Präfix, siehe MAP_SIZE/pivot-Konvention)
	# — von Minimap.gd/MapView.gd über get_tree().current_scene gelesen,
	# gleiches Zugriffsmuster wie dort schon für MAP_SIZE/pivot etabliert.
	var cell := Vector2i(floori(world_pos.x / FOG_CELL_SIZE), floori(world_pos.z / FOG_CELL_SIZE))
	return _explored_cells.has(cell)


func maybe_alert_sos(target: Node3D) -> void:
	# Aufgerufen von Zombie._try_attack() nach jedem erfolgreichen Treffer
	# (siehe dort) — öffentlich, gleiches Cross-Node-Muster wie
	# report_status()/spawn_recruit(). Host-gated, weil Zombie._try_attack()
	# ohnehin nur host-seitig läuft (siehe Zombie._ready()), aber ein
	# zweiter Guard hier schadet nicht und macht die Voraussetzung explizit.
	if not multiplayer.is_server():
		return
	# duck-typed statt has_method("take_damage")-Check — Survivor/Wall/
	# Building/Vehicle haben alle ein owner_peer_id-Feld, target.get(...)
	# liefert null zurück statt eines Laufzeitfehlers, falls doch nicht.
	var victim_peer_id_variant = target.get("owner_peer_id")
	if victim_peer_id_variant == null:
		return
	var victim_peer_id: int = victim_peer_id_variant
	if victim_peer_id == 0:
		# Herrenlos (z. B. eine noch nicht geclaimte Struktur) — niemand,
		# dem geholfen werden könnte.
		return
	var now := Time.get_ticks_msec() / 1000.0
	var last: float = _last_sos_broadcast.get(victim_peer_id, -INF)
	if now - last < SOS_COOLDOWN:
		return
	_last_sos_broadcast[victim_peer_id] = now
	var victim_name: String = NetworkManager.players.get(victim_peer_id, {}).get("name", "Ein Spieler")
	for peer_id in NetworkManager.players.keys():
		if peer_id == victim_peer_id:
			continue
		report_status(peer_id, "%s wird angegriffen! Hilfe gebraucht." % victim_name)
	_sync_sos_alert.rpc(victim_peer_id, target.global_position, SOS_MARKER_DURATION)


@rpc("authority", "call_local", "reliable")
func _sync_sos_alert(victim_peer_id: int, alert_position: Vector3, duration: float) -> void:
	# duration statt eines absoluten Zeitstempels — Time.get_ticks_msec()
	# läuft auf jedem Peer unabhängig seit dessen eigenem Prozessstart,
	# ein vom Host gesendeter absoluter Zeitstempel wäre auf einem Client
	# bedeutungslos. Jeder Peer berechnet seinen eigenen lokalen
	# Ablaufzeitpunkt beim Empfang.
	_sos_alerts[victim_peer_id] = {
		"position": alert_position,
		"expires_at": Time.get_ticks_msec() / 1000.0 + duration,
	}


func active_sos_alerts() -> Array:
	# Öffentlich, von Minimap.gd/MapView.gd gelesen (gleiches Zugriffsmuster
	# wie is_cell_explored()) — filtert abgelaufene Alarme beim Lesen raus,
	# kein eigener Cleanup-Timer nötig (Dictionary bleibt ohnehin klein,
	# siehe _sos_alerts oben).
	var now := Time.get_ticks_msec() / 1000.0
	var active: Array = []
	for victim_peer_id in _sos_alerts:
		var entry: Dictionary = _sos_alerts[victim_peer_id]
		if entry["expires_at"] > now:
			active.append(entry["position"])
	return active


func _update_zombie_count_label() -> void:
	# Benchmark-Anzeige für MAX_ZOMBIES (siehe dort) — läuft gedrosselt über
	# WORKER_UI_REFRESH_INTERVAL statt jeden Frame, da get_nodes_in_group()
	# das Array jedes Mal neu kopiert (Godot-Verhalten), für eine reine
	# Text-Anzeige reicht der gröbere Takt.
	var count: int = get_tree().get_nodes_in_group("zombie").size()
	zombie_count_label.text = "Zombies: %d/%d" % [count, MAX_ZOMBIES]


func _despawn_far_zombies() -> void:
	# Läuft nur alle ZOMBIE_DESPAWN_CHECK_INTERVAL Sekunden (nicht jeden
	# Frame nötig, ohnehin kein zeitkritischer Vorgang) — Kandidatenliste wie
	# Zombie._find_nearest_target() ("living" + geclaimte "searchable"),
	# PLUS "home_base" (jeder Peer hat immer genau eine, siehe docs/base.md
	# — anders als _find_nearest_target() zählt hier auch eine Home-Base
	# ohne Trupps in der Nähe als "hier ist jemand präsent", auch wenn
	# Zombies sie mangels take_damage() nie als Angriffsziel wählen können).
	# Einmal pro Check aufgebaut statt pro Zombie.
	var presence := get_tree().get_nodes_in_group("living")
	presence.append_array(get_tree().get_nodes_in_group("home_base"))
	for building in get_tree().get_nodes_in_group("searchable"):
		if is_instance_valid(building) and building.owner_peer_id != 0:
			presence.append(building)
	if presence.is_empty():
		# Kein Referenzpunkt vorhanden (z. B. kurz nach einem Wipe, bevor
		# irgendjemand wieder spawnt) — dann lieber nichts despawnen statt
		# versehentlich die gesamte Population zu löschen.
		return
	for zombie in get_tree().get_nodes_in_group("zombie"):
		if is_instance_valid(zombie) and _is_far_from_all(zombie.global_position, presence):
			zombie.despawn()


func _is_far_from_all(pos: Vector3, presence: Array) -> bool:
	for entity in presence:
		if is_instance_valid(entity) and pos.distance_to(entity.global_position) <= ZOMBIE_DESPAWN_RADIUS:
			return false
	return true


func _rebuild_zombie_grid(zombies: Array) -> void:
	# Einmal pro Frame komplett neu befüllt (O(z), billig) statt inkrementell
	# gepflegt — Zombies bewegen sich jeden Frame, ein Dirty-Tracking würde
	# hier mehr Komplexität kosten als die simple Neuberfüllung spart. Siehe
	# ZOMBIE_GRID_CELL_SIZE oben. `zombies` wird von _process() übergeben
	# (eine gemeinsame "zombie"-Gruppenabfrage statt einer eigenen hier UND
	# einer zweiten in _sync_zombies_batch(), siehe dort).
	_zombie_grid.clear()
	for zombie in zombies:
		if not is_instance_valid(zombie):
			continue
		var cell := _zombie_grid_cell(zombie.global_position)
		if not _zombie_grid.has(cell):
			_zombie_grid[cell] = []
		_zombie_grid[cell].append(zombie)


func _sync_zombies_batch(zombies: Array) -> void:
	# Performance: Netzwerk-Sync gebündelt statt Einzel-RPC pro Zombie
	# (siehe docs/zombies.md, "Performance: Netzwerk-Sync bündeln" — Punkt 7
	# der Performance-Liste). Ersetzt das frühere `Zombie._sync_state.rpc()`
	# (jeden Frame, einmal PRO Zombie) durch EIN gebündeltes RPC für alle
	# Zombies zusammen — bei 600+ Zombies vorher 600+ einzelne RPC-Dispatches
	# (Argument-Marshalling, Methoden-Lookup, ein Netzwerkpaket pro Aufruf),
	# jetzt einer. Gleiche Solo-Optimierung wie beim vorherigen Fix
	# (`multiplayer.get_peers().is_empty()`) bleibt erhalten — betrifft aber
	# jetzt zusätzlich den echten Multiplayer-Fall (weniger Pakete, nicht
	# nur weniger Aufrufe beim Host selbst).
	if multiplayer.get_peers().is_empty():
		return
	var ids := PackedInt32Array()
	var positions := PackedVector3Array()
	var hps := PackedInt32Array()
	for zombie in zombies:
		if not is_instance_valid(zombie):
			continue
		ids.append(zombie.zombie_id)
		positions.append(zombie.position)
		hps.append(zombie.hp)
	if ids.is_empty():
		return
	_apply_zombie_batch.rpc(ids, positions, hps)


@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_zombie_batch(ids: PackedInt32Array, positions: PackedVector3Array, hps: PackedInt32Array) -> void:
	# "call_remote" statt "call_local" — der Host braucht die eigene
	# Sendung nicht, sein Zustand ist über die direkten Feldzuweisungen in
	# Zombie._process_chase()/_process_wander()/take_damage() längst aktuell
	# (siehe Zombie.apply_synced_state(), nur noch für Remote-Clients
	# gedacht). Zombie-Knoten werden wie beim Catch-up über den Namen
	# gefunden ("zombie_%d" % id, siehe World._create_zombie()).
	for i in ids.size():
		var zombie: Node3D = zombies_container.get_node_or_null("zombie_%d" % ids[i])
		if zombie != null:
			zombie.apply_synced_state(positions[i], hps[i])


func _zombie_grid_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / ZOMBIE_GRID_CELL_SIZE), floori(pos.z / ZOMBIE_GRID_CELL_SIZE))


func zombies_near(pos: Vector3, radius: float) -> Array:
	# Ersetzt die volle "zombie"-Gruppenabfrage in
	# Zombie._alert_nearby_zombies() und
	# GuardPost._find_nearest_zombie()/_alert_nearby_zombies() (siehe
	# ZOMBIE_GRID_CELL_SIZE oben). `radius` muss <= ZOMBIE_GRID_CELL_SIZE
	# bleiben, sonst reicht der 3×3-Ausschnitt nicht mehr aus.
	var result: Array = []
	var center := _zombie_grid_cell(pos)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cell := center + Vector2i(dx, dz)
			if not _zombie_grid.has(cell):
				continue
			for zombie in _zombie_grid[cell]:
				if is_instance_valid(zombie) and pos.distance_to(zombie.global_position) <= radius:
					result.append(zombie)
	return result


func _night_amount() -> float:
	# 0.0 = voller Tag, 1.0 = volle Nacht — sanfter Übergang über
	# DUSK_LENGTH Sekunden vor Nachtbeginn und vor Tagesbeginn statt eines
	# harten Umschaltens (siehe docs/world.md, "Tag/Nacht-Zyklus"). Muss
	# den Mitternachts-Wrap von NIGHT_START_TIME (275s) über das
	# Zyklusende zu NIGHT_END_TIME (50s) mitberechnen, anders als beim
	# alten, nicht wrappenden DAY_LENGTH/NIGHT_LENGTH-Schema.
	if is_night():
		var time_left_in_night: float
		if _day_time >= NIGHT_START_TIME:
			time_left_in_night = (CYCLE_LENGTH - _day_time) + NIGHT_END_TIME
		else:
			time_left_in_night = NIGHT_END_TIME - _day_time
		if time_left_in_night < DUSK_LENGTH:
			return time_left_in_night / DUSK_LENGTH
		return 1.0
	var time_left_in_day: float = NIGHT_START_TIME - _day_time
	if time_left_in_day < DUSK_LENGTH:
		return 1.0 - (time_left_in_day / DUSK_LENGTH)
	return 0.0


func _update_day_night_visuals() -> void:
	var amount: float = _night_amount()
	var light_color: Color = DAY_LIGHT_COLOR.lerp(NIGHT_LIGHT_COLOR, amount)
	var sky_color: Color = DAY_SKY_COLOR.lerp(NIGHT_SKY_COLOR, amount)
	if is_blood_moon_night():
		light_color = light_color.lerp(BLOOD_MOON_LIGHT_COLOR, amount)
		sky_color = sky_color.lerp(BLOOD_MOON_SKY_COLOR, amount)
	directional_light.light_energy = lerp(DAY_LIGHT_ENERGY, NIGHT_LIGHT_ENERGY, amount)
	directional_light.light_color = light_color
	var env: Environment = world_environment.environment
	env.background_color = sky_color
	env.ambient_light_color = sky_color
	env.ambient_light_energy = lerp(DAY_AMBIENT_ENERGY, NIGHT_AMBIENT_ENERGY, amount)


func _trigger_horde_night() -> void:
	# Ausgelöst über _handle_day_night() bei jedem Nachteintritt (siehe
	# docs/zombies.md, "Horde-Nächte") — HORDE_SIZE Zombies, sofort auf ein
	# gemeinsames Ziel alarmiert (statt normal zu wandern) für echten,
	# gebündelten Druck statt nur mehr Wander-Zombies. Warnt vorher alle
	# Spieler. Seit dem Kartenumbau (siehe docs/world.md, "Kartengröße")
	# spawnt die Horde NICHT mehr an einem festen, ggf. weit entfernten
	# Punkt, sondern aus HORDE_APPROACH_DISTANCE Entfernung um das gewählte
	# Ziel selbst — sonst müsste eine Horde auf der 5000×5000-Karte unter
	# Umständen kilometerweit zum eigentlichen Ziel laufen, bevor überhaupt
	# Druck entsteht. Ohne lebendes Ziel (ganz frühes Spiel) fällt der
	# Spawn-Punkt auf ein zufälliges Stadt-Zonen-Zentrum zurück.
	# Blutmond-Eskalation (siehe BLOOD_MOON_INTERVAL_DAYS oben, Punkt 21 der
	# Gesamtliste) — jede Nte Nacht ist deutlich größer/brute-lastiger,
	# eigene Vorwarnung statt der normalen Horde-Nacht-Meldung.
	var blood_moon: bool = is_blood_moon_night()
	var horde_size: int = BLOOD_MOON_HORDE_SIZE if blood_moon else HORDE_SIZE
	var brute_count: int = BLOOD_MOON_BRUTE_COUNT if blood_moon else HORDE_BRUTE_COUNT
	var warning: String = "BLUTMOND! Eine gewaltige Horde formiert sich!" if blood_moon else "Die Nacht bricht an — eine Horde nähert sich!"
	for peer_id in NetworkManager.players.keys():
		report_status(peer_id, warning)
	var target := _random_horde_target()
	var base_point: Vector3
	if target != null:
		var direction := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if direction.length() < 0.01:
			direction = Vector2(1, 0)
		direction = direction.normalized()
		base_point = target.global_position + Vector3(direction.x, 0, direction.y) * HORDE_APPROACH_DISTANCE
	elif not _city_zone_centers.is_empty():
		base_point = _city_zone_centers[randi() % _city_zone_centers.size()]
	else:
		base_point = Vector3.ZERO
	for i in horde_size:
		var is_brute: bool = i < brute_count
		var ground_y: float = ZOMBIE_BRUTE_GROUND_Y if is_brute else ZOMBIE_GROUND_Y
		var offset := Vector3(randf_range(-HORDE_SPAWN_SCATTER, HORDE_SPAWN_SCATTER), 0, randf_range(-HORDE_SPAWN_SCATTER, HORDE_SPAWN_SCATTER))
		var spawn_position := Vector3(base_point.x + offset.x, ground_y, base_point.z + offset.z)
		var zombie := zombie_spawner.spawn({"index": _next_nest_zombie_id, "position": spawn_position, "is_brute": is_brute})
		_next_nest_zombie_id += 1
		if target != null and is_instance_valid(zombie):
			zombie.alert(target)


func _random_horde_target() -> Node3D:
	# Zielt bewusst auf einen lebenden Trupp (Gruppe "living"), NICHT auf
	# eine Home-Base/ein Gebäude — Zombie._try_attack() ruft
	# target.take_damage() auf, das nur Survivor/Wall/Building/Vehicle/
	# ZombieNest implementieren, HomeBase aber nicht. Fällt auf null
	# zurück, falls noch niemand einen Trupp hat (ganz frühes Spiel) — die
	# Horde wandert dann einfach normal.
	var living := get_tree().get_nodes_in_group("living")
	if living.is_empty():
		return null
	return living[randi() % living.size()]


func _debug_spawn_zombies() -> void:
	# Reines Entwickler-Werkzeug zum Benchmarken von MAX_ZOMBIES (siehe
	# dort) — ausgelöst über F9 (siehe _unhandled_input()). Spawnt bewusst
	# UM DIE KAMERA statt an einem Nest/Zonen-Zentrum (man will die
	# Auswirkung direkt sichtbar/spürbar haben) und bewusst OHNE
	# MAX_ZOMBIES-Prüfung (Stresstest soll den Deckel gezielt überschreiten
	# können, anders als das normale Zombie-Nest, siehe spawn_nest_zombie()).
	if not multiplayer.is_server():
		return
	for i in DEBUG_ZOMBIE_SPAWN_COUNT:
		var offset := Vector3(
			randf_range(-DEBUG_ZOMBIE_SPAWN_SCATTER, DEBUG_ZOMBIE_SPAWN_SCATTER),
			0,
			randf_range(-DEBUG_ZOMBIE_SPAWN_SCATTER, DEBUG_ZOMBIE_SPAWN_SCATTER),
		)
		var spawn_position := Vector3(pivot.position.x + offset.x, ZOMBIE_GROUND_Y, pivot.position.z + offset.z)
		zombie_spawner.spawn({"index": _next_nest_zombie_id, "position": spawn_position})
		_next_nest_zombie_id += 1


func _on_player_connected(peer_id: int, _info: Dictionary) -> void:
	# Jeder player_connected, der hier noch ankommt, ist per Definition ein
	# später Beitritt (alle regulären Mitspieler sind schon vor dem
	# Szenen-Wechsel in NetworkManager.players) — deshalb hier immer spawnen,
	# kein "vor/nach Start"-Unterschied wie in der früheren Testszene nötig.
	if not multiplayer.is_server():
		return
	_spawn_for_peer(peer_id)


func _spawn_for_peer(peer_id: int) -> void:
	# Bekannte Godot-Lücke: MultiplayerSpawner repliziert bereits gespawnte
	# Nodes NICHT automatisch an Peers, die erst später beitreten (siehe
	# docs/3d-migration.md) — deshalb hier zuerst alle schon existierenden
	# Survivor/Home-Bases gezielt an genau diesen Peer nachliefern (harmlos
	# redundant, aber ungefährlich dank Guard in den _catch_up_*-Funktionen).
	# Reine Catch-up-Funktion — die eigene Home-Base samt Survivor-Start
	# entsteht seit der Start-Basis-Wahl NICHT mehr automatisch hier, sondern
	# erst über request_choose_start_base(), sobald der Spieler selbst ein
	# Gebäude anklickt (siehe docs/zones.md, "Start-Basis wählen").
	# Zonen-Zentren/Straßen-Meshes brauchen HIER keinen eigenen Catch-up-Ruf
	# — ein spät beitretender Peer fragt sie selbst an, sobald sein eigenes
	# World-Node bereit ist (siehe request_city_zones() in _ready()), genau
	# wie ein Peer beim normalen Partie-Start.
	for existing in survivors_container.get_children():
		_catch_up_survivor.rpc_id(peer_id, existing.trupp_id, existing.owner_peer_id, existing.position)
	for existing in home_bases_container.get_children():
		_catch_up_home_base.rpc_id(peer_id, existing.owner_peer_id, existing.position)
	for existing in zombies_container.get_children():
		_catch_up_zombie.rpc_id(peer_id, existing.zombie_id, existing.position, existing.is_brute)
	for existing in guard_posts_container.get_children():
		_catch_up_guard_post.rpc_id(peer_id, existing.guard_post_id, existing.owner_peer_id, existing.position)
	for existing in walls_container.get_children():
		_catch_up_wall.rpc_id(peer_id, existing.wall_id, existing.owner_peer_id, existing.position, existing.rotation.y, existing.is_gate)
	for existing in medical_stations_container.get_children():
		_catch_up_medical_station.rpc_id(peer_id, existing.medical_station_id, existing.owner_peer_id, existing.position)
	for existing in workshops_container.get_children():
		_catch_up_workshop.rpc_id(peer_id, existing.workshop_id, existing.owner_peer_id, existing.position)
	for existing in storages_container.get_children():
		_catch_up_storage.rpc_id(peer_id, existing.storage_id, existing.owner_peer_id, existing.position)
	for existing in beds_container.get_children():
		_catch_up_bed.rpc_id(peer_id, existing.bed_id, existing.owner_peer_id, existing.position)
	for existing in trees_container.get_children():
		_catch_up_tree.rpc_id(peer_id, existing.tree_id, existing.position)
	for existing in car_wrecks_container.get_children():
		_catch_up_car_wreck.rpc_id(peer_id, existing.wreck_id, existing.position)
	for existing in stone_piles_container.get_children():
		_catch_up_stone_pile.rpc_id(peer_id, existing.pile_id, existing.position)
	for existing in brick_piles_container.get_children():
		_catch_up_brick_pile.rpc_id(peer_id, existing.pile_id, existing.position)
	for existing in fields_container.get_children():
		_catch_up_field.rpc_id(peer_id, existing.field_id, existing.owner_peer_id, existing.position)
	for existing in outposts_container.get_children():
		_catch_up_outpost.rpc_id(peer_id, existing.outpost_id, existing.owner_peer_id, existing.position)
	# Seit dem Kartenumbau (siehe docs/world.md, "Kartengröße") sind auch
	# Buildings/Vehicles/ZombieNests Spawner-Entities (vorher feste
	# .tscn-Kind-Nodes, die jeder Peer automatisch schon lokal hatte, kein
	# Catch-up nötig) — schließt die vorher bekannte, akzeptierte Lücke
	# "kein Catch-up für spät beitretende Peers bzgl. HP/Zerstört-Zustand"
	# für diese drei Typen mit.
	for existing in buildings_container.get_children():
		_catch_up_building.rpc_id(peer_id, {
			"id": existing.building_id,
			"position": existing.position,
			"zone_center": existing.zone_center,
			"size": (existing.get_node("Mesh").mesh as BoxMesh).size,
			"loot": existing.loot,
			"default_color": existing.default_color,
			"has_survivor": existing.has_survivor,
			"is_looted": existing.is_looted,
			"owner_peer_id": existing.owner_peer_id,
			"hp": existing.hp,
		})
	for existing in vehicles_container.get_children():
		_catch_up_vehicle.rpc_id(peer_id, existing.vehicle_id, existing.position, existing.hp, existing.owner_peer_id, existing.vehicle_type)
	for existing in zombie_nests_container.get_children():
		_catch_up_zombie_nest.rpc_id(peer_id, existing.zombie_nest_id, existing.position, existing.hp)
	# Tag/Nacht-Stand (siehe _handle_day_night()) — ohne das hier
	# würde ein später beitretender Peer lokal bei _day_time = 0 (Taganfang)
	# neu anfangen, unabhängig davon, wie weit die anderen schon sind.
	_catch_up_day_time.rpc_id(peer_id, _day_time, _day_count)


func _spawn_survivor(peer_id: int, spawn_position: Vector3) -> void:
	survivor_spawner.spawn({"id": _next_survivor_id, "peer_id": peer_id, "position": spawn_position})
	_next_survivor_id += 1


func spawn_recruit(peer_id: int, spawn_position: Vector3) -> void:
	# Aufgerufen von Survivor._finish_search(), wenn ein durchsuchtes
	# Gebäude has_survivor = true hatte. Siehe docs/recruitment.md.
	_spawn_survivor(peer_id, spawn_position)


func spawn_nest_zombie(spawn_position: Vector3) -> void:
	# Aufgerufen von ZombieNest._process() (host-seitig, siehe
	# docs/zombies.md, "Zombie-Nest") — gleiches Cross-Node-Muster wie
	# spawn_recruit(). Kein Peer-Bezug, gehört keinem Spieler, wie die vier
	# festen Start-Zombies auch. Y bewusst NICHT von spawn_position
	# übernommen (Bug, gefunden beim Ergänzen des Brute-Typs) — ZombieNest
	# übergibt seine EIGENE global_position + Streuung, deren Y (1.35, die
	# Nest-Höhe) nichts mit der nötigen Zombie-Bodenhöhe zu tun hat; sonst
	# würde der Zombie sichtbar über dem Boden schweben (gleiche Fehlerklasse
	# wie bei den Ressourcenknoten, siehe docs/survivor.md).
	if get_tree().get_nodes_in_group("zombie").size() >= MAX_ZOMBIES:
		# Zombie-Obergrenze erreicht (siehe MAX_ZOMBIES oben) — Nest lässt
		# diesen Spawn einfach aus, kein Fehler/Feedback nötig (Spieler
		# merken höchstens, dass die Zahl nicht weiter steigt). Nächster
		# Versuch automatisch beim nächsten SPAWN_INTERVAL.
		return
	var pos := Vector3(spawn_position.x, ZOMBIE_GROUND_Y, spawn_position.z)
	zombie_spawner.spawn({"index": _next_nest_zombie_id, "position": pos})
	_next_nest_zombie_id += 1


func grant_zombie_loot(peer_id: int, is_brute: bool) -> void:
	# Aufgerufen von Zombie.take_damage() (host-seitig) beim Tod, siehe
	# docs/zombies.md, "Zombie-Loot-Drop" — Nutzerwunsch: nur Munition,
	# Heilzeug, oder eine Waffe droppen, sonst nichts. Kein physischer
	# Pickup-Node, direkt an die Home-Base des Verursachers (peer_id kommt
	# aus Zombie._last_damage_source_peer_id, gesetzt von Survivor-
	# Gegenschaden bzw. Wachposten-Beschuss). peer_id == 0 (kein bekannter
	# Verursacher) → kein Drop, auch kein Buch-Wurf.
	if peer_id == 0:
		return
	var home_base := _find_home_base_for_peer(peer_id)
	if home_base == null:
		return
	if randf() <= ZOMBIE_LOOT_DROP_CHANCE:
		var loot_type: String = ZOMBIE_LOOT_TABLE[randi() % ZOMBIE_LOOT_TABLE.size()]
		var amounts: Dictionary = BRUTE_LOOT_AMOUNT if is_brute else ZOMBIE_LOOT_AMOUNT
		home_base.add_resources.rpc({loot_type: amounts[loot_type]})
		report_status(peer_id, "Zombie-Beute: +%d %s" % [amounts[loot_type], RESOURCE_DISPLAY_NAMES.get(loot_type, loot_type)])
	# Unabhängiger, selterer Buch-Wurf (siehe BOOK_DROP_CHANCE oben) — läuft
	# separat vom Haupt-Loot-Wurf, kann also auch zusätzlich zu normalem
	# Loot (oder ganz ohne) auftreten.
	if randf() <= BOOK_DROP_CHANCE:
		var book_type: String = BOOK_TABLE[randi() % BOOK_TABLE.size()]
		home_base.add_resources.rpc({book_type: 1})
		report_status(peer_id, "Zombie-Beute: %s gefunden!" % RESOURCE_DISPLAY_NAMES.get(book_type, book_type))


@rpc("authority", "reliable")
func _catch_up_survivor(id: int, peer_id: int, spawn_position: Vector3) -> void:
	var survivor_name := "survivor_%d" % id
	if survivors_container.has_node(survivor_name):
		return
	var survivor := _create_survivor({"id": id, "peer_id": peer_id, "position": spawn_position})
	survivors_container.add_child(survivor)


@rpc("authority", "reliable")
func _catch_up_home_base(peer_id: int, spawn_position: Vector3) -> void:
	var base_name := "homebase_%d" % peer_id
	if home_bases_container.has_node(base_name):
		return
	var base := _create_home_base({"peer_id": peer_id, "position": spawn_position})
	home_bases_container.add_child(base)


@rpc("authority", "reliable")
func _catch_up_zombie(index: int, spawn_position: Vector3, is_brute: bool) -> void:
	var zombie_name := "zombie_%d" % index
	if zombies_container.has_node(zombie_name):
		return
	var zombie := _create_zombie({"index": index, "position": spawn_position, "is_brute": is_brute})
	zombies_container.add_child(zombie)


@rpc("authority", "reliable")
func _catch_up_guard_post(id: int, peer_id: int, spawn_position: Vector3) -> void:
	var post_name := "guardpost_%d" % id
	if guard_posts_container.has_node(post_name):
		return
	var post := _create_guard_post({"id": id, "peer_id": peer_id, "position": spawn_position})
	guard_posts_container.add_child(post)


@rpc("authority", "reliable")
func _catch_up_wall(id: int, peer_id: int, spawn_position: Vector3, spawn_rotation_y: float, is_gate: bool) -> void:
	var wall_name := "wall_%d" % id
	if walls_container.has_node(wall_name):
		return
	var wall := _create_wall({"id": id, "peer_id": peer_id, "position": spawn_position, "rotation_y": spawn_rotation_y, "is_gate": is_gate})
	walls_container.add_child(wall)


@rpc("authority", "reliable")
func _catch_up_medical_station(id: int, peer_id: int, spawn_position: Vector3) -> void:
	var station_name := "medicalstation_%d" % id
	if medical_stations_container.has_node(station_name):
		return
	var station := _create_medical_station({"id": id, "peer_id": peer_id, "position": spawn_position})
	medical_stations_container.add_child(station)


@rpc("authority", "reliable")
func _catch_up_workshop(id: int, peer_id: int, spawn_position: Vector3) -> void:
	var workshop_name := "workshop_%d" % id
	if workshops_container.has_node(workshop_name):
		return
	var workshop := _create_workshop({"id": id, "peer_id": peer_id, "position": spawn_position})
	workshops_container.add_child(workshop)


@rpc("authority", "reliable")
func _catch_up_storage(id: int, peer_id: int, spawn_position: Vector3) -> void:
	# capacity_bonus bewusst nicht mitgeschickt/genutzt — die Kapazität
	# wurde beim echten Erstellen längst auf der Home-Base gutgeschrieben
	# (siehe Storage._ready()), diese Kopie ist rein visuell für den spät
	# beitretenden Peer. _ready()s Server-Guard verhindert ohnehin, dass
	# add_storage_capacity() hier erneut feuert.
	var storage_name := "storage_%d" % id
	if storages_container.has_node(storage_name):
		return
	var storage := _create_storage({"id": id, "peer_id": peer_id, "position": spawn_position})
	storages_container.add_child(storage)


@rpc("authority", "reliable")
func _catch_up_bed(id: int, peer_id: int, spawn_position: Vector3) -> void:
	var bed_name := "bed_%d" % id
	if beds_container.has_node(bed_name):
		return
	var bed := _create_bed({"id": id, "peer_id": peer_id, "position": spawn_position})
	beds_container.add_child(bed)


@rpc("authority", "reliable")
func _catch_up_tree(id: int, spawn_position: Vector3) -> void:
	var tree_name := "tree_%d" % id
	if trees_container.has_node(tree_name):
		return
	var tree := _create_tree({"id": id, "position": spawn_position})
	trees_container.add_child(tree)


@rpc("authority", "reliable")
func _catch_up_car_wreck(id: int, spawn_position: Vector3) -> void:
	var wreck_name := "car_wreck_%d" % id
	if car_wrecks_container.has_node(wreck_name):
		return
	var wreck := _create_car_wreck({"id": id, "position": spawn_position})
	car_wrecks_container.add_child(wreck)


@rpc("authority", "reliable")
func _catch_up_stone_pile(id: int, spawn_position: Vector3) -> void:
	var pile_name := "stone_pile_%d" % id
	if stone_piles_container.has_node(pile_name):
		return
	var pile := _create_stone_pile({"id": id, "position": spawn_position})
	stone_piles_container.add_child(pile)


@rpc("authority", "reliable")
func _catch_up_brick_pile(id: int, spawn_position: Vector3) -> void:
	var pile_name := "brick_pile_%d" % id
	if brick_piles_container.has_node(pile_name):
		return
	var pile := _create_brick_pile({"id": id, "position": spawn_position})
	brick_piles_container.add_child(pile)


@rpc("authority", "reliable")
func _catch_up_field(id: int, peer_id: int, spawn_position: Vector3) -> void:
	var field_name := "field_%d" % id
	if fields_container.has_node(field_name):
		return
	var field := _create_field({"id": id, "peer_id": peer_id, "position": spawn_position})
	fields_container.add_child(field)


@rpc("authority", "reliable")
func _catch_up_outpost(id: int, peer_id: int, spawn_position: Vector3) -> void:
	var outpost_name := "outpost_%d" % id
	if outposts_container.has_node(outpost_name):
		return
	var outpost := _create_outpost({"id": id, "peer_id": peer_id, "position": spawn_position})
	outposts_container.add_child(outpost)


@rpc("authority", "reliable")
func _catch_up_building(data: Dictionary) -> void:
	var building_name := "building_%d" % data["id"]
	if buildings_container.has_node(building_name):
		return
	var building := _create_building(data)
	buildings_container.add_child(building)


@rpc("authority", "reliable")
func _catch_up_vehicle(id: int, spawn_position: Vector3, hp: int, owner_peer_id: int, vehicle_type: String) -> void:
	# owner_peer_id seit Punkt 6 der Performance-Liste (Task #35) mit
	# dabei — vorher bekam ein spät beitretender Peer nie mit, dass ein
	# Fahrzeug schon besetzt ist (siehe docs/vehicle.md, "Bekannte
	# Grenzen"), sein lokales `owner_peer_id` blieb fälschlich 0.
	var vehicle_name := "vehicle_%d" % id
	if vehicles_container.has_node(vehicle_name):
		return
	var vehicle := _create_vehicle({"id": id, "position": spawn_position, "owner_peer_id": owner_peer_id, "vehicle_type": vehicle_type})
	vehicles_container.add_child(vehicle)
	# hp erst NACH add_child setzen (siehe _create_vehicle()) — sonst
	# überschreibt Vehicle._ready() den hier übertragenen Wert wieder mit
	# dem vollen Höchstwert des Typs.
	vehicle.hp = hp


@rpc("authority", "reliable")
func _catch_up_zombie_nest(id: int, spawn_position: Vector3, hp: int) -> void:
	var nest_name := "zombie_nest_%d" % id
	if zombie_nests_container.has_node(nest_name):
		return
	var nest := _create_zombie_nest({"id": id, "position": spawn_position, "hp": hp})
	zombie_nests_container.add_child(nest)


@rpc("authority", "reliable")
func _catch_up_day_time(day_time: float, day_count: int) -> void:
	_day_time = day_time
	_day_count = day_count


func _create_survivor(data: Dictionary) -> Node:
	# Läuft identisch auf jedem Peer (siehe docs/world.md, "Warum spawn_function").
	# hp/hunger/fatigue/morale/carried_loot/troop_type sind optionale
	# Zusatzfelder fürs Laden eines Spielstands (siehe docs/save_load.md) —
	# normale Spawns im Spiel übergeben sie nie, Verhalten dort bleibt
	# unverändert (Survivor.gd setzt die Defaults selbst über
	# Feld-Initialisierer).
	var survivor := SURVIVOR_SCENE.instantiate()
	survivor.name = "survivor_%d" % data["id"]
	survivor.trupp_id = data["id"]
	survivor.position = data["position"]
	survivor.owner_peer_id = data["peer_id"]
	if data.has("hp"):
		survivor.hp = data["hp"]
	if data.has("hunger"):
		survivor.hunger = data["hunger"]
	if data.has("fatigue"):
		survivor.fatigue = data["fatigue"]
	if data.has("morale"):
		survivor.morale = data["morale"]
	if data.has("carried_loot"):
		survivor.carried_loot = data["carried_loot"]
	if data.has("troop_type"):
		survivor.troop_type = data["troop_type"]
	if data.has("is_armed"):
		survivor.is_armed = data["is_armed"]
	if data.has("is_wearing_armor"):
		survivor.is_wearing_armor = data["is_wearing_armor"]
	if data.has("has_helmet"):
		survivor.has_helmet = data["has_helmet"]
	if data.has("secondary_weapon"):
		survivor.secondary_weapon = data["secondary_weapon"]
	if data.has("has_leg_armor"):
		survivor.has_leg_armor = data["has_leg_armor"]
	return survivor


func _create_home_base(data: Dictionary) -> Node:
	var base := HOME_BASE_SCENE.instantiate()
	base.name = "homebase_%d" % data["peer_id"]
	base.position = data["position"]
	base.owner_peer_id = data["peer_id"]
	if data["peer_id"] == multiplayer.get_unique_id():
		# Kamera direkt zur eigenen Basis, statt am Kartenursprung zu starten.
		pivot.position = Vector3(base.position.x, 0, base.position.z)
	return base


func _create_zombie(data: Dictionary) -> Node:
	var is_brute: bool = data.get("is_brute", false)
	var scene: PackedScene = ZOMBIE_BRUTE_SCENE if is_brute else ZOMBIE_SCENE
	var zombie := scene.instantiate()
	zombie.name = "zombie_%d" % data["index"]
	zombie.zombie_id = data["index"]
	zombie.position = data["position"]
	zombie.is_brute = is_brute
	# Kein hp-Override hier (anders als bei Survivor) — Zombie._ready()
	# berechnet hp = _max_hp erst NACHDEM dieser Node dem Baum hinzugefügt
	# wurde (siehe dortige @export-Timing-Erklärung) und würde einen hier
	# gesetzten Wert sofort wieder überschreiben. Für den Spielstand-Import
	# setzt _load_game_state() das hp-Override deshalb erst NACH dem
	# eigentlichen spawn()-Aufruf (siehe dort).
	return zombie


func _create_guard_post(data: Dictionary) -> Node:
	var post := GUARD_POST_SCENE.instantiate()
	post.name = "guardpost_%d" % data["id"]
	post.guard_post_id = data["id"]
	post.position = data["position"]
	post.owner_peer_id = data["peer_id"]
	# Optionales built-Override fürs Laden eines Spielstands (siehe
	# docs/save_load.md) — ein beim Speichern schon fertig gebauter
	# Wachposten soll nicht erneut die Bauzeit durchlaufen. Ruft dieselbe
	# Funktion auf, die auch der normale Bau-Timer nutzt (_set_built_visual(),
	# als RPC deklariert, aber ganz normal lokal aufrufbar — kein Client
	# angeschlossen, an den beim Laden ohnehin schon repliziert werden
	# könnte), statt built/_update_color() getrennt zu duplizieren.
	if data.get("built", false):
		post._set_built_visual()
	return post


func _create_wall(data: Dictionary) -> Node:
	# is_gate steckt schon in der jeweiligen Szene (Wall.tscn/Gate.tscn, per
	# @export in Wall.gd voreingestellt) — hier nur die passende Szene wählen.
	var scene: PackedScene = GATE_SCENE if data["is_gate"] else WALL_SCENE
	var wall := scene.instantiate()
	wall.name = "wall_%d" % data["id"]
	wall.wall_id = data["id"]
	wall.position = data["position"]
	wall.rotation.y = data.get("rotation_y", 0.0)
	wall.owner_peer_id = data["peer_id"]
	return wall


func _create_medical_station(data: Dictionary) -> Node:
	var station := MEDICAL_STATION_SCENE.instantiate()
	station.name = "medicalstation_%d" % data["id"]
	station.medical_station_id = data["id"]
	station.position = data["position"]
	station.owner_peer_id = data["peer_id"]
	return station


func _create_bed(data: Dictionary) -> Node:
	var bed := BED_SCENE.instantiate()
	bed.name = "bed_%d" % data["id"]
	bed.bed_id = data["id"]
	bed.position = data["position"]
	bed.owner_peer_id = data["peer_id"]
	return bed


func _create_workshop(data: Dictionary) -> Node:
	var workshop := WORKSHOP_SCENE.instantiate()
	workshop.name = "workshop_%d" % data["id"]
	workshop.workshop_id = data["id"]
	workshop.position = data["position"]
	workshop.owner_peer_id = data["peer_id"]
	return workshop


func _create_storage(data: Dictionary) -> Node:
	var storage := STORAGE_SCENE.instantiate()
	storage.name = "storage_%d" % data["id"]
	storage.storage_id = data["id"]
	storage.position = data["position"]
	storage.owner_peer_id = data["peer_id"]
	storage.capacity_bonus = data.get("capacity", 0)
	return storage


func _create_field(data: Dictionary) -> Node:
	var field := FIELD_SCENE.instantiate()
	field.name = "field_%d" % data["id"]
	field.field_id = data["id"]
	field.position = data["position"]
	field.owner_peer_id = data["peer_id"]
	return field


func _create_outpost(data: Dictionary) -> Node:
	var outpost := OUTPOST_SCENE.instantiate()
	outpost.name = "outpost_%d" % data["id"]
	outpost.outpost_id = data["id"]
	outpost.position = data["position"]
	outpost.owner_peer_id = data["peer_id"]
	return outpost


func _create_building(data: Dictionary) -> Node:
	# Seit dem Kartenumbau (siehe docs/world.md, "Kartengröße") aus
	# BUILDING_TYPES erzeugt statt fester .tscn-Kind-Node — Mesh/
	# Collision bekommen JEWEILS FRISCHE Resource-Objekte (nicht die im
	# .tscn hinterlegte, geteilte Standardgröße direkt mutiert!), sonst
	# würden alle Gebäude-Instanzen dieselbe BoxMesh-Resource teilen und
	# sich gegenseitig in der Größe verändern.
	var building := BUILDING_SCENE.instantiate()
	building.name = "building_%d" % data["id"]
	building.building_id = data["id"]
	building.position = data["position"]
	building.zone_center = data["zone_center"]
	var size: Vector3 = data["size"]
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	var mesh_instance: MeshInstance3D = building.get_node("Mesh")
	mesh_instance.mesh = box_mesh
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	var collision: CollisionShape3D = building.get_node("Collision")
	collision.shape = box_shape
	building.default_color = data["default_color"]
	var default_mat := StandardMaterial3D.new()
	default_mat.albedo_color = building.default_color
	mesh_instance.set_surface_override_material(0, default_mat)
	building.loot = data["loot"]
	building.has_survivor = data.get("has_survivor", false)
	# is_looted/owner_peer_id/hp sind optionale Zusatzfelder fürs Laden
	# eines Spielstands (siehe docs/save_load.md) — normale Zonen-
	# Generierung übergibt sie nie, Building.gd setzt die Defaults selbst
	# über Feld-Initialisierer. _update_visual() danach explizit
	# aufgerufen, damit ein aus einem Spielstand geladenes, schon
	# geplündertes/geclaimtes Gebäude sofort korrekt aussieht (normalerweise
	# passiert das über mark_looted()/_sync_owner(), die hier beim Laden
	# nicht extra aufgerufen werden).
	building.is_looted = data.get("is_looted", false)
	building.owner_peer_id = data.get("owner_peer_id", 0)
	building.hp = data.get("hp", 100)  # 100 == Building.MAX_HP
	building._update_visual()
	return building


func _create_vehicle(data: Dictionary) -> Node:
	# Seit dem Kartenumbau (siehe docs/world.md, "Kartengröße") pro
	# Stadt-Zone gespawnt statt zweier fester .tscn-Kind-Nodes.
	var vehicle := VEHICLE_SCENE.instantiate()
	vehicle.name = "vehicle_%d" % data["id"]
	vehicle.vehicle_id = data["id"]
	vehicle.position = data["position"]
	vehicle.vehicle_type = data.get("vehicle_type", "car")
	# Kein hp-Override hier (anders als früher, siehe Zombie._ready() für
	# dasselbe Muster) — Vehicle._ready() berechnet hp = _max_hp abhängig
	# vom vehicle_type erst NACHDEM dieser Node dem Baum hinzugefügt wurde,
	# ein hier gesetzter Wert würde sofort wieder überschrieben. Aufrufer,
	# die ein bestimmtes hp brauchen (Catch-up/Spielstand-Import), setzen es
	# deshalb erst NACH dem eigentlichen spawn()-Aufruf.
	if data.has("owner_peer_id"):
		vehicle.owner_peer_id = data["owner_peer_id"]
	return vehicle


func _create_zombie_nest(data: Dictionary) -> Node:
	# Seit dem Kartenumbau (siehe docs/world.md, "Kartengröße") ein Nest PRO
	# Stadt-Zone statt einmalig auf der ganzen Karte, deshalb jetzt
	# gespawnt statt fester .tscn-Kind-Node.
	var nest := ZOMBIE_NEST_SCENE.instantiate()
	nest.name = "zombie_nest_%d" % data["id"]
	nest.zombie_nest_id = data["id"]
	nest.position = data["position"]
	if data.has("hp"):
		nest.hp = data["hp"]
	return nest


func _create_tree(data: Dictionary) -> Node:
	# hp/is_marked optional fürs Laden eines Spielstands (siehe
	# docs/save_load.md) — Tree._ready() liest hp/is_marked nur für die
	# Farbe, überschreibt sie nicht (anders als Zombie.is_brute), deshalb
	# hier direkt vor dem Hinzufügen zum Baum setzbar.
	var tree := TREE_SCENE.instantiate()
	tree.name = "tree_%d" % data["id"]
	tree.tree_id = data["id"]
	tree.position = data["position"]
	if data.has("hp"):
		tree.hp = data["hp"]
	if data.has("is_marked"):
		tree.is_marked = data["is_marked"]
	return tree


func _create_car_wreck(data: Dictionary) -> Node:
	var wreck := CAR_WRECK_SCENE.instantiate()
	wreck.name = "car_wreck_%d" % data["id"]
	wreck.wreck_id = data["id"]
	wreck.position = data["position"]
	if data.has("hp"):
		wreck.hp = data["hp"]
	if data.has("is_marked"):
		wreck.is_marked = data["is_marked"]
	return wreck


func _create_stone_pile(data: Dictionary) -> Node:
	var pile := STONE_PILE_SCENE.instantiate()
	pile.name = "stone_pile_%d" % data["id"]
	pile.pile_id = data["id"]
	pile.position = data["position"]
	if data.has("hp"):
		pile.hp = data["hp"]
	if data.has("is_marked"):
		pile.is_marked = data["is_marked"]
	return pile


func _create_brick_pile(data: Dictionary) -> Node:
	var pile := BRICK_PILE_SCENE.instantiate()
	pile.name = "brick_pile_%d" % data["id"]
	pile.pile_id = data["id"]
	pile.position = data["position"]
	if data.has("hp"):
		pile.hp = data["hp"]
	if data.has("is_marked"):
		pile.is_marked = data["is_marked"]
	return pile


func _generate_world() -> void:
	# Ersetzt die früheren _spawn_zombies()/_spawn_initial_resources()-
	# Aufrufe (siehe _ready()) — Host würfelt zuerst CITY_ZONE_LARGE_COUNT
	# große, dann CITY_ZONE_SMALL_COUNT kleine Stadt-Zonen mit Mindestabstand
	# (siehe docs/world.md, "Kartengröße"/"Straßen-Raster"), pro Zone
	# entsteht eine komplette Mini-Stadt (Gebäude/Fahrzeuge/Nest/Zombie-
	# Spawnpunkte), danach FOREST_ZONE_COUNT Wald-Zonen (siehe
	# "Wald-Zonen" oben, kennen bereits alle Stadt-Zentren und weichen
	# ihnen aus), danach werden Ressourcen über die restliche Karte
	# verteilt. Kein neuer Netzwerk-Mechanismus nötig — läuft einmalig auf
	# dem Host, jeder Spawn repliziert schon über die bestehende
	# MultiplayerSpawner-Infrastruktur (identisches Prinzip wie vorher für
	# Bäume/Zombies). zone_index läuft weiter durch (nicht pro Größe neu bei
	# 0 startend) — bleibt so weiterhin eindeutig für
	# _next_nest_zombie_id-Namensräume (siehe ZOMBIES_PER_ZONE-Kommentar).
	var zone_index := 0
	for i in CITY_ZONE_LARGE_COUNT:
		var center := _pick_zone_center(CITY_ZONE_RADIUS_LARGE)
		_city_zone_centers.append(center)
		_generate_city_zone(center, zone_index, CITY_ZONE_RADIUS_LARGE, BUILDINGS_PER_LARGE_ZONE)
		zone_index += 1
	for i in CITY_ZONE_SMALL_COUNT:
		var center := _pick_zone_center(CITY_ZONE_RADIUS_SMALL)
		_city_zone_centers.append(center)
		_generate_city_zone(center, zone_index, CITY_ZONE_RADIUS_SMALL, BUILDINGS_PER_SMALL_ZONE)
		zone_index += 1
	for i in FOREST_ZONE_COUNT:
		var center := _pick_forest_zone_center()
		_forest_zone_centers.append(center)
		_generate_forest_zone(center)
	_spawn_wilderness_resources()


func _pick_zone_center(radius: float) -> Vector3:
	# Innerhalb von MAP_SIZE minus radius Rand, damit keine Zone über den
	# Kartenrand hinausragt — radius ist seit den zwei Zonengrößen (siehe
	# CITY_ZONE_RADIUS_LARGE/_SMALL) ein Parameter statt einer festen
	# Konstante. Gleiches "nach SPACING_ATTEMPTS aufgeben statt endlos
	# probieren"-Prinzip wie _spaced_position(). Mindestabstand siehe
	# _is_far_from_zone_centers().
	var half_map: float = MAP_SIZE / 2.0 - radius
	var candidate := Vector3.ZERO
	for attempt in SPACING_ATTEMPTS:
		candidate = Vector3(randf_range(-half_map, half_map), 0.0, randf_range(-half_map, half_map))
		candidate = _snap_to_tile_grid(candidate)
		if _is_far_from_zone_centers(candidate):
			return candidate
	return candidate


func _snap_to_tile_grid(pos: Vector3) -> Vector3:
	# Rundet auf das globale STREET_TILE_SIZE-Raster — ohne das würde jede
	# Zone mit einem zufälligen Sub-Tile-Versatz starten, und
	# _build_zone_street_tiles() könnte ihre Straßen-Kacheln nicht mehr exakt
	# auf ganze GridMap-Zellen legen (die Gebäude-Reihen aus
	# _generate_street_slots() bleiben relativ zum jeweiligen Zonen-Zentrum
	# exakt, verschieben sich also automatisch mit).
	return Vector3(snappedf(pos.x, STREET_TILE_SIZE), pos.y, snappedf(pos.z, STREET_TILE_SIZE))


func _pick_forest_zone_center() -> Vector3:
	# Gleiches Prinzip wie _pick_zone_center(), eigener Rand-Abstand wegen
	# des kleineren FOREST_ZONE_RADIUS. Läuft NACH den Stadt-Zonen (siehe
	# _generate_world()), _is_far_from_zone_centers() kennt zu diesem
	# Zeitpunkt also schon alle Stadt-Zentren.
	var half_map: float = MAP_SIZE / 2.0 - FOREST_ZONE_RADIUS
	var candidate := Vector3.ZERO
	for attempt in SPACING_ATTEMPTS:
		candidate = Vector3(randf_range(-half_map, half_map), 0.0, randf_range(-half_map, half_map))
		if _is_far_from_zone_centers(candidate):
			return candidate
	return candidate


func _is_far_from_zone_centers(candidate: Vector3) -> bool:
	# Gemeinsamer Mindestabstand (CITY_ZONE_MIN_SPACING) zu ALLEN
	# Zonen-Zentren, Stadt UND Wald — verhindert Überlappung zwischen
	# beiden Zonen-Typen genauso wie zwischen zwei Zonen desselben Typs.
	# Ein einziger, bewusst großzügiger Wert statt separater Konstanten pro
	# Typ-Paarung (Stadt-Stadt/Stadt-Wald/Wald-Wald) — deutlich größer als
	# jeder einzelne Zonen-Radius, Überlappung also in jedem Fall sicher
	# ausgeschlossen.
	for existing in _city_zone_centers:
		if Vector2(candidate.x, candidate.z).distance_to(Vector2(existing.x, existing.z)) < CITY_ZONE_MIN_SPACING:
			return false
	for existing in _forest_zone_centers:
		if Vector2(candidate.x, candidate.z).distance_to(Vector2(existing.x, existing.z)) < CITY_ZONE_MIN_SPACING:
			return false
	return true


func _generate_city_zone(center: Vector3, zone_index: int, radius: float, building_count: int) -> void:
	# Straßen-Raster statt Zufallsstreuen (2026-08-01, Kartenplanungs-
	# Session) — _generate_street_slots() liefert mehr mögliche
	# Reihenplätze als gebraucht, hier wird zufällig NUR building_count
	# davon ausgewählt (siehe STREET_BLOCK_SIZE-Kommentar oben), Rest bleibt
	# als "unbebaute Lücke" stehen (wirkt organischer als jeden Platz zu
	# füllen, und wäre bei den großen Zonen sonst weit über tausend Gebäude).
	# Genau EIN Platz pro Zone bekommt has_survivor = true, UNABHÄNGIG von
	# dem dort gewürfelten Typ (siehe BUILDING_TYPES) — reproduziert
	# "ein Rekrut pro Stadt-Zone" aus dem ursprünglichen Einzel-Gebäude-
	# Design.
	var slots: Array[Vector3] = _generate_street_slots(center, radius)
	slots.shuffle()
	var count: int = mini(building_count, slots.size())
	var recruit_slot: int = randi() % count if count > 0 else -1
	for i in count:
		var template: Dictionary = BUILDING_TYPES[randi() % BUILDING_TYPES.size()]
		var size: Vector3 = template["size"]
		var slot: Vector3 = slots[i]
		var pos := Vector3(slot.x, size.y / 2.0, slot.z)
		building_spawner.spawn({
			"id": _next_building_id,
			"position": pos,
			"size": size,
			"loot": _roll_building_loot(template),
			"default_color": template["default_color"],
			"has_survivor": i == recruit_slot,
			"zone_center": center,
		})
		_next_building_id += 1
	for i in VEHICLES_PER_ZONE:
		var vehicle_type: String = VEHICLE_TYPES[randi() % VEHICLE_TYPES.size()]
		var ground_y: float = VEHICLE_GROUND_Y_BY_TYPE.get(vehicle_type, VEHICLE_GROUND_Y)
		var pos := _spaced_position(center, radius, ground_y)
		vehicle_spawner.spawn({"id": _next_vehicle_id, "position": pos, "vehicle_type": vehicle_type})
		_next_vehicle_id += 1
	var nest_pos := _spaced_position(center, radius, ZOMBIE_NEST_GROUND_Y)
	zombie_nest_spawner.spawn({"id": _next_zombie_nest_id, "position": nest_pos})
	_next_zombie_nest_id += 1
	var ring_radius: float = radius + ZOMBIE_SPAWN_RING_OFFSET
	for i in ZOMBIES_PER_ZONE:
		var angle: float = float(i) / float(ZOMBIES_PER_ZONE) * TAU
		var ring_pos := center + Vector3(cos(angle), 0, sin(angle)) * ring_radius
		var index: int = zone_index * ZOMBIES_PER_ZONE + i
		zombie_spawner.spawn({"index": index, "position": Vector3(ring_pos.x, ZOMBIE_GROUND_Y, ring_pos.z)})


func _generate_street_slots(center: Vector3, radius: float) -> Array[Vector3]:
	# Baut ALLE möglichen Gebäude-Reihenplätze entlang eines Straßen-Rasters
	# innerhalb von radius um center (deutlich mehr als gebraucht, siehe
	# _generate_city_zone(), das nur eine zufällige Teilmenge davon
	# tatsächlich bebaut) — dadurch folgt die GEOMETRIE echten Reihen/
	# Straßen statt reinem Zufallsstreuen, ohne die Gesamt-Gebäudezahl (und
	# damit Performance) zu erhöhen. Raster ist PRO ZONE um center zentriert
	# (nicht global über die ganze Karte ausgerichtet) — jede Zone bleibt
	# dadurch optisch in sich geschlossen, unabhängig von ihrer Position.
	var slots: Array[Vector3] = []
	var half_block: float = STREET_BLOCK_SIZE / 2.0
	var block_range: int = ceili(radius / STREET_CELL_SIZE) + 1
	for bi in range(-block_range, block_range + 1):
		for bj in range(-block_range, block_range + 1):
			var block_x: float = center.x + bi * STREET_CELL_SIZE
			var block_z: float = center.z + bj * STREET_CELL_SIZE
			if Vector2(block_x, block_z).distance_to(Vector2(center.x, center.z)) > radius:
				continue
			var edge_start: float = -half_block + BUILDING_MIN_SPACING / 2.0
			var edge_end: float = half_block - BUILDING_MIN_SPACING / 2.0
			var s: float = edge_start
			while s <= edge_end:
				var row_candidates: Array[Vector3] = [
					Vector3(block_x + s, 0.0, block_z - half_block + BUILDING_ROW_INSET),
					Vector3(block_x + s, 0.0, block_z + half_block - BUILDING_ROW_INSET),
					Vector3(block_x - half_block + BUILDING_ROW_INSET, 0.0, block_z + s),
					Vector3(block_x + half_block - BUILDING_ROW_INSET, 0.0, block_z + s),
				]
				for candidate in row_candidates:
					if Vector2(candidate.x, candidate.z).distance_to(Vector2(center.x, center.z)) <= radius:
						slots.append(candidate)
				s += BUILDING_MIN_SPACING
	return slots


@rpc("any_peer", "reliable")
func request_city_zones() -> void:
	# Client-seitiger PULL (siehe _ready(), Bugfix-Kommentar dort) — läuft
	# garantiert erst NACHDEM der anfragende Peer sein eigenes World-Node im
	# Baum hat (sonst hätte er das RPC ja gar nicht erst verschicken
	# können), und der Host hat beim Verarbeiten eingehender RPCs sein
	# eigenes _ready() immer schon vollständig durchlaufen — dadurch ist
	# _city_zone_centers hier immer schon korrekt gefüllt, kein Race
	# möglich.
	if not multiplayer.is_server():
		return
	_sync_city_zones.rpc_id(multiplayer.get_remote_sender_id(), _city_zone_centers)


@rpc("authority", "reliable")
func _sync_city_zones(zones: Array) -> void:
	# Einziger Weg, wie NICHT-Host-Peers überhaupt _city_zone_centers zu
	# sehen bekommen — vorher brauchte das niemand außer dem Host selbst
	# (nur für _is_far_from_city_zones()/_trigger_horde_night(), beide
	# host-only), seit der sichtbaren Straßen-Geometrie (siehe unten)
	# müssen aber auch Clients die Zonen-Zentren kennen, um dieselben
	# Straßen-Meshes lokal nachzubauen. Element-für-Element statt Bulk-
	# Zuweisung (gleiches Muster wie beim Laden, siehe _load_game_state()),
	# damit der generische `Array`-RPC-Parameter sauber in das
	# `Array[Vector3]`-Feld passt. KEIN `call_local` (anders als z. B.
	# _sync_trade_offers) — der Host ruft das nie selbst auf, er baut seine
	# eigenen Straßen direkt über _build_street_visuals(), siehe _ready().
	_city_zone_centers.clear()
	for zone_center in zones:
		_city_zone_centers.append(zone_center)
	_build_street_visuals()


func _build_street_visuals() -> void:
	# Rein lokale, deterministische Sicht-Geometrie — jeder Peer baut sie
	# unabhängig aus denselben Zonen-Zentren (siehe _sync_city_zones())
	# neu auf und kommt dabei IMMER zum selben Ergebnis, weil hier (anders
	# als bei der zufälligen Gebäude-Auswahl in _generate_city_zone())
	# nichts gewürfelt wird — nur (center, radius) → Geometrie.
	street_grid_map.clear()
	for i in _city_zone_centers.size():
		var center: Vector3 = _city_zone_centers[i]
		# Reihenfolge entspricht immer erst den großen, dann den kleinen
		# Zonen (siehe _generate_world()) — bleibt beim Speichern/Laden
		# erhalten (_collect_save_data() dupliziert das Array unverändert),
		# deshalb reicht der Index, ohne Radius/Größe extra zu speichern.
		var radius: float = CITY_ZONE_RADIUS_LARGE if i < CITY_ZONE_LARGE_COUNT else CITY_ZONE_RADIUS_SMALL
		_build_zone_street_tiles(center, radius)


func _compute_zone_blocks(center: Vector3, radius: float) -> Dictionary:
	# Gemeinsame Grundlage für _build_zone_street_tiles() (Sicht-Geometrie) UND
	# find_vehicle_path() (Fahrzeug-Pathing, siehe unten) — dieselbe
	# Blockraster-Logik wie _generate_street_slots() (dieselben
	# STREET_*-Konstanten), hier aber nur "welche Blöcke liegen in der
	# Zone", ohne Gebäude-Reihenplätze/Straßen-Streifen selbst zu bauen.
	var block_range: int = ceili(radius / STREET_CELL_SIZE) + 1
	var in_zone: Dictionary = {}
	for bi in range(-block_range, block_range + 1):
		for bj in range(-block_range, block_range + 1):
			var block_x: float = center.x + bi * STREET_CELL_SIZE
			var block_z: float = center.z + bj * STREET_CELL_SIZE
			if Vector2(block_x, block_z).distance_to(Vector2(center.x, center.z)) <= radius:
				in_zone[Vector2i(bi, bj)] = true
	return in_zone


# Richtungs-Offsets in Kachel-Koordinaten (Norden = -Z, siehe
# Infos/04 Straßen-Kacheln Modellier-Referenz.md, "Ausrichtung").
const _TILE_DIR_N := Vector2i(0, -1)
const _TILE_DIR_S := Vector2i(0, 1)
const _TILE_DIR_E := Vector2i(1, 0)
const _TILE_DIR_W := Vector2i(-1, 0)


func _zone_street_tiles(center: Vector3, radius: float) -> Dictionary:
	# Jeder Block (aus _compute_zone_blocks(), gleiches Raster wie
	# _generate_street_slots()) "besitzt" den Straßen-Kachelstreifen an
	# seiner Ost-/Südkante + die Südost-Eck-Kachel, nur wenn der jeweilige
	# Nachbarblock existiert (gleiches Dedup-Prinzip wie vorher: nur der
	# "nächste" Nachbar wird geprüft, sonst würde jede Kante doppelt
	# gezeichnet). Dadurch entsteht ein durchgehendes Straßennetz zwischen
	# allen Blöcken, ohne Sackgassen-Stummel an den Nachbarn, die es nicht
	# gibt. Extrahiert aus _build_zone_street_tiles() (2026-08-02), damit
	# find_vehicle_path() dieselben Kachel-Positionen für echtes
	# Straßen-Pathing wiederverwenden kann, statt (wie zuvor) über
	# Block-MITTEN zu pathen, die mitten durchs Gras schneiden.
	var in_zone: Dictionary = _compute_zone_blocks(center, radius)
	var street_tiles: Dictionary = {}
	for key in in_zone:
		var bi: int = key.x
		var bj: int = key.y
		var has_east: bool = in_zone.has(Vector2i(bi + 1, bj))
		var has_south: bool = in_zone.has(Vector2i(bi, bj + 1))
		var tile_i: int = bi * (BLOCK_TILES + 1)
		var tile_j: int = bj * (BLOCK_TILES + 1)
		if has_east:
			for k in BLOCK_TILES:
				street_tiles[Vector2i(tile_i + BLOCK_TILES, tile_j + k)] = true
		if has_south:
			for k in BLOCK_TILES:
				street_tiles[Vector2i(tile_i + k, tile_j + BLOCK_TILES)] = true
		if has_east or has_south:
			street_tiles[Vector2i(tile_i + BLOCK_TILES, tile_j + BLOCK_TILES)] = true
	return street_tiles


func _build_zone_street_tiles(center: Vector3, radius: float) -> void:
	var in_zone: Dictionary = _compute_zone_blocks(center, radius)
	for key in in_zone:
		var bi: int = key.x
		var bj: int = key.y
		var tile_i: int = bi * (BLOCK_TILES + 1)
		var tile_j: int = bj * (BLOCK_TILES + 1)
		for gi in BLOCK_TILES:
			for gj in BLOCK_TILES:
				_place_grid_tile(center, Vector2i(tile_i + gi, tile_j + gj), "grass", 0)
	var street_tiles: Dictionary = _zone_street_tiles(center, radius)
	for tile in street_tiles:
		_place_street_tile(center, tile, street_tiles)


func _place_street_tile(center: Vector3, tile: Vector2i, street_tiles: Dictionary) -> void:
	# Nachbarschafts-Bitmaske (welche der 4 Nachbar-Kacheln sind ebenfalls
	# Straße?) bestimmt Form + Rotation. rotation_steps zählt 90°-Schritte
	# im Uhrzeigersinn (von oben gesehen) ausgehend von der jeweiligen
	# Basis-Ausrichtung der Modelle. road_straight ist nativ (rotation_steps=0)
	# Nord-Süd ausgerichtet — per Vertex-Daten aus road_straight.glb
	# verifiziert (2026-08-02, Linien-Flächen sind alle entlang Z
	# langgezogen, nicht X).
	# road_corner/road_t waren zunächst nur GERATEN (Nord+Ost bzw. "alles
	# außer Süd") statt verifiziert — Nutzer meldete danach falsch gedrehte
	# Ecken im Spiel. Per Vertex-Schwerpunkt (tools/inspect_road_shapes.gd)
	# nachgemessen: beide Modelle sind nativ exakt 180° gegenüber der
	# geratenen Annahme verdreht (road_corner nativ Süd+West, road_t nativ
	# offen Süd+Ost+West / geschlossen Nord) — unten um 2 Schritte
	# korrigiert.
	var has_n: bool = street_tiles.has(tile + _TILE_DIR_N)
	var has_s: bool = street_tiles.has(tile + _TILE_DIR_S)
	var has_e: bool = street_tiles.has(tile + _TILE_DIR_E)
	var has_w: bool = street_tiles.has(tile + _TILE_DIR_W)
	var open_count: int = int(has_n) + int(has_s) + int(has_e) + int(has_w)
	var item_name: String
	var rotation_steps: int
	if open_count >= 4:
		item_name = "road_cross"
		rotation_steps = 0
	elif open_count == 3:
		item_name = "road_t"
		if not has_s:
			rotation_steps = 2
		elif not has_e:
			rotation_steps = 3
		elif not has_n:
			rotation_steps = 0
		else:
			rotation_steps = 1
	elif (has_n and has_s) or (has_e and has_w):
		item_name = "road_straight"
		rotation_steps = 0 if has_n or has_s else 1
	elif open_count == 2:
		item_name = "road_corner"
		if has_n and has_e:
			rotation_steps = 2
		elif has_n and has_w:
			rotation_steps = 3
		elif has_s and has_w:
			rotation_steps = 0
		else:
			rotation_steps = 1
	else:
		# Sackgasse/Einzelkachel (Zonenrand) — rein kosmetischer Randfall,
		# als gerade Straße in Richtung der einzigen (bzw. gar keiner)
		# Nachbar-Kachel beholfen.
		item_name = "road_straight"
		rotation_steps = 0 if (has_n or has_s) else 1
	_place_grid_tile(center, tile, item_name, rotation_steps)


func _place_grid_tile(center: Vector3, tile: Vector2i, item_name: String, rotation_steps: int) -> void:
	var mesh_library: MeshLibrary = street_grid_map.mesh_library
	if mesh_library == null:
		return
	var item_id: int = _find_mesh_library_item(mesh_library, item_name)
	if item_id == -1:
		# Defensiv statt Absturz — z. B. wenn die grass-Kachel (optional,
		# siehe Infos/04 ...) noch fehlt.
		return
	var basis := Basis(Vector3.UP, deg_to_rad(90.0 * rotation_steps))
	var orientation: int = street_grid_map.get_orthogonal_index_from_basis(basis)
	var cell: Vector3i = _zone_tile_cell(center, tile)
	street_grid_map.set_cell_item(cell, item_id, orientation)


func _find_mesh_library_item(mesh_library: MeshLibrary, item_name: String) -> int:
	# Eigene Suche statt eines evtl. gar nicht existierenden
	# `MeshLibrary.find_item_by_name()` — sicherer Weg über die offiziell
	# dokumentierten `get_item_list()`/`get_item_name()`.
	for id in mesh_library.get_item_list():
		if mesh_library.get_item_name(id) == item_name:
			return id
	return -1


func _zone_tile_cell(center: Vector3, tile: Vector2i) -> Vector3i:
	# tile ist relativ zum (schon aufs Kachelraster gerundeten, siehe
	# _snap_to_tile_grid()) Zonen-Zentrum gezählt, mit demselben Nullpunkt
	# wie die Block-Indizes (bi=0 → Block-MITTE liegt bei center) — der
	# -TILE_SIZE/2-Versatz gleicht aus, dass tile=0 sonst auf der Kachel-
	# GRENZE statt in der Block-Mitte läge. Bewusst per Hand auf
	# Ganzzahl-Zellkoordinaten gerechnet statt über
	# GridMap.local_to_map()/to_local() — $StreetGridMap steht zwar exakt
	# im Ursprung (position.x/z = 0), aber so bleibt die X/Z-Umrechnung
	# unabhängig von Transform-Details. Y ist immer Zellschicht 0 (eine
	# einzige flache Kachel-Ebene, siehe $StreetGridMap.position.y in
	# World.tscn für die Boden-Ausrichtung).
	var world_x: float = center.x + tile.x * STREET_TILE_SIZE - STREET_TILE_SIZE / 2.0
	var world_z: float = center.z + tile.y * STREET_TILE_SIZE - STREET_TILE_SIZE / 2.0
	return Vector3i(floori(world_x / STREET_TILE_SIZE), 0, floori(world_z / STREET_TILE_SIZE))


# Fahrzeug-Pathing (2026-08-01, Kartenplanungs-Session, letzter offener
# Punkt — der ursprüngliche Auslöser der ganzen Session). Bewusst KEIN
# `NavigationServer3D`/gebackenes Navigationsmesh (wäre eigene Collision-
# Erfassung pro Gebäude + Bake-Schritt nötig, deutlich größerer Umbau) —
# stattdessen ein simpler Wegpunkt-Graph aus genau denselben Straßen-
# Kachel-Daten, die schon für die Straßen-Sicht-Geometrie existieren
# (_zone_street_tiles()). Nur INNERHALB von Stadt-Zonen aktiv — in der
# Wildnis (keine Straßen-Daten vorhanden) bleibt es bei der bisherigen
# Luftlinie, was dort auch inhaltlich richtig ist (keine echten Straßen
# zwischen den Zonen).
#
# **Korrektur (2026-08-02, Nutzer-Report "fährt über das Gras statt über
# die Straße"):** ursprünglich pathete dies über Block-MITTEN
# (_compute_zone_blocks(), 36m-Raster) statt über die tatsächlichen
# Straßen-Kacheln. Zwei benachbarte Block-Mitten liegen 36m auseinander,
# ein Block ist aber 24m breit — die direkte Linie zwischen zwei
# Block-Mitten verläuft dadurch zu zwei Dritteln (24 von 36m) mitten durchs
# Blockinnere (Gras) und nur ein Drittel auf der eigentlichen Straße.
# Jetzt pathet es stattdessen direkt über die 12m-Straßen-Kacheln selbst
# (dieselben Positionen wie die sichtbare Straßen-Geometrie) — jedes
# Wegstück zwischen zwei Wegpunkten liegt damit vollständig auf Straße.
#
# **Zweite Korrektur (2026-08-02, direkt im Anschluss, Nutzer-Report "ein
# bisschen versetzt ist er noch"):** die Wegpunkte hatten einen
# systematischen halben Kachel-Versatz (6m) gegenüber der tatsächlich
# sichtbaren Kachel-Position. `$StreetGridMap` hat `cell_center_x`/
# `cell_center_z` auf dem Godot-Standard `true` (nur `cell_center_y` ist
# explizit `false` gesetzt, siehe World.tscn) — dadurch zentriert
# `_zone_tile_cell()` jede Kachel automatisch einen halben `STREET_TILE_
# SIZE`-Schritt gegenüber der rohen `center + tile*STREET_TILE_SIZE`-
# Rechnung. Die neuen Pathing-Funktionen unten haben diesen Versatz nicht
# nachvollzogen. Fix: `_street_tile_world_pos()` kapselt jetzt exakt
# dieselbe Formel wie `_zone_tile_cell()`, von `_nearest_street_tile()`
# UND der Wegpunkt-Umrechnung hier gemeinsam genutzt — keine zwei
# unabhängigen Kopien der Umrechnung mehr, die auseinanderlaufen können.
func find_vehicle_path(from: Vector3, to: Vector3) -> Array:
	var zone_index := _zone_index_containing(to)
	if zone_index == -1:
		return [to]
	var center: Vector3 = _city_zone_centers[zone_index]
	var radius: float = CITY_ZONE_RADIUS_LARGE if zone_index < CITY_ZONE_LARGE_COUNT else CITY_ZONE_RADIUS_SMALL
	var street_tiles: Dictionary = _zone_street_tiles(center, radius)
	if street_tiles.is_empty():
		return [to]
	var start_tile: Vector2i = _nearest_street_tile(from, center, street_tiles)
	var end_tile: Vector2i = _nearest_street_tile(to, center, street_tiles)
	var tile_path: Array = _bfs_grid_path(street_tiles, start_tile, end_tile)
	var world_path: Array = []
	for tile in tile_path:
		var pos: Vector2 = _street_tile_world_pos(center, tile)
		world_path.append(Vector3(pos.x, to.y, pos.y))
	# Letztes Stück vom nächsten Straßen-Knoten zum eigentlichen Ziel
	# (z. B. ein Gebäude leicht abseits der Straße, siehe
	# BUILDING_ROW_INSET) bleibt Luftlinie — Fahrzeuge kollidieren ohnehin
	# nur mit Mauern/Toren, nicht mit Gebäuden (siehe
	# Vehicle._is_path_blocked(), OBSTACLE_LAYER), ein kurzer letzter
	# Diagonal-Schlenker ist hier kein Problem.
	world_path.append(to)
	return world_path


func _zone_index_containing(pos: Vector3) -> int:
	for i in _city_zone_centers.size():
		var center: Vector3 = _city_zone_centers[i]
		var radius: float = CITY_ZONE_RADIUS_LARGE if i < CITY_ZONE_LARGE_COUNT else CITY_ZONE_RADIUS_SMALL
		if Vector2(pos.x, pos.z).distance_to(Vector2(center.x, center.z)) <= radius:
			return i
	return -1


# Weltposition (X/Z) der Kachel-MITTE, exakt dieselbe Formel wie
# _zone_tile_cell() (siehe dort für die Begründung des -STREET_TILE_SIZE/2-
# Versatzes: $StreetGridMap hat cell_center_x/cell_center_z auf dem
# Godot-Standard true, verschiebt jede Kachel dadurch einen halben
# Kachel-Schritt gegenüber der rohen center+tile*STREET_TILE_SIZE-Rechnung).
func _street_tile_world_pos(center: Vector3, tile: Vector2i) -> Vector2:
	return Vector2(
		center.x + tile.x * STREET_TILE_SIZE - STREET_TILE_SIZE / 2.0,
		center.z + tile.y * STREET_TILE_SIZE - STREET_TILE_SIZE / 2.0
	)


func _nearest_street_tile(pos: Vector3, center: Vector3, street_tiles: Dictionary) -> Vector2i:
	var best_tile := Vector2i.ZERO
	var best_dist: float = INF
	for tile in street_tiles:
		var tile_pos: Vector2 = _street_tile_world_pos(center, tile)
		var d: float = Vector2(pos.x, pos.z).distance_squared_to(tile_pos)
		if d < best_dist:
			best_dist = d
			best_tile = tile
	return best_tile


func _bfs_grid_path(cells: Dictionary, start: Vector2i, end: Vector2i) -> Array:
	# Generisches BFS über ein beliebiges Vector2i-Zellraster (aktuell nur
	# für Straßen-Kacheln genutzt, siehe find_vehicle_path()) — reines BFS
	# statt gewichtetem A*, da jede Kante gleich lang ist, findet also
	# automatisch den kürzesten Weg, ohne Prioritäts-Warteschlange. Ein
	# paar tausend Knoten pro Zone, aber nur einmalig pro Bewegungsbefehl
	# — kein wiederkehrender Kostenfaktor.
	if start == end:
		return [start]
	var frontier: Array = [start]
	var came_from: Dictionary = {start: start}
	var directions := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == end:
			break
		for direction in directions:
			var next_cell: Vector2i = current + direction
			if cells.has(next_cell) and not came_from.has(next_cell):
				came_from[next_cell] = current
				frontier.append(next_cell)
	if not came_from.has(end):
		# Sollte bei einem zusammenhängenden Straßennetz (siehe
		# _zone_street_tiles(), aus dem Blockraster abgeleitet) nicht
		# vorkommen — defensiver Fallback statt Absturz.
		return [start]
	var path: Array = []
	var node: Vector2i = end
	while node != start:
		path.append(node)
		node = came_from[node]
	path.append(start)
	path.reverse()
	return path


func _generate_forest_zone(center: Vector3) -> void:
	# Dichtes Baum-Cluster statt der dünnen Wildnis-Streuung (siehe
	# _spawn_wilderness_resources() unten) — der eigentliche visuelle/
	# thematische Unterschied, siehe TREES_PER_FOREST_ZONE oben. Plus ein
	# Jagdstand pro Zone über denselben Building-Spawner wie Stadt-Gebäude,
	# aber mit der festen FOREST_BUILDING_TEMPLATE statt eines zufälligen
	# Eintrags aus BUILDING_TYPES.
	for i in TREES_PER_FOREST_ZONE:
		var pos := _spaced_position(center, FOREST_ZONE_RADIUS, TREE_GROUND_Y)
		tree_spawner.spawn({"id": _next_tree_id, "position": pos})
		_next_tree_id += 1
	var building_size: Vector3 = FOREST_BUILDING_TEMPLATE["size"]
	var building_pos := _spaced_position(center, FOREST_ZONE_RADIUS, building_size.y / 2.0, BUILDING_MIN_SPACING)
	building_spawner.spawn({
		"id": _next_building_id,
		"position": building_pos,
		"size": building_size,
		"loot": FOREST_BUILDING_TEMPLATE["loot"],
		"default_color": FOREST_BUILDING_TEMPLATE["default_color"],
		"has_survivor": false,
		"zone_center": center,
	})
	_next_building_id += 1


func _spawn_wilderness_resources() -> void:
	# Ersetzt die frühere _spawn_initial_resources() — Ressourcen über die
	# GANZE Karte verteilt statt nur um die Kartenmitte (siehe TREES_TOTAL &
	# Co. oben, bewusst nicht proportional zur Fläche hochskaliert).
	for i in TREES_TOTAL:
		var pos := _random_wilderness_position(TREE_GROUND_Y)
		tree_spawner.spawn({"id": _next_tree_id, "position": pos})
		_next_tree_id += 1
	for i in CAR_WRECKS_TOTAL:
		var pos := _random_wilderness_position(CAR_WRECK_GROUND_Y)
		car_wreck_spawner.spawn({"id": _next_car_wreck_id, "position": pos})
		_next_car_wreck_id += 1
	for i in STONE_PILES_TOTAL:
		var pos := _random_wilderness_position(STONE_PILE_GROUND_Y)
		stone_pile_spawner.spawn({"id": _next_stone_pile_id, "position": pos})
		_next_stone_pile_id += 1
	for i in BRICK_PILES_TOTAL:
		var pos := _random_wilderness_position(BRICK_PILE_GROUND_Y)
		brick_pile_spawner.spawn({"id": _next_brick_pile_id, "position": pos})
		_next_brick_pile_id += 1


func _regrow_resources() -> void:
	# Siehe RESOURCE_REGROWTH_INTERVAL oben — höchstens ein neuer Knoten pro
	# Typ pro Aufruf, nie über die jeweilige TOTAL-Konstante hinaus (eigene
	# Typ-Gruppe wie "tree" statt der gemeinsamen "harvestable"-Gruppe, sonst
	# könnte z. B. ein komplett leergeerntetes Holz-Vorkommen fälschlich als
	# "voll" gelten, nur weil noch genug Steine/Ziegel/Wracks übrig sind).
	if get_tree().get_nodes_in_group("tree").size() < TREES_TOTAL:
		var pos := _random_wilderness_position(TREE_GROUND_Y)
		tree_spawner.spawn({"id": _next_tree_id, "position": pos})
		_next_tree_id += 1
	if get_tree().get_nodes_in_group("car_wreck").size() < CAR_WRECKS_TOTAL:
		var pos := _random_wilderness_position(CAR_WRECK_GROUND_Y)
		car_wreck_spawner.spawn({"id": _next_car_wreck_id, "position": pos})
		_next_car_wreck_id += 1
	if get_tree().get_nodes_in_group("stone_pile").size() < STONE_PILES_TOTAL:
		var pos := _random_wilderness_position(STONE_PILE_GROUND_Y)
		stone_pile_spawner.spawn({"id": _next_stone_pile_id, "position": pos})
		_next_stone_pile_id += 1
	if get_tree().get_nodes_in_group("brick_pile").size() < BRICK_PILES_TOTAL:
		var pos := _random_wilderness_position(BRICK_PILE_GROUND_Y)
		brick_pile_spawner.spawn({"id": _next_brick_pile_id, "position": pos})
		_next_brick_pile_id += 1


func _random_wilderness_position(ground_y: float) -> Vector3:
	# Wie _spaced_position(), aber zusätzlich außerhalb ALLER Stadt-Zonen
	# (sonst könnte ein Baum mitten auf einer Straße wachsen) — eigene
	# Funktion statt _is_far_enough_from_others() zu erweitern, weil genau
	# das bei der Gebäude-/Fahrzeug-/Nest-Platzierung INNERHALB einer Zone
	# falsch wäre (die sollen ja gerade nah am Zonen-Zentrum liegen).
	var half_map: float = MAP_SIZE / 2.0
	var candidate := Vector3(0.0, ground_y, 0.0)
	for attempt in SPACING_ATTEMPTS:
		var offset := Vector3(randf_range(-half_map, half_map), 0, randf_range(-half_map, half_map))
		candidate = Vector3(offset.x, ground_y, offset.z)
		if _is_far_enough_from_others(candidate) and _is_far_from_city_zones(candidate):
			return candidate
	return candidate


func _is_far_from_city_zones(candidate: Vector3) -> bool:
	# Nutzt bewusst IMMER den großen Zonen-Radius als Sicherheitsabstand,
	# auch für kleine Zonen (seit den zwei Zonengrößen, siehe
	# CITY_ZONE_RADIUS_LARGE/_SMALL) — hält Wildnis-Ressourcen bei kleinen
	# Zonen etwas großzügiger fern als nötig, spart aber eine eigene
	# Radius-Verwaltung pro Zonen-Zentrum (_city_zone_centers bleibt ein
	# einfaches Array[Vector3] statt Center+Radius-Paaren).
	for zone_center in _city_zone_centers:
		var dx: float = candidate.x - zone_center.x
		var dz: float = candidate.z - zone_center.z
		if dx * dx + dz * dz < CITY_ZONE_RADIUS_LARGE * CITY_ZONE_RADIUS_LARGE:
			return false
	return true


func _spaced_position(center: Vector3, radius: float, ground_y: float, min_spacing: float = MIN_RESOURCE_SPACING) -> Vector3:
	# Nutzerwunsch: "alles was im Spiel spawnt soll ein bisschen Platz
	# dazwischen haben" — probiert bis zu SPACING_ATTEMPTS Zufallspositionen
	# im Radius um center, bis eine gefunden ist, die min_spacing von jedem
	# bereits existierenden Gebäude/Fahrzeug/Zombie-Nest/anderen
	# Ressourcenknoten entfernt ist. min_spacing ist optional (Standard
	# MIN_RESOURCE_SPACING) — Gebäude-Platzierung übergibt stattdessen das
	# größere BUILDING_MIN_SPACING (siehe _generate_city_zone()), weil
	# Gebäude spürbar größer sind als Ressourcenknoten. Akzeptiert nach den
	# Versuchen auch eine zu nahe Position, statt endlos zu probieren oder
	# das Spawnen ganz zu verhindern.
	var candidate := Vector3(center.x, ground_y, center.z)
	for attempt in SPACING_ATTEMPTS:
		var offset := Vector3(randf_range(-radius, radius), 0, randf_range(-radius, radius))
		candidate = Vector3(center.x + offset.x, ground_y, center.z + offset.z)
		if _is_far_enough_from_others(candidate, min_spacing):
			return candidate
	return candidate


func _is_far_enough_from_others(candidate: Vector3, min_spacing: float = MIN_RESOURCE_SPACING) -> bool:
	for group_name in ["harvestable", "searchable", "vehicle", "zombie_nest"]:
		for other in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(other):
				continue
			var dx: float = candidate.x - other.position.x
			var dz: float = candidate.z - other.position.z
			if dx * dx + dz * dz < min_spacing * min_spacing:
				return false
	return true


func save_game() -> void:
	# Aufgerufen von PauseMenu (Button dort nur für multiplayer.is_server()
	# sichtbar, siehe docs/save_load.md) — reine Koordination: SaveManager
	# kennt nur Datei-I/O, nicht den Inhalt; World.gd kennt den Inhalt, nicht
	# die Datei.
	var ok := SaveManager.save_to_disk(_collect_save_data())
	report_status(multiplayer.get_unique_id(), "Spielstand gespeichert." if ok else "Speichern fehlgeschlagen.")


func _collect_save_data() -> Dictionary:
	# Liest ausschließlich den eigenen (Host-)Node-Baum — der Host ist die
	# einzige Instanz mit autoritativem Zustand (siehe docs/save_load.md).
	var data: Dictionary = {}
	data["day_time"] = _day_time
	data["day_count"] = _day_count
	data["next_ids"] = {
		"survivor": _next_survivor_id,
		"nest_zombie": _next_nest_zombie_id,
		"tree": _next_tree_id,
		"car_wreck": _next_car_wreck_id,
		"stone_pile": _next_stone_pile_id,
		"brick_pile": _next_brick_pile_id,
		"guard_post": _next_guard_post_id,
		"wall": _next_wall_id,
		"medical_station": _next_medical_station_id,
		"workshop": _next_workshop_id,
		"storage": _next_storage_id,
		"bed": _next_bed_id,
		"field": _next_field_id,
		"outpost": _next_outpost_id,
		"building": _next_building_id,
		"vehicle": _next_vehicle_id,
		"zombie_nest": _next_zombie_nest_id,
	}
	data["city_zone_centers"] = _city_zone_centers.duplicate()
	data["forest_zone_centers"] = _forest_zone_centers.duplicate()

	var home_bases: Array = []
	for base in home_bases_container.get_children():
		home_bases.append({
			"peer_id": base.owner_peer_id,
			"position": base.position,
			"resources": base.resources.duplicate(),
			"storage_capacity": base.storage_capacity,
		})
	data["home_bases"] = home_bases

	var survivors: Array = []
	for survivor in survivors_container.get_children():
		survivors.append({
			"id": survivor.trupp_id,
			"peer_id": survivor.owner_peer_id,
			"position": survivor.position,
			"hp": survivor.hp,
			"hunger": survivor.hunger,
			"fatigue": survivor.fatigue,
			"morale": survivor.morale,
			"carried_loot": survivor.carried_loot.duplicate(),
			"troop_type": survivor.troop_type,
			"is_armed": survivor.is_armed,
			"is_wearing_armor": survivor.is_wearing_armor,
			"has_helmet": survivor.has_helmet,
			"secondary_weapon": survivor.secondary_weapon,
			"has_leg_armor": survivor.has_leg_armor,
		})
	data["survivors"] = survivors

	var zombies: Array = []
	for zombie in zombies_container.get_children():
		zombies.append({
			"index": zombie.zombie_id,
			"position": zombie.position,
			"hp": zombie.hp,
			"is_brute": zombie.is_brute,
		})
	data["zombies"] = zombies

	var guard_posts: Array = []
	for post in guard_posts_container.get_children():
		guard_posts.append({
			"id": post.guard_post_id,
			"peer_id": post.owner_peer_id,
			"position": post.position,
			"built": post.built,
		})
	data["guard_posts"] = guard_posts

	var walls: Array = []
	for wall in walls_container.get_children():
		walls.append({
			"id": wall.wall_id,
			"peer_id": wall.owner_peer_id,
			"position": wall.position,
			"rotation_y": wall.rotation.y,
			"is_gate": wall.is_gate,
		})
	data["walls"] = walls

	var medical_stations: Array = []
	for station in medical_stations_container.get_children():
		medical_stations.append({"id": station.medical_station_id, "peer_id": station.owner_peer_id, "position": station.position})
	data["medical_stations"] = medical_stations

	var workshops: Array = []
	for workshop in workshops_container.get_children():
		workshops.append({"id": workshop.workshop_id, "peer_id": workshop.owner_peer_id, "position": workshop.position})
	data["workshops"] = workshops

	var storages: Array = []
	for storage in storages_container.get_children():
		storages.append({"id": storage.storage_id, "peer_id": storage.owner_peer_id, "position": storage.position, "capacity": storage.capacity_bonus})
	data["storages"] = storages

	var beds: Array = []
	for bed in beds_container.get_children():
		beds.append({"id": bed.bed_id, "peer_id": bed.owner_peer_id, "position": bed.position})
	data["beds"] = beds

	var fields: Array = []
	for field in fields_container.get_children():
		fields.append({"id": field.field_id, "peer_id": field.owner_peer_id, "position": field.position})
	data["fields"] = fields

	var outposts: Array = []
	for outpost in outposts_container.get_children():
		outposts.append({"id": outpost.outpost_id, "peer_id": outpost.owner_peer_id, "position": outpost.position})
	data["outposts"] = outposts

	var trees: Array = []
	for tree in trees_container.get_children():
		trees.append({"id": tree.tree_id, "position": tree.position, "hp": tree.hp, "is_marked": tree.is_marked})
	data["trees"] = trees

	var car_wrecks: Array = []
	for wreck in car_wrecks_container.get_children():
		car_wrecks.append({"id": wreck.wreck_id, "position": wreck.position, "hp": wreck.hp, "is_marked": wreck.is_marked})
	data["car_wrecks"] = car_wrecks

	var stone_piles: Array = []
	for pile in stone_piles_container.get_children():
		stone_piles.append({"id": pile.pile_id, "position": pile.position, "hp": pile.hp, "is_marked": pile.is_marked})
	data["stone_piles"] = stone_piles

	var brick_piles: Array = []
	for pile in brick_piles_container.get_children():
		brick_piles.append({"id": pile.pile_id, "position": pile.position, "hp": pile.hp, "is_marked": pile.is_marked})
	data["brick_piles"] = brick_piles

	# Seit dem Kartenumbau (siehe docs/world.md, "Kartengröße") sind
	# Buildings/Vehicles/ZombieNests Spawner-Entities wie Trees/Zombies —
	# genau wie dort reicht Container-Iteration, keine feste Namensliste
	# und keine "demolished"/"destroyed"-Sonderfälle mehr nötig: ein
	# zerstörtes/abgerissenes Exemplar ist einfach nicht mehr im Container,
	# taucht also von selbst nicht im gespeicherten Array auf (echte
	# Vereinfachung gegenüber vorher).
	var buildings: Array = []
	for building in buildings_container.get_children():
		buildings.append({
			"id": building.building_id,
			"position": building.position,
			"zone_center": building.zone_center,
			"size": (building.get_node("Mesh").mesh as BoxMesh).size,
			"loot": building.loot.duplicate(),
			"default_color": building.default_color,
			"has_survivor": building.has_survivor,
			"is_looted": building.is_looted,
			"owner_peer_id": building.owner_peer_id,
			"hp": building.hp,
		})
	data["buildings"] = buildings

	var vehicles: Array = []
	for vehicle in vehicles_container.get_children():
		vehicles.append({"id": vehicle.vehicle_id, "position": vehicle.position, "hp": vehicle.hp, "vehicle_type": vehicle.vehicle_type})
	data["vehicles"] = vehicles

	var zombie_nests: Array = []
	for nest in zombie_nests_container.get_children():
		zombie_nests.append({"id": nest.zombie_nest_id, "position": nest.position, "hp": nest.hp})
	data["zombie_nests"] = zombie_nests

	return data


func _load_game_state(data: Dictionary) -> void:
	# Gegenstück zu _collect_save_data() — ersetzt den normalen Frisch-Start
	# (siehe _ready()). Nutzt überall dieselben xxx_spawner.spawn()-Aufrufe
	# wie das normale Spiel (repliziert also automatisch genauso), nur mit
	# Daten aus der Save-Datei statt frisch generierten Positionen.
	_day_time = data.get("day_time", 0.0)
	_day_count = data.get("day_count", 0)
	var next_ids: Dictionary = data.get("next_ids", {})
	_next_survivor_id = next_ids.get("survivor", 0)
	_next_nest_zombie_id = next_ids.get("nest_zombie", CITY_ZONE_COUNT * ZOMBIES_PER_ZONE)
	_next_tree_id = next_ids.get("tree", 0)
	_next_car_wreck_id = next_ids.get("car_wreck", 0)
	_next_stone_pile_id = next_ids.get("stone_pile", 0)
	_next_brick_pile_id = next_ids.get("brick_pile", 0)
	_next_guard_post_id = next_ids.get("guard_post", 0)
	_next_wall_id = next_ids.get("wall", 0)
	_next_medical_station_id = next_ids.get("medical_station", 0)
	_next_workshop_id = next_ids.get("workshop", 0)
	_next_storage_id = next_ids.get("storage", 0)
	_next_bed_id = next_ids.get("bed", 0)
	_next_field_id = next_ids.get("field", 0)
	_next_outpost_id = next_ids.get("outpost", 0)
	_next_building_id = next_ids.get("building", 0)
	_next_vehicle_id = next_ids.get("vehicle", 0)
	_next_zombie_nest_id = next_ids.get("zombie_nest", 0)
	_city_zone_centers.clear()
	for zone_center in data.get("city_zone_centers", []):
		_city_zone_centers.append(zone_center)
	_forest_zone_centers.clear()
	for zone_center in data.get("forest_zone_centers", []):
		_forest_zone_centers.append(zone_center)

	for entry in data.get("home_bases", []):
		var base := home_base_spawner.spawn({"peer_id": entry["peer_id"], "position": entry["position"]})
		if is_instance_valid(base):
			base.resources = entry["resources"]
			base.storage_capacity = entry["storage_capacity"]

	for entry in data.get("survivors", []):
		# hp/hunger/carried_loot/troop_type/is_armed/is_wearing_armor/
		# has_helmet werden schon in _create_survivor() angewendet (siehe
		# dort) — keine Timing-Falle wie bei Zombie, weil Survivor._ready()
		# diese Felder nicht neu berechnet.
		survivor_spawner.spawn({
			"id": entry["id"],
			"peer_id": entry["peer_id"],
			"position": entry["position"],
			"hp": entry["hp"],
			"hunger": entry["hunger"],
			"fatigue": entry.get("fatigue", 100.0),
			"morale": entry.get("morale", 100.0),
			"carried_loot": entry["carried_loot"],
			"troop_type": entry["troop_type"],
			"is_armed": entry.get("is_armed", false),
			"is_wearing_armor": entry.get("is_wearing_armor", false),
			"has_helmet": entry.get("has_helmet", false),
			"secondary_weapon": entry.get("secondary_weapon", false),
			"has_leg_armor": entry.get("has_leg_armor", false),
		})

	for entry in data.get("zombies", []):
		# hp wird erst NACH dem Spawnen gesetzt (siehe _create_zombie()) —
		# Zombie._ready() berechnet hp = _max_hp abhängig von is_brute, ein
		# vorher gesetzter Wert würde sofort überschrieben.
		var zombie := zombie_spawner.spawn({"index": entry["index"], "position": entry["position"], "is_brute": entry["is_brute"]})
		if is_instance_valid(zombie):
			zombie.hp = entry["hp"]

	for entry in data.get("guard_posts", []):
		guard_post_spawner.spawn({"id": entry["id"], "peer_id": entry["peer_id"], "position": entry["position"], "built": entry["built"]})

	for entry in data.get("walls", []):
		wall_spawner.spawn({"id": entry["id"], "peer_id": entry["peer_id"], "position": entry["position"], "rotation_y": entry["rotation_y"], "is_gate": entry["is_gate"]})

	for entry in data.get("medical_stations", []):
		medical_station_spawner.spawn({"id": entry["id"], "peer_id": entry["peer_id"], "position": entry["position"]})

	for entry in data.get("workshops", []):
		workshop_spawner.spawn({"id": entry["id"], "peer_id": entry["peer_id"], "position": entry["position"]})

	for entry in data.get("storages", []):
		storage_spawner.spawn({"id": entry["id"], "peer_id": entry["peer_id"], "position": entry["position"], "capacity": entry["capacity"]})

	for entry in data.get("beds", []):
		bed_spawner.spawn({"id": entry["id"], "peer_id": entry["peer_id"], "position": entry["position"]})

	for entry in data.get("fields", []):
		field_spawner.spawn({"id": entry["id"], "peer_id": entry["peer_id"], "position": entry["position"]})

	for entry in data.get("outposts", []):
		outpost_spawner.spawn({"id": entry["id"], "peer_id": entry["peer_id"], "position": entry["position"]})

	for entry in data.get("trees", []):
		tree_spawner.spawn({"id": entry["id"], "position": entry["position"], "hp": entry["hp"], "is_marked": entry["is_marked"]})

	for entry in data.get("car_wrecks", []):
		car_wreck_spawner.spawn({"id": entry["id"], "position": entry["position"], "hp": entry["hp"], "is_marked": entry["is_marked"]})

	for entry in data.get("stone_piles", []):
		stone_pile_spawner.spawn({"id": entry["id"], "position": entry["position"], "hp": entry["hp"], "is_marked": entry["is_marked"]})

	for entry in data.get("brick_piles", []):
		brick_pile_spawner.spawn({"id": entry["id"], "position": entry["position"], "hp": entry["hp"], "is_marked": entry["is_marked"]})

	# Seit dem Kartenumbau (siehe docs/world.md, "Kartengröße") reicht ein
	# einfacher spawn()-Aufruf pro gespeichertem Eintrag (wie bei Trees/
	# Zombies) — _create_building()/_create_vehicle()/_create_zombie_nest()
	# kennen schon alle nötigen optionalen Felder (hp/is_looted/
	# owner_peer_id), kein Nachträglich-Patchen über take_damage()/
	# mark_looted() mehr nötig. Ein beim Speichern schon
	# zerstörtes/abgerissenes Exemplar taucht im Array einfach gar nicht
	# erst auf (siehe _collect_save_data()), muss also auch beim Laden
	# nicht extra behandelt werden.
	for entry in data.get("buildings", []):
		building_spawner.spawn(entry)

	for entry in data.get("vehicles", []):
		# hp wird erst NACH dem Spawnen gesetzt (siehe _create_vehicle()) —
		# Vehicle._ready() berechnet hp = _max_hp abhängig vom vehicle_type,
		# ein vorher gesetzter Wert würde sofort überschrieben.
		var vehicle := vehicle_spawner.spawn(entry)
		if is_instance_valid(vehicle):
			vehicle.hp = entry["hp"]

	for entry in data.get("zombie_nests", []):
		zombie_nest_spawner.spawn(entry)


func _on_toggle_build_mode_pressed(type: BuildType) -> void:
	# Ein-Klick-Modus: schaltet sich nach der nächsten Platzierung
	# automatisch wieder ab, kein Dauer-Baumodus (siehe docs/building.md).
	# Erneutes Klicken auf denselben Button schaltet aus; ein anderer
	# Bau-Button wechselt stattdessen direkt den Bautyp.
	if _build_mode and _build_type == type:
		_build_mode = false
	else:
		_build_mode = true
		_build_type = type
	_update_build_button_texts()


func _on_upgrade_building_pressed(upgrade_type: BuildType) -> void:
	if not is_instance_valid(_selected_claimed_building):
		return
	request_upgrade_building.rpc_id(1, _selected_claimed_building.get_path(), upgrade_type, multiplayer.get_unique_id())
	# Optimistisch sofort zurücksetzen (siehe docs/building.md, "Ausbauen")
	# statt auf die serverseitige Bestätigung zu warten — dieselbe
	# UI-Auswahl könnte sonst versehentlich einen zweiten Ausbau desselben,
	# eigentlich schon ersetzten Gebäudes anstoßen.
	_selected_claimed_building = null


func _update_build_button_texts() -> void:
	# Zeigt den tatsächlichen (ggf. werkstattrabattierten) Preis live an,
	# statt der festen *_BUTTON_TEXT-Konstante — sonst sieht ein Rabatt beim
	# Draufschauen aus wie "kommt gar nicht an" (schon mal beim Testen zu
	# Verwirrung geführt, siehe docs/building.md, "Werkstatt").
	var peer_id := multiplayer.get_unique_id()
	build_button.text = BUILD_MODE_ACTIVE_TEXT if (_build_mode and _build_type == BuildType.GUARD_POST) else _build_button_label("Wachposten", BuildType.GUARD_POST, peer_id)
	wall_button.text = BUILD_MODE_ACTIVE_TEXT if (_build_mode and _build_type == BuildType.WALL) else _build_button_label("Mauer", BuildType.WALL, peer_id)
	gate_button.text = BUILD_MODE_ACTIVE_TEXT if (_build_mode and _build_type == BuildType.GATE) else _build_button_label("Tor", BuildType.GATE, peer_id)
	field_button.text = BUILD_MODE_ACTIVE_TEXT if (_build_mode and _build_type == BuildType.FIELD) else _build_button_label("Feld", BuildType.FIELD, peer_id)
	outpost_button.text = BUILD_MODE_ACTIVE_TEXT if (_build_mode and _build_type == BuildType.OUTPOST) else _build_button_label("Außenposten", BuildType.OUTPOST, peer_id)
	_refresh_building_upgrade_ui(peer_id)


func _refresh_building_upgrade_ui(peer_id: int) -> void:
	# Ausbauen (siehe docs/building.md, "Ausbauen") — Abschnitt im
	# "Bauen"-Tab nur sichtbar, solange ein eigenes, geclaimtes Gebäude
	# ausgewählt ist (siehe World._select_at(), "searchable"-Branch).
	var has_selection := is_instance_valid(_selected_claimed_building)
	upgrade_separator.visible = has_selection
	upgrade_label.visible = has_selection
	upgrade_medical_button.visible = has_selection
	upgrade_workshop_button.visible = has_selection
	upgrade_storage_button.visible = has_selection
	upgrade_bed_button.visible = has_selection
	if not has_selection:
		return
	upgrade_label.text = "Ausbauen:"
	upgrade_medical_button.text = _build_button_label("Zu Krankenstation", BuildType.MEDICAL_STATION, peer_id)
	upgrade_workshop_button.text = _build_button_label("Zu Werkstatt", BuildType.WORKSHOP, peer_id)
	# Zeigt zusätzlich die tatsächliche Kapazität DIESES Gebäudes (siehe
	# docs/building.md, "Lager") — anders als die anderen beiden hängt der
	# Nutzen hier vom konkret ausgewählten Gebäude ab, nicht nur von den
	# Kosten.
	var capacity := int(round(_building_volume(_selected_claimed_building) * STORAGE_CAPACITY_PER_VOLUME))
	upgrade_storage_button.text = "%s (+%d Kapazität)" % [_build_button_label("Zu Lager", BuildType.STORAGE, peer_id), capacity]
	upgrade_bed_button.text = _build_button_label("Zu Schlafraum", BuildType.BED, peer_id)


func _build_button_label(display_name: String, type: BuildType, peer_id: int) -> String:
	# Generisch über RESOURCE_DISPLAY_NAMES statt fest auf "materials"/
	# "Baumaterial" verdrahtet — jeder Bautyp braucht jetzt eine andere
	# Rohstoffart (siehe docs/base.md, "Vier Baurohstoffe"), funktioniert
	# aber auch für einen künftigen Mehr-Ressourcen-Kostenblock.
	var cost := _cost_for_build_type(type, peer_id)
	var parts: Array = []
	for key in cost:
		parts.append("%d %s" % [cost[key], RESOURCE_DISPLAY_NAMES.get(key, key)])
	return "%s bauen (%s)" % [display_name, ", ".join(parts)]


@rpc("any_peer", "call_local", "reliable")
func request_build_structure(type: BuildType, build_position: Vector3, requesting_peer_id: int) -> void:
	# call_local Pflicht, weil rpc_id(1, ...) beim Host sich selbst anspricht.
	# Ein RPC für alle Einzelklick-Bautypen (Wachposten/Feld) — sie
	# unterscheiden sich nur in Szene/Kosten/Spawner. Mauer/Tor haben ihr
	# eigenes RPC (request_build_wall_line), weil sie mehrere Segmente pro
	# Aufruf brauchen (siehe docs/walls.md). Krankenstation/Werkstatt sind
	# hier NICHT mehr erreichbar (Baumenü-Umbau, Nutzerwunsch) — die
	# entstehen jetzt über request_upgrade_building(), siehe dort.
	if not multiplayer.is_server():
		return
	var cost := _cost_for_build_type(type, requesting_peer_id)
	if not _can_build_at(requesting_peer_id, build_position, cost, type):
		_report_build_failure(requesting_peer_id, build_position, cost)
		return
	var base := _find_home_base_for_peer(requesting_peer_id)
	var cost_delta := {}
	for key in cost:
		cost_delta[key] = -cost[key]
	base.add_resources.rpc(cost_delta)
	match type:
		BuildType.FIELD:
			field_spawner.spawn({"id": _next_field_id, "peer_id": requesting_peer_id, "position": build_position})
			_next_field_id += 1
		BuildType.OUTPOST:
			outpost_spawner.spawn({"id": _next_outpost_id, "peer_id": requesting_peer_id, "position": build_position})
			_next_outpost_id += 1
		_:
			guard_post_spawner.spawn({"id": _next_guard_post_id, "peer_id": requesting_peer_id, "position": build_position})
			_next_guard_post_id += 1


@rpc("any_peer", "call_local", "reliable")
func request_upgrade_building(building_path: NodePath, upgrade_type: BuildType, requesting_peer_id: int) -> void:
	# Baumenü-Umbau (siehe docs/building.md, "Ausbauen"): Krankenstation/
	# Werkstatt entstehen nicht mehr durch freies Platzieren, sondern durch
	# Ausbauen eines bereits geplünderten UND vom Spieler selbst geclaimten
	# Gebäudes. Ersetzt das Building am selben Platz durch die jeweilige
	# Struktur — kein neues RPC für die Entfernung nötig,
	# building.take_damage(building.hp) räumt es sauber (netzwerksicher)
	# über den schon bestehenden Abriss-Pfad weg (siehe
	# docs/survivor.md, "Gebäude abreißen"), ohne dabei (anders als beim
	# echten Abreißen) Rohstoffe auszuzahlen.
	if not multiplayer.is_server():
		return
	var building := get_node_or_null(building_path)
	if building == null or building.owner_peer_id != requesting_peer_id:
		return
	var cost := _cost_for_build_type(upgrade_type, requesting_peer_id)
	if not _can_afford(requesting_peer_id, cost):
		report_status(requesting_peer_id, "Nicht genug Ressourcen.")
		return
	var base := _find_home_base_for_peer(requesting_peer_id)
	var cost_delta := {}
	for key in cost:
		cost_delta[key] = -cost[key]
	base.add_resources.rpc(cost_delta)
	var build_position: Vector3 = building.position
	# Volumen VOR dem Entfernen berechnen (siehe docs/building.md, "Lager")
	# — building.take_damage() räumt den Node zwar erst am Frame-Ende
	# tatsächlich weg (queue_free()), aber sauberer, die Mesh-Größe
	# auszulesen, bevor der Abriss-Pfad überhaupt losläuft.
	var volume := _building_volume(building)
	building.take_damage(building.hp)
	match upgrade_type:
		BuildType.WORKSHOP:
			workshop_spawner.spawn({"id": _next_workshop_id, "peer_id": requesting_peer_id, "position": build_position})
			_next_workshop_id += 1
		BuildType.STORAGE:
			var capacity := int(round(volume * STORAGE_CAPACITY_PER_VOLUME))
			storage_spawner.spawn({"id": _next_storage_id, "peer_id": requesting_peer_id, "position": build_position, "capacity": capacity})
			_next_storage_id += 1
		BuildType.BED:
			bed_spawner.spawn({"id": _next_bed_id, "peer_id": requesting_peer_id, "position": build_position})
			_next_bed_id += 1
		_:
			medical_station_spawner.spawn({"id": _next_medical_station_id, "peer_id": requesting_peer_id, "position": build_position})
			_next_medical_station_id += 1


func _building_volume(building: Node3D) -> float:
	# Breite×Höhe×Tiefe der Gebäude-BoxMesh (siehe docs/building.md,
	# "Lager") — Grundlage für die Lager-Kapazität. `as BoxMesh` statt
	# direktem Feldzugriff, weil `MeshInstance3D.mesh` statisch nur als
	# `Mesh` (Basisklasse ohne `.size`) typisiert ist.
	var mesh_node: MeshInstance3D = building.get_node_or_null("Mesh")
	if mesh_node == null:
		return 0.0
	var box_mesh := mesh_node.mesh as BoxMesh
	if box_mesh == null:
		return 0.0
	return box_mesh.size.x * box_mesh.size.y * box_mesh.size.z


@rpc("any_peer", "call_local", "reliable")
func request_build_wall_line(positions: Array, line_rotation_y: float, requesting_peer_id: int, is_gate: bool) -> void:
	# call_local Pflicht, siehe request_build_structure(). Ein RPC für
	# beliebig viele Segmente (auch nur eins, bei einem reinen Klick ohne
	# Ziehen, siehe World._finish_wall_drag()) — jedes Segment wird einzeln
	# geprüft/bezahlt, in der Reihenfolge des Zugs. Bricht beim ersten
	# Segment ab, das sich nicht mehr leisten lässt (add_resources.rpc() ist
	# call_local, der Host sieht die Kosten des vorigen Segments also schon
	# VOR der nächsten Prüfung) — wer mehr zieht, als er sich leisten kann,
	# bekommt einfach eine kürzere Mauer statt eines Fehlers.
	if not multiplayer.is_server():
		return
	var cost := _cost_for_build_type(BuildType.GATE if is_gate else BuildType.WALL, requesting_peer_id)
	var built_count := 0
	for build_position in positions:
		if not _can_build_at(requesting_peer_id, build_position, cost):
			break
		var base := _find_home_base_for_peer(requesting_peer_id)
		var cost_delta := {}
		for key in cost:
			cost_delta[key] = -cost[key]
		base.add_resources.rpc(cost_delta)
		wall_spawner.spawn({"id": _next_wall_id, "peer_id": requesting_peer_id, "position": build_position, "rotation_y": line_rotation_y, "is_gate": is_gate})
		_next_wall_id += 1
		built_count += 1
	if built_count == 0 and not positions.is_empty():
		# Kein Feedback bei teilweisem Erfolg (Zug läuft einfach früher aus,
		# siehe docs/walls.md) — nur wenn NICHTS gebaut werden konnte.
		_report_build_failure(requesting_peer_id, positions[0], cost)


func _find_home_base_for_peer(peer_id: int) -> Node3D:
	for base in home_bases_container.get_children():
		if base.owner_peer_id == peer_id:
			return base
	return null


func _refresh_worker_ui() -> void:
	# Komplettes Neuaufbauen statt Einzelupdate, gleiches simples Muster wie
	# Lobby._refresh_player_list() (docs/networking.md).
	for child in workers_list.get_children():
		child.queue_free()
	for post in guard_posts_container.get_children():
		if post.owner_peer_id != multiplayer.get_unique_id():
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "Wachposten %d: %d Arbeiter" % [post.guard_post_id, post.worker_count]
		row.add_child(label)
		var button := Button.new()
		button.text = "Arbeiter schicken"
		button.pressed.connect(_on_request_worker_pressed.bind(post))
		row.add_child(button)
		if post.worker_count > 0:
			# Gegenstück zu "Arbeiter schicken" — zieht einen Arbeiter wieder
			# ab, macht ihn wieder zu einer frei bewegbaren Einheit (siehe
			# docs/building.md, "Fehlermeldungen"-Nachbarabschnitt "Arbeiter
			# zuweisen"). Nur sichtbar, wenn überhaupt jemand stationiert ist.
			var recall_button := Button.new()
			recall_button.text = "Arbeiter abziehen"
			recall_button.pressed.connect(_on_recall_worker_pressed.bind(post))
			row.add_child(recall_button)
		workers_list.add_child(row)


func _on_request_worker_pressed(post: Node3D) -> void:
	if not is_instance_valid(post):
		return
	post.request_worker.rpc_id(1, multiplayer.get_unique_id())


func _on_recall_worker_pressed(post: Node3D) -> void:
	if not is_instance_valid(post):
		return
	post.request_recall_worker.rpc_id(1, multiplayer.get_unique_id())


func _refresh_crafting_ui() -> void:
	# Sichtbar nur mit eigener gebauter Werkstatt (siehe CRAFTING_RECIPES
	# oben) — komplettes Neuaufbauen statt Einzelupdate, gleiches Muster wie
	# _refresh_worker_ui(). Drei Zustände pro Rezept (siehe
	# docs/building.md, "Forschungsbücher"): erforscht (normaler
	# Herstellen-Button), Buch vorhanden aber noch nicht erforscht
	# (Erforschen-Button), weder erforscht noch Buch vorhanden (deaktivierter
	# Hinweis-Button).
	var peer_id := multiplayer.get_unique_id()
	var has_workshop := _has_own_workshop(peer_id)
	# Seit dem UI-Overhaul (siehe docs/world.md) ist "Herstellen" ein Tab im
	# gemeinsamen MainTabsUI-TabContainer statt eines eigenen CanvasLayer —
	# blendet den ganzen TAB aus statt eines Panels.
	main_tabs.set_tab_hidden(main_tabs.get_tab_idx_from_control(crafting_tab), not has_workshop)
	if not has_workshop:
		return
	for child in crafting_recipe_list.get_children():
		child.queue_free()
	var base := _find_own_home_base()
	for recipe in CRAFTING_RECIPES:
		var recipe_id: String = recipe["id"]
		var unlocked: bool = base != null and base.unlocked_recipes.get(recipe_id, false)
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 12)
		if unlocked:
			button.text = _craft_button_label(recipe)
			button.pressed.connect(_on_craft_pressed.bind(recipe_id))
		else:
			var book_type := "book_%s" % recipe_id
			var has_book: bool = base != null and base.resources.get(book_type, 0) > 0
			button.text = "%s erforschen (%s)" % [recipe["name"], RESOURCE_DISPLAY_NAMES.get(book_type, book_type)]
			button.disabled = not has_book
			button.pressed.connect(_on_research_pressed.bind(recipe_id))
		crafting_recipe_list.add_child(button)


func _craft_button_label(recipe: Dictionary) -> String:
	var cost: Dictionary = recipe["cost"]
	var cost_parts: Array = []
	for key in cost:
		cost_parts.append("%d %s" % [cost[key], RESOURCE_DISPLAY_NAMES.get(key, key)])
	var recipe_yield: Dictionary = recipe["yield"]
	var yield_parts: Array = []
	for key in recipe_yield:
		yield_parts.append("%d %s" % [recipe_yield[key], RESOURCE_DISPLAY_NAMES.get(key, key)])
	return "%s (%s) → %s" % [recipe["name"], ", ".join(cost_parts), ", ".join(yield_parts)]


func _on_craft_pressed(recipe_id: String) -> void:
	request_craft.rpc_id(1, recipe_id, multiplayer.get_unique_id())


func _on_research_pressed(recipe_id: String) -> void:
	request_research.rpc_id(1, recipe_id, multiplayer.get_unique_id())


func _find_recipe(recipe_id: String) -> Dictionary:
	for recipe in CRAFTING_RECIPES:
		if recipe["id"] == recipe_id:
			return recipe
	return {}


@rpc("any_peer", "call_local", "reliable")
func request_craft(recipe_id: String, requesting_peer_id: int) -> void:
	# Braucht eine eigene, gebaute Werkstatt (siehe CRAFTING_RECIPES oben) —
	# dieselbe Prüfung wie beim Werkstatt-Rabatt (_has_own_workshop()), aber
	# hier eine Pflicht statt nur eines Rabatts. Seit den Forschungsbüchern
	# (siehe docs/building.md, "Forschungsbücher") zusätzlich: das Rezept
	# muss erst über request_research() freigeschaltet worden sein.
	if not multiplayer.is_server():
		return
	if not _has_own_workshop(requesting_peer_id):
		report_status(requesting_peer_id, "Braucht eine eigene Werkstatt.")
		return
	var recipe := _find_recipe(recipe_id)
	if recipe.is_empty():
		return
	var base := _find_home_base_for_peer(requesting_peer_id)
	if base == null or not base.unlocked_recipes.get(recipe_id, false):
		report_status(requesting_peer_id, "Rezept noch nicht erforscht.")
		return
	var cost: Dictionary = recipe["cost"]
	if not _can_afford(requesting_peer_id, cost):
		report_status(requesting_peer_id, "Nicht genug Ressourcen.")
		return
	# Kosten UND Ertrag in einem einzigen add_resources()-Aufruf (Abzug +
	# Gutschrift überschneiden sich nie in denselben Ressourcenarten, siehe
	# CRAFTING_RECIPES — Kosten sind immer Basis-Rohstoffe, Ertrag immer ein
	# Ausrüstungsgegenstand).
	var delta: Dictionary = {}
	for key in cost:
		delta[key] = -cost[key]
	var recipe_yield: Dictionary = recipe["yield"]
	for key in recipe_yield:
		delta[key] = delta.get(key, 0) + recipe_yield[key]
	base.add_resources.rpc(delta)


@rpc("any_peer", "call_local", "reliable")
func request_research(recipe_id: String, requesting_peer_id: int) -> void:
	# Forschungsbücher (siehe docs/building.md, "Forschungsbücher") —
	# verbraucht 1× "book_<recipe_id>" aus der eigenen Home-Base, schaltet
	# das passende Rezept DAUERHAFT frei (HomeBase.unlock_recipe(), kein
	# Vergessen). Braucht bewusst KEINE eigene Werkstatt (Lesen geht überall,
	# nur das eigentliche Herstellen ist an die Werkstatt gebunden).
	if not multiplayer.is_server():
		return
	var recipe := _find_recipe(recipe_id)
	if recipe.is_empty():
		return
	var base := _find_home_base_for_peer(requesting_peer_id)
	if base == null:
		return
	if base.unlocked_recipes.get(recipe_id, false):
		return
	var book_type := "book_%s" % recipe_id
	if base.resources.get(book_type, 0) <= 0:
		report_status(requesting_peer_id, "Kein passendes Buch vorhanden.")
		return
	base.add_resources.rpc({book_type: -1})
	base.unlock_recipe.rpc(recipe_id)


# Handel (siehe docs/trading.md, Punkt 14 der Gesamtliste) — Nutzerwunsch:
# "kann schenken kann aber auch tauschen", also beide Varianten aus der
# Vision-Kurzbeschreibung ("Spieler können Ressourcen untereinander
# tauschen/geben") umgesetzt statt nur einer.
func _populate_resource_option(option: OptionButton) -> void:
	option.clear()
	for key in RESOURCE_DISPLAY_NAMES:
		option.add_item(RESOURCE_DISPLAY_NAMES[key])
		option.set_item_metadata(option.item_count - 1, key)


func _refresh_trade_ui() -> void:
	var own_id := multiplayer.get_unique_id()
	var current_peer_ids: Array = NetworkManager.players.keys().filter(
		func(id: int) -> bool: return id != own_id
	)
	if current_peer_ids != _trade_peer_ids_cache:
		_trade_peer_ids_cache = current_peer_ids
		var previous_peer: int = -1
		if trade_peer_option.item_count > 0:
			previous_peer = trade_peer_option.get_item_metadata(trade_peer_option.get_selected())
		trade_peer_option.clear()
		for peer_id in current_peer_ids:
			var info: Dictionary = NetworkManager.players.get(peer_id, {})
			trade_peer_option.add_item("%s (Spieler %d)" % [info.get("name", "Spieler"), peer_id])
			trade_peer_option.set_item_metadata(trade_peer_option.item_count - 1, peer_id)
			if peer_id == previous_peer:
				trade_peer_option.select(trade_peer_option.item_count - 1)
	for child in trade_offers_list.get_children():
		child.queue_free()
	for offer in _trade_offers:
		if offer["from_peer"] != own_id and offer["to_peer"] != own_id:
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 12)
		var offer_text: String = "%d× %s" % [
			offer["offer_amount"], RESOURCE_DISPLAY_NAMES.get(offer["offer_resource"], offer["offer_resource"])
		]
		var want_text: String = "%d× %s" % [
			offer["want_amount"], RESOURCE_DISPLAY_NAMES.get(offer["want_resource"], offer["want_resource"])
		]
		if offer["from_peer"] == own_id:
			label.text = "An Spieler %d: %s gegen %s" % [offer["to_peer"], offer_text, want_text]
			row.add_child(label)
			var cancel_button := Button.new()
			cancel_button.add_theme_font_size_override("font_size", 12)
			cancel_button.text = "Zurückziehen"
			cancel_button.pressed.connect(_on_trade_offer_decline_pressed.bind(offer["id"]))
			row.add_child(cancel_button)
		else:
			label.text = "Von Spieler %d: %s gegen %s" % [offer["from_peer"], offer_text, want_text]
			row.add_child(label)
			var accept_button := Button.new()
			accept_button.add_theme_font_size_override("font_size", 12)
			accept_button.text = "Annehmen"
			accept_button.pressed.connect(_on_trade_offer_accept_pressed.bind(offer["id"]))
			row.add_child(accept_button)
			var decline_button := Button.new()
			decline_button.add_theme_font_size_override("font_size", 12)
			decline_button.text = "Ablehnen"
			decline_button.pressed.connect(_on_trade_offer_decline_pressed.bind(offer["id"]))
			row.add_child(decline_button)
		trade_offers_list.add_child(row)


func _on_gift_pressed() -> void:
	if trade_peer_option.item_count == 0:
		return
	var to_peer: int = trade_peer_option.get_item_metadata(trade_peer_option.get_selected())
	var resource_id: String = trade_gift_resource_option.get_item_metadata(trade_gift_resource_option.get_selected())
	var amount := int(trade_gift_amount_spinbox.value)
	request_gift_resources.rpc_id(1, to_peer, resource_id, amount, multiplayer.get_unique_id())


func _on_trade_offer_pressed() -> void:
	if trade_peer_option.item_count == 0:
		return
	var to_peer: int = trade_peer_option.get_item_metadata(trade_peer_option.get_selected())
	var offer_resource: String = trade_offer_resource_option.get_item_metadata(trade_offer_resource_option.get_selected())
	var offer_amount := int(trade_offer_amount_spinbox.value)
	var want_resource: String = trade_want_resource_option.get_item_metadata(trade_want_resource_option.get_selected())
	var want_amount := int(trade_want_amount_spinbox.value)
	request_create_trade_offer.rpc_id(
		1, to_peer, offer_resource, offer_amount, want_resource, want_amount, multiplayer.get_unique_id()
	)


func _on_trade_offer_accept_pressed(offer_id: int) -> void:
	request_accept_trade_offer.rpc_id(1, offer_id, multiplayer.get_unique_id())


func _on_trade_offer_decline_pressed(offer_id: int) -> void:
	request_decline_trade_offer.rpc_id(1, offer_id, multiplayer.get_unique_id())


func _find_trade_offer(offer_id: int) -> Dictionary:
	for offer in _trade_offers:
		if offer["id"] == offer_id:
			return offer
	return {}


func _remove_trade_offer(offer_id: int) -> void:
	for i in _trade_offers.size():
		if _trade_offers[i]["id"] == offer_id:
			_trade_offers.remove_at(i)
			break
	_sync_trade_offers.rpc(_trade_offers)


@rpc("authority", "call_local", "reliable")
func _sync_trade_offers(offers: Array) -> void:
	_trade_offers = offers
	_refresh_trade_ui()


@rpc("any_peer", "call_local", "reliable")
func request_gift_resources(to_peer_id: int, resource_id: String, amount: int, requesting_peer_id: int) -> void:
	# Einseitiges Schenken — kein Gegenangebot/keine Bestätigung nötig,
	# schlankste der beiden Handel-Varianten (siehe "Tauschen" unten für die
	# Gegenstück-Variante mit Annahme-Flow).
	if not multiplayer.is_server():
		return
	if amount <= 0 or to_peer_id == requesting_peer_id:
		return
	var from_base := _find_home_base_for_peer(requesting_peer_id)
	var to_base := _find_home_base_for_peer(to_peer_id)
	if from_base == null or to_base == null:
		return
	if from_base.resources.get(resource_id, 0) < amount:
		report_status(requesting_peer_id, "Nicht genug Ressourcen zum Verschenken.")
		return
	from_base.add_resources.rpc({resource_id: -amount})
	to_base.add_resources.rpc({resource_id: amount})
	var display_name: String = RESOURCE_DISPLAY_NAMES.get(resource_id, resource_id)
	report_status(requesting_peer_id, "%d× %s verschenkt." % [amount, display_name])
	report_status(to_peer_id, "%d× %s von Spieler %d erhalten." % [amount, display_name, requesting_peer_id])


@rpc("any_peer", "call_local", "reliable")
func request_create_trade_offer(
	to_peer_id: int, offer_resource: String, offer_amount: int, want_resource: String, want_amount: int, requesting_peer_id: int
) -> void:
	# Echtes Tausch-Angebot — nur ANLEGEN hier, die eigentliche Ressourcen-
	# Bewegung passiert erst bei request_accept_trade_offer(). Vorab-Prüfung
	# hier nur eine Komfort-Bremse (kein Angebot anlegen, das der Ersteller
	# offensichtlich schon jetzt nicht bezahlen kann) — bei der Annahme wird
	# TROTZDEM nochmal geprüft, da sich der Bestand zwischenzeitlich geändert
	# haben kann (siehe request_accept_trade_offer()).
	if not multiplayer.is_server():
		return
	if offer_amount <= 0 or want_amount <= 0 or to_peer_id == requesting_peer_id:
		return
	var from_base := _find_home_base_for_peer(requesting_peer_id)
	var to_base := _find_home_base_for_peer(to_peer_id)
	if from_base == null or to_base == null:
		return
	if from_base.resources.get(offer_resource, 0) < offer_amount:
		report_status(requesting_peer_id, "Nicht genug Ressourcen für dieses Angebot.")
		return
	_trade_offers.append({
		"id": _next_trade_offer_id,
		"from_peer": requesting_peer_id,
		"to_peer": to_peer_id,
		"offer_resource": offer_resource,
		"offer_amount": offer_amount,
		"want_resource": want_resource,
		"want_amount": want_amount,
	})
	_next_trade_offer_id += 1
	_sync_trade_offers.rpc(_trade_offers)
	report_status(requesting_peer_id, "Tauschangebot verschickt.")
	report_status(to_peer_id, "Neues Tauschangebot erhalten.")


@rpc("any_peer", "call_local", "reliable")
func request_accept_trade_offer(offer_id: int, requesting_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var offer := _find_trade_offer(offer_id)
	if offer.is_empty() or offer["to_peer"] != requesting_peer_id:
		return
	var from_base := _find_home_base_for_peer(offer["from_peer"])
	var to_base := _find_home_base_for_peer(offer["to_peer"])
	if from_base == null or to_base == null:
		_remove_trade_offer(offer_id)
		return
	var offer_resource: String = offer["offer_resource"]
	var offer_amount: int = offer["offer_amount"]
	var want_resource: String = offer["want_resource"]
	var want_amount: int = offer["want_amount"]
	if from_base.resources.get(offer_resource, 0) < offer_amount:
		report_status(requesting_peer_id, "Anbieter hat nicht mehr genug Ressourcen.")
		_remove_trade_offer(offer_id)
		return
	if to_base.resources.get(want_resource, 0) < want_amount:
		report_status(requesting_peer_id, "Nicht genug eigene Ressourcen zum Annehmen.")
		return
	# Über ein Dictionary statt zweier Einzel-Deltas gebaut, damit der
	# Sonderfall offer_resource == want_resource (Tausch derselben Art)
	# nicht zwei sich widersprechende Keys im selben add_resources()-Aufruf
	# erzeugt (gleiches Muster wie request_craft() für Kosten+Ertrag).
	var from_delta: Dictionary = {}
	from_delta[offer_resource] = from_delta.get(offer_resource, 0) - offer_amount
	from_delta[want_resource] = from_delta.get(want_resource, 0) + want_amount
	var to_delta: Dictionary = {}
	to_delta[want_resource] = to_delta.get(want_resource, 0) - want_amount
	to_delta[offer_resource] = to_delta.get(offer_resource, 0) + offer_amount
	from_base.add_resources.rpc(from_delta)
	to_base.add_resources.rpc(to_delta)
	_remove_trade_offer(offer_id)
	report_status(offer["from_peer"], "Tauschangebot angenommen.")
	report_status(requesting_peer_id, "Tausch abgeschlossen.")


@rpc("any_peer", "call_local", "reliable")
func request_decline_trade_offer(offer_id: int, requesting_peer_id: int) -> void:
	# Von BEIDEN Seiten aufrufbar — Empfänger lehnt ab ODER Ersteller zieht
	# das eigene Angebot zurück, gleicher RPC für beide Fälle.
	if not multiplayer.is_server():
		return
	var offer := _find_trade_offer(offer_id)
	if offer.is_empty():
		return
	if offer["to_peer"] != requesting_peer_id and offer["from_peer"] != requesting_peer_id:
		return
	var from_peer: int = offer["from_peer"]
	var to_peer: int = offer["to_peer"]
	_remove_trade_offer(offer_id)
	report_status(from_peer, "Tauschangebot abgelehnt/zurückgezogen.")
	report_status(to_peer, "Tauschangebot abgelehnt/zurückgezogen.")


func _refresh_units_ui() -> void:
	for child in units_list.get_children():
		child.queue_free()
	for survivor in _find_own_survivors():
		# Zweizeilig statt einer einzigen breiten HBoxContainer-Zeile
		# (Nutzer-Feedback: UI zu groß/unübersichtlich, seit dem
		# "Ausrüsten"-Button lief die Zeile über die Panel-Breite hinaus) —
		# Zeile 1 = kompakter Statustext, Zeile 2 = alle Buttons, dazu
		# kürzere Button-Beschriftungen und kleinere Schrift.
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 0)
		var label := Label.new()
		var type_label := "Feld" if survivor.troop_type == survivor.TroopType.FIELD else "Bau"
		label.text = "T%d %s HP%d H%d Mü%d Mo%d" % [survivor.trupp_id, type_label, survivor.hp, int(survivor.hunger), int(survivor.fatigue), int(survivor.morale)]
		if survivor.is_armed:
			label.text += " [W]"
		if survivor.is_wearing_armor:
			label.text += " [R]"
		if survivor.has_helmet:
			label.text += " [H]"
		if survivor.secondary_weapon:
			label.text += " [S]"
		if survivor.has_leg_armor:
			label.text += " [B]"
		var carried: int = _carried_total(survivor.carried_loot)
		if carried > 0:
			label.text += " +%d/%d" % [carried, survivor.CARRY_CAPACITY]
		label.add_theme_font_size_override("font_size", 13)
		entry.add_child(label)
		var button_row := HBoxContainer.new()
		button_row.add_theme_constant_override("separation", 2)
		var select_button := Button.new()
		select_button.text = "Wähl."
		select_button.add_theme_font_size_override("font_size", 12)
		select_button.pressed.connect(_on_select_unit_pressed.bind(survivor))
		button_row.add_child(select_button)
		var type_button := Button.new()
		# Zeigt das Umschalt-ZIEL, nicht den aktuellen Typ (Nutzer klickt auf
		# das, was er haben will) — siehe docs/survivor.md, "Trupp-Arten".
		type_button.text = "→Bau" if survivor.troop_type == survivor.TroopType.FIELD else "→Feld"
		type_button.add_theme_font_size_override("font_size", 12)
		type_button.pressed.connect(_on_toggle_troop_type_pressed.bind(survivor))
		button_row.add_child(type_button)
		# Ausrüsten-Buttons (Waffe/Rüstung) sind ins Trupp-Detailfenster
		# gewandert (siehe _update_unit_detail_panel(), docs/survivor.md,
		# "Rüstungssystem") — Nutzer-Feedback: die kompakte Liste sollte
		# klein/übersichtlich bleiben, [W]/[R] oben reicht als Kurzindikator.
		for g in range(1, GROUP_UI_COUNT + 1):
			var in_group: bool = _control_groups.has(g) and survivor in _control_groups[g]
			var group_button := Button.new()
			group_button.text = "✓%d" % g if in_group else str(g)
			group_button.add_theme_font_size_override("font_size", 12)
			group_button.pressed.connect(_on_toggle_group_pressed.bind(survivor, g))
			button_row.add_child(group_button)
		entry.add_child(button_row)
		units_list.add_child(entry)


func _update_unit_detail_panel() -> void:
	# Trupp-Detailfenster (siehe docs/survivor.md, "Rüstungssystem") — Tab
	# nur ANWÄHLBAR bei genau einem ausgewählten eigenen Survivor
	# (has_method("is_sheltered") als Survivor-vs-Fahrzeug-Unterscheidung,
	# gleiches Muster wie in Zombie.gd etabliert). set_tab_hidden() statt
	# eines eigenen visible-Togglens (siehe _refresh_crafting_ui() für
	# dasselbe Muster) — schaltet NICHT automatisch auf den Tab um, wechselt
	# nur, ob er überhaupt anwählbar ist (kein erzwungener Fokuswechsel
	# mitten in einer anderen Tab-Aktion).
	var tab_idx: int = main_tabs.get_tab_idx_from_control(unit_detail_tab)
	if selected.size() != 1 or not is_instance_valid(selected[0]) or not selected[0].has_method("is_sheltered"):
		main_tabs.set_tab_hidden(tab_idx, true)
		_unit_detail_survivor = null
		return
	var survivor: Node3D = selected[0]
	_unit_detail_survivor = survivor
	main_tabs.set_tab_hidden(tab_idx, false)
	var type_label := "Feld" if survivor.troop_type == survivor.TroopType.FIELD else "Bau"
	var carried: int = _carried_total(survivor.carried_loot)
	unit_detail_stats_label.text = "Trupp %d (%s)\nHP: %d/%d\nHunger: %d\nMüdigkeit: %d\nMoral: %d\nLoot: %d/%d" % [
		survivor.trupp_id, type_label, survivor.hp, survivor.MAX_HP, int(survivor.hunger), int(survivor.fatigue), int(survivor.morale), carried, survivor.CARRY_CAPACITY,
	]
	if survivor.is_armed:
		unit_detail_weapon_label.text = "Waffe: ausgerüstet"
		unit_detail_weapon_button.visible = false
	else:
		unit_detail_weapon_label.text = "Waffe: keine"
		# Nur Feldtrupps können sich bewaffnen, siehe order_equip_weapon().
		unit_detail_weapon_button.visible = survivor.troop_type == survivor.TroopType.FIELD
	if survivor.is_wearing_armor:
		unit_detail_armor_label.text = "Brustpanzer: getragen"
		unit_detail_armor_button.visible = false
	else:
		unit_detail_armor_label.text = "Brustpanzer: keine"
		# Kein Trupp-Arten-Filter bei Rüstung, siehe order_equip_armor().
		unit_detail_armor_button.visible = true
	if survivor.has_helmet:
		unit_detail_helmet_label.text = "Helm: getragen"
		unit_detail_helmet_button.visible = false
	else:
		unit_detail_helmet_label.text = "Helm: keiner"
		# Kein Trupp-Arten-Filter, siehe order_equip_helmet().
		unit_detail_helmet_button.visible = true
	if survivor.secondary_weapon:
		unit_detail_secondary_weapon_label.text = "Nahkampfwaffe: ausgerüstet"
		unit_detail_secondary_weapon_button.visible = false
	else:
		unit_detail_secondary_weapon_label.text = "Nahkampfwaffe: keine"
		# Nur Feldtrupps, wie die Hauptwaffe, siehe order_equip_secondary_weapon().
		unit_detail_secondary_weapon_button.visible = survivor.troop_type == survivor.TroopType.FIELD
	if survivor.has_leg_armor:
		unit_detail_leg_armor_label.text = "Beinschutz: getragen"
		unit_detail_leg_armor_button.visible = false
	else:
		unit_detail_leg_armor_label.text = "Beinschutz: keiner"
		# Kein Trupp-Arten-Filter, siehe order_equip_leg_armor().
		unit_detail_leg_armor_button.visible = true


func _on_select_unit_pressed(survivor: Node3D) -> void:
	if not is_instance_valid(survivor):
		return
	selected = [survivor]


func _on_toggle_troop_type_pressed(survivor: Node3D) -> void:
	if not is_instance_valid(survivor):
		return
	var new_type = survivor.TroopType.BUILD if survivor.troop_type == survivor.TroopType.FIELD else survivor.TroopType.FIELD
	survivor.set_troop_type.rpc_id(1, new_type, multiplayer.get_unique_id())


func _on_detail_equip_weapon_pressed() -> void:
	# Trupp-Detailfenster (siehe docs/survivor.md, "Rüstungssystem") — die
	# Buttons dort sind fest verdrahtet (kein Neu-Erzeugen pro Refresh wie
	# in _refresh_units_ui()), deshalb hier über _unit_detail_survivor
	# statt eines gebundenen Arguments.
	if is_instance_valid(_unit_detail_survivor):
		_unit_detail_survivor.order_equip_weapon.rpc_id(1, multiplayer.get_unique_id())


func _on_detail_equip_armor_pressed() -> void:
	if is_instance_valid(_unit_detail_survivor):
		_unit_detail_survivor.order_equip_armor.rpc_id(1, multiplayer.get_unique_id())


func _on_detail_equip_helmet_pressed() -> void:
	if is_instance_valid(_unit_detail_survivor):
		_unit_detail_survivor.order_equip_helmet.rpc_id(1, multiplayer.get_unique_id())


func _on_detail_equip_secondary_weapon_pressed() -> void:
	if is_instance_valid(_unit_detail_survivor):
		_unit_detail_survivor.order_equip_secondary_weapon.rpc_id(1, multiplayer.get_unique_id())


func _on_detail_equip_leg_armor_pressed() -> void:
	if is_instance_valid(_unit_detail_survivor):
		_unit_detail_survivor.order_equip_leg_armor.rpc_id(1, multiplayer.get_unique_id())


func _on_toggle_group_pressed(survivor: Node3D, group_number: int) -> void:
	if not is_instance_valid(survivor):
		return
	var group: Array = _control_groups.get(group_number, [])
	if survivor in group:
		group.erase(survivor)
	else:
		group.append(survivor)
	_control_groups[group_number] = group


func _process(delta: float) -> void:
	if multiplayer.is_server():
		# Muss VOR den Zombie-/Wachposten-_process()-Aufrufen desselben Frames
		# laufen (World ist deren Vorfahre im Szenenbaum, Godot verarbeitet
		# _process() in Baum-Reihenfolge, Eltern vor Kindern) — sonst würden
		# sie mit dem Grid-Stand vom Vorframe arbeiten. Eine gemeinsame
		# "zombie"-Gruppenabfrage für Grid-Aufbau UND Netzwerk-Sync-Bündelung
		# (siehe _sync_zombies_batch()) statt zwei getrennter pro Frame.
		var zombies := get_tree().get_nodes_in_group("zombie")
		_rebuild_zombie_grid(zombies)
		_sync_zombies_batch(zombies)
		_zombie_despawn_timer += delta
		if _zombie_despawn_timer >= ZOMBIE_DESPAWN_CHECK_INTERVAL:
			_zombie_despawn_timer = 0.0
			_despawn_far_zombies()
		_resource_regrowth_timer += delta
		if _resource_regrowth_timer >= RESOURCE_REGROWTH_INTERVAL:
			_resource_regrowth_timer = 0.0
			_regrow_resources()
	_handle_pan(delta)
	_update_hud()
	_update_build_ghost()
	_handle_day_night(delta)
	_fog_update_timer += delta
	if _fog_update_timer >= FOG_UPDATE_INTERVAL:
		_fog_update_timer = 0.0
		_update_fog_of_war()
	_worker_ui_timer += delta
	if _worker_ui_timer >= WORKER_UI_REFRESH_INTERVAL:
		_worker_ui_timer = 0.0
		_refresh_worker_ui()
		_refresh_units_ui()
		_update_build_button_texts()
		_update_unit_detail_panel()
		_update_zombie_count_label()
		_refresh_crafting_ui()
		_refresh_trade_ui()
	if status_label.visible:
		_status_message_timer -= delta
		if _status_message_timer <= 0.0:
			status_label.visible = false


func _raycast_position(screen_pos: Vector2) -> Variant:
	# Gemeinsamer Raycast-Helfer für alles, das nur den getroffenen
	# Weltpunkt braucht (Ghost-Preview, Mauer-Ziehen) — _select_at() macht
	# ihren eigenen Raycast, weil sie zusätzlich den Collider selbst
	# braucht (Auswahl/Gebäude-Erkennung).
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return result.position if result else null


func _update_build_ghost() -> void:
	# Platzierungs-Preview für den Baumodus: folgt der Maus (nicht dem
	# Klick, anders als der eigentliche Bauversuch), färbt sich grün/rot je
	# nachdem, ob an dieser Stelle tatsächlich gebaut werden dürfte
	# (dieselben Prüfungen wie beim Bauversuch — Radius um die eigene Basis
	# + genug Ressourcen). Rein optisch, kein Ersatz für die serverseitige
	# Prüfung beim tatsächlichen Bauversuch.
	if not _build_mode:
		build_ghost.visible = false
		_clear_ghost_line()
		return
	if _wall_drag_active:
		# Während des Ziehens übernimmt die Ghost-Linie (siehe
		# _update_wall_drag_ghost()) — der einzelne Ghost-Würfel bleibt aus.
		build_ghost.visible = false
		_update_wall_drag_ghost()
		return
	_clear_ghost_line()
	var screen_pos := get_viewport().get_mouse_position()
	var hit_position: Variant = _raycast_position(screen_pos)
	if hit_position == null:
		build_ghost.visible = false
		return
	build_ghost.visible = true
	build_ghost.position = hit_position
	# Wall/Gate laufen zwar übers Ziehen und erreichen diesen Zweig nie
	# (siehe _wall_drag_active oben), die Mesh-Auswahl bleibt trotzdem
	# generisch für alle Einzelklick-Bautypen (Wachposten/Krankenstation/
	# Werkstatt teilen sich die 1,5³-Box).
	build_ghost.mesh = _wall_ghost_mesh if _build_type in [BuildType.WALL, BuildType.GATE] else _guard_post_ghost_mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var peer_id := multiplayer.get_unique_id()
	var valid := _can_build_at(peer_id, hit_position, _cost_for_build_type(_build_type, peer_id), _build_type)
	mat.albedo_color = BUILD_GHOST_VALID_COLOR if valid else BUILD_GHOST_INVALID_COLOR
	build_ghost.material_override = mat


func _update_wall_drag_ghost() -> void:
	var end: Variant = _raycast_position(get_viewport().get_mouse_position())
	if end == null:
		_clear_ghost_line()
		return
	var line := _compute_wall_line(_wall_drag_start, end)
	var positions: Array = line["positions"]
	var line_rotation_y: float = line["rotation_y"]
	var cost := _cost_for_build_type(_build_type, multiplayer.get_unique_id())
	while _ghost_line_meshes.size() < positions.size():
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = _wall_ghost_mesh
		build_ghost_line.add_child(mesh_instance)
		_ghost_line_meshes.append(mesh_instance)
	for i in _ghost_line_meshes.size():
		var mesh_instance: MeshInstance3D = _ghost_line_meshes[i]
		if i >= positions.size():
			mesh_instance.visible = false
			continue
		mesh_instance.visible = true
		mesh_instance.position = positions[i]
		mesh_instance.rotation.y = line_rotation_y
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var valid := _can_build_at(multiplayer.get_unique_id(), positions[i], cost)
		mat.albedo_color = BUILD_GHOST_VALID_COLOR if valid else BUILD_GHOST_INVALID_COLOR
		mesh_instance.material_override = mat


func _clear_ghost_line() -> void:
	for mesh_instance in _ghost_line_meshes:
		mesh_instance.visible = false


func _compute_wall_line(start: Vector3, end: Vector3) -> Dictionary:
	# Ein Ort für Positions- UND Rotationsberechnung, damit beide garantiert
	# dieselbe (gerasterte) Richtung verwenden — würden sie getrennt
	# gerundet, könnten Segment-Reihe und ihre eigene Drehung leicht
	# auseinanderlaufen und sichtbare Lücken zeigen. Bei einem reinen Klick
	# ohne Ziehen (distance ~0) kommt genau ein Segment bei start heraus,
	# identisch zum alten Einzelklick-Verhalten.
	var raw_direction := end - start
	var distance := raw_direction.length()
	if distance < 0.01:
		return {"positions": [start], "rotation_y": 0.0}
	# Snap (siehe docs/walls.md, "Snap"): Zugrichtung rundet auf
	# WALL_SNAP_ANGLE (45°) — Mauer-BoxMesh ist 2×2×0.4 (siehe Wall.tscn),
	# die lange X-Achse (2 m) muss der (gerasterten) Zugrichtung folgen,
	# damit aufeinanderfolgende Segmente lückenlos aneinander anschließen.
	# Die 180°-Mehrdeutigkeit von atan2 ist irrelevant, der Quader ist um
	# die Y-Achse symmetrisch.
	var raw_angle := atan2(-raw_direction.z, raw_direction.x)
	var snapped_angle: float = round(raw_angle / WALL_SNAP_ANGLE) * WALL_SNAP_ANGLE
	var snapped_dir := Vector3(cos(snapped_angle), 0, -sin(snapped_angle))
	var count := int(round(distance / WALL_SEGMENT_LENGTH)) + 1
	var positions: Array = []
	for i in count:
		positions.append(start + snapped_dir * WALL_SEGMENT_LENGTH * i)
	return {"positions": positions, "rotation_y": snapped_angle}


func _snap_to_grid(position: Vector3) -> Vector3:
	# Rastert X/Z auf WALL_SEGMENT_LENGTH-Zellen (fest am Weltursprung, nicht
	# an der Home-Base) — mehrere Mauer-Züge, auch aus unterschiedlichen
	# Sessions, landen dadurch zuverlässig auf denselben Punkten statt an
	# der exakten, leicht ungenauen Maus-Position zu kleben (siehe
	# docs/walls.md, "Snap"). Fallback, falls kein bestehendes Mauerende in
	# der Nähe ist (siehe _nearest_wall_endpoint()) — deckt vor allem den
	# Fall ab, dass noch gar keine Mauer existiert.
	var snapped_x: float = round(position.x / WALL_SEGMENT_LENGTH) * WALL_SEGMENT_LENGTH
	var snapped_z: float = round(position.z / WALL_SEGMENT_LENGTH) * WALL_SEGMENT_LENGTH
	return Vector3(snapped_x, position.y, snapped_z)


func _nearest_wall_endpoint(hit_position: Vector3) -> Variant:
	# Magnetet den Startpunkt eines neuen Zugs ans nächste Ende einer schon
	# platzierten Mauer/eines Tors (siehe docs/walls.md, "Snap") — wichtig
	# vor allem bei diagonalen Segmenten (45°), deren Enden NICHT auf dem
	# achsenparallelen Weltraster von _snap_to_grid() liegen. Jedes Segment
	# hat zwei Enden, jeweils WALL_SEGMENT_LENGTH/2 vom Mittelpunkt entfernt
	# entlang seiner eigenen (evtl. gedrehten) Längsachse.
	var nearest_point: Vector3
	var nearest_dist := WALL_SNAP_ENDPOINT_RADIUS
	var found := false
	for wall in walls_container.get_children():
		var wall_dir := Vector3(cos(wall.rotation.y), 0, -sin(wall.rotation.y))
		var half := wall_dir * (WALL_SEGMENT_LENGTH / 2.0)
		for endpoint in [wall.position + half, wall.position - half]:
			var dist: float = hit_position.distance_to(endpoint)
			if dist < nearest_dist:
				nearest_point = endpoint
				nearest_dist = dist
				found = true
	return nearest_point if found else null


func _start_wall_drag(screen_pos: Vector2) -> void:
	var hit_position: Variant = _raycast_position(screen_pos)
	if hit_position == null:
		return
	_wall_drag_active = true
	# Erst versuchen, ans Ende einer bestehenden Mauer/eines Tors zu
	# snappen (näher am tatsächlichen Ziel des Nutzers: nahtlos anschließen)
	# — nur wenn nichts in der Nähe ist, aufs allgemeine Weltraster
	# zurückfallen.
	var endpoint_snap: Variant = _nearest_wall_endpoint(hit_position)
	_wall_drag_start = endpoint_snap if endpoint_snap != null else _snap_to_grid(hit_position)


func _finish_wall_drag(screen_pos: Vector2) -> void:
	_wall_drag_active = false
	_build_mode = false
	_update_build_button_texts()
	var end: Variant = _raycast_position(screen_pos)
	if end == null:
		return
	var line := _compute_wall_line(_wall_drag_start, end)
	var positions: Array = line["positions"]
	var line_rotation_y: float = line["rotation_y"]
	request_build_wall_line.rpc_id(1, positions, line_rotation_y, multiplayer.get_unique_id(), _build_type == BuildType.GATE)


func _cost_for_build_type(type: BuildType, peer_id: int) -> Dictionary:
	var base_cost: Dictionary
	match type:
		BuildType.WALL:
			base_cost = WALL_COST
		BuildType.GATE:
			base_cost = GATE_COST
		BuildType.MEDICAL_STATION:
			base_cost = MEDICAL_STATION_COST
		BuildType.WORKSHOP:
			base_cost = WORKSHOP_COST
		BuildType.FIELD:
			base_cost = FIELD_COST
		BuildType.STORAGE:
			base_cost = STORAGE_COST
		BuildType.OUTPOST:
			base_cost = OUTPOST_COST
		BuildType.BED:
			base_cost = BED_COST
		_:
			base_cost = GUARD_POST_COST
	# Werkstatt-Rabatt gilt für jeden ANDEREN Bautyp, nicht auf sich selbst
	# (siehe docs/building.md, "Werkstatt") — sonst müsste man schon eine
	# Werkstatt besitzen, um die erste günstiger zu bekommen.
	if type == BuildType.WORKSHOP or not _has_own_workshop(peer_id):
		return base_cost
	var discounted := {}
	for key in base_cost:
		discounted[key] = int(ceil(base_cost[key] * WORKSHOP_DISCOUNT))
	return discounted


func _has_own_workshop(peer_id: int) -> bool:
	for workshop in workshops_container.get_children():
		if workshop.owner_peer_id == peer_id:
			return true
	return false


func _can_build_at(peer_id: int, build_position: Vector3, cost: Dictionary, type: BuildType = BuildType.GUARD_POST) -> bool:
	# Dieselbe Prüfung wie request_build_structure()/request_build_wall_line()
	# (dort mit requesting_peer_id aufgerufen, hier fürs Ghost-Preview mit
	# der eigenen multiplayer.get_unique_id()) — ein Ort für die Regeln,
	# damit Preview und tatsächlicher Bauversuch nie auseinanderlaufen.
	# claim_building() nutzt das bewusst NICHT (siehe dort) — nur die reine
	# Ressourcenprüfung über _can_afford(). `type` optional mit
	# GUARD_POST-Standard (unkritisch: alle Bautypen außer OUTPOST prüfen
	# ohnehin dieselbe Zonen-Regel) — Außenposten ist laut Vision
	# (Infos/01 Architektur.md, "Außenposten") die einzige "Ausnahme von der
	# Zusammenhang-Regel", überspringt die Zonen-Prüfung deshalb bewusst.
	if type != BuildType.OUTPOST and not is_within_own_zone(peer_id, build_position):
		return false
	return _can_afford(peer_id, cost)


func _can_afford(peer_id: int, cost: Dictionary) -> bool:
	var base := _find_home_base_for_peer(peer_id)
	if base == null:
		return false
	for key in cost:
		if base.resources.get(key, 0) < cost[key]:
			return false
	return true


func is_within_own_zone(peer_id: int, position: Vector3) -> bool:
	# Die eigene Bauzone (siehe docs/zones.md): BUILD_RADIUS um die eigene
	# Home-Base ODER um jedes bereits geclaimte Gebäude dieses Spielers —
	# claimt man ein Gebäude, wächst die Zone dadurch organisch weiter.
	# Gilt NUR fürs Bauen von Wachposten/Mauer/etc., NICHT fürs Claimen
	# selbst (siehe claim_building() — die acht Gebäude liegen viel zu weit
	# von jeder Home-Base entfernt, um je "angrenzend" zu sein, siehe
	# docs/zones.md, "Warum Claimen ohne Abstandsprüfung").
	var base := _find_home_base_for_peer(peer_id)
	if base != null and base.position.distance_to(position) <= BUILD_RADIUS:
		return true
	for building in get_tree().get_nodes_in_group("searchable"):
		if building.owner_peer_id == peer_id and building.global_position.distance_to(position) <= BUILD_RADIUS:
			return true
	return false


func claim_building(peer_id: int, building: Node3D) -> void:
	# Aufgerufen von Survivor._claim_building() (schon host-seitig, siehe
	# dort). Bewusst OHNE Zonen-Abstandsprüfung (anders als
	# request_build_structure(), das is_within_own_zone() nutzt) — die acht
	# Gebäude liegen weit von jeder Home-Base entfernt (Kartenlayout, siehe
	# docs/zones.md), eine Zusammenhang-Regel wäre hier unspielbar: kein
	# Gebäude läge je innerhalb von BUILD_RADIUS der eigenen Basis. Claimen
	# braucht deshalb nur: geplündert, noch niemandem gehörend, bezahlbar —
	# danach wird das Gebäude selbst zum neuen Anker für
	# is_within_own_zone() (Bauen UND Weiter-Claimen benachbarter Gebäude).
	if not building.is_looted or building.owner_peer_id != 0:
		return
	if not _can_afford(peer_id, ZONE_CLAIM_COST):
		report_status(peer_id, "Nicht genug Ressourcen.")
		return
	var base := _find_home_base_for_peer(peer_id)
	var cost_delta := {}
	for key in ZONE_CLAIM_COST:
		cost_delta[key] = -ZONE_CLAIM_COST[key]
	base.add_resources.rpc(cost_delta)
	building.set_claimed_owner(peer_id)


@rpc("any_peer", "call_local", "reliable")
func request_choose_start_base(building_path: NodePath, requesting_peer_id: int) -> void:
	# call_local Pflicht, siehe request_build_structure() — rpc_id(1, ...)
	# beim Host zielt sonst auf sich selbst. Ersetzt die früheren festen
	# Kartenecken (HOME_BASE_POSITIONS/START_POSITIONS): jeder Peer wählt
	# beim Betreten von World.tscn eines der generierten Stadt-Gebäude als
	# eigene Start-Basis, siehe docs/zones.md, "Start-Basis wählen".
	# Kostenlos und ohne vorheriges Durchsuchen (anders als
	# claim_building()) — man startet ja dort, das Gebäude gilt als von
	# Anfang an gesichert.
	if not multiplayer.is_server():
		return
	if _find_home_base_for_peer(requesting_peer_id) != null:
		return  # Hat schon eine Basis gewählt, kein zweiter Versuch möglich.
	var building: Node3D = get_node_or_null(building_path)
	if building == null or not building.is_in_group("searchable") or building.owner_peer_id != 0:
		report_status(requesting_peer_id, "Dieses Gebäude ist schon vergeben.")
		return
	building.mark_looted.rpc()
	building.set_claimed_owner(requesting_peer_id)
	# Richtung von der ZONEN-Mitte weg (siehe docs/world.md, "Kartengröße"),
	# damit Home-Base/Survivor-Start nicht mitten im Gebäude-Mesh landen —
	# bei einem Gebäude genau im Zonen-Zentrum selbst (Länge ~0) Vector3(1,
	# 0, 0) als Fallback-Richtung. Vor dem Kartenumbau war das "weg vom
	# Weltursprung", weil ausnahmslos alle Gebäude nah am Ursprung lagen —
	# bricht mit mehreren, über die Karte verteilten Stadt-Zonen (siehe
	# Building.zone_center).
	var away := Vector3(building.position.x - building.zone_center.x, 0, building.position.z - building.zone_center.z)
	away = away.normalized() if away.length() > 0.01 else Vector3(1, 0, 0)
	var home_base_position := Vector3(building.position.x, 0.75, building.position.z) + away * BASE_CHOICE_HOME_OFFSET
	var survivor_position := Vector3(building.position.x, SURVIVOR_GROUND_Y, building.position.z) + away * BASE_CHOICE_SURVIVOR_OFFSET
	home_base_spawner.spawn({"peer_id": requesting_peer_id, "position": home_base_position})
	# Alle Start-Trupps seitlich zu "away" versetzt (90°, XZ-Ebene), NICHT
	# mit einem festen Welt-Vektor — der könnte je nach Gebäuderichtung
	# zurück Richtung/in das Gebäude-Mesh zeigen (Bug, vom Nutzer gemeldet:
	# "zweiter Spieler hatte nur eine Unit" — der zweite Trupp landete
	# dabei im Gebäude und war weder sichtbar noch anklickbar). Seitlicher
	# Versatz hält den Abstand zum Gebäude für JEDEN Trupp unabhängig von
	# dessen Position immer gleich groß — eine Reihe entlang "sideways",
	# zentriert um survivor_position, statt eines Rasters in beide Achsen.
	var sideways := Vector3(-away.z, 0, away.x)
	for i in START_SURVIVOR_COUNT:
		var lateral: float = (i - (START_SURVIVOR_COUNT - 1) / 2.0) * START_SURVIVOR_SPACING
		_spawn_survivor(requesting_peer_id, survivor_position + sideways * lateral)


@rpc("any_peer", "call_local", "reliable")
func request_toggle_harvest_mark(target_path: NodePath) -> void:
	# Markier-System (siehe docs/survivor.md, "Trupp-Arten", "Markier-
	# System") — gilt für jedes "harvestable" (Baum ODER Autowrack, siehe
	# docs/survivor.md). Jeder Spieler kann jedes Ziel markieren, kein
	# Besitz-Check nötig (geteilte Aufgabenliste, jeder freie Bautrupp
	# jedes Spielers greift zu). call_local Pflicht, siehe
	# request_build_structure().
	if not multiplayer.is_server():
		return
	var target := get_node_or_null(target_path)
	if target == null:
		return
	target.toggle_marked()


func _report_build_failure(peer_id: int, build_position: Vector3, cost: Dictionary) -> void:
	# Läuft NUR im Fehlerfall von request_build_structure()/
	# request_build_wall_line() (claim_building() hat sein eigenes,
	# einfacheres Feedback, siehe dort — keine Zonen-Abstandsprüfung),
	# ermittelt dafür extra den genauen Grund — bewusst getrennt von
	# _can_build_at() (bleibt dadurch ein einfacher, oft aufgerufener
	# Bool-Check fürs Ghost-Preview, ohne Text-Overhead jeden Frame).
	var base := _find_home_base_for_peer(peer_id)
	var message := "Keine eigene Basis gefunden."
	if base != null:
		if not is_within_own_zone(peer_id, build_position):
			message = "Zu weit von der eigenen Zone entfernt."
		else:
			message = "Nicht genug Ressourcen."
	report_status(peer_id, message)


func report_status(peer_id: int, message: String) -> void:
	# Öffentlich, damit auch andere Nodes (z. B. GuardPost.request_worker())
	# über get_tree().current_scene Feedback anzeigen können, gleiches
	# Muster wie Survivor._finish_search() -> World.spawn_recruit().
	_show_status_message.rpc_id(peer_id, message)


@rpc("authority", "call_local", "reliable")
func _show_status_message(message: String) -> void:
	status_label.text = message
	status_label.visible = true
	_status_message_timer = STATUS_MESSAGE_DURATION


func _update_hud() -> void:
	var own_base := _find_own_home_base()
	base_choice_label.visible = own_base == null
	var lines: Array = []
	var own_survivors := _find_own_survivors()
	if own_survivors.is_empty():
		lines.append("Keine eigenen Trupps")
	for survivor in own_survivors:
		var line := "Trupp %d — HP %d/%d, Hunger %d, Müdigkeit %d, Moral %d" % [survivor.trupp_id, survivor.hp, survivor.MAX_HP, int(survivor.hunger), int(survivor.fatigue), int(survivor.morale)]
		var carried: int = _carried_total(survivor.carried_loot)
		if carried > 0:
			line += " — trägt %d/%d" % [carried, survivor.CARRY_CAPACITY]
		lines.append(line)
	for unit in selected:
		if is_instance_valid(unit) and unit.has_method("request_exit"):
			lines.append("F: Aussteigen")
			break
	hud_label.text = "\n".join(lines)
	_update_resources_label(own_base)


func _update_resources_label(own_base: Node3D) -> void:
	# Eigenes Panel statt einer einzelnen HUD-Zeile (siehe docs/base.md,
	# "Vier Baurohstoffe") — sieben Ressourcenarten in eine Textzeile
	# gequetscht wäre nach der Rohstoff-Aufteilung kaum noch lesbar
	# gewesen (Nutzer-Feedback: UI überarbeiten). Seit RESOURCE_CATEGORIES
	# (siehe oben) ein Label PRO Kategorie statt einer einzigen Liste mit
	# allen 16 Arten — nächster Schritt derselben "wird unübersichtlich"-
	# Beobachtung, diesmal auf Kategorie- statt auf Panel-Ebene.
	if not is_instance_valid(own_base):
		for label in resource_category_labels:
			label.text = "—"
		return
	var r: Dictionary = own_base.resources
	var cap: int = own_base.storage_capacity
	for i in RESOURCE_CATEGORIES.size():
		var category: Dictionary = RESOURCE_CATEGORIES[i]
		var lines: Array = []
		for key in category["keys"]:
			lines.append("%s: %d/%d" % [RESOURCE_DISPLAY_NAMES.get(key, key), r.get(key, 0), cap])
		resource_category_labels[i].text = "\n".join(lines)


func _carried_total(loot: Dictionary) -> int:
	# Summe über alle Ressourcenarten hinweg, siehe docs/scavenging.md,
	# "Rückweg" — HUD und Einheiten-Liste zeigen nur die Summe, nicht die
	# Aufschlüsselung nach Art.
	var total := 0
	for amount in loot.values():
		total += amount
	return total


func _find_own_survivors() -> Array:
	var own: Array = []
	for survivor in survivors_container.get_children():
		# Eingestiegene Trupps (siehe docs/vehicle.md) sind aus "living"
		# entfernt (Survivor._board()) — tauchen dadurch weder im HUD noch
		# in der Einheiten-Liste auf, solange sie im Fahrzeug sitzen.
		if survivor.owner_peer_id == multiplayer.get_unique_id() and survivor.is_in_group("living"):
			own.append(survivor)
	return own


func _find_own_home_base() -> Node3D:
	for base in home_bases_container.get_children():
		if base.owner_peer_id == multiplayer.get_unique_id():
			return base
	return null


func _handle_pan(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if input_dir != Vector3.ZERO:
		# WASD bleibt bildschirm-relativ, unabhängig von der aktuellen
		# Rotation. Bewegt pivot.position (direkter Elternteil der Kamera),
		# nicht global_position der Wurzel (siehe docs/3d-migration.md, "Der
		# eigentliche Rendering-Bug").
		var rotated := input_dir.rotated(Vector3.UP, pivot.rotation.y)
		pivot.position += rotated.normalized() * PAN_SPEED * delta
		# Kamera-Pan-Begrenzung (siehe docs/world.md, "Kartengröße") — gab es
		# vorher gar nicht, war bei der kleinen 160er-Karte kaum spürbar; bei
		# MAP_SIZE := 5000 würde man sonst unbemerkt lange ins Leere fahren.
		var half_map: float = MAP_SIZE / 2.0
		pivot.position.x = clampf(pivot.position.x, -half_map, half_map)
		pivot.position.z = clampf(pivot.position.z, -half_map, half_map)


func _stop_selected_units() -> void:
	for unit in selected:
		if is_instance_valid(unit) and unit.has_method("order_stop"):
			unit.order_stop.rpc_id(1, multiplayer.get_unique_id())


func _exit_selected_vehicles() -> void:
	var exited := false
	for unit in selected:
		if is_instance_valid(unit) and unit.has_method("request_exit"):
			unit.request_exit.rpc_id(1, multiplayer.get_unique_id())
			exited = true
	if exited:
		# Nichts bleibt ausgewählt — der Trupp steht sichtbar neben dem
		# Fahrzeug und kann per Klick normal weiter befehligt werden.
		selected.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					if _build_mode and _build_type in [BuildType.WALL, BuildType.GATE]:
						# Mauer/Tor werden gezogen statt einzeln geklickt
						# (siehe docs/walls.md, "Ziehen") — Wachposten/
						# Krankenstation/Werkstatt bleiben beim alten
						# Einzelklick über _select_at().
						_start_wall_drag(event.position)
					else:
						_select_at(event.position, event.shift_pressed)
				elif _wall_drag_active:
					_finish_wall_drag(event.position)
			MOUSE_BUTTON_RIGHT:
				# Unterscheidung Klick vs. Ziehen: Ziehen rotiert die Kamera,
				# ein reiner Klick (kein Rotieren dazwischen) stoppt
				# stattdessen die ausgewählten Einheiten.
				_rotating = event.pressed
				if event.pressed:
					_right_click_dragged = false
				elif not _right_click_dragged:
					_stop_selected_units()
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom(-1.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom(1.0)
	elif event is InputEventMouseMotion and _rotating:
		# Rechte Maustaste halten + ziehen = rotieren (horizontal) UND neigen
		# (vertikal, ändert den Blickwinkel der Kamera).
		_right_click_dragged = true
		pivot.rotate_y(-event.relative.x * MOUSE_ROTATE_SENSITIVITY)
		_tilt_angle = clamp(_tilt_angle - event.relative.y * MOUSE_TILT_SENSITIVITY, TILT_MIN, TILT_MAX)
		_apply_zoom()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			# Kontrollgruppen (RTS-Standard): Strg+Zifferntaste weist die
			# aktuelle Auswahl der Gruppe zu, Zifferntaste allein wählt sie
			# wieder aus.
			_handle_control_group_key(event.keycode - KEY_1 + 1, event.ctrl_pressed)
		elif event.keycode == KEY_F:
			# Aussteigen aus einem gefahrenen Fahrzeug (siehe docs/vehicle.md)
			# — kein eigener UI-Button, Taste analog zu den Kontrollgruppen.
			_exit_selected_vehicles()
		elif event.keycode == KEY_ESCAPE:
			# Einziger Weg, World.tscn wieder zu verlassen (siehe
			# docs/save_load.md) — vorher gab es dafür gar keine Taste/UI.
			pause_menu.toggle()
		elif event.keycode == KEY_F9:
			# Debug-Stresstest zum Benchmarken von MAX_ZOMBIES (siehe dort) —
			# kein Spielfeature, bewusst ohne UI-Button/Feedback.
			_debug_spawn_zombies()
		elif event.keycode == KEY_M:
			# Vollbild-Kartenansicht (siehe docs/world.md, "Kartenansicht") —
			# eigene Taste statt automatisch bei ZOOM_MAX (Nutzerentscheidung
			# 2026-08-01, offene Design-Frage aus der Planung), unabhängig
			# vom aktuellen Zoom-Level.
			toggle_map_view()


func toggle_map_view() -> void:
	# Von KEY_M (siehe _unhandled_input()) UND von MapView._gui_input()
	# selbst aufgerufen (Klick auf die Karte springt dorthin und schließt
	# die Ansicht wieder, siehe docs/world.md, "Kartenansicht") — eine
	# einzige Stelle für beide Auslöser.
	map_view_ui.visible = not map_view_ui.visible


func _handle_control_group_key(group_number: int, assign: bool) -> void:
	if assign:
		if selected.is_empty():
			return
		_control_groups[group_number] = selected.duplicate()
		return
	if not _control_groups.has(group_number):
		return
	selected.clear()
	for unit in _control_groups[group_number]:
		if is_instance_valid(unit):
			selected.append(unit)


func _select_at(screen_pos: Vector2, additive: bool) -> void:
	# 3D-Pendant zu Commander._select_at() (2D, Distanz-Check) — echter
	# Physik-Raycast von der Kamera durch die Klickposition.
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if _build_mode:
		# Für alle Einzelklick-Bautypen (Wachposten/Feld) — Mauer/Tor laufen
		# übers Ziehen (_start_wall_drag()/_finish_wall_drag(), siehe
		# _unhandled_input()), erreichen _select_at() also gar nicht mehr.
		# Baumodus hat Vorrang vor Auswahl/Bewegung. Ein-Klick-Modus: schaltet
		# sich danach immer ab, auch bei Fehlschlag (kein Feedback bei
		# Ablehnung, wie im 2D-Original).
		_build_mode = false
		_update_build_button_texts()
		if result:
			request_build_structure.rpc_id(1, _build_type, result.position, multiplayer.get_unique_id())
		return
	if _find_own_home_base() == null and result and result.collider.is_in_group("searchable"):
		# Start-Basis-Wahl (siehe docs/zones.md, "Start-Basis wählen"): vor der
		# eigenen ersten Home-Base ersetzt ein Klick auf eines der acht
		# Stadt-Gebäude die normale Such-/Claim-Logik weiter unten — kein
		# ausgewählter Trupp nötig, den gibt es ja noch nicht.
		var choice: Node3D = result.collider
		if choice.owner_peer_id == 0:
			request_choose_start_base.rpc_id(1, choice.get_path(), multiplayer.get_unique_id())
		return
	if result and result.collider.is_in_group("selectable"):
		var hit: Node3D = result.collider
		if hit.owner_peer_id == multiplayer.get_unique_id():
			if not additive:
				selected.clear()
			if hit in selected:
				selected.erase(hit)
			else:
				selected.append(hit)
			return
		if hit.is_in_group("vehicle") and hit.owner_peer_id == 0 and not selected.is_empty():
			# Unbesetztes Fahrzeug (owner_peer_id == 0, siehe docs/vehicle.md)
			# — nur der ERSTE ausgewählte Trupp versucht einzusteigen (ein
			# Fahrzeug hat nur einen Fahrersitz), Rest der Auswahl bleibt
			# unangetastet stehen. X/Z vom Raycast-Treffpunkt, feste
			# Bodenhöhe — gleiches Muster wie beim Gebäude-Klick.
			var unit = selected[0]
			if is_instance_valid(unit) and unit.has_method("order_enter_vehicle"):
				var target := Vector3(result.position.x, SURVIVOR_GROUND_Y, result.position.z)
				unit.order_enter_vehicle.rpc_id(1, target, hit.get_path(), multiplayer.get_unique_id())
				# Optimistisch schon auf das Fahrzeug umschalten, nicht erst
				# nachdem der Trupp tatsächlich angekommen ist — sonst bliebe
				# bis dahin der (nach dem Einsteigen unsichtbare, nicht mehr
				# auswählbare) Trupp ausgewählt. Befehle ans Fahrzeug vor dem
				# tatsächlichen Einsteigen laufen einfach ins Leere (RPC prüft
				# requesting_peer_id == owner_peer_id, das Fahrzeug gehört bis
				# dahin noch niemandem).
				selected = [hit]
			return
		return
	if result and result.collider.is_in_group("searchable"):
		# Gebäude-Ziel — läuft unabhängig davon, ob gerade etwas ausgewählt
		# ist (anders als die meisten anderen Branches), weil ein Klick auf
		# das EIGENE geclaimte Gebäude zum Ausbauen führt (siehe
		# docs/building.md, "Ausbauen") und dafür kein Trupp nötig ist.
		var building: Node3D = result.collider
		if building.is_looted and building.owner_peer_id != 0:
			if building.owner_peer_id == multiplayer.get_unique_id():
				# Eigenes geclaimtes Gebäude — zum Ausbauen auswählen statt
				# nichts zu tun.
				_selected_claimed_building = building
				_update_build_button_texts()
			return
		if selected.is_empty():
			return
		# Ruft order_search() (noch nicht geplündert) oder
		# order_claim_building()/order_demolish_building() (schon
		# geplündert, noch niemandem gehörend — siehe docs/zones.md,
		# docs/survivor.md) statt order_move() auf, je nach Zustand. X/Z vom
		# Raycast-Treffpunkt (result.position), NICHT building.global_position
		# — Gebäude sind auf ihrem Node-Origin zentrierte BoxMeshes, ein Ziel
		# auf dem Origin läge mitten im Mesh und der Trupp wäre während der
		# ganzen Suche/des Claimens unsichtbar. Y bewusst NICHT vom
		# Treffpunkt übernommen (`result.position.y`) — je nachdem, ob die
		# Seite oder das Dach der Box getroffen wird, schwankt diese Höhe,
		# und der Trupp würde dorthin hochlaufen ("steht auf dem Dach").
		# Stattdessen dieselbe feste Bodenhöhe wie beim normalen
		# Bodenklick (Ground-BoxMesh-Oberfläche 0.1 + Bewegungsziel-Offset
		# 0.5).
		var base_target := Vector3(result.position.x, SURVIVOR_GROUND_Y, result.position.z)
		# StringName statt direktem Methodenaufruf, weil je nach Zustand
		# unterschiedliche RPCs dran sind — Node.rpc_id() kann das generisch
		# per Methodenname aufrufen (anders als unit.call(), das NICHT über
		# das Netzwerk geht, siehe docs/zones.md). Seit "Gebäude abreißen"
		# (siehe docs/survivor.md) PRO EINHEIT bestimmt, nicht mehr nur
		# einmal für die ganze Auswahl — ein bereits geplündertes,
		# unbesetztes Gebäude claimt ein Feldtrupp, ein Bautrupp reißt es
		# stattdessen ab (has_method("order_harvest") als "ist das ein
		# Survivor?"-Indikator, gleiches Duck-Typing-Prinzip wie anderswo).
		for i in selected.size():
			var unit = selected[i]
			if not is_instance_valid(unit):
				continue
			var order_method: StringName = &"order_search"
			if building.is_looted:
				order_method = &"order_claim_building"
				if unit.has_method("order_harvest") and unit.troop_type == unit.TroopType.BUILD:
					order_method = &"order_demolish_building"
			if unit.has_method(order_method):
				var target := base_target + _formation_offset(i, selected.size())
				unit.rpc_id(1, order_method, target, building.get_path(), multiplayer.get_unique_id())
		return
	if result and not selected.is_empty() and (result.collider.is_in_group("zombie") or result.collider.is_in_group("zombie_nest")):
		# Angriffsbefehl (siehe docs/survivor.md, "Angriffsbefehl") — Klick
		# auf einen Zombie oder ein Zombie-Nest (siehe docs/zombies.md) statt
		# auf Boden/Gebäude. has_method-Check filtert Fahrzeuge aus der
		# Auswahl heraus (die haben keinen eigenen Angriff, siehe
		# docs/vehicle.md). Kein Formation-Offset nötig — mehrere Trupps
		# laufen bewusst auf denselben Punkt zu (Nahkampf-Cluster).
		var enemy: Node3D = result.collider
		for unit in selected:
			if is_instance_valid(unit) and unit.has_method("order_attack"):
				unit.order_attack.rpc_id(1, enemy.get_path(), multiplayer.get_unique_id())
		return
	if result and not selected.is_empty() and result.collider.is_in_group("harvestable"):
		# Bautrupp-Aktion (siehe docs/survivor.md, "Trupp-Arten") — Klick auf
		# einen Baum ODER ein Autowrack (gemeinsame Gruppe "harvestable").
		# order_harvest() prüft server-seitig, ob die jeweilige Einheit
		# überhaupt ein Bautrupp ist (siehe dort).
		var harvestable: Node3D = result.collider
		for unit in selected:
			if is_instance_valid(unit) and unit.has_method("order_harvest"):
				unit.order_harvest.rpc_id(1, harvestable.get_path(), multiplayer.get_unique_id())
		return
	if result and selected.is_empty() and result.collider.is_in_group("harvestable"):
		# Markieren statt Direktbefehl, siehe docs/survivor.md, "Trupp-
		# Arten", "Markier-System" — nur wenn gerade nichts ausgewählt ist
		# (mit ausgewähltem Bautrupp greift stattdessen der Branch oben,
		# direkter Befehl). Nochmal klicken hebt die Markierung wieder auf.
		request_toggle_harvest_mark.rpc_id(1, result.collider.get_path())
		return
	if result and not selected.is_empty():
		# Boden getroffen, während etwas ausgewählt ist: order_move() an den
		# Host schicken. Shift+Klick (additive) hängt einen Wegpunkt hinten
		# an die bestehende Schlange an, statt sie zu ersetzen.
		var base_target := Vector3(result.position.x, SURVIVOR_GROUND_Y, result.position.z)
		for i in selected.size():
			var unit = selected[i]
			if is_instance_valid(unit) and unit.has_method("order_move"):
				var target := base_target + _formation_offset(i, selected.size())
				unit.order_move.rpc_id(1, target, multiplayer.get_unique_id(), additive)
		return
	selected.clear()


const FORMATION_SPACING := 1.2

func _formation_offset(index: int, count: int) -> Vector3:
	# Ohne Kollision/Pathfinding (siehe docs/survivor.md, "Bekannte Grenzen")
	# würden mehrere gleichzeitig befohlene Einheiten sonst exakt übereinander
	# laufen und ineinander clippen — verteilt sie stattdessen in einem
	# einfachen Raster um den eigentlichen Zielpunkt.
	if count <= 1:
		return Vector3.ZERO
	var columns := int(ceil(sqrt(float(count))))
	var rows := int(ceil(float(count) / columns))
	var col := index % columns
	var row := index / columns
	var offset_x := (col - (columns - 1) / 2.0) * FORMATION_SPACING
	var offset_z := (row - (rows - 1) / 2.0) * FORMATION_SPACING
	return Vector3(offset_x, 0, offset_z)


func _zoom(direction: float) -> void:
	_zoom_distance = clamp(
		_zoom_distance + direction * _zoom_distance * ZOOM_STEP_FACTOR,
		ZOOM_MIN,
		ZOOM_MAX,
	)
	_apply_zoom()


func _apply_zoom() -> void:
	# Kamera-Offset aus _tilt_angle berechnet. Weil sich die Blickrichtung
	# dadurch ändern kann, muss look_at() bei jedem Aufruf neu berechnet
	# werden, nicht nur einmalig in _ready() (siehe docs/3d-migration.md,
	# "Der eigentliche Rendering-Bug").
	var offset_dir := Vector3(0, sin(_tilt_angle), cos(_tilt_angle))
	camera.position = offset_dir * _zoom_distance
	camera.look_at(pivot.global_position, Vector3.UP)
