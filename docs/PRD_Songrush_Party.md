# 🎵 Songrush Party  
**Product Requirements Document (PRD)**  
Version: 1.0  
Status: Draft  
Owner: [Dein Name]  
Tech Stack: Flutter, Supabase, Spotify Web API  
Repository: Git Versionierung  

---

# 1. Produktübersicht

## Produktname
Songrush Party

## Vision
Songrush Party ist eine mobile Multiplayer-Party-App, bei der ein Host Songs über Spotify abspielt und Spieler in Echtzeit darum wetteifern, den Songtitel möglichst schnell korrekt einzugeben.

Das Ziel ist maximale Party-Dynamik, minimale Setup-Hürden und schnelle Runden mit hohem Spaßfaktor.

---

# 2. Ziele & Nicht-Ziele

## 🎯 Ziele
- Realtime Multiplayer Song-Quiz
- Extrem schneller Einstieg (Party-Code System)
- Spotify-Integration für automatisches Abspielen
- Realtime Buzzer-System
- Skalierbar via Supabase
- Flutter Cross-Platform (iOS & Android)

## ❌ Nicht-Ziele (v1)
- Kein globales Ranking
- Keine KI-Song-Erkennung
- Keine Spotify-Alternative (nur Spotify API)
- Kein Video-Streaming
- Kein Sprachbuzzer

---

# 3. Zielgruppe
- 16–35 Jahre
- Party-Gänger
- Studenten
- WG-Abende
- Geburtstage
- Events

---

# 4. User Rollen

## 🎤 Host
- Erstellt eine Party
- Erhält Party-Code
- Startet Song-Runden
- Spielt Songs über Spotify ab
- Sieht Scores aller Spieler
- Kann Spiel beenden

## 🎮 Player
- Tritt via Party-Code bei
- Sieht aktuellen Songstatus
- Kann buzzern
- Gibt Songtitel ein
- Erhält Punkte

---

# 5. Core Features

## 5.1 Party erstellen
### Ablauf
1. Host klickt auf "Party starten"
2. App erstellt:
   - Unique Party ID
   - 6-stelligen Party-Code
3. Party wird in Supabase gespeichert
4. Host erhält Lobby Screen

---

## 5.2 Party beitreten
1. Player öffnet App
2. Gibt Party-Code ein
3. Wird der Lobby hinzugefügt
4. Host sieht Spieler in Realtime

---

## 5.3 Spielrunde Ablauf
1. Host klickt „Song starten“
2. Spotify API startet Song Playback
3. Buzzer wird für alle aktiv
4. Erster Spieler der buzzert:
   - Andere werden gesperrt
   - 15 Sekunden Timer startet
5. Spieler gibt Songtitel ein
6. Validierung:
   - Supabase prüft via Spotify Track Name
   - Fuzzy Match (min 80% Similarity)
7. Wenn korrekt:
   - +1 Punkt
8. Wenn falsch:
   - Nächster Spieler darf buzzern
9. Runde endet nach:
   - Richtigem Guess
   - Oder Timeout

---

# 6. Technische Architektur

## 6.1 Frontend
Framework: Flutter  
State Management: Riverpod oder Bloc  
Navigation: GoRouter  
Realtime: Supabase Realtime  

## 6.2 Backend
Backend: Supabase  

Enthalten:
- PostgreSQL DB
- Auth (optional anonym)
- Realtime Subscriptions
- Edge Functions (Validierung)

## 6.3 Spotify Integration
Spotify API via:
- Spotify Web API
- Playback SDK
- OAuth 2.0

Erforderlich:
- Spotify Premium Account (Host)
- Spotify Developer App
- Client ID
- Redirect URI

---

# 7. Datenbank Schema (Supabase)

## Tabelle: parties
| Feld | Typ | Beschreibung |
|------|------|-------------|
| id | uuid | Primary Key |
| code | varchar(6) | Party Code |
| host_id | uuid | Host User |
| status | enum | lobby, playing, finished |
| created_at | timestamp | |

## Tabelle: players
| Feld | Typ |
|------|------|
| id | uuid |
| party_id | uuid |
| name | varchar |
| score | int |
| is_host | boolean |

## Tabelle: rounds
| Feld | Typ |
|------|------|
| id | uuid |
| party_id | uuid |
| spotify_track_id | varchar |
| started_at | timestamp |
| winner_id | uuid |

## Tabelle: buzzers
| Feld | Typ |
|------|------|
| id | uuid |
| round_id | uuid |
| player_id | uuid |
| timestamp | timestamp |

---

# 8. Realtime Logik
Supabase Realtime Subscriptions:
- players table
- rounds table
- buzzers table
- parties status

Wichtig:
- Optimistic UI Updates
- Server Side Validation
- Edge Function für Buzzer Lock

---

# 9. Spiel-Logik Regeln
- Nur erster Buzzer zählt
- 15 Sekunden Antwortzeit
- Fuzzy Match ≥ 80%
- Keine Groß-/Kleinschreibung
- Ignoriere Sonderzeichen

---

# 10. UI Screens
1. Splash Screen
2. Home Screen
3. Party erstellen
4. Party beitreten
5. Lobby
6. Game Screen
7. Scoreboard
8. Game Over Screen

---

# 11. Sicherheit
- Row Level Security in Supabase
- Party-Code Rate Limiting
- Anti-Spam Buzzer Cooldown (1s)
- Host-only Game Controls
- Spotify Token Refresh Handling

---

# 12. Edge Cases
- Host verlässt Party → neuer Host wird ältester Player
- Spotify Playback bricht ab → Retry
- Spieler disconnected → bleibt in DB
- Zwei Spieler buzzern gleichzeitig → Server entscheidet via Timestamp

---

# 13. Monetarisierung (v2)
- Premium Themes
- Custom Playlists
- Werbung
- In-App Purchases

---

# 14. Analytics
Tracken:
- Anzahl Partys
- Ø Runden pro Party
- Erfolgsrate Guess
- Durchschnittliche Buzz Zeit

Tool: Supabase Logs oder PostHog

---

# 15. Git Struktur

/lib  
  /core  
  /features  
  /models  
  /services  
/docs  
  PRD_Songrush_Party.md  

Branch Strategy:
- main
- dev
- feature/*
- hotfix/*

---

# 16. MVP Definition
MVP =
- Party erstellen
- Party beitreten
- Spotify Song starten
- Buzzer System
- Punktevergabe
- Realtime Sync

---

# 17. Erweiterungen (Future Roadmap)
- Team Mode
- Hardcore Mode (5 Sekunden)
- Global Leaderboard
- Twitch Integration
- Web Version
- Spotify Playlist Import

---

# 18. Erfolgskriterien
- < 5 Sekunden Party Join
- < 200ms Realtime Buzzer Sync
- Keine Doppel-Buzzer
- 99% Crash-Free Sessions

---

# 19. Offene Fragen
- Playlist vom Host oder zufällig?
- Nur Titel oder auch Interpret?
- Schwierigkeitsgrad?
- Max Spieleranzahl?

---

# 20. Definition of Done
- Build erfolgreich iOS & Android
- Spotify Playback stabil
- Realtime ohne Race Conditions
- Host Migration funktioniert
- 10 User Test erfolgreich
