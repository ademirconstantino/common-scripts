#!/usr/bin/env bash
# Corrige os alto-falantes internos do MacBook Pro 2016/2017 (Intel) no Ubuntu 22.04
# Instala o driver snd_hda_macbookpro (codec Cirrus Logic CS8409)
# Projeto: https://github.com/davidjo/snd_hda_macbookpro
#
# Funciona com o kernel HWE 6.8 do 22.04: como não existe "linux-source-6.8.0"
# no repositório do 22.04, o script baixa esse pacote do Ubuntu 24.04 (mesmo
# kernel 6.8) e só extrai o código-fonte para /usr/src — nada do 24.04 é instalado.
#
# Uso:  chmod +x fix-som-macbookpro2017.sh && sudo ./fix-som-macbookpro2017.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Execute com sudo: sudo $0"
  exit 1
fi

UNAME="$(uname -r)"                       # ex: 6.8.0-85-generic
KVER="$(echo "$UNAME" | cut -d- -f1)"     # ex: 6.8.0
ABI="$(echo "$UNAME" | cut -d- -f2)"      # ex: 85
echo "==> Kernel em uso: $UNAME"

echo "==> Verificando o codec de áudio..."
if grep -qs "Cirrus Logic" /proc/asound/card*/codec#* ; then
  grep -hs "Codec:" /proc/asound/card*/codec#* | sed 's/^/    /'
else
  echo "    Aviso: codec Cirrus Logic não detectado. O driver pode não se aplicar a esta máquina."
  read -rp "    Continuar mesmo assim? [s/N] " r
  [[ "${r,,}" == "s" ]] || exit 1
fi

echo "==> Instalando dependências de compilação..."
apt-get update
apt-get install -y build-essential git patch wget bzip2 "linux-headers-$UNAME"

# ---------- Código-fonte do kernel exigido pelo instalador ----------
SRC_TAR="/usr/src/linux-source-$KVER.tar.bz2"
if [[ ! -e "$SRC_TAR" ]]; then
  if apt-get install -y "linux-source-$KVER" 2>/dev/null; then
    echo "    linux-source-$KVER instalado pelo apt."
  else
    echo "==> linux-source-$KVER não existe no 22.04; buscando no repositório do Ubuntu 24.04..."
    POOL="http://archive.ubuntu.com/ubuntu/pool/main/l/linux"
    LIST="$(wget -qO- "$POOL/" | grep -o "linux-source-${KVER}_${KVER}-[0-9]*\.[0-9]*_all\.deb" | sort -uV)"
    if [[ -z "$LIST" ]]; then
      echo "    Não encontrei o pacote linux-source-$KVER em $POOL"
      exit 1
    fi
    # Prefere a mesma revisão do seu kernel; senão, a mais próxima acima; senão, a mais recente
    DEB="$(echo "$LIST" | grep "_${KVER}-${ABI}\." | tail -n1 || true)"
    if [[ -z "$DEB" ]]; then
      DEB="$(echo "$LIST" | awk -F'[-.]' -v a="$ABI" '{ if ($(NF-2)+0 >= a+0) { print; exit } }' || true)"
    fi
    [[ -z "$DEB" ]] && DEB="$(echo "$LIST" | tail -n1)"
    echo "    Usando: $DEB"

    TMP="$(mktemp -d)"
    wget -q --show-progress -O "$TMP/$DEB" "$POOL/$DEB"
    dpkg-deb -x "$TMP/$DEB" "$TMP/x"
    cp "$TMP/x/usr/src/linux-source-$KVER/linux-source-$KVER.tar.bz2" "$SRC_TAR"
    rm -rf "$TMP"
    echo "    Código-fonte copiado para $SRC_TAR"
  fi
fi

# ---------- Driver ----------
WORKDIR="/opt/snd_hda_macbookpro"
echo "==> Baixando o driver em $WORKDIR ..."
if [[ -d "$WORKDIR/.git" ]]; then
  git -C "$WORKDIR" pull --ff-only
else
  rm -rf "$WORKDIR"
  git clone https://github.com/davidjo/snd_hda_macbookpro.git "$WORKDIR"
fi

echo "==> Compilando e instalando o módulo (pode levar alguns minutos)..."
cd "$WORKDIR"
rm -rf build
./install.cirrus.driver.sh

echo
echo "==> Pronto! Reinicie o computador:  sudo reboot"
echo "    Se ainda estiver mudo depois do reboot: abra 'alsamixer', pressione F6,"
echo "    escolha HDA Intel PCH e confira se 'Master'/'Speaker' não estão em MM (mudo)."
echo
echo "    IMPORTANTE: após cada atualização de kernel, rode este script de novo."
