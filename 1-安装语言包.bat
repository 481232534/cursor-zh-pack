@echo off
chcp 65001 >nul
setlocal
echo.
echo  [1/2] Installing Chinese language pack ... (no admin needed)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\langpack.ps1"
echo.
echo  Next: run the 2-* batch file (patch UI)
echo.
pause
