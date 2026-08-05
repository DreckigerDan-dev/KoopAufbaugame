# Einstellungen

Erklärt `autoloads/SettingsManager.gd` + `scenes/settings/SettingsMenu.tscn`/
`.gd`. Teil derselben Nutzeranfrage wie `docs/save_load.md` ("Titelbildschirm
ändern mit Einstellungs-Knopf, Solo-Start, Koop, was man so braucht").

## Umfang bewusst klein gehalten

Vor diesem Feature gab es **keinerlei** Settings-/Audio-Infrastruktur im
Projekt: kein Audio-Bus außer dem Godot-Standard-"Master", keine
`user://`-Config, `assets/audio/` ist ein leerer Ordner, nirgends im Code
wird überhaupt Sound abgespielt (kein `AudioStreamPlayer` verwendet). Umfang
für "was man so braucht":

- **Fullscreen-Toggle** (`DisplayServer.window_set_mode(...)`) — hat sofort
  sichtbaren Effekt.
- **Master-Lautstärke-Regler** (`AudioServer.set_bus_volume_db(...)`) — wird
  korrekt am Master-Bus verdrahtet, hat aber **noch keine hörbare Wirkung**,
  da im Projekt bisher gar kein Sound abgespielt wird. Kein totes Feature,
  nur schon vorbereitet für später, sobald es echten Sound gibt.

## `SettingsManager` (Autoload)

Lädt beim Spielstart `user://settings.cfg` (Godot-`ConfigFile`, Standard-
Persistenzmechanismus, kein neuer Abhängigkeitscode), wendet Fullscreen
sofort an. `set_fullscreen(enabled)`/`apply_master_volume(db)` speichern bei
jedem Aufruf sofort auf Platte (kein separater "Übernehmen"-Button nötig für
so wenige, einfache Optionen).

## `SettingsMenu` — ein Overlay, zwei Aufrufer

`scenes/settings/SettingsMenu.tscn`/`.gd` ist eine eigenständige
`CanvasLayer`-Szene (`CheckButton` + `HSlider` + "Zurück"-Button), als
Kind-Node **sowohl** in `MainMenu.tscn` als auch in `PauseMenu.tscn`
eingehängt (`visible = false` per Default, `open()`/`close()` blenden es
ein/aus) — bewusst nicht dupliziert, da die Einstellungen unabhängig davon
gelten, ob man sich gerade im Hauptmenü oder mitten im Spiel befindet.
Rein lokale Client-UI, keine Netzwerk-Relevanz — läuft identisch für Host
und Client.

## Steuerungs-Präferenzen (2026-08-05, Nutzerwunsch "am besten über Einstellungen kann man das alles umstellen wie man will")

Zwei weitere `CheckButton`s, gleiches Auf-Platte-speichern-bei-jedem-Klick-
Prinzip wie oben:

- **`pan_with_mouse`** (Standard AN) — steuert BEIDES: `World.gd`s
  Kamera-Schwenk per mittlerer Maustaste halten+ziehen (siehe
  `MOUSE_PAN_SENSITIVITY`) UND `MapView.gd`s Rechtsklick-Ziehen zum
  Verschieben des Kartenausschnitts. Ein gemeinsamer Schalter statt zwei
  getrennter, da beide dieselbe Nutzerpräferenz ausdrücken ("Maus-Ziehen
  zum Navigieren an/aus").
- **`zoom_to_cursor`** (Standard AN) — steuert, ob `World._zoom()` beim
  Reinzoomen den Weltpunkt unter dem Mauscursor ungefähr an Ort und Stelle
  hält (siehe dortiger Kommentar) oder auf das alte, feste
  Pivot-zentrierte Zoomen zurückfällt.

Beide bewusst standardmäßig AN (neue Komfort-Features, aber unauffällig
genug für Opt-out statt Opt-in) — WASD-Kamera-Schwenk UND die alte
Rechtsklick-Dreh-Steuerung bleiben in jedem Fall unverändert bestehen,
unabhängig von diesen beiden Schaltern.

## Testen

Vollbild-Haken umschalten → Fenstermodus sollte sofort wechseln. Spiel
neu starten → Einstellung sollte erhalten geblieben sein
(`user://settings.cfg` prüfen). Lautstärke-Regler bewegen → aktuell ohne
hörbaren Effekt (siehe oben), aber `AudioServer.get_bus_volume_db(...)`
sollte den neuen Wert zeigen.
