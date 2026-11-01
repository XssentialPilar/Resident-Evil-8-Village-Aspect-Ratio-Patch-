# Resident Evil 8: Village - Aspect Ratio & Windows Native Cursor Override (16:10 / Ultrawide)

![Resident Evil Village](https://img.shields.io/badge/Game-Resident%20Evil%20Village%20(RE8)-red.svg)
![Version](https://img.shields.io/badge/Release-v1.4.0-blue.svg)
![Platform](https://img.shields.io/badge/Platform-PC%20Windows%20(DirectX%2012)-green.svg)
![Aspect Ratios](https://img.shields.io/badge/Aspect%20Ratio-16:10%20%7C%2021:9%20%7C%2032:9%20%7C%20Any-orange.svg)
![License](https://img.shields.io/badge/License-MIT-purple.svg)

Parche individual y completo para **Resident Evil 8: Village** en PC que elimina definitivamente las barras negras (letterboxing/pillarboxing) en resoluciones **16:10** *(ej. 1920x1200, 2560x1600, 2880x1800)*, **Ultrawide** *(21:9, 32:9)* y pantallas arbitrarias.

Esta versión **elimina de forma permanente el cursor interno defectuoso del juego** (el cursor negro con borde blanco) y utiliza **exclusiva y directamente el cursor de hardware de Windows** (puntero blanco 1:1), activándolo únicamente en menús, inventario y pantallas de configuración, manteniéndolo oculto durante el gameplay. Además, rediseña el menú ImGUI renombrándolo a **Aspect Ratio Config Menu** y ocultando opciones innecesarias de desarrollo.

---

## El Problema y Causa Raíz / Root Cause Analysis

### 1. Barras negras forzadas (Letterbox / Pillarbox)
Resident Evil Village fue programado bloqueando la relación de aspecto a 16:9. En pantallas 16:10 (como 1920x1200 o 2880x1800), el juego fuerza franjas negras arriba y abajo.

### 2. El Bug del Cursor Fantasma y Desface (Issue #1617)
Al remover las barras negras, el juego continuaba calculando la posición gráfica del cursor interno restando el margen de letterboxing ($Y_{offset} = (1200 - 1080) / 2 = 60\text{ px}$). Esto provocaba que el sprite negro del cursor interno se desplazara hacia arriba respecto al punto de impacto real, mientras que el ratón real de Windows (el que realmente registra los clics y colisiones) permanecía invisible.

---

## Nueva Solución de Bajo Nivel C++ en v1.4.0 / The Solution

1. **Eliminación Total y Permanente del Cursor Interno del Juego:**
   - **`Graphics::on_pre_gui_draw_element`:** Intercepta y cancela incondicionalmente el renderizado de cualquier elemento o GameObject de cursor interno (`GUIMouseCursor`, `MouseCursor`, `cursor_select`, `cursor_highlight`, `DewormCursor`, etc.), así como componentes de tipo `app.GUIMouseCursor`.
   - **`via.gui.GUI::set_UseVirtualMouse(false)`:** Desactiva permanentemente en el motor RE Engine el renderizado de cualquier ratón virtual por software.

2. **Control Inteligente del Cursor de Windows (1:1 Hardware):**
   - **En Menús e Inventario:** Cuando se abre el menú de pausa (`Esc`), el inventario de Ethan (`Tab`), el mapa (`M`), la tienda o los ajustes de opciones, el juego solicita el cursor. El parche detecta este estado a través de los hooks de `via.hid.MouseDevice::set_ShowCursor`, `app.HIDManager::requestShowMouseCursor` y el estado del motor, forzando la visualización del puntero nativo de Windows (`ShowCursor(TRUE)` + `SetCursor(LoadCursor(NULL, IDC_ARROW))`).
   - **Durante el Gameplay:** Fuera de los menús (mientras caminas, apuntas o exploras en primera persona), el cursor de Windows se oculta automáticamente (`ShowCursor(FALSE)` + `SetCursor(nullptr)`), garantizando una inmersión completa y sin distracciones.
   - **Manejador de Mensajes Win32 (`WM_SETCURSOR`):** Asegura que el cursor se mantenga estable sin parpadeos ni interferencias del motor.

3. **Menú ImGUI Simplificado y Renombrado:**
   - La ventana principal de ImGUI ahora se titula **Aspect Ratio Config Menu**.
   - Se ocultaron módulos irrelevantes para usuarios estándar (VR, RE8VR, FreeCam, SceneMods, LooseFileLoader, etc.), dejando accesibles únicamente las opciones esenciales de **Aspect Ratio/FOV**, **Configuración** y el **Script de supervisión**.

4. **FOV 100% Natural (Hor+ Vanilla):**
   - El campo de visión horizontal se preserva intacto sin multiplicadores deformantes, extendiendo la escena 3D verticalmente sobre las barras negras.

---

## Contenido del Paquete

- `dinput8.dll` - Módulo principal compilado nativamente en C++ con la arquitectura de cursor de hardware y supresión de cursor interno.
- `re2_fw_config.txt` - Configuración precalibrada (FOV 1.0 neutro, sin barras negras, sin cursor duplicado).
- `reframework/autorun/re8_aspect_ratio_fix.lua` - Script supervisor con soporte de supresión y diagnósticos.
- `reframework/data/re8_aspect_ratio_fix.json` - Configuración persistente del script.
- `install.bat` - Instalador automático con autodetección de Resident Evil Village en Steam.
- `uninstall.bat` - Desinstalador limpio para restaurar el juego a su estado original.

---

## Instalación

1. Descarga el archivo `.zip` del release más reciente (`Resident-Evil-8-Village-Aspect-Ratio-Patch-v1.4.0.zip`).
2. Extrae el contenido en cualquier carpeta.
3. Ejecuta `install.bat` (detectará automáticamente la carpeta de instalación de Steam del juego y copiará los archivos).
4. Inicia Resident Evil 8 Village. ¡Disfruta de tu pantalla 16:10 o Ultrawide con el puntero nativo de Windows perfectamente sincronizado en menús y sin cursor fantasma!

---

## 🗑️ Desinstalación

Para desinstalar el mod en cualquier momento:
1. Ejecuta `uninstall.bat`.
2. Todos los archivos del parche serán eliminados de la carpeta del juego.

---

## ⚖️ Licencia
Distribuido bajo la licencia MIT. Basado en el proyecto de código abierto REFramework de praydog.
