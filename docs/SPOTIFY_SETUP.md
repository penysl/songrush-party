# Spotify Redirect URI Setup

Damit der OAuth Login später funktioniert, müssen die Redirect URIs im [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) eingetragen werden.

## 1. Android
Für die Android App nutzen wir ein Custom Scheme:
- **URI**: `com.songrush.party://callback`

## 2. Web (Localhost Entwicklung)
Flutter Web startet standardmäßig auf einem zufälligen Port. Für Spotify Auth sollten wir dies fixieren oder flexibel halten.
- **URI**: `http://localhost:PORT/callback`
- **Empfehlung**: Starte Flutter Web mit fixem Port:
  ```bash
  flutter run -d chrome --web-port 3000
  ```
- Dann trage ein: `http://localhost:3000/callback`

## 3. Production Web
Wenn die App deployed ist (z.B. Vercel/Netlify):
- **URI**: `https://deine-app-domain.com/callback`
