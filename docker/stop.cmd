@echo off
rem Stops the Touchless relay. Your data (the relay-data volume) is kept.
cd /d "%~dp0"
docker compose -f docker-compose.yml down --remove-orphans
echo.
pause
