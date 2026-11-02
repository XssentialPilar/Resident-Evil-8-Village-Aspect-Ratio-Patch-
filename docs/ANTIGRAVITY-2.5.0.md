# RE8Display 2.5.0 — entrega para publicación

El usuario delegó VS Code, sincronización Git y publicación a Antigravity. Esta preparación no crea etiquetas ni publica un release.

La fuente corrige la representación double de los valores Single en la invocación administrada, la calibración/aspecto de cámara y el bucle de restauración/Fit que produjo 811 resizes en 151.348 segundos con el candidato anterior. El último DLL compilado registrado es `54B6C44D04242F705198CDA7F79FE966BE6A70A03FADCA4C5783BD26FD5C0ABF`. Pasan siete suites nativas/ABI y 41 comprobaciones de instalación/paquete.

La revisión visual completa del candidato con viewport persistente sigue pendiente. El reporte más reciente de parpadeo corresponde al candidato anterior; no debe marcarse cerrado solo por aprobar pruebas unitarias. Revisar `docs/release-2.5.0.md` y `docs/validation-2.5.0.json` antes de publicar.

El entregable principal es `dist/RE8Display-2.5.0.zip`, con `dist/SHA256SUMS-2.5.0.txt`. SHA256 del ZIP final: `3DA8E5DB233F7654362655B848FA6424A5ED442BE664450CB99893C79FF994FF`. Fingerprint del código principal: `9BD8CEEF91C4131BCADA3984F3F9C146F51B5A8F8668D842AE47DE75F4177E51`; el recibo fue actualizado sin cambiar el DLL. El alcance es `native/common`, `native/plugin`, `native/CMakeLists.txt`, SDK público y MinHook. Los probes opcionales no están enlazados al DLL principal.

El ZIP principal contiene exactamente DLL, INI privado y avisos de licencia, con rutas directas para copiar a la raíz del juego. No incluye Agility, DirectStorage, dinput8.dll, ajustes compartidos ni archivos de desarrollo. Conservar todos los ZIP anteriores y respaldos de recuperación. No sobrescribir archivos de un juego activo.

Los dos ZIP opcionales son diagnósticos independientes, **no integraciones en RE8**:

- `dist/RE8Agility-722-Compatibility.zip`, SHA256 `BE0A3F5CBCE10060CEC0B39DC9D931CFC952ADD48437721C35D8ECCF50448ECA`: prueba real de dispositivo SDK 722 en RTX 5050 Laptop GPU aprobada, S_OK y salida 0.
- `dist/RE8DirectStorage-1.4-Compatibility.zip`, SHA256 `21DF36065CD90325233FEBF86401292AA7912C71F7BD49CD4C7A9EE810AE3001`: lectura independiente de 1 MiB hacia memoria CPU aprobada, comparación completa y CRC32 E66DF102, salida 0. No prueba GPU ni rendimiento.

Ver `docs/technology-integration-status.md`. El arranque de RE8 con Agility y el adaptador de streaming DirectStorage siguen sin implementar. No publicar estos kits como mods que ya activen esas tecnologías en el juego ni afirmar compatibilidad sin conflictos. No distribuir los binarios preview ni sus NuGet por asumir que su licencia es MIT; los paquetes originales están ignorados por Git y se usan únicamente como dependencias locales.

Revisar, guardar en commit y subir toda la fuente final 2.5.0 antes de crear `v2.5.0`. Confirmar que la etiqueta apunta a esos cambios y revisar el workflow y los archivos/checksum efectivamente publicados. No reutilizar un diálogo pendiente de etiqueta 2.1.0 ni subir binarios anteriores. El alcance pendiente de validación debe figurar claramente en el release.
