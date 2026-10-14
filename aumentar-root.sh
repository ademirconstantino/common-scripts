#!/usr/bin/env bash
# aumentar-root.sh — deixa o filesystem raiz (/) com pelo menos N GB livres.
# Fase 1: limpeza segura (imagens k3s/docker, journal, cache de pacotes, snaps antigos).
# Fase 2: se ainda faltar, tenta crescer o root (LVM ou partição comum com espaço livre no disco).
#
# Uso:  sudo bash aumentar-root.sh            # alvo 3 GB, pergunta antes de cada passo
#       sudo bash aumentar-root.sh -g 5       # alvo 5 GB
#       sudo bash aumentar-root.sh -y         # não pergunta (modo automático)
#       sudo bash aumentar-root.sh -d         # só diagnóstico, não altera nada

set -uo pipefail

TARGET_GB=3
ASSUME_YES=0
DIAG_ONLY=0

while getopts "g:yd" opt; do
  case $opt in
    g) TARGET_GB=$OPTARG ;;
    y) ASSUME_YES=1 ;;
    d) DIAG_ONLY=1 ;;
    *) echo "Uso: $0 [-g GB] [-y] [-d]"; exit 1 ;;
  esac
done

[[ $EUID -eq 0 ]] || { echo "Rode como root: sudo bash $0"; exit 1; }

TARGET=$(( TARGET_GB * 1024 * 1024 * 1024 ))

c_info() { echo -e "\e[36m==> $*\e[0m"; }
c_ok()   { echo -e "\e[32m✔ $*\e[0m"; }
c_warn() { echo -e "\e[33m⚠ $*\e[0m"; }
c_err()  { echo -e "\e[31m✘ $*\e[0m"; }

free_bytes() { df -B1 --output=avail / | tail -1 | tr -d ' '; }
human()      { numfmt --to=iec --suffix=B "$1"; }
has()        { command -v "$1" >/dev/null 2>&1; }

confirm() {
  [[ $ASSUME_YES -eq 1 ]] && return 0
  read -rp "    $1 [s/N] " r
  [[ $r =~ ^[sSyY]$ ]]
}

done_if_enough() {
  local f; f=$(free_bytes)
  echo "    Livre agora: $(human "$f")"
  if (( f >= TARGET )); then
    c_ok "Meta atingida: $(human "$f") livres em / (alvo ${TARGET_GB} GB)."
    exit 0
  fi
}

# ---------------------------------------------------------------- diagnóstico
c_info "Diagnóstico"
df -hT /
echo
lsblk -o NAME,SIZE,FSTYPE,TYPE,MOUNTPOINT
echo
has vgs && vgs 2>/dev/null && echo
c_info "Maiores diretórios em / (mesmo filesystem)"
du -xh / --max-depth=2 2>/dev/null | sort -h | tail -15
echo

ROOT_SRC=$(findmnt -no SOURCE /)
ROOT_FS=$(findmnt -no FSTYPE /)
echo "Root: $ROOT_SRC ($ROOT_FS)"
echo "Alvo: ${TARGET_GB} GB livres"
done_if_enough

[[ $DIAG_ONLY -eq 1 ]] && { c_warn "Modo diagnóstico: nada foi alterado."; exit 0; }

# ---------------------------------------------------------------- fase 1: limpeza
c_info "Fase 1 — limpeza"

if has k3s && confirm "Remover imagens não usadas do k3s (crictl rmi --prune)?"; then
  k3s crictl rmi --prune || c_warn "falhou"
  done_if_enough
fi

if has docker && confirm "Limpar Docker (containers parados, imagens e cache não usados)?"; then
  docker system prune -af || c_warn "falhou"
  done_if_enough
fi

if has journalctl && confirm "Reduzir logs do systemd para 200 MB?"; then
  journalctl --vacuum-size=200M
  done_if_enough
fi

if confirm "Limpar cache do gerenciador de pacotes e pacotes órfãos?"; then
  if   has apt-get; then apt-get clean; apt-get -y autoremove --purge
  elif has dnf;     then dnf clean all; dnf -y autoremove
  elif has pacman;  then pacman -Sc --noconfirm
  elif has zypper;  then zypper clean -a
  fi
  done_if_enough
fi

if has snap && confirm "Remover revisões antigas (desativadas) de snaps?"; then
  snap list --all | awk '/disabled/{print $1, $3}' | while read -r n rev; do
    snap remove "$n" --revision="$rev"
  done
  done_if_enough
fi

if confirm "Apagar logs antigos rotacionados em /var/log (*.gz, *.1, *.old)?"; then
  find /var/log -type f \( -name '*.gz' -o -name '*.[0-9]' -o -name '*.old' \) -delete
  done_if_enough
fi

# ---------------------------------------------------------------- fase 2: crescer o root
c_info "Fase 2 — aumentar o filesystem raiz"

NEED=$(( TARGET - $(free_bytes) ))
NEED_MB=$(( NEED / 1024 / 1024 + 100 ))   # +100 MB de folga
echo "    Faltam ~${NEED_MB} MB"

grow_fs() {
  case $ROOT_FS in
    ext2|ext3|ext4) resize2fs "$ROOT_SRC" ;;
    xfs)            xfs_growfs / ;;
    btrfs)          btrfs filesystem resize max / ;;
    *) c_err "Filesystem $ROOT_FS não suportado para redimensionar automaticamente."; return 1 ;;
  esac
}

ensure_growpart() {
  has growpart && return 0
  c_info "Instalando growpart..."
  if   has apt-get; then apt-get install -y cloud-guest-utils
  elif has dnf;     then dnf install -y cloud-utils-growpart
  elif has zypper;  then zypper install -y growpart
  fi
  has growpart
}

# Tenta crescer uma partição até o fim do disco. $1 = /dev/sdXN
grow_partition() {
  local part=$1 name disk num
  name=$(basename "$(readlink -f "$part")")
  disk=$(lsblk -no PKNAME "/dev/$name" | head -1)
  num=$(cat "/sys/class/block/$name/partition" 2>/dev/null)
  [[ -n $disk && -n $num ]] || { c_warn "$part não é uma partição simples."; return 1; }
  ensure_growpart || { c_err "growpart indisponível."; return 1; }
  if ! growpart --dry-run "/dev/$disk" "$num" >/dev/null 2>&1; then
    c_warn "Não há espaço livre após /dev/$name no disco /dev/$disk."
    return 1
  fi
  confirm "Expandir /dev/$name até o fim do disco /dev/$disk?" || return 1
  growpart "/dev/$disk" "$num"
}

if [[ $(lsblk -no TYPE "$ROOT_SRC" 2>/dev/null) == lvm ]]; then
  VG=$(lvs --noheadings -o vg_name "$ROOT_SRC" | tr -d ' ')
  VFREE=$(vgs --noheadings --units b --nosuffix -o vg_free "$VG" | tr -d ' ')
  echo "    LVM: VG=$VG, livre no VG=$(human "$VFREE")"

  if (( VFREE < NEED_MB * 1024 * 1024 )); then
    c_info "Pouco espaço no VG; tentando crescer o(s) PV(s)..."
    for pv in $(pvs --noheadings -o pv_name -S vg_name="$VG" | tr -d ' '); do
      grow_partition "$pv" && pvresize "$pv"
    done
    VFREE=$(vgs --noheadings --units b --nosuffix -o vg_free "$VG" | tr -d ' ')
  fi

  if (( VFREE >= NEED_MB * 1024 * 1024 )); then
    if confirm "Executar lvextend -r -L +${NEED_MB}M $ROOT_SRC?"; then
      lvextend -r -L "+${NEED_MB}M" "$ROOT_SRC"
      done_if_enough
    fi
  else
    c_err "O VG $VG não tem espaço suficiente ($(human "$VFREE"))."
  fi
else
  if grow_partition "$ROOT_SRC"; then
    grow_fs
    done_if_enough
  fi
fi

# ---------------------------------------------------------------- não deu
c_err "Não foi possível chegar a ${TARGET_GB} GB livres automaticamente."
cat <<'EOF'
Próximas opções (manuais):
  • Se for VM: aumente o disco virtual no hypervisor e rode este script de novo.
  • Mova dados grandes para outro disco/partição e monte lá, por exemplo:
      /var/lib/rancher  (k3s)   /var/lib/docker   ~/.m2   ~/.gradle
  • Encolha outra partição (ex.: /home) com GParted a partir de um live USB
    e depois rode este script de novo. Faça backup antes.
EOF
exit 1
