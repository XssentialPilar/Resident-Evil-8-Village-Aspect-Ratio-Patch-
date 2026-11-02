# Controlador del cursor: investigación y límites de verificación

## Evidencia local

`cursor-evidence.json` se generó con `tools/RE8Patch.InspectMenus.py` leyendo únicamente el ejecutable instalado. Incluye SHA-256 y el offset del TDB69. Esta inspección verifica nombres, tipos y firmas; no demuestra visibilidad, interactividad ni latencia en ejecución.

El TDB contiene `app.MenuDefine` con identificadores separados para `Ammo`, `Health`, `InteractIcon`, `Map`, inventario, pausa, tienda y menús principales. `app.GUIManager.isShowingGUI(System.UInt32)` devuelve `System.Boolean`. `app.GUIDriver.guiStatus` es una referencia a `app.IGUIStatus`; `app.GUIStatus` contiene el campo `System.UInt32 <hash>k__BackingField`. `setShowMouseCursorGUI(Boolean)` pertenece a `app.GUIMouseCursor`, y no a `app.GUIManager` como asumía el hook anterior.

## Causas demostrables en el código anterior

1. `Graphics::on_pre_gui_draw_element` autorizaba cualquier GUI cuyo nombre no coincidiera con una lista pequeña de palabras del HUD. Una notificación o indicación con otro nombre activaba el cursor.
2. Cada activación recargaba un contador de diez fotogramas; cerrar el menú no anulaba inmediatamente esa autorización.
3. La ausencia del jugador autorizaba también cargas y transiciones; un estado GUIMaster distinto de cero y pulsar Esc/Tab/M/I se aceptaban como prueba de menú sin comprobar su apertura real.
4. Las llamadas repetidas a `ShowCursor(TRUE/FALSE)` normalizaban e incrementaban/decrementaban el contador incluso cuando la condición ya se cumplía. Había decisiones independientes en el fotograma, el procedimiento de ventana, los setters del motor y el dibujo GUI.
5. Los hooks de posición sustituían cuatro transformaciones distintas de RE Engine por coordenadas físicas del cliente; la conversión física-a-virtual perdía además su argumento de offset. Los setters/getters de visibilidad falsificados podían desactivar el modo de entrada que necesita el mapa. Son causas potenciales del fallo del mapa, pendientes de prueba funcional; no se afirma haber demostrado el arrastre real.

## Implementación candidata

`RE8CursorPolicy.hpp` contiene una lista exacta de campos autorizados de `app.MenuDefine`, sin expresiones parciales ni autorización por HUD. Los valores hash se leen mediante reflexión en ejecución. `RE8NativeCursor.hpp` consulta exclusivamente esos identificadores y reconcilia sus cambios después de UpdateGUI, con respaldo en Present cuando se omite esa entrada. Los hooks de ciclo de vida usan el despachador de REFramework y la metadata de las firmas, sin adivinar el convenio de llamada nativo.

Al solicitar ocultar un menú se excluye su estado durante el fade; las rutas de creación, reapertura del driver y pushMenu restablecen esa exclusión. El resto de menús autorizados conserva su autorización durante las transiciones. Estado desconocido implica cursor oculto; abrir Aspect Ratio Config Menu constituye una autorización independiente explícita.

La interceptación de SetCursor decide solamente dentro del área cliente enfocada del juego. Las actualizaciones nativas se ejecutan en el hilo propietario de su ventana; otras hebras publican un mensaje. No se interceptan ShowCursor ni SetCursorPos. Para mostrar se corrige condicionalmente un contador negativo con un máximo de 32 incrementos; se registra un error si ese límite impide mostrarlo. Al ocultar, minimizar o perder foco se deshacen exactamente los incrementos aportados. El gameplay oculta el glifo con SetCursor(NULL), sin decrementar repetidamente el contador.

Se eliminan los hooks de coordenadas y los setters/getters falsificados del motor. RE Engine conserva sus deltas, botones, rueda, arrastre y transformación a coordenadas virtuales. Se omite exclusivamente el dibujo del componente tipado `app.GUIMouseCursor`; no se deshabilita permanentemente su GameObject ni su actualización.

## Diagnóstico y pruebas

Las pruebas portables `tests/re8_cursor_policy_tests.cpp` comprueban la autorización exacta, el rechazo de HUD y estados desconocidos, el foco y 10.000 ciclos rápidos sin temporizadores. Estas pruebas no equivalen a interactuar con RE8.

Activar `RE8PATCH_CURSOR_DIAGNOSTICS=1` antes de iniciar el juego, o la casilla correspondiente del menú del parche, registra secuencia, QPC y hebra al publicar la política y al aplicarla en WndProc. `policy_to_apply_us` mide exclusivamente publicación-a-aplicación. No incluye la detección anterior, la consulta de estado, el tiempo hasta Present, la frecuencia de actualización ni la visualización física. No debe presentarse como latencia total ni como cero milisegundos garantizados.

Es necesario verificar en juego todos los menús autorizados, cierres y reaperturas rápidas, mapa/arrastre/rueda/selección, munición, Presiona F, notificaciones, combate, diferentes relaciones de aspecto y Alt+Tab. La metadata disponible no demuestra que todas las rutas de ciclo de vida se recorran de la misma manera en cada versión del juego. El informe general debe registrar únicamente los casos realmente ejecutados y sus resultados observados.

## Prueba de arranque fallida y corrección posterior

El primer candidato compiló, pero la prueba real del 1 de noviembre de 2026 a las 22:12:56 falló con `0xC0000005`. El registro se conserva en `artifacts/runtime/attempt-1/re8-runtime.log`. No se considera una prueba superada ni una solución publicada.

El registro muestra que los métodos base `GUIDriver.onHide` y `GUIDriver.onSuicide` tienen exactamente la misma dirección `0x7ff6ad6794b0` (RVA `0x694b0` para esa ejecución). La lectura independiente del ejecutable en disco confirma sus bytes `C2 00 00 CC...`: un stub vacío `ret 0` compartido por optimización. Después de instrumentar `onHide`, el resolvedor de HookManager siguió el salto recién instalado y volvió a instrumentar su destino como si fuera un wrapper de `onSuicide`. Esta doble instrumentación y el uso de un stub compartido son errores comprobados. El valor `RDX=0x68` durante el fallo es compatible con una llamada ajena al driver capturada por ese stub; sin un símbolo de la instrucción exacta no se presenta ese detalle como una demostración del dereference concreto.

La revisión siguiente elimina por completo `onShow/onHide/onSuicide` y conserva únicamente las operaciones sustanciales `show/hide/suicide` con firmas reales verificadas (`app.GUIDriver.ExecuteResult.Value(app.GUIRequest.Parameter)`), además de las transiciones tipadas del manager. Rechaza destinos repetidos, retornos triviales y saltos existentes antes de instrumentar; usa `ignore_jmp=true` para no seguir detours instalados. Los callbacks permanecen inactivos mientras se instalan todos los hooks. Se valida tanto el objeto administrado como su herencia de `app.GUIDriver` antes de leer `guiStatus`.

Los resultados del segundo candidato deben registrarse separadamente: la corrección del código no sustituye repetir el arranque real.

## Segundo candidato: arranque y diagnóstico de transiciones

El segundo candidato compiló y la prueba principal de ejecución alcanzó el gameplay. Ese resultado verifica el arranque corregido; no implica completar la matriz de menús y controles.

El registro real mostró muestras de publicación-a-WndProc de 45,218 ms y 67,561 ms al ocultar. También figura una muestra de 96,500 ms. Por tanto, la ocultación prácticamente instantánea sigue sin demostrarse y estas observaciones no deben presentarse como latencia cero. Son medidas de la cola y aplicación de la política, no de la pantalla física.

Se observaron publicaciones false/true consecutivas durante algunas aperturas. El registro antiguo no identificaba el menú ni la operación, por lo que no permite decidir si eran transiciones internas del motor, cambios entre submenús o exclusiones de cierre reiniciadas prematuramente. Además, mezclaba campos atómicos leídos por separado: en la secuencia 21 se imprimió una visibilidad anterior con el número y QPC de una transición posterior. Esa muestra concreta no es un par de medición válido.

La revisión posterior conserva la exclusión de cierre hasta una operación explícita de reapertura, sin reiniciarla porque una consulta transitoria devuelva false. Añade trazas opcionales `lifecycle` y `menu-edge` con nombre exacto de MenuDefine, hash, estado del motor, exclusión de cierre, estado efectivo y operación o fase que hizo la consulta. La decisión, generación y QPC se publican como una unidad; WndProc aplica y registra esa misma unidad. Los estados intermedios que se agrupen antes de aplicarse no reciben una medición de aplicación inventada.

No se introduce ningún temporizador ni nueva suposición de navegación. Es necesario volver a ejecutar y registrar las transiciones del candidato revisado; los resultados anteriores se conservan como evidencia de los límites detectados.

## Notificación al hilo de ventana

El candidato actual usa `SendNotifyMessageW` entre hilos en lugar de `PostMessageW`. La llamada no espera a que termine el procedimiento de la otra hebra; Windows entrega notificaciones enviadas antes de retirar los mensajes publicados de la cola. Esto reduce una fuente de espera por acumulación de mensajes, pero no evita que una hebra ocupada retrase su procesamiento. El efecto real debe medirse con el candidato actual. Referencias: [SendNotifyMessageW](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendnotifymessagew) y [GetMessage](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getmessage).

## Límite pendiente: solicitud y resultado de operaciones del driver

La metadata real define resultados de `GUIDriver.show/hide/suicide` mediante `app.GUIDriver.ExecuteResult.Value`, con campos `V` (`Int32`) y `H` (`UInt32`). Los estados declarados son `Done`, `Continuous`, `NoSupport` y `Already`; sus valores numéricos no se presuponen.

Las trazas nuevas identifican qué menú y qué operación solicitan abrir/cerrar. Todavía no registran el resultado devuelto por cada operación. Por ello, no se ha demostrado si alguna oscilación observada al abrir responde a un hide rechazado, redundante, interno o a un cambio legítimo entre pantallas. El controlador actual procesa la solicitud de cierre antes de conocer ese resultado. Cualquier modificación futura para distinguir solicitudes aceptadas/rechazadas deberá basarse en una traza real del retorno y compararlo con los estados reflejados del juego, sin asignar significados a números adivinados.

El cambio posterior de entrega al hilo de ventana utiliza `SendNotifyMessageW` entre hebras, conservando el retorno inmediato al emisor. Esto evita depender únicamente de la cola de mensajes publicados, pero no garantiza una latencia determinada cuando el hilo receptor está ocupado. Su efecto real exige repetir la medición del candidato que incluye el cambio.
