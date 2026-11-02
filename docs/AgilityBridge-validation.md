# Agility Bridge: validación real en RE8

El 2 de noviembre de 2026 se confirmó la selección de **Agility SDK 722 y la creación correcta del dispositivo D3D12 en el proceso real de Resident Evil Village**, PID `11592`. Esta evidencia corresponde al proxy compilado e instalado identificado abajo; no es solamente una prueba del ejecutable de diagnóstico.

## Evidencia de activación

El archivo del juego `RE8Agility/bridge.log` registra, en orden, estas operaciones de la sesión:

| Hora local | Resultado |
|---|---|
| 17:10:00.943 | Arranque con el cargador `C:\WINDOWS\system32\d3d12.dll`; `preexisting_core=none`. |
| 17:10:00.986 | `ACTIVATED SDK 722 before forwarded device creation`; Core privado en `RE8Agility/D3D12/D3D12Core.dll`. |
| 17:10:01.807 | `FIRST_DEVICE HRESULT=0x00000000 active=1 device_sdk=722`; `observed_core_sdk=722`, desde la misma ruta privada. |

Las horas son las del registro local de la sesión en Santo Domingo, UTC−4. La activación precede a la creación del dispositivo. El registro anterior con `HRESULT=0x00000001` y `device_sdk=0` no se utiliza como prueba de creación: la confirmación es la llamada posterior con `S_OK`, dispositivo SDK 722 y Core SDK 722.

La implementación obtiene `device_sdk` del descriptor de configuración del dispositivo devuelto. El Core observado se identifica por su módulo cargado y su versión exportada. Por tanto, la confirmación utiliza el dispositivo y el módulo efectivos; no se basa únicamente en que exista una DLL en el directorio del juego.

## Identidad de los archivos verificados

Todos los valores siguientes son SHA-256:

| Archivo | Hash |
|---|---|
| Proxy compilado `artifacts/agility-bridge/Release/d3d12.dll` y proxy instalado en la raíz del juego | `EB7592E6DB3BB4AD28263A83C71A8DF2F6097CE49CF98F07D8435D435654C52F` |
| Core instalado `RE8Agility/D3D12/D3D12Core.dll` | `1A588965B12422DB5DF18F9331E244616F4F7A3893DB83A4C578F7DE50A36F13` |
| Ejecutable real `re8.exe` | `B489826FD3E8AEEA0DD0B1C4ADCF35D5C98D1B599EED022623AA73241FE21E3B` |
| Cargador de Windows `System32/d3d12.dll` | `0963513F3291A67EA56985A6E8B7ED8088A1E858803BE6DC3373FAA07460CE02` |
| Recibo de compilación `artifacts/build/RE8AgilityBridge-build.json` | `2BA88B123F39202079E212700B1F6C5E2868C12494EE985DB1A6BC7596EA7E1D` |
| Manifiesto instalado `.RE8Technologies/Agility/install-manifest.json` | `E5AEBA396B3637286D7B17DEE84736C617EF6088744E95A1625F2E41D72A8B1A` |
| Registro completo archivado `bridge.log` | `FD656F3D3FD905898E54055714C2BB25B2622F34EE516D7131A66D01D4C8E386` |

El proxy instalado coincide con el binario y el hash del recibo de compilación. Se comprobaron también los cuatro archivos fuente declarados en ese recibo y los tres archivos que posee el manifiesto de instalación: proxy, Core y licencia preview. Todos coinciden. El Core tiene firma Authenticode **Valid**, de Microsoft Corporation. La identidad criptográfica y la firma no sustituyen las condiciones de uso del runtime preliminar.

## Archivo local de la prueba

La evidencia se conserva en:

`artifacts/runtime/agility-game/evidence-20261102-213024-7948de/`

Contiene una copia íntegra de `bridge.log`, el manifiesto instalado, el recibo de compilación y el registro de REFramework de la sesión. No incluye otra copia del ejecutable ni de los binarios Microsoft.

El recibo estructurado de esta validación es:

`artifacts/build/RE8AgilityBridge-game-test.json`

Incluye los hashes, las líneas exactas del PID `11592`, la comprobación del orden activación/dispositivo y los resultados de contraste con el manifiesto y las fuentes. El campo pendiente de validación real que aparece en el recibo original de compilación describe su estado al compilar; la prueba posterior del juego está registrada por separado aquí y en el nuevo recibo de sesión.

## Alcance confirmado

Se confirmó la selección del runtime privado SDK 722 antes de crear correctamente el dispositivo del juego, con estos archivos y esta sesión. Esto no demuestra por sí mismo una mejora de FPS, la activación automática de nuevas funciones gráficas, ni compatibilidad universal con controladores, overlays o mods. El módulo permanece opcional y separado de RE8Display; las restricciones originales del runtime preview siguen siendo aplicables.
