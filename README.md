# Resident Evil 8: Village - Aspect Ratio & Windows Native Cursor Override (16:10 / Ultrawide)

![Resident Evil Village](https://img.shields.io/badge/Game-Resident%20Evil%20Village%20(RE8)-red.svg)
![Version](https://img.shields.io/badge/Release-v1.4.2-blue.svg)
![Platform](https://img.shields.io/badge/Platform-PC%20Windows%20(DirectX%2012)-green.svg)
![Aspect Ratios](https://img.shields.io/badge/Aspect%20Ratio-16:10%20%7C%2021:9%20%7C%2032:9%20%7C%20Any-orange.svg)
![License](https://img.shields.io/badge/License-MIT-purple.svg)

Parche individual y completo para **Resident Evil 8: Village** en PC que elimina definitivamente las barras negras (letterboxing/pillarboxing) en resoluciones **16:10** *(ej. 1920x1200, 2560x1600, 2880x1800)*, **Ultrawide** *(21:9, 32:9)* y pantallas arbitrarias.

Esta versión **elimina de forma permanente el cursor interno defectuoso del juego** (el cursor negro con borde blanco) y utiliza **exclusiva y directamente el cursor de hardware de Windows** (puntero blanco 1:1), activándolo únicamente en menús, inventario y pantallas de configuración, manteniéndolo oculto durante el gameplay. Además, rediseña el menú ImGUI renombrándolo a **Aspect Ratio Config Menu** y ocultando opciones innecesarias de desarrollo.

---
## 📦 Instalación Rápida / Quick Install

### Opción 1: Instalador Automático (Recomendado)
1. Descarga el archivo **`Resident-Evil-8-Village-Aspect-Ratio-Patch-v1.4.2.zip`** desde la sección [Releases](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/releases).
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
