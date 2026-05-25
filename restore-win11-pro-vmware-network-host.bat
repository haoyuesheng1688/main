@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "VMX=G:\WIN11-专业版\Windows 11 x64.vmx"
set "VMRUN=D:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe"
set "VMCLI=D:\Program Files (x86)\VMware\VMware Workstation\vmcli.exe"
set "LOG=%TEMP%\restore-win11-pro-vmware-network-host.log"

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  echo Requesting administrator permission...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo === %date% %time% === > "%LOG%"
echo Starting VMware NAT and DHCP services...
echo Starting VMware NAT and DHCP services... >> "%LOG%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Service -Name 'VMnetDHCP' -ErrorAction Stop; Start-Service -Name 'VMware NAT Service' -ErrorAction Stop; Get-Service -Name 'VMnetDHCP','VMware NAT Service' | Format-Table -AutoSize" >> "%LOG%" 2>&1

echo Ensuring VM network adapter is NAT and connected...
echo Ensuring VM network adapter is NAT and connected... >> "%LOG%"
"%VMCLI%" "%VMX%" ConfigParams SetEntry ethernet0.connectionType nat >> "%LOG%" 2>&1
"%VMCLI%" "%VMX%" ConfigParams SetEntry ethernet0.startConnected TRUE >> "%LOG%" 2>&1
"%VMCLI%" "%VMX%" Ethernet query >> "%LOG%" 2>&1

echo Waiting briefly for DHCP...
echo Waiting briefly for DHCP... >> "%LOG%"
timeout /t 8 /nobreak >nul

echo Checking guest IP...
echo Checking guest IP... >> "%LOG%"
"%VMRUN%" -T ws getGuestIPAddress "%VMX%" >> "%LOG%" 2>&1

type "%LOG%"
echo.
echo Log written to "%LOG%"
pause
