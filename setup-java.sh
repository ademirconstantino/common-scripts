#!/usr/bin/env bash
# Instala OpenJDK 11, 17 e 25 (LTS) via Eclipse Temurin (Adoptium)
# O Ubuntu 22.04 não traz o JDK 25 nos repositórios oficiais, por isso
# usamos o repositório da Adoptium, que tem builds OpenJDK certificadas.
# A versão 25 fica como padrão. Testado para Ubuntu 22.04.
set -euo pipefail

VERSIONS=(11 17 25)
DEFAULT_VERSION=25
ARCH="$(dpkg --print-architecture)"   # amd64 ou arm64

echo ">> Instalando dependências básicas..."
sudo apt update
sudo apt install -y wget apt-transport-https gpg ca-certificates

echo ">> Adicionando o repositório da Adoptium (Eclipse Temurin)..."
sudo mkdir -p -m 755 /etc/apt/keyrings
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
  | gpg --dearmor | sudo tee /etc/apt/keyrings/adoptium.gpg >/dev/null
sudo chmod go+r /etc/apt/keyrings/adoptium.gpg

CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb ${CODENAME} main" \
  | sudo tee /etc/apt/sources.list.d/adoptium.list >/dev/null
sudo apt update

echo ">> Instalando JDKs: ${VERSIONS[*]}..."
for v in "${VERSIONS[@]}"; do
  sudo apt install -y "temurin-${v}-jdk"
done

echo ">> Definindo o JDK ${DEFAULT_VERSION} como padrão do sistema..."
DEFAULT_HOME="/usr/lib/jvm/temurin-${DEFAULT_VERSION}-jdk-${ARCH}"
for tool in java javac jar javadoc jshell keytool; do
  if [ -x "${DEFAULT_HOME}/bin/${tool}" ]; then
    sudo update-alternatives --set "$tool" "${DEFAULT_HOME}/bin/${tool}" 2>/dev/null || true
  fi
done

echo ">> Configurando JAVA_HOME e o comando 'jdk' no ~/.bashrc..."
if ! grep -q '# java-setup' "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" <<'EOF'

# java-setup
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"

# Troca a versão do Java só no terminal atual. Uso: jdk 11 | jdk 17 | jdk 25
jdk() {
  local home
  home="$(ls -d /usr/lib/jvm/temurin-"$1"-jdk-* 2>/dev/null | head -n1)"
  if [ -z "$home" ]; then
    echo "JDK $1 não encontrado. Instalados:"; ls /usr/lib/jvm | grep temurin
    return 1
  fi
  export JAVA_HOME="$home"
  export PATH="$JAVA_HOME/bin:$PATH"
  java -version
}
EOF
fi

echo ""
echo "==================== JDKs instalados ===================="
for v in "${VERSIONS[@]}"; do
  home="/usr/lib/jvm/temurin-${v}-jdk-${ARCH}"
  if [ -x "$home/bin/java" ]; then
    echo "JDK ${v}: $("$home/bin/java" -version 2>&1 | head -n1)"
  else
    echo "JDK ${v}: NÃO encontrado"
  fi
done
echo "Padrão:  $(java -version 2>&1 | head -n1)"
echo "========================================================="
echo ""
echo "Pronto! Abra um novo terminal (ou rode: source ~/.bashrc)."
echo ""
echo "Trocar no terminal atual:   jdk 17"
echo "Trocar o padrão do sistema: sudo update-alternatives --config java"
echo "                            sudo update-alternatives --config javac"
