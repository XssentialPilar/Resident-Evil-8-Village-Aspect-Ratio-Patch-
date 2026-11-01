# Resident Evil 8: Village - Aspect Ratio & Ghost Cursor Fix (16:10 / Ultrawide)

![Resident Evil Village](https://img.shields.io/badge/Game-Resident%20Evil%20Village%20(RE8)-red.svg)
![Version](https://img.shields.io/badge/Release-v1.2.0-blue.svg)
![Platform](https://img.shields.io/badge/Platform-PC%20Windows%20(DirectX%2012)-green.svg)
![Aspect Ratios](https://img.shields.io/badge/Aspect%20Ratio-16:10%20%7C%2021:9%20%7C%2032:9%20%7C%20Any-orange.svg)
![License](https://img.shields.io/badge/License-MIT-purple.svg)

Parche individual y completo para **Resident Evil 8: Village** en PC que elimina definitivamente las barras negras (letterboxing/pillarboxing) en resoluciones **16:10** *(ej. 1920x1200, 2560x1600, 2880x1800)*, **Ultrawide** *(21:9, 32:9)* y pantallas arbitrarias, solucionando de raíz el infame bug del **cursor fantasma / desface de doble cursor** (GitHub Issue #1617) y **preservando el campo visual (FOV) original del juego** de forma 100% natural (Hor+).

---

## 📌 El Problema y Causa Raíz / Root Cause Analysis

### 1. Barras negras forzadas (Letterbox / Pillarbox)
Resident Evil Village fue programado internamente bloqueando la relación de aspecto a 16:9. En monitores o portátiles 16:10 (como 1920x1200 o 2880x1800), el juego añade franjas negras arriba y abajo, reduciendo el área visible y desperdiciando pantalla.

### 2. El Bug del "Cursor Fantasma" y Doble Puntero (Issue #1617)
Al intentar forzar la eliminación de las barras con mods estándar o el Aspect Ratio fix básico de REFramework:
- **Doble Cursor:** Aparece el puntero blanco de Windows superpuesto junto al cursor del juego.
- **Desface de Puntero (Offset):** El cursor interno del juego (flecha negra con contorno blanco) se desplaza verticalmente (60px en 1200p) respecto a la posición real del ratón.
- **Fallos en Clics e Inventario:** El jugador intenta hacer clic sobre un objeto del inventario, mapa o botón del menú guiándose por la imagen del cursor interno, pero los clics se registran en una coordenada desincronizada (donde realmente está el puntero de Windows oculto), haciendo imposible una navegación precisa.

### 3. Causa Raíz Descubierta en REFramework
En el código de REFramework (`Graphics.cpp`), la función encargada de sincronizar el tamaño de la ventana (`correct_window_size_if_needed`) estaba condicionada por:
```cpp
if ((sdk::GameIdentity::get().is_sf6() || sdk::GameIdentity::get().is_dmc5() || sdk::GameIdentity::get().tdb_ver() >= 73) && m_ultrawide_fix->value()) {
    correct_window_size_if_needed(scene_view);
}
```
Debido a que RE8 utiliza `tdb_ver == 69`, **Resident Evil 8 quedaba completamente excluido de la sincronización de `borderless_size`**. Por tanto, `via.Window.borderless_size` permanecía congelado en 1080p, provocando que el sistema GUI del juego aplicara un desfase de 60px y una escala errónea al calcular las coordenadas del ratón.

### 4. Distorsión Excesiva del FOV
Anteriormente, al activar el fix de aspecto en REFramework, el sistema recalculaba y multiplicaba el FOV de la cámara, provocando un efecto ojo de pez o alejamiento masivo ("FOV super aumentado"). En monitores 16:10, la expansión debe ser **Hor+ pura**: mantener intacto el campo de visión horizontal (el FOV configurado en opciones por el usuario) y permitir que la escena 3D se extienda naturalmente en las zonas superior e inferior donde antes estaban las barras negras.

---

## 💡 Cómo lo soluciona la versión v1.2.0 / The Solution

1. **Binario Nativo C++ Compilado (`dinput8.dll`) con Corrección para RE8:**
   - Se añadió `sdk::GameIdentity::get().is_re8()` y `tdb_ver() >= 69` en la rutina nativa `on_view_get_size`.
   - En cada frame y en cada llamada de tamaño del motor, `window->borderless_size` se sincroniza exactamente con `window->width` y `window->height` (1920x1200 en pantallas 16:10).
   - El sistema de entrada de RE Engine calcula el punto del ratón en espacio de pantalla con escala 1.0 y desplazamiento 0, eliminando al 100% el desfase y sincronizando el cursor del juego con el ratón de Windows.

2. **FOV 100% Natural y sin Alterar (Hor+):**
   - Se corrigió la lógica de relación de aspecto para 16:10 en `set_ultrawide_fov`: el FOV horizontal se mantiene idéntico al original del juego.
   - La pantalla simplemente muestra el contenido 3D adicional detrás de las barras negras sin alejamientos ni deformaciones.

3. **Eliminación Total del Cursor Blanco Duplicado:**
   - Configuración predeterminada que desactiva `REFrameworkConfig_DrawCursorWithMenuOpen`, impidiendo que aparezca un segundo puntero blanco flotante.

4. **Script Supervisor e Interfaz de Diagnósticos en Tiempo Real:**
   - Incluye `re8_aspect_ratio_fix.lua` para verificar el estado de la sincronización en el menú de REFramework (tecla `Insert`).
   - Muestra métricas exactas: resolución activa, delta de coordenadas, dimensiones de ventana y estado del viewport.

---

## 📦 Contenido del Paquete

- `dinput8.dll` - Módulo principal de REFramework compilado nativamente con la corrección para RE8.
- `re2_fw_config.txt` - Archivo de configuración calibrado para aspecto 16:10/ultrawide, FOV natural y sin doble cursor.
- `reframework/autorun/re8_aspect_ratio_fix.lua` - Script supervisor y panel de control en pantalla.
- `reframework/data/re8_aspect_ratio_fix.json` - Configuración predeterminada del script.
- `install.bat` - Instalador automático con detección de ruta de Resident Evil Village.
- `uninstall.bat` - Desinstalador limpio para restaurar el juego a su estado original.

---

## 🚀 Instalación

1. Descarga el archivo `.zip` del release más reciente (`Resident-Evil-8-Village-Aspect-Ratio-Patch-v1.2.0.zip`).
2. Extrae el contenido en cualquier carpeta.
3. Ejecuta `install.bat` (detectará automáticamente la carpeta de instalación de Steam del juego y copiará los archivos).
4. Inicia Resident Evil 8 Village. ¡Disfruta de tu pantalla 16:10 o Ultrawide sin barras negras, con FOV natural y con el cursor perfectamente alineado!

---

## 🗑️ Desinstalación

Para desinstalar el mod en cualquier momento:
1. Ejecuta `uninstall.bat`.
2. Todos los archivos del parche serán eliminados de la carpeta del juego.

---

## ⚖️ Licencia
Distribuido bajo la licencia MIT. Basado en el proyecto de código abierto REFramework de praydog.
