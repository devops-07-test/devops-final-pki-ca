#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Использование: $0 stage1|all"
  exit 1
}

[[ "$(id -u)" -eq 0 ]] || { echo "Запусти от root: sudo $0 ..."; exit 1; }
[[ $# -eq 1 ]] || usage

MODE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_scripts_to_path() {
  install -m 0755 "$SCRIPT_DIR/install_ca.sh" /usr/local/sbin/install_ca.sh
  install -m 0755 "$SCRIPT_DIR/init_ca.sh" /usr/local/sbin/init_ca.sh
  install -m 0755 "$SCRIPT_DIR/sign_csr.sh" /usr/local/sbin/sign_csr.sh
  install -m 0755 "$SCRIPT_DIR/revoke_cert.sh" /usr/local/sbin/revoke_cert.sh
}

run_stage1() {
  echo "[*] Stage1: CA install"
  /usr/local/sbin/install_ca.sh
  echo "[*] Stage1: CA init"
  /usr/local/sbin/init_ca.sh
  echo "[+] Stage1 completed"
}

echo "[*] Installing scripts to /usr/local/sbin ..."
install_scripts_to_path

case "$MODE" in
  stage1) run_stage1 ;;
  all)
    run_stage1
    echo "[!] Этапы 2–6 пока не реализованы: будут добавлены последовательно по брифу."
    ;;
  *) usage ;;
esac
