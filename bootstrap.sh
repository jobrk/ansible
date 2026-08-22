#!/usr/bin/env bash
set -euo pipefail

# SSH clients can forward locale variables that do not exist on a new server.
# Keep bootstrap usable long enough for Ansible to generate the preferred locale.
unset LANGUAGE LC_ADDRESS LC_ALL LC_COLLATE LC_CTYPE LC_IDENTIFICATION LC_MEASUREMENT \
  LC_MESSAGES LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE LC_TIME
if locale -a 2> /dev/null | grep -Eiq '^en_US\.(UTF-8|utf8)$'; then
  export LANG=en_US.UTF-8
elif locale -a 2> /dev/null | grep -Eiq '^C\.(UTF-8|utf8)$'; then
  export LANG=C.UTF-8
else
  export LANG=C
fi

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
if [ "$(id -u)" = 0 ] || sudo -n -k true 2> /dev/null; then
  :
elif [ -t 0 ]; then
  ARGS+=(-K)
else
  SKIP="${SKIP:+$SKIP,}become"
fi
[ -n "$SKIP" ] && ARGS+=(--skip-tags "$SKIP")

log "Running playbook ${ARGS[*]:-}"
ansible-playbook -i inventory.ini main.yml ${ARGS[@]+"${ARGS[@]}"}

log "Done. Neovim is ready; no first-launch setup is required."
echo "Remaining manual steps:"
echo "  - edit ~/.gitconfig.local (placeholder email)"
echo "  - fill ~/.zshrc.local, ~/.config/sessionizer/paths as needed"
echo "  - put local credentials in ~/.config/zsh/secrets.zsh"
