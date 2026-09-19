<#
.SYNOPSIS
    Remove TUDO que sobra no Windows depois de desinstalar Riot Client, Riot Vanguard e VALORANT:
    servicos/driver, registro, pastas, tarefa agendada e atalhos.
.DESCRIPTION
    Cobre:
      1. Servicos/driver do Vanguard (vgk = kernel, vgc = user-mode) + arquivo vgk.sys no disco
      2. Chaves de registro (HKLM 64-bit, WOW6432Node, HKCU) da Riot Games
      3. Entradas de desinstalacao (Uninstall) do VALORANT, Riot Client e Riot Vanguard
      4. Handlers de protocolo (riotclient://, rgp://) — best-effort
      5. Pastas em disco: C:\Riot Games, C:\ProgramData\Riot Games, C:\Program Files\Riot Vanguard,
         %LOCALAPPDATA%\Riot Games, %APPDATA%\Riot Games
      6. Tarefa agendada do Vanguard no Agendador de Tarefas
      7. Atalhos na Area de Trabalho e no Menu Iniciar (usuario atual e "All Users")

    IMPORTANTE:
      - Rode como Administrador.
      - Desinstale VALORANT/Riot Client pelo Configuracoes do Windows ANTES de rodar isso — o
        script limpa o que sobra depois, nao substitui a desinstalacao.
      - Feche Riot Client, VALORANT e Vanguard antes. O driver vgk as vezes so libera o arquivo
        .sys depois de um reboot — se a remocao dele falhar, reinicie e rode o script de novo.
      - Por padrao roda em modo simulacao (-WhatIf). Pra executar de verdade:
            .\clean-riot-full.ps1 -Confirm:$false
      - Se o Windows bloquear por ser "arquivo baixado da internet", rode antes:
            Unblock-File -Path .\clean-riot-full.ps1
#>

#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param()

function Remove-RegKeySafe {
    param([string]$Path)
    if (Test-Path $Path) {
        if ($PSCmdlet.ShouldProcess($Path, "Remover chave de registro")) {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "[OK] Registro removido: $Path" -ForegroundColor Green
        }
    }
    else {
        Write-Host "[--] Registro nao encontrado: $Path" -ForegroundColor DarkGray
    }
}

function Remove-ServiceSafe {
    param([string]$ServiceName)
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($svc) {
        if ($PSCmdlet.ShouldProcess($ServiceName, "Parar e remover servico/driver")) {
            try {
                if ($svc.Status -ne 'Stopped') {
                    Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
                }
                & sc.exe delete $ServiceName | Out-Null
                Write-Host "[OK] Servico removido: $ServiceName" -ForegroundColor Green
            }
            catch {
                Write-Host "[ERRO] Falha ao remover servico $ServiceName : $_" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "[--] Servico nao encontrado: $ServiceName" -ForegroundColor DarkGray
    }
}

function Remove-UninstallEntries {
    param([string]$Pattern)
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($root in $roots) {
        Get-ChildItem -Path $root -ErrorAction SilentlyContinue | ForEach-Object {
            $displayName = (Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue).DisplayName
            if ($displayName -match $Pattern) {
                Remove-RegKeySafe -Path $_.PSPath
            }
        }
    }
}

function Remove-PathSafe {
    param([string]$Path)
    if (Test-Path $Path) {
        if ($PSCmdlet.ShouldProcess($Path, "Remover arquivo/pasta")) {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path $Path) {
                Write-Host "[AVISO] Nao foi possivel remover totalmente (arquivo em uso?): $Path" -ForegroundColor Yellow
            }
            else {
                Write-Host "[OK] Removido: $Path" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "[--] Nao encontrado: $Path" -ForegroundColor DarkGray
    }
}

function Remove-ScheduledTaskSafe {
    param([string]$Pattern)
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        $_.TaskName -match $Pattern -or $_.TaskPath -match $Pattern
    }
    foreach ($task in $tasks) {
        $full = Join-Path $task.TaskPath $task.TaskName
        if ($PSCmdlet.ShouldProcess($full, "Remover tarefa agendada")) {
            Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "[OK] Tarefa agendada removida: $full" -ForegroundColor Green
        }
    }
    if (-not $tasks) {
        Write-Host "[--] Nenhuma tarefa agendada encontrada para o padrao '$Pattern'" -ForegroundColor DarkGray
    }
}

Write-Host "`n=== Limpeza completa: Riot Client / Vanguard / VALORANT ===`n" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. Servicos e driver do Vanguard
# ---------------------------------------------------------------------------
Write-Host "--- Servicos e driver ---" -ForegroundColor Cyan
Remove-ServiceSafe -ServiceName "vgk"
Remove-ServiceSafe -ServiceName "vgc"
Remove-PathSafe -Path "$env:WINDIR\System32\drivers\vgk.sys"

# ---------------------------------------------------------------------------
# 2. Registro — chaves principais da Riot Games
# ---------------------------------------------------------------------------
Write-Host "`n--- Registro: chaves principais ---" -ForegroundColor Cyan
$riotKeys = @(
    'HKLM:\SOFTWARE\Riot Games, Inc',
    'HKLM:\SOFTWARE\WOW6432Node\Riot Games, Inc',
    'HKLM:\SOFTWARE\Riot Games',
    'HKLM:\SOFTWARE\WOW6432Node\Riot Games',
    'HKCU:\SOFTWARE\Riot Games, Inc',
    'HKCU:\SOFTWARE\Riot Games'
)
foreach ($key in $riotKeys) { Remove-RegKeySafe -Path $key }

# ---------------------------------------------------------------------------
# 3. Registro — entradas de desinstalacao
# ---------------------------------------------------------------------------
Write-Host "`n--- Registro: entradas de desinstalacao ---" -ForegroundColor Cyan
Remove-UninstallEntries -Pattern 'Riot Client|Riot Vanguard|VALORANT'

# ---------------------------------------------------------------------------
# 4. Registro — handlers de protocolo (best-effort)
# ---------------------------------------------------------------------------
Write-Host "`n--- Registro: handlers de protocolo ---" -ForegroundColor Cyan
$protocolKeys = @(
    'HKLM:\SOFTWARE\Classes\riotclient',
    'HKLM:\SOFTWARE\Classes\riotgames',
    'HKLM:\SOFTWARE\Classes\rgp',
    'HKCU:\SOFTWARE\Classes\riotclient',
    'HKCU:\SOFTWARE\Classes\riotgames',
    'HKCU:\SOFTWARE\Classes\rgp'
)
foreach ($key in $protocolKeys) { Remove-RegKeySafe -Path $key }

# ---------------------------------------------------------------------------
# 5. Pastas em disco
# ---------------------------------------------------------------------------
Write-Host "`n--- Pastas em disco ---" -ForegroundColor Cyan
$diskPaths = @(
    "C:\Riot Games",
    "C:\ProgramData\Riot Games",
    "C:\Program Files\Riot Vanguard",
    "$env:LOCALAPPDATA\Riot Games",
    "$env:APPDATA\Riot Games"
)
foreach ($path in $diskPaths) { Remove-PathSafe -Path $path }

# ---------------------------------------------------------------------------
# 6. Tarefa agendada do Vanguard
# ---------------------------------------------------------------------------
Write-Host "`n--- Tarefas agendadas ---" -ForegroundColor Cyan
Remove-ScheduledTaskSafe -Pattern 'Riot|Vanguard|VALORANT'

# ---------------------------------------------------------------------------
# 7. Atalhos (Area de Trabalho e Menu Iniciar, usuario atual + All Users)
# ---------------------------------------------------------------------------
Write-Host "`n--- Atalhos ---" -ForegroundColor Cyan
$shortcutDirs = @(
    "$env:USERPROFILE\Desktop",
    "$env:PUBLIC\Desktop",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
)
foreach ($dir in $shortcutDirs) {
    if (Test-Path $dir) {
        Get-ChildItem -Path $dir -Recurse -Filter "*.lnk" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'Riot|VALORANT|Vanguard' } |
            ForEach-Object { Remove-PathSafe -Path $_.FullName }
    }
}

Write-Host "`n=== Concluido ===" -ForegroundColor Cyan
Write-Host "Reinicie o Windows para garantir que o driver vgk seja totalmente descarregado e" -ForegroundColor Yellow
Write-Host "qualquer arquivo que ainda estava em uso possa ser removido no proximo boot.`n" -ForegroundColor Yellow
