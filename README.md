# Resident Evil 8: Village - Aspect Ratio & Ghost Cursor Fix (16:10 / Ultrawide)

![Resident Evil Village](https://img.shields.io/badge/Game-Resident%20Evil%20Village%20(RE8)-red.svg)
![Version](https://img.shields.io/badge/Release-v1.3.0-blue.svg)
![Platform](https://img.shields.io/badge/Platform-PC%20Windows%20(DirectX%2012)-green.svg)
![Aspect Ratios](https://img.shields.io/badge/Aspect%20Ratio-16:10%20%7C%2021:9%20%7C%2032:9%20%7C%20Any-orange.svg)
![License](https://img.shields.io/badge/License-MIT-purple.svg)

Parche individual y completo para **Resident Evil 8: Village** en PC que elimina definitivamente las barras negras (letterboxing/pillarboxing) en resoluciones **16:10** *(ej. 1920x1200, 2560x1600, 2880x1800)*, **Ultrawide** *(21:9, 32:9)* y pantallas arbitrarias, solucionando de raíz el infame bug del **cursor fantasma / desface de doble cursor** (GitHub Issue #1617) mediante **hooks e interceptores de bajo nivel en C++**, y **preservando el campo visual (FOV) original del juego** de forma 100% natural (Hor+).

---

## 📌 El Problema y Causa Raíz / Root Cause Analysis

### 1. Barras negras forzadas (Letterbox / Pillarbox)
Resident Evil Village fue programado internamente bloqueando la relación de aspecto a 16:9. En monitores o portátiles 16:10 (como 1920x1200 o 2880x1800), el juego añade franjas negras arriba y abajo, reduciendo el área visible y desperdiciando pantalla.

### 2. El Bug del "Cursor Fantasma" y Doble Puntero (Issue #1617)
Al intentar forzar la eliminación de las barras con mods estándar o el Aspect Ratio fix básico de REFramework:
- **Doble Cursor:** Aparece el puntero blanco de Windows superpuesto junto al cursor del juego.
- **Desface de Puntero (Offset):** El cursor interno del juego (flecha negra con contorno blanco) se desplaza verticalmente (60px en 1200p) respecto a la posición real del ratón.
- **Fallos en Clics e Inventario:** El jugador intenta hacer clic sobre un objeto del inventario, mapa o botón del menú guiándose por la imagen del cursor interno, pero los clics se registran en una coordenada desincronizada (donde realmente está el puntero de Windows oculto), haciendo imposible una navegación precisa.

### 3. Causa Raíz a Nivel de Motor RE Engine
En RE Engine existen 4 capas distintas que intervienen en la posición del cursor:
1. **Capa Win32 Client (`via.Window`):** Campo `cursor_pos` (offset `0x78`).
2. **Capa Viewport (`via.SceneView`):** Campos `size` (`0x30`), `custom_display_size` (`0x38`), `present_rect` (`0x40`) y `display_type` (`0x64`). Cuando el juego opera en modo letterbox, calcula la coordenada del ratón relativa a `present_rect` sustrayendo el offset de las barras negras ($Y_{offset} = (1200 - 1080) / 2 = 60\text{ px}$).
3. **Capa HID (`via.hid.MouseDevice`):** Métodos internos `getViewCursorPosition`, `getPresentRectCursorPosition` y `get_CursorPos`.
4. **Capa GUI Canvas (`via.gui.View`):** Método `getPhysicalToVirtualMousePos` que traduce la coordenada física de pantalla a la coordenada virtual del canvas UI del inventario y menús.

Si el juego no actualiza todas estas capas simultáneamente, el cursor gráfico del juego y el punto de impacto de clic se desincronizan.

---

## 💡 Solución de Bajo Nivel C++ en v1.3.0 / The Low-Level Native Override

1. **Hooks Nativos de C++ en Métodos Críticos de Entrada (vía MinHook / SafetyHook):**
   - Interceptación directa en `via.hid.MouseDevice::getViewCursorPosition` y `getPresentRectCursorPosition`: Devuelven de inmediato la posición física del cliente Win32 (`GetCursorPos` + `ScreenToClient`), neutralizando el cálculo de sustracción de barras negras.
   - Interceptación en `via.gui.View::getPhysicalToVirtualMousePos`: Garantiza que el canvas del inventario, mapa y menús reciba exactamente la coordenada 1:1 del ratón de Windows.
   - Interceptación en `via.hid.MouseDevice::get_CursorPos`: Sobrescribe la lectura de bajo nivel del cursor HID.

2. **Forzado de Memoria en Cada Frame (`on_frame` & `on_view_get_size`):**
   - Inyección continua en `via.Window`: `cursor_pos` = `pt.x, pt.y` exacto; `borderless_size` = `width, height` de la ventana.
   - Forzado de `via.SceneView`: `size` y `custom_display_size` = tamaño total de ventana; `present_rect` = `(0, 0, width, height)`; `display_type` = `Fit` (0).
   - `on_view_get_size`: Devuelve incondicionalmente el ancho y alto completo de la ventana para RE8.

3. **FOV 100% Natural y sin Alterar (Hor+):**
   - En `Graphics::set_ultrawide_fov`, se exime a 16:10 de cualquier recálculo o multiplicador de FOV vertical.
   - Se mantiene el FOV horizontal nativo exacto que el usuario configuró en las opciones del juego, mostrando limpiamente la escena donde estaban las franjas negras sin alejamientos ni efecto ojo de pez.

4. **Eliminación Total del Cursor Blanco Duplicado:**
   - Desactivación forzada en configuración de `REFrameworkConfig_DrawCursorWithMenuOpen`, garantizando un cursor único y perfectamente alineado.

5. **Script Supervisor Lua de Diagnóstico (`re8_aspect_ratio_fix.lua`):**
   - Panel en tiempo real dentro del menú de REFramework (`Insert`) que monitoriza deltas en px, estado del viewport y dimensiones.

---

## 📦 Contenido del Paquete

- `dinput8.dll` - Módulo nativo compilado con los hooks C++ de baja latencia e inyección en memoria.
- `re2_fw_config.txt` - Configuración precalibrada (FOV nativo 1.0, barras eliminadas, sin doble cursor).
- `reframework/autorun/re8_aspect_ratio_fix.lua` - Script supervisor de diagnóstico en tiempo real.
- `reframework/data/re8_aspect_ratio_fix.json` - Configuración predeterminada del script supervisor.
- `install.bat` - Instalador automático con detección de ruta de Resident Evil Village.
- `uninstall.bat` - Desinstalador limpio para restaurar el juego a su estado original.

---

## 🚀 Instalación

1. Descarga el archivo `.zip` del release más reciente (`Resident-Evil-8-Village-Aspect-Ratio-Patch-v1.3.0.zip`).
2. Extrae el contenido en cualquier carpeta.
3. Ejecuta `install.bat` (detectará automáticamente la carpeta de instalación de Steam del juego y copiará los archivos).
4. Inicia Resident Evil 8 Village. ¡Disfruta de tu pantalla 16:10 o Ultrawide sin barras negras, con FOV natural y con el cursor 1:1 perfectamente alineado!

---

## 🗑️ Desinstalación

Para desinstalar el mod en cualquier momento:
1. Ejecuta `uninstall.bat`.
2. Todos los archivos del parche serán eliminados de la carpeta del juego.

---

## ⚖️ Licencia
Distribuido bajo la licencia MIT. Basado en el proyecto de código abierto REFramework de praydog.
