#!/usr/bin/env bash
# ==============================================================================
# Script:      check-wsl-el.sh
# Descrição:   Checagem final (somente leitura) para instâncias Enterprise Linux
#              no WSL 2 (CentOS Stream 10, Amazon Linux 2023 e AL2027 Preview).
#              Valida PID 1 (systemd), /etc/fstab, montagem de /mnt/c, usuário,
#              grupo wheel, /etc/wsl.conf e serviço OpenSSH Server.
# Autor:       Alex Luiz Rabelo
# Uso:         bash check-wsl-el.sh [usuario] [porta_ssh]
# ==============================================================================

set -euo pipefail

readonly TARGET_USER="${1:-${USER:-labuser}}"
readonly EXPECTED_PORT="${2:-}"
PASS=0
FAIL=0

ok()   { echo -e "\e[1;32m[OK]\e[0m   $*"; PASS=$((PASS + 1)); }
fail() { echo -e "\e[1;31m[FAIL]\e[0m $*"; FAIL=$((FAIL + 1)); }
info() { echo -e "\e[1;34m[INFO]\e[0m $*"; }

info "Iniciando checagem final do ambiente WSL 2..."

# 1. Identificação do SO
if [[ -f /etc/os-release ]]; then
    pretty=$(awk -F= '/^PRETTY_NAME=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    ok "Sistema identificado: ${pretty}"
else
    fail "/etc/os-release não encontrado"
fi

# 2. /etc/fstab e ponto de montagem /mnt/c
if [[ -f /etc/fstab ]]; then
    ok "/etc/fstab presente"
else
    fail "/etc/fstab ausente (pode causar erro no mount -a)"
fi

if mountpoint -q /mnt/c; then
    ok "/mnt/c montado"
else
    fail "/mnt/c não está montado"
fi

# 3. systemd como PID 1
pid1=$(ps -p 1 -o comm= 2>/dev/null || true)
if [[ "${pid1}" == "systemd" ]]; then
    ok "PID 1 é systemd"
else
    fail "PID 1 é '${pid1:-desconhecido}' (esperado: systemd — rode 'wsl --terminate <distro>')"
fi

# 4. Usuário padrão e grupo wheel
if id "${TARGET_USER}" &>/dev/null; then
    if id -nG "${TARGET_USER}" | grep -qw "wheel"; then
        ok "Usuário '${TARGET_USER}' existe e pertence ao grupo 'wheel'"
    else
        fail "Usuário '${TARGET_USER}' não pertence ao grupo 'wheel'"
    fi
else
    fail "Usuário '${TARGET_USER}' não existe"
fi

# 5. /etc/wsl.conf e hostname
if [[ -f /etc/wsl.conf ]] && grep -q "systemd=true" /etc/wsl.conf; then
    ok "/etc/wsl.conf configurado com systemd=true (hostname: $(hostname))"
else
    fail "/etc/wsl.conf ausente ou sem systemd=true"
fi

# 6. OpenSSH Server
if command -v sshd >/dev/null 2>&1; then
    if systemctl is-active --quiet sshd 2>/dev/null; then
        ok "Serviço sshd ativo"
    else
        fail "Serviço sshd não está ativo"
    fi
    if [[ -n "${EXPECTED_PORT}" ]]; then
        if ss -tln 2>/dev/null | grep -q ":${EXPECTED_PORT} "; then
            ok "sshd escutando na porta ${EXPECTED_PORT}"
        else
            fail "sshd não está escutando na porta ${EXPECTED_PORT}"
        fi
    fi
else
    fail "OpenSSH Server (sshd) não encontrado"
fi

echo ""
echo "Resumo: ${PASS} OK | ${FAIL} falha(s)"
[[ ${FAIL} -eq 0 ]]
