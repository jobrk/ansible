# ansible

Machine provisioning for personal machines (Debian-family, Fedora/RHEL-family,
macOS). Installs packages and toolchains, then clones
[jobrk/dotfiles](https://github.com/jobrk/dotfiles) and stows it. Config files
live in dotfiles only — this repo owns machine state, never file content.

## Usage

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/jobrk/ansible/main/bootstrap.sh)
```

Bootstrap installs ansible, clones or updates this repo, and infers flags:
`ui` skipped over SSH (force with `UI=1`), `-K` only when sudo needs a
password, `become` skipped when non-interactive without sudo. Env overrides:
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

Only applies to Linux — macOS installs everything through Homebrew as the
user. A user-space pass runs after system packages on every run; each task
checks for a command and fills the gap under `~/.local` only when missing.
`~/.local/bin` is first on PATH, so a fallback shadows a later system
install; delete the local copy to hand the command back to the distro.

| Component | With sudo | Without sudo |
|---|---|---|
| Compilers, make, cmake, git, python3, tmux, zsh, unzip, locales | dnf/apt | none — administrator |
| Go, Java 25, .NET 10 SDKs | dnf/apt | none — administrator |
| Hyprland desktop, greetd, Waybar, portals, Zen Browser (`ui`) | dnf/apt + Flatpak | none — administrator |
| fzf, ripgrep, fd, bat, delta, jq, direnv | dnf/apt | pinned release binaries |
| Stow | dnf/apt | built from source (needs make and perl) |
| pipx | dnf/apt | `pip install --user` |
| Tree-sitter CLI | release binary | same; cargo-built when the host glibc is too old |
| zsh as the login shell | chsh | opt-in `--tags handoff`: `~/.bash_profile` hands interactive logins to zsh |
| Rust, Node LTS, Neovim, oh-my-zsh + plugins, fzf-git, alacritty, fonts, tpm, Mason tools, parsers, dotfiles | user-space | same — sudo never needed |

Without sudo, run bootstrap non-interactively and let the smoke test report
anything missing:

```sh
curl -fsSL https://raw.githubusercontent.com/jobrk/ansible/main/bootstrap.sh | bash &&
/bin/zsh -lic 'bash ~/ansible/tests/smoke.sh'
```

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
Ansible. Also edit the seeded `~/.gitconfig.local` (placeholder email).

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
