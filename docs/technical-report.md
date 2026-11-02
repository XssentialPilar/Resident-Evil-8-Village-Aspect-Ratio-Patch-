# Informe técnico — candidato de desarrollo RE8

Trabajo local iniciado el 1 de noviembre de 2026, zona America/Santo_Domingo. No se publica una versión ni se afirma una corrección definitiva antes de completar la matriz de juego.

## Causas identificadas

El controlador anterior autorizaba el cursor al dibujar casi cualquier GUI, salvo una lista pequeña de exclusiones. Las actualizaciones del HUD podían activar el mismo camino que un menú. Cada activación prolongaba el estado durante diez fotogramas; además existían activaciones por teclas y por ausencia de jugador, incluso en cargas. Varias rutas llamaban repetidamente a `ShowCursor` hasta forzar el contador.

Los hooks de coordenadas devolvían el mismo punto cliente para espacios diferentes y anulaban la conversión física/virtual de las vistas. Los hooks de visibilidad del dispositivo también cambiaban el estado semántico de entrada del motor. Estas pérdidas de información son evidencia estática de una causa plausible del mapa; la operación exacta afectada exige comprobar la sesión real.

## Cambios

- Controlador propio `RE8NativeCursor.hpp` y política `RE8CursorPolicy.hpp`, integrados desde `Graphics.cpp` y los mensajes de REFramework. Lista explícita de campos de `app.MenuDefine`, consulta tipada de `GUIManager.isShowingGUI` y reconciliación de transiciones. Ningún dibujo genérico de HUD autoriza el cursor.
- Se retiran el contador de fotogramas, las activaciones por teclas, la ausencia de jugador y los hooks que sustituyen las coordenadas. El motor conserva movimiento relativo, rueda, botones y transformaciones del mapa. La supresión visual se limita al componente de cursor identificado.
- Una autoridad lógica decide el puntero. Los cambios nativos se aplican en el hilo de ventana, con límites al área cliente enfocada y restauración de las contribuciones propias al contador de Windows. Los diagnósticos registran el intervalo interno de política a aplicación; no representan latencia del monitor.
- `RE8DisplayGeometry.hpp` calcula FOV horizontal/vertical desde la salida de renderizado actual. Conserva la configuración y el multiplicador manual `1.715`; el cálculo automático se elige desactivando la anulación manual.
- La geometría de vista afecta únicamente a la vista principal. La opción experimental de área segura utiliza el escalado proporcional del motor. No se inventan anclajes individuales para HUD, mapa o subtítulos.
- `re8_display.lua` sustituye al Lua anterior: diagnóstico y migración de configuración, sin offsets ni escrituras de memoria. La ruta de dibujo de scripts permite mostrar este panel en el menú limpio sin añadir los controles de desarrollo de la dependencia.
- Instalación y retirada mediante manifiestos y copias verificadas. Distribución con lista explícita de archivos, licencias y recibo de compilación. Limpieza recuperable y parches del código externo fuera de su checkout ignorado.

## Fallos comunicados durante la prueba real

El usuario confirmó en la sesión activa de 1920×1200 que el FOV está demasiado alterado/no uniforme y que el mapa todavía no se desplaza correctamente. La secuencia señalada es abrir mapa, hacer clic para ampliarlo y mover la vista aérea, manteniendo fijos los elementos de interfaz. La captura `re8_2026_11_01_22_32_39_926.png` documenta la imagen del candidato que se estaba probando; se conserva localmente con hash. Ambos problemas se consideran abiertos. Las pruebas matemáticas previas no validaban la proyección efectiva del motor ni esta interacción real.

El usuario mantiene la partida en ejecución y ha pedido continuar sin interrumpir procesos. No se sustituirán sus archivos mientras continúe esa prueba. Las siguientes correcciones se desarrollan en el árbol fuente.

## Verificaciones y límites

La primera compilación completa terminó correctamente con MSVC x64 Release, pero **su prueba de arranque falló** con `c0000005`. El registro reveló dos callbacks base de GUIDriver fusionados en el mismo stub `ret 0`; el segundo hook siguió el detour recién instalado. Se eliminaron esos callbacks, se añadió rechazo de destinos triviales/duplicados y se impide seguir saltos ya instrumentados. Esta revisión requiere una nueva compilación y ejecución; el primer DLL fue retirado del juego y su versión previa restaurada con éxito. Evidencia local: `artifacts/runtime/attempt-1/`.

La batería integrada completó tres suites C++/Lua y 44 comprobaciones de herramientas. Los parches exportados superaron la verificación de aplicabilidad inversa. Estos resultados no corrigen por sí solos el fallo de arranque detectado.

El estado definitivo de compilación y ejecución se añadirá tras las comprobaciones integradas. Hasta entonces no se debe tomar este candidato como validado dentro del juego.

Pruebas de herramientas ejecutadas: 21 comprobaciones de instalación y 19 de empaquetado en Windows PowerShell 5.1, todas aprobadas con fixtures. No utilizaron un DLL real ni instalaron en el juego. Las pruebas geométricas cubren once dimensiones y las de Lua validan carga, migración y diagnósticos con un entorno controlado. Los detalles están en los informes enlazados.

La ejecución de referencia del binario anterior llegó a la pantalla inicial a 1920×1200 y mostró Aspect Ratio Config Menu. Esto no valida el nuevo código. No se usa el historial de capturas como prueba de la implementación actual.

## Organización, recuperación y atribución

Se conservan `.recovery/pre-edit-project.zip`, una copia del ImGui previo y los archivos históricos retirados. `.recovery/retired-manifest.json` identifica los archivos retirados y hashes. No se elimina el historial Git ni se toca la carpeta protegida por su nombre. El binario anterior queda en `artifacts/baseline/dinput8.dll`.

Renombrados propios: Lua a `runtime/reframework/autorun/re8_display.lua`; configuración a `config/re8_display.json`; scripts a `tools/RE8Patch.*`; capturas a `docs/evidence/`. Las rutas y clases externas obligatorias conservan su nombre. La revisión del binario antiguo y la del código fuente se documentan separadamente porque difieren.

Se conserva la licencia del parche y la MIT original de Praydog, junto a los textos de las dependencias en `licenses/`. El usuario ha autorizado subir los cambios al repositorio de GitHub. Los commits de desarrollo deben conservar estas limitaciones; no se crean etiquetas ni releases.

## Evidencia complementaria

- [Auditoría de archivos, nombres e instaladores](file-audit.md).
- [Proyección, interfaz y entrada del mapa](aspect-evidence.md).
- [Matriz de escenarios y resoluciones](validation-matrix.md).
- Reconstrucción de la dependencia: `patches/README.md` en el checkout de fuentes de GitHub.

La gestión del contador sigue el contrato documentado de [ShowCursor](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-showcursor), y la limitación al cliente sigue [Setting the Cursor Image](https://learn.microsoft.com/en-us/windows/win32/learnwin32/setting-the-cursor-image). La integración utiliza las APIs del [SDK de REFramework](https://cursey.github.io/reframework-book/api/sdk.html) y su código local; los identificadores concretos de RE8 proceden del ejecutable instalado.
