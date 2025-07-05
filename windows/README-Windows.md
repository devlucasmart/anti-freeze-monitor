# Sistema Anti-Travamento para Windows

Sistema de monitoramento que detecta travamentos do Windows e encerra automaticamente processos com alto consumo de recursos.

## 🚀 Instalação e Uso

### Método 1: Interface Gráfica (Recomendado)
```cmd
# Execute o arquivo batch como Administrador
Anti-FreezeMonitor.bat
```

### Método 2: PowerShell Direto
```powershell
# Execução normal com notificações
.\Anti-FreezeMonitor.ps1

# Execução sem notificações visuais
.\Anti-FreezeMonitor.ps1 -NoNotifications

# Instalar como serviço do Windows
.\Anti-FreezeMonitor.ps1 -Install

# Ver ajuda
.\Anti-FreezeMonitor.ps1 -Help
```

## 🛠️ Executar como Serviço do Windows

### Instalação do Serviço:
```powershell
# Instala automaticamente como serviço
.\Anti-FreezeMonitor.ps1 -Install
```

### Gerenciar o Serviço:
```powershell
# Iniciar serviço
Start-Service -Name "AntiFreeze"

# Parar serviço
Stop-Service -Name "AntiFreeze"

# Ver status
Get-Service -Name "AntiFreeze"

# Desinstalar serviço
Stop-Service -Name "AntiFreeze" -Force
& sc.exe delete "AntiFreeze"
```

## 📊 Como Verificar os Logs

### Localização dos Logs:
```
%TEMP%\anti-freeze.log
```
*Geralmente: `C:\Users\[Usuario]\AppData\Local\Temp\anti-freeze.log`*

### Visualizar Logs em Tempo Real:
```powershell
# PowerShell - Monitorar logs
Get-Content "$env:TEMP\anti-freeze.log" -Wait -Tail 10

# Command Prompt - Ver últimas linhas
type "%TEMP%\anti-freeze.log"
```

### Logs do Serviço Windows:
```powershell
# Ver logs do serviço no Event Viewer
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Service Control Manager'} | Where-Object {$_.Message -like "*AntiFreeze*"}
```

## ⚙️ Configurações

### Configurações Principais:
- **Threshold CPU**: 80% (processos acima são considerados problemáticos)
- **Threshold Memória**: 15% (processos acima são considerados problemáticos)
- **Timeout Travamento**: 5 segundos
- **Intervalo de Verificação**: 1 segundo
- **Máximo de Processos Encerrados**: 3 por vez

### Processos Protegidos (Whitelist):
- `System` - Kernel do Windows
- `csrss` - Client/Server Runtime Subsystem
- `winlogon` - Processo de login
- `services` - Gerenciador de serviços
- `lsass` - Local Security Authority
- `explorer` - Windows Explorer
- `dwm` - Desktop Window Manager
- `svchost` - Service Host

## 🔧 Comandos Úteis

### Monitoramento Manual:
```powershell
# Ver processos com alto CPU
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10

# Ver processos com alta memória
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10

# Ver uso de CPU do sistema
Get-Counter '\Processor(_Total)\% Processor Time'

# Ver uso de memória do sistema
Get-WmiObject -Class Win32_OperatingSystem | Select-Object @{Name="MemoryUsage";Expression={[math]::Round((($_.TotalPhysicalMemory - $_.FreePhysicalMemory) / $_.TotalPhysicalMemory) * 100, 2)}}
```

### Limpeza Manual de Memória:
```powershell
# Força garbage collection
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
[System.GC]::Collect()
```

## 📋 Requisitos do Sistema

- **OS**: Windows 7/8/10/11 (32-bit ou 64-bit)
- **PowerShell**: 3.0 ou superior (já incluído no Windows)
- **Privilégios**: Executar como Administrador
- **RAM**: Mínimo 2GB recomendado
- **CPU**: Qualquer processador compatível com Windows

## 🚨 Avisos Importantes

### Segurança:
- ⚠️ **Execute sempre como Administrador**
- ⚠️ O sistema pode encerrar processos automaticamente
- ⚠️ Processos importantes estão protegidos por whitelist
- ⚠️ Teste em ambiente controlado antes de usar em produção

### Limitações:
- Não funciona com processos do sistema protegidos pelo Windows
- Requer privilégios administrativos para funcionar
- Notificações podem não aparecer em algumas versões do Windows Server

## 🔍 Troubleshooting

### Problemas Comuns:

#### "Execution Policy" Error:
```powershell
# Permitir execução de scripts (como Admin)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

#### Serviço não inicia:
```powershell
# Verificar logs do sistema
Get-WinEvent -FilterHashtable @{LogName='System'; Level=2,3} -MaxEvents 10
```

#### Notificações não aparecem:
- Verificar se as notificações estão habilitadas no Windows
- Executar como usuário normal, não como serviço, para testar

### Logs de Debug:
```powershell
# Executar com verbose
.\Anti-FreezeMonitor.ps1 -Verbose
```

## 📞 Suporte

- **Logs**: `%TEMP%\anti-freeze.log`
- **Event Viewer**: Windows Logs > System
- **Performance Monitor**: Para monitoramento detalhado do sistema

---

**Desenvolvido para Windows • Versão PowerShell • 2025**
