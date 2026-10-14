#!/usr/bin/env bash
# Instala Node.js (LTS via nvm), npm, Angular CLI, ferramentas React (Vite) e gh-pages
# Testado para Ubuntu 22.04
set -euo pipefail

NVM_VERSION="v0.40.3"

echo ">> Atualizando pacotes e instalando dependências básicas..."
sudo apt update
sudo apt install -y curl git build-essential ca-certificates

echo ">> Instalando nvm ${NVM_VERSION}..."
if [ ! -d "$HOME/.nvm" ]; then
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

echo ">> Instalando Node.js LTS (inclui npm)..."
nvm install --lts
nvm alias default 'lts/*'
nvm use default

echo ">> Atualizando npm..."
npm install -g npm@latest

echo ">> Instalando ferramentas globais..."
npm install -g \
  @angular/cli \
  gh-pages \
  serve

# React: o create-react-app foi descontinuado; o padrão atual é o Vite,
# que roda via "npm create vite@latest" sem precisar de instalação global.
echo ">> Pré-carregando o criador de projetos Vite (React)..."
npm cache add create-vite@latest >/dev/null 2>&1 || true

# Opcional: GitHub CLI (útil para autenticar e criar repositórios)
if ! command -v gh >/dev/null 2>&1; then
  echo ">> Instalando GitHub CLI (gh)..."
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt update
  sudo apt install -y gh
fi

echo ""
echo "==================== Versões instaladas ===================="
echo "node:        $(node -v)"
echo "npm:         $(npm -v)"
echo "angular-cli: $(ng version 2>/dev/null | grep -i 'Angular CLI' | awk '{print $3}')"
echo "gh-pages:    $(npm ls -g gh-pages --depth=0 2>/dev/null | grep gh-pages | awk -F@ '{print $NF}')"
echo "gh (CLI):    $(gh --version | head -n1)"
echo "============================================================"
echo ""
echo "Pronto! Abra um novo terminal (ou rode: source ~/.bashrc)."
echo ""
echo "Criar projeto React:   npm create vite@latest meu-app -- --template react"
echo "Criar projeto Angular: ng new meu-app"
echo "Publicar no GH Pages:  gh-pages -d dist"
