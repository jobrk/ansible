# ansible

Machine provisioning for personal machines (Debian-family, Fedora/RHEL-family,
macOS). Installs packages, shell frameworks, and toolchains, then clones
[jobrk/dotfiles](https://github.com/jobrk/dotfiles) and stows it. Config files
live in dotfiles only — this repo owns machine state, never file content.

The development toolchains include Go, Rust, Node LTS, .NET 10 LTS, Java 25
LTS, Python with virtual environments and pipx, plus Tree-sitter and Neovim.

## Usage

From an interactive shell on any machine (Debian/Ubuntu, Fedora/RHEL, macOS):

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/jobrk/ansible/main/bootstrap.sh)
```

Process substitution keeps standard input attached to the terminal so Ansible
can request the sudo password when required. The piped form is suitable only
when sudo is unnecessary or already passwordless.

The script installs ansible (pipx/brew, bootstrapping brew on a bare mac),
clones or updates this repo, and runs the playbook with flags inferred from
the machine: `ui` skipped in SSH sessions (force with `UI=1`), `-K` only when
sudo needs a password and stdin is a tty, `become` skipped when non-interactive
without sudo. A local Linux console installs the complete Hyprland desktop. Env
overrides: `SKIP_TAGS`, `ANSIBLE_REPO`, `ANSIBLE_DEST`.

On Linux, a user-space pass (`--tags userspace`) runs after system packages on
every run, sudoed or not. Each task checks for a command and installs into
`~/.local` only when it is missing, so on a sudoed machine everything skips,
and on any machine the run heals commands the system stops providing. The
same check-then-fill approach covers release binaries listed under Without
sudo, pipx via `pip install --user`, and a cargo build of the Tree-sitter CLI
when the release binary needs a newer glibc than the host has. Fallbacks in
`~/.local/bin` shadow later system installs because it is first on PATH;
delete the local copy to hand a command back to the distro package.

### Without sudo

On a machine where the user has no sudo access, run:

```sh
curl -fsSL https://raw.githubusercontent.com/jobrk/ansible/main/bootstrap.sh | bash &&
/bin/zsh -lic 'bash ~/ansible/tests/smoke.sh'
```

The pipe keeps the run non-interactive, so bootstrap skips `become`; SSH also
skips `ui`. Everything user-space converges: toolchains, dotfiles, and pinned
release binaries into `~/.local/bin` for commands the system lacks (fzf,
ripgrep, fd, bat, delta, jq, direnv, and Stow built from source when make and
perl exist). When zsh cannot be made the login shell, interactive bash logins
hand over to zsh instead. Git and either Ansible or pipx must already be
available; compilers, tmux, zsh itself, and the UI stack still require an
administrator. The smoke test reports anything missing.

The Linux UI setup installs Hyprland with Waybar, clipboard history, portals,
audio, notifications, graphical authentication, and Qt Wayland support. Zen is
installed from Flathub as the default browser. It keeps an existing compatible
display manager or adds greetd when needed, then selects Hyprland as the user's
next desktop session. The dotfiles provide the black Catppuccin Mocha
configuration. Zen's supported Flatpak system-configuration extension applies
the portable preferences and add-ons used on the primary Mac: compact mode,
right-side tabs, Dark Reader, uBlock Origin, and Vimium.

Re-run any time to converge; a second run reports `changed=0`. Neovim follows
the latest stable GitHub release and upgrades when that release changes.

Manual equivalent:

```sh
git clone https://github.com/jobrk/ansible ~/ansible
cd ~/ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory.ini main.yml -K
```

Partial runs by tag: `--tags zsh,tmux`, `--tags userspace`, `--skip-tags ui`,
`--skip-tags become` (everything sudo-free).

## Over SSH

Copy `inventory.example.ini` to a private inventory, list your machines, then
from any control machine:

```sh
ansible-playbook -i my-inventory.ini main.yml -e target=workstations -K
```

Targets need SSH access and Python; everything else is pushed over the
connection. `-e target=droplet` hits a single host. Without `-e target`
the playbook runs locally as before. Headless targets: add
`--skip-tags ui`. First-run macOS targets are better provisioned locally
(brew bootstrap is interactive over SSH).

## Cloud (DigitalOcean, etc.)

Paste `cloud-init.yml` as user data at droplet creation. It creates the `josh`
user with passwordless sudo, imports SSH keys from GitHub, and configures the
`en_US.UTF-8` locale. It also prevents SSH clients from replacing that locale
with one unavailable on the server, then runs the bootstrap script without UI
packages as `josh`. SSH in as `josh` after cloud-init finishes.

## Secrets

```sh
mkdir -p ~/.config/zsh
cp ~/projects/dotfiles/templates/secrets.zsh.example ~/.config/zsh/secrets.zsh
chmod 600 ~/.config/zsh/secrets.zsh
$EDITOR ~/.config/zsh/secrets.zsh
```

The file is sourced by the dotfiles Zsh configuration and is never tracked or
managed by Ansible.

## Local configuration

Edit the seeded `~/.gitconfig.local` (placeholder email) and any other
machine-local files as needed.

## Testing

```sh
podman build --no-cache -f ubuntu.Dockerfile .
podman build --no-cache -f debian.Dockerfile .
podman build --no-cache -f fedora.Dockerfile .
podman build --no-cache -f nosudo.Dockerfile .
```

Each image runs the playbook twice, requires `changed=0` on the second run, and
runs `tests/smoke.sh`. The nosudo image instead provisions as a user with no
sudo on a Fedora base an administrator prepared, and asserts the user-space
fallbacks: every command resolves, Stow and fzf came from `~/.local/bin`,
dotfiles are stowed, and bash logins hand over to zsh. The other three
exercise local-console UI provisioning; Debian
also runs the headless cloud-init lifecycle and verifies its status,
locale, user, and imported GitHub SSH keys. The
playbook installs every Neovim plugin, Mason tool, and Tree-sitter parser; the
smoke test verifies them and compiles and runs each language toolchain. It also
validates the Hyprland, Waybar, clipboard, browser, shell, and tmux setup, and
checks Corepack/pnpm, Bat, and repository cleanliness. Desktop checks run only
when Hyprland is installed; they validate binaries and configuration, not a
live graphical session or hardware. GitHub Actions runs these checks for
Ubuntu, Debian, Fedora, and Fedora without sudo, plus a native macOS job, on
every push and pull request. Use `docker` instead of `podman` when Docker is
running.

macOS can't be containerized: `ansible-playbook -i inventory.ini main.yml --check` first,
then a real run.
