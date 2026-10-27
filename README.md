# ansible

Fresh-machine provisioning for personal machines (Debian-family, Fedora/RHEL-family,
macOS). Installs packages and toolchains, then clones
[jobrk/dotfiles](https://github.com/jobrk/dotfiles) and stows it. Config files
live in dotfiles only — this repo owns machine state, never file content.

The playbook installs and configures the desired setup. Migrations and retirement
of previous setups are handled separately; there are no legacy cleanup tasks or
tags. Installation still removes its own downloaded installers and build files.

## Usage

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/jobrk/ansible/main/bootstrap.sh)
```

Bootstrap installs ansible, clones or updates this repo, and infers flags:
`ui` skipped over SSH (force with `UI=1`), `-K` only when sudo needs a
password, `become` skipped when sudo is unavailable or non-interactive. Env overrides:
`SKIP_TAGS`, `ANSIBLE_REPO`, `ANSIBLE_DEST`.

Manual equivalent:

```sh
git clone https://github.com/jobrk/ansible ~/ansible
cd ~/ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory.ini main.yml -K
```

Partial runs: `--tags zsh,tmux`, `--tags userspace`, `--skip-tags ui`,
`--skip-tags become`. The bash-to-zsh login handoff never runs by default:
add it with `--tags handoff` (alone, or `--tags all,handoff` alongside a full
run). Re-run any time; a second run reports `changed=0`.

## What needs sudo

Linux system packages require sudo. macOS uses Homebrew as the user; the optional
Window Effects backend also needs administrator authentication (see below).
A user-space pass runs after system packages on every run; each task
checks for a command and fills the gap under `~/.local` only when missing.
`~/.local/bin` is first on PATH, so a fallback shadows a later system
install; delete the local copy to hand the command back to the distro.

| Component | With sudo | Without sudo |
|---|---|---|
| Compilers, make, cmake, git, python3, tmux, zsh, unzip, locales | dnf/apt | none — administrator |
| Go, Java 25, .NET 10 SDKs | dnf/apt | none — administrator |
| Hyprland desktop, greetd, Waybar, portals, Zen Browser (`ui`) | dnf/apt + Flatpak | none — administrator |
| Ghostty (`ui`) | dnf/apt | pinned AppImage |
| fzf, ripgrep, fd, bat, delta, jq, direnv | dnf/apt | pinned release binaries |
| Stow | dnf/apt | built from source (needs make and perl) |
| pipx | dnf/apt | `pip install --user` |
| Tree-sitter CLI | release binary | same; cargo-built when the host glibc is too old |
| zsh as the login shell | chsh | opt-in `--tags handoff`: `~/.bash_profile` hands interactive logins to zsh |
| Rust, Node LTS, Neovim, oh-my-zsh + plugins, fzf-git, fonts, tpm, Mason tools, parsers, dotfiles | user-space | same — sudo never needed |

The Linux Tree-sitter CLI pin (`tree_sitter_version` in `main.yml`) satisfies
the Neovim configuration's 0.26.1 minimum. macOS installs the CLI through Homebrew.

Without sudo, run bootstrap non-interactively and let the smoke test report
anything missing:

```sh
curl -fsSL https://raw.githubusercontent.com/jobrk/ansible/main/bootstrap.sh | bash &&
/bin/zsh -lic 'bash ~/ansible/tests/smoke.sh'
```

On a graphical Linux machine without sudo, Ghostty falls back to a community
AppImage when it is not already installed. It is verified against a pinned
checksum and extracted under `~/.local/opt`, so it does not depend on FUSE.

Ghostty remains untouched when provisioning a server over SSH because `ui` is
skipped. Set `UI=1` when provisioning a graphical workstation over SSH.

Linux UI provisioning installs greetd when no display manager is selected. It
configures an existing greetd installation and preserves other display managers.

## Over SSH

Copy `inventory.example.ini` to a private inventory, list your machines, then:

```sh
ansible-playbook -i my-inventory.ini main.yml -e target=workstations -K
```

Targets need SSH access and Python. `-e target=droplet` hits a single host;
without `-e target` the playbook runs locally. Headless targets: add
`--skip-tags ui`. First-run macOS targets are better provisioned locally.

## Cloud (DigitalOcean, etc.)

Paste `cloud-init.yml` as user data at droplet creation. It creates the `josh`
user with passwordless sudo, imports SSH keys from GitHub, sets the
`en_US.UTF-8` locale, and runs bootstrap without UI packages.

## Secrets

```sh
mkdir -p ~/.config/zsh
cp ~/projects/dotfiles/templates/secrets.zsh.example ~/.config/zsh/secrets.zsh
chmod 600 ~/.config/zsh/secrets.zsh
$EDITOR ~/.config/zsh/secrets.zsh
```

Sourced by the dotfiles zsh configuration; never tracked or managed by
Ansible. Also edit the seeded `~/.gitconfig.local` (placeholder email). For
public commits, use your GitHub `noreply` address from
[email settings](https://github.com/settings/emails).

## Testing

```sh
podman build --no-cache -f ubuntu.Dockerfile .
podman build --no-cache -f debian.Dockerfile .
podman build --no-cache -f fedora.Dockerfile .
podman build --no-cache -f nosudo.Dockerfile .
```

Each image provisions twice, requires `changed=0` on the second run, and runs
`tests/smoke.sh`. The first three exercise the full sudoed setup including the
Hyprland desktop; Debian also runs the cloud-init lifecycle. The nosudo image
provisions as a user with no sudo on an administrator-prepared base and
asserts the user-space fallbacks. GitHub Actions runs all four plus a native
macOS job on every push.

macOS can't be containerized: `--check` first, then a real run.

## macOS desktop

The completed workstation transition and validation limits are recorded in
[docs/desktop-migration.md](docs/desktop-migration.md).

AeroSpace owns tiling, workspaces and shortcuts. [Window Effects](https://github.com/jobrk/window-effects)
provides shadow removal and active/inactive opacity. Dotfiles owns both configs;
Ansible owns installation and selected native preferences. Ghostty's existing
`local.ghostty` (including fonts and `window-decoration = none`) is preserved.

Install the packages/preferences, then update and stow dotfiles:

```sh
ansible-playbook -i inventory.ini main.yml --tags aerospace,macos-preferences --check --diff
ansible-playbook -i inventory.ini main.yml --tags aerospace,macos-preferences
ansible-playbook -i inventory.ini main.yml --tags dotfiles
```

On a checkout with local edits, update it deliberately and run
`stow --target="$HOME" aerospace window-effects` inside that checkout instead
of letting the dotfiles git task update it.

On a corporate Mac where SIP must remain enabled, keep the default
`window_effects_enabled: false` in `vars/Darwin.yml`. Provisioning skips the
appearance backend, CLI, LaunchAgent and sudoers rule. AeroSpace still provides
tiling, shortcuts and instant workspace switching if company policy permits
its installation and Accessibility access. Windows keep their normal shadows
and opacity. Ansible never changes SIP or boot arguments.

Open AeroSpace and grant its interactive Accessibility authorization. This works
independently of the optional appearance backend:

```sh
open -a AeroSpace
```

The appearance backend is opt-in because it requires Apple Silicon, Xcode Command
Line Tools, and Window Effects' documented SIP/arm64e prerequisites. The playbook
does not currently check SIP before installation: explicitly enabling the helper
can install it successfully even though its backend cannot load. If started in
that state, the watcher retries and logs backend errors. Enable it only when the
prerequisites are satisfied, then install with administrator authentication:

```sh
ansible-playbook -i inventory.ini main.yml --tags window-effects --ask-become-pass \
  -e window_effects_enabled=true -e window_effects_autoload=true
```

The source is pinned to a full commit in `vars/Darwin.yml` and built in
`~/.local/share/window-effects/source`. Backend files are root-owned; the CLI,
LaunchAgent and policy are installed as the desktop user. Config is stowed before
the watcher is installed. `window_effects_autoload=true` adds one hash-pinned
sudoers command: the root-owned loader with no arguments. It permits automatic
recovery after Dock restarts without password prompts. With the default `false`,
provisioning does not manage that rule; a fresh installation then needs manual
loading after login or Dock restart.

After granting AeroSpace Accessibility access, repeat the helper installation
command with `-e desktop_activate=true` to start the watcher. Activation checks
for conflicting window managers and leaves them untouched. The playbook never
changes SIP or restarts Dock automatically.
See the [dotfiles desktop guide](https://github.com/jobrk/dotfiles/blob/main/aerospace/README.md)
for controls and the helper's documentation for upgrades or removal.

`tasks/macos-preferences.yml` versions keyboard repeat, immediate Dock reveal/hide,
menu-bar hiding, stable native Space ordering and native Ctrl+Cmd dragging. Log
out/in or relaunch apps to apply the dragging preference. Whole domains and
unverified animation/shadow keys are not copied.

AeroSpace requires 0.21.3-Beta or newer. Homebrew uses `state: present` and does not
upgrade an installed app on every run. Core behavior is verified on macOS 27.2
(26B123); physical gestures, sleep/wake and external displays remain unverified.
CI validates installation/idempotence without loading code into Dock or granting
Accessibility permissions.

## License

[MIT](LICENSE). Installed packages and external repositories retain their own licenses.
