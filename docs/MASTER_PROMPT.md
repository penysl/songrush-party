# 🚀 AntiGravity Master Prompt
Projekt: Songrush Party
Stack: Flutter + Supabase + Spotify API
Ziel: Android APK + Web Build (Chrome)
Architektur: Clean Feature-Based Architecture

---

# 🧠 CONTEXT

Du entwickelst eine Production-Ready Flutter App namens "Songrush Party".

Es existiert:
- Ein Supabase Projekt (leer, Tabellen werden separat per SQL erstellt)
- Eine Spotify Developer App (Client ID vorhanden)
- Git als Versionierung
- PRD Datei im /docs Ordner

Die App muss:
- Android APK buildbar sein
- Im Browser (Flutter Web) laufen
- Supabase Realtime nutzen
- Spotify OAuth vorbereiten
- Saubere Architektur besitzen
- Null Hardcoded Secrets enthalten

---

# 🎯 PRODUKT ZIEL

Songrush Party ist eine Multiplayer Party App.

Host:
- Erstellt Party
- Erhält 6-stelligen Code
- Startet Songs via Spotify
- Sieht Scores

Player:
- Tritt via Code bei
- Kann buzzern
- Hat 15 Sekunden Antwortzeit
- Erhält Punkte bei korrektem Songtitel

Realtime Sync ist kritisch.

---

# 🏗️ ERSTELLE PROJEKTSTRUKTUR

Nutze Feature-Based Structure:

lib/
  core/
    constants/
    theme/
    utils/
    routing/
  services/
    supabase_service.dart
    spotify_service.dart
  features/
    home/
    party/
    lobby/
    game/
    scoreboard/
  models/
  main.dart

---

# ⚙️ DEPENDENCIES

Nutze folgende Packages:

- flutter_riverpod
- supabase_flutter
- go_router
- uuid
- http
- flutter_dotenv
- freezed (für Models optional)

Web Support muss aktiviert sein.
Android Support muss aktiviert sein.

---

# 🔐 ENV HANDLING

Erstelle:
.env

Beispiel:
SUPABASE_URL=
SUPABASE_ANON_KEY=
SPOTIFY_CLIENT_ID=
SPOTIFY_REDIRECT_URI=

Nutze flutter_dotenv.
Keine Keys hardcoden.

---

# 🧩 IMPLEMENTIERUNGSSCHRITTE

PHASE 1 – Grundsetup
- Flutter Projekt initialisieren
- Supabase init in main.dart
- GoRouter Setup
- Theme definieren
- Riverpod Setup

PHASE 2 – Party Core
- Party erstellen
- Party beitreten via Code
- Realtime Player Sync
- Lobby Screen mit Live Player Liste

PHASE 3 – Game Mechanik
- Runde starten
- Buzzer Button
- Lock sobald erster Buzz
- 15 Sekunden Countdown
- Antwortfeld
- Punktvergabe

PHASE 4 – Spotify Vorbereitung
- OAuth Flow vorbereiten (kein Playback MVP nötig)
- Spotify Track ID speichern
- Service Struktur vorbereiten

PHASE 5 – Scoreboard
- Live Punktestand
- Game Over Screen

---

# 📡 SUPABASE ANBINDUNG

Nutze:
Supabase.instance.client

Verwende:
- from('parties')
- from('players')
- from('rounds')
- from('buzzers')

Realtime:
channel('public:players')
.onPostgresChanges(...)

---

# 🎮 BUZZER LOGIK

WICHTIG:

- Nur erster Insert in buzzers zählt
- Bei Insert Error → UI blockieren
- Countdown Timer clientseitig
- Punktevergabe nach Validierung

---

# 📱 BUILD ANFORDERUNGEN

Android:
- minSdk 21
- Kotlin kompatibel
- APK Buildbar via:
  flutter build apk --release

Web:
- flutter build web
- Chrome testbar via:
  flutter run -d chrome

Fehlerfrei kompilierbar.

---

# 🎨 UI STYLE

Design:
- Dunkler Party Mode
- Neon Akzente (Pink / Blau)
- Große Buttons
- Animierter Buzzer

Responsiv:
- Mobile first
- Web mittig zentriert

---

# 🧪 TESTBARE KRITERIEN

MVP ist fertig wenn:

- Party erstellen funktioniert
- Player join funktioniert
- Realtime Sync funktioniert
- Buzzer Lock funktioniert
- Punktevergabe funktioniert
- APK Build ohne Fehler
- Web läuft in Chrome

---

# 🛑 WICHTIGE REGELN

- Keine toten Dateien erzeugen
- Keine Dummy Logik
- Keine Pseudocode Klassen
- Keine UI ohne Funktion
- Keine Hardcoded Daten
- Production-ready Code

---

# 🚀 ARBEITSMODUS

Arbeite iterativ.
Erzeuge erst Grundstruktur.
Dann Feature für Feature.
Erkläre kurz was du generierst.
Erzeuge lauffähigen Code.

Beginne mit PHASE 1.
