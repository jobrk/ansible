#!/usr/bin/env bash
set -euo pipefail

REPO="${ANSIBLE_REPO:-https://github.com/jobrk/ansible}"
DEST="${ANSIBLE_DEST:-$HOME/ansible}"
OS="$(uname -s)"

log() { printf '\n==> %s\n' "$*"; }

export PATH="$HOME/.local/bin:$PATH"
if ! command -v git > /dev/null || ! command -v ansible-playbook > /dev/null; then
  log "Installing git + ansible"
  if [ "$OS" = "Darwin" ]; then
    if ! command -v brew > /dev/null; then
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv 2> /dev/null || /usr/local/bin/brew shellenv)"
    fi
    command -v ansible-playbook > /dev/null || brew install ansible
  else
    SUDO=""
    [ "$(id -u)" != 0 ] && SUDO="sudo"
    if ! command -v pipx > /dev/null || ! command -v git > /dev/null; then
      if command -v apt-get > /dev/null; then
        $SUDO apt-get update -y
        $SUDO apt-get install -y git pipx
      elif command -v dnf > /dev/null; then
        $SUDO dnf install -y git pipx
      else
        log "No supported package manager (apt/dnf)"; exit 1
      fi
    fi
    command -v ansible-playbook > /dev/null || pipx install --include-deps ansible
  fi
fi

if [ -n "${GH_TOKEN:-}" ]; then
  log "Configuring GitHub token auth"
  git config --global credential.helper store
  printf 'https://oauth2:%s@github.com\n' "$GH_TOKEN" > ~/.git-credentials
  chmod 600 ~/.git-credentials
fi

log "Fetching playbook"
if [ -d "$DEST/.git" ]; then
  git -C "$DEST" pull --ff-only
else
  git clone "$REPO" "$DEST"
fi
cd "$DEST"
ansible-galaxy collection install -r requirements.yml > /dev/null

SKIP="${SKIP_TAGS:-}"
if [ "$OS" != "Darwin" ] && [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && [ -z "${UI:-}" ]; then
  SKIP="${SKIP:+$SKIP,}ui"
fi

ARGS=()
if [ "$(id -u)" = 0 ] || sudo -n true 2> /dev/null; then
  :
elif [ -t 0 ]; then
  ARGS+=(-K)
else
  SKIP="${SKIP:+$SKIP,}become"
fi
[ -n "$SKIP" ] && ARGS+=(--skip-tags "$SKIP")
[ -f vars/secrets.yml ] && [ -t 0 ] && ARGS+=(--ask-vault-pass)

log "Running playbook ${ARGS[*]:-}"
ansible-playbook main.yml ${ARGS[@]+"${ARGS[@]}"}

log "Done. Remaining manual steps:"
echo "  - edit ~/.gitconfig.local (placeholder email)"
echo "  - fill ~/.zshrc.local, ~/.config/sessionizer/paths as needed"
echo "  - secrets: cp vars/secrets.yml.example vars/secrets.yml, edit,"
echo "    ansible-vault encrypt, re-run — or write ~/.config/zsh/secrets.zsh by hand"
echo "  - launch nvim once (plugins bootstrap)"
