@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 (
  echo Installation failed. See the message above.
) else (
  echo Installation complete. Open a new Windows PowerShell window.
)
pause
