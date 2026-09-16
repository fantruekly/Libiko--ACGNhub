@echo off
setlocal
set "PATH=C:\flutter\bin;%PATH%"
set "ROOT=%~dp0"
set "EXE=%ROOT%build\windows\x64\runner\Debug\libiko.exe"

echo Building Libiko...
pushd "%ROOT%"
call flutter build windows --debug
popd

if exist "%EXE%" (
  start "" "%EXE%"
) else (
  echo Build failed. See output above.
  pause
)
endlocal
