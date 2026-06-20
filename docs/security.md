# Seguridad — Modelo Zero Trust

JARVIS expone un servidor con acceso a shell completo a internet. El modelo de
seguridad implementado tiene **4 capas independientes** que deben superarse todas
para que se emita un JWT válido.

---

## Arquitectura de seguridad

```
Internet (Cloudflare Tunnel — CF-Ray header presente)
    │
    ▼
┌─ CAPA 1: Dashboard Guard ──────────────────────────────┐
│  Verifica cabecera CF-Ray en CADA request              │
│  Si CF-Ray presente + ruta no es /api/ ni /ws/ → 403  │
│  Dashboard web solo accesible desde LAN                │
└────────────────────────────────────────────────────────┘
    │ solo /api/auth/login pasa
    ▼
┌─ CAPA 2a: Rate Limiting ───────────────────────────────┐
│  Máximo 5 intentos de login por IP en 15 minutos       │
│  Intento 6+ → 429 Too Many Requests                    │
└────────────────────────────────────────────────────────┘
    │
    ▼
┌─ CAPA 2b: Password ────────────────────────────────────┐
│  Comparación directa con DASHBOARD_PASSWORD del .env   │
│  Fallo → 401 "Contraseña incorrecta"                   │
└────────────────────────────────────────────────────────┘
    │
    ▼
┌─ CAPA 2c: Device ID (Zero Trust) ─────────────────────┐
│  deviceId del body debe estar en ALLOWED_DEVICE_IDS    │
│  UUID generado una vez en la app, persiste para siempre│
│  Fallo → 401 "Dispositivo no autorizado"               │
└────────────────────────────────────────────────────────┘
    │
    ▼
┌─ JWT emitido ──────────────────────────────────────────┐
│  Expira en 2 horas (antes: 8 horas)                    │
│  Payload: { role: "admin", deviceId: "uuid" }          │
│  Firmado con JWT_SECRET del .env (min 32 chars)        │
└────────────────────────────────────────────────────────┘
```

---

## Device ID — Identificador de Hardware

### Qué es

Un UUID v4 generado **una sola vez** por la app en el primer arranque.
Se persiste en `SharedPreferences` con la clave `jarvis_device_id` y nunca cambia
(a menos que el usuario desinstale la app o limpie los datos).

### Cómo se genera (Flutter)

```dart
// lib/core/services/device_id_service.dart
class DeviceIdService {
  static Future<String> get() async {
    // 1. Si está en caché en memoria → retorna inmediato
    // 2. Si está en SharedPreferences → retorna desde disco
    // 3. Si no existe → genera UUID v4, guarda, retorna
  }
}
```

### Dónde se usa

Se incluye en **cada request de login**:

```json
POST /api/auth/login
{
  "password": "tu-contraseña",
  "deviceId": "1344eb4b-9e65-4dc1-aea9-31b007ff9720"
}
```

### Cómo ver el Device ID de tu teléfono

1. Abre la app
2. Ve a **Ajustes → Seguridad**
3. El Device ID aparece truncado en la fila "Device ID"
4. Toca el ícono de copiar (📋) para copiarlo al portapapeles

---

## Activar la validación de Device ID

Por defecto, `ALLOWED_DEVICE_IDS` está vacío → la validación está **desactivada**
(compatible con el dashboard web que no envía `deviceId`).

### Pasos para activar

**Paso 1:** Obtener el Device ID del teléfono autorizado

```
App → Ajustes → Seguridad → copiar Device ID
```

**Paso 2:** Agregar al `.env` del servidor

```env
# C:\Users\USER\source\agentes\jarvis\.env
ALLOWED_DEVICE_IDS=1344eb4b-9e65-4dc1-aea9-31b007ff9720
```

**Paso 3:** Reiniciar el servidor

```bash
npm run dev
```

**Paso 4:** Verificar que el teléfono conecta correctamente y que otro dispositivo es rechazado.

### Múltiples dispositivos autorizados

Separar los UUIDs con comas:

```env
ALLOWED_DEVICE_IDS=uuid-del-telefono-1,uuid-del-tablet-2,uuid-del-telefono-3
```

---

## Configuración del servidor

Todas las variables de seguridad están en `C:\Users\USER\source\agentes\jarvis\.env`:

```env
# Contraseña del dashboard (mínimo 8 caracteres)
DASHBOARD_PASSWORD=tu-contraseña-segura

# Clave de firma JWT (mínimo 32 caracteres — NO compartir)
JWT_SECRET=clave-super-secreta-de-al-menos-32-caracteres

# UUIDs autorizados separados por coma (vacío = sin restricción)
ALLOWED_DEVICE_IDS=1344eb4b-9e65-4dc1-aea9-31b007ff9720

# Orígenes CORS permitidos (dashboard web local)
CORS_ORIGINS=http://localhost:3000
```

---

## Verificación de las capas de seguridad

### Capa 1 — Dashboard bloqueado desde Cloudflare

```bash
# Desde internet → debe retornar 403
curl -H "CF-Ray: test-abc123" https://jarvis.unicali.app/
# Esperado: {"error":"Dashboard access is restricted to the local network."}

# API sigue funcionando desde internet
curl -X POST https://jarvis.unicali.app/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"password":"tu-pass","deviceId":"uuid-valido"}'
# Esperado: {"token":"..."}
```

### Capa 2a — Rate limiting

```bash
# 6 intentos fallidos seguidos desde la misma IP:
for i in {1..6}; do
  curl -s -X POST http://localhost:3000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"password":"incorrecta"}' | jq .error
done
# El 6° intento responde: "Demasiados intentos. Espera 15 minutos."
```

### Capa 2c — Device ID no autorizado

```bash
curl -X POST https://jarvis.unicali.app/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"password":"correcta","deviceId":"uuid-no-autorizado"}'
# Esperado: 401 {"error":"Dispositivo no autorizado"}
```

---

## Amenazas mitigadas

| Amenaza | Mitigación |
|---------|------------|
| Acceso al dashboard web desde internet | Capa 1: guard CF-Ray → 403 |
| Brute force de contraseña | Capa 2a: 5 intentos / 15 min por IP |
| Contraseña filtrada usada desde otro dispositivo | Capa 2c: Device ID no coincide |
| Token JWT robado de larga duración | JWT expira en 2h (antes: 8h) |
| CORS abierto (cross-origin requests) | CORS_ORIGINS allowlist |
| Sin trazabilidad de accesos | Logs en servidor: `[AUTH] Login OK/FAIL` |

---

## Logs de auditoría del servidor

Todos los intentos de login se registran en la consola del servidor:

```
[AUTH] Login OK    — IP: 189.xxx.xxx.xxx, deviceId: 1344eb4b-...
[AUTH] Wrong password — IP: 45.xxx.xxx.xxx
[AUTH] Unauthorized device — IP: 203.xxx.xxx.xxx, deviceId: abc-123
[AUTH] Rate limit exceeded — IP: 185.xxx.xxx.xxx
```

---

## Consideraciones adicionales

- **JWT_SECRET** debe ser una cadena larga y aleatoria. Generar con:
  ```bash
  node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
  ```
- **DASHBOARD_PASSWORD** debe tener al menos 12 caracteres y no ser una palabra del diccionario.
- Si se desinstala la app y se reinstala, se genera un nuevo Device ID — hay que actualizar `ALLOWED_DEVICE_IDS`.
- El rate limiter es en memoria: se resetea al reiniciar el servidor.
