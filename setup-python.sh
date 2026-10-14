#!/usr/bin/env bash
# Instala a versão estável mais recente do Python via pyenv, sem mexer no
# Python do sistema (o Ubuntu depende do python3 nativo).
# Inclui pip, venv, pipx e uv. Testado para Ubuntu 22.04.
set -euo pipefail

echo ">> Instalando dependências de compilação do Python..."
sudo apt update
sudo apt install -y \
  make build-essential curl git ca-certificates \
  libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev libgdbm-dev uuid-dev

echo ">> Instalando pyenv..."
if [ ! -d "$HOME/.pyenv" ]; then
  curl -fsSL https://pyenv.run | bash
else
  git -C "$HOME/.pyenv" pull --quiet || true
fi

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"

# Adiciona o pyenv ao ~/.bashrc (apenas uma vez)
if ! grep -q 'PYENV_ROOT' "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" <<'EOF'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
EOF
fi

echo ">> Descobrindo a versão estável mais recente do Python..."
PY_VERSION="$(pyenv latest -k 3)"
echo "   Versão escolhida: ${PY_VERSION}"

echo ">> Compilando e instalando Python ${PY_VERSION} (pode levar alguns minutos)..."
pyenv install -s "$PY_VERSION"
pyenv global "$PY_VERSION"
pyenv rehash

echo ">> Atualizando pip, setuptools e wheel..."
python -m pip install --upgrade pip setuptools wheel

echo ">> Instalando pipx (ferramentas de linha de comando isoladas)..."
python -m pip install --upgrade pipx
python -m pipx ensurepath

echo ">> Instalando uv (gerenciador de pacotes e projetos rápido)..."
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

echo ">> Instalando ferramentas de desenvolvimento via pipx..."
python -m pipx install --force ruff
python -m pipx install --force black
python -m pipx install --force ipython

echo ""
echo "==================== Versões instaladas ===================="
echo "python: $(python --version)"
echo "pip:    $(python -m pip --version | awk '{print $2}')"
echo "pipx:   $(python -m pipx --version)"
echo "uv:     $("$HOME/.local/bin/uv" --version 2>/dev/null || uv --version)"
echo "python do sistema (intocado): $(/usr/bin/python3 --version)"
echo "============================================================"
echo ""
echo "Pronto! Abra um novo terminal (ou rode: source ~/.bashrc)."
echo ""
echo "Criar ambiente virtual:  python -m venv .venv && source .venv/bin/activate"
echo "Projeto com uv:          uv init meu-projeto && cd meu-projeto && uv add requests"
echo "Trocar versão:           pyenv install 3.12 && pyenv local 3.12"
