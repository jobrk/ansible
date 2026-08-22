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
for root, passwordless sudo, or another non-interactive environment.

The script installs ansible (pipx/brew, bootstrapping brew on a bare mac),
clones or updates this repo, and runs the playbook with flags inferred from
the machine: `ui` skipped on headless Linux (no `$DISPLAY`; force with
`UI=1`), `-K` only when sudo needs a password and stdin is a tty, `become`
skipped when non-interactive without sudo. Env overrides: `SKIP_TAGS`,
`ANSIBLE_REPO`, `ANSIBLE_DEST`.

Re-run any time to converge; a second run reports `changed=0`. Neovim follows
the latest stable GitHub release and upgrades when that release changes.

Manual equivalent:

```sh
git clone https://github.com/jobrk/ansible ~/ansible
cd ~/ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory.ini main.yml -K
```

Partial runs by tag: `--tags zsh,tmux`, `--skip-tags ui`, `--skip-tags become`
(everything sudo-free).

## Cloud (DigitalOcean, etc.)

Paste `cloud-init.yml` as user data at droplet creation. It creates the `josh`
user with passwordless sudo, imports SSH keys from GitHub, and configures the
`en_US.UTF-8` locale. It also prevents SSH clients from replacing that locale
with one unavailable on the server. SSH in as `josh`, then run the bootstrap
command from [Usage](#usage). Ansible installs zsh and makes it the default
shell. Secrets stay manual by design.

## Secrets

```sh
mkdir -p ~/.config/zsh
cp ~/projects/dotfiles/templates/secrets.zsh.example ~/.config/zsh/secrets.zsh
chmod 600 ~/.config/zsh/secrets.zsh
$EDITOR ~/.config/zsh/secrets.zsh
```

The file is sourced by the dotfiles Zsh configuration and is never tracked or
managed by Ansible.

## After the playbook

- launch `nvim`; its plugins, Tree-sitter parsers, and Mason tools are already
  installed
- inside tmux: `prefix + I` if tpm plugins didn't auto-install
- edit the seeded `~/.gitconfig.local` (placeholder email) and other
  `*.local` files (templates come from dotfiles)

## Testing

```sh
podman build --no-cache -f ubuntu.Dockerfile .
podman build --no-cache -f debian.Dockerfile .
podman build --no-cache -f fedora.Dockerfile .
```

Each image runs the playbook twice, requires `changed=0` on the second run, and
runs `tests/smoke.sh`. The Debian image also runs the full cloud-init lifecycle
and verifies its status, locale, user, and imported GitHub SSH keys. The
playbook installs every Neovim plugin, Mason tool, and Tree-sitter parser; the
smoke test verifies them and compiles and runs each language toolchain. It also
validates shell/tmux setup and checks Corepack/pnpm,
Bat, and repository cleanliness. GitHub Actions runs these checks for Ubuntu,
Debian, and Fedora, plus a native macOS job, on every push and pull request. Use
`docker` instead of `podman` when Docker is running.

macOS can't be containerized: `ansible-playbook -i inventory.ini main.yml --check` first,
then a real run.
