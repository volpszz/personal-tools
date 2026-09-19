@echo off
:: ============================================
:: VBS / WSL / Hyper-V - Enable / Disable toggle
:: VBS = Virtualization Based Security
:: ============================================

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Solicitando permissao de administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:menu
cls
echo ============================================
echo   VBS / WSL / HYPER-V TOGGLE
echo   (Virtualization Based Security)
echo ============================================
echo.
echo  1 - DISABLE  (desliga VBS, WSL, Hyper-V, VMP)
echo  2 - ENABLE   (liga VBS, WSL, Hyper-V, VMP)
echo  3 - STATUS   (verifica status atual do VBS)
echo  4 - Sair
echo.
set /p opcao="Escolha uma opcao: "

if "%opcao%"=="1" goto disable
if "%opcao%"=="2" goto enable
if "%opcao%"=="3" goto status
if "%opcao%"=="4" exit /b
goto menu

:disable
echo.
echo [1/3] Desativando WSL, Hyper-V e VirtualMachinePlatform...
dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart
dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart
dism.exe /online /disable-feature /featurename:Microsoft-Hyper-V /norestart

echo.
echo [2/3] Desativando VBS via registro...
powershell -Command "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'EnableVirtualizationBasedSecurity' -Value 0"

echo.
echo [3/3] Desativando hypervisor no boot...
bcdedit /set "{current}" hypervisorlaunchtype off
bcdedit /set "{current}" vsmlaunchtype off

echo.
echo ============================================
echo DISABLE concluido! Reinicie o PC para aplicar.
echo ============================================
pause
exit /b

:enable
echo.
echo [1/3] Ativando WSL, Hyper-V e VirtualMachinePlatform...
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
dism.exe /online /enable-feature /featurename:Microsoft-Hyper-V /all /norestart

echo.
echo [2/3] Reativando VBS via registro...
powershell -Command "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'EnableVirtualizationBasedSecurity' -Value 1"

echo.
echo [3/3] Reativando hypervisor no boot...
bcdedit /set "{current}" hypervisorlaunchtype auto
bcdedit /set "{current}" vsmlaunchtype auto

echo.
echo ============================================
echo ENABLE concluido! Reinicie o PC para aplicar.
echo ============================================
pause
exit /b

:status
echo.
powershell -Command "Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard | Select-Object SecurityServicesRunning, VirtualizationBasedSecurityStatus"
echo.
echo Status 0 = totalmente desligado
echo Status 1 = enabled but not running (hypervisor OFF, sem overhead)
echo Status 2 = rodando ativamente
echo.
pause
goto menu
