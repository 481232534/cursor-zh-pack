@echo off
chcp 65001 >nul
setlocal
echo.
echo  [2/2] Patching Cursor UI text ... UAC prompt will appear, click YES
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\patch.ps1" -Mode Apply
echo.
echo  Done. Fully quit Cursor and open it again.
echo.
pause
