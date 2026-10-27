#!/usr/bin/env bash
# ==============================================================================
# Script: install-smartmontools.sh
# Objetivo: Instalar e configurar o smartmontools no host (ZorinOS / Debian / Ubuntu)
#           para permitir que o QDiskInfo / CrystalDiskInfo acesse dados S.M.A.R.T.
# ==============================================================================

set -euo pipefail

# Cores para feedback no terminal
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem cor

echo -e "${BLUE}=== Instalador de Dependências S.M.A.R.T. (smartmontools) ===${NC}"

# 1. Verificar se o script possui privilégios de administrador
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}[!] Privilégios de root necessários. Elevando permissão via sudo...${NC}"
    exec sudo bash "$0" "$@"
fi

# 2. Identificar a distribuição Linux
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
    echo -e "${GREEN}[+] Distribuição detectada:${NC} ${PRETTY_NAME:-$DISTRO_ID}"
else
    echo -e "${RED}[x] Não foi possível identificar /etc/os-release.${NC}"
    exit 1
fi

# 3. Instalar o pacote smartmontools de acordo com o gerenciador de pacotes
echo -e "${BLUE}[*] Instalando o pacote smartmontools...${NC}"
if [[ "$DISTRO_ID" == "zorin" ]] || [[ "$DISTRO_ID" == "ubuntu" ]] || [[ "$DISTRO_ID" == "debian" ]] || [[ "$DISTRO_LIKE" == *"debian"* ]] || [[ "$DISTRO_LIKE" == *"ubuntu"* ]]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y --no-install-recommends smartmontools policykit-1 pkexec
elif [[ "$DISTRO_ID" == "fedora" ]] || [[ "$DISTRO_LIKE" == *"fedora"* ]] || [[ "$DISTRO_LIKE" == *"rhel"* ]]; then
    dnf install -y smartmontools polkit
elif [[ "$DISTRO_ID" == "arch" ]] || [[ "$DISTRO_LIKE" == *"arch"* ]]; then
    pacman -Sy --noconfirm smartmontools polkit
elif [[ "$DISTRO_ID" == "opensuse"* ]] || [[ "$DISTRO_LIKE" == *"suse"* ]]; then
    zypper --non-interactive in smartmontools polkit
else
    echo -e "${RED}[x] Gerenciador de pacotes não suportado automaticamente.${NC}"
    echo "Instale manualmente o pacote 'smartmontools' no seu sistema."
    exit 1
fi

# 4. Habilitar e iniciar o daemon smartd (se systemd estiver ativo)
if command -v systemctl &>/dev/null && systemctl is-system-running &>/dev/null; then
    echo -e "${BLUE}[*] Ativando serviço de monitoramento em segundo plano (smartd)...${NC}"
    systemctl enable smartd.service 2>/dev/null || true
    systemctl restart smartd.service 2>/dev/null || true
fi

# 5. Validação da instalação e varredura de discos
echo -e "${GREEN}[+] Validação da ferramenta smartctl:${NC}"
smartctl --version | head -n 2

echo -e "\n${BLUE}[*] Escaneando discos físicos disponíveis no sistema:${NC}"
DISKS_FOUND=$(smartctl --scan || true)

if [ -n "$DISKS_FOUND" ]; then
    echo -e "${GREEN}${DISKS_FOUND}${NC}"
else
    echo -e "${YELLOW}[!] Nenhum disco detectado via varredura padrão ou acesso restrito.${NC}"
fi

echo -e "\n${GREEN}================================================================${NC}"
echo -e "${GREEN}Dependência smartmontools instalada e configurada com sucesso!${NC}"
echo -e "Você já pode executar o QDiskInfo (.AppImage) com privilégios de root:"
echo -e "  ${YELLOW}pkexec ./QDiskInfo-x86_64.AppImage${NC}"
echo -e "${GREEN}================================================================${NC}"
