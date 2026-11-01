@echo off
setlocal enabledelayedexpansion

echo =====================================================================
echo  Resident Evil Village (RE8) - Desinstalador de Parche
echo =====================================================================
echo.

set "TARGET_DIR=C:\Program Files (x86)\Steam\steamapps\common\Resident Evil Village BIOHAZARD VILLAGE"

if not exist "!TARGET_DIR!\re8.exe" (
    for %%d in (C D E F G) do (
        if exist "%%d:\SteamLibrary\steamapps\common\Resident Evil Village BIOHAZARD VILLAGE\re8.exe" (
            set "TARGET_DIR=%%d:\SteamLibrary\steamapps\common\Resident Evil Village BIOHAZARD VILLAGE"
        )
    )
)

if exist "!TARGET_DIR!\dinput8.dll" (
    del /f /q "!TARGET_DIR!\dinput8.dll" >nul 2>&1
    echo [*] Eliminado dinput8.dll
)

if exist "!TARGET_DIR!\reframework\autorun\re8_aspect_ratio_fix.lua" (
    del /f /q "!TARGET_DIR!\reframework\autorun\re8_aspect_ratio_fix.lua" >nul 2>&1
    echo [*] Eliminado script de aspect ratio fix
)

echo.
echo [EXITO] Desinstalacion completada.
pause
