# Resident Evil 8: Village - Aspect Ratio & Ghost Cursor Fix (16:10 / Ultrawide)

![Resident Evil Village](https://img.shields.io/badge/Game-Resident%20Evil%20Village%20(RE8)-red.svg)
![Version](https://img.shields.io/badge/Release-v1.0.0-blue.svg)
![Platform](https://img.shields.io/badge/Platform-PC%20Windows%20(DirectX%2012)-green.svg)
![Aspect Ratios](https://img.shields.io/badge/Aspect%20Ratio-16:10%20%7C%2021:9%20%7C%2032:9%20%7C%20Any-orange.svg)
![License](https://img.shields.io/badge/License-MIT-purple.svg)

Parche individual y completo para **Resident Evil 8: Village** en PC que elimina definitivamente las barras negras (letterboxing/pillarboxing) en resoluciones **16:10** *(ej. 1920x1200, 2560x1600, 2880x1800)*, **Ultrawide** *(21:9, 32:9)* y pantallas arbitrarias, solucionando de raíz el infame bug del **cursor fantasma / desface de doble cursor** que inutilizaba el inventario y los menús.

---

## 🔍 El Problema Original / The Original Issue

### 1. Barras negras forzadas (Letterbox / Pillarbox)
Resident Evil Village fue programado internamente bloqueando la relación de aspecto a 16:9. En monitores o portátiles 16:10 (como 1920x1200 o 2880x1800), el juego añade franjas negras arriba y abajo, reduciendo el área visible y desperdiciando pantalla.

### 2. El Bug del "Cursor Fantasma" y Doble Puntero (Issue #1617)
Al intentar forzar la eliminación de las barras con mods estándar o el Aspect Ratio fix básico:
- **Doble Cursor:** El puntero blanco de Windows aparece superpuesto durante la partida y en los bordes.
- **Desface de Puntero (Offset):** El cursor interno del juego (flecha negra con contorno blanco) se desplaza hacia arriba y a la izquierda respecto a la posición real del ratón.
- **Fallos en Clics e Inventario:** El jugador intenta hacer clic sobre un objeto del inventario, mapa o botón del menú guiándose por la imagen del cursor interno, pero los clics se registran en una coordenada desincronizada (donde realmente está el puntero de Windows oculto), haciendo imposible una navegación precisa.

---

## 💡 ¿Cómo lo soluciona este parche? / The Solution

1. **Eliminación Total de Barras Negras sin Deformación (Hor+ Scaling):**
   - Ajusta el `DisplayType` del motor `via.SceneView` dinámicamente (`Fit` / `Uniform16x10` / `Uniform21x9`).
   - Mantiene la relación de campo visual vertical (Vertical FOV lock) para que la imagen no sufra estiramientos, deformaciones ojo de pez ni pérdida de visión periférica.
   - Oculta selectivamente las máscaras de sombreado (`app.LetterBoxBehavior`, `GUI_PillarBox`, `AcLetterBox`).

2. **Sincronización 1:1 de Coordenadas de Ratón:**
   - Sincroniza la estructura `via.Window.borderless_size` (offset `0xB0`) que el motor RE Engine mantenía desactualizada para RE8.
   - Re-mapea en tiempo real las coordenadas del cursor del juego (`via.Window.cursor_pos`) al espacio del cliente en 16:10 / Ultrawide con compensación automática de márgenes.
   - Clics, arrastre de ítems en el inventario, examen de objetos en 3D, selección de armas y menús responden con **100% de precisión milimétrica**.

3. **Aislamiento del Cursor de Windows:**
   - Durante el gameplay y control de cámara, el cursor del sistema se mantiene oculto y confinado, evitando que aparezca el doble puntero blanco o que se escape a los bordes.
   - En menús y pausas, ambos cursores se encuentran exactamente en el mismo punto físico.

4. **Menú de Calibración In-Game (REFramework Overlay):**
   - Presionando la tecla **Insert** dentro del juego accedes al menú con detección automática de resolución, perfiles para 16:10, 21:9 y sliders de calibración fina para usuarios con escalado DPI de Windows personalizado (125%, 150%).

---

## 🚀 Instalación Rápida / Quick Installation

### Opción Automática (Recomendada):
1. Descarga el paquete `Resident-Evil-8-Village-Aspect-Ratio-Patch-v1.0.0.zip` desde la sección de **[Releases](https://github.com/XssentialPilar/Resident-Evil-8-Village-Aspect-Ratio-Patch-/releases)**.
2. Descomprime el contenido en una carpeta.
3. Ejecuta **`install.bat`**. Detectará tu instalación de Steam y copiará los archivos automáticamente.
4. Inicia Resident Evil 8 y disfruta de tu pantalla completa con puntero perfecto.

### Opción Manual:
1. Copia el archivo `dinput8.dll` en la carpeta principal de tu juego:
   ```text
   C:\Program Files (x86)\Steam\steamapps\common\Resident Evil Village BIOHAZARD VILLAGE\
   ```
2. Copia la carpeta `reframework` (con su contenido `autorun\re8_aspect_ratio_fix.lua` y utilidades) en la misma carpeta raíz del juego.
3. Inicia el juego.

---

## ⚙️ Configuración dentro del Juego

Para abrir o cerrar el menú de configuración:
- Presiona la tecla **`Insert`** en tu teclado.
- Despliega la pestaña **`RE8 Aspect Ratio & Cursor Patch`**.
- Opciones disponibles:
  - **Enable Aspect Ratio & Cursor Fix:** Activa o desactiva el parche completo.
  - **Remove Black Bars:** Expande el viewport 3D al 100% de la pantalla.
  - **Fix Ghost Cursor & Mouse Offset:** Sincroniza el puntero del juego con el ratón real.
  - **Adaptive Camera FOV:** Protege el campo de visión sin deformaciones.
  - **Center HUD Elements (16:9 Safe Frame):** Centra el HUD o lo deja expandido.
  - **Advanced Cursor Fine-Tuning:** Permite calibrar milimétricamente el cursor en pantallas con escalado DPI especial.

---

## 📁 Estructura del Repositorio

```text
├── dinput8.dll                        # Binario cargador optimizado de REFramework
├── install.bat                        # Script de instalación automática para Steam
├── uninstall.bat                      # Script de desinstalación limpia
├── reframework_revision.txt           # Hash de revisión de compilación
├── reframework/
│   └── autorun/
│       ├── re8_aspect_ratio_fix.lua   # Script principal de Aspect Ratio y Cursor Sync
│       └── utility/
│           ├── RE8.lua                # Biblioteca de tipos y llamadas nativas de RE8
│           ├── GameObject.lua
│           ├── ManagedObjectDict.lua
│           └── Statics.lua
├── README.md                          # Documentación del proyecto
└── LICENSE                            # Licencia MIT
```

---

## 🤝 Créditos y Agradecimientos

- **praydog** por la base de REFramework.
- Comunidad de GitHub & usuarios del reporte **Issue #1617** por las pruebas y documentación del desface en 16:10.
- Desarrollado y empaquetado por **XssentialPilar**.
