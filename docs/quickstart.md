# Полная инструкция по развёртыванию проекта (для новичка)

Данная инструкция предназначена для пользователей без опыта DevOps или системного администрирования.
Следуя шагам ниже, можно развернуть инфраструктуру проекта целиком:

* Удостоверяющий центр (CA / PKI)
* VPN-сервер (OpenVPN)
* Мониторинг (Prometheus + Alertmanager)
* Система резервного копирования

Инструкция построена так, чтобы каждый шаг можно было выполнить последовательно.

---

# 0. Что нужно заранее

## Обязательное

1️⃣ Аккаунт в облаке (Yandex Cloud или аналог)

2️⃣ Базовые навыки:

* открыть веб-консоль облака
* подключиться к серверу по SSH
* копировать команды в терминал

3️⃣ На локальном компьютере должны быть установлены:

### Linux / macOS

```bash
sudo apt install git openssh-client
```

### Windows

Установить:

* Git
* PuTTY или использовать WSL

---

# 1. Создание виртуальных машин

Создаём 4 виртуальные машины Ubuntu 24.04:

| Имя        | Назначение           |
| ---------- | -------------------- |
| vm-ca      | Удостоверяющий центр |
| vm-vpn     | VPN сервер           |
| vm-monitor | Мониторинг           |
| vm-backup  | Бэкапы               |

## Минимальные требования

* 2 CPU
* 2 GB RAM
* 20 GB диск
* одна VPC сеть (пример `10.10.0.0/24`)

## Открытые порты

### vm-ca

* 22/tcp

### vm-vpn

* 22/tcp
* 1194/udp

### vm-monitor

* 22/tcp
* 9090/tcp
* 9093/tcp

### vm-backup

* 22/tcp

---

# 2. Подготовка репозитория

На локальной машине:

```bash
git clone https://github.com/devops-07-test/devops-final-pki-ca.git
cd devops-final-pki-ca
```

---

# 3. Этап 1 — Развёртывание CA

## Копирование файлов

```bash
scp artifacts/devops-ca-tools_1.0-1_all.deb user@IP_VM_CA:~
scp -r devops-final-pki-ca user@IP_VM_CA:~
```

## Подключение

```bash
ssh user@IP_VM_CA
```

## Установка

```bash
sudo apt update
sudo apt install -y easy-rsa openssl ufw bash
sudo dpkg -i devops-ca-tools_1.0-1_all.deb
```

## Запуск bootstrap

```bash
cd ~/devops-final-pki-ca/scripts
chmod +x bootstrap.sh
sudo ./bootstrap.sh stage1
```

Введите пароль CA при запросе.

## Проверка

```bash
sudo ./bootstrap.sh stage1
```

Ожидаемый результат:

```
Stage1 verify: OK
Stage1 completed
```

CA готов.

---

# 4. Этап 2 — Развёртывание VPN

## Копирование репозитория

```bash
scp -r devops-final-pki-ca user@IP_VM_VPN:~
```

## Подключение

```bash
ssh user@IP_VM_VPN
```

## Установка

```bash
cd ~/devops-final-pki-ca/scripts
chmod +x bootstrap.sh
sudo ./bootstrap.sh stage2
```

## Генерация CSR

```bash
sudo stage2_request_server_csr.sh
```

## Передача CSR на CA

```bash
scp vpn-server.csr user@IP_VM_CA:~
```

## Подпись

На vm-ca:

```bash
sudo sign_csr.sh server ~/vpn-server.csr
```

## Возврат сертификатов

Передать на vm-vpn:

* server.crt
* ca.crt

В каталог:

```
/root/vpn-server-signed
```

## Установка сертификатов

```bash
sudo stage2_fetch_signed_cert.sh vpn-server
sudo stage2_configure_openvpn.sh
```

## Проверка

```bash
sudo ./bootstrap.sh stage2-verify
```

Ожидается:

```
Stage2 verify: OK
```

---

# 5. Этап 3 — Мониторинг

Подключиться к vm-monitor:

```bash
scp -r devops-final-pki-ca user@IP_VM_MONITOR:~
ssh user@IP_VM_MONITOR
```

Запуск:

```bash
cd ~/devops-final-pki-ca/scripts
sudo ./bootstrap.sh stage3
```

Добавить цели мониторинга:

```bash
sudo nano /etc/prometheus/targets.yml
```

Указать IP остальных машин.

Проверка:

```bash
sudo ./bootstrap.sh stage3-verify
```

Интерфейс:

```
http://IP_VM_MONITOR:9090
```

---

# 6. Этап 4 — Бэкапы

Подключиться к vm-backup:

```bash
scp -r devops-final-pki-ca user@IP_VM_BACKUP:~
ssh user@IP_VM_BACKUP
```

Запуск:

```bash
cd ~/devops-final-pki-ca/scripts
sudo ./bootstrap.sh stage4
```

Ручной запуск тестового бэкапа:

```bash
sudo /usr/local/sbin/stage4_run_backup.sh
```

Проверка:

```bash
sudo ./bootstrap.sh stage4-verify
```

---

# 7. Проверка итоговой инфраструктуры

Убедиться:

* CA создаёт сертификаты
* VPN запускается
* Prometheus собирает метрики
* Создаются архивы бэкапов

---

# 8. Типичные ошибки новичков

### Не работает SSH

Проверь security group

### Bootstrap не запускается

```
chmod +x bootstrap.sh
```

### VPN verify FAIL

Проверь:

* сертификаты
* порт 1194
* IP forwarding

### Monitoring FAIL

Проверь:

```
systemctl status prometheus
```

---

# Заключение

Следуя данной инструкции, пользователь без опыта может развернуть полноценную инфраструктуру:

* защищённый доступ через VPN
* централизованную PKI
* систему мониторинга
* автоматические резервные копии

Проект демонстрирует базовые практики DevOps-развёртывания и может служить стартовой точкой для дальнейшего развития.