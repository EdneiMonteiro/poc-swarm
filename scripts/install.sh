#!/bin/bash
# install.sh
# Instala a skill poc-swarm no Copilot CLI (Linux/macOS) criando um symlink:
#   ~/.copilot/skills/poc-swarm  ->  <raiz deste repo>
#
# Uso:
#   ./scripts/install.sh
#   ./scripts/install.sh --with-tools   # tenta instalar tb o toolchain de validação/deploy
set -e

WITH_TOOLS=0
for arg in "$@"; do
  case "$arg" in
    --with-tools) WITH_TOOLS=1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$HOME/.copilot/skills"
LINK_PATH="$SKILLS_DIR/poc-swarm"

if [ ! -f "$REPO_ROOT/SKILL.md" ]; then
  echo "SKILL.md não encontrado em $REPO_ROOT — rode este script de dentro do repo poc-swarm." >&2
  exit 1
fi

echo "🛠️🐝 Instalando skill poc-swarm"
echo "   repo:  $REPO_ROOT"
echo "   link:  $LINK_PATH"

mkdir -p "$SKILLS_DIR"

# Remove link/pasta existente
if [ -L "$LINK_PATH" ] || [ -e "$LINK_PATH" ]; then
  rm -rf "$LINK_PATH"
fi

ln -s "$REPO_ROOT" "$LINK_PATH"

echo "   ✅ poc-swarm instalado -> $(readlink -f "$LINK_PATH")"
echo ""
echo "Reinicie o Copilot CLI e confirme com /skills."
echo "Saída das POCs (padrão): $REPO_ROOT/pocs"
echo "Para mudar a saída, defina POCSWARM_ROOT ou indique o destino no pedido."

# ── Toolchain de validação/deploy: opcional ────────────────────────────────────
# O motor de agentes funciona sem nada disto. Validação e deploy precisam de
# az CLI + Bicep, Terraform (se usado), e linters (tflint/checkov/PSRule).
echo ""
echo "— Toolchain de validação/deploy: checando —"

PY=python3; command -v python3 >/dev/null 2>&1 || PY=python
have()      { command -v "$1" >/dev/null 2>&1; }
have_bicep() { have az && az bicep version >/dev/null 2>&1; }

MISSING=""
check() {
  if eval "$2" >/dev/null 2>&1; then
    echo "   ✅ $1"
  else
    echo "   ⚠️  $1 (ausente)"
    MISSING="$MISSING $1"
  fi
}

check "az (Azure CLI)"    "have az"
check "bicep (az bicep)"  "have_bicep"
check "terraform"         "have terraform"
check "tflint"            "have tflint"
check "checkov"           "have checkov"

if [ -z "$MISSING" ]; then
  echo "   ✅ toolchain de validação/deploy completo."
elif [ "$WITH_TOOLS" = "1" ]; then
  echo ""
  echo "   Instalando toolchain (--with-tools)..."
  if have brew; then
    brew install azure-cli terraform tflint checkov || true
  elif have apt-get; then
    # Azure CLI e Terraform têm repositórios próprios; instalação mínima best-effort:
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash || true
    sudo apt-get update && sudo apt-get install -y unzip || true
    have "$PY" && "$PY" -m pip install --quiet checkov || true
    echo "   ⚠️  Terraform e tflint: instale via repositório HashiCorp (veja README)."
  elif have dnf; then
    sudo dnf install -y azure-cli || true
    have "$PY" && "$PY" -m pip install --quiet checkov || true
    echo "   ⚠️  Terraform e tflint: instale via repositório HashiCorp (veja README)."
  else
    echo "   ⚠️  Gerenciador de pacotes não detectado — instale az CLI, Terraform, tflint e checkov manualmente."
  fi
  have az && az bicep install || true
  echo "   ✅ Tentativa concluída. Reinicie o terminal se necessário e faça 'az login'."
else
  echo ""
  echo "   Para habilitar validação/deploy, instale o que falta:"
  echo "     az CLI:     https://learn.microsoft.com/cli/azure/install-azure-cli  ;  az bicep install"
  echo "     Terraform:  https://developer.hashicorp.com/terraform/install"
  echo "     tflint:     https://github.com/terraform-linters/tflint"
  echo "     checkov:    pip install checkov"
  echo "   macOS:  brew install azure-cli terraform tflint checkov"
  echo "   Ou rode:  ./scripts/install.sh --with-tools"
  echo "   Depois, faça 'az login'."
fi
