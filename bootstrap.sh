#!/usr/bin/env bash
set -euo pipefail

REPO="${ANSIBLE_REPO:-https://github.com/jobrk/ansible}"
DEST="${ANSIBLE_DEST:-$HOME/ansible}"
OS="$(uname -s)"

log() { printf '\n==> %s\n' "$*"; }

configure_locale() {
  unset LANGUAGE LC_ADDRESS LC_ALL LC_COLLATE LC_CTYPE LC_IDENTIFICATION LC_MEASUREMENT \
    LC_MESSAGES LC_MONETARY LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE LC_TIME

  if locale -a 2> /dev/null | grep -Eiq '^en_US\.(UTF-8|utf8)$'; then
    export LANG=en_US.UTF-8
  elif locale -a 2> /dev/null | grep -Eiq '^C\.(UTF-8|utf8)$'; then
    export LANG=C.UTF-8
  else
    export LANG=C
  fi
}

as_root() {
  if [[ $(id -u) == 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

add_skip_tag() {
  if [[ -n $skip_tags ]]; then
    skip_tags="$skip_tags,$1"
  else
    skip_tags=$1
  fi
}

configure_locale
export PATH="$HOME/.local/bin:$PATH"
if [[ -x /usr/bin/sudo.ws ]]; then
  export ANSIBLE_BECOME_EXE=/usr/bin/sudo.ws
fi

if ! command -v git > /dev/null || ! command -v ansible-playbook > /dev/null; then
  log "Installing git + ansible"
  if [[ $OS == Darwin ]]; then
    if ! command -v brew > /dev/null; then
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv 2> /dev/null || /usr/local/bin/brew shellenv)"
    fi
    command -v ansible-playbook > /dev/null || brew install ansible
  else
    if ! command -v pipx > /dev/null || ! command -v git > /dev/null; then
      if command -v apt-get > /dev/null; then
        as_root apt-get update -y
        as_root apt-get install -y git pipx
      elif command -v dnf > /dev/null; then
        as_root dnf install -y git pipx
      else
        log "No supported package manager (apt/dnf)"
        exit 1
      fi
    fi
    command -v ansible-playbook > /dev/null || pipx install --include-deps ansible
  fi
fi

log "Fetching playbook"
if [[ -d $DEST/.git ]]; then
  git -C "$DEST" pull --ff-only
else
  git clone "$REPO" "$DEST"
fi
cd "$DEST"
ansible-galaxy collection install -r requirements.yml > /dev/null

set -- -i inventory.ini main.yml
skip_tags="${SKIP_TAGS:-}"
if [[ $OS != Darwin && -z ${DISPLAY:-}${WAYLAND_DISPLAY:-} && -z ${UI:-} ]]; then
  add_skip_tag ui
fi

if [[ $(id -u) == 0 ]] || sudo -n -k true 2> /dev/null; then
  :
elif [[ -t 0 ]]; then
  set -- "$@" -K
else
  add_skip_tag become
fi
[[ -n $skip_tags ]] && set -- "$@" --skip-tags "$skip_tags"

log "Running playbook"
ansible-playbook "$@"

log "Done"
