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

run_with_timeout() {
  local log=$1
  local seconds=$2
  shift 2

  python3 - "$log" "$seconds" "$@" <<'PY'
import subprocess
import sys

log, seconds, *command = sys.argv[1:]
with open(log, "w", encoding="utf-8") as output:
    try:
        result = subprocess.run(
            command,
            stdout=output,
            stderr=subprocess.STDOUT,
            timeout=int(seconds),
            check=False,
        )
    except subprocess.TimeoutExpired:
        output.write(f"command timed out after {seconds} seconds\n")
        raise SystemExit(124)
raise SystemExit(result.returncode)
PY
}

for executable in \
  bat cargo delta direnv dotnet fd fnm fzf git git-absorb go java javac jq \
  node npm nvim pipx python3 rg rustc stow tmux tree-sitter zsh; do
  require_command "$executable"
done

go version | grep -q '^go version go' || fail 'Go version is invalid'
tree-sitter --version | grep -q '^tree-sitter ' || fail 'Tree-sitter version is invalid'
dotnet --version | grep -q '^10\.' || fail '.NET 10 SDK version is invalid'
java -version 2>&1 | grep -q 'version "25' || fail 'Java 25 version is invalid'
javac -version 2>&1 | grep -q '^javac 25' || fail 'Javac 25 version is invalid'
python3 --version | grep -q '^Python 3\.' || fail 'Python 3 version is invalid'
node --version | grep -q '^v' || fail 'Node version is invalid'
rustc --version | grep -q '^rustc ' || fail 'Rust version is invalid'

test_root=$(mktemp -d)
tmux_socket="ansible-smoke-$$"
cleanup() {
  tmux -L "$tmux_socket" kill-server 2>/dev/null || true
  rm -r -- "$test_root"
}
trap cleanup EXIT

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

zsh -n "$HOME/.zshrc"
bash -n "$HOME/.local/bin/tmux-sessionizer"
tmux -L "$tmux_socket" -f "$HOME/.tmux.conf" new-session -d -s smoke -c "$test_root"
[[ $(tmux -L "$tmux_socket" display-message -p -t smoke '#S') == smoke ]] || fail 'Tmux configuration failed'

bat --list-themes | grep -qx 'Catppuccin-mocha' || fail 'Bat theme is unavailable'
bat_warning=$(printf 'test\n' | bat --color=always --plain --language=txt 2>&1 >/dev/null)
[[ -z $bat_warning ]] || fail "Bat emitted: $bat_warning"

nvim --headless +qa > "$test_root/nvim-first-run.log" 2>&1 || {
  sed -n '1,200p' "$test_root/nvim-first-run.log" >&2
  fail 'Neovim first launch failed'
}
check_log "$test_root/nvim-first-run.log" 'Neovim first launch'

run_with_timeout "$test_root/mason.log" 900 nvim --headless '+MasonToolsInstallSync' +qa || {
  sed -n '1,200p' "$test_root/mason.log" >&2
  fail 'Mason tool installation failed or timed out'
}
check_log "$test_root/mason.log" 'Mason tool installation'

cat > "$test_root/check-parsers.lua" <<'LUA'
local parsers = {
  'bash', 'c', 'c_sharp', 'css', 'diff', 'dockerfile', 'gitignore', 'git_rebase',
  'go', 'graphql', 'groovy', 'html', 'ini', 'javascript', 'jinja', 'jinja_inline',
  'json', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'powershell', 'proto',
  'puppet', 'python', 'query', 'rust', 'sql', 'toml', 'tsx', 'typescript', 'vim',
  'vimdoc', 'xml', 'yaml', 'zsh',
}
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

[[ -z $(git -C "$HOME/projects/dotfiles" status --porcelain) ]] || fail 'Dotfiles worktree is dirty'
[[ -z $(git -C "$HOME/projects/dotfiles/nvim/.config/nvim" status --porcelain) ]] || fail 'Neovim worktree is dirty'

printf 'smoke test passed\n'
