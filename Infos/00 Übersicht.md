---
tags:
  - spiel
  - godot
  - projekt
status: aktiv
erstellt: 2026-07-29
aktualisiert: 2026-07-29
---

# KoopGame — Übersicht

> [!info] Kontext
> Lucas (Entwickler) hat keine Programmiererfahrung und lernt Godot/GDScript
> direkt am Projekt. Erklärungen bleiben einsteigerfreundlich, ohne das
> Projekt zu verwässern.

Diese Notiz ist der Einstiegspunkt: Meta-Infos, Workflow, Verlauf. Das
Spielkonzept steht in [[Koop aufbaugame/01 Architektur.md]] (Konzept-Snapshot
vom 29.07.2026). Der **laufend aktuelle Implementierungsstand inkl.
Code-Erklärungen** liegt direkt im Projektordner unter `docs/` und ist hier
gespiegelt in **[[Koop aufbaugame/Claude code/ARCHITECTURE.md]]** — dort auch
pro System eine Detaildoku (Networking, Commander, World, Home-Base,
Survivor, Zombies, Scavenging), die bei jeder Erweiterung mitgepflegt wird.

---

## Verlauf des Konzepts

1. **Ursprünglicher Plan:** einfaches Kolonieaufbau-Survival, Singleplayer-
   Prototyp zuerst, manuelle Arbeiter/Truppen-Steuerung, Multiplayer-Layer
   ganz am Ende. Erste lauffähige Version bis Etappe 2 (Commit b14b137).
2. **Neustart beschlossen (29.07.2026):** alter Code war laut Lucas "nur
   zum Testen", kompletter Neuanfang mit neuem Godot-Projekt.
3. **Architektur-Session mit Claude Code (29.07.2026):** Konzept deutlich
   ausgearbeitet — von Anfang an als **Koop-Multiplayer** gedacht (Host-and-
   Play, mehrere Spieler mit getrennten Basen auf gemeinsamer Karte), mit
   Rollen/Bedürfnissen, Zonen-Claiming, Lärm-System, Permadeath. Das ist der
   **aktuell gültige Stand**, siehe [[Koop aufbaugame/01 Architektur.md]].

> [!note] Alter Code als Lernprotokoll
> Der ursprüngliche Prototyp (Etappe 0–2) ist technisch überholt, enthielt
> aber eine Lektion, die weiterhin gilt: Klick-/Eingabe-Erkennung sollte
> zentral an einer Stelle passieren, nicht über mehrere Nodes verteilt —
> sonst entstehen Wettlaufsituationen zwischen Eingabe-Pfaden. Damals in
> `main.gd` über eine einzige `intersect_point`-Abfrage gelöst. Relevant
> für die neue Codebase, auch wenn der Code selbst nicht übernommen wird.

---

## Repository

- **GitHub:** neues privates Repo — wird **bewusst erst zum Schluss**
  angelegt, nicht jetzt schon (alter Name `DreckigerDan-dev/Koop-aufbau`
  gehörte zum verworfenen Prototyp)
- **Branch:** main — direkt auf main gepusht, keine Feature-Branches
- **Workflow:** Claude Code lokal direkt im (leeren) Projektordner, `git`
  und ggf. `gh` CLI dort mitbenutzt statt ZIP-Download

> [!warning] Kein Backup, solange kein Repo existiert
> Bis das Repo angelegt ist, läuft die Entwicklung ohne Versionskontrolle —
> jede Änderung ist bis dahin nicht rücksicherbar. Lieber lokal ab und zu
> committen (`git init` + Commits reichen auch ohne Remote schon als
> Rücksprungpunkt), auch wenn das eigentliche GitHub-Repo erst später kommt.

---

## Werkzeuge & Modellwahl

- **Claude Code lokal im Projektordner** — hat direkten Datei- und
  Git-Zugriff, im Gegensatz zu dieser Vault-Session hier
- **Modell:** standardmäßig **Sonnet** (schnell, günstig, für alltägliches
  Godot-Coding ausreichend); **Opus** nur gezielt bei tiefen Refactors,
  komplexer Multiplayer-/Netzwerklogik oder hartnäckigen Bugs zuschalten

---

## Stand (29.07.2026, aus Claude-Code-Session synchronisiert)

Kompletter Flow MainMenu → Lobby → Welt ist spielbar:

- **Networking:** Host/Join per `ENetMultiplayerPeer`, Lobby mit Spielerliste, Host-only "Spiel starten" ✅
- **Commander:** Kamera-Pan/Zoom, Klick-Auswahl, Bewegungsbefehl, Multiplayer-Authority pro Spieler ✅
- **Welt:** kleine Platzhalter-Testkarte (Boden + vier durchsuchbare Platzhalter-Gebäude, `ColorRect`) ✅
- **Home-Base:** pro Spieler eigenes Ressourcen-Datenmodell (Nahrung/Baumaterial/Medizin/Munition), HUD zeigt eigene Werte live ✅
- **Survivor:** bewegbare, auswählbare Einheit, host-autoritativ simuliert, HP + Permadeath ✅
- **Scavenging:** Rechtsklick auf Gebäude → hinlaufen → automatisch durchsuchen → Loot direkt in Home-Base ✅
- **Zombies:** wandern ziellos, erkennen/verfolgen nahe Survivor, fügen bei Kontakt Schaden zu ✅

**Noch offen** (siehe Detaildocs für genaue Grenzen): echtes Stadtlayout/
Assets, Zonen-Erweiterung/Bauen, Lärm-System, Zurückschlagen/Zombie-HP,
Trage-Kapazität/Rückweg beim Scavenging, Survivor-Rekrutierung/Rollen/
Bedürfnisse/Heilung, Feldtrupp- vs. Bautrupp-Unterscheidung.

Bewusste technische Vereinfachungen fürs Grundgerüst (dokumentiert, kein
Versehen): Auswahl per Distanz-Check statt Physik-Raycast, Tasten direkt per
`Input.is_key_pressed()` statt Input-Map, `requesting_peer_id` bei Befehlen
ungeprüft vertraut (keine echte Anti-Cheat-Prüfung) — Details je in
[[Koop aufbaugame/Claude code/commander.md]] und
[[Koop aufbaugame/Claude code/survivor.md]].

---

Verwandt: [[Koop aufbaugame/01 Architektur.md]]
