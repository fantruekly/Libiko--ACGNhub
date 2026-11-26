@echo off
setlocal
set "APP_DIR=%~dp0build\windows-vs2026\runner\Release"

if not exist "%APP_DIR%\libiko.exe" goto missing
if not exist "%APP_DIR%\data\app.so" goto missing

start "" /D "%APP_DIR%" "%APP_DIR%\libiko.exe"
if not errorlevel 1 exit /b 0

echo Libiko could not start.
pause
exit /b 1

:missing
echo The Libiko acceptance build was not found:
echo   "%APP_DIR%"
echo Build the Windows Release target before using this launcher.
pause
exit /b 1
