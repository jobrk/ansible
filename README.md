# ansible

Machine provisioning for personal machines (Debian-family, Fedora/RHEL-family,
macOS). Installs packages, shell frameworks, and toolchains, then clones
[jobrk/dotfiles](https://github.com/jobrk/dotfiles) and stows it. Config files
live in dotfiles only — this repo owns machine state, never file content.

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
skipped when non-interactive without sudo. Env overrides: `GH_TOKEN`
(private-repo auth via credential store), `SKIP_TAGS`, `ANSIBLE_REPO`,
`ANSIBLE_DEST`.

Re-run any time to converge; a second run reports `changed=0`.

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

Paste `cloud-init.yml` as user data at droplet creation: makes the user
(SSH keys imported from GitHub), then runs bootstrap. The machine is
provisioned before first login. Its piped bootstrap command is safe because the
created user has passwordless sudo. Secrets stay manual by design.

## Private repos

If the repos are made private, set a fine-grained read-only PAT before
bootstrapping: `GH_TOKEN=github_pat_... bash bootstrap.sh` — or run
`gh auth login` first and use the manual flow.

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

- launch `nvim` once (lazy.nvim bootstraps plugins, Mason pulls LSP servers)
- inside tmux: `prefix + I` if tpm plugins didn't auto-install
- edit the seeded `~/.gitconfig.local` (placeholder email) and other
  `*.local` files (templates come from dotfiles)

## Testing

```sh
podman build --no-cache -f ubuntu.Dockerfile .  # headless playbook + idempotency gate
podman build --no-cache -f fedora.Dockerfile .
```

Use `docker` instead of `podman` when Docker is running.

macOS can't be containerized: `ansible-playbook -i inventory.ini main.yml --check` first,
then a real run.
