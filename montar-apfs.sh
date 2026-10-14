#!/usr/bin/env bash
# montar-apfs.sh - Monta (somente leitura) particoes APFS no Ubuntu usando apfs-fuse.
#
# Uso:
#   sudo ./montar-apfs.sh                 # instala (se preciso), lista e monta
#   sudo ./montar-apfs.sh /dev/sdb2       # monta a particao indicada
#   sudo ./montar-apfs.sh -v 1 /dev/sdb2  # escolhe o volume dentro do container
#   sudo ./montar-apfs.sh -m /mnt/mac /dev/sdb2   # ponto de montagem customizado
#   sudo ./montar-apfs.sh -u              # desmonta
#
set -euo pipefail

MOUNT_POINT="/mnt/apfs"
VOLUME=""
DEVICE=""
UNMOUNT=0
APFS_GUID="7c3457ef-0000-11aa-aa11-00306543ecac"
SRC_DIR="/opt/apfs-fuse"

verde()   { printf '\e[32m%s\e[0m\n' "$*"; }
amarelo() { printf '\e[33m%s\e[0m\n' "$*"; }
erro()    { printf '\e[31mErro: %s\e[0m\n' "$*" >&2; exit 1; }

uso() {
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while getopts ":m:v:uh" opt; do
  case "$opt" in
    m) MOUNT_POINT="$OPTARG" ;;
    v) VOLUME="$OPTARG" ;;
    u) UNMOUNT=1 ;;
    h) uso ;;
    *) erro "opcao invalida. Use -h para ajuda." ;;
  esac
done
shift $((OPTIND - 1))
DEVICE="${1:-}"

[[ $EUID -eq 0 ]] || erro "execute com sudo: sudo $0 $*"

# ---------- Desmontar ----------
if [[ $UNMOUNT -eq 1 ]]; then
  if mountpoint -q "$MOUNT_POINT"; then
    fusermount3 -u "$MOUNT_POINT" 2>/dev/null || umount "$MOUNT_POINT"
    verde "Desmontado: $MOUNT_POINT"
  else
    amarelo "$MOUNT_POINT nao esta montado."
  fi
  exit 0
fi

# ---------- Instalar apfs-fuse se necessario ----------
if ! command -v apfs-fuse >/dev/null 2>&1; then
  amarelo "apfs-fuse nao encontrado. Instalando dependencias e compilando..."
  apt-get update
  apt-get install -y fuse3 libfuse3-dev bzip2 libbz2-dev cmake g++ git \
                     libattr1-dev zlib1g-dev

  rm -rf "$SRC_DIR"
  git clone --recursive https://github.com/sgan81/apfs-fuse.git "$SRC_DIR"
  mkdir -p "$SRC_DIR/build"
  cd "$SRC_DIR/build"
  cmake ..
  make -j"$(nproc)"
  make install
  cd - >/dev/null
  command -v apfs-fuse >/dev/null 2>&1 || erro "falha ao instalar apfs-fuse."
  verde "apfs-fuse instalado."
fi

# ---------- Escolher a particao ----------
if [[ -z "$DEVICE" ]]; then
  mapfile -t PARTS < <(
    lsblk -rpno NAME,FSTYPE,PARTTYPE | awk -v g="$APFS_GUID" \
      'tolower($2)=="apfs" || tolower($3)==g {print $1}' | sort -u
  )

  if [[ ${#PARTS[@]} -eq 0 ]]; then
    amarelo "Nenhuma particao APFS detectada automaticamente. Discos disponiveis:"
    lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,MODEL
    read -rp "Digite a particao (ex: /dev/sdb2): " DEVICE
  elif [[ ${#PARTS[@]} -eq 1 ]]; then
    DEVICE="${PARTS[0]}"
    verde "Particao APFS encontrada: $DEVICE"
  else
    echo "Particoes APFS encontradas:"
    for i in "${!PARTS[@]}"; do
      size=$(lsblk -dno SIZE "${PARTS[$i]}")
      echo "  [$((i + 1))] ${PARTS[$i]} ($size)"
    done
    read -rp "Escolha o numero: " n
    [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#PARTS[@]} )) || erro "opcao invalida."
    DEVICE="${PARTS[$((n - 1))]}"
  fi
fi

[[ -b "$DEVICE" ]] || erro "$DEVICE nao e um dispositivo de bloco valido."

# ---------- Montar ----------
mkdir -p "$MOUNT_POINT"
if mountpoint -q "$MOUNT_POINT"; then
  erro "$MOUNT_POINT ja esta em uso. Desmonte com: sudo $0 -u"
fi

OPTS=(-o allow_other)
[[ -n "$VOLUME" ]] && OPTS+=(-v "$VOLUME")

echo "Montando $DEVICE em $MOUNT_POINT (somente leitura)..."
echo "(Se o volume for criptografado, a senha sera solicitada.)"
apfs-fuse "${OPTS[@]}" "$DEVICE" "$MOUNT_POINT"

verde "Pronto! Conteudo em: $MOUNT_POINT"
ls "$MOUNT_POINT"
[[ -d "$MOUNT_POINT/root/Users" ]] && echo "Pastas de usuario: $MOUNT_POINT/root/Users"
echo
echo "Para desmontar: sudo $0 -u"
