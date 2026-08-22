#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1
export NUGET_XMLDOC_MODE=skip

fail() {
  printf 'smoke test failed: %s\n' "$*" >&2
  exit 1
}

step() {
  printf '\n==> %s\n' "$1"
}

require_command() {
  command -v "$1" >/dev/null || fail "$1 is unavailable"
}

check_log() {
  local log=$1
  local description=$2
  if grep -Eiq 'error:|warning:|failed|enoent|killed|unsupported' "$log"; then
    sed -n '1,200p' "$log" >&2
    fail "$description reported a problem"
  fi
}

printf 'Smoke test: %s %s\n' "$(uname -s)" "$(uname -m)"

step 'Commands'
required_commands=(
  bat cargo corepack delta direnv dotnet fd fnm fzf git git-absorb go java javac \
  jq node npm nvim pipx pnpm python3 rg rustc stow tmux tree-sitter zsh
)
for executable in "${required_commands[@]}"; do
  require_command "$executable"
done
if [[ $(uname -s) == Linux ]] && command -v apt-get >/dev/null; then
  [[ $(LC_ALL=en_US.UTF-8 locale charmap) == UTF-8 ]] || fail 'en_US.UTF-8 locale is unavailable'
  if [[ -f /etc/ssh/sshd_config ]]; then
    ssh_accept_env=$(grep -ER '^[[:space:]]*AcceptEnv[[:space:]]' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null || true)
    [[ -z $ssh_accept_env ]] || fail "SSH still accepts client locale variables: $ssh_accept_env"
  fi
fi

go version | grep -q '^go version go' || fail 'Go version is invalid'
tree-sitter --version | grep -q '^tree-sitter ' || fail 'Tree-sitter version is invalid'
dotnet --version | grep -q '^10\.' || fail '.NET 10 SDK version is invalid'
java -version 2>&1 | grep -q 'version "25' || fail 'Java 25 version is invalid'
javac -version 2>&1 | grep -q '^javac 25' || fail 'Javac 25 version is invalid'
python3 --version | grep -q '^Python 3\.' || fail 'Python 3 version is invalid'
node --version | grep -q '^v' || fail 'Node version is invalid'
rustc --version | grep -q '^rustc ' || fail 'Rust version is invalid'
nvim --version | grep -Eq '^NVIM v[0-9]+\.[0-9]+\.[0-9]+$' || fail 'Neovim version is invalid'
corepack --version | grep -Eq '^[0-9]+\.' || fail 'Corepack version is invalid'
pnpm --version | grep -Eq '^[0-9]+\.' || fail 'pnpm version is invalid'

test_root=$(mktemp -d)
tmux_socket="ansible-smoke-$$"
cleanup() {
  tmux -L "$tmux_socket" kill-server 2>/dev/null || true
  rm -r -- "$test_root"
}
trap cleanup EXIT

step 'Toolchains'
python3 -m venv "$test_root/venv"
[[ $("$test_root/venv/bin/python" -c 'import sys; assert sys.prefix != sys.base_prefix; print("smoke-ok")') == smoke-ok ]] || fail 'Python virtual environment failed'

mkdir "$test_root/go"
printf 'package main\nimport "fmt"\nfunc main() { fmt.Println("smoke-ok") }\n' > "$test_root/go/main.go"
[[ $(cd "$test_root/go" && go run main.go) == smoke-ok ]] || fail 'Go compile/run failed'

printf 'fn main() { println!("smoke-ok"); }\n' > "$test_root/main.rs"
rustc "$test_root/main.rs" -o "$test_root/rust-smoke"
[[ $("$test_root/rust-smoke") == smoke-ok ]] || fail 'Rust compile/run failed'

mkdir "$test_root/java"
printf 'class Smoke { public static void main(String[] args) { System.out.println("smoke-ok"); } }\n' > "$test_root/java/Smoke.java"
javac -d "$test_root/java" "$test_root/java/Smoke.java"
[[ $(java -cp "$test_root/java" Smoke) == smoke-ok ]] || fail 'Java compile/run failed'

dotnet new console --output "$test_root/dotnet" --no-restore >/dev/null
dotnet run --project "$test_root/dotnet" > "$test_root/dotnet.log"
grep -qx 'Hello, World!' "$test_root/dotnet.log" || fail '.NET compile/run failed'

[[ $(node -e 'console.log("smoke-ok")') == smoke-ok ]] || fail 'Node execution failed'

step 'Shell'
[[ ${LANG:-} == en_US.UTF-8 ]] || fail "shell LANG is ${LANG:-unset}, expected en_US.UTF-8"
[[ -z ${LC_ALL+x} ]] || fail "shell LC_ALL should be unset, got $LC_ALL"
zsh -n "$HOME/.zshrc"
bash -n "$HOME/.local/bin/tmux-sessionizer"
tmux -L "$tmux_socket" -f "$HOME/.tmux.conf" new-session -d -s smoke -c "$test_root"
[[ $(tmux -L "$tmux_socket" display-message -p -t smoke '#S') == smoke ]] || fail 'Tmux configuration failed'

step 'Bat'
bat --list-themes | grep -qx 'Catppuccin-mocha' || fail 'Bat theme is unavailable'
bat_warning=$(printf 'test\n' | bat --color=always --plain --language=txt 2>&1 >/dev/null)
[[ -z $bat_warning ]] || fail "Bat emitted: $bat_warning"

step 'Neovim'
nvim --headless +qa > "$test_root/nvim-startup.log" 2>&1 || {
  sed -n '1,200p' "$test_root/nvim-startup.log" >&2
  fail 'Neovim startup failed'
}
check_log "$test_root/nvim-startup.log" 'Neovim startup'

step 'Plugins'
cat > "$test_root/check-plugins.lua" <<'LUA'
local missing = {}
for name, plugin in pairs(require('lazy.core.config').plugins) do
  if plugin.enabled ~= false and plugin.dir and not vim.uv.fs_stat(plugin.dir) then
    table.insert(missing, name)
  end
end
table.sort(missing)
assert(#missing == 0, 'missing Neovim plugins: ' .. table.concat(missing, ', '))
LUA
nvim --headless "+luafile $test_root/check-plugins.lua" +qa > "$test_root/nvim-plugins.log" 2>&1 || {
  sed -n '1,200p' "$test_root/nvim-plugins.log" >&2
  fail 'Neovim plugin verification failed'
}
check_log "$test_root/nvim-plugins.log" 'Neovim plugin verification'

step 'Mason'
cat > "$test_root/check-mason.lua" <<'LUA'
local registry = require 'mason-registry'
local missing = {}
for _, name in ipairs(require('tooling').mason) do
  local ok, package = pcall(registry.get_package, name)
  if not ok or not package:is_installed() then
    table.insert(missing, name)
  end
end
assert(#missing == 0, 'missing Mason tools: ' .. table.concat(missing, ', '))
LUA
nvim --headless "+luafile $test_root/check-mason.lua" +qa > "$test_root/nvim-mason.log" 2>&1 || {
  sed -n '1,200p' "$test_root/nvim-mason.log" >&2
  fail 'Mason tool verification failed'
}
check_log "$test_root/nvim-mason.log" 'Mason tool verification'

step 'Java'
mkdir -p "$test_root/java-lsp/.git"
printf 'class Smoke { public static void main(String[] args) { System.out.println("smoke-ok"); } }\n' > "$test_root/java-lsp/Smoke.java"
cat > "$test_root/check-jdtls.lua" <<'LUA'
local attached = vim.wait(180000, function()
  local clients = vim.lsp.get_clients { name = 'jdtls' }
  return #clients > 0 and require('dap').adapters.java ~= nil
end, 100)
assert(attached, 'JDTLS did not attach or register its debug adapter')
local client = vim.lsp.get_clients { name = 'jdtls' }[1]
local bundles = client.config.init_options and client.config.init_options.bundles or {}
assert(#bundles > 1, 'Java debug and test bundles were not loaded')
LUA
nvim --headless "$test_root/java-lsp/Smoke.java" \
  "+luafile $test_root/check-jdtls.lua" +qa > "$test_root/jdtls.log" 2>&1 || {
  sed -n '1,200p' "$test_root/jdtls.log" >&2
  fail 'Java editor integration failed'
}
check_log "$test_root/jdtls.log" 'Java editor integration'

step 'Tree-sitter'
cat > "$test_root/check-parsers.lua" <<'LUA'
local parsers = require('tooling').treesitter
local missing = vim.tbl_filter(function(parser)
  return not pcall(vim.treesitter.language.inspect, parser)
end, parsers)
assert(#missing == 0, 'missing Tree-sitter parsers: ' .. table.concat(missing, ', '))
LUA

nvim --headless "+luafile $test_root/check-parsers.lua" +qa > "$test_root/nvim-parsers.log" 2>&1 || {
  sed -n '1,200p' "$test_root/nvim-parsers.log" >&2
  fail 'Tree-sitter parser verification failed'
}
check_log "$test_root/nvim-parsers.log" 'Tree-sitter parser verification'

step 'Repositories'
[[ -z $(git -C "$HOME/projects/dotfiles" status --porcelain) ]] || fail 'Dotfiles worktree is dirty'
[[ -z $(git -C "$HOME/projects/dotfiles/nvim/.config/nvim" status --porcelain) ]] || fail 'Neovim worktree is dirty'

printf '\nSmoke test passed\n'
