# Sistema de Monitoramento Anti-Travamento

Um sistema robusto de monitoramento que detecta e resolve automaticamente travamentos do sistema, encerrando processos problemáticos que consomem recursos excessivos.

## 🎯 Funcionalidades

### 🚨 Detecção Inteligente de Travamentos
- **Monitoramento em tempo real** do estado do sistema
- **Detecção automática** de travamentos baseada em:
  - Load average elevado (Linux)
  - Tempo de resposta do sistema
  - Uso excessivo de CPU/memória
  - Testes de responsividade do sistema

### 🔧 Recuperação Automática
- **Encerramento seguro** de processos problemáticos
- **Lista de proteção** para processos críticos do sistema
- **Liberação automática** de cache de memória
- **Notificações visuais** em tempo real
- **Logs detalhados** de todas as ações

### 🎛️ Configuração Flexível
- **Thresholds personalizáveis** para CPU e memória
- **Intervalos de verificação** ajustáveis
- **Tempo de timeout** configurável
- **Limite de processos** encerrados por vez
- **Modo daemon/serviço** para execução em background

## 📁 Estrutura do Projeto

```
anti-freeze-monitor/
├── README                     # Este arquivo
├── linux/                     # Scripts para Linux
│   ├── anti-freeze-monitor.sh  # Script principal
│   └── README                  # Documentação específica do Linux
└── windows/                    # Scripts para Windows
    ├── Anti-FreezeMonitor.ps1  # Script PowerShell principal
    ├── Anti-FreezeMonitor.bat  # Launcher batch
    ├── Install.ps1            # Script de instalação
    └── README-Windows.md       # Documentação específica do Windows
```

## 🐧 Linux

### Requisitos
- Sistema Linux (Ubuntu/Debian, CentOS/RHEL, Fedora)
- Acesso root (sudo)
- Dependências instaladas automaticamente:
  - `bc` (calculadora de linha de comando)
  - `libnotify-bin` (notificações desktop)
  - `zenity` (diálogos gráficos)

### Instalação e Uso

#### Execução Simples
```bash
# Torna o script executável
chmod +x linux/anti-freeze-monitor.sh

# Executa com notificações
sudo ./linux/anti-freeze-monitor.sh

# Executa sem notificações
sudo ./linux/anti-freeze-monitor.sh --no-notifications
```

#### Instalação como Serviço
```bash
# Instala dependências e cria serviço systemd
sudo ./linux/anti-freeze-monitor.sh --install

# Inicia o serviço
sudo systemctl start anti-freeze

# Verifica status
sudo systemctl status anti-freeze

# Para/reinicia
sudo systemctl stop anti-freeze
sudo systemctl restart anti-freeze
```

### Configurações (Linux)
- **FREEZE_TIMEOUT**: 5s - Tempo para considerar travamento
- **CHECK_INTERVAL**: 1s - Intervalo entre verificações
- **CPU_THRESHOLD**: 80% - Limite de CPU para processos problemáticos
- **MEMORY_THRESHOLD**: 15% - Limite de memória para processos problemáticos
- **MAX_PROCESSES_TO_KILL**: 3 - Máximo de processos encerrados por vez
- **LOG_FILE**: `/var/log/anti-freeze.log`

## 🪟 Windows

### Requisitos
- Windows 10/11 ou Windows Server 2016+
- PowerShell 5.1+ (já incluído no Windows)
- Privilégios de administrador

### Instalação e Uso

#### Execução Manual
1. **Baixe** os arquivos para uma pasta
2. **Clique com botão direito** em `Anti-FreezeMonitor.bat`
3. **Selecione** "Executar como administrador"
4. **Escolha** uma opção do menu:
   - Monitoramento com notificações
   - Monitoramento sem notificações
   - Instalação como serviço

#### Execução via PowerShell
```powershell
# Execução normal
.\windows\Anti-FreezeMonitor.ps1

# Sem notificações
.\windows\Anti-FreezeMonitor.ps1 -NoNotifications

# Instalação como serviço
.\windows\Anti-FreezeMonitor.ps1 -Install
```

#### Instalação como Serviço
```powershell
# Via script batch (menu opção 3)
.\windows\Anti-FreezeMonitor.bat

# Ou via PowerShell
.\windows\Install.ps1
```

### Configurações (Windows)
- **FREEZE_TIMEOUT**: 5s - Tempo para considerar travamento
- **CHECK_INTERVAL**: 1s - Intervalo entre verificações
- **CPU_THRESHOLD**: 80% - Limite de CPU para processos problemáticos
- **MEMORY_THRESHOLD**: 15% - Limite de memória para processos problemáticos
- **MAX_PROCESSES_TO_KILL**: 3 - Máximo de processos encerrados por vez
- **LOG_FILE**: `%TEMP%\anti-freeze.log`

## 🛡️ Processos Protegidos

### Linux
- `systemd`, `kernel`, `init`
- `ssh`, `NetworkManager`
- Outros processos críticos do sistema

### Windows
- `System`, `csrss`, `winlogon`
- `services`, `lsass`, `explorer`
- `dwm`, `svchost`

## 📊 Como Funciona

### 1. Detecção de Travamento
O sistema monitora continuamente:
- **Load average** vs número de CPUs (Linux)
- **Tempo de resposta** a comandos simples
- **Uso de CPU/memória** dos processos
- **Responsividade** do sistema operacional

### 2. Identificação de Processos Problemáticos
Quando um travamento é detectado:
- **Lista** processos com alto consumo de recursos
- **Filtra** processos protegidos (whitelist)
- **Ordena** por consumo de CPU e memória
- **Seleciona** até X processos para encerramento

### 3. Recuperação do Sistema
- **Encerra processos** graciosamente (SIGTERM/CloseMainWindow)
- **Força encerramento** se necessário (SIGKILL/Kill)
- **Libera cache** de memória se não houver processos para encerrar
- **Registra** todas as ações nos logs
- **Notifica** o usuário sobre as ações realizadas

### 4. Monitoramento Contínuo
- **Aguarda** estabilização do sistema
- **Reinicia** ciclo de monitoramento
- **Mantém** histórico nos logs
- **Previne** ações muito frequentes

## 📝 Logs

### Localização
- **Linux**: `/var/log/anti-freeze.log`
- **Windows**: `%TEMP%\anti-freeze.log`

### Informações Registradas
- Timestamp de todas as ações
- Detecções de travamento
- Processos encerrados (PID, nome, CPU%, memória%)
- Liberação de cache
- Estatísticas do sistema
- Erros e avisos

## 🔧 Personalização

### Editando Configurações
Abra o script e modifique as variáveis no topo:

**Linux** (`anti-freeze-monitor.sh`):
```bash
FREEZE_TIMEOUT=5          # Altere conforme necessário
CPU_THRESHOLD=80          # 0-100%
MEMORY_THRESHOLD=15       # 0-100%
MAX_PROCESSES_TO_KILL=3   # Número de processos
```

**Windows** (`Anti-FreezeMonitor.ps1`):
```powershell
$FREEZE_TIMEOUT = 5          # Altere conforme necessário
$CPU_THRESHOLD = 80          # 0-100%
$MEMORY_THRESHOLD = 15       # 0-100%
$MAX_PROCESSES_TO_KILL = 3   # Número de processos
```

### Adicionando Processos à Whitelist
Edite a variável `WHITELIST`/`$WHITELIST` nos scripts.

## ⚠️ Avisos Importantes

1. **Execute sempre como administrador/root**
2. **Teste** as configurações antes de usar em produção
3. **Monitore** os logs para verificar funcionamento
4. **Backup** de dados importantes antes de usar
5. **Configure** thresholds adequados para seu sistema

## 🚀 Casos de Uso

- **Servidores** com aplicações que podem travar
- **Estações de trabalho** com software pesado
- **Sistemas de desenvolvimento** que executam builds longos
- **Ambientes** onde a estabilidade é crítica
- **Sistemas remotos** que precisam de recuperação automática

## 📞 Suporte

- **Logs**: Sempre consulte os logs para diagnóstico
- **Configurações**: Ajuste os thresholds conforme seu hardware
- **Processos**: Adicione aplicações importantes à whitelist
- **Testes**: Execute em modo manual antes de instalar como serviço

---

**Desenvolvido para manter seus sistemas funcionando de forma confiável e automática!** 🚀