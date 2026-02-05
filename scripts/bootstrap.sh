#!/usr/bin/env bash
set -euo pipefail

# ==========================================================

# DevOps Final Project Bootstrap

# Orchestrates all stages

# ==========================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
echo -e "\n\033[1;34m[BOOTSTRAP]\033[0m $1"
}

fail() {
echo -e "\033[1;31m[ERROR]\033[0m $1"
exit 1
}

require_script() {
[[ -x "$1" ]] || fail "Script not found or not executable: $1"
}

# ==========================================================

# STAGE 1 — CA

# ==========================================================

run_stage1() {
log "Running Stage 1 — CA setup"

require_script "$PROJECT_ROOT/scripts/install_ca.sh"
require_script "$PROJECT_ROOT/scripts/init_ca.sh"

sudo "$PROJECT_ROOT/scripts/install_ca.sh"
sudo "$PROJECT_ROOT/scripts/init_ca.sh"

verify_stage1
}

verify_stage1() {
log "Verifying Stage 1"

[[ -d /etc/pki ]] || fail "/etc/pki missing"
[[ -f /etc/pki/ca.crt ]] || fail "CA certificate missing"
[[ -f /etc/pki/private/ca.key ]] || fail "CA private key missing"

log "Stage 1 verification OK"
}

# ==========================================================

# STAGE 2 — OpenVPN

# ==========================================================

run_stage2() {
log "Running Stage 2 — OpenVPN"

require_script "$PROJECT_ROOT/scripts/stage2_install_openvpn.sh"
require_script "$PROJECT_ROOT/scripts/stage2_configure_server.sh"

sudo "$PROJECT_ROOT/scripts/stage2_install_openvpn.sh"
sudo "$PROJECT_ROOT/scripts/stage2_configure_server.sh"

verify_stage2
}

verify_stage2() {
log "Verifying Stage 2"

dpkg -l | grep -q openvpn || fail "OpenVPN not installed"

systemctl is-active --quiet openvpn-server@server || 
fail "OpenVPN service not active"

ss -lnt '( sport = :1194 )' | grep -q LISTEN || 
fail "Port 1194 not listening"

log "Stage 2 verification OK"
}

# ==========================================================

# STAGE 3 — Monitoring

# ==========================================================

run_stage3() {
log "Running Stage 3 — Monitoring"

require_script "$PROJECT_ROOT/scripts/stage3_install_monitoring.sh"
require_script "$PROJECT_ROOT/scripts/stage3_configure_prometheus.sh"

sudo "$PROJECT_ROOT/scripts/stage3_install_monitoring.sh"
sudo "$PROJECT_ROOT/scripts/stage3_configure_prometheus.sh"

verify_stage3
}

verify_stage3() {
log "Verifying Stage 3"

systemctl is-active --quiet prometheus || 
fail "Prometheus inactive"

systemctl is-active --quiet node_exporter || 
fail "Node Exporter inactive"

ss -lnt '( sport = :9090 )' | grep -q LISTEN || 
fail "Prometheus port closed"

ss -lnt '( sport = :9100 )' | grep -q LISTEN || 
fail "Node exporter port closed"

[[ -f /etc/prometheus/targets.yml ]] || 
fail "targets.yml missing"

log "Stage 3 verification OK"
}

# ==========================================================

# STAGE 4 — Backup

# ==========================================================

run_stage4() {
log "Running Stage 4 — Backup"

require_script "$PROJECT_ROOT/scripts/stage4_setup_backup.sh"

sudo "$PROJECT_ROOT/scripts/stage4_setup_backup.sh"

verify_stage4
}

verify_stage4() {
log "Verifying Stage 4"

systemctl is-enabled --quiet devops-backup.timer || 
fail "Backup timer not enabled"

systemctl list-timers | grep -q devops-backup || 
fail "Backup timer not scheduled"

[[ -d /var/backups/devops ]] || 
fail "Backup directory missing"

ls /var/backups/devops/*.tar.gz >/dev/null 2>&1 || 
fail "No backup archives found"

log "Stage 4 verification OK"
}

# ==========================================================

# MENU

# ==========================================================

usage() {
echo
echo "Usage:"
echo "  $0 stage1"
echo "  $0 stage2"
echo "  $0 stage3"
echo "  $0 stage4"
echo "  $0 all"
echo
}

case "${1:-}" in
stage1) run_stage1 ;;
stage2) run_stage2 ;;
stage3) run_stage3 ;;
stage4) run_stage4 ;;
all)
run_stage1
run_stage2
run_stage3
run_stage4
;;
*)
usage
exit 1
;;
esac