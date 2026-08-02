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

## Stand (2026-07-31, veraltete 29.07.-Momentaufnahme ersetzt)

> [!warning] Diese Sektion war seit dem 29.07. nicht mehr aktualisiert
> Alter Text beschrieb noch "kleine Platzhalter-Testkarte, vier Gebäude,
> Commander-Node" — das ist seit dem 3D-Umstieg und diversen Umbauten
> längst überholt. Für den **laufend** aktuellen Stand ist
> **[[Koop aufbaugame/Claude code/status.md]]** die einzige
> Quelle, die nicht veraltet — hier nur eine grobe Momentaufnahme.

Weit über den ursprünglichen 4-Gebäude-Prototyp hinaus: komplett 3D,
eigene 5000×5000-Karte mit 5 prozedural generierten Stadt-Zonen (je ~24
Gebäude, 2 Fahrzeuge, 1 Zombie-Nest), Tag/Nacht-Zyklus mit Uhrzeit und
Horde-Nächten, Waffen-/Rüstungssystem (1 Waffen-, 1 Rüstungs-, 1
Helm-Slot), Zonen-Claiming + Gebäude-Ausbau (Krankenstation/Werkstatt/
Lager), Speichern/Laden, Minimap, Zombie-Obergrenze mit Benchmark-Tooling.
Siehe `docs/status.md` im Projektordner (bzw. die Kopie hier im Vault,
[[Koop aufbaugame/Claude code/status.md]]) für die vollständige,
chronologische Feature-Liste inkl. Testergebnissen.

**Noch offen, größte Lücken zur vollen Vision** (siehe
[[Koop aufbaugame/01 Architektur.md]]/[[Koop aufbaugame/02 Item-Liste.md]]
für den Vergleichsmaßstab): Crafting-System, Forschungsbücher, Handel
zwischen Spielern, echte Survivor-Rollen + Müdigkeit/Moral, differenzierte
Gebäudetypen mit echten Loot-Tabellen, erweitertes Waffen-/
Rüstungs-Progressionssystem, differenzierte Fahrzeugtypen, gegenseitige
Trupp-Hilfe zwischen Spielern, Blutmond-Kalender-Eskalation. Alle 3D-Assets
sind weiterhin Platzhalter-Boxen — kein einziges Blender-Modell ist bisher
im Spiel selbst verbaut.

Bewusste technische Vereinfachungen aus der Frühphase (teils inzwischen
überholt, siehe Detaildocs): Auswahl lief anfangs per Distanz-Check statt
Physik-Raycast (inzwischen echtes Raycasting), Tasten teils direkt per
`Input.is_key_pressed()` statt Input-Map, `requesting_peer_id` bei
Befehlen weiterhin ungeprüft vertraut (keine echte Anti-Cheat-Prüfung,
für ein Koop-Spiel unter Freunden bewusst so belassen).

---

Verwandt: [[Koop aufbaugame/01 Architektur.md]]
