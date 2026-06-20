# JARVIS Mobile — Documentación

Cliente móvil Flutter para control remoto del backend JARVIS vía WebSocket.
Permite ejecutar comandos de terminal, gestionar sesiones PTY y monitorear el sistema
desde cualquier dispositivo Android/iOS, ya sea dentro de la red local o a través
de internet mediante Cloudflare Tunnel.

---

## Índice

| Documento | Descripción |
|-----------|-------------|
| [README.md](README.md) | Este archivo — inicio rápido |
| [architecture.md](architecture.md) | Estructura de capas, providers y entidades |
| [terminal.md](terminal.md) | Uso del terminal, sesiones y barra auxiliar |
| [connection.md](connection.md) | Modos de conexión: LAN directo y Cloudflare |
| [security.md](security.md) | Seguridad: Device ID, guard Cloudflare, rate limiting |

---

## Requisitos

| Herramienta | Versión mínima |
|-------------|----------------|
| Flutter SDK | 3.5.0 |
| Dart | 3.5.0 |
| Android | API 21 (Android 5.0) |
| iOS | 13.0 |
| Backend JARVIS | corriendo en el mismo servidor |

---

## Inicio rápido

### 1. Clonar y preparar

```bash
cd C:\Users\USER\source\agentes\jarv
flutter pub get
```

### 2. Ejecutar en modo debug

```bash
flutter run
```

### 3. Primer uso

1. La app abre la pantalla **Splash** → verifica si hay configuración guardada
2. Si no hay config: redirige a **Setup** → ingresa URL y contraseña del backend
3. La app intenta autenticar y conectar por WebSocket
4. Al conectar: accede al **Terminal**, **Logs** y **Ajustes** desde la barra inferior

---

## Dependencias principales

```yaml
flutter_riverpod: ^2.6.1   # State management
go_router: ^14.6.2         # Navegación declarativa
http: ^1.2.2               # Login HTTP
web_socket_channel: ^3.0.1 # Transporte WebSocket
shared_preferences: ^2.3.3 # Persistencia local
xterm: ^4.0.0              # Emulador de terminal VT100
uuid: ^4.5.1               # Device ID único
```

---

## Build de producción

```bash
# Android APK
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (requiere Mac + Xcode)
flutter build ios --release
```
