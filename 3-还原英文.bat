@echo off
chcp 65001 >nul
setlocal
echo.
echo  Restoring original English UI ... UAC prompt will appear, click YES
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\patch.ps1" -Mode Restore
echo.
pause
