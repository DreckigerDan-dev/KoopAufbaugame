# Home-Base + Ressourcen

Erklärt `scenes/entities/base/HomeBase.gd` (Ressourcen-Datenmodell pro
Spieler) und das zugehörige HUD in `World.gd`. Jede eigene Zone/jeder
Bautyp baut auf diesen Ressourcen auf, siehe
[`docs/building.md`](building.md), [`docs/zones.md`](zones.md),
[`docs/scavenging.md`](scavenging.md).

## Eigene 3D-Assets statt Platzhalter-Boxen

Erstes eigenes 3D-Asset des Nutzers, `assets/startbasetest.glb`
(Blender-Export, Barrikaden-Struktur, 84 Meshes), als `HomeBase`-Modell
eingebaut (`[node name="Model" ... instance=ExtResource(...)]` in
`HomeBase.tscn`) — die alte `BoxMesh` bleibt als unsichtbarer Platzhalter
für die Kollisionsform erhalten (`visible = false`). **Vom Nutzer nach
einmaliger Größenkorrektur bestätigt** — siehe
[`docs/survivor.md`](survivor.md) für die daraus resultierende
1,70-m-Kapselgröße als Maßstabs-Referenz.

Gleiches Muster seitdem auch für `GuardPost.tscn`
(`assets/wachturmtest.glb`) und `Wall.tscn`
(`assets/holzmauertest.glb`, NUR die Mauer — `Gate.tscn` ist eine
eigenständige Szene mit demselben Script und bleibt bei der
Platzhalter-Box) — siehe [`docs/building.md`](building.md), "Wachturm +
Holzmauer". Bei Bedarf `Model`s `scale`/`position` in der jeweiligen
`.tscn` anpassen oder auf die alte Box zurückrollen (`Mesh.visible =
true`, `Model`-Node entfernen).

## Eine Home-Base pro Spieler

`ARCHITECTURE.md`: "Jeder Spieler hat seine eigene Basis/Kolonie, nicht
geteilt." Jede Home-Base ist ein eigener, unabhängiger Node mit eigenem
`resources`-Dictionary — kein gemeinsamer Pool, kein Ressourcen-Sharing
zwischen Spielern. Spawn-Position kommt seit der Start-Basis-Wahl (siehe
[`docs/zones.md`](zones.md), "Start-Basis wählen") relativ zu dem
Stadt-Gebäude, das der jeweilige Peer selbst als Basis gewählt hat, nicht
mehr aus festen Kartenecken (`World.request_choose_start_base()`).

## Zerstörbarkeit + Rettungsmechanik (2026-08-04)

Vorher komplett unzerstörbar — Nutzerwunsch nach dem Mechaniken-Bericht
(siehe `docs/mechanics-review.md`, "Fehlende Enden/Ziele"): das Spiel
hatte keinen Sieg-/Niederlage-Zustand.

- **`HomeBase.MAX_HP := 500`** — deutlich zäher als jedes andere Gebäude
  ("sehr zäh", Nutzerwunsch), Zerstörung bleibt ein seltenes, dramatisches
  Ereignis. `take_damage()` gleiches Muster wie `Building`/`Wall`.
  Zombies erreichen sie über `Zombie._find_nearest_target()`, eigene
  Gruppe `"home_base"` (nicht `"searchable"`, keine Scavenging-Semantik).
- **Ruine statt Verschwinden:** bei Zerstörung spawnt `World.
  home_base_destroyed()` an derselben Stelle ein normales, schon
  geplündertes, unbesetztes `Building` (reine Wiederverwendung des
  bestehenden Abriss-Mechanismus — Nutzerwunsch: "kaputte Gebäude für
  paar Ressourcen bergen").
- **Rettungsmechanik statt sofortigem Aus:** der betroffene Spieler sieht
  ein Panel (`GameOverUI.gd`/`.tscn`) mit "Hilfe anfragen" oder
  "Aufgeben". Bittet er um Hilfe, sieht jeder Mitspieler die Anfrage im
  Einheiten-Tab (`RescueList`) und kann einen EIGENEN Trupp auswählen +
  "Trupp senden" drücken — der Trupp wird zum **Base-Erstellen-Trupp**
  (`Survivor.is_rescue_unit`, golden eingefärbt, kostet den Helfer
  dauerhaft eine Einheit), wechselt den Besitzer zum verlorenen Spieler
  und schaltet für ihn `World.request_choose_start_base()` wieder frei
  (praktisch wie ein Neustart innerhalb derselben Session — er wählt
  erneut ein Gebäude als Basis, bekommt `START_SURVIVOR_COUNT` neue
  Trupps). Ohne Hilfe (Solo oder "Aufgeben"): echter Game-Over-Bildschirm
  mit "Neu starten" (frisches Solo-Spiel) oder "Zurück zum Hauptmenü".
- **`World._lost_peers`/`_rescue_requests`** — gleiches Muster wie
  `_trade_offers` (nur Host führt Buch, an alle Peers gespiegelt, KEIN
  Catch-up/KEINE Speicherstand-Persistenz, kurzlebiger Zwischenzustand).
  **Bekannte Lücke:** speichert/lädt jemand exakt während ein Spieler im
  "verloren, wartet auf Rettung"-Zustand ist, geht dieser Zustand beim
  Neuladen verloren (Spieler hat dann einfach keine Basis, keine
  gesperrte `request_choose_start_base()` mehr) — akzeptierter Randfall,
  gleiche Vereinfachung wie bei Handelsangeboten.
- **Trupps unterwegs überleben** die Zerstörung der eigenen Home-Base
  (Annahme, vom Nutzer nicht widersprochen) — gelten bis zur Rettung als
  "heimatlos" (kein Lager/Heilung/Forschung mehr erreichbar).
- HP ist Teil von Speicherstand/Catch-up (`_collect_save_data()`/
  `_load_game_state()`/`_catch_up_home_base()`), damit ein Neuladen nicht
  stillschweigend jede Home-Base wieder auf volle HP zurücksetzt.
- Noch nicht vom Nutzer getestet.

## Ressourcen

```gdscript
const START_RESOURCES := {"food": 60, "wood": 50, "metal": 25, "stone": 40, "brick": 25, "medicine": 25, "ammo": 30, "weapon": 1, "armor": 1, "helmet": 1, "melee_weapon": 1, "leg_armor": 1}
var resources: Dictionary = START_RESOURCES.duplicate()
```

Echte Balance-Werte (nicht mehr die temporären 150/Art-Testwerte vom
2026-08-01, siehe persistentes Memory `koopgame_temp_test_resources` für
die Historie — diese Doku-Zeile war seitdem veraltet, hier korrigiert).
Baurohstoffe/Überlebensgüter 2026-08-04 nochmal angehoben (Nutzerwunsch:
"mehr start resourcen das man seine base gleich bischen ausbauen kann",
siehe `docs/mechanics-review.md`, "Ressourcen-Wirtschaft") — reicht jetzt
z. B. für eine Zonen-Erweiterung (15 Stein) PLUS einen Wachposten (30
Holz) direkt zu Spielbeginn. Kein `book_research` im Startbestand — Bücher
sind NUR über seltenen Zombie-Loot erreichbar (siehe
[`docs/zombies.md`](zombies.md)). Ausrüstungs-Startbestand (`weapon`/
`armor`/`helmet`/`melee_weapon`/`leg_armor`) bewusst bei 1 belassen —
Einzel-Slots, kein Grund die zu erhöhen.

Dreizehn Ressourcenarten (2026-08-04: Universal-Buch-Migration — die
vorher fünf getrennten `book_*`-Ressourcen sind jetzt eine einzige
`book_research`, siehe [`building.md`](building.md), "Forschungsbücher";
2026-08-02: `melee_weapon`/`leg_armor` seit Punkt 18 der Gesamtliste
dazugekommen, siehe [`survivor.md`](survivor.md), "Haupt-/Sekundärwaffe"/
"Dritter Rüstungs-Slot"). `food` wird beim Essen
verbraucht (siehe [`docs/survivor.md`](survivor.md)), `medicine` beim
Heilen, `wood`/`metal`/`stone`/`brick` beim Bauen/Claimen (siehe unten).
`weapon`/`armor`/`helmet`/`melee_weapon`/`leg_armor` kommen über
Zombie-Kills (siehe [`docs/zombies.md`](zombies.md), "Zombie-Loot-Drop")
rein — `weapon`/`armor`/`helmet` zusätzlich seit dem Crafting-System
(siehe [`docs/building.md`](building.md), "Herstellen") über die eigene
Werkstatt, `melee_weapon`/`leg_armor` bewusst NICHT (siehe
[`survivor.md`](survivor.md) für die Begründung). `weapon`/`melee_weapon`
werden beim Ausrüsten eines Trupps verbraucht, `armor`/`helmet`/
`leg_armor` beim jeweiligen Anlegen (drei getrennte Slots, siehe
[`docs/survivor.md`](survivor.md), "Rüstungssystem"), `ammo` pro
Fernkampf-Schuss — alle Systeme nur eine schlanke erste Stufe, nicht das
volle Vision-System. Die Trage-Kapazität (`CARRY_CAPACITY`) ist dagegen
KEIN Ressourcenverbrauch mehr, sondern ein fester Wert jedes Trupps, siehe
[`docs/survivor.md`](survivor.md), "Rucksack".

### Vier Baurohstoffe (statt einem generischen "materials")

Ursprünglich gab es nur eine einzige Bau-Ressource (`materials`). Auf
Nutzerwunsch aufgeteilt in vier thematisch unterschiedliche Arten:

- **`wood`** (Holz) — aus Bäumen gefällt (siehe
  [`docs/survivor.md`](survivor.md), "Ressourcen abbauen").
- **`metal`** (Metall) — aus Autowracks abgebaut.
- **`stone`** (Stein) — aus Steinhaufen abgebaut.
- **`brick`** (Ziegel) — aus Ziegelhaufen abgebaut.

Alle vier sind reine Bautrupp-Ressourcen (siehe
[`docs/survivor.md`](survivor.md), "Ressourcen abbauen") — bewusst
**nicht** aus Stadt-Gebäude-Loot (das war ein früherer Zwischenstand,
siehe unten). Stadt-Gebäude-Loot (Feldtrupp-Territorium) bleibt bei
`food`/`medicine`/`ammo`, siehe [`docs/scavenging.md`](scavenging.md).

Jeder Bautyp braucht genau **eine** thematisch passende Art (siehe
[`docs/building.md`](building.md) für die genaue Zuordnung), Beträge
unverändert zur alten `materials`-Fassung — nur auf die jeweils passende
Art umgehängt, keine Balancing-Änderung. `World.RESOURCE_DISPLAY_NAMES`
ist der eine zentrale Ort für die deutschen Anzeigenamen aller zehn
Arten (HUD, Bau-Buttons).

## `add_resources()` — der einzige Schreibzugriff

```gdscript
@rpc("authority", "call_local", "reliable")
func add_resources(delta: Dictionary) -> void:
    for key in delta:
        resources[key] = resources.get(key, 0) + delta[key]
    resources_changed.emit(resources)
```

Nimmt ein Delta-Dictionary (positiv = Gewinn, negativ = Kosten) — jeder
Verbrauch im Spiel ruft dieselbe Funktion mit negierten Werten auf, kein
separates `spend_resources()`. `authority`, weil nur der Host (der alles
simuliert, was Ressourcen verändert) aufrufen darf; `call_local`, damit
der Host seine eigene Home-Base auch direkt aktualisiert sieht. Aufrufer
u. a.: `Survivor._handle_carried_loot()` (Loot-Ablieferung),
`Survivor._handle_eating()`/`_handle_healing()` (Verbrauch),
`World.request_build_structure()`/`request_build_wall_line()`/
`claim_building()` (Baukosten).

Kein Datenschutz-Problem, dass `add_resources` theoretisch von jedem
aufrufbar wäre — jede Home-Base bleibt ein eigener Node, ein Aufruf auf
der eigenen Instanz betrifft nie die Ressourcen eines anderen Spielers.

## HUD (`World._update_hud()` + eigenes Ressourcen-Panel)

`hud_label` (oben links) zeigt pro Frame nur noch die eigenen Trupps
(HP/Hunger/getragener Loot, siehe [`docs/survivor.md`](survivor.md)) —
die Ressourcenzeile wurde auf Nutzerwunsch ("UI überarbeiten") in ein
eigenes Panel ausgelagert: `$ResourcesUI` (oben rechts), gefüllt von
`World._update_resources_label()`. Eine Zeile pro Ressourcenart (zehn seit
der Rohstoff-Aufteilung + Zombie-Loot-Drop + Rüstungssystem — als eine
gemeinsame HUD-Zeile kaum noch lesbar gewesen), feste Reihenfolge über
`RESOURCE_DISPLAY_NAMES`.
`_find_own_home_base()` filtert auf `owner_peer_id ==
multiplayer.get_unique_id()`; ohne eigene Home-Base zeigt das Panel "—".
Reine Anzeige, kein Caching — liest `resources` direkt bei jedem
`_process()`-Frame.

## Bekannte Grenzen (noch nicht gelöst)

- **Nur schlanke, erste Waffen-/Rüstungssystem-Stufen** (siehe
  [`docs/survivor.md`](survivor.md), "Waffensystem"/"Rüstungssystem") — ein
  Waffen-Slot, zwei Rüstungs-Slots (Brustpanzer + Helm),
  keine Waffentypen/-stufen, keine Rüstungsteile für weitere Körperzonen.
  Trage-Kapazität ist kein Ausrüstungs-Slot mehr, sondern ein fester Wert
  pro Trupp (siehe [`docs/survivor.md`](survivor.md), "Rucksack").
  **Crafting seit 2026-08-01 umgesetzt** (siehe
  [`docs/building.md`](building.md), "Herstellen"/"Forschungsbücher"), 4
  feste Rezepte, seit denselben Tag mit Forschungsbücher-Gate — bei Weitem
  nicht das volle Vision-System aus `Infos/02 Item-Liste.md` (kein
  Buch-Kopieren, keine Lese-Aktion am Survivor).
- **Obergrenze über `storage_capacity`** (siehe
  [`docs/building.md`](building.md), "Lager") — EIN gemeinsamer Deckel für
  alle sechzehn Ressourcenarten, kein separates Limit pro Art. Startwert
  `BASE_STORAGE_CAPACITY` aktuell **temporär auf 300** (normal 150, siehe
  "Ressourcen" oben), erhöht sich dauerhaft durchs Ausbauen von Gebäuden
  zu Lagern.
- **Kein Ressourcen-/Kapazitäts-Catch-up-Sonderfall** — `HomeBase` läuft
  über `MultiplayerSpawner`/`_catch_up_home_base()` wie Survivor/Zombie/
  etc., aber weder `resources` noch `storage_capacity` werden beim
  Catch-up explizit erneut gesynct (nur die Startwerte werden beim
  `_create_home_base()` gesetzt); ein spät beitretender Peer sieht ohnehin
  nur seine **eigene** Home-Base im HUD, fremde Ressourcenstände werden
  nirgends angezeigt.

## Testen

Debug → Customize Run Instances → 2 → F5, Host + Join, "Spiel starten".
Ressourcen-Panel oben rechts beobachten, ein Gebäude durchsuchen lassen
(siehe [`docs/scavenging.md`](scavenging.md)) — Stein-/Ziegel-Werte
sollten sich beim Ablegen an der Basis erhöhen. Baum fällen/Wrack
abbauen lassen (siehe [`docs/survivor.md`](survivor.md)) — Holz bzw.
Metall sollte steigen. Jeden Bautyp einmal bauen — die jeweils passende
Rohstoffart sollte sinken (siehe [`docs/building.md`](building.md) für
die Zuordnung).
