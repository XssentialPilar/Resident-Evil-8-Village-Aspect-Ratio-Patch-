# Auditoría de organización y distribución

## Criterio aplicado

Se revisaron el árbol del proyecto, los archivos seguidos por Git, las referencias del Lua, la configuración CMake y los scripts anteriores. La limpieza distingue el árbol de mantenimiento de los archivos instalados: fuentes, pruebas y dependencias sirven para mantener y compilar; no pertenecen al paquete de ejecución.

El inventario de recuperación registra los movimientos concretos y sus hashes. No se borró el historial Git. La carpeta `Installed from GitHub (Don't Touch This)` se respeta como referencia protegida y no forma parte del paquete.

## Archivos retirados del árbol activo

| Contenido anterior | Motivo | Conservación |
| --- | --- | --- |
| `staging/` | Copias de código, DLL antiguas, scripts de sustitución y publicación que no son entradas de la compilación activa. | `.recovery/retired/` |
| `Experimental Releases (LEGACY) (USELESS)/` | Paquetes históricos; no se instalan ni se utilizan para compilar. | `.recovery/retired/` |
| `Final Releases/` | Distribuciones anteriores; no acreditan las nuevas correcciones. | `.recovery/retired/` |
| ZIP históricos de la raíz | Descargas y copias de distribuciones anteriores. | `.recovery/retired/` |
| `REFramework-1.5.9.1/` | Copia anterior separada del checkout C++ activo. | `.recovery/retired/` |
| `reframework/autorun/utility/` | El script del parche no llama `require`, `dofile` ni `loadfile` para utilizar estos auxiliares de varios juegos. | `.recovery/retired/` |
| `dinput8.dll` de la raíz | Binario de referencia anterior; no corresponde al nuevo código. | `artifacts/baseline/` |

Las fotografías y capturas se conservan en `docs/evidence/` como evidencia histórica, sin afirmar que prueben los cambios actuales. Las rutas finales y el listado exhaustivo de movimientos deben contrastarse con el manifiesto de recuperación.

## Organización activa

| Ruta | Función |
| --- | --- |
| `runtime/reframework/autorun/re8_display.lua` | Configuración y diagnóstico; las modificaciones de proyección y cursor pertenecen al controlador nativo. |
| `config/re8_display.json` | Valores iniciales del módulo de pantalla. |
| `config/re2_fw_config.txt` | Valores iniciales de la dependencia nativa. |
| `reframework_src/` | Dependencia externa modificada; conserva sus nombres, submódulos y caché CMake para mantener compatibilidad. |
| `patches/` | Cambios propios sobre la dependencia externa, recuperables fuera del checkout ignorado. |
| `external/REFramework.source.json` | Procedencia y revisión del código fuente de REFramework. |
| `external/REFramework.legacy-binary.revision.txt` | Revisión declarada del binario anterior; se distingue de la revisión del código fuente. |
| `tools/RE8Patch.*.ps1` | Compilación, empaquetado, instalación y desinstalación. |
| `tests/` | Pruebas automatizadas; no se instalan en el juego. |
| `licenses/` | Avisos de Praydog / REFramework y de las dependencias disponibles en el checkout. |
| `artifacts/` | Resultados locales de compilación y de pruebas; se excluyen del paquete. |
| `dist/` | Candidatos locales de desarrollo, marcados como pendientes de validación en el juego. |

## Nombres externos conservados

`dinput8.dll` mantiene el nombre de carga del proxy de DirectInput. `reframework/autorun/` y `reframework/data/` son rutas de la dependencia. `re2_fw_config.txt`, las API Lua `re` / `sdk` y las clases e identificadores originales del checkout externo mantienen su contrato existente. Cambiar estos nombres como sustitución textual rompería la carga o el enlace. La identidad del código propio utiliza el prefijo RE8 y nombres de responsabilidad concretos.

El copyright y la licencia MIT de Praydog se incluyen íntegros en `licenses/REFramework-MIT.txt`. Se copiaron los avisos disponibles de las dependencias sin alterar sus textos. Las licencias de Lua y nlohmann-json se extrajeron literalmente de sus encabezados originales. El inventario de procedencia de esos textos está en `licenses/license-sources.json`.

## Instalación y desinstalación

El instalador acepta una ruta explícita que contenga `re8.exe`, verifica los hashes del paquete, rechaza enlaces/junctions y rutas que escapen de esa carpeta y comprueba que ese juego esté cerrado. No busca ni modifica instalaciones de otros programas. Copia únicamente los cuatro archivos de ejecución enumerados en `runtime-files.json` y retira exactamente el Lua anterior del parche para impedir una doble ejecución.

Antes de reemplazar un archivo crea y verifica una copia en `.RE8VillagePatch/backups/`. Conserva configuraciones preexistentes. El manifiesto guarda la propiedad de cada archivo. Ante un error normal de copia revierte los cambios ya aplicados. Una interrupción abrupta del sistema puede requerir restaurar manualmente las copias verificadas; no se presenta la instalación como una transacción infalible frente a cortes de energía.

La desinstalación restaura los originales. Si otro mod cambió un binario o el script instalado, se detiene antes de modificar cualquier archivo. Los cambios posteriores del usuario a la configuración se conservan. No elimina la carpeta completa de REFramework ni otros mods. Las copias se retienen como recuperación.

## Pruebas reales de las herramientas

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/RE8Patch.Install.Tests.ps1` completó 21 comprobaciones en Windows PowerShell 5.1 con archivos de prueba, sin instalar en el juego real. Se comprobaron rutas con espacios y `!`, copia y restauración de la DLL previa, migración y restauración del Lua anterior, conservación de otros mods y configuraciones, rechazo de reinstalación, rechazo de desinstalación de binarios modificados, reversión tras un fallo inyectado de copia, hashes incorrectos, recorrido `..`, rutas absolutas, streams alternativos y junctions.

Estos resultados verifican las operaciones de archivos. No verifican el inicio del juego, el cursor, el mapa, la proyección ni el rendimiento durante gameplay. Los resultados C++ y la matriz de ejecución real se documentan en el informe técnico general.

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/RE8Patch.Package.Tests.ps1` completó otras 19 comprobaciones. Se verificaron los cuatro archivos de ejecución y sus hashes, la inclusión de licencias e informes, la exclusión de fuentes y pruebas, el rechazo de recibos de compilación obsoletos, DLL alterada, rutas ajenas a la salida de compilación y licencias ausentes. Los casos rechazados no crean carpetas de distribución parciales. Se ejecutaron también los wrappers BAT reales para instalar y desinstalar una carpeta de prueba con espacios y `!`.

Las pruebas del empaquetador utilizan expresamente una DLL ficticia dentro de su fixture. Esto verifica el flujo de archivos y sus protecciones, nunca una compilación ni la ejecución del juego. Los 40 resultados de estas dos suites se conservan en `artifacts/tests/`.

`powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/RE8Patch.Build.Tests.ps1` completó 4 comprobaciones adicionales con CMake y MSBuild reales: configuración inicial Visual Studio 18 2026 x64 aunque el entorno solicite Ninja, conservación del generador de una caché existente y hash del archivo producido. El proyecto de prueba usa un target que copia una DLL ficticia y no compila código del parche. Estos 4 resultados acreditan el flujo de configuración, y deben distinguirse del build C++ real descrito en el informe técnico. Total de comprobaciones de herramientas: 44.
