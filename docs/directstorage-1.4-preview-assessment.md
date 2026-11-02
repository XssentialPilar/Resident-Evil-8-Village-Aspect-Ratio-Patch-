# Evaluación del paquete DirectStorage 1.4 Preview

Fecha: 2026-11-02. Estado: inventario estático y verificación de firmas; **sin integración ni ejecución del runtime DirectStorage dentro de RE8**.

El paquete es auténtico según las verificaciones realizadas, pero copiar sus DLL no convierte el streaming de RE8 en DirectStorage. Además, los términos incluidos para estos binarios de prueba no permiten asumir su redistribución en nuestro ZIP público. La mejora del FOV y del viewport no depende de este SDK.

## Paquete local verificado

Archivo: `microsoft.direct3d.directstorage.1.4.0-preview1-2603.504.nupkg`, 4.001.190 bytes.

SHA-256: `5E0EC8178EDD0F5B6EDABA8EC89D3540DC2AE17A9D2DD70E5737ADAC3F50C590`.

El `.nuspec` identifica `Microsoft.Direct3D.DirectStorage`, versión `1.4.0-preview1-2603.504`, autor Microsoft. El campo `requireLicenseAcceptance=false` es metadato de NuGet; no sustituye las condiciones de licencia de los archivos. La [ficha oficial de esta versión](https://www.nuget.org/packages/Microsoft.Direct3D.DirectStorage/1.4.0-preview1-2603.504) confirma que se trata de un paquete preliminar.

Se ejecutó `dotnet nuget verify microsoft.direct3d.directstorage.1.4.0-preview1-2603.504.nupkg --all`, con código de salida 0. Se verificaron las firmas de autor Microsoft Corporation y del repositorio NuGet.org. Sus huellas SHA-256 de certificado son, respectivamente:

- `566A31882BE208BE4422F7CFD66ED09F5D4524A5994F50CCC8B05EC0528C1353`.
- `1F4B311D9ACC115C8DC8018B5A49E00FCE6DA8E2855F9F014CA6F34570BC482D`.

Una verificación criptográfica valida procedencia e integridad; no demuestra compatibilidad, rendimiento ni permiso de redistribución.

## Contenido y firmas x64

El archivo contiene 23 entradas: metadatos NuGet, firma del paquete, README, tres documentos de licencia/notificaciones, objetivos MSBuild, icono, dos cabeceras, metadatos WinMD y bibliotecas/DLL para x64, x86 y ARM64. Los objetivos MSBuild añaden el include, enlazan `dstorage.lib` y copian `dstorage.dll` y `dstoragecore.dll` al resultado de una aplicación que utilice el SDK.

| Archivo x64 | Bytes | Versión de archivo | SHA-256 | Authenticode |
|---|---:|---|---|---|
| `native/bin/x64/dstorage.dll` | 207.392 | `1.4.2603.504` | `4AE887A8CD21DB2CFECD97C34B5F4DA48D8370D4646F3853D60DB809AA02A8BF` | Valid, Microsoft Corporation |
| `native/bin/x64/dstoragecore.dll` | 2.517.064 | `1.4.2603.504` | `C6A160899D2C607E1547476B210E36B1CE059A78FEB6DC027A2A0CF4A6F22B78` | Valid, Microsoft Corporation |

Ambas declaran ProductVersion `1.4.0-preview1-2603.504` y tienen sello de tiempo de Microsoft. Se usó `Get-AuthenticodeSignature`; no se cargaron estas DLL mediante `LoadLibrary`, no se invocó DirectStorage y no se copiaron archivos al directorio del juego.

La extracción local limitada se conserva en `artifacts/dependencies/directstorage-1.4-preview-inventory/`, ignorada por Git. Incluye `inventory.json` con hashes de los archivos extraídos y resultados de firma. Este inventario no añade los binarios a la distribución del parche.

## Licencias realmente incluidas

El README asigna expresamente `LICENSE.txt` a todo `native/bin/` y `LICENSE-CODE.txt` a `native/include/`.

- **Cabeceras:** `LICENSE-CODE.txt` usa MIT y exige conservar el aviso de copyright y la licencia. Esto no concede por sí solo derechos sobre los binarios.
- **Binarios:** `LICENSE.txt` contiene los términos de **Microsoft Project DirectStorage de prueba**. La sección 1(a) limita el uso a Windows y excluye un entorno operativo real salvo otro acuerdo; la 2 establece una duración limitada; la 4(f) restringe compartir, publicar, distribuir o transferir el software. La 4(d) también restringe divulgar resultados de benchmark sin autorización previa. La 5 identifica el software como preliminar. `NOTICES.txt` añade avisos de componentes de terceros.

El encabezado genérico del README que describe binarios redistribuibles no resuelve esa discrepancia con los términos específicos de este archivo. Para este parche no se ha presentado otro acuerdo de Microsoft que autorice su uso operativo o redistribución. Por ello, **este paquete preview no debe incorporarse al ZIP público basándose únicamente en el README o en la licencia MIT de las cabeceras**. Debe resolverse el permiso aplicable o evaluar por separado una versión con condiciones adecuadas antes de distribuir binarios. No se han ejecutado benchmarks de este runtime.

## API y funciones observadas en las cabeceras

`native/include/dstorage.h` declara `DStorageGetFactory`, las familias `IDStorageFactory`, `IDStorageFile`, `IDStorageQueue`/1/2/3, `IDStorageStatusArray`, colas de descompresión personalizada e `IDStorageCompressionCodec`. Las solicitudes describen origen, offset, tamaño, formato de compresión y destino. El destino puede ser memoria CPU o un recurso D3D12; el dispositivo de la cola debe coincidir con el recurso GPU. Para varios destinos se exige el estado D3D12 `COMMON`. La sincronización utiliza estados, eventos o fences, y el trabajo debe enviarse con `Submit` o el mecanismo de envío automático.

Las novedades 1.4 verificadas en README/cabeceras son:

- `DSTORAGE_CONFIGURATION2` y `DStorageSetConfiguration2`, con un `CreatorID` global para las colas D3D12 creadas por DirectStorage.
- `DSTORAGE_COMPRESSION_FORMAT_ZSTD`, utilizable en solicitudes y codecs.
- `DSTORAGE_GACL_SHUFFLE_TRANSFORM_TYPE` por solicitud, con transformaciones BC1, BC3, BC4 y BC5 que deben corresponder al acondicionamiento de los datos de origen.

`IDStorageQueue2::GetCompressionSupport` permite consultar la ruta seleccionada, que puede ser descompresión GPU optimizada, fallback GPU o fallback CPU. La presencia de las DLL no demuestra que una GPU concreta use la ruta rápida. `IDStorageQueue3::EnqueueRequests` permite grupos de solicitudes sincronizados con un fence. La configuración global debe establecerse antes de `DStorageGetFactory`; cambiarla con colas o archivos activos puede fallar.

El README de este preview advierte fallos posibles con buffers de staging superiores a 256 MB y TDR del fallback GPU Zstd en cierto contenido/GPU. No son pruebas de un fallo en este equipo, pero impiden tratar esta versión preliminar como una mejora universal ya validada. Las advertencias también aparecen en la [publicación oficial del paquete](https://www.nuget.org/packages/Microsoft.Direct3D.DirectStorage/1.4.0-preview1-2603.504).

## Qué requeriría una integración real en RE8

El [ejemplo oficial HelloDirectStorage](https://github.com/microsoft/DirectStorage/blob/main/Samples/HelloDirectStorage/HelloDirectStorage.cpp) crea una fábrica, abre un archivo, crea una cola y un recurso GPU, encola una solicitud y espera la finalización mediante un fence. La [guía oficial](https://github.com/microsoft/DirectStorage/blob/main/Docs/DeveloperGuidance.md) describe las responsabilidades de la aplicación sobre solicitudes, recursos, formatos y sincronización.

En el código actual del plugin no hay creación de fábrica o colas DirectStorage ni redirección de solicitudes de streaming. Las cabeceras y DLL inventariadas no aportan automáticamente un adaptador para los contenedores, compresión y gestor de recursos de RE8.

Una integración de verdad requeriría identificar una frontera estable del cargador del juego y reconstruir sus contratos: archivos/offsets, formatos de compresión, destino y vida de cada buffer/recurso, cancelación, errores, sincronización y dependencias de finalización. Para enviar directamente a la GPU también haría falta usar el dispositivo D3D12 correcto y respetar estados de recursos y fences del motor. Un formato nativo distinto de los soportados no se transforma en GDeflate o Zstd al sustituir una DLL; habría que conservar su descompresión o desarrollar una ruta compatible. Las transformaciones GACL requieren contenido preparado para ellas.

Esto es trabajo adicional sobre un motor cerrado y exige validación dentro del juego con fallback al cargador original. No está implementado en RE8Display ni cubierto por las pruebas del parche de pantalla. Interceptar `ReadFile` de forma general, crear una fábrica sin enviar recursos del juego o mostrar un interruptor ImGui no demostraría esta integración. Tampoco demostraría eliminar tirones o mejorar FPS.

## Resultado de esta revisión

Verificado: identidad del paquete, inventario, hashes, firmas del paquete y de sus DLL x64, licencias locales y existencia de las API descritas.

La revisión estática fue seguida por la prueba aislada descrita a continuación. Permanecen pendientes el permiso para usar/distribuir estos binarios preview en el contexto de producción, la adaptación del streaming de RE8, la compatibilidad GPU/controlador y las mediciones autorizadas de rendimiento. No se modifica el cargador del juego ni se añade este SDK al ZIP principal.

## Prueba funcional aislada posterior

A las 15:33:15 America/Santo_Domingo del 2 de noviembre de 2026 se ejecutó RE8DirectStorageProbe con los dos DLL revisados, preparados únicamente en su carpeta privada. Se creó una fábrica y una cola DirectStorage, se envió una lectura sin compresión de 1.048.576 bytes hacia memoria CPU y se esperó su finalización. La comparación de todos los bytes y el CRC32 `E66DF102` coincidieron; código de salida 0. Se usó `DStorageSetConfiguration2` y se desactivó la descompresión GPU para esta prueba.

El resultado se conserva en `artifacts/build/RE8DirectStorage-runtime-test.json` y su `probe-result.txt`. No se midió ni publicó rendimiento. No se leyeron PAK de RE8, no se usó el dispositivo del juego ni se probaron descompresión GPU, Zstd o GACL. Este resultado no acredita integración del streaming ni mejoras de carga del juego.
