# =============================================================================
# Instalador Automático do Sistema Anti-Travamento para Windows
# =============================================================================

param(
    [switch]$Uninstall,
    [switch]$Silent,
    [string]$InstallPath = "$env:ProgramFiles\AntiFreeze"
)

# Verifica se está executando como administrador
function Test-Administrator {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

# Função para log
function Write-InstallLog {
    param([string]$Message, [string]$Type = "Info")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Type) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        default { "White" }
    }
    
    if (-not $Silent) {
        Write-Host "[$timestamp] $Message" -ForegroundColor $color
    }
    
    # Log to file
    Add-Content -Path "$env:TEMP\antifreeze-install.log" -Value "[$timestamp][$Type] $Message"
}

# Função para mostrar banner
function Show-Banner {
    if ($Silent) { return }
    
    Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║        Sistema Anti-Travamento para Windows - Instalador    ║
║                                                              ║
║  Detecta travamentos e encerra processos problemáticos      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan
}

# Função para instalar
function Install-AntiFreeze {
    try {
        Write-InstallLog "Iniciando instalação..." "Info"
        
        # Criar diretório de instalação
        if (-not (Test-Path $InstallPath)) {
            New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
            Write-InstallLog "Diretório criado: $InstallPath" "Success"
        }
        
        # Copiar arquivos
        $sourceFiles = @(
            "Anti-FreezeMonitor.ps1",
            "Anti-FreezeMonitor.bat",
            "README-Windows.md"
        )
        
        $scriptDir = Split-Path -Parent $PSCommandPath
        
        foreach ($file in $sourceFiles) {
            $sourcePath = Join-Path $scriptDir $file
            $destPath = Join-Path $InstallPath $file
            
            if (Test-Path $sourcePath) {
                Copy-Item $sourcePath $destPath -Force
                Write-InstallLog "Arquivo copiado: $file" "Success"
            } else {
                Write-InstallLog "Arquivo não encontrado: $file" "Warning"
            }
        }
        
        # Criar atalho na área de trabalho
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = Join-Path $desktopPath "Sistema Anti-Travamento.lnk"
        
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = Join-Path $InstallPath "Anti-FreezeMonitor.bat"
        $shortcut.WorkingDirectory = $InstallPath
        $shortcut.Description = "Sistema de Monitoramento Anti-Travamento"
        $shortcut.IconLocation = "shell32.dll,21"  # Ícone de escudo
        $shortcut.Save()
        
        Write-InstallLog "Atalho criado na área de trabalho" "Success"
        
        # Criar entrada no menu iniciar
        $startMenuPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
        $startMenuShortcut = Join-Path $startMenuPath "Sistema Anti-Travamento.lnk"
        
        $startShortcut = $shell.CreateShortcut($startMenuShortcut)
        $startShortcut.TargetPath = Join-Path $InstallPath "Anti-FreezeMonitor.bat"
        $startShortcut.WorkingDirectory = $InstallPath
        $startShortcut.Description = "Sistema de Monitoramento Anti-Travamento"
        $startShortcut.IconLocation = "shell32.dll,21"
        $startShortcut.Save()
        
        Write-InstallLog "Entrada criada no Menu Iniciar" "Success"
        
        # Adicionar ao PATH (opcional)
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        if ($currentPath -notlike "*$InstallPath*") {
            $newPath = "$currentPath;$InstallPath"
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
            Write-InstallLog "Adicionado ao PATH do sistema" "Success"
        }
        
        # Criar entrada no registro para Add/Remove Programs
        $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AntiFreeze"
        
        if (-not (Test-Path $uninstallKey)) {
            New-Item -Path $uninstallKey -Force | Out-Null
        }
        
        Set-ItemProperty -Path $uninstallKey -Name "DisplayName" -Value "Sistema Anti-Travamento"
        Set-ItemProperty -Path $uninstallKey -Name "DisplayVersion" -Value "1.0.0"
        Set-ItemProperty -Path $uninstallKey -Name "Publisher" -Value "Anti-Freeze Team"
        Set-ItemProperty -Path $uninstallKey -Name "InstallLocation" -Value $InstallPath
        Set-ItemProperty -Path $uninstallKey -Name "UninstallString" -Value "PowerShell.exe -ExecutionPolicy Bypass -File `"$InstallPath\Install.ps1`" -Uninstall"
        Set-ItemProperty -Path $uninstallKey -Name "DisplayIcon" -Value "shell32.dll,21"
        Set-ItemProperty -Path $uninstallKey -Name "NoModify" -Value 1
        Set-ItemProperty -Path $uninstallKey -Name "NoRepair" -Value 1
        
        Write-InstallLog "Entrada criada em Programas e Recursos" "Success"
        
        # Configurar ExecutionPolicy se necessário
        $currentPolicy = Get-ExecutionPolicy -Scope LocalMachine
        if ($currentPolicy -eq "Restricted") {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
            Write-InstallLog "ExecutionPolicy configurada para RemoteSigned" "Success"
        }
        
        Write-InstallLog "Instalação concluída com sucesso!" "Success"
        
        if (-not $Silent) {
            Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                    INSTALAÇÃO CONCLUÍDA!                    ║
║                                                              ║
║  ✅ Arquivos instalados em: $InstallPath
║  ✅ Atalho criado na área de trabalho                       ║
║  ✅ Entrada criada no Menu Iniciar                          ║
║  ✅ Adicionado ao PATH do sistema                           ║
║                                                              ║
║  Para usar:                                                  ║
║  • Clique no atalho da área de trabalho                     ║
║  • Ou execute: Anti-FreezeMonitor.bat                       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green
            
            Read-Host "Pressione Enter para continuar"
        }
        
        return $true
    }
    catch {
        Write-InstallLog "Erro durante a instalação: $_" "Error"
        return $false
    }
}

# Função para desinstalar
function Uninstall-AntiFreeze {
    try {
        Write-InstallLog "Iniciando desinstalação..." "Info"
        
        # Parar serviço se estiver rodando
        $service = Get-Service -Name "AntiFreeze" -ErrorAction SilentlyContinue
        if ($service) {
            Write-InstallLog "Parando serviço..." "Info"
            Stop-Service -Name "AntiFreeze" -Force -ErrorAction SilentlyContinue
            & sc.exe delete "AntiFreeze" | Out-Null
            Write-InstallLog "Serviço removido" "Success"
        }
        
        # Remover atalhos
        $desktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "Sistema Anti-Travamento.lnk"
        if (Test-Path $desktopShortcut) {
            Remove-Item $desktopShortcut -Force
            Write-InstallLog "Atalho da área de trabalho removido" "Success"
        }
        
        $startMenuShortcut = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Sistema Anti-Travamento.lnk"
        if (Test-Path $startMenuShortcut) {
            Remove-Item $startMenuShortcut -Force
            Write-InstallLog "Entrada do Menu Iniciar removida" "Success"
        }
        
        # Remover do PATH
        $currentPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
        if ($currentPath -like "*$InstallPath*") {
            $newPath = ($currentPath -split ';' | Where-Object { $_ -ne $InstallPath }) -join ';'
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
            Write-InstallLog "Removido do PATH do sistema" "Success"
        }
        
        # Remover entrada do registro
        $uninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\AntiFreeze"
        if (Test-Path $uninstallKey) {
            Remove-Item -Path $uninstallKey -Recurse -Force
            Write-InstallLog "Entrada removida de Programas e Recursos" "Success"
        }
        
        # Remover diretório de instalação
        if (Test-Path $InstallPath) {
            Remove-Item -Path $InstallPath -Recurse -Force
            Write-InstallLog "Diretório de instalação removido: $InstallPath" "Success"
        }
        
        Write-InstallLog "Desinstalação concluída com sucesso!" "Success"
        
        if (-not $Silent) {
            Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                  DESINSTALAÇÃO CONCLUÍDA!                   ║
║                                                              ║
║  ✅ Serviço removido                                        ║
║  ✅ Atalhos removidos                                       ║
║  ✅ Entradas do registro removidas                          ║
║  ✅ Arquivos removidos                                      ║
║                                                              ║
║  O Sistema Anti-Travamento foi completamente removido.      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green
            
            Read-Host "Pressione Enter para continuar"
        }
        
        return $true
    }
    catch {
        Write-InstallLog "Erro durante a desinstalação: $_" "Error"
        return $false
    }
}

# Função principal
function Main {
    # Verificar privilégios de administrador
    if (-not (Test-Administrator)) {
        Write-Host "Este instalador precisa ser executado como Administrador!" -ForegroundColor Red
        Write-Host "Clique com o botão direito e selecione 'Executar como administrador'" -ForegroundColor Yellow
        Read-Host "Pressione Enter para sair"
        exit 1
    }
    
    Show-Banner
    
    if ($Uninstall) {
        if (-not $Silent) {
            $confirm = Read-Host "Tem certeza que deseja desinstalar o Sistema Anti-Travamento? (S/N)"
            if ($confirm -notmatch '^[Ss]') {
                Write-Host "Desinstalação cancelada." -ForegroundColor Yellow
                exit 0
            }
        }
        
        $result = Uninstall-AntiFreeze
    }
    else {
        if (-not $Silent) {
            Write-Host "Preparando para instalar o Sistema Anti-Travamento..." -ForegroundColor Cyan
            Write-Host "Diretório de instalação: $InstallPath" -ForegroundColor Gray
            Write-Host ""
            
            $confirm = Read-Host "Continuar com a instalação? (S/N)"
            if ($confirm -notmatch '^[Ss]') {
                Write-Host "Instalação cancelada." -ForegroundColor Yellow
                exit 0
            }
        }
        
        $result = Install-AntiFreeze
    }
    
    if (-not $result) {
        exit 1
    }
}

# Executar se não estiver sendo importado
if ($MyInvocation.InvocationName -ne '.') {
    Main
}
