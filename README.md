# Resident Evil 8: Village - Aspect Ratio & Windows Native Cursor Override (16:10 / Ultrawide)

![Resident Evil Village](https://img.shields.io/badge/Game-Resident%20Evil%20Village%20(RE8)-red.svg)
![Version](https://img.shields.io/badge/Release-v1.4.1-blue.svg)
![Platform](https://img.shields.io/badge/Platform-PC%20Windows%20(DirectX%2012)-green.svg)
![Aspect Ratios](https://img.shields.io/badge/Aspect%20Ratio-16:10%20%7C%2021:9%20%7C%2032:9%20%7C%20Any-orange.svg)
![License](https://img.shields.io/badge/License-MIT-purple.svg)

Parche individual y completo para **Resident Evil 8: Village** en PC que elimina definitivamente las barras negras (letterboxing/pillarboxing) en resoluciones **16:10** *(ej. 1920x1200, 2560x1600, 2880x1800)*, **Ultrawide** *(21:9, 32:9)* y pantallas arbitrarias.

Esta versión **elimina de forma permanente el cursor interno defectuoso del juego** (el cursor negro con borde blanco) y utiliza **exclusiva y directamente el cursor de hardware de Windows** (puntero blanco 1:1), activándolo únicamente en menús, inventario y pantallas de configuración, manteniéndolo oculto durante el gameplay. Además, rediseña el menú ImGUI renombrándolo a **Aspect Ratio Config Menu** y ocultando opciones innecesarias de desarrollo.

---

## 📌 El Problema y Causa Raíz / Root Cause Analysis

### 1. Barras negras forzadas (Letterbox / Pillarbox)
Resident Evil Village fue programado bloqueando la relación de aspecto a 16:9. En pantallas 16:10 (como 1920x1200 o 2880x1800), el juego fuerza franjas negras arriba y abajo.

### 2. El Bug del Cursor Fantasma y Desface (Issue #1617)
Al remover las barras negras, el juego continuaba calculando la posición gráfica del cursor interno restando el margen de letterboxing ($Y_{offset} = (1200 - 1080) / 2 = 60\text{ px}$). Esto provocaba que el sprite negro del cursor interno se desplazara hacia arriba respecto al punto de impacto real, mientras que el ratón real de Windows (el que realmente registra los clics y colisiones) permanecía invisible.

---

## ⚡ Solución de Bajo Nivel C++ en v1.4.1 / The Solution

1. **Eliminación Total y Permanente del Cursor Interno del Motor:**
   - **Hook en `via.hid.MouseDevice::set_ShowCursor`:** Registra la intención del juego de abrir menús, pero pasa incondicionalmente `false` a la rutina interna del motor RE Engine para impedir que genere o dibuje el sprite del ratón.
   - **Hook en `via.hid.MouseDevice::get_ShowCursor`:** Retorna siempre `false` a los subsistemas del juego para que ninguna capa gráfica de interfaz intente renderizar el cursor interno por software.
   - **`Graphics::on_pre_gui_draw_element`:** Intercepta y cancela incondicionalmente el renderizado de cualquier elemento o GameObject de cursor interno (`GUIMouseCursor`, `MouseCursor`, `cursor_select`, `cursor_highlight`, `DewormCursor`, etc.), así como componentes de tipo `app.GUIMouseCursor`.
   - **`ImGui::GetIO().MouseDrawCursor = false`:** Desactiva de forma fija el renderizado de cursor por software de ImGUI.

2. **Control Nativo del Cursor de Windows (1:1 Hardware):**
   - **En Menús e Inventario:** Cuando se abre el menú de pausa (`Esc`), el inventario de Ethan (`Tab`), el mapa (`M`), la tienda del Duque o los ajustes, el motor notifica el estado a través del mensaje `RE_TOGGLE_CURSOR` y los hooks de `MouseDevice`. El parche muestra de inmediato el cursor nativo de Windows (`IDC_ARROW`).
   - **Durante el Gameplay:** Fuera de los menús (mientras caminas, apuntas o exploras en primera persona), el cursor de Windows se oculta automáticamente (`SetCursor(nullptr)`), garantizando una inmersión completa y sin distracciones.
   - **Manejador Win32 Seguro (`WM_SETCURSOR`):** Controla directamente el mensaje de Windows retornando `TRUE` de manera segura, sin llamadas managed durante el inicio del juego, eliminando cualquier riesgo de cuelgue o parpadeo.

3. **Menú ImGUI Simplificado y Renombrado:**
   - La ventana principal de ImGUI ahora se titula **Aspect Ratio Config Menu**.
   - Se ocultaron módulos irrelevantes para usuarios estándar (VR, RE8VR, FreeCam, SceneMods, LooseFileLoader, etc.), dejando accesibles únicamente las opciones esenciales de **Aspect Ratio/FOV**, **Configuración** y el **Script de supervisión**.

4. **FOV 100% Natural (Hor+ Vanilla):**
   - El parche respeta el campo de visión horizontal original sin estirar, comprimir ni aplicar efectos de ojo de pez, expandiendo la geometría de forma natural en los bordes.

---

## 📦 Instalación Rápida / Quick Install

### Opción 1: Instalador Automático (Recomendado)
1. Descarga el archivo **`Resident-Evil-8-Village-Aspect-Ratio-Patch-v1.4.1.zip`** desde la sección [Releases](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/releases).
2. Extrae el contenido en cualquier carpeta.
3. Haz doble clic en **`install.bat`**. Detectará automáticamente la carpeta de Resident Evil Village en Steam e instalará todos los archivos necesarios.

### Opción 2: Instalación Manual
Copia los siguientes archivos en la carpeta raíz del juego (`C:\Program Files (x86)\Steam\steamapps\common\Resident Evil Village BIOHAZARD VILLAGE`):
- `dinput8.dll`
- La carpeta `reframework/` completa (con `reframework/autorun/re8_aspect_ratio_fix.lua`).

Inicia Resident Evil 8 Village. ¡Disfruta de tu pantalla 16:10 o Ultrawide con el puntero nativo de Windows perfectamente sincronizado en menús y sin cursor fantasma!

---

## ⚙️ Configuración y Teclas en el Juego

- **`Insert`:** Abre/cierra el **Aspect Ratio Config Menu**.
- **`F10`:** Alterna la visibilidad de la interfaz de diagnóstico del parche.

---

## 🗑️ Desinstalación

Para restaurar los archivos originales del juego:
- Ejecuta **`uninstall.bat`** o elimina manualmente `dinput8.dll` y la carpeta `reframework/` de la carpeta del juego.
