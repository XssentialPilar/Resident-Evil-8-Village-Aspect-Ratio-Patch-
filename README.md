# Resident Evil 8: Village - 16:10 Aspect Ratio & Windows Native Cursor Patch

![Resident Evil Village](https://img.shields.io/badge/Game-Resident%20Evil%20Village%20(RE8)-red.svg)
![Version](https://img.shields.io/badge/Release-v1.1.0-blue.svg)
![Platform](https://img.shields.io/badge/Platform-PC%20Windows%20(DirectX%2012)-green.svg)
![Aspect Ratio](https://img.shields.io/badge/Aspect%20Ratio-16:10%20(1920x1200%20%7C%202560x1600)-orange.svg)
![Status](https://img.shields.io/badge/Status-16:10%20Demostrable%20y%20Verificado-success.svg)
![License](https://img.shields.io/badge/License-MIT-purple.svg)

Parche individual y optimizado para **Resident Evil 8: Village** en PC. Diseñado y **comprobado de forma demostrable para pantallas con relación de aspecto 16:10** *(1920x1200p, 2560x1600p, 2880x1800p)*, eliminando completamente las barras negras horizontales (letterboxing) sin distorsionar el campo visual (FOV) ni estirar la imagen.

---

## 🎯 Características Principales

1. **Eliminación Total de Barras Negras (16:10 Verificado):**
   - Expande la imagen 3D para ocupar el 100% del área vertical y horizontal de tu monitor 16:10.
   - Sin estiramiento ni deformación anamórfica de la perspectiva.

2. **Supresión del Cursor Interno y Restauración del Cursor Nativo de Windows (1:1):**
   - **Cursor interno suprimido:** El cursor propio de RE Engine (el puntero negro con borde blanco que sufría de desface y desfase fantasma al eliminar las barras negras) ha sido **anulado y suprimido permanentemente**.
   - **Cursor de Windows 1:1 en Menús:** Se activa de forma exclusiva el puntero blanco estándar de hardware de Windows (`IDC_ARROW`), sincronizado a nivel de píxel exacto con los botones de la interfaz.
   - **Activación Inteligente Solo en Menús:** El cursor de Windows se muestra **únicamente** cuando es necesario:
     - Menú de pausa (`Esc`).
     - Inventario de Ethan (`Tab`).
     - Tienda del Duque (Mercader).
     - Mapa (`M`).
     - Menús de configuración, controles y gráficos.
     - Pantalla de inicio / Menú principal.
   - **Ocultamiento Total en Gameplay:** Durante la exploración y combate en primera persona, el cursor de Windows permanece completamente oculto para no interferir con la mira.

3. **Menú de Configuración Limpio (Aspect Ratio Config Menu):**
   - El menú de ImGUI (`Insert`) ha sido renombrado a **Aspect Ratio Config Menu (16:10 Verified)**, ocultando pestañas y opciones innecesarias de desarrollo para que el usuario tenga acceso directo a lo esencial.

---

## 📐 Configuración Óptima de FOV para 16:10 (1920x1200p)

Para obtener la mejor experiencia visual en 16:10 a 1920x1200p sin deformación, asegúrate de mantener los siguientes valores en el menú (tecla `Insert`):

| Opción en el Menú | Estado Recomendado | Explicación |
| :--- | :---: | :--- |
| **`Ultrawide/FOV/Aspect Ratio Fix`** | **Activado (ON)** | Activa el renderizado a pantalla completa sin barras negras. |
| **`16:10 Mode: Use Black Bars`** | **Desactivado (OFF)** | Debe estar apagado para eliminar las barras negras y usar toda la pantalla. |
| **`Ultrawide: Enable Vertical FOV`** | **Desactivado (OFF)** | Mantiene la escala vertical de la cámara sin alterar la altura de la vista. |
| **`Ultrawide: Override FOV`** | **Activado (ON)** | Permite calibrar el multiplicador de perspectiva. |
| **`Ultrawide: FOV Multiplier`** | **`1.715`** | **Multiplicador óptimo para 16:10 a 1920x1200p.** Proporciona el campo de visión perfecto y natural. |

> [!TIP]
> El parche viene preconfigurado de forma predeterminada con estos valores exactos en C++ para que no tengas que ajustarlos manualmente.

---

## 📦 Instalación Rápida / Quick Install

### Opción 1: Instalador Automático (Recomendado)
1. Descarga el archivo **`Resident-Evil-8-Village-16-10-Aspect-Ratio-Patch-v1.1.0.zip`** desde la sección [Releases](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/releases).
2. Extrae el contenido en cualquier carpeta.
3. Haz doble clic en **`install.bat`**. Detectará automáticamente la carpeta de Resident Evil Village en Steam e instalará todos los archivos necesarios.

### Opción 2: Instalación Manual
Copia los siguientes archivos en la carpeta raíz del juego (`C:\Program Files (x86)\Steam\steamapps\common\Resident Evil Village BIOHAZARD VILLAGE`):
- `dinput8.dll`
- `re2_fw_config.txt` (opcional, contiene la configuración recomendada pregrabada)
- La carpeta `reframework/` completa con `reframework/autorun/re8_aspect_ratio_fix.lua`.

Inicia Resident Evil 8 Village. ¡Disfruta de tu pantalla 16:10 a 1920x1200p con el puntero nativo de Windows perfectamente sincronizado en menús y sin cursor fantasma!

---

## ⚙️ Controles y Teclas

- **`Insert`:** Abre/cierra el **Aspect Ratio Config Menu (16:10 Verified)**.
- **`Tab`:** Abre el inventario de Ethan (el cursor de Windows se hace visible automáticamente).
- **`Esc`:** Abre el menú de pausa / opciones (el cursor de Windows se hace visible automáticamente).
- **`M`:** Abre el mapa (el cursor de Windows se hace visible automáticamente).

---

## 🗑️ Desinstalación

Para restaurar los archivos originales del juego:
- Ejecuta **`uninstall.bat`** o elimina manualmente `dinput8.dll` y la carpeta `reframework/` de la carpeta del juego.
