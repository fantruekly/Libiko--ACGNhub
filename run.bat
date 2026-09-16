@echo off
cd /d "%~dp0"

set "FLUTTER_CMD=C:\flutter\bin\flutter.bat"

if not exist "%FLUTTER_CMD%" (
    echo Flutter SDK was not detected at C:\flutter\bin\flutter.bat.
    echo Please confirm the Flutter installation path.
    echo.
    echo You can also run this manually in a terminal:
    echo   flutter run -d windows
    echo.
    pause
    exit /b 1
)

echo Starting Libiko (Flutter Windows)...
echo.

call "%FLUTTER_CMD%" run -d windows

if errorlevel 1 (
    echo.
    echo Launch failed. Please check the Flutter environment and project dependencies.
    echo.
    pause
)
