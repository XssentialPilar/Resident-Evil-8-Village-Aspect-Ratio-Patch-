# DirectStorage 1.4 — validación en RE8

Prueba del 2 de noviembre de 2026, America/Santo_Domingo. El usuario terminó la carga y recorrido de su partida y confirmó: «Terminé sin errores de carga ni bloqueos».

## Resultado observado

| Comprobación | Resultado |
| --- | --- |
| Lecturas PAK completadas y entregadas mediante DirectStorage | 18.011 |
| Bytes entregados | 4.543.855.912 |
| Lecturas comparadas completamente con otro handle nativo | 64 |
| Diferencias / errores de comparación | 0 / 0 |
| Timeouts / errores del runtime / asignación / copia | 0 / 0 / 0 / 0 |
| Lecturas con estado nativo del archivo preservado | 18.011, sin errores |
| Lecturas conservadas en Windows por su tamaño | 19.657 |

Los contadores se incrementan después de esperar la finalización de DirectStorage, comprobar su resultado, conservar el estado nativo del archivo, copiar los datos al juego y completar su estructura OVERLAPPED. No son únicamente solicitudes encoladas. La comparación completa corresponde a las primeras 64 lecturas exitosas, no a todos los bytes de la sesión.

## Identidad y evidencia

- DLL compilada, instalada y validada: `1D8A53EC6C9434AE08FD1E12E5CC55EE327F844D4B29BE42BDAA6607863C8094`.
- Ejecutable RE8 probado: `B489826FD3E8AEEA0DD0B1C4ADCF35D5C98D1B599EED022623AA73241FE21E3B`.
- Registro archivado SHA256: `92417960D5185B59601955898071532F5ECDFAC38F00198F6F4527854A5470EC`.
- Última muestra: `2026-11-02 17:11:51.100`, con `active=1`.
- Recibo local: `artifacts/build/RE8DirectStorageBridge-game-test.json`.
- Registro y manifiesto de instalación preservados: `artifacts/runtime/directstorage-game/verified-20261102-211808/`.

La DLL final conserva el mismo hash; empaquetar no requiere recompilar ni sustituir el archivo instalado. El empaquetador exige evidencia de partida y contadores válidos para esa DLL. Los archivos en `artifacts/` son evidencia local y no se incluyen automáticamente en Git.

## Alcance y límites

El puente usa DirectStorage para el volumen de lecturas síncronas, no alertables, de PAK de solo lectura hacia memoria CPU, incluidos los offsets explícitos OVERLAPPED sin evento usados por este ejecutable. Una lectura nativa de un byte conserva el estado del archivo y su comportamiento al llegar al final. La descompresión y subida de recursos del juego siguen siendo las originales. Las solicitudes no compatibles se conservan en la ruta nativa.

Pasaron ocho modos del harness: lectura real y concurrencia, importaciones reales del juego, OVERLAPPED síncrono contra el oráculo nativo, conflicto con hooks ajenos, rollback, timeout, handles duplicados y diferencia de datos inyectada. Incluyen offsets superiores a 4 GiB, estado de finalización, cursor, EOF y LastError.

Esta prueba confirma el uso real observado y la partida completada sin fallos de carga. No valida descompresión GPU, una mejora de FPS, todos los mods/equipos o ausencia de fallos futuros. No se convierte en una garantía del 100 %.

## Entrega

`dist/RE8DirectStorage-1.4-Game.zip` es el instalador del módulo del juego. `*-Compatibility.zip` identifica los diagnósticos independientes anteriores y no debe confundirse con esta integración. El ZIP contiene la DLL propia compilada y las herramientas/documentación necesarias. El instalador usa el NuGet original del usuario y verifica sus hashes y firmas; no se redistribuyen los binarios preview de Microsoft. Ver [instalación y retirada](DirectStorageBridge-README.md).
