# Установка Kubernetes кластера с помощью Ansible ###########

Данный проект содержит набор Ansible плейбуков для автоматической установки Kubernetes кластера, состоящего из 1 мастер-ноды и 2 воркер-нод.

## Структура проекта

- `inventory.ini` - файл инвентаря, определяющий серверы кластера
- `k8s-install.yml` - установка Docker, kubeadm, kubelet и kubectl
- `prerequisites.yml` - настройка предварительных условий
- `init-master.yml` - инициализация мастер-ноды
- `join-workers.yml` - присоединение воркер-нод к кластеру
- `test-cluster.yml` - проверка работоспособности кластера
- `site.yml` - главный плейбук, объединяющий все шаги
- `README.md` - данный файл документации

## Требования

- 3 сервера Ubuntu (рекомендуется Ubuntu 20.04 или новее)
- Ansible установлен на машине администратора
- Доступ по SSH к серверам с использованием ключей
- Пользователь с sudo правами на целевых серверах
- Открытые порты:
  - 6443 (Kubernetes API server)
  - 2379-2380 (etcd server client API)
  - 10250 (Kubelet API)
  - 10251 (kube-scheduler)
  - 10252 (kube-controller-manager)
  - 30000-32767 (NodePort Services)

## Подготовка

### 1. Настройка SSH доступа

Убедитесь, что у вас есть доступ по SSH к каждому серверу с использованием SSH-ключей. Рекомендуется использовать один и тот же пользовательский аккаунт на всех серверах.

### 2. Настройка файла инвентаря

Откройте файл `inventory.ini` и замените следующие значения:

- `MASTER_SERVER_IP` - IP-адрес вашего сервера, который будет мастер-нодой
- `WORKER1_SERVER_IP` - IP-адрес первого воркер-сервера
- `WORKER2_SERVER_IP` - IP-адрес второго воркер-сервера
- `ansible_user` - имя пользователя, от которого будет производиться подключение
- `ansible_ssh_private_key_file` - путь к вашему приватному SSH-ключу

Пример:
```
[k8s-cluster]
k8s-master ansible_host=192.168.1.10 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
k8s-worker1 ansible_host=192.168.1.11 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
k8s-worker2 ansible_host=192.168.1.12 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[k8s-masters]
k8s-master

[k8s-workers]
k8s-worker1
k8s-worker2
```

## Установка

### 1. Проверка соединения

Перед запуском установки проверьте соединение с серверами:

```bash
ansible -i inventory.ini all -m ping
```

### 2. Запуск установки

Для запуска полной установки выполните команду:

```bash
ansible-playbook -i inventory.ini site.yml
```

Альтернативно, вы можете запустить каждый плейбук по отдельности в следующем порядке:

1. `ansible-playbook -i inventory.ini prerequisites.yml`
2. `ansible-playbook -i inventory.ini k8s-install.yml`
3. `ansible-playbook -i inventory.ini init-master.yml`
4. `ansible-playbook -i inventory.ini join-workers.yml`
5. `ansible-playbook -i inventory.ini test-cluster.yml`

### 3. Проверка установки

После завершения установки вы можете проверить состояние кластера, подключившись к мастер-ноде:

```bash
ssh ubuntu@MASTER_SERVER_IP
kubectl get nodes
```

Вы должны увидеть список из 3 нод, все в состоянии `Ready`.

## Конфигурация

### Версии программного обеспечения

По умолчанию используются следующие версии:

- Docker: 20.10.21
- Kubernetes: 1.28.0

Чтобы изменить версии, отредактируйте переменные в файле `k8s-install.yml`:

```yaml
vars:
  docker_version: '20.10.21'
  kubernetes_version: '1.28.0'
```

### Настройка CNI

По умолчанию используется Flannel CNI. Если вы хотите использовать другую реализацию CNI (например, Calico), отредактируйте файл `init-master.yml`, заменив URL для установки CNI.

### Разрешение использования мастера как рабочей ноды

В текущей конфигурации плейбук позволяет запускать поды на мастер-ноде (удаляет тейнт `node-role.kubernetes.io/control-plane-`). Это может быть полезно для тестовых сред, но не рекомендуется для продакшена.

## Устранение неполадок

### Проблемы с подключением

Если возникают проблемы с подключением к серверам, проверьте:

- Правильность IP-адресов в файле инвентаря
- Наличие SSH-ключа и права на него (должны быть 600)
- Правила брандмауэра, разрешающие SSH-подключения
- Доступность портов, необходимых для Kubernetes

### Проблемы с установкой Kubernetes

Если установка не завершается успешно:

1. Проверьте логи выполнения Ansible
2. Убедитесь, что все серверы соответствуют требованиям
3. Проверьте, что на серверах отключен swap
4. Убедитесь, что все системные требования Kubernetes выполнены
5. Проверьте, что на серверах нет других контейнерных решений (Docker, containerd, Podman) с конфликтующими настройками
6. Убедитесь, что на серверах отсутствуют остаточные файлы от предыдущих установок Kubernetes

### Сброс кластера

Если вам нужно сбросить кластер, выполните на каждой ноде:

```bash
sudo kubeadm reset
sudo systemctl restart kubelet
sudo systemctl restart docker
```

Затем удалите конфигурационные файлы:

```bash
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/etcd/
sudo rm -rf /var/lib/kubelet/
sudo rm -rf /var/lib/docker/
```

И повторите процесс установки.

## Безопасность

- Храните файлы инвентаря и конфигурации в безопасном месте
- Не храните SSH-ключи в открытом виде
- Регулярно обновляйте версии Kubernetes и компонентов
- Ограничьте доступ к API серверу в продакшене
- Используйте RBAC для управления доступом
- Регулярно сканируйте уязвимости в образах контейнеров

## Полезные команды

- Просмотр всех нод: `kubectl get nodes`
- Просмотр всех подов: `kubectl get pods --all-namespaces`
- Просмотр логов ноды: `kubectl describe node NODE_NAME`
- Просмотр системных подов: `kubectl get pods -n kube-system`
- Получение токена для присоединения новых нод: `kubeadm token create --print-join-command`
- Проверка статуса кластера: `kubectl cluster-info`

## Архитектура установки

Процесс установки включает в себя следующие этапы:

1. **prerequisites.yml**: Подготовка системы (отключение swap, настройка сетевых параметров)
2. **k8s-install.yml**: Установка Docker и компонентов Kubernetes (kubeadm, kubelet, kubectl)
3. **init-master.yml**: Инициализация мастер-ноды и установка CNI
4. **join-workers.yml**: Присоединение воркер-нод к кластеру
5. **test-cluster.yml**: Проверка работоспособности кластера

## Лицензия

Этот проект распространяется по лицензии MIT.