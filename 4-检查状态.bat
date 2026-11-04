@echo off
chcp 65001 >nul
setlocal
echo.
echo  Read-only status check ... (no admin needed)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\patch.ps1" -Mode Check
echo.
pause
