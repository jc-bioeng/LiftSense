@echo off
set VIDEO=%1
if "%VIDEO%"=="" (
    echo Uso: run_tracker.bat "ruta_absoluta_del_video.mp4"
    exit /b 1
)

:: Moverse a la carpeta del script automáticamente
cd /d "%~dp0"

.\venv\Scripts\python.exe pose_tracker.py %VIDEO%
pause
