@echo off
setlocal EnableExtensions
chcp 65001 >nul

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

set "LOG=%USERPROFILE%\Desktop\restore-network-inside-win11-pro-guest.log"
echo === %date% %time% === > "%LOG%"
echo Restoring DHCP and DNS for Ethernet0... >> "%LOG%"

netsh interface ipv4 set address name="Ethernet0" dhcp >> "%LOG%" 2>&1
netsh interface ipv4 set dns name="Ethernet0" dhcp >> "%LOG%" 2>&1
ipconfig /renew >> "%LOG%" 2>&1
ipconfig /flushdns >> "%LOG%" 2>&1

echo === ipconfig /all === >> "%LOG%"
ipconfig /all >> "%LOG%" 2>&1
echo === route print -4 === >> "%LOG%"
route print -4 >> "%LOG%" 2>&1
echo === ping gateway === >> "%LOG%"
ping -n 2 -w 1000 192.168.50.2 >> "%LOG%" 2>&1
echo === ping public ip === >> "%LOG%"
ping -n 2 -w 1000 8.8.8.8 >> "%LOG%" 2>&1
echo === DNS === >> "%LOG%"
nslookup www.baidu.com >> "%LOG%" 2>&1
echo === HTTP === >> "%LOG%"
curl.exe -I --connect-timeout 8 https://www.baidu.com >> "%LOG%" 2>&1

type "%LOG%"
echo.
echo Log written to "%LOG%"
pause
