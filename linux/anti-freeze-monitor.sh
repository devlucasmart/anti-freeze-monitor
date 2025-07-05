#!/bin/bash

# =============================================================================
# Sistema de Monitoramento Anti-Travamento
# Detecta travamentos do sistema e encerra processos com alto consumo de recursos
# =============================================================================

# Configurações
FREEZE_TIMEOUT=5          # Tempo em segundos para considerar travamento
CHECK_INTERVAL=1          # Intervalo entre verificações (segundos)
CPU_THRESHOLD=80          # Threshold de CPU para considerar processo problemático (%)
MEMORY_THRESHOLD=15       # Threshold de memória para considerar processo problemático (%)
MAX_PROCESSES_TO_KILL=3   # Máximo de processos a serem encerrados por vez
LOG_FILE="/var/log/anti-freeze.log"
WHITELIST=("systemd" "kernel" "init" "ssh" "NetworkManager")  # Processos protegidos
SHOW_NOTIFICATIONS=true      # Mostrar notificações na tela
NOTIFICATION_TIMEOUT=10      # Tempo de exibição das notificações (segundos)

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - ${message}" | tee -a "$LOG_FILE"
}

# Função para verificar se o processo está na whitelist
is_whitelisted() {
    local process_name="$1"
    for whitelist_item in "${WHITELIST[@]}"; do
        if [[ "$process_name" == *"$whitelist_item"* ]]; then
            return 0
        fi
    done
    return 1
}

# Função para obter load average
get_load_average() {
    awk '{print $1}' /proc/loadavg
}

# Função para obter número de CPUs
get_cpu_count() {
    nproc
}

# Função para verificar se o sistema está travado
is_system_frozen() {
    local start_time=$(date +%s)
    local load_avg=$(get_load_average)
    local cpu_count=$(get_cpu_count)
    
    # Considera travamento se load average > (CPUs * 2)
    local freeze_threshold=$(echo "$cpu_count * 2" | bc -l)
    
    if (( $(echo "$load_avg > $freeze_threshold" | bc -l) )); then
        # Verifica se o sistema responde
        timeout 2 ls /proc > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            return 0  # Sistema travado
        fi
        
        # Verifica se comando simples demora mais que o esperado
        timeout $FREEZE_TIMEOUT ping -c 1 127.0.0.1 > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            return 0  # Sistema travado
        fi
    fi
    
    return 1  # Sistema OK
}

# Função para obter processos com alto consumo
get_high_resource_processes() {
    # Obtém processos ordenados por CPU e memória
    ps aux --sort=-%cpu,-%mem | awk -v cpu_thresh="$CPU_THRESHOLD" -v mem_thresh="$MEMORY_THRESHOLD" '
    NR>1 {
        if ($3 > cpu_thresh || $4 > mem_thresh) {
            printf "%s|%s|%s|%s|%s\n", $2, $11, $3, $4, $1
        }
    }' | head -n 10
}

# Função para encerrar processo com segurança
kill_process_safely() {
    local pid="$1"
    local process_name="$2"
    local cpu_usage="$3"
    local mem_usage="$4"
    local user="$5"
    
    # Verifica se o processo ainda existe
    if ! kill -0 "$pid" 2>/dev/null; then
        log_message "${YELLOW}Processo PID $pid já não existe${NC}"
        return 1
    fi
    
    # Verifica whitelist
    if is_whitelisted "$process_name"; then
        log_message "${YELLOW}Processo $process_name (PID: $pid) está na whitelist - IGNORADO${NC}"
        return 1
    fi
    
    log_message "${RED}ENCERRANDO processo problemático:${NC}"
    log_message "  PID: $pid | Nome: $process_name | CPU: ${cpu_usage}% | MEM: ${mem_usage}% | User: $user"
    
    # Notificação sobre o processo sendo encerrado
    send_desktop_notification \
        "🚨 Sistema Anti-Travamento" \
        "Encerrando processo problemático:\n• Nome: $process_name\n• PID: $pid\n• CPU: ${cpu_usage}%\n• Memória: ${mem_usage}%" \
        "critical" \
        "dialog-error"
    
    # Tenta SIGTERM primeiro
    if kill -TERM "$pid" 2>/dev/null; then
        log_message "${YELLOW}Enviado SIGTERM para PID $pid${NC}"
        
        # Aguarda 3 segundos para o processo encerrar graciosamente
        sleep 3
        
        # Verifica se ainda está rodando
        if kill -0 "$pid" 2>/dev/null; then
            log_message "${RED}Processo $pid não respondeu ao SIGTERM, enviando SIGKILL${NC}"
            if kill -KILL "$pid" 2>/dev/null; then
                log_message "${GREEN}Processo $pid encerrado com SIGKILL${NC}"
                
                # Notificação de sucesso (força)
                send_desktop_notification \
                    "✅ Processo Encerrado" \
                    "Processo $process_name (PID: $pid) foi encerrado forçadamente" \
                    "normal" \
                    "dialog-information"
                return 0
            else
                log_message "${RED}ERRO: Não foi possível encerrar processo $pid${NC}"
                return 1
            fi
        else
            log_message "${GREEN}Processo $pid encerrado graciosamente${NC}"
            
            # Notificação de sucesso (gracioso)
            send_desktop_notification \
                "✅ Processo Encerrado" \
                "Processo $process_name (PID: $pid) foi encerrado graciosamente" \
                "normal" \
                "dialog-information"
            return 0
        fi
    else
        log_message "${RED}ERRO: Não foi possível enviar sinal para PID $pid${NC}"
        return 1
    fi
}

# Função para liberar memória cache
free_memory_cache() {
    log_message "${BLUE}Liberando cache de memória...${NC}"
    
    # Notificação sobre limpeza de cache
    send_desktop_notification \
        "🧹 Sistema Anti-Travamento" \
        "Liberando cache de memória para melhorar performance" \
        "normal" \
        "dialog-information"
    
    sync
    echo 1 > /proc/sys/vm/drop_caches
    echo 2 > /proc/sys/vm/drop_caches
    echo 3 > /proc/sys/vm/drop_caches
    log_message "${GREEN}Cache de memória liberado${NC}"
    
    # Notificação de conclusão
    send_desktop_notification \
        "✅ Cache Liberado" \
        "Cache de memória foi liberado com sucesso" \
        "normal" \
        "dialog-information"
}

# Função para mostrar estatísticas do sistema
show_system_stats() {
    local load_avg=$(get_load_average)
    local cpu_count=$(get_cpu_count)
    local mem_info=$(free -m | grep "Mem:")
    local mem_total=$(echo $mem_info | awk '{print $2}')
    local mem_used=$(echo $mem_info | awk '{print $3}')
    local mem_percent=$(echo "scale=1; ($mem_used * 100) / $mem_total" | bc -l)
    
    log_message "${BLUE}=== ESTATÍSTICAS DO SISTEMA ===${NC}"
    log_message "Load Average: $load_avg (CPUs: $cpu_count)"
    log_message "Memória: ${mem_used}MB/${mem_total}MB (${mem_percent}%)"
    log_message "Uptime: $(uptime -p)"
}

# Função principal de monitoramento
monitor_system() {
    log_message "${GREEN}=== INICIANDO MONITORAMENTO ANTI-TRAVAMENTO ===${NC}"
    log_message "Configurações:"
    log_message "  - Timeout de travamento: ${FREEZE_TIMEOUT}s"
    log_message "  - Intervalo de verificação: ${CHECK_INTERVAL}s"
    log_message "  - Threshold CPU: ${CPU_THRESHOLD}%"
    log_message "  - Threshold Memória: ${MEMORY_THRESHOLD}%"
    log_message "  - Máximo de processos a encerrar: $MAX_PROCESSES_TO_KILL"
    
    local freeze_count=0
    local last_action_time=0
    
    while true; do
        current_time=$(date +%s)
        
        # Verifica se o sistema está travado
        if is_system_frozen; then
            freeze_count=$((freeze_count + 1))
            log_message "${RED}SISTEMA TRAVADO DETECTADO! (${freeze_count}ª detecção)${NC}"
            
            # Notificação crítica de travamento
            send_desktop_notification \
                "🚨 SISTEMA TRAVADO!" \
                "Travamento detectado! Iniciando ações de recuperação..." \
                "critical" \
                "dialog-error"
            
            # Previne ações muito frequentes (mínimo 30 segundos entre ações)
            if [ $((current_time - last_action_time)) -lt 30 ]; then
                log_message "${YELLOW}Aguardando 30s antes da próxima ação...${NC}"
                sleep 5
                continue
            fi
            
            show_system_stats
            
            # Obtém processos com alto consumo
            log_message "${BLUE}Identificando processos com alto consumo de recursos...${NC}"
            
            processes_killed=0
            killed_processes_list=""
            
            while IFS='|' read -r pid process_name cpu_usage mem_usage user; do
                if [ -n "$pid" ] && [ "$processes_killed" -lt "$MAX_PROCESSES_TO_KILL" ]; then
                    if kill_process_safely "$pid" "$process_name" "$cpu_usage" "$mem_usage" "$user"; then
                        processes_killed=$((processes_killed + 1))
                        killed_processes_list="${killed_processes_list}• $process_name (PID: $pid) - CPU: ${cpu_usage}%, MEM: ${mem_usage}%\n"
                        sleep 2  # Pausa entre os kills
                    fi
                fi
            done < <(get_high_resource_processes)
            
            if [ "$processes_killed" -eq 0 ]; then
                log_message "${YELLOW}Nenhum processo foi encerrado. Liberando cache de memória...${NC}"
                free_memory_cache
            else
                log_message "${GREEN}$processes_killed processo(s) encerrado(s)${NC}"
                
                # Modal detalhado com resumo das ações
                local summary_message="Sistema recuperado!\n\n"
                summary_message="${summary_message}Processos encerrados ($processes_killed):\n"
                summary_message="${summary_message}${killed_processes_list}\n"
                summary_message="${summary_message}Tempo de detecção: ${FREEZE_TIMEOUT}s\n"
                summary_message="${summary_message}$(date '+%H:%M:%S - %d/%m/%Y')"
                
                show_modal_dialog \
                    "Sistema Anti-Travamento - Relatório" \
                    "$summary_message" \
                    "info"
                
                # Notificação de recuperação
                send_desktop_notification \
                    "✅ Sistema Recuperado" \
                    "Travamento resolvido! $processes_killed processo(s) encerrado(s)" \
                    "normal" \
                    "dialog-information"
            fi
            
            last_action_time=$current_time
            freeze_count=0  # Reset contador após ação
            
            # Aguarda um pouco para o sistema se estabilizar
            sleep 10
        else
            # Sistema OK, reset contador
            if [ "$freeze_count" -gt 0 ]; then
                log_message "${GREEN}Sistema estabilizado${NC}"
                freeze_count=0
            fi
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

# Função para verificar dependências
check_dependencies() {
    local missing_dependencies=()
    
    # Verifica se bc está instalado
    if ! command -v bc &> /dev/null; then
        missing_dependencies+=("bc")
    fi
    
    # Verifica se notify-send está disponível
    if ! command -v notify-send &> /dev/null; then
        missing_dependencies+=("notify-send")
    fi
    
    # Verifica se zenity está disponível
    if ! command -v zenity &> /dev/null; then
        missing_dependencies+=("zenity")
    fi
    
    if [ ${#missing_dependencies[@]} -ne 0 ]; then
        log_message "${RED}Dependências ausentes: ${missing_dependencies[*]}${NC}"
        log_message "${YELLOW}Instalando dependências...${NC}"
        
        # Instala dependências
        for dep in "${missing_dependencies[@]}"; do
            if [ "$dep" == "bc" ]; then
                if command -v apt-get &> /dev/null; then
                    sudo apt-get update && sudo apt-get install -y bc
                elif command -v yum &> /dev/null; then
                    sudo yum install -y bc
                elif command -v dnf &> /dev/null; then
                    sudo dnf install -y bc
                fi
            fi
        done
        
        log_message "${GREEN}Dependências instaladas com sucesso!${NC}"
    else
        log_message "${GREEN}Todas as dependências estão satisfeitas.${NC}"
    fi
}

# Função para instalar dependências
install_dependencies() {
    log_message "${BLUE}Verificando dependências...${NC}"
    
    # Verifica se bc está instalado
    if ! command -v bc &> /dev/null; then
        log_message "${YELLOW}Instalando bc...${NC}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y bc
        elif command -v yum &> /dev/null; then
            sudo yum install -y bc
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y bc
        else
            log_message "${RED}ERRO: Não foi possível instalar bc automaticamente${NC}"
            exit 1
        fi
    fi
    
    # Verifica e instala notify-send (libnotify)
    if ! command -v notify-send &> /dev/null; then
        log_message "${YELLOW}Instalando libnotify-bin...${NC}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y libnotify-bin
        elif command -v yum &> /dev/null; then
            sudo yum install -y libnotify
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y libnotify
        else
            log_message "${YELLOW}AVISO: notify-send não disponível - notificações desabilitadas${NC}"
            SHOW_NOTIFICATIONS=false
        fi
    fi
    
    # Verifica e instala zenity
    if ! command -v zenity &> /dev/null; then
        log_message "${YELLOW}Instalando zenity...${NC}"
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y zenity
        elif command -v yum &> /dev/null; then
            sudo yum install -y zenity
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y zenity
        else
            log_message "${YELLOW}AVISO: zenity não disponível - modais desabilitados${NC}"
        fi
    fi
}

# Função para criar serviço systemd
create_systemd_service() {
    cat > /tmp/anti-freeze.service << EOF
[Unit]
Description=Sistema Anti-Travamento
After=multi-user.target

[Service]
Type=simple
ExecStart=$PWD/$(basename "$0") --daemon
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

    log_message "${BLUE}Criando serviço systemd...${NC}"
    sudo mv /tmp/anti-freeze.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable anti-freeze.service
    log_message "${GREEN}Serviço criado! Use: sudo systemctl start anti-freeze${NC}"
}

# Função para detectar usuários logados com interface gráfica
get_logged_users() {
    who | grep "(:0" | awk '{print $1}' | sort -u
}

# Função para obter o DISPLAY do usuário
get_user_display() {
    local username="$1"
    local display=$(sudo -u "$username" bash -c 'echo $DISPLAY' 2>/dev/null)
    if [ -z "$display" ]; then
        display=":0"
    fi
    echo "$display"
}

# Função para enviar notificação desktop
send_desktop_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"  # low, normal, critical
    local icon="${4:-dialog-warning}"
    
    if [ "$SHOW_NOTIFICATIONS" != "true" ]; then
        return
    fi
    
    # Obtém usuários logados
    local users=($(get_logged_users))
    
    for user in "${users[@]}"; do
        if [ -n "$user" ]; then
            local display=$(get_user_display "$user")
            
            # Envia notificação usando notify-send
            sudo -u "$user" DISPLAY="$display" notify-send \
                --urgency="$urgency" \
                --expire-time=$((NOTIFICATION_TIMEOUT * 1000)) \
                --icon="$icon" \
                "$title" "$message" 2>/dev/null &
        fi
    done
}

# Função para mostrar modal detalhado
show_modal_dialog() {
    local title="$1"
    local message="$2"
    local type="${3:-warning}"  # info, warning, error
    
    if [ "$SHOW_NOTIFICATIONS" != "true" ]; then
        return
    fi
    
    # Obtém usuários logados
    local users=($(get_logged_users))
    
    for user in "${users[@]}"; do
        if [ -n "$user" ]; then
            local display=$(get_user_display "$user")
            
            # Mostra modal usando zenity (se disponível)
            if command -v zenity &> /dev/null; then
                sudo -u "$user" DISPLAY="$display" zenity \
                    --$type \
                    --title="$title" \
                    --text="$message" \
                    --width=400 \
                    --timeout=$NOTIFICATION_TIMEOUT 2>/dev/null &
            fi
        fi
    done
}

# Tratamento de sinais
cleanup() {
    log_message "${YELLOW}Encerrando monitoramento...${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Verifica se está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script precisa ser executado como root!${NC}"
    echo "Use: sudo $0"
    exit 1
fi

# Processa argumentos
case "${1:-}" in
    --install)
        install_dependencies
        create_systemd_service
        exit 0
        ;;
    --daemon)
        # Modo daemon (sem interação)
        ;;
    --no-notifications)
        SHOW_NOTIFICATIONS=false
        echo "Notificações visuais desabilitadas"
        ;;
    --help|-h)
        echo "Sistema de Monitoramento Anti-Travamento"
        echo ""
        echo "Uso: $0 [opção]"
        echo ""
        echo "Opções:"
        echo "  --install           Instala dependências e cria serviço systemd"
        echo "  --daemon            Executa em modo daemon"
        echo "  --no-notifications  Desabilita notificações visuais"
        echo "  --help              Mostra esta ajuda"
        echo ""
        echo "Execução normal: sudo $0"
        exit 0
        ;;
esac

# Instala dependências se necessário
install_dependencies

# Cria diretório de log se não existir
mkdir -p "$(dirname "$LOG_FILE")"

# Inicia monitoramento
monitor_system
