# Informe técnico — RE8 Aspect Ratio & Native Cursor Patch

Estado: **candidato de desarrollo, sin nueva release**. Trabajo realizado el 1 de noviembre de 2026, zona America/Santo_Domingo. El código compilado más reciente requiere verificación en el juego; no se declara una solución definitiva.

## Resultado real y problemas abiertos

El candidato anterior arrancó y llegó a una partida a 1920×1200. El usuario comprobó un FOV excesivamente alterado/no uniforme y que el mapa no se desplazaba como esperaba. Ambos resultados se registran como fallos, no como pruebas superadas. Las capturas `re8_2026_11_01_22_32_39_926.png` y `re8_2026_11_01_22_30_14_393.png` se conservaron localmente con hashes; no se modificaron los originales de la carpeta de capturas.

La interacción de mapa solicitada quedó precisada: clic para ampliar y mantener el mismo botón configurable para arrastrar la vista aérea; la rueda conserva el zoom. El nuevo código implementa esa entrada, pero aún debe verificarse su conexión efectiva al mapa y a los controles de cada vista. Las posiciones geográficas y los elementos de interfaz siguen bajo control del motor.

## Cursor: causa y corrección

La ruta anterior aceptaba casi cualquier GUI dibujada como prueba de menú y renovaba una autorización de diez fotogramas. El HUD podía activarla. También autorizaba teclas de apertura y la ausencia del jugador, incluso durante cargas. Se repetían bucles de `ShowCursor` desde varias rutas.

La nueva política enumera 71 campos reales de `app.MenuDefine`, agrupados en principal/submenús, pausa, configuración, Duque, inventario, guardado/carga y mapa. No se autoriza por HUD ni por ausencia del jugador. Una autoridad decide el cursor; su aplicación Win32 queda en el hilo propietario de la ventana y limitada al cliente enfocado. No se modifican cursores de otras aplicaciones.

Se retiran la retención por fotogramas y los hooks que sustituían las coordenadas o falseaban los estados de entrada. La supresión gráfica actual afecta únicamente al panel del cursor `GUIMouseCursor.cursorPanel` mediante `ForceInvisible`; permite ejecutar la ruta GUI original, conservando sus actualizaciones y pruebas de impacto. No se desactiva el GameObject completo.

Los hooks de cierre excluyen un menú durante su salida. La exclusión se conserva hasta una apertura explícita. Los destinos triviales/duplicados o ya instrumentados se rechazan. Los resultados de solicitudes de cierre no admitidas por el motor siguen siendo un caso que requiere trazas y validación; no se inventan valores de éxito para esas operaciones.

## FOV y proyección

Se encontró una brecha de integración: modificar el tamaño de la vista y calcular un FOV no garantizaba que la cámara utilizara la misma relación de aspecto. Además, capturar nuevamente un FOV ya corregido permitía acumular una modificación si había aplicaciones repetidas antes de restaurar.

`RE8CameraProjection.hpp` conserva una instantánea por cámara y ciclo. Captura FOV, eje y proporción antes de escribirlos; aplica explícitamente `Camera.AspectRatio` según el búfer físico; evita multiplicaciones acumulativas y restaura sólo los valores propios, conservando actualizaciones legítimas del motor. La lectura posterior a los setters contempla límites aplicados por el motor. Se omiten cámaras ortográficas y cámaras durante menús autorizados.

La relación de aspecto procede de la salida DXGI actual, sin lista fija de resoluciones. La proyección automática mantiene cobertura horizontal en formatos estrechos y vertical en anchos. El modo de respaldo 16:10 con barras y el menú **Aspect Ratio Config Menu** se conservan.

El valor manual `1.715` se conserva como calibración opcional; no se presenta como requisito geométrico ni como valor universal óptimo. Las instalaciones nuevas usan proyección automática. El instalador conserva configuraciones preexistentes: una anulación manual ya activada permanece activada hasta que el usuario la cambie. No se sobrescribió la configuración personal de la sesión activa para ocultar el fallo.

## Mapa: entrada y elementos fijos

Los cuatro hooks antiguos de coordenadas devolvían píxeles cliente para espacios distintos y anulaban la conversión física/virtual. Su eliminación conserva el contrato del motor, pero el ensayo del usuario mostró que eso por sí solo no resolvía la interacción solicitada.

El nuevo `RE8MapDragController.hpp` identifica el mapa por su identificador real, obtiene el driver y comprueba los estados reales `World`/`Area`. Convierte el punto mediante la función GUI original y excluye los paneles de leyenda, estado, pisos y navegación mediante sus pruebas de impacto. Un clic conserva selección/ampliación; mantener el botón y mover el ratón inicia el paneo del motor. Se puede elegir control nativo o botón izquierdo, derecho, central, Mouse 4 o Mouse 5.

La traducción se limita a los getters nativos de botones y al contexto del mapa. Los bits se recuperan de `via.hid.MouseButton`, sin inventar sus valores. No se intercepta la rueda, no se trasladan los paneles globales ni se reubican iconos. El foco, los menús del parche y los controles fuera del contenido delimitan su alcance. Si faltan firmas o destinos seguros, conserva los controles nativos y muestra el respaldo en el panel. **Debe comprobarse en ejecución que la ruta se active y que el clic, la ampliación, el arrastre y los puntos de interés respondan correctamente.**

## Compilación y pruebas ejecutadas

Compilación completa Windows x64 Release con Visual Studio 18 Build Tools/MSVC 19.51 y CMake: **correcta**. Las primeras compilaciones detectaron errores de tipos en hooks que se corrigieron antes de generar el candidato actual.

Una primera ejecución real falló con `c0000005`: `onHide` y `onSuicide` compartían un stub `ret 0`, y el segundo hook volvió a instrumentar el detour instalado. Se eliminaron esos callbacks y se añadieron comprobaciones de destino. El candidato siguiente arrancó correctamente. Los registros de ambos intentos están en `artifacts/runtime/` localmente.

| Comprobación automatizada | Resultado |
| --- | --- |
| Geometría en 11 dimensiones, ejes, cobertura y área segura | Aprobada |
| Política exacta del cursor, HUD excluido, foco y 10.000 ciclos | Aprobada |
| Proyección de cámara, 10.000 ciclos, restauración, cambios del motor y límites | Aprobada |
| Gesto de mapa, 10.000 ciclos, botón asignado, liberación y rueda preservada | Aprobada |
| Carga/configuración y diagnóstico Lua 5.4 | Aprobada |
| Instalación/retirada en fixtures | 21 comprobaciones aprobadas |
| Empaquetado, hashes y rechazos | 19 comprobaciones aprobadas |
| Configuración CMake/MSBuild en fixtures | 4 comprobaciones aprobadas |
| Preparación de fuente con repositorios Git de prueba | 13 comprobaciones aprobadas |
| Exportación de parches y aplicación inversa | Aprobada |
| Preparación idempotente del checkout real | Aprobada, sin sobrescribir cambios |

Los 57 controles de herramientas y las cinco suites no equivalen a una sesión jugable. Los fixtures de instalación/paquete/flujo de compilación usan archivos ficticios expresamente identificados; el resultado de compilación del DLL real se registra separadamente.

## Latencia y rendimiento

Las trazas del candidato anterior mostraron esperas de aplicación al hilo de ventana, incluidas muestras superiores a 45 ms y hasta aproximadamente 96,5 ms. También se descubrió una carrera que emparejaba algunas muestras con otra generación de política. No se consideran una medición fiable de latencia total.

El código actual registra la tupla generación/visibilidad/QPC de forma coherente y usa `SendNotifyMessageW` entre hilos, que no espera a la finalización de la otra hebra y se atiende antes de los mensajes publicados. Una hebra ocupada todavía puede retrasar la aplicación. **La mejora debe medirse de nuevo; no se afirma latencia cero ni ocultación instantánea demostrada.** No se han medido FPS, consumo de memoria prolongado ni impacto durante combate. Las rutas de arrastre inactivas retornan sin consultas Win32 adicionales desde los getters de botones.

## Matriz de ejecución pendiente

La configuración real observada fue 1920×1200 DirectX 12. Se observaron la partida, el menú del parche, inventario y guardado; ello no demuestra todos sus controles. Faltan verificaciones completas de cada menú, HUD, notificaciones, combate, duplicación del puntero, reaperturas rápidas, Alt+Tab, minimizar/restaurar y las medidas actuales de transición.

Las once dimensiones de la suite son casos matemáticos, no monitores verificados: 1280×1024, 1440×1080, 1620×1080, 1920×1200, 2560×1600, 1920×1080, 3440×1440, 5120×1440, 7680×1440, 1373×911 y 1080×1920. Faltan imagen final, HUD, subtítulos, selección, mapa, cambios en caliente, DPI y frecuencias. El área segura proporcional sigue siendo opcional; no se modificaron decodificadores de vídeo ni se garantiza expansión de escenas prerenderizadas.

## Organización, recuperación y GitHub

Se reorganizaron Lua, configuración, herramientas, pruebas, documentación, licencias y resultados. Se retiraron del árbol activo paquetes históricos, scripts de sustitución/publicación, copias de código/DLL y utilidades Lua sin referencias. Los originales quedan recuperables en `.recovery/`, con manifiestos y hashes; el binario de referencia está en `artifacts/baseline/`. No se borró el historial Git ni se modificó la carpeta marcada **Don't Touch This**.

Los nombres externos `dinput8.dll`, `reframework/`, `re2_fw_config.txt`, APIs/clases, licencias y atribución de Praydog se conservan por compatibilidad. Los módulos propios nuevos usan nombres RE8 por función. Los cambios del checkout externo ignorado se incluyen íntegros en los parches versionados y su procedencia.

La subida se realiza en la rama de desarrollo `work/re8-cursor-map-projection`, preservando los dos commits recientes del README remoto y la documentación original de v1.1.0. No se crea una nueva release. El paquete local incluye sólo los cuatro archivos de ejecución, instaladores, documentación y licencias; no fuentes, tests, logs, copias anteriores ni configuración personal.

## Referencias y evidencia

- [Auditoría de archivos y renombrados](file-audit.md).
- [Controlador del cursor y primer fallo de arranque](cursor-controller.md).
- [Evidencia de pantalla y mapa](aspect-evidence.md).
- [Matriz de validación](validation-matrix.md).
- `cursor-evidence.json`: metadatos del ejecutable instalado, con SHA-256; no es una prueba de interacción real.
- Reconstrucción: `patches/README.md` y `external/REFramework.source.json` del checkout fuente.

Los contratos Win32 se contrastaron con [ShowCursor](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-showcursor), [Setting the Cursor Image](https://learn.microsoft.com/en-us/windows/win32/learnwin32/setting-the-cursor-image), [SendNotifyMessageW](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendnotifymessagew) y [GetMessage](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getmessage). Las firmas concretas proceden del SDK local y del TDB69, no de nombres de GUI supuestos.
