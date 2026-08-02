# Handel zwischen Spielern (2026-08-01, Punkt 14 der Gesamtliste)

Vision (`Infos/01 Architektur.md`, "Kooperation trotz getrennter Basen"):
"Handel — Spieler können Ressourcen untereinander tauschen/geben." Nur
diese eine kurze Zeile als Vorgabe. Rückfrage (einseitiges Schenken vs.
echtes Tausch-Angebot mit Annahme) → Nutzer wollte **beides**: "kann
schenken kann aber auch tauschen". Neuer Tab `Handel` in `MainTabsUI`
(siehe [`world.md`](world.md), "UI-Overhaul" — die dortige Umstellung auf
`TabContainer` war bewusst auch im Hinblick auf Handel gemacht worden).

## Ein gemeinsames Ziel-Spieler-Dropdown für beide Varianten

`PeerOption` (`OptionButton`) oben im Tab, listet alle anderen verbundenen
Peers aus `NetworkManager.players` (Name + Peer-ID), gilt für Schenken UND
Tausch-Angebot gleichermaßen — kein doppeltes Dropdown. Wird NICHT bei
jedem UI-Refresh-Tick (`WORKER_UI_REFRESH_INTERVAL := 0.5`) neu aufgebaut,
sondern nur wenn sich die Peer-Liste tatsächlich geändert hat
(`_trade_peer_ids_cache`) — sonst würde die laufende Dropdown-Auswahl des
Nutzers alle 0,5s auf den ersten Eintrag zurückspringen. Beim Neuaufbau
wird versucht, die vorherige Auswahl (falls der Peer noch da ist) zu
erhalten.

## Schenken — einseitige, sofortige Übergabe

- **UI:** Ressourcen-Dropdown + Mengen-`SpinBox` + "Schenken"-Button
  (`GiftRow`).
- **`request_gift_resources(to_peer_id, resource_id, amount,
  requesting_peer_id)`** (`@rpc("any_peer", "call_local", "reliable")`):
  host-seitig geprüft (genug Ressourcen, nicht an sich selbst), dann zwei
  `HomeBase.add_resources.rpc()`-Aufrufe (Abzug beim Absender, Gutschrift
  beim Ziel) — gleiches Muster wie bei Baukosten/Crafting. Keine
  Bestätigung nötig, kein Zurücknehmen.
- **Feedback:** `report_status()` an BEIDE Seiten ("X verschenkt" /
  "X von Spieler Y erhalten").

## Tauschen — echtes Angebot mit Annahme/Ablehnung

- **UI:** zwei Zeilen "Ich gebe" (`TradeOfferRow`) / "Ich will"
  (`TradeWantRow`), je Ressourcen-Dropdown + Mengen-`SpinBox`, darunter
  "Angebot senden" (`TradeOfferButton`). Darunter eine Liste
  (`OffersList`) mit allen Angeboten, die den eigenen Peer betreffen —
  eigene gesendete Angebote mit "Zurückziehen", eingehende mit
  "Annehmen"/"Ablehnen".
- **`World._trade_offers: Array`** — Quelle der Wahrheit nur auf dem Host
  (`{id, from_peer, to_peer, offer_resource, offer_amount, want_resource,
  want_amount}`), an alle Peers per `_sync_trade_offers.rpc()`
  (`@rpc("authority", "call_local", "reliable")`) gespiegelt, gleiches
  Broadcast-Muster wie `_show_status_message()`. **Bewusst KEIN Catch-up
  für spät beitretende Peers und KEINE Persistenz in
  `_collect_save_data()`/`_load_game_state()`** — offene Angebote sind ein
  kurzlebiger Zwischenzustand, gleiche Vereinfachung wie bei
  `HomeBase.unlocked_recipes` fehlendem Catch-up (siehe
  [`base.md`](base.md), "Bekannte Grenzen").
- **`request_create_trade_offer(...)`**: legt nur das Angebot an (host-
  seitige Vorab-Prüfung, ob der Ersteller sich das grundsätzlich leisten
  kann — reine Komfort-Bremse, keine Reservierung der Ressourcen).
- **`request_accept_trade_offer(offer_id, requesting_peer_id)`**: prüft
  bei der Annahme NOCHMAL beide Seiten (Bestand kann sich zwischenzeitlich
  geändert haben), baut dann für beide Home-Bases je ein Delta-Dictionary
  (statt zweier Einzel-Aufrufe, damit der Sonderfall "gleiche Ressourcenart
  auf beiden Seiten" nicht zwei widersprüchliche Keys erzeugt — gleiches
  Muster wie `request_craft()` für Kosten+Ertrag in einem Aufruf) und
  ruft `add_resources.rpc()` auf beiden Basen auf. Danach wird das Angebot
  entfernt.
- **`request_decline_trade_offer(offer_id, requesting_peer_id)`**: von
  BEIDEN Seiten aufrufbar — Empfänger lehnt ab ODER Ersteller zieht das
  eigene Angebot zurück, gleicher RPC für beide Fälle (nur ein
  Berechtigungs-Check: `requesting_peer_id` muss `from_peer` oder
  `to_peer` sein).

## Bewusst nicht umgesetzt (MVP-Abgrenzung)

- Kein Gegenangebot/Verhandeln (nur Annehmen/Ablehnen, kein Nachbessern
  eines bestehenden Angebots).
- Keine Übersicht "alle Angebote aller Spieler", nur die, die den eigenen
  Peer betreffen.
- Kein Timeout/automatisches Verfallen alter Angebote.

**Vom Nutzer bestätigt getestet (2026-08-01):** "passt tauschen und
schenken funktioniert" — Detail-Teilschritte (Ablehnen, Sonderfälle bei
zu wenig Ressourcen) siehe [`pending-tests.md`](pending-tests.md).
