@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" install
if errorlevel 1 exit /b %errorlevel%
echo.
echo Zotero MCP installed.
pause
