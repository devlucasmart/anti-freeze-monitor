# =============================================================================
# Sistema de Monitoramento Anti-Travamento para Windows
# Detecta travamentos do sistema e encerra processos com alto consumo de recursos
# =============================================================================

param(
    [switch]$Install,
    [switch]$Service,
    [switch]$NoNotifications,
    [switch]$Help
)

# Configurações
$FREEZE_TIMEOUT = 5          # Tempo em segundos para considerar travamento
$CHECK_INTERVAL = 1          # Intervalo entre verificações (segundos)
$CPU_THRESHOLD = 80          # Threshold de CPU para considerar processo problemático (%)
$MEMORY_THRESHOLD = 15       # Threshold de memória para considerar processo problemático (%)
$MAX_PROCESSES_TO_KILL = 3   # Máximo de processos a serem encerrados por vez
$LOG_FILE = "$env:TEMP\anti-freeze.log"
$WHITELIST = @("System", "csrss", "winlogon", "services", "lsass", "explorer", "dwm", "svchost")  # Processos protegidos
$SHOW_NOTIFICATIONS = $true   # Mostrar notificações na tela
$NOTIFICATION_TIMEOUT = 10    # Tempo de exibição das notificações (segundos)
$SERVICE_NAME = "AntiFreeze"

# Função para logging
function Write-LogMessage {
    param([string]$Message)
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $Message"
    
    Write-Host $logEntry -ForegroundColor Green
    Add-Content -Path $LOG_FILE -Value $logEntry -Encoding UTF8
}

# Função para verificar se o processo está na whitelist
function Test-IsWhitelisted {
    param([string]$ProcessName)
    
    foreach ($whitelistItem in $WHITELIST) {
        if ($ProcessName -like "*$whitelistItem*") {
            return $true
        }
    }
    return $false
}

# Função para obter CPU count
function Get-CpuCount {
    return (Get-WmiObject -Class Win32_ComputerSystem).NumberOfLogicalProcessors
}

# Função para obter uso de CPU do sistema
function Get-SystemCpuUsage {
    $cpuUsage = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 2
    return [math]::Round(($cpuUsage.CounterSamples | Select-Object -Last 1).CookedValue, 2)
}

# Função para obter uso de memória do sistema
function Get-SystemMemoryUsage {
    $totalMemory = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory
    $availableMemory = (Get-WmiObject -Class Win32_OperatingSystem).FreePhysicalMemory * 1024
    $usedMemory = $totalMemory - $availableMemory
    return [math]::Round(($usedMemory / $totalMemory) * 100, 2)
}

# Função para verificar se o sistema está travado
function Test-SystemFrozen {
    try {
        # Verifica responsividade do sistema testando acesso ao registro
        $startTime = Get-Date
        $null = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion" -Name "ProgramFilesDir" -ErrorAction Stop
        $responseTime = (Get-Date) - $startTime
        
        # Se demorar mais que o timeout, considera travado
        if ($responseTime.TotalSeconds -gt $FREEZE_TIMEOUT) {
            return $true
        }
        
        # Verifica CPU muito alta por muito tempo
        $cpuUsage = Get-SystemCpuUsage
        if ($cpuUsage -gt 95) {
            Start-Sleep -Seconds 2
            $cpuUsage2 = Get-SystemCpuUsage
            if ($cpuUsage2 -gt 95) {
                return $true
            }
        }
        
        return $false
    }
    catch {
        return $true  # Se houve erro, assume que está travado
    }
}

# Função para obter processos com alto consumo
function Get-HighResourceProcesses {
    try {
        $processes = Get-Process | Where-Object {
            $_.ProcessName -and 
            $_.CPU -and 
            $_.WorkingSet -and
            ($_.CPU -gt 0 -or $_.WorkingSet -gt 0)
        } | ForEach-Object {
            try {
                $cpuPercent = 0
                $memoryPercent = 0
                
                # Calcula CPU percent (aproximado)
                if ($_.CPU) {
                    $runtime = (Get-Date) - $_.StartTime
                    if ($runtime.TotalSeconds -gt 0) {
                        $cpuPercent = [math]::Round(($_.CPU / $runtime.TotalSeconds) / (Get-CpuCount) * 100, 2)
                    }
                }
                
                # Calcula Memory percent
                if ($_.WorkingSet) {
                    $totalMemory = (Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory
                    $memoryPercent = [math]::Round(($_.WorkingSet / $totalMemory) * 100, 2)
                }
                
                if ($cpuPercent -gt $CPU_THRESHOLD -or $memoryPercent -gt $MEMORY_THRESHOLD) {
                    return [PSCustomObject]@{
                        PID = $_.Id
                        Name = $_.ProcessName
                        CPU = $cpuPercent
                        Memory = $memoryPercent
                        WorkingSet = [math]::Round($_.WorkingSet / 1MB, 2)
                    }
                }
            }
            catch {
                # Ignora processos que não conseguimos acessar
            }
        } | Sort-Object CPU, Memory -Descending | Select-Object -First 10
        
        return $processes
    }
    catch {
        Write-LogMessage "Erro ao obter processos com alto consumo: $_"
        return @()
    }
}

# Função para encerrar processo com segurança
function Stop-ProcessSafely {
    param(
        [int]$ProcessId,
        [string]$ProcessName,
        [double]$CpuUsage,
        [double]$MemoryUsage
    )
    
    try {
        # Verifica se o processo ainda existe
        $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if (-not $process) {
            Write-LogMessage "Processo PID $ProcessId já não existe"
            return $false
        }
        
        # Verifica whitelist
        if (Test-IsWhitelisted -ProcessName $ProcessName) {
            Write-LogMessage "Processo $ProcessName (PID: $ProcessId) está na whitelist - IGNORADO"
            return $false
        }
        
        Write-LogMessage "ENCERRANDO processo problemático:"
        Write-LogMessage "  PID: $ProcessId | Nome: $ProcessName | CPU: $CpuUsage% | MEM: $MemoryUsage%"
        
        # Notificação sobre o processo sendo encerrado
        Send-DesktopNotification -Title "🚨 Sistema Anti-Travamento" -Message "Encerrando processo problemático:`n• Nome: $ProcessName`n• PID: $ProcessId`n• CPU: $CpuUsage%`n• Memória: $MemoryUsage%" -Type "Warning"
        
        # Tenta encerrar graciosamente primeiro
        $process.CloseMainWindow()
        Start-Sleep -Seconds 3
        
        # Verifica se ainda está rodando
        $process.Refresh()
        if (-not $process.HasExited) {
            Write-LogMessage "Processo $ProcessId não respondeu, forçando encerramento"
            $process.Kill()
            Start-Sleep -Seconds 1
            
            if ((Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) -eq $null) {
                Write-LogMessage "Processo $ProcessId encerrado com sucesso"
                Send-DesktopNotification -Title "✅ Processo Encerrado" -Message "Processo $ProcessName (PID: $ProcessId) foi encerrado" -Type "Information"
                return $true
            }
            else {
                Write-LogMessage "ERRO: Não foi possível encerrar processo $ProcessId"
                return $false
            }
        }
        else {
            Write-LogMessage "Processo $ProcessId encerrado graciosamente"
            Send-DesktopNotification -Title "✅ Processo Encerrado" -Message "Processo $ProcessName (PID: $ProcessId) foi encerrado graciosamente" -Type "Information"
            return $true
        }
    }
    catch {
        Write-LogMessage "ERRO ao encerrar processo $ProcessId : $_"
        return $false
    }
}

# Função para liberar memória cache
function Clear-MemoryCache {
    Write-LogMessage "Liberando cache de memória..."
    
    Send-DesktopNotification -Title "🧹 Sistema Anti-Travamento" -Message "Liberando cache de memória para melhorar performance" -Type "Information"
    
    try {
        # Força garbage collection
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
        
        # Limpa working set de processos (equivalente ao drop_caches do Linux)
        if ([Environment]::OSVersion.Version.Major -ge 6) {
            $signature = @"
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool SetProcessWorkingSetSize(IntPtr hProcess, UIntPtr dwMinimumWorkingSetSize, UIntPtr dwMaximumWorkingSetSize);
[DllImport("kernel32.dll")]
public static extern IntPtr GetCurrentProcess();
"@
            
            $type = Add-Type -MemberDefinition $signature -Name "Win32" -Namespace "Win32Functions" -PassThru -ErrorAction SilentlyContinue
            if ($type) {
                $null = [Win32Functions.Win32]::SetProcessWorkingSetSize((Get-Process -Id $PID).Handle, [UIntPtr]::Zero, [UIntPtr]::Zero)
            }
        }
        
        Write-LogMessage "Cache de memória liberado"
        Send-DesktopNotification -Title "✅ Cache Liberado" -Message "Cache de memória foi liberado com sucesso" -Type "Information"
    }
    catch {
        Write-LogMessage "Erro ao liberar cache: $_"
    }
}

# Função para mostrar estatísticas do sistema
function Show-SystemStats {
    try {
        $cpuUsage = Get-SystemCpuUsage
        $memUsage = Get-SystemMemoryUsage
        $cpuCount = Get-CpuCount
        $uptime = (Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
        
        Write-LogMessage "=== ESTATÍSTICAS DO SISTEMA ==="
        Write-LogMessage "CPU: $cpuUsage% (Cores: $cpuCount)"
        Write-LogMessage "Memória: $memUsage%"
        Write-LogMessage "Uptime: $($uptime.Days) dias, $($uptime.Hours) horas"
    }
    catch {
        Write-LogMessage "Erro ao obter estatísticas: $_"
    }
}

# Função para enviar notificação desktop
function Send-DesktopNotification {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Type = "Information"  # Information, Warning, Error
    )
    
    if (-not $SHOW_NOTIFICATIONS) {
        return
    }
    
    try {
        # Usa Windows Toast Notification
        Add-Type -AssemblyName System.Windows.Forms
        
        $notification = New-Object System.Windows.Forms.NotifyIcon
        $notification.Icon = [System.Drawing.SystemIcons]::Information
        $notification.BalloonTipIcon = $Type
        $notification.BalloonTipText = $Message
        $notification.BalloonTipTitle = $Title
        $notification.Visible = $true
        $notification.ShowBalloonTip($NOTIFICATION_TIMEOUT * 1000)
        
        Start-Sleep -Seconds 1
        $notification.Dispose()
    }
    catch {
        # Fallback para Write-Host se notificações falharem
        Write-Host "$Title - $Message" -ForegroundColor Yellow
    }
}

# Função para mostrar modal detalhado
function Show-ModalDialog {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Type = "Information"
    )
    
    if (-not $SHOW_NOTIFICATIONS) {
        return
    }
    
    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::$Type)
    }
    catch {
        Write-Host "$Title`n$Message" -ForegroundColor Cyan
    }
}

# Função principal de monitoramento
function Start-SystemMonitoring {
    Write-LogMessage "=== INICIANDO MONITORAMENTO ANTI-TRAVAMENTO ==="
    Write-LogMessage "Configurações:"
    Write-LogMessage "  - Timeout de travamento: ${FREEZE_TIMEOUT}s"
    Write-LogMessage "  - Intervalo de verificação: ${CHECK_INTERVAL}s"
    Write-LogMessage "  - Threshold CPU: ${CPU_THRESHOLD}%"
    Write-LogMessage "  - Threshold Memória: ${MEMORY_THRESHOLD}%"
    Write-LogMessage "  - Máximo de processos a encerrar: $MAX_PROCESSES_TO_KILL"
    
    $freezeCount = 0
    $lastActionTime = 0
    
    while ($true) {
        try {
            $currentTime = (Get-Date).Ticks / 10000000  # Segundos desde epoch
            
            # Verifica se o sistema está travado
            if (Test-SystemFrozen) {
                $freezeCount++
                Write-LogMessage "SISTEMA TRAVADO DETECTADO! (${freezeCount}ª detecção)"
                
                # Notificação crítica de travamento
                Send-DesktopNotification -Title "🚨 SISTEMA TRAVADO!" -Message "Travamento detectado! Iniciando ações de recuperação..." -Type "Error"
                
                # Previne ações muito frequentes (mínimo 30 segundos entre ações)
                if (($currentTime - $lastActionTime) -lt 30) {
                    Write-LogMessage "Aguardando 30s antes da próxima ação..."
                    Start-Sleep -Seconds 5
                    continue
                }
                
                Show-SystemStats
                
                # Obtém processos com alto consumo
                Write-LogMessage "Identificando processos com alto consumo de recursos..."
                
                $processesKilled = 0
                $killedProcessesList = ""
                
                $highResourceProcesses = Get-HighResourceProcesses
                
                foreach ($proc in $highResourceProcesses) {
                    if ($processesKilled -lt $MAX_PROCESSES_TO_KILL) {
                        if (Stop-ProcessSafely -ProcessId $proc.PID -ProcessName $proc.Name -CpuUsage $proc.CPU -MemoryUsage $proc.Memory) {
                            $processesKilled++
                            $killedProcessesList += "• $($proc.Name) (PID: $($proc.PID)) - CPU: $($proc.CPU)%, MEM: $($proc.Memory)%`n"
                            Start-Sleep -Seconds 2  # Pausa entre os kills
                        }
                    }
                }
                
                if ($processesKilled -eq 0) {
                    Write-LogMessage "Nenhum processo foi encerrado. Liberando cache de memória..."
                    Clear-MemoryCache
                }
                else {
                    Write-LogMessage "$processesKilled processo(s) encerrado(s)"
                    
                    # Modal detalhado com resumo das ações
                    $summaryMessage = "Sistema recuperado!`n`n"
                    $summaryMessage += "Processos encerrados ($processesKilled):`n"
                    $summaryMessage += $killedProcessesList
                    $summaryMessage += "`nTempo de detecção: ${FREEZE_TIMEOUT}s`n"
                    $summaryMessage += (Get-Date -Format "HH:mm:ss - dd/MM/yyyy")
                    
                    Show-ModalDialog -Title "Sistema Anti-Travamento - Relatório" -Message $summaryMessage -Type "Information"
                    
                    # Notificação de recuperação
                    Send-DesktopNotification -Title "✅ Sistema Recuperado" -Message "Travamento resolvido! $processesKilled processo(s) encerrado(s)" -Type "Information"
                }
                
                $lastActionTime = $currentTime
                $freezeCount = 0  # Reset contador após ação
                
                # Aguarda um pouco para o sistema se estabilizar
                Start-Sleep -Seconds 10
            }
            else {
                # Sistema OK, reset contador
                if ($freezeCount -gt 0) {
                    Write-LogMessage "Sistema estabilizado"
                    $freezeCount = 0
                }
            }
            
            Start-Sleep -Seconds $CHECK_INTERVAL
        }
        catch {
            Write-LogMessage "Erro no loop de monitoramento: $_"
            Start-Sleep -Seconds 5
        }
    }
}

# Função para instalar como serviço do Windows
function Install-WindowsService {
    try {
        Write-LogMessage "Instalando serviço do Windows..."
        
        # Verifica se está executando como administrador
        if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            Write-Host "Este script precisa ser executado como Administrador!" -ForegroundColor Red
            Write-Host "Clique com o botão direito no PowerShell e selecione 'Executar como administrador'" -ForegroundColor Yellow
            exit 1
        }
        
        $servicePath = $PSCommandPath
        $serviceDisplayName = "Sistema Anti-Travamento"
        $serviceDescription = "Detecta travamentos do sistema e encerra processos com alto consumo de recursos"
        
        # Remove serviço se já existir
        $existingService = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
        if ($existingService) {
            Write-LogMessage "Removendo serviço existente..."
            Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
            & sc.exe delete $SERVICE_NAME
            Start-Sleep -Seconds 2
        }
        
        # Cria novo serviço
        $serviceCommand = "PowerShell.exe -ExecutionPolicy Bypass -File `"$servicePath`" -Service"
        
        & sc.exe create $SERVICE_NAME binPath= $serviceCommand DisplayName= $serviceDisplayName start= auto
        & sc.exe description $SERVICE_NAME $serviceDescription
        
        Write-LogMessage "Serviço instalado com sucesso!"
        Write-LogMessage "Use: Start-Service -Name $SERVICE_NAME para iniciar"
        Write-LogMessage "Use: Stop-Service -Name $SERVICE_NAME para parar"
        
        return $true
    }
    catch {
        Write-LogMessage "Erro ao instalar serviço: $_"
        return $false
    }
}

# Função para desinstalar serviço
function Uninstall-WindowsService {
    try {
        $existingService = Get-Service -Name $SERVICE_NAME -ErrorAction SilentlyContinue
        if ($existingService) {
            Write-LogMessage "Removendo serviço..."
            Stop-Service -Name $SERVICE_NAME -Force -ErrorAction SilentlyContinue
            & sc.exe delete $SERVICE_NAME
            Write-LogMessage "Serviço removido com sucesso!"
        }
        else {
            Write-LogMessage "Serviço não encontrado"
        }
    }
    catch {
        Write-LogMessage "Erro ao remover serviço: $_"
    }
}

# Função para mostrar ajuda
function Show-Help {
    Write-Host @"
Sistema de Monitoramento Anti-Travamento para Windows

Uso: .\Anti-FreezeMonitor.ps1 [parâmetros]

Parâmetros:
  -Install            Instala como serviço do Windows
  -Service            Executa em modo serviço
  -NoNotifications    Desabilita notificações visuais
  -Help               Mostra esta ajuda

Exemplos:
  .\Anti-FreezeMonitor.ps1                    # Execução normal
  .\Anti-FreezeMonitor.ps1 -Install           # Instala como serviço
  .\Anti-FreezeMonitor.ps1 -NoNotifications   # Sem notificações

Gerenciamento do Serviço:
  Start-Service -Name AntiFreeze              # Iniciar serviço
  Stop-Service -Name AntiFreeze               # Parar serviço
  Get-Service -Name AntiFreeze                # Status do serviço
  
Logs:
  $LOG_FILE

"@ -ForegroundColor Cyan
}

# Função para verificar se está executando como administrador
function Test-Administrator {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

# Função principal
function Main {
    # Verifica parâmetros
    if ($Help) {
        Show-Help
        exit 0
    }
    
    # Verifica se está executando como administrador (necessário para encerrar processos)
    if (-not (Test-Administrator)) {
        Write-Host "Este script precisa ser executado como Administrador!" -ForegroundColor Red
        Write-Host "Clique com o botão direito no PowerShell e selecione 'Executar como administrador'" -ForegroundColor Yellow
        exit 1
    }
    
    # Processa parâmetros
    if ($Install) {
        Install-WindowsService
        exit 0
    }
    
    if ($NoNotifications) {
        $global:SHOW_NOTIFICATIONS = $false
        Write-LogMessage "Notificações visuais desabilitadas"
    }
    
    # Cria diretório de log se não existir
    $logDir = Split-Path -Path $LOG_FILE -Parent
    if (-not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    # Tratamento de Ctrl+C
    [Console]::TreatControlCAsInput = $false
    $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
        Write-LogMessage "Encerrando monitoramento..."
    }
    
    # Inicia monitoramento
    Start-SystemMonitoring
}

# Executa função principal
if ($MyInvocation.InvocationName -ne '.') {
    Main
}
