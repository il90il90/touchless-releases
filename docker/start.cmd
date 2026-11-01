@echo off
rem Touchless self-hosted relay - double-click to install/start.
rem   start.cmd            asks a few questions
rem   start.cmd lan        phone on the same Wi-Fi
rem   start.cmd local      this computer only
rem   start.cmd public     your own HTTPS domain
rem   start.cmd update     download the newest relay image, then start
setlocal
set "MODE="
set "EXTRA="
if /I "%~1"=="lan" set "MODE=-Mode lan"
if /I "%~1"=="local" set "MODE=-Mode local"
if /I "%~1"=="public" set "MODE=-Mode public"
if /I "%~1"=="update" set "EXTRA=-Update"
if /I "%~2"=="update" set "EXTRA=-Update"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start.ps1" %MODE% %EXTRA%
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
