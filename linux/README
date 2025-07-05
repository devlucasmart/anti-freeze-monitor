# Sistema Anti-Travamento - Multiplataforma

Monitora o sistema em tempo real e encerra automaticamente processos problemáticos que causam travamentos.

## 🐧 LINUX (Bash) - anti-freeze-monitor.sh

### Instalação e Execução:
```bash
# Instalação completa (dependências + serviço systemd)
sudo ./anti-freeze-monitor.sh --install

# Iniciar serviço
sudo systemctl start anti-freeze

# Ver status
sudo systemctl status anti-freeze

# Execução manual com notificações
sudo ./anti-freeze-monitor.sh

# Execução manual sem notificações
sudo ./anti-freeze-monitor.sh --no-notifications
```

### Logs Linux:
```bash
# Logs principais
sudo tail -f /var/log/anti-freeze.log

# Logs do systemd
sudo journalctl -u anti-freeze.service -f
```

## 🪟 WINDOWS (PowerShell) - Anti-FreezeMonitor.ps1

### Instalação e Execução:
```powershell
# Interface gráfica (Execute como Administrador)
Anti-FreezeMonitor.bat

# Instalação automática completa
.\Install.ps1

# Instalar como serviço Windows
.\Anti-FreezeMonitor.ps1 -Install

# Iniciar serviço
Start-Service -Name "AntiFreeze"

# Ver status
Get-Service -Name "AntiFreeze"

# Execução manual
.\Anti-FreezeMonitor.ps1
```

### Logs Windows:
```cmd
# Logs principais
type "%TEMP%\anti-freeze.log"

# Event Viewer
Get-WinEvent -FilterHashtable @{LogName='System'}
```

## 📋 Comandos de Controle

### Linux:
```bash
sudo systemctl start|stop|restart|status anti-freeze
sudo journalctl -u anti-freeze.service --since today
```

### Windows:
```powershell
Start-Service|Stop-Service|Restart-Service -Name "AntiFreeze"
Get-Service -Name "AntiFreeze"
```

## ⚙️ Configurações Padrão

- **CPU Threshold**: 80%
- **Memory Threshold**: 15% 
- **Freeze Timeout**: 5 segundos
- **Check Interval**: 1 segundo
- **Max Processes Kill**: 3 por vez

## 📚 Documentação Completa

- **Linux**: Veja este README
- **Windows**: Veja `README-Windows.md`