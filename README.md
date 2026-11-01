# Resident Evil 8: Village - Aspect Ratio & Ghost Cursor Fix (16:10 / Ultrawide)

![Resident Evil Village](https://img.shields.io/badge/Game-Resident%20Evil%20Village%20(RE8)-red.svg)
![Version](https://img.shields.io/badge/Release-v1.1.0-blue.svg)
![Platform](https://img.shields.io/badge/Platform-PC%20Windows%20(DirectX%2012)-green.svg)
![Aspect Ratios](https://img.shields.io/badge/Aspect%20Ratio-16:10%20%7C%2021:9%20%7C%2032:9%20%7C%20Any-orange.svg)
![License](https://img.shields.io/badge/License-MIT-purple.svg)

Parche individual y completo para **Resident Evil 8: Village** en PC que elimina definitivamente las barras negras (letterboxing/pillarboxing) en resoluciones **16:10** *(ej. 1920x1200, 2560x1600, 2880x1800)*, **Ultrawide** *(21:9, 32:9)* y pantallas arbitrarias, solucionando de raíz el infame bug del **cursor fantasma / desface de doble cursor** (GitHub Issue #1617) que inutilizaba el inventario, los puzles y los menús del juego.

---

## 📌 El Problema Original / The Original Issue

### 1. Barras negras forzadas (Letterbox / Pillarbox)
Resident Evil Village fue programado internamente bloqueando la relación de aspecto a 16:9. En monitores o portátiles 16:10 (como 1920x1200 o 2880x1800), el juego añade franjas negras arriba y abajo, reduciendo el área visible y desperdiciando pantalla.

### 2. El Bug del "Cursor Fantasma" y Doble Puntero (Issue #1617)
Al intentar forzar la eliminación de las barras con mods estándar o el Aspect Ratio fix básico de REFramework:
- **Doble Cursor:** Aparece el puntero blanco de Windows superpuesto junto al cursor del juego.
- **Desface de Puntero (Offset):** El cursor interno del juego (flecha negra con contorno blanco) se desplaza vertical y horizontalmente respecto a la posición real del ratón.
- **Fallos en Clics e Inventario:** El jugador intenta hacer clic sobre un objeto del inventario, mapa o botón del menú guiándose por la imagen del cursor interno, pero los clics se registran en una coordenada desincronizada (donde realmente está el puntero de Windows oculto), haciendo imposible una navegación precisa.

### 3. Causa Raíz Técnica Identificada
En RE Engine para RE8 (`TDB_VER < 73`), el motor no actualiza las estructuras internas de ventana:
- `via.Window.borderless_size` (offset `0xB0`) queda fijado en la resolución 16:9 base (1080p).
- El sistema GUI escala los eventos de ratón asumiendo un desfase de letterbox de 60px arriba y abajo (en pantallas 1200p) o escalado `1080 / 1200 = 0.9`.
- Al quitar las barras negras en 3D, el motor GUI no se entera del nuevo tamaño de ventana y dibuja el cursor interno desfasado de la coordenada física del ratón.
- Además, la opción de REFramework `Draw Cursor With Menu Open` fuerza el dibujado del cursor de Windows por encima del juego.

---

## 💡 Cómo lo soluciona este parche (v1.1.0) / The Solution

1. **Eliminación Total de Barras Negras sin Deformación (Hor+ Scaling):**
   - Ajusta el `DisplayType` del motor `via.SceneView` dinámicamente (`Fit` / `Uniform16x10` / `Uniform21x9`).
   - Mantiene la relación de campo visual vertical (Vertical FOV lock) para que la imagen no sufra estiramientos ni distorsiones.
   - Oculta selectivamente las máscaras de sombreado (`app.LetterBoxBehavior`, `GUI_PillarBox`, `AcLetterBox`).

2. **Alineación de Memoria del Motor RE Engine en Tiempo Real:**
   - Escribe dinámicamente las dimensiones reales de pantalla en `via.Window.borderless_size` (`0xB0`, `0xB4`).
   - Sincroniza `via.SceneView.size` (`0x30`), `custom_display_size` (`0x38`) y `present_rect` (`0x40`).

3. **Sincronización 1:1 de Coordenadas de Ratón:**
   - Lee en tiempo real la posición del hardware del ratón de Windows y la inyecta directamente en `via.Window.cursor_pos` (`0x78`, `0x7C`) interceptando las fases `UpdateHID`, `UpdateGUI` y `on_frame`.
   - Incluye **Presets de Calibración instantánea**:
     - **1:1 Direct Hardware Sync (Por defecto):** Mapeo directo y nativo.
     - **16:10 Offset Compensated (+60 Y):** Cancela el desplazamiento de 60px del letterbox si el motor lo resta.
     - **16:10 Scale Compensated (x1.111 Y):** Deshace el reescalado 1080/1200.
     - **21:9 Ultrawide Offset:** Corrige monitores ultrawide.
     - **Custom Calibration:** Sliders interactivos en tiempo real para calibración manual al milímetro.

4. **Eliminación del Cursor Duplicado:**
   - Elimina el cursor blanco superpuesto de Windows para que solo exista y se mueva el cursor legítimo del juego, exactamente donde haces clic.

---

## 🎮 Controles en el Menú de REFramework

Al presionar la tecla **Insert** (o la tecla asignada para abrir el menú de REFramework), verás la sección:

```
▼ RE8 Aspect Ratio & Ghost Cursor Fix (v1.1.0)
  [x] Enable Mod
      Current Display: 1920x1200 (Aspect Ratio: 1.60:1)
      Status: 16:10 Display Detected (Native 1200p / 1600p / 1800p)
  -------------------------------------------------------------
  Aspect Ratio & Viewport Options:
  [x] Remove Black Bars (Aspect Ratio Fix)
  [x] Auto-Align Viewport & Borderless Resolution
  [x] Automatic Vertical FOV Preservation (Hor+)
  [ ] Constrain HUD Elements to 16:9 Center
  -------------------------------------------------------------
  Ghost Cursor Elimination & Alignment:
  [x] Synchronize In-Game Cursor with Mouse
      Calibration Preset: [ 1:1 Direct Hardware Sync (Default) ▼ ]
      Cursor Offset X (px)  [---------|---------] 0.0
      Cursor Offset Y (px)  [---------|---------] 0.0
      Cursor Scale X        [---------|---------] 1.000
      Cursor Scale Y        [---------|---------] 1.000
      [ Reset to 1:1 ] [ Apply 16:10 (+60px Y) ] [ Apply 16:10 Inverse Scale ]
  -------------------------------------------------------------
  [ ] Show Real-Time Diagnostics
```

---

## 📦 Instalación Rápida / Quick Installation

1. Descarga el archivo `Resident-Evil-8-Village-Aspect-Ratio-Patch-v1.1.0.zip` de los [Releases de GitHub](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/releases).
2. Extrae el contenido en la carpeta principal de tu juego:
   `C:\Program Files (x86)\Steam\steamapps\common\Resident Evil Village BIOHAZARD VILLAGE`
   *(O ejecuta `install.bat` como Administrador).*
3. Inicia el juego normalmente. ¡Las barras negras desaparecerán y el cursor responderá con total sincronización y precisión!

---

## 🗑️ Desinstalación / Uninstall

Ejecuta `uninstall.bat` o elimina los siguientes archivos de la carpeta del juego:
- `dinput8.dll`
- `reframework\autorun\re8_aspect_ratio_fix.lua`
- `re8_aspect_ratio_fix.json`

---

## 📜 Licencia / License

Distribuido bajo la licencia [MIT](LICENSE). Basado en REFramework por praydog.
