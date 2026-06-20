# Conexión — Modos de Transporte

JARVIS Mobile soporta dos modos de transporte activos. Ambos usan el mismo protocolo
WebSocket y el mismo backend — solo cambia la URL de destino.

---

## Modos disponibles

| Modo | Estado | Cuándo usar |
|------|--------|-------------|
| **Direct (LAN)** | Activo | Dentro de la red WiFi local |
| **Cloudflare Tunnel** | Activo | Desde internet (4G/5G, otra red) |
| Telegram | Próximamente | — |

---

## Direct (LAN)

Conexión directa al backend por IP local. Requiere estar en la misma red WiFi.

**Configuración:**
```
URL: http://192.168.1.100:3000   ← IP del servidor en la red local
```

**Ventajas:**
- Latencia mínima (< 5 ms en LAN)
- Sin límites de idle timeout
- Acceso al dashboard web en la misma URL

**Configurar en la app:**
1. Ajustes → Transporte → Direct (LAN)
2. O desde Setup → ingresar la IP del servidor

---

## Cloudflare Tunnel

Acceso desde internet a través del túnel cifrado de Cloudflare.
La URL pública es permanente y no cambia aunque el servidor cambie de IP.

**URL pública:** `https://jarvis.unicali.app`
- HTTP → `https://jarvis.unicali.app`
- WebSocket → `wss://jarvis.unicali.app`

**Activar en la app:**
1. Ajustes → Transporte → Cloudflare Tunnel
2. La app automáticamente usa `wss://jarvis.unicali.app` para WebSocket

**Ventajas:**
- Acceso desde cualquier red sin VPN
- HTTPS/WSS cifrado extremo a extremo
- IP del servidor oculta

**Restricciones de seguridad:**
- El dashboard web (`/`) retorna **403** desde Cloudflare (solo accesible desde LAN)
- Se requiere Device ID autorizado en el servidor (ver [security.md](security.md))

---

## Reconexión automática para redes móviles

Las redes 4G/5G tienen micro-cortes frecuentes (handoffs de torre, cambios de radio).
El transporte WebSocket implementa una estrategia de reconexión diseñada para móvil:

```
Intento 1: inmediato (0 ms)
           → cubre micro-cortes transitorios (< 1 s)

Intento 2: 2 s base ±25% jitter
Intento 3: 4 s base ±25% jitter
Intento 4: 8 s base ±25% jitter
Intento N: máximo 15 s ±25% jitter
           → cap bajo (vs 30 s previo) para mejor UX móvil
```

El jitter `±25%` evita que múltiples dispositivos reconecten simultáneamente
("thundering herd") cuando el servidor vuelve después de una caída.

### Keepalive para Cloudflare

Cloudflare cierra conexiones WebSocket inactivas después de **100 segundos**.
La app envía un `{type:"ping"}` cada **20 segundos** para mantener la conexión viva.

```
Constantes relevantes (app_constants.dart):
  pingInterval      = 20s   (< 100s idle timeout de Cloudflare)
  reconnectMaxDelay = 15s   (cap de backoff)
  reconnectInitial  = 2s    (base del exponential backoff)
```

---

## Cambiar de modo en runtime

No es necesario reiniciar la app. Desde **Ajustes → Transporte**:

1. Toca el modo deseado
2. La app desconecta el socket actual
3. Reconecta automáticamente con la URL del nuevo modo

El proceso es transparente: el terminal mantiene su estado (scrollback, sesiones).

---

## Diagnóstico de conexión

Si la conexión falla, la `ConnectionStatusBar` muestra el error específico:

| Error | Causa probable |
|-------|----------------|
| `Connection refused` | Backend no está corriendo |
| `Unauthorized` | Contraseña incorrecta |
| `Dispositivo no autorizado` | Device ID no está en `ALLOWED_DEVICE_IDS` |
| `WebSocket handshake failed` | URL incorrecta o proxy que bloquea WS |
| `Demasiados intentos` | Rate limit (5 intentos / 15 min) |

Para ver el detalle completo: **Logs** → buscar bloque `system` con el error.
