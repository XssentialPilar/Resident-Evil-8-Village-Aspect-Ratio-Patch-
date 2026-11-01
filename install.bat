@echo off
setlocal enabledelayedexpansion

echo =====================================================================
echo  Resident Evil Village (RE8) - 16:10 Aspect Ratio & Cursor Patch
echo  Version v1.1.0 (16:10 Verified + Windows Native Cursor 1:1)
echo =====================================================================
echo.

set "TARGET_DIR=C:\Program Files (x86)\Steam\steamapps\common\Resident Evil Village BIOHAZARD VILLAGE"

if not exist "!TARGET_DIR!\re8.exe" (
    echo [?] Buscando ruta de instalacion de Resident Evil Village...
    for %%d in (C D E F G) do (
        if exist "%%d:\SteamLibrary\steamapps\common\Resident Evil Village BIOHAZARD VILLAGE\re8.exe" (
            set "TARGET_DIR=%%d:\SteamLibrary\steamapps\common\Resident Evil Village BIOHAZARD VILLAGE"
        )
    )
)

if not exist "!TARGET_DIR!\re8.exe" (
    echo.
    echo [!] No se encontro automaticamente la carpeta del juego.
    set /p "TARGET_DIR=Introduce la ruta completa donde se encuentra re8.exe: "
)

if not exist "!TARGET_DIR!\re8.exe" (
    echo.
    echo [ERROR] No se encontro re8.exe en: !TARGET_DIR!
    pause
    exit /b 1
)

echo.
echo [*] Instalando en: !TARGET_DIR!
echo.

copy /y "%~dp0dinput8.dll" "!TARGET_DIR!\dinput8.dll" >nul
if exist "%~dp0re2_fw_config.txt" copy /y "%~dp0re2_fw_config.txt" "!TARGET_DIR!\re2_fw_config.txt" >nul
if exist "%~dp0reframework_revision.txt" copy /y "%~dp0reframework_revision.txt" "!TARGET_DIR!\reframework_revision.txt" >nul

if not exist "!TARGET_DIR!\reframework\autorun\utility" (
    mkdir "!TARGET_DIR!\reframework\autorun\utility" >nul 2>&1
)
if not exist "!TARGET_DIR!\reframework\data" (
    mkdir "!TARGET_DIR!\reframework\data" >nul 2>&1
)

copy /y "%~dp0reframework\autorun\re8_aspect_ratio_fix.lua" "!TARGET_DIR!\reframework\autorun\re8_aspect_ratio_fix.lua" >nul
if exist "%~dp0re8_aspect_ratio_fix.json" (
    copy /y "%~dp0re8_aspect_ratio_fix.json" "!TARGET_DIR!\reframework\data\re8_aspect_ratio_fix.json" >nul
)

echo [OK] Parche v1.1.0 (16:10 Demostrable) instalado correctamente.
echo.
echo Recuerda:
echo  - Pulsa INSERT dentro del juego para abrir el Aspect Ratio Config Menu.
echo  - Configuracion optima para 16:10 (1920x1200):
echo      * Ultrawide/FOV Fix: ON
echo      * 16:10 Black Bars: OFF
echo      * Vertical FOV: OFF
echo      * Override FOV: ON
echo      * FOV Multiplier: 1.715
echo.
pause
