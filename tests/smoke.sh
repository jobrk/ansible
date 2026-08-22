#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

fail() {
  printf 'smoke test failed: %s\n' "$*" >&2
  exit 1
}

go version | grep -q '^go version go' || fail 'Go is unavailable'
tree-sitter --version | grep -q '^tree-sitter ' || fail 'Tree-sitter is unavailable'
dotnet --version | grep -q '^10\.' || fail '.NET 10 SDK is unavailable'
java -version 2>&1 | grep -q 'version "25' || fail 'Java 25 is unavailable'
javac -version 2>&1 | grep -q '^javac 25' || fail 'Javac 25 is unavailable'
python3 --version | grep -q '^Python 3\.' || fail 'Python 3 is unavailable'

test_root=$(mktemp -d)
trap 'rm -r -- "$test_root"' EXIT

python3 -m venv "$test_root/venv"
"$test_root/venv/bin/python" -c 'import sys; assert sys.prefix != sys.base_prefix'

bat --list-themes | grep -qx 'Catppuccin-mocha' || fail 'Bat theme is unavailable'
bat_warning=$(printf 'test\n' | bat --color=always --plain --language=txt 2>&1 >/dev/null)
[[ -z $bat_warning ]] || fail "Bat emitted: $bat_warning"

nvim --headless +qa >"$test_root/nvim-first-run.log" 2>&1 || {
  sed -n '1,200p' "$test_root/nvim-first-run.log" >&2
  fail 'Neovim first launch failed'
}
if grep -Eiq 'error:|warning:|failed|enoent|killed|unsupported' "$test_root/nvim-first-run.log"; then
  sed -n '1,200p' "$test_root/nvim-first-run.log" >&2
  fail 'Neovim first launch reported a problem'
fi

nvim --headless '+set filetype=go' \
  '+lua assert(vim.wait(120000, function() return pcall(vim.treesitter.language.inspect, "go") end, 100))' \
  +qa >"$test_root/nvim-go.log" 2>&1 || {
  sed -n '1,200p' "$test_root/nvim-go.log" >&2
  fail 'Go parser installation failed'
}
if grep -Eiq 'error:|warning:|failed|enoent|killed|unsupported' "$test_root/nvim-go.log"; then
  sed -n '1,200p' "$test_root/nvim-go.log" >&2
  fail 'Go parser installation reported a problem'
fi

[[ -z $(git -C "$HOME/projects/dotfiles" status --porcelain) ]] || fail 'Dotfiles worktree is dirty'
[[ -z $(git -C "$HOME/projects/dotfiles/nvim/.config/nvim" status --porcelain) ]] || fail 'Neovim worktree is dirty'

printf 'smoke test passed\n'
