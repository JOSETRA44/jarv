# Terminal — Uso y Características

El tab **Terminal** es un emulador VT100 completo potenciado por `xterm.dart v4.0.0`.
Soporta aplicaciones TUI (vim, htop, gemini CLI, node REPL, etc.) con colores ANSI,
cursor posicionado, y entrada de teclado nativo desde el teclado soft de Android/iOS.

---

## Interfaz del Terminal

```
┌─────────────────────────────────────────────────────┐
│  [sess-1] [sess-2] [+]                  ← SessionTabBar
├─────────────────────────────────────────────────────┤
│                                                     │
│  JARVIS ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━           │
│    Session  mobile-a1b2c3d4                         │
│    CWD      C:\Users\USER\source\jarvis             │
│    Shell    PowerShell 7.4                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━            │
│                                                     │
│  PS C:\Users\USER> git status                       │
│  On branch main                                     │
│  nothing to commit, working tree clean              │
│                                                     │
│  PS C:\Users\USER> █                 ← cursor xterm │
│                                                     │
│                          ← TerminalView (full area) │
├─────────────────────────────────────────────────────┤
│ ESC  Tab  ↑  ↓  ←  →  ^C  ^D  ^Z    ← HelperBar   │
└─────────────────────────────────────────────────────┘
```

---

## Barra de Teclas Especiales (HelperBar)

Accesible cuando hay una sesión conectada. Envía secuencias VT al PTY directamente.

| Botón | Secuencia | Uso típico |
|-------|-----------|------------|
| `ESC` | `\x1b` | Salir de modos en vim, cancelar diálogos |
| `Tab` | `\t` | Autocompletar comandos y rutas |
| `↑` | `\x1b[A` | Historial anterior en shell / navegar listas |
| `↓` | `\x1b[B` | Historial siguiente / navegar listas |
| `←` | `\x1b[D` | Mover cursor izquierda en readline |
| `→` | `\x1b[C` | Mover cursor derecha en readline |
| `^C` | `\x03` | Interrumpir proceso en ejecución (SIGINT) |
| `^D` | `\x04` | EOF — salir de REPL, cerrar sesión SSH |
| `^Z` | `\x1a` | Suspender proceso (SIGTSTP) → bg en Unix |

---

## Sesiones PTY (Multi-tab)

El servidor mantiene una sesión PTY independiente por cada tab abierta.
Cada sesión tiene su propio proceso de shell, directorio de trabajo y scrollback.

### Abrir nueva sesión

Toca el botón **`+`** en la `SessionTabBar`. El servidor crea un nuevo proceso PTY
y responde con `{type:"session_created", id:"sess-xxx", cwd:"/path"}`.

### Cambiar entre sesiones

Toca el nombre de la sesión en la `SessionTabBar`. El estado del terminal (scrollback,
cursor, colores) se preserva en el objeto `Terminal` del provider — no se pierde al cambiar.

### Cerrar sesión

Toca la **×** al lado del nombre de la sesión.

---

## Soporte TUI completo

El emulador VT100 de `xterm.dart` soporta:

- **Colores ANSI** — 256 colores + True Color (24-bit)
- **Cursor posicionado** — aplicaciones ncurses, vim, htop
- **Secuencias de control** — borrar pantalla, mover cursor, modos alternativos
- **Scrollback buffer** — scroll manual hacia arriba para ver historial
- **Resize** — el notifier envía `{type:"resize"}` cuando cambia el layout

### Ejemplo: vim

```
# Abre vim en el backend
vim archivo.ts

# Navegación con HelperBar:
↑↓←→  → mover cursor
ESC   → volver a modo normal
i     → modo inserción (teclado soft)
:wq   → guardar y salir (teclado soft)
```

### Ejemplo: node REPL

```
node          ← abre REPL
> 2 + 2       ← escribe con teclado soft
4
> .exit       ← o usa ^D desde HelperBar
```

---

## Tab de Logs

El tab **Logs** (anteriormente "Historial") muestra eventos del sistema:

| Tipo de bloque | Color | Contenido |
|----------------|-------|-----------|
| `motd` | Azul accent | Mensaje de bienvenida al conectar |
| `system` | Amarillo/Rojo | Eventos de conexión, errores, desconexiones |

Los logs se ordenan del más reciente al más antiguo. El badge en la barra inferior
muestra el número de eventos `system` acumulados.

---

## Estados de conexión

| Estado | Color | Descripción |
|--------|-------|-------------|
| `connected` | Verde | WebSocket autenticado y activo |
| `connecting` | Naranja | Intentando conectar / reconectar |
| `disconnected` | Gris | Sin conexión — voluntaria |
| `error` | Rojo | Fallo de conexión con detalle |

La `ConnectionStatusBar` se muestra en la parte superior del terminal con el estado actual.
