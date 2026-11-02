# Matriz de validación

Las pruebas de lógica, la compilación y la inspección de metadatos no equivalen a validar una sesión jugable. Registrar por separado observación visual, estado del controlador y tiempos medidos. No inferir una latencia de cero a partir de la ausencia de temporizadores.

| Escenario | Comprobación requerida |
| --- | --- |
| Título, principal y opciones | Cursor nativo, selección correcta, submenús sin intermitencia |
| Pausa y configuración del parche | Apertura/cierre, último menú cerrado, transición repetida |
| Inventario | Selección, colocación y arrastre de objetos, un solo puntero |
| Duque | Comprar, vender, mejoras y vuelta entre submenús |
| Guardar/cargar | Máquina de escribir, ranuras y confirmaciones |
| Mapa | Abrir, pan horizontal/vertical con controles originales, zoom y puntos de interés |
| HUD | Munición, recarga, notificación y «Presiona F» sin autorizar cursor |
| Gameplay | Exploración, apuntado y combate sin puntero |
| Foco | Alt+Tab, minimizar/restaurar, cursor sobre otra aplicación y fuera del cliente |
| Transiciones | Cargas y cambios de escena sin autorizar menús por falta de jugador |

Para el mapa, observar los controles que muestra el juego y conservar su comportamiento; no asumir que todas las pantallas usan arrastre libre con botón izquierdo. Comparar la posición de los puntos de interés y las coordenadas de selección.

| Formato | Resolución representativa | Lógica matemática | Imagen y menús en juego |
| --- | --- | --- | --- |
| 5:4 | 1280×1024 | Suite geométrica | Pendiente |
| 4:3 | 1440×1080 | Suite geométrica | Pendiente |
| 3:2 | 1620×1080 | Suite geométrica | Pendiente |
| 16:10 | 1920×1200 y 2560×1600 | Suite geométrica | Ver informe técnico |
| 16:9 | 1920×1080 | Suite geométrica | Pendiente |
| Ultrapanorámico | 3440×1440 | Suite geométrica | Pendiente |
| 32:9 | 5120×1440 | Suite geométrica | Pendiente |
| Personalizado | 1373×911 | Suite geométrica | Pendiente |
| Extremo/vertical | 7680×1440 y 1080×1920 | Suite geométrica | Pendiente |

En cada resolución: verificar círculo/objeto de referencia sin deformación, FOV, texto, márgenes, subtítulos, iconos, selección y mapa. Repetir en pantalla completa, ventana y sin bordes; probar cambio de resolución en caliente, redimensionado, DPI de Windows y frecuencias disponibles. El escalado interno de renderizado no debe confundirse con la relación de aspecto del búfer de salida.

Medir el intervalo entre el cambio de autorización y su aplicación en el hilo de ventana. La presentación física del cursor también depende de Win32, compositor y refresco; los tiempos internos no demuestran por sí solos latencia visible.
