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

pass() {
  printf '    ok: %s\n' "$1"
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

step 'Checking required commands'
required_commands=(
  bat cargo corepack delta direnv dotnet fd fnm fzf git git-absorb go java javac \
  jq node npm nvim pipx pnpm python3 rg rustc stow tmux tree-sitter zsh
)
for executable in "${required_commands[@]}"; do
  require_command "$executable"
done
pass "${#required_commands[@]} commands available"

if [[ $(uname -s) == Linux ]] && command -v apt-get >/dev/null; then
  [[ $(LC_ALL=en_US.UTF-8 locale charmap) == UTF-8 ]] || fail 'en_US.UTF-8 locale is unavailable'
  pass 'en_US.UTF-8 locale generated'
  if [[ -f /etc/ssh/sshd_config ]]; then
    ssh_accept_env=$(grep -ER '^[[:space:]]*AcceptEnv[[:space:]]' /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null || true)
    [[ -z $ssh_accept_env ]] || fail "SSH still accepts client locale variables: $ssh_accept_env"
    pass 'SSH ignores client locale variables'
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
printf '    Go:          %s\n' "$(go version)"
printf '    Rust:        %s\n' "$(rustc --version)"
printf '    Node:        %s\n' "$(node --version)"
printf '    Corepack:    %s\n' "$(corepack --version)"
printf '    pnpm:        %s\n' "$(pnpm --version)"
printf '    .NET SDK:    %s\n' "$(dotnet --version)"
printf '    Java:        %s\n' "$(java -version 2>&1 | sed -n '1p')"
printf '    Python:      %s\n' "$(python3 --version)"
printf '    Tree-sitter: %s\n' "$(tree-sitter --version)"
printf '    Neovim:      %s\n' "$(nvim --version | sed -n '1p')"

test_root=$(mktemp -d)
tmux_socket="ansible-smoke-$$"
cleanup() {
  tmux -L "$tmux_socket" kill-server 2>/dev/null || true
  rm -r -- "$test_root"
}
trap cleanup EXIT

step 'Running language toolchains'
python3 -m venv "$test_root/venv"
[[ $("$test_root/venv/bin/python" -c 'import sys; assert sys.prefix != sys.base_prefix; print("smoke-ok")') == smoke-ok ]] || fail 'Python virtual environment failed'
pass 'Python virtual environment'

mkdir "$test_root/go"
printf 'package main\nimport "fmt"\nfunc main() { fmt.Println("smoke-ok") }\n' > "$test_root/go/main.go"
[[ $(cd "$test_root/go" && go run main.go) == smoke-ok ]] || fail 'Go compile/run failed'
pass 'Go compile and run'

printf 'fn main() { println!("smoke-ok"); }\n' > "$test_root/main.rs"
rustc "$test_root/main.rs" -o "$test_root/rust-smoke"
[[ $("$test_root/rust-smoke") == smoke-ok ]] || fail 'Rust compile/run failed'
pass 'Rust compile and run'

mkdir "$test_root/java"
printf 'class Smoke { public static void main(String[] args) { System.out.println("smoke-ok"); } }\n' > "$test_root/java/Smoke.java"
javac -d "$test_root/java" "$test_root/java/Smoke.java"
[[ $(java -cp "$test_root/java" Smoke) == smoke-ok ]] || fail 'Java compile/run failed'
pass 'Java compile and run'

dotnet new console --output "$test_root/dotnet" --no-restore >/dev/null
dotnet run --project "$test_root/dotnet" > "$test_root/dotnet.log"
grep -qx 'Hello, World!' "$test_root/dotnet.log" || fail '.NET compile/run failed'
pass '.NET compile and run'

[[ $(node -e 'console.log("smoke-ok")') == smoke-ok ]] || fail 'Node execution failed'
pass 'Node execution'

step 'Checking shell and terminal configuration'
[[ ${LANG:-} == en_US.UTF-8 ]] || fail "shell LANG is ${LANG:-unset}, expected en_US.UTF-8"
[[ -z ${LC_ALL+x} ]] || fail "shell LC_ALL should be unset, got $LC_ALL"
pass 'Shell uses en_US.UTF-8 without an LC_ALL override'
zsh -n "$HOME/.zshrc"
pass 'Zsh configuration syntax'
[[ -r $HOME/.fzf.zsh ]] || fail 'fzf shell integration is unavailable'
pass 'fzf shell integration'
fzf_git="$HOME/.local/share/fzf-git/fzf-git.sh"
[[ -r $fzf_git ]] || fail 'fzf-git.sh is unavailable (~/.zshrc sources it silently)'
zsh -n "$fzf_git"
pass 'fzf-git key bindings'
bash -n "$HOME/.local/bin/tmux-sessionizer"
pass 'Sessionizer syntax'
tmux -L "$tmux_socket" -f "$HOME/.tmux.conf" new-session -d -s smoke -c "$test_root"
[[ $(tmux -L "$tmux_socket" display-message -p -t smoke '#S') == smoke ]] || fail 'Tmux configuration failed'
pass 'Tmux server with configured plugins'

step 'Checking Zen Browser defaults'
zen_defaults="$HOME/.config/zen/policies.json"
[[ -f $zen_defaults ]] || fail 'Zen Browser defaults are unavailable'
zen_autoconfig="$HOME/.config/zen/autoconfig.js"
zen_profile="$HOME/.config/zen/jobrk.cfg"
[[ -f $zen_autoconfig ]] || fail 'Zen Browser AutoConfig loader is unavailable'
[[ -f $zen_profile ]] || fail 'Zen Browser profile defaults are unavailable'
node --check "$zen_autoconfig"
node --check < "$zen_profile"
jq -e '
  .policies.ExtensionSettings["addon@darkreader.org"].installation_mode == "normal_installed" and
  .policies.ExtensionSettings["uBlock0@raymondhill.net"].installation_mode == "normal_installed" and
  .policies.ExtensionSettings["{d7742d87-e61d-4b78-b8a1-b469842139fa}"].installation_mode == "normal_installed"
' "$zen_defaults" >/dev/null || fail 'Zen Browser defaults do not match the Mac profile'
grep -Fqx '    pref("zen.view.compact.enable-at-startup", true);' "$zen_profile" || fail 'Zen compact mode default is unavailable'
grep -Fqx '    pref("zen.tabs.vertical.right-side", true);' "$zen_profile" || fail 'Zen right-side tabs default is unavailable'
grep -Fqx '    pref("zen.glance.enabled", false);' "$zen_profile" || fail 'Zen Glance default is unavailable'
grep -Fqx '    pref("layout.css.prefers-color-scheme.content-override", 0);' "$zen_profile" || fail 'Zen dark content default is unavailable'
grep -Fqx '    pref("findbar.highlightAll", true);' "$zen_profile" || fail 'Zen highlight-all search preference is unavailable'
grep -Fqx '    pref("pdfjs.enableAltTextForEnglish", true);' "$zen_profile" || fail 'Zen PDF alt-text preference is unavailable'
grep -Fqx '    pref("privacy.clearOnShutdown_v2.formdata", true);' "$zen_profile" || fail 'Zen form-data cleanup preference is unavailable'
pass 'Portable preferences and Dark Reader, uBlock Origin, and Vimium policies'

if command -v Hyprland >/dev/null; then
  step 'Checking Hyprland desktop configuration'
  for executable in alacritty cliphist flatpak Hyprland hyprctl hypridle hyprland-dialog hyprlock \
    mako waybar wl-copy wl-paste wofi wpctl xdg-open zen; do
    require_command "$executable"
  done
  [[ -f /usr/lib/systemd/user/hyprpolkitagent.service ]] || fail 'Hyprland polkit agent service is unavailable'
  [[ -f /usr/lib/systemd/user/mako.service ]] || fail 'Mako notification service is unavailable'
  [[ -f "$HOME/.config/hypr/hyprland.conf" ]] || fail 'Hyprland configuration is unavailable'
  [[ -f "$HOME/.config/waybar/config.jsonc" ]] || fail 'Waybar configuration is unavailable'
  [[ -f "$HOME/.config/waybar/style.css" ]] || fail 'Waybar style is unavailable'
  [[ -f "$HOME/.config/mako/config" ]] || fail 'Mako configuration is unavailable'
  grep -qx 'Session=hyprland' "$HOME/.dmrc" || fail 'Hyprland is not the selected desktop session'
  grep -Fqx '$term = ~/.cargo/bin/alacritty' "$HOME/.config/hypr/hyprland.conf" || fail 'Alacritty is not the Hyprland terminal'
  grep -Fqx 'monitor = , preferred, auto, auto' "$HOME/.config/hypr/hyprland.conf" || fail 'Hyprland does not use each display preferred mode and automatic scale'
  grep -Fqx 'env = XDG_DATA_DIRS,/var/lib/flatpak/exports/share:/usr/local/share:/usr/share' "$HOME/.config/hypr/hyprland.conf" || fail 'Hyprland cannot discover system Flatpak applications'
  grep -Fqx '    gaps_in = 6' "$HOME/.config/hypr/hyprland.conf" || fail 'Hyprland inner gaps are incorrect'
  grep -Fqx '    gaps_out = 0' "$HOME/.config/hypr/hyprland.conf" || fail 'Hyprland outer gaps are incorrect'
  grep -Fqx '    background_color = rgb(000000)' "$HOME/.config/hypr/hyprland.conf" || fail 'Hyprland background is not black'
  grep -Fqx 'exec-once = systemctl --user start hyprpolkitagent' "$HOME/.config/hypr/hyprland.conf" || fail 'Hyprland polkit agent is not started'
  grep -Fqx 'exec-once = waybar' "$HOME/.config/hypr/hyprland.conf" || fail 'Waybar is not started'
  grep -Fqx 'exec-once = wl-paste --type text --watch cliphist store' "$HOME/.config/hypr/hyprland.conf" || fail 'Text clipboard history is not started'
  grep -Fqx 'exec-once = wl-paste --type image --watch cliphist store' "$HOME/.config/hypr/hyprland.conf" || fail 'Image clipboard history is not started'
  grep -Fqx 'bind = $mod, V, exec, cliphist list | wofi --dmenu --prompt Clipboard | cliphist decode | wl-copy' "$HOME/.config/hypr/hyprland.conf" || fail 'Clipboard picker shortcut is unavailable'
  jq empty "$HOME/.config/waybar/config.jsonc" || fail 'Waybar configuration is invalid JSON'
  grep -Fqx '    background: #000000;' "$HOME/.config/waybar/style.css" || fail 'Waybar background is not black'
  grep -Fqx 'background-color=#000000' "$HOME/.config/mako/config" || fail 'Mako background is not black'
  grep -Fqx 'x-scheme-handler/https=app.zen_browser.zen.desktop' "$HOME/.config/mimeapps.list" || fail 'Zen Browser is not the HTTPS default'
  flatpak info --system app.zen_browser.zen >/dev/null || fail 'Zen Browser Flatpak is unavailable'
  [[ -f /var/lib/flatpak/exports/share/applications/app.zen_browser.zen.desktop ]] || fail 'Zen Browser desktop entry is unavailable'
  zen_flatpak_arch=$(flatpak --default-arch)
  zen_systemconfig="/var/lib/flatpak/extension/app.zen_browser.zen.systemconfig/$zen_flatpak_arch/stable"
  cmp -s "$HOME/.config/zen/policies.json" "$zen_systemconfig/policies/policies.json" || fail 'Zen Browser policies are not installed'
  cmp -s "$HOME/.config/zen/autoconfig.js" "$zen_systemconfig/defaults/pref/autoconfig.js" || fail 'Zen Browser AutoConfig loader is not installed'
  cmp -s "$HOME/.config/zen/jobrk.cfg" "$zen_systemconfig/jobrk.cfg" || fail 'Zen Browser profile defaults are not installed'
  [[ ! -e $HOME/.tarball-installations/zen ]] || fail 'Retired Zen Browser tarball is still installed'
  mkdir -m 700 "$test_root/runtime"
  XDG_RUNTIME_DIR="$test_root/runtime" Hyprland --verify-config \
    --config "$HOME/.config/hypr/hyprland.conf" > "$test_root/hyprland-config.log" 2>&1 || {
    sed -n '1,200p' "$test_root/hyprland-config.log" >&2
    fail 'Hyprland configuration is invalid'
  }
  hyprland_version=$(XDG_RUNTIME_DIR="$test_root/runtime" Hyprland --version 2>/dev/null | sed -n '1p')
  [[ -n $hyprland_version ]] || fail 'Hyprland version is unavailable'
  waybar_version=$(waybar --version)
  [[ -n $waybar_version ]] || fail 'Waybar version is unavailable'
  zen_version=$(flatpak info --system app.zen_browser.zen | sed -n 's/^[[:space:]]*Version:[[:space:]]*//p')
  [[ -n $zen_version ]] || fail 'Zen Browser version is unavailable'
  printf '    Waybar: %s\n' "$waybar_version"
  printf '    Zen:    %s\n' "$zen_version"
  pass "$hyprland_version with the desktop, clipboard history, and default browser configured"

  if [[ -e /.dockerenv || -e /run/.containerenv ]]; then
    pass 'Flatpak Zen installation and configuration; sandbox launch unavailable inside the container'
  else
    mkdir "$test_root/zen-profile"
    timeout 45 flatpak run --filesystem="$test_root" app.zen_browser.zen \
      --headless --no-remote --profile "$test_root/zen-profile" \
      --screenshot "$test_root/zen-first.png" 'data:text/html,smoke' > "$test_root/zen-first.log" 2>&1 || {
      sed -n '1,120p' "$test_root/zen-first.log" >&2
      fail 'Zen first launch failed'
    }
    zen_prefs="$test_root/zen-profile/prefs.js"
    grep -Fqx 'user_pref("jobrk.zen.config-version", 2);' "$zen_prefs" || fail 'Zen profile defaults were not imported'
    grep -Fqx 'user_pref("zen.tabs.vertical.right-side", true);' "$zen_prefs" || fail 'Zen right-side tabs were not imported'
    grep -Fqx 'user_pref("zen.view.compact.enable-at-startup", true);' "$zen_prefs" || fail 'Zen compact mode was not imported'
    grep -Fqx 'user_pref("browser.preferences.experimental.hidden", true);' "$zen_prefs" || fail 'Zen experimental-settings preference was not imported'
    grep -Fqx 'user_pref("findbar.highlightAll", true);' "$zen_prefs" || fail 'Zen highlight-all search preference was not imported'
    grep -Fqx 'user_pref("pdfjs.enableAltTextForEnglish", true);' "$zen_prefs" || fail 'Zen PDF alt-text preference was not imported'
    grep -Fqx 'user_pref("privacy.clearOnShutdown_v2.formdata", true);' "$zen_prefs" || fail 'Zen form-data cleanup preference was not imported'
    grep -Fqx 'user_pref("privacy.history.custom", true);' "$zen_prefs" || fail 'Zen custom-history preference was not imported'
    sed -i 's/user_pref("zen.glance.enabled", false);/user_pref("zen.glance.enabled", true);/' "$zen_prefs"
    timeout 45 flatpak run --filesystem="$test_root" app.zen_browser.zen \
      --headless --no-remote --profile "$test_root/zen-profile" \
      --screenshot "$test_root/zen-second.png" 'data:text/html,smoke' > "$test_root/zen-second.log" 2>&1 || {
      sed -n '1,120p' "$test_root/zen-second.log" >&2
      fail 'Zen second launch failed'
    }
    if grep -Fqx 'user_pref("zen.glance.enabled", false);' "$zen_prefs"; then
      fail 'Zen profile defaults were reapplied after import'
    fi
    pass 'Flatpak Zen imports the Mac profile once and preserves later user changes'
  fi
fi

step 'Checking Bat theme'
bat --list-themes | grep -qx 'Catppuccin-mocha' || fail 'Bat theme is unavailable'
bat_warning=$(printf 'test\n' | bat --color=always --plain --language=txt 2>&1 >/dev/null)
[[ -z $bat_warning ]] || fail "Bat emitted: $bat_warning"
pass 'Catppuccin-mocha renders without warnings'

step 'Checking clean Neovim startup'
nvim --headless +qa > "$test_root/nvim-startup.log" 2>&1 || {
  sed -n '1,200p' "$test_root/nvim-startup.log" >&2
  fail 'Neovim startup failed'
}
check_log "$test_root/nvim-startup.log" 'Neovim startup'
pass 'Neovim started without warnings or errors'

step 'Checking Neovim plugins were provisioned'
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
pass 'All configured Neovim plugins installed'

step 'Checking Mason tools were provisioned'
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
pass 'All configured Mason tools installed'

step 'Checking Java editor integration'
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
pass 'JDTLS, Java debugging, and Java test bundles'

step 'Checking Tree-sitter parsers'
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
pass 'All configured Tree-sitter parsers installed'

step 'Checking repository cleanliness'
[[ -z $(git -C "$HOME/projects/dotfiles" status --porcelain) ]] || fail 'Dotfiles worktree is dirty'
[[ -z $(git -C "$HOME/projects/dotfiles/nvim/.config/nvim" status --porcelain) ]] || fail 'Neovim worktree is dirty'
pass 'Dotfiles and Neovim worktrees are clean'

printf '\nSmoke test passed\n'
