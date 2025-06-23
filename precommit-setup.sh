#!/usr/bin/env bash
set -e

echo "🔍 Detecting OS..."
OS="$(uname -s)"

install_on_linux() {
  echo "🛠 Installing Python on Linux..."
  if [ -f /etc/debian_version ]; then
    sudo apt update
    sudo apt install -y python3 python3-venv curl

    echo "📦 Installing pipx via apt (Ubuntu 23.04+)..."
    if apt-cache show pipx &>/dev/null; then
      sudo apt install -y pipx
    else
      echo "📦 Installing pipx via pip (older Ubuntu/Debian)..."
      python3 -m ensurepip --upgrade || true
      python3 -m pip install --user pipx
    fi
  elif [ -f /etc/redhat-release ]; then
    sudo dnf install -y python3 python3-pip python3-virtualenv pipx || {
      echo "Fallback to pip..."
      python3 -m pip install --user pipx
    }
  elif [ -f /etc/arch-release ]; then
    sudo pacman -Sy --noconfirm python python-pip python-pipx
  else
    echo "❌ Unsupported Linux distro"
    exit 1
  fi
}

install_on_macos() {
  echo "🛠 Installing Python and pipx on macOS..."
  if ! command -v brew &>/dev/null; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  brew install python
  brew install pipx
}

ensure_pipx_path() {
  echo "✅ Running pipx ensurepath..."
  pipx ensurepath

  echo "📌 Add pipx to your PATH if not already:"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
}

install_tools_with_pipx() {
  echo "📦 Installing CLI tools using pipx..."
  tools=("pre-commit")

  for tool in "${tools[@]}"; do
    echo "➡ Installing $tool..."
    pipx install "$tool" || echo "⚠️ Skipped $tool (already installed?)"
  done
}

install_pre_commit() {
  echo "🔍 Checking for pre-commit..."
  if ! command -v pre-commit &>/dev/null; then
    echo "📦 Installing pre-commit via pipx..."
    pipx install pre-commit
  fi

  echo "📎 Running 'pre-commit install' if .pre-commit-config.yaml is present..."
  if [ -f .pre-commit-config.yaml ]; then
    pre-commit install
  else
    echo "⚠️ No .pre-commit-config.yaml found — skipping hook install"
  fi
}

case "$OS" in
  Linux*)   install_on_linux ;;
  Darwin*)  install_on_macos ;;
  *)        echo "❌ Unsupported OS: $OS"; exit 1 ;;
esac

echo "✅ Python version:"
python3 --version

echo "✅ pipx version:"
pipx --version

ensure_pipx_path
install_tools_with_pipx

pre-commit install


HOOK_FILE=".git/hooks/pre-commit"
if [ -f "$HOOK_FILE" ]; then
  echo "🔧 Patching pre-commit hook with gitleaks.enabled check..."

  TMP_HOOK="${HOOK_FILE}.tmp"

  awk '
  BEGIN {
    print "GITLEAKS_ENABLED=$(git config --get gitleaks.enabled)"
    print "if [ \"$GITLEAKS_ENABLED\" = \"true\" ]; then"
    inside=0
  }

  /if \[ -x "\$INSTALL_PYTHON" \]; then/ { inside=1 }

  {
    print
  }

  /^fi$/ && inside {
    print "else"
    print "  exit 0"
    print "fi"
    inside=0
  }
  ' .git/hooks/pre-commit > .git/hooks/pre-commit.tmp && mv .git/hooks/pre-commit.tmp .git/hooks/pre-commit

  git config gitleaks.enabled true


  chmod +x "$HOOK_FILE"
else
  echo "⚠️ pre-commit hook not found. Run 'pre-commit install' to generate it."
fi

echo "🎉 All done!"
