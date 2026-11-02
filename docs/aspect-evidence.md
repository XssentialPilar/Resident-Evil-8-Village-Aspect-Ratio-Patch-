# Evidencia: proyección, interfaz y entrada del mapa

Estado: implementación de desarrollo; pruebas dentro de Resident Evil Village pendientes. Sin publicación de una versión nueva.

## Hallazgos estáticos

- El parche sustituía `via.gui.View::getPhysicalToVirtualMousePos` por una conversión identidad. Ignoraba `offset` y la transformación propia de cada vista. También devolvía las mismas coordenadas cliente para `getViewCursorPosition`, `getPresentRectCursorPosition` y `get_CursorPos`, pese a representar espacios diferentes. Esto es una causa plausible del desfase del mapa, demostrable como pérdida de información en el código; no demuestra por sí solo qué operación concreta del mapa fallaba durante una partida.
- La supresión del cursor alteraba `set_ShowCursor`/`get_ShowCursor`, además del dibujo. El controlador del cursor elimina esas sustituciones para conservar las decisiones de entrada del motor. No se implementan arrastres, velocidades o asignaciones de botones nuevas: los controles originales siguen siendo responsabilidad del juego.
- Lua escribía dimensiones mediante offsets de memoria en tres callbacks por fotograma; C++ también reemplazaba las coordenadas de entrada. Además intentaba usar `sdk.get_main_view`, que no figura como función exportada en los bindings locales de `Sdk.cpp`. `via.Window` es una estructura nativa, no un objeto administrado CLR. Se han retirado estas escrituras y conversiones; no se ha observado una ejecución de aquel error en el juego durante esta revisión.
- El modo 16:10 con barras se reiniciaba a `false` al cargar configuración. Se sobrescribían también opciones de FOV, ocultando algunas elecciones del usuario. Se conserva ahora la configuración cargada.
- La decisión de `DisplayType` dependía de coincidencias con formatos predeterminados. La ruta RE8 utiliza `Fit` para la salida continua o `Uniform16x9` cuando se solicita el respaldo con barras en 16:10. La rama 4:3 de otros juegos se conserva.

## Implementación

- `Graphics.cpp`: dimensiones actuales desde `IDXGISwapChain::GetDesc`, en píxeles del buffer de salida. Sin deducirlas de la resolución del escritorio ni del factor de escala de Windows.
- `on_view_get_size`: aplica las dimensiones únicamente al `MainView`. Conserva vistas auxiliares, `present_rect`, `borderless_size` y las coordenadas de entrada del motor. Si no existe una salida válida o los datos del juego aún no se han inicializado, no modifica la geometría. Las consultas de metadatos de cámara toleran tipos o métodos ausentes; un FOV manual no finito no se escribe.
- `RE8DisplayGeometry.hpp`: conversión matemática entre FOV horizontal y vertical. La proyección automática conserva cobertura horizontal en salidas estrechas (Vert+) y cobertura vertical en salidas anchas (Hor+). Usa la relación de aspecto de origen que informa la cámara para evitar una segunda expansión sobre un FOV nativo ya ampliado.
- El FOV de `via.Camera` se trata en grados conforme al código existente: `Graphics.cpp` usa conversiones `glm::radians`/`glm::degrees`, y la ruta activa de `VR.cpp` calcula `glm::degrees(2 * atan(1 / projection[1][1]))` antes de llamar a `set_FOV`. Esta es evidencia de la interfaz utilizada por el SDK local, no una medición nueva dentro de RE8.
- Se conserva el multiplicador manual `1.715` y su comportamiento horizontal. La proyección automática se activa desmarcando **Manual FOV override (legacy calibration)**. No se reemplazan las preferencias existentes al cargar.
- Se expone la opción existente de interfaz proporcional mediante `FitSmallRatioAxis`, anclaje central y `ResolutionAdjust`. Permanece desactivada por defecto: los anclajes por elemento y la precisión de interacción requieren validación dentro del juego. No se inventan desplazamientos individuales de HUD, subtítulos ni puntos del mapa.
- `runtime/reframework/autorun/re8_display.lua`: diagnóstico y migración de `show_diagnostics` desde `re8_aspect_ratio_fix.json`. Guarda únicamente la nueva configuración `re8_display.json`. No registra callbacks de fotograma, HID ni dibujo GUI; no escribe estructuras del motor ni controla el cursor.

`Fit` y la modificación del tamaño de vista conservan el mecanismo utilizado por el parche previo. La uniformidad de la proyección está cubierta por pruebas matemáticas; la ausencia de estiramiento en la imagen final, los vídeos prerenderizados y los ajustes internos del juego requieren inspección visual real. No se afirma compatibilidad visual universal.

## Pruebas ejecutadas

Compilador: Microsoft C/C++ de Visual Studio 18 Build Tools, MSVC `14.51.36231`, x64. Geometría compilada con C++20 y `/W4`; sin definir `NDEBUG`.

Comando ejecutado, con el entorno `vcvars64.bat` cargado:

```bat
cl /nologo /EHsc /std:c++20 /W4 /I. tests\re8_display_geometry_tests.cpp /Fo:build-tests\re8_display_geometry_tests.obj /Fe:build-tests\re8_display_geometry_tests.exe
build-tests\re8_display_geometry_tests.exe
```

Resultado: código de salida `0`. Prueba cobertura horizontal/vertical conservada, escala de proyección uniforme en ambos ejes, equivalencia entre representación horizontal/vertical, ausencia de doble expansión, límites y área segura proporcional. Salidas numéricas observadas para una cámara de referencia con FOV horizontal 90°:

| Salida | H resultante | V resultante | Verificación en juego |
|---|---:|---:|---|
| 1280×1024 | 90.0000° | 77.3196° | Pendiente |
| 1440×1080 | 90.0000° | 73.7398° | Pendiente |
| 1620×1080 | 90.0000° | 67.3801° | Pendiente |
| 1920×1200 | 90.0000° | 64.0108° | Pendiente |
| 2560×1600 | 90.0000° | 64.0108° | Pendiente |
| 1920×1080 | 90.0000° | 58.7155° | Pendiente |
| 3440×1440 | 106.6880° | 58.7155° | Pendiente |
| 5120×1440 | 126.8700° | 58.7155° | Pendiente |
| 7680×1440 | 143.1300° | 58.7155° | Pendiente |
| 1373×911 | 90.0000° | 67.1294° | Pendiente |
| 1080×1920 | 90.0000° | 121.2840° | Pendiente |

Prueba Lua compilada y enlazada con la biblioteca Lua 5.4 ya presente en el proyecto, sin instalar dependencias nuevas:

```bat
cl /nologo /O2 /MT /EHsc /std:c++20 /Ireframework_src\dependencies\lua\src tests\re8_lua_test_runner.cpp reframework_src\build\Release\lua.lib /Fo:build-tests\re8_lua_test_runner.obj /Fe:build-tests\re8_lua_test_runner.exe
```

Se ejecutó `re8_lua_test_runner.exe tests\re8_display_diagnostics_tests.lua reframework\autorun\re8_aspect_ratio_fix.lua` antes del movimiento del script. Resultado: código `0`, `PASS`. Comprueba carga Lua 5.4, migración del booleano, renderizado del panel, dimensión cero y configuración de tipo incorrecto. El entorno de prueba carece deliberadamente de APIs de memoria, SDK, HID y fotograma.

Ruta equivalente tras la reorganización:

```bat
build-tests\re8_lua_test_runner.exe tests\re8_display_diagnostics_tests.lua runtime\reframework\autorun\re8_display.lua
```

Estos resultados verifican código y matemáticas fuera del juego. No son pruebas de menús, mapa, HUD, rendimiento, frecuencia de actualización, DPI ni cambio de resolución real. La compilación completa del DLL y las pruebas integradas se documentan en el informe principal.

## Pendiente de validación real

1. Comparar círculos y proporciones del escenario con capturas equivalentes de 16:9; revisar inventario, tienda, mapa, guardado/carga, subtítulos y notificaciones en cada formato.
2. Comprobar movimiento original del mapa, controles indicados por el propio juego, puntos seleccionables y correspondencia visual de coordenadas. No se ha verificado qué botón inicia el arrastre en esta instalación.
3. Probar con/sin override manual y con/sin área segura; confirmar que abrir el mapa no altera la cámara de gameplay ni las vistas auxiliares.
4. Cambiar resolución y tamaño de ventana mientras corre el juego; probar pantalla completa, sin bordes, escalas Windows y varias frecuencias. Medir tiempos y estabilidad, sin inferirlos de las pruebas de funciones puras.
5. Verificar películas prerenderizadas y transiciones: conservar proporcionalidad mediante opciones originales o barras cuando el contenido no permite expansión real. No se han modificado decodificadores ni texturas de vídeo.
