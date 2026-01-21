#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# DevOps Final Project - Bootstrap Orchestrator
# Поддерживает этапы 1-6 инфраструктуры (CA, VPN, мониторинг, бэкапы, доки)
###############################################################################

usage() {
  cat <<EOF
Использование: $0 <stage>

Доступные режимы:
  stage1         - развернуть и проверить CA (vm-ca)
  stage2         - подготовить VPN-сервер OpenVPN (vm-vpn)
  stage2-verify  - проверить состояние VPN-сервера (vm-vpn)
  stage3         - развернуть Prometheus + Alertmanager (vm-monitor) [TODO]
  stage3-verify  - проверить мониторинг [TODO]
  stage4         - настроить резервное копирование (vm-backup) [TODO]
  stage4-verify  - проверить бэкапы [TODO]
  stage5         - подготовить документацию [TODO]
  stage6         - план развития (roadmap) [TODO]
  all            - последовательно выполнить все этапы [TODO для 2-6]

Примеры:
  # На vm-ca:
  sudo ./bootstrap.sh stage1

  # На vm-vpn:
  sudo ./bootstrap.sh stage2
  sudo ./bootstrap.sh stage2-verify

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

  # Stage3 (TODO)
  # Stage4 (TODO)
  # Stage5 (TODO)
  # Stage6 (TODO)

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
       sudo stage2_create_client_ovpn.sh lient-name>

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
# STAGE 3: Мониторинг (Prometheus + Alertmanager) [TODO]
###############################################################################

run_stage3() {
  log_error "[TODO] Stage3: мониторинг (Prometheus + Alertmanager)"
  echo "[i] Этап 3 находится в разработке. Будет добавлен позже."
  return 0
}

verify_stage3() {
  log_error "[TODO] Stage3: verify"
  echo "[i] Этап 3 находится в разработке."
  return 0
}

###############################################################################
# STAGE 4: Резервное копирование [TODO]
###############################################################################

run_stage4() {
  log_error "[TODO] Stage4: резервное копирование"
  echo "[i] Этап 4 находится в разработке. Будет добавлен позже."
  return 0
}

verify_stage4() {
  log_error "[TODO] Stage4: verify"
  echo "[i] Этап 4 находится в разработке."
  return 0
}

###############################################################################
# STAGE 5: Документация [TODO]
###############################################################################

run_stage5() {
  log_error "[TODO] Stage5: документация"
  echo "[i] Этап 5 находится в разработке. Будет добавлен позже."
  return 0
}

###############################################################################
# STAGE 6: План развития [TODO]
###############################################################################

run_stage6() {
  log_error "[TODO] Stage6: план развития (roadmap)"
  echo "[i] Этап 6 находится в разработке. Будет добавл
