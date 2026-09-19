@echo off
setlocal EnableExtensions EnableDelayedExpansion
:: ============================================
:: VBS / WSL / Hyper-V - Enable / Disable toggle
:: VBS = Virtualization Based Security
:: ============================================

net session >nul 2>&1
if errorlevel 1 (
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
echo  1 - DISABLE  (desliga VBS, HVCI, WSL, Hyper-V, VMP)
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
echo [1/4] Desativando WSL, Hyper-V e VirtualMachinePlatform...
call :dismDisable Microsoft-Windows-Subsystem-Linux
call :dismDisable VirtualMachinePlatform
call :dismDisable Microsoft-Hyper-V

echo.
echo [2/4] Desativando VBS e HVCI via registro...
powershell -NoProfile -ExecutionPolicy Bypass -Command "New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Force ^| Out-Null; New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Force ^| Out-Null; Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'EnableVirtualizationBasedSecurity' -Type DWord -Value 0; Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'Locked' -Type DWord -Value 0; Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Enabled' -Type DWord -Value 0; Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Locked' -Type DWord -Value 0"
if errorlevel 1 echo [AVISO] Nao foi possivel atualizar todas as chaves de VBS/HVCI.

echo.
echo [3/4] Desativando hypervisor e VSM no boot...
bcdedit /set "{current}" hypervisorlaunchtype off
bcdedit /set "{current}" vsmlaunchtype off

echo.
echo ============================================
echo [4/4] Concluido. Reinicie o PC para aplicar VBS/HVCI e os recursos opcionais.
echo ============================================
pause
exit /b

:enable
echo.
echo [1/4] Ativando WSL, Hyper-V e VirtualMachinePlatform...
call :dismEnable Microsoft-Windows-Subsystem-Linux
call :dismEnable VirtualMachinePlatform
call :dismEnable Microsoft-Hyper-V

echo.
echo [2/4] Reativando VBS e HVCI via registro...
powershell -NoProfile -ExecutionPolicy Bypass -Command "New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Force ^| Out-Null; New-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Force ^| Out-Null; Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'EnableVirtualizationBasedSecurity' -Type DWord -Value 1; Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'Locked' -Type DWord -Value 0; Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Enabled' -Type DWord -Value 1; Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Locked' -Type DWord -Value 0"
if errorlevel 1 echo [AVISO] Nao foi possivel atualizar todas as chaves de VBS/HVCI.

echo.
echo [3/4] Reativando hypervisor e VSM no boot...
bcdedit /set "{current}" hypervisorlaunchtype auto
bcdedit /set "{current}" vsmlaunchtype auto

echo.
echo ============================================
echo [4/4] Concluido. Reinicie o PC para aplicar VBS/HVCI e os recursos opcionais.
echo ============================================
pause
exit /b

:status
echo.
powershell -NoProfile -Command "$dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue; $hvci = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name Enabled -ErrorAction SilentlyContinue).Enabled; [pscustomobject]@{VBSStatus=$dg.VirtualizationBasedSecurityStatus; SecurityServicesRunning=($dg.SecurityServicesRunning -join ','); HVCIRegistry=$hvci; HypervisorLaunchType=((bcdedit /enum '{current}' | Select-String 'hypervisorlaunchtype').ToString().Trim())} | Format-List"
echo.
echo Status 0 = totalmente desligado
echo Status 1 = enabled but not running (hypervisor OFF, sem overhead)
echo Status 2 = rodando ativamente
echo HVCIRegistry 0 = desligado, 1 = configurado para ligar
echo.
pause
goto menu

:dismDisable
dism.exe /online /disable-feature /featurename:%~1 /norestart
if errorlevel 1 echo [AVISO] Falha ou recurso ausente: %~1
exit /b 0

:dismEnable
dism.exe /online /enable-feature /featurename:%~1 /all /norestart
if errorlevel 1 echo [AVISO] Falha ao ativar: %~1
exit /b 0
