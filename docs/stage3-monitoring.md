# Этап 3. Мониторинг (Prometheus + Alertmanager)

## 1. Цель и роль мониторинга

На третьем этапе развёрнут централизованный мониторинг инфраструктуры на базе Prometheus и Alertmanager.  
Система мониторинга позволяет:

- собирать метрики с ключевых узлов (vm-ca, vm-vpn, vm-backup, vm-monitor);
- отслеживать доступность сервисов и инфраструктуры;
- получать уведомления о сбоях (через Alertmanager).

Мониторинг разворачивается на отдельной ВМ `vm-monitor` и не совмещается с другими ролями.

---

## 2. Инфраструктура и размещение

- Облако: Yandex Cloud.
- ОС: Ubuntu 24.04 LTS.
- Отдельная ВМ `vm-monitor` в той же VPC, где размещены `vm-ca`, `vm-vpn`, `vm-backup`.
- Публичный IP может быть отключён; доступ организуется через VPN или bastion-хост.

Сетевые правила:

- входящие:
  - `9090/tcp` — веб-интерфейс Prometheus (обычно доступен только из внутренней сети);
  - `9093/tcp` — Alertmanager (только из внутренней сети);
  - `9100/tcp` — Node Exporter (для локального мониторинга самой vm-monitor);
- исходящие: разрешён доступ к узлам инфраструктуры для опроса метрик.

---

## 3. Интеграция с предыдущими этапами

Мониторинг опирается на результаты Этапов 1 и 2:

- проверка доступности `vm-ca` и `vm-vpn` по метрикам Node Exporter;
- возможность определить, что VPN-сервер не отвечает или отключён;
- контроль состояния и доступности инфраструктуры бэкапов (Этап 4).

---

## 4. Скрипты автоматизации (scripts/)

Скрипты Stage3 находятся в `scripts/` и устанавливаются в `/usr/local/sbin` при запуске `bootstrap.sh`.

### 4.1. stage3_install_monitoring.sh

Назначение: установка Prometheus, Alertmanager и Node Exporter на `vm-monitor`.

Основные действия:

- устанавливает пакеты `prometheus`, `alertmanager`, `prometheus-node-exporter`;
- открывает порты `9090/tcp`, `9093/tcp`, `9100/tcp` в UFW (если UFW установлен);
- работает идемпотентно.

Запуск через bootstrap:

```bash
cd ~/devops-final-pki-ca/scripts
sudo ./bootstrap.sh stage3
```

---

### 4.2. stage3_configure_prometheus.sh

Назначение: настройка Prometheus, Alertmanager и правил алёртов.

Основные действия:

- создаёт `/etc/prometheus/targets.yml` с примером списка целей (Node Exporter на vm-ca, vm-vpn, vm-backup);
- создаёт файл правил `/etc/prometheus/rules/alerts.yml` с алёртом `InstanceDown`;
- создаёт минимальный конфиг Alertmanager (`/etc/alertmanager/alertmanager.yml`) с заглушкой `null`;
- создаёт `prometheus.yml` (если ещё не существует), подключая файл целей и правила;
- включает и перезапускает сервисы `prometheus`, `alertmanager`, `prometheus-node-exporter`.

После выполнения нужно обновить `/etc/prometheus/targets.yml` под реальные IP-адреса узлов.

---

## 5. Проверка работоспособности Этапа 3

Автоматическая проверка доступна через bootstrap:

```bash
cd ~/devops-final-pki-ca/scripts
sudo ./bootstrap.sh stage3-verify
```

`stage3-verify` проверяет:

- активность сервисов `prometheus`, `alertmanager`, `prometheus-node-exporter`;
- открытые порты `9090`, `9093`, `9100`;
- наличие `/etc/prometheus/targets.yml`.

Минимальная ручная проверка:

- открыть веб-интерфейс Prometheus: `http://<vm-monitor>:9090`;
- убедиться, что таргеты в состоянии `UP` в разделе **Status → Targets**;
- проверить Alertmanager: `http://<vm-monitor>:9093`.

---

## 6. Связь с другими этапами

- Этап 3 использует данные Этапов 1 и 2 (доступность vm-ca/vm-vpn).
- Этап 4 (резервное копирование) включается в мониторинг как отдельная цель.
- Этап 5 (документация) описывает пользовательские и администраторские инструкции.
- Этап 6 (план развития) может включать расширение метрик, интеграцию с Grafana и централизованный алёртинг.