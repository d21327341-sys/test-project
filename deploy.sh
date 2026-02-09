#!/bin/bash

# Скрипт для деплоя Kubernetes кластера
# Использование: ./deploy.sh [all|pre-checks|install|test]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функции
print_header() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

print_error() {
    echo -e "${RED}❌ Ошибка: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Проверка предварительных условий
check_prerequisites() {
    print_header "Проверка предварительных условий"
    
    if ! command -v ansible &> /dev/null; then
        print_error "Ansible не установлен"
        exit 1
    fi
    print_success "Ansible установлен: $(ansible --version | head -n1)"
    
    if ! command -v ansible-playbook &> /dev/null; then
        print_error "ansible-playbook не найден"
        exit 1
    fi
    
    if [ ! -f "inventory.ini" ]; then
        print_error "Файл inventory.ini не найден"
        exit 1
    fi
    print_success "inventory.ini найден"
    
    if [ ! -f "group_vars/all.yml" ]; then
        print_warning "Файл group_vars/all.yml не найден, создаю..."
        mkdir -p group_vars
    fi
}

# Проверка подключения
check_connectivity() {
    print_header "Проверка подключения к хостам"
    
    ansible -i inventory.ini all -m ping || {
        print_error "Не удается подключиться к хостам"
        exit 1
    }
    print_success "Все хосты доступны"
}

# Запуск pre-checks
run_pre_checks() {
    print_header "Запуск предварительных проверок"
    
    ansible-playbook -i inventory.ini pre-checks.yml || {
        print_error "Предварительные проверки не прошли"
        exit 1
    }
    print_success "Предварительные проверки пройдены"
}

# Полная установка
run_full_install() {
    print_header "Запуск полной установки Kubernetes кластера"
    
    ansible-playbook -i inventory.ini site.yml \
        --extra-vars "ansible_become_pass=''" \
        -vv || {
        print_error "Установка завершилась с ошибкой"
        exit 1
    }
    print_success "Kubernetes кластер успешно установлен"
}

# Проверка кластера
test_cluster() {
    print_header "Тестирование кластера"
    
    ansible-playbook -i inventory.ini test-cluster.yml || {
        print_error "Тестирование кластера не пройдено"
        exit 1
    }
    print_success "Тестирование кластера завершено"
}

# Основное меню
main() {
    local action="${1:-all}"
    
    case "$action" in
        all)
            check_prerequisites
            check_connectivity
            run_pre_checks
            run_full_install
            test_cluster
            ;;
        pre-checks)
            check_prerequisites
            check_connectivity
            run_pre_checks
            ;;
        install)
            check_prerequisites
            check_connectivity
            run_full_install
            ;;
        test)
            check_prerequisites
            test_cluster
            ;;
        *)
            echo "Использование: $0 [all|pre-checks|install|test]"
            exit 1
            ;;
    esac
}

main "$@"
