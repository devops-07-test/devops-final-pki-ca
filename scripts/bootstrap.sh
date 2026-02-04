#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# DevOps Final Project - Bootstrap Orchestrator
# Поддерживает этапы 1-4 инфраструктуры (CA, VPN, мониторинг, бэкапы)
# Этапы 5 (документация) и 6 (план развития) являются отдельными документами.
###############################################################################

usage() {
  cat <<EOF
Использование: $0 <stage>

Доступные режимы:
  stage1         - развернуть и проверить CA (vm-ca)
  stage2         - подготовить VPN-сервер OpenVPN (vm-vpn)
  stage2-verify  - проверить состояние VPN-сервера (vm-vpn)
  stage3         - развернуть мониторинг (vm-monitor)
  stage3-verify  - проверить мониторинг
  stage4         - настроить резервное копирование (vm-backup)
  stage4-verify  - проверить бэкапы
  all            - последовательно выполнить этапы 1-4 [ВНИМАНИЕ: Используйте с осторожностью]

Примеры:
  # На vm-ca:
  sudo ./bootstrap.sh stage1

  # На vm-vpn:
  sudo ./bootstrap.sh stage2
  sudo ./bootstrap.sh stage2-verify

  # На vm-monitor:
  sudo ./bootstrap.sh stage3
  sudo ./bootstrap.sh stage3-verify

  # На vm-backup:
  sudo ./bootstrap.sh stage4
  sudo ./bootstrap.sh stage4-verify

Все режимы требуют root-доступа.
EOF
  exit 1
}

# Проверка прав
[[ "$(id -u)" -eq 0 ]] || { echo "[!] Запусти от root: sudo $0 ..."; exit 1; }

# Проверка аргумента
[[ $# -eq 1 ]] || usage

MODE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

###############################################################################
# Вспомогательные функции
###############################################################################

log_info() {
  echo "[*] $*"
}

log_error() {
  echo "[!] $*" >&2
}

log_success() {
  echo "[+] $*"
}

die() {
  log_error "$*"
  exit 1
}

###############################################################################
# Установка скриптов в /usr/local/sbin
###############################################################################

install_scripts_to_path() {
  log_info "Установка скриптов в /usr/local/sbin..."

  # Создаем целевую директорию, если её нет
  mkdir -p /usr/local/sbin

  # Stage1
  [[ -f "$SCRIPT_DIR/install_ca.sh" ]] && \
    install -m 0755 "$SCRIPT_DIR/install_ca.sh" /usr/local/sbin/install_ca.sh
  [[ -f "$SCRIPT_DIR/init_ca.sh" ]] && \
    install -m 0755 "$SCRIPT_DIR/init_ca.sh" /usr/local/sbin/init_ca.sh
  [[ -f "$SCRIPT_DIR/sign_csr.sh" ]] && \
    install -m 0755 "$SCRIPT_DIR/sign_csr.sh" /usr/local/sbin/sign_csr.sh
  [[ -f "$SCRIPT_DIR/revoke_cert.sh" ]] && \
    install -m 0755 "$SCRIPT_DIR/revoke_cert.sh" /usr/local/sbin/revoke_cert.sh

  # Stage2
  [[ -f "$SCRIPT_DIR/stage2_install_openvpn.sh" ]] && \
    install -m 0755 "$SCRIPT_DIR/stage2_install_openvpn.sh" /usr/local/sbin/stage2_install_openvpn.sh
  [[ -f "$SCRIPT_DIR/stage2_request_server_csr.sh" ]] && \
    install -m 0755 "$SCRIPT_DIR/stage2_request_server_csr.sh" /usr/local/sbin/stage2_request_server_csr.sh
  [[ -f "$SCRIPT_DIR/stage2_fetch_signed_cert.sh" ]] && \
    install -m 0755 "$SCRIPT_DIR/stage2_fetch_signed_cert.sh" /usr/local/sbin/stage2_fetch_signed_cert.sh
  [[ -f "$SCRIPT_DIR/stage2_configure_openvpn.sh" ]] && \
    install -m 0755 "$SCRIPT_DIR/stage2_configure_openvpn.sh" /usr/local/sbin/stage2_configure_openvpn.sh
  [[ -f "$SCRIPT_DIR/stage2_create_client_ovpn.sh" ]] && \
    install -m 0755 "$SCRIPT_DIR/stage2_create_client_ovpn.sh" /usr/local/sbin/stage2_create_client_ovpn.sh

  # Stage3
  [[ -f "$SCRIPT_DIR/stage3_install_monitoring.sh" ]] && \
    install -m 0755 "$SCRIPT_DIR/stage3_install_monitoring.sh" /usr/local/sbin/stage3_install_monitoring.sh
  [[ -f "$SCRIPT_DIR/stage3_configure_prometheus.sh" ]] && \
    install -m 0755 "$SCRIPT_DIR/stage3_configure_prometheus.sh" /usr/local/sbin/stage3_configure_prometheus.sh

  # Stage4
  [[ -f "$SCRIPT_DIR/stage4_run_backup.sh" ]] && \
    install -m 0755 "$SCRIPT_DIR/stage4_run_backup.sh" /usr/local/sbin/stage4_run_backup.sh
  [[ -f "$SCRIPT_DIR/stage4_configure_backup.sh" ]] && \
    install -m 0755 "$SCRIPT_DIR/stage4_configure_backup.sh" /usr/local/sbin/stage4_configure_backup.sh

  log_success "Скрипты установлены."
}

###############################################################################
# STAGE 1: CA (Удостоверяющий центр)
###############################################################################

run_init_ca_with_retry() {
  local attempts=0
  local max_attempts=3

  while true; do
    attempts=$((attempts + 1))

    log_info "Stage1: CA init (попытка $attempts/$max_attempts)"
    echo "[i] Сейчас Easy-RSA запросит пароль ключа CA. Пароль обязателен."

    set +e
    /usr/local/sbin/init_ca.sh
    rc=$?
    set -e

    if [[ $rc -eq 0 ]]; then
      return 0
    fi

    echo
    log_error "Ошибка при создании Root CA (код: $rc)."
    log_error "Пароль для ключа CA обязателен — без него продолжить нельзя."
    echo "[i] Если ошибся при вводе пароля/подтверждении или CN — просто повтори."
    echo

    if [[ $attempts -ge $max_attempts ]]; then
      log_error "Достигнут лимит попыток ($max_attempts). Завершаю."
      return 1
    fi

    read -r -p "Повторить ввод пароля и продолжить? [y/N]: " ans
    case "${ans:-N}" in
      y|Y|yes|YES) ;;
      *) log_error "Остановлено пользователем."; return 1 ;;
    esac
  done
}

verify_stage1() {
  log_info "Stage1: verify"

  local PKI_BASE="/etc/pki"
  local PKI_DIR="$PKI_BASE/pki"

  # 1. Структура PKI
  [[ -d "$PKI_DIR" ]] || { log_error "FAIL: нет каталога $PKI_DIR"; return 1; }
  [[ -f "$PKI_DIR/ca.crt" ]] || { log_error "FAIL: нет $PKI_DIR/ca.crt"; return 1; }
  [[ -f "$PKI_DIR/private/ca.key" ]] || { log_error "FAIL: нет $PKI_DIR/private/ca.key"; return 1; }

  # 2. Права на ключ
  local perms
  perms="$(stat -c '%a' "$PKI_DIR/private/ca.key")"
  if [[ "$perms" != "600" && "$perms" != "400" ]]; then
    log_error "FAIL: права на ca.key должны быть 600 (или строже), сейчас: $perms"
    return 1
  fi

  # 3. Проверка сертификата
  if ! openssl x509 -in "$PKI_DIR/ca.crt" -noout -subject -issuer -dates >/dev/null 2>&1; then
    log_error "FAIL: ca.crt не читается openssl"
    return 1
  fi

  # 4. UFW должен быть активен
  if ! ufw status | grep -q "Status: active"; then
    log_error "FAIL: UFW не активен (ожидалось active)"
    return 1
  fi

  log_success "Stage1 verify: OK"
}

run_stage1() {
  log_info "Stage1: CA install"
  /usr/local/sbin/install_ca.sh

  log_info "Stage1: CA init"
  run_init_ca_with_retry

  verify_stage1
  log_success "Stage1 completed"
}

###############################################################################
# STAGE 2: VPN (OpenVPN)
###############################################################################

run_stage2() {
  log_info "Stage2: VPN install & base configure (vm-vpn)"

  if ! command -v openvpn >/dev/null 2>&1; then
    log_info "OpenVPN не найден, запускаю stage2_install_openvpn.sh..."
    /usr/local/sbin/stage2_install_openvpn.sh
  else
    log_info "OpenVPN уже установлен, пропускаю stage2_install_openvpn.sh."
  fi

  cat <<'EOF'

[i] Дальнейшие шаги Stage2 (выполняются администратором вручную):

  1) На vm-vpn:
       sudo stage2_request_server_csr.sh
     -> будет создан CSR и приватный ключ сервера.

  2) Передать CSR на vm-ca и там выполнить:
       sudo sign_csr.sh server <путь_к_csr>
     -> CA подпишет CSR и создаст server.crt.

  3) Вернуть server.crt и ca.crt на vm-vpn в каталог /root/<name>-signed.

  4) На vm-vpn:
       sudo stage2_fetch_signed_cert.sh <name>
       sudo stage2_configure_openvpn.sh

  5) (Опционально) На vm-vpn создать клиентский профиль:
       sudo stage2_create_client_ovpn.sh client-name>

После выполнения шагов можно запустить:
  sudo ./bootstrap.sh stage2-verify

EOF
}

verify_stage2() {
  log_info "Stage2: verify (vm-vpn)"

  if ! command -v openvpn >/dev/null 2>&1; then
    log_error "FAIL: openvpn не установлен."
    return 1
  fi

  local PKI_DIR="/etc/openvpn/pki"
  [[ -f "$PKI_DIR/server.crt" ]] || { log_error "FAIL: нет $PKI_DIR/server.crt"; return 1; }
  [[ -f "$PKI_DIR/ca.crt"     ]] || { log_error "FAIL: нет $PKI_DIR/ca.crt"; return 1; }

  if ! ss -lun | grep -q ":1194 "; then
    log_error "FAIL: OpenVPN не слушает 1194/udp."
    return 1
  fi

  local fwd
  fwd="$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo 0)"
  if [[ "$fwd" -ne 1 ]]; then
    log_error "FAIL: net.ipv4.ip_forward != 1"
    return 1
  fi

  log_success "Stage2 verify: OK (серверная часть)."
  echo "[i] Для полной проверки нужно подключиться клиентом и проверить доступ во внутреннюю сеть."
}

###############################################################################
# STAGE 3: Мониторинг (Prometheus + Alertmanager)
###############################################################################

run_stage3() {
  log_info "Stage3: развертывание мониторинга (Prometheus + Alertmanager)"

  if ! command -v prometheus >/dev/null 2>&1; then
    log_info "Prometheus не найден, запускаю stage3_install_monitoring.sh..."
    /usr/local/sbin/stage3_install_monitoring.sh
  else
    log_info "Prometheus уже установлен, пропускаю stage3_install_monitoring.sh."
  fi

  log_info "Stage3: конфигурация Prometheus и Alertmanager"
  /usr/local/sbin/stage3_configure_prometheus.sh

  cat <<'EOF'

[i] Следующие шаги:
  1) Обнови /etc/prometheus/targets.yml (IP-адреса vm-ca/vm-vpn/vm-backup).
  2) При необходимости настрой alertmanager.yml под реальные каналы уведомлений.
  3) Проверь доступность веб-интерфейса Prometheus (http://<monitor>:9090).

После выполнения шагов можно запустить:
  sudo ./bootstrap.sh stage3-verify

EOF
}

verify_stage3() {
  log_info "Stage3: проверка мониторинга"

  for svc in prometheus alertmanager prometheus-node-exporter; do
    if ! systemctl is-active --quiet "$svc"; then
      log_error "FAIL: сервис $svc не активен"
      return 1
    fi
  done

  if ! ss -lnt | grep -q ":9090 "; then
    log_error "FAIL: Prometheus не слушает 9090/tcp."
    return 1
  fi
  if ! ss -lnt | grep -q ":9093 "; then
    log_error "FAIL: Alertmanager не слушает 9093/tcp."
    return 1
  fi
  if ! ss -lnt | grep -q ":9100 "; then
    log_error "FAIL: Node Exporter не слушает 9100/tcp."
    return 1
  fi

  if [[ ! -f /etc/prometheus/targets.yml ]]; then
    log_error "FAIL: отсутствует /etc/prometheus/targets.yml"
    return 1
  fi

  log_success "Stage3 verify: OK"
}

###############################################################################
# STAGE 4: Резервное копирование
###############################################################################

run_stage4() {
  log_info "Stage4: настройка резервного копирования"
  /usr/local/sbin/stage4_configure_backup.sh

  cat <<'EOF'

[i] Бэкапы выполняются таймером systemd (devops-backup.timer).
    Для ручного запуска:
      sudo /usr/local/sbin/stage4_run_backup.sh

После выполнения шагов можно запустить:
  sudo ./bootstrap.sh stage4-verify

EOF
}

verify_stage4() {
  log_info "Stage4: проверка бэкапов"

  if ! systemctl is-active --quiet devops-backup.timer; then
    log_error "FAIL: таймер devops-backup.timer не активен"
    return 1
  fi

  if ! ls -1 /var/backups/devops-final/devops-backup-*.tar.gz >/dev/null 2>&1; then
    log_error "FAIL: нет бэкапов в /var/backups/devops-final"
    return 1
  fi

  log_success "Stage4 verify: OK"
}

###############################################################################
# ОСНОВНАЯ ЛОГИКА ЗАПУСКА
###############################################################################

# Первым делом устанавливаем скрипты в PATH
install_scripts_to_path

case "$MODE" in
  stage1)
    run_stage1
    ;;
  stage2)
    run_stage2
    ;;
  stage2-verify)
    verify_stage2
    ;;
  stage3)
    run_stage3
    ;;
  stage3-verify)
    verify_stage3
    ;;
  stage4)
    run_stage4
    ;;
  stage4-verify)
    verify_stage4
    ;;
  all)
    log_info "Последовательно выполняю все этапы (1-4)..."
    run_stage1
    run_stage2
    run_stage3
    run_stage4
    log_success "Все этапы (1-4) выполнены."
    ;;
  *)
    log_error "Неизвестный режим: $MODE"
    usage
    ;;
esac
