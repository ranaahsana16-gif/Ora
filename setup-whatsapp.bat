@echo off
title Ora WhatsApp Server Setup
color 0E
echo ================================================================
echo          🚀 ORA WHATSAPP SERVER ZERO-DEPENDENCY SETUP 🚀
echo ================================================================
echo.
echo This script will help you set up the WhatsApp Server to run
echo in the background and automatically start when your computer boots.
echo.
echo ================================================================
echo.

cd /d "%~dp0\whatsapp-server"

echo 📦 [1/3] Installing WhatsApp Server dependencies...
call npm install
if %ERRORLEVEL% neq 0 (
    color 0C
    echo.
    echo ❌ Error: Failed to install dependencies.
    pause
    exit /b
)
echo ✅ Dependencies installed!
echo.

echo ⚡ [2/3] Setting up Automatic Windows Boot Startup...
:: Create VBS script in Windows Startup folder for silent background execution
set "StartupFolder=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "VbsFile=%StartupFolder%\ora-whatsapp-startup.vbs"

echo WScript.Sleep 5000 > "%VbsFile%"
echo Set WshShell = CreateObject("WScript.Shell") >> "%VbsFile%"
echo WshShell.CurrentDirectory = "%~dp0whatsapp-server" >> "%VbsFile%"
echo WshShell.Run "node index.js", 0, false >> "%VbsFile%"

echo ✅ Boot startup registered in your Windows Startup Folder!
echo    Path: %VbsFile%
echo.

echo 📱 [3/3] Scanning the QR Code (First-Time Verification)
echo.
echo ================================================================
echo ⚠️  IMPORTANT INSTRUCTIONS:
echo 1. A new window will now open and show a WhatsApp QR code.
echo 2. SCAN the QR code with your phone's WhatsApp Link Devices.
echo 3. Once you see "WhatsApp client is ready!", you can CLOSE that window.
echo ================================================================
echo.
pause

:: Start the server in a visible window so they can scan the QR code
start "Ora WhatsApp QR Scanner" cmd.exe /c "cd /d "%~dp0whatsapp-server" && npm start"

echo.
echo ================================================================
echo 🎉 SETUP COMPLETED SUCCESSFULLY!
echo ================================================================
echo.
echo Once you scan the QR code in the scanner window, your WhatsApp
echo session will be saved permanently.
echo.
echo From now on, whenever you start your computer, the WhatsApp server
echo will run fully silently in the background. No windows will open!
echo ================================================================
echo.
pause
