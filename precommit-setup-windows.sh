#!/usr/bin/env bash
set -e

echo "📦 Setting up Python and pipx on Git Bash (Windows 😒)..."

PYTHON_VERSION="3.12.3"
PYTHON_INSTALLER="python-${PYTHON_VERSION}-amd64.exe"
PYTHON_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/${PYTHON_INSTALLER}"

if [ ! -f "$PYTHON_INSTALLER" ]; then
  echo "⬇️  Downloading Python ${PYTHON_VERSION}..."
  curl -LO "$PYTHON_URL"
fi

echo "⚙️  Installing Python..."
powershell.exe -Command "Start-Process './${PYTHON_INSTALLER}' -ArgumentList '/quiet','InstallAllUsers=1','PrependPath=1','Include_test=0' -Wait"

USER_PROFILE_PATH=$(cmd.exe /c "echo %USERPROFILE%" | tr -d '\r')
PYTHON_PATH="$(echo "$USER_PROFILE_PATH\\AppData\\Local\\Programs\\Python\\Python${PYTHON_VERSION/./}" | sed 's#\\#/#g')"
export PATH="$PYTHON_PATH/Scripts:$PYTHON_PATH:$PATH"

echo "🚀 Installing pipx..."
python -m ensurepip --upgrade
python -m pip install --upgrade pip
python -m pip install pipx
python -m pipx ensurepath

echo "✅ pipx installed. Restart Git Bash or run:"
echo "    source ~/.bashrc"

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
