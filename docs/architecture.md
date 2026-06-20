# Arquitectura — JARVIS Mobile

El proyecto sigue **Clean Architecture** con capas bien definidas. Las dependencias
siempre apuntan hacia adentro: UI → Providers → Domain → (sin dependencias externas).

---

## Estructura de carpetas

```
lib/
├── core/                          # Infraestructura transversal
│   ├── constants/
│   │   └── app_constants.dart     # URLs, timeouts, paths, comandos rápidos
│   ├── router/
│   │   └── app_router.dart        # Rutas declarativas con GoRouter
│   ├── services/
│   │   └── device_id_service.dart # UUID persistente del dispositivo
│   ├── theme/
│   │   ├── app_colors.dart        # Paleta de colores (dark/light)
│   │   ├── app_text_styles.dart   # Estilos de texto reutilizables
│   │   └── app_theme.dart         # ThemeData dark y light
│   └── transport/
│       ├── i_transport_strategy.dart  # Interfaz del transporte
│       ├── transport_factory.dart     # Factory: Direct → WebSocket
│       ├── websocket_transport.dart   # Transporte WebSocket (con reconexión)
│       └── http_sse_transport.dart    # Transporte SSE (futuro)
│
├── domain/                        # Entidades y contratos puros
│   ├── entities/
│   │   ├── connection_config.dart # Config de conexión + URLs efectivas
│   │   ├── session_state.dart     # Estado de sesión (enum SessionStatus)
│   │   ├── session_tab.dart       # Tab de sesión PTY activa
│   │   ├── terminal_block.dart    # Bloque de output (motd/command/system)
│   │   └── terminal_message.dart  # Mensaje legacy (referencia histórica)
│   ├── repositories/              # Interfaces de repositorios
│   └── usecases/                  # Casos de uso (connect, send_command)
│
├── data/                          # Implementaciones de datos
│   ├── datasources/
│   │   ├── local/
│   │   │   └── config_local_datasource.dart  # SharedPreferences
│   │   └── remote/
│   │       └── jarvis_ws_datasource.dart      # (legacy datasource)
│   ├── models/
│   │   ├── connection_config_model.dart  # JSON ↔ ConnectionConfig
│   │   └── terminal_message_model.dart
│   └── repositories/              # Implementaciones concretas
│
└── presentation/                  # UI y estado reactivo
    ├── providers/
    │   ├── config_provider.dart   # ConfigNotifier: carga/guarda config
    │   ├── terminal_provider.dart # TerminalNotifier: estado principal
    │   └── theme_provider.dart    # ThemeNotifier: dark/light/system
    ├── pages/
    │   ├── splash/                # Pantalla de carga inicial
    │   ├── setup/                 # Formulario de configuración
    │   ├── terminal/              # Terminal principal (Tab 0)
    │   │   └── widgets/
    │   │       ├── connection_status_bar.dart
    │   │       ├── helper_bar.dart          # Barra de teclas especiales
    │   │       ├── session_tab_bar.dart     # Tabs de sesiones PTY
    │   │       ├── terminal_session_view.dart  # TerminalView ↔ xterm.dart
    │   │       ├── terminal_block_widget.dart
    │   │       ├── motd_widget.dart
    │   │       └── prompt_bar.dart
    │   ├── history/               # Logs del sistema (Tab 1)
    │   └── settings/              # Ajustes (Tab 2)
    └── widgets/
        └── main_scaffold.dart     # IndexedStack con 3 tabs
```

---

## Flujo de datos

```
Usuario (toca tecla en TerminalView)
    │
    ▼
terminal.onOutput(data)          ← callback en objeto Terminal (xterm.dart)
    │
    ▼
TerminalNotifier.sendRawInput()  ← escribe al transporte activo
    │
    ▼
WebSocketTransport.send()        ← {type:"input", data:"\r", session:"id"}
    │
    ▼
Backend PTY                      ← escribe a la sesión PTY del servidor
    │
    ▼ (respuesta)
WebSocketTransport.events        ← Stream<Map<String,dynamic>>
    │
    ▼
TerminalNotifier._onEvent()      ← despacha por type
    │
    ├── type:"output"  → terminal.write(data)   ← xterm renderiza
    ├── type:"prompt"  → actualiza CWD / sessionTab
    └── type:"system"  → añade TerminalBlock al estado
```

---

## State Management (Riverpod)

### `terminalProvider` — `StateNotifier<TerminalState>`

El estado central de la app. Contiene:

```dart
class TerminalState {
  final List<TerminalBlock> blocks;     // bloques de log (MOTD, system)
  final List<SessionTab> sessions;      // sesiones PTY activas
  final String activeSessionId;
  final String currentCwd;             // directorio actual
  final SessionStatus connectionStatus;
  final bool isWaitingForPrompt;
}
```

**Métodos públicos del notifier:**

| Método | Acción |
|--------|--------|
| `connectWithConfig(config)` | Autentica (HTTP) + conecta (WebSocket) |
| `disconnect()` | Cierra el socket limpiamente |
| `sendRawInput(data, {sessionId})` | Envía keystrokes raw al PTY |
| `getTerminal(sessionId)` | Devuelve el objeto `Terminal` de xterm.dart |
| `newSession()` | Solicita nueva sesión PTY al servidor |
| `closeSession(id)` | Cierra una sesión PTY |

### `configProvider` — `StateNotifier<ConfigState>`

Persiste `ConnectionConfig` en `SharedPreferences`. Incluye: `baseUrl`,
`cloudflareUrl`, `password`, `transportType`.

### `themeProvider` — `StateNotifier<ThemeMode>`

Persiste la preferencia de tema (dark/light/system) en `SharedPreferences`.

---

## Entidad `ConnectionConfig`

```dart
class ConnectionConfig {
  final String baseUrl;         // ej: "http://192.168.1.100:3000"
  final String cloudflareUrl;   // ej: "https://jarvis.unicali.app"
  final String password;
  final TransportType transportType; // direct | telegram | cloudflare

  String get httpUrl { ... }  // URL correcta para REST según transport
  String get wsUrl  { ... }  // URL correcta para WS (https→wss)
}
```

La propiedad `_effectiveBase` despacha automáticamente entre `baseUrl` y
`cloudflareUrl` según el `transportType` activo.

---

## Protocolo WebSocket (cliente → servidor)

```json
{ "type": "auth",        "token": "<JWT>" }
{ "type": "input",       "data": "ls -la\r", "session": "sess-id" }
{ "type": "resize",      "cols": 80, "rows": 40, "session": "sess-id" }
{ "type": "session_new" }
{ "type": "session_close", "id": "sess-id" }
{ "type": "ping" }
```

```json
{ "type": "authenticated",   "connectionId": "conn-id", "sessions": [...] }
{ "type": "output",          "data": "texto\n", "session": "sess-id" }
{ "type": "prompt",          "cwd": "/path", "exitCode": 0, "session": "sess-id" }
{ "type": "session_created", "id": "sess-id", "cwd": "/path" }
{ "type": "pong" }
{ "type": "error",           "message": "..." }
```
