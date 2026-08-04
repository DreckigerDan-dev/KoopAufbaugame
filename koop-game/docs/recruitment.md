# Rekrutierung

Erklärt, wie ein Spieler zu zusätzlichen Trupps kommt. Aufbauend auf
[`docs/scavenging.md`](scavenging.md) (Durchsuchen als Auslöser) und
[`docs/base.md`](base.md) (Home-Base als Spawn-Bezugspunkt). **Hinweis:**
die beiden Abschnitte unten ("Start: zwei Trupps"/"Rekrutierung über
durchsuchte Gebäude") sind historisch und teilweise veraltet
(`START_SURVIVOR_COUNT` ist inzwischen 5, nicht 2, siehe `World.gd`) —
für den aktuellen Gesamtstand siehe "Erweiterte Rekrutierung
(2026-08-04)" weiter unten.

## Aktive Rekrutierungs-Aktion: "Ruf aussenden" (2026-08-04)

Ergänzung zum passiven Schutzsuchenden-Timer (siehe "Erweiterte
Rekrutierung" unten) — Nutzerwunsch aus `Infos/07 Backlog-
Umsetzungspläne.md`. Button im Einheiten-Tab, direkt unter dem
Auto-Zuweisungs-Dropdown.

- **`World.request_active_recruit_call(requesting_peer_id)`**
  (`@rpc("any_peer", "call_local", "reliable")`): erzwingt einen
  Schutzsuchenden-Spawn-Versuch — ruft `_maybe_spawn_refugee(true)` auf,
  das jetzt einen `force`-Parameter hat, der NUR den Zufalls-Würfel
  (`REFUGEE_SPAWN_CHANCE`) überspringt. Der Aktiv-Deckel
  (`REFUGEE_MAX_ACTIVE := 3`) gilt weiterhin — ein Spieler kann also nicht
  beliebig viele gleichzeitige Schutzsuchende erzwingen, nur den nächsten
  freien Slot sofort statt erst nach einem zufälligen Timer-Tick füllen.
- **`ACTIVE_RECRUIT_CALL_COOLDOWN := 90.0`**, PRO SPIELER (nicht global)
  in `World._active_recruit_call_cooldowns: Dictionary` (peer_id →
  restliche Sekunden), jeden Frame runtergezählt (host-seitig, wie der
  passive `_refugee_spawn_timer`). Verhindert Spam-Klicks, unabhängig
  davon, was andere Spieler gerade tun.
- **Kein eigener UI-Cooldown-Countdown** — die Cooldown-Buchführung ist
  rein host-seitig (nie an Clients repliziert), der Button zeigt bewusst
  immer denselben Text. Ein Klick während des Cooldowns gibt stattdessen
  eine `report_status()`-Meldung ("Noch X s bis zum nächsten Ruf.") statt
  stiller Ablehnung — gleiches Feedback-Prinzip wie überall sonst im
  Projekt (z. B. "Kein freier Trupp verfügbar." am Wachposten).
- **Ist der Aktiv-Deckel erreicht** (3 Schutzsuchende schon unterwegs):
  eigene Meldung ("Schon genug Schutzsuchende unterwegs — später erneut
  versuchen."), kein Cooldown-Verbrauch in diesem Fall (der Spieler hat ja
  nichts bekommen, soll es also gleich nochmal versuchen dürfen, sobald
  einer der bestehenden Schutzsuchenden gefunden/verschwunden ist).

**Noch nicht vom Nutzer getestet.**

## Zivilisten-Konzept: neue Rekruten starten unzugewiesen (2026-08-04)

Nutzerwunsch nach der IFZ-Gap-Analyse (siehe `Infos/06 Infection Free Zone
Recherche.md`, `Infos/01 Architektur.md` "Ideen-Backlog") — leichte Variante
des dort diskutierten "Zivilisten-Konzepts", ohne eigene Housing-Kapazität
o. Ä. zu bauen. Betrifft NUR neue Rekruten (alle drei Kanäle unten), NICHT
die Start-Trupps (`request_choose_start_base()`, bleiben unverändert FIELD).

- **`Survivor.TroopType.UNASSIGNED`** — dritter Wert neben FIELD/BUILD.
  Ein unzugewiesener Trupp kann sich nicht bewegen (`order_move()`),
  nicht ins Fahrzeug steigen (`order_enter_vehicle()`) — beide lehnen mit
  `report_status()`-Feedback ab — und über die bestehenden FIELD-/BUILD-
  exklusiven Prüfungen auch nicht suchen/claimen/angreifen/abbauen. Er
  steht sichtbar (deutlich blasser/grauer eingefärbt, siehe
  `Survivor._unit_base_color()`) in der Einheiten-Liste, bis der Spieler
  ihn per Klick auf "→Feld" oder "→Bau" manuell zuweist (zwei getrennte
  Buttons statt des sonst üblichen FIELD<->BUILD-Togglers, siehe
  `World._refresh_units_ui()`).
- **Auto-Zuweisungs-Profil** (Dropdown im Einheiten-Tab, über der
  Einheiten-Liste, `World.RECRUIT_POLICIES`) — pro Spieler wählbar:
  - *Manuell (unzugewiesen)* — Standard, siehe oben.
  - *Automatisch: Feldtrupp* / *Automatisch: Baueinheit* — neuer Rekrut
    bekommt sofort den gewählten Typ, kein manueller Schritt nötig.
  - *Automatisch: Wachposten besetzen* — neuer Rekrut wird sofort FIELD
    UND direkt zum ersten eigenen Wachposten geschickt
    (`Survivor.order_station()`, gleicher Weg wie der "Trupp anfordern"-
    Button am Wachposten). Existiert noch kein eigener Wachposten, bleibt
    der Rekrut lieber unzugewiesen als still als Feldtrupp zu enden.
  - Rein host-seitige Buchführung (`World._recruit_policy`,
    `request_set_recruit_policy()`), wirkt erst beim NÄCHSTEN Rekruten,
    keine Speicherstand-Persistenz nötig (reine Session-Einstellung).
- **`GuardPost._find_idle_trupp()`** (für den manuellen "Trupp anfordern"-
  Button) überspringt UNASSIGNED-Trupps jetzt explizit — ein Klick auf
  den Button soll keinen frisch rekrutierten, noch nicht eingeteilten
  Zivilisten einziehen.
- **Bewusst NICHT umgesetzt** (siehe Backlog-Diskussion): eigene Housing-
  Kapazität/Bett-Kopplung, eigene Zivilisten-Entity getrennt von
  `Survivor` — beides würde deutlich tiefer ins Grundmodell eingreifen,
  hier bewusst die leichte Variante gewählt.

Noch nicht vom Nutzer getestet.

## Erweiterte Rekrutierung (2026-08-04)

Nutzerwunsch nach dem Mechaniken-Bericht (siehe `docs/mechanics-review.md`,
"Spieler-Kapazität") — der einzige Nachschub-Kanal war vorher EIN festes
Gebäude auf der ganzen Karte, einmalig. Jetzt drei Kanäle nebeneinander,
alle über denselben bestehenden `has_survivor`-Mechanismus
(`Survivor._finish_search()` → `World.spawn_recruit()`):

1. **Festes Rekrutierungs-Gebäude** (unverändert) — ein einzelnes,
   fest platziertes Gebäude, einmalig, ungedeckelt.
2. **Plünder-Zufallschance (`Survivor.LOOT_RECRUIT_CHANCE := 0.15`)** —
   JEDES normal durchsuchte Gebäude hat jetzt zusätzlich 15 % Chance auf
   einen neuen Trupp, ungedeckelt, unabhängig vom festen Gebäude.
3. **Schutzsuchende** (`World._maybe_spawn_refugee()`,
   `Building.is_refugee`) — alle `REFUGEE_SPAWN_INTERVAL := 180s` (3 Min.)
   eine `REFUGEE_SPAWN_CHANCE := 0.4`-Chance, dass irgendwo in der
   Wildnis ein neuer, aufsammelbarer Überlebender auftaucht (reine
   Wiederverwendung von `Building.gd` mit `has_survivor = true`,
   `is_refugee = true`, minimalem Loot `{"food": 3}`), bis zu
   `REFUGEE_MAX_ACTIVE := 3` gleichzeitig aktive auf der Karte. Einziger
   Kanal mit Deckel: `World.spawn_refugee_recruit()` gewährt maximal
   `REFUGEE_RECRUIT_CAP_PER_PEER := 2` Trupps pro Spieler über diesen Weg
   (Nutzerwunsch, "2 pro Spieler erstmal") — danach durchsucht, aber ohne
   neuen Trupp ("Der Schutzsuchende zieht weiter ...").

`Building.is_refugee` ist Teil von Speicherstand/Catch-up (gleiches
optionales Zusatzfeld-Muster wie `is_looted`/`hp`/etc.), der Pro-Spieler-
Zähler `World._refugee_recruits_granted` dagegen NICHT (kurzlebiger
Zustand, akzeptierte Lücke — ein Speichern+Laden während offener
Schutzsuchender-Zähler würde den Deckel theoretisch zurücksetzen).

Noch nicht vom Nutzer getestet.

## Start: zwei Trupps pro Peer

```gdscript
# Zweiter Survivor pro Peer, weil es (noch) keine Rekrutierung in 3D gibt
# (bekannte Lücke, siehe docs/recruitment.md) — sonst gäbe es nie einen
# freien Trupp für einen GuardPost, sobald der einzige stationiert ist.
const SECOND_SURVIVOR_OFFSET := Vector3(1.5, 0, 0)
```

`request_choose_start_base()` spawnt bei der Basis-Wahl **zwei** Survivor
(`_spawn_survivor(peer_id, survivor_position)` und `_spawn_survivor(peer_id,
survivor_position + SECOND_SURVIVOR_OFFSET)`) statt nur einem — ein
bewusster Kompromiss, bevor es überhaupt eine In-Game-Rekrutierung gab:
mit nur einem Trupp gäbe es nie einen zweiten freien für einen
Wachposten, sobald der einzige irgendwo stationiert oder unterwegs ist.

## Rekrutierung über durchsuchte Gebäude

Ein Platzhalter-Gebäude kann zusätzlich zu seinem Ressourcen-Loot
`@export var has_survivor: bool = false` gesetzt haben (aktuell **eines**
der acht Gebäude in `World.tscn`, mit `loot = {"food": 25, "medicine":
5}` **und** `has_survivor = true`). Beim Abschluss einer Suche
(`Survivor._finish_search()`, siehe [`docs/scavenging.md`](scavenging.md)):

```gdscript
if building.has_survivor:
    get_tree().current_scene.spawn_recruit(owner_peer_id, position)
```

`get_tree().current_scene` ist zuverlässig die `World`-Node, weil
`Survivor` nur existiert, während `World.tscn` die aktuell geladene Szene
ist (gleiches Cross-Node-Muster wie `report_status()`, siehe
[`docs/networking.md`](networking.md)).

`World.spawn_recruit(peer_id, spawn_position)` ruft schlicht denselben
`_spawn_survivor()`-Helfer wie beim Startspawn auf, an der Position des
durchsuchenden Trupps (`position`, also am Gebäude selbst) — der neue
Trupp erscheint dort und muss selbst zurück zur Basis laufen, wie jeder
andere neue Trupp auch.

## Bekannte Grenzen (noch nicht gelöst)

- **Genau ein rekrutierbares Gebäude auf der ganzen Karte** — kein
  Zufalls- oder Wiederauffüll-Mechanismus, sobald es durchsucht ist, gibt
  es keine weitere Rekrutierungsquelle mehr.
- **Kein Limit** auf die maximale Truppzahl pro Spieler.
- **Fester Zweit-Trupp bleibt bestehen**, obwohl es jetzt eine echte
  Rekrutierungsquelle gibt — beide Mechanismen koexistieren, ohne dass
  der Startbonus reduziert wurde.
- **Kein eigener Rekrutierungs-Bautyp** (z. B. eine Kaserne) aus der
  größeren Vision (siehe [`docs/status.md`](status.md)) — bislang nur an
  ein einzelnes, festes Gebäude gebunden.

## Testen

Debug → Customize Run Instances → 2 → F5, Host + Join, "Spiel starten".
Erst je eine Start-Basis wählen (siehe [`docs/zones.md`](zones.md),
"Start-Basis wählen") — danach sollten pro Spieler zwei Trupps in der
Einheiten-Liste (Einheiten-Tab, siehe [`world.md`](world.md),
"UI-Overhaul") stehen. Das Gebäude mit Loot `{"food": 25,
"medicine": 5}` durchsuchen lassen (siehe `World.tscn`, `Building2`) —
danach sollte ein dritter Trupp am Gebäude erscheinen.
