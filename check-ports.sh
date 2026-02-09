#!/bin/bash

# Скрипт для проверки открытых портов на хостах Kubernetes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Порты для проверки
declare -A master_ports=(
    [6443]="Kubernetes API server"
    [2379]="etcd server client API"
    [2380]="etcd peer communication"
    [10250]="Kubelet API"
    [10251]="kube-scheduler"
    [10252]="kube-controller-manager"
)

declare -A worker_ports=(
    [10250]="Kubelet API"
    [10256]="kube-proxy"
)

# Функция для проверки портов
check_ports() {
    local host=$1
    local role=$2
    local -n ports=$3
    
    echo -e "${YELLOW}Проверка портов на $role: $host${NC}"
    
    for port in "${!ports[@]}"; do
        desc="${ports[$port]}"
        timeout 2 bash -c "</dev/tcp/$host/$port" 2>/dev/null && \
            echo -e "${GREEN}✅ Порт $port ($desc) открыт${NC}" || \
            echo -e "${RED}❌ Порт $port ($desc) закрыт${NC}"
    done
    echo ""
}

# Основная функция
main() {
    if [ ! -f "inventory.ini" ]; then
        echo -e "${RED}Ошибка: inventory.ini не найден${NC}"
        exit 1
    fi
    
    # Извлечение IP адресов из inventory
    local masters=$(grep -E '^\s*k8s-master' inventory.ini | awk '{print $NF}' | grep -oP '(?<=ansible_host=)[^ ]*')
    local workers=$(grep -E '^\s*k8s-worker' inventory.ini | awk '{print $NF}' | grep -oP '(?<=ansible_host=)[^ ]*')
    
    if [ -z "$masters" ]; then
        echo -e "${RED}Ошибка: мастер-ноды не найдены в inventory${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}========== Проверка портов Kubernetes ==========${NC}\n"
    
    # Проверка мастер-нод
    for master in $masters; do
        check_ports "$master" "MASTER" master_ports
    done
    
    # Проверка воркер-нод
    for worker in $workers; do
        check_ports "$worker" "WORKER" worker_ports
    done
}

main
