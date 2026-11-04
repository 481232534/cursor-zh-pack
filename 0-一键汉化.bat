@echo off
chcp 65001 >nul
setlocal
title Cursor 一键汉化
echo.
echo  ============================================
echo    Cursor 一键汉化
echo    （语言包 + 界面文案，全程自动完成）
echo  ============================================
echo.
echo  [1/3] 安装中文语言包（无需管理员权限）...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\langpack.ps1"
if errorlevel 1 goto fail
echo.
echo  [2/3] 汉化 Cursor 内置界面文案...
echo        接下来会弹 UAC 提权窗口，请点「是」。
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\patch.ps1" -Mode Apply
if errorlevel 1 goto fail
echo.
echo  ============================================
echo    全部完成！
echo  ============================================
echo.
echo  请完全退出 Cursor（含右下角托盘）后再打开，
echo  界面即为中文。
echo.
echo  还原英文：双击  3-还原英文.bat
echo  检查效果：双击  4-检查状态.bat
echo.
pause
exit /b 0

:fail
echo.
echo  [错误] 执行未完成，请查看上方提示。
echo  可把整个窗口截图发给我排查。
echo.
pause
exit /b 1