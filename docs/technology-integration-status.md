# Estado de las tecnologías opcionales

Actualizado el 2 de noviembre de 2026. Los módulos de Agility y DirectStorage son opcionales, separados entre sí y de RE8Display 2.5.0.

| Tecnología | Integración y evidencia dentro de RE8 | ZIP del módulo |
| --- | --- | --- |
| Agility SDK 722 Preview | Activación antes de crear el dispositivo del juego. Registro real: `FIRST_DEVICE HRESULT=0x00000000 active=1 device_sdk=722`, con Core privado 722. | `RE8Agility-722-Game.zip` |
| DirectStorage 1.4 Preview | 18.011 lecturas PAK y 4.543.855.912 bytes completados hacia memoria CPU. Primeras 64 lecturas comparadas completamente con Windows, cero diferencias/errores/timeouts. El usuario terminó su prueba sin errores de carga ni bloqueos. | `RE8DirectStorage-1.4-Game.zip` |

Ver [validación de DirectStorage](DirectStorageBridge-validation.md), [validación de Agility](AgilityBridge-validation.md) y los README de instalación de [DirectStorage](DirectStorageBridge-README.md) y [Agility](AgilityBridge-README.md). La evidencia corresponde al ejecutable RE8 SHA256 `B489826FD3E8AEEA0DD0B1C4ADCF35D5C98D1B599EED022623AA73241FE21E3B` y las DLL identificadas en esos informes.

Agility selecciona el runtime; no añade automáticamente todas las nuevas funciones gráficas. DirectStorage adapta las lecturas PAK elegibles hacia CPU y conserva la descompresión original; no implementa descompresión GPU. Estas pruebas no establecen una mejora de rendimiento ni compatibilidad universal.

Los instaladores verifican el NuGet original del usuario, el hash y la firma de los runtime. Instalan archivos privados y se niegan a sobrescribir archivos ajenos. Agility usa un proxy `d3d12.dll` local y un Core privado; no sustituye archivos de Windows. DirectStorage usa un plugin REFramework y dos DLL privadas, sin reemplazar su cargador ni otros mods. Instalar o retirar solo con RE8 cerrado.

Los ZIP incluyen código propio compilado, instalador, retirada, manifiesto y avisos. No redistribuyen los binarios preview ni sus NuGet, conforme a las restricciones identificadas en [Agility](agility-1.722.0-preview-assessment.md) y [DirectStorage](directstorage-1.4-preview-assessment.md). Las dependencias originales permanecen locales.

Los antiguos `*-Compatibility.zip` son diagnósticos independientes, conservados como antecedentes. Sus pruebas de dispositivo/archivo propio no deben presentarse como la evidencia de integración actual. Los nuevos `*-Game.zip` corresponden a los módulos instalables.

El paquete principal `RE8Display-2.5.0.zip` conserva solo sus tres archivos propios y no depende de estas tecnologías. La verificación visual completa de FOV, sombras, interfaz y todas las resoluciones conserva el alcance pendiente descrito en [el informe principal](release-2.5.0.md).

