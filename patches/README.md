> Historical bundled development implementation. RE8Display 2.1.0 uses the standalone source in native/ and the vendored public SDK; these patches are preserved for audit and recovery, and are not its shipped runtime.

# Dependencia externa reproducible

`external/REFramework.source.json` registra la revisión real del código fuente, los submódulos y los hashes de los parches. La revisión del antiguo binario se conserva separadamente: no coincide con la revisión del checkout fuente y no debe usarse para reconstruirlo.

`RE8Framework.patch` contiene las modificaciones locales de REFramework, incluidas las mejoras anteriores conservadas y los módulos propios bajo `src/mods/re8/`. `RE8ImGuiStartup.patch` conserva las dos comprobaciones previas que evitan activar un breakpoint de depuración con identificadores nulos.

Para reconstruir en un checkout limpio de la revisión registrada, inicializar los submódulos, aplicar `RE8Framework.patch` en la raíz de REFramework y `RE8ImGuiStartup.patch` en `dependencies/imgui`, y compilar con las herramientas indicadas por REFramework. No aplicar otra vez sobre el checkout local ya modificado. No se renombra el framework externo ni sus APIs.

Para actualizar la copia revisable de los cambios locales:

```powershell
python .\tools\RE8Patch.ExportSources.py
```

El exportador no modifica el índice Git y verifica que ambos parches se puedan revertir sobre el árbol actual. La compilación completa se documenta por separado; comprobar la aplicación de un parche no sustituye compilarlo ni ejecutarlo.

Preparación automatizada desde el checkout fuente (sin sobrescribir cambios ajenos):

```powershell
.\tools\RE8Patch.PrepareSource.ps1
.\tools\RE8Patch.Build.ps1
.\tools\RE8Patch.Test.ps1
.\tools\RE8Patch.Package.ps1
```

El preparador verifica revisión, hashes y cambios exactos antes de aplicar los dos parches. Si el árbol ya coincide, lo conserva. Rechaza modificaciones adicionales y revisiones distintas; no utiliza reset ni fuerza su sustitución.
