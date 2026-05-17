@echo off
title Stop Ora WhatsApp Server
color 0C
echo ================================================================
echo          🛑 STOP ORA WHATSAPP SERVER BACKGROUND PROCESS 🛑
echo ================================================================
echo.
echo This script will terminate any running background instances of
echo the WhatsApp server.
echo.
echo ================================================================
echo.

taskkill /f /im node.exe >nul 2>&1

echo ✅ WhatsApp Server stopped successfully!
echo.
echo ================================================================
pause
