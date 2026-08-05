# KoopGame — Test-/Feedback-Liste

Ihr müsst nicht stur diese Liste abarbeiten — einfach normal spielen und
dabei im Hinterkopf behalten, ob euch eines der Dinge unten auffällt. Bei
allem, was NICHT so funktioniert wie beschrieben (oder komisch aussieht):
kurz notieren was, wann, im besten Fall Screenshot. Danke euch!

## Zuerst wichtig (Basis-Check)

- [ ] Spiel startet, Host kann hosten, Mitspieler kann per IP beitreten,
      keine Abstürze beim Laden.
- [ ] Später Beitreten (nachdem schon gespielt wird) funktioniert, landet
      direkt in der laufenden Welt statt in der Lobby festzuhängen.
- [ ] UI generell: keine abgeschnittenen Buttons/Texte, keine
      überlappenden Fenster, alles lesbar (das war heute die Hauptbaustelle
      — bitte besonders genau hinschauen).

## Grundablauf

- [ ] Start-Basis wählen — Home-Base erscheint an der Stelle des gewählten
      Gebäudes (nicht mehr daneben/auf der Straße), fünf Start-Trupps
      spawnen sauber daneben, nicht ineinander/im Gebäude.
- [ ] Gebäude plündern → claimen → ausbauen (Krankenstation/Werkstatt/
      Lager/Schlafraum) — kompletter Ablauf einmal durchspielen.
- [ ] Baustellen-System: Bautrupps einer Baustelle zuweisen, Fortschritt
      wird sichtbar schneller mit mehr zugewiesenen Trupps.
- [ ] Direkt bauen (Wachposten/Mauer/Tor/Feld/Außenposten/Wachturm) —
      Vorschau vor dem Platzieren, alles landet sauber auf dem Boden.
- [ ] Zivilisten (neue Rekruten): startet unzugewiesen (blasser gefärbt),
      lässt sich nicht bewegen bis ihr "→Feld" oder "→Bau" klickt.
- [ ] Hunger/Müdigkeit/Moral sinken spürbar, erholen sich an Home-Base
      (Hunger) bzw. Schlafraum (Müdigkeit/Moral).

## Neuere/riskantere Features — besonders gegentesten

- [ ] **Fahrzeuge & Treibstoff:** einsteigen, fahren, Tank sinkt sichtbar,
      bei leerem Tank bleibt es liegen, tankt an der Home-Base automatisch
      wieder auf.
- [ ] **Banditen:** eigene Lager in der Wildnis (nicht in Städten), NPCs
      schießen aus der Distanz statt nahzukämpfen, Lager zerstörbar für
      Bonus-Loot.
- [ ] **Home-Base-Zerstörung + Rettung:** falls eine Basis auf 0 HP fällt
      (dauert lange, 500 HP) — Panel "Hilfe anfragen"/"Aufgeben" erscheint,
      Mitspieler kann per Rettungstrupp helfen.
- [ ] **Wetter-Tab:** zeigt aktuelles Wetter + nächsten Wechsel, bei Regen
      sichtbar kleinerer aufgedeckter Kartenbereich.
- [ ] **Forschungs-Tab:** zeigt Rezept-/Ausbaustufen-Status, ändert sich
      nach echter Forschung.
- [ ] **Ereignisse-Tab:** füllt sich bei Horde-Nächten/SOS-Hilferufen.
- [ ] **Zeitraffer (1x/2x/3x) + Pause:** nur Host sieht/bedient sie, wirkt
      sich für ALLE Spieler gleich aus.
- [ ] **Karte (Taste M):** öffnet Vollbild-Karte, zoombar, Klick springt
      zur Position und schließt die Karte wieder.
- [ ] **Aktive Rekrutierung ("Ruf aussenden" im Einheiten-Tab):** hat
      Cooldown (90s), meldet sich falls schon zu viele Schutzsuchende
      unterwegs sind.
- [ ] **Runner-Zombies:** nur in Horde-/Blutmond-Nächten, kleiner+schneller
      als normale Zombies, wenig HP.

## Mehrspieler-spezifisch (am besten zu zweit/dritt testen)

- [ ] **Handel-Tab:** Schenken funktioniert sofort, Tauschangebote lassen
      sich anbieten/annehmen/ablehnen/zurückziehen.
- [ ] **Gegenseitige Hilfe:** wird ein Trupp/Gebäude eines Spielers
      angegriffen, sehen ALLE anderen eine Meldung + pulsierenden roten
      Ring auf der Karte (auch in unerkundetem Gebiet).
- [ ] **Geteilter Fog of War:** von einem Spieler aufgedecktes Gebiet ist
      sofort auch für die anderen sichtbar.
- [ ] **Zombie-Skalierung:** Horde-Nächte sollten mit mehr Spielern
      sichtbar größer ausfallen.
- [ ] Jeder hat wirklich SEINE EIGENEN Ressourcen — kein gemeinsamer Topf,
      kein versehentliches Teilen.

## Speichern/Laden

- [ ] Speichern (Pause-Menü → Speichern), Hauptmenü → Laden — Ressourcen,
      Trupps, Gebäude, Fahrzeuge, Uhrzeit bleiben erhalten.
- [ ] Bekannte, akzeptierte Ausnahme: Bautrupps, die einer Baustelle
      zugewiesen waren, müssen nach dem Laden neu zugewiesen werden (kein
      Bug, ist so gewollt).

## Allgemeines Feedback

- [ ] Fühlt sich das Spieltempo/die Schwierigkeit stimmig an (zu leicht/zu
      hart, zu viel/zu wenig zu tun)?
- [ ] Ist die Steuerung/UI insgesamt verständlich, ohne die Anleitung
      gelesen zu haben?
- [ ] Irgendwas, das einfach komisch aussieht oder sich falsch anfühlt,
      auch wenn's oben nicht explizit steht — immer gerne melden.

Danke fürs Mitspielen und Testen!
