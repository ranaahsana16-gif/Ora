@echo off
title Ora WhatsApp Server Starter
color 0E
echo ================================================================
echo          🚀 ORA WHATSAPP SERVER STARTER (NO-PM2) 🚀
echo ================================================================
echo.

cd /d "%~dp0\whatsapp-server"

echo 📦 [1/3] Installing/checking dependencies...
call npm install
if %ERRORLEVEL% neq 0 (
    color 0C
    echo.
    echo ❌ Error: npm install failed. Make sure Node.js is installed!
    pause
    exit /b
)
echo ✅ Dependencies ok!
echo.

echo ⚡ [2/3] Checking if WhatsApp Server is already running...
:: We can use PowerShell to check if port 12456 is bound
powershell -Command "if (Get-NetTCPConnection -LocalPort 12456 -ErrorAction SilentlyContinue) { exit 1 } else { exit 0 }" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    color 0A
    echo.
    echo ℹ️  WhatsApp Server is ALREADY running in the background!
    echo    If you need to scan the QR code, please stop the server first
    echo    using stop-whatsapp.bat, then run start-whatsapp.bat.
    echo.
    pause
    exit /b
)
echo ✅ Server is not running.
echo.

echo 🚀 [3/3] Starting WhatsApp Server in the background...
:: Create a local, temporary start-silent.vbs to spawn it without opening a window
set "VbsFile=%temp%\ora-whatsapp-start.vbs"
echo Set WshShell = CreateObject("WScript.Shell") > "%VbsFile%"
echo WshShell.CurrentDirectory = "%~dp0whatsapp-server" >> "%VbsFile%"
echo WshShell.Run "node index.js", 0, false >> "%VbsFile%"

wscript "%VbsFile%"
del "%VbsFile%"

echo.
echo ================================================================
echo 🎉 SUCCESS! The WhatsApp server is now running in the background!
echo ================================================================
echo.
echo 💡 The server runs fully silently.
echo    If this is your first time, make sure you ran setup-whatsapp.bat
echo    to scan the QR code first!
echo.
echo ================================================================
pause
