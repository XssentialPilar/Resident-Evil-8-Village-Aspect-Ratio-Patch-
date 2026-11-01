@echo off
setlocal enabledelayedexpansion

echo =====================================================================
echo  Resident Evil Village (RE8) - Aspect Ratio ^& Cursor Patch Installer
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
if exist "%~dp0reframework_revision.txt" copy /y "%~dp0reframework_revision.txt" "!TARGET_DIR!\reframework_revision.txt" >nul

if not exist "!TARGET_DIR!\reframework\autorun\utility" (
    mkdir "!TARGET_DIR!\reframework\autorun\utility" >nul 2>&1
)

copy /y "%~dp0reframework\autorun\re8_aspect_ratio_fix.lua" "!TARGET_DIR!\reframework\autorun\re8_aspect_ratio_fix.lua" >nul
xcopy /y /s "%~dp0reframework\autorun\utility\*" "!TARGET_DIR!\reframework\autorun\utility\" >nul

echo =====================================================================
echo  [EXITO] Parche instalado correctamente.
echo  Ya puedes iniciar Resident Evil Village y jugar en 16:10 / Ultrawide
echo  sin barras negras y con el cursor 100%% sincronizado sin desface!
echo =====================================================================
echo.
pause
