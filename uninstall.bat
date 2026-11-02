@echo off
setlocal DisableDelayedExpansion
if "%~1"=="" (
    echo Usage: uninstall.bat "C:\path\to\Resident Evil Village"
    echo The supplied folder must contain re8.exe. Close the game first.
    exit /b 2
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\RE8Patch.Uninstall.ps1" -GamePath "%~1"
exit /b %ERRORLEVEL%
