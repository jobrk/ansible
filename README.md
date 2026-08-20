# ansible

Machine provisioning for personal machines (Debian-family, Fedora/RHEL-family,
macOS). Installs packages, shell frameworks, and toolchains, then clones
[jobrk/dotfiles](https://github.com/jobrk/dotfiles) and stows it. Config files
live in dotfiles only — this repo owns machine state, never file content.

## Usage

```sh
# ansible via pipx (linux) or brew (mac)
git clone https://github.com/jobrk/ansible ~/ansible
cd ~/ansible
ansible-playbook main.yml -K            # -K prompts for sudo (linux)
```

Re-run any time to converge; a second run reports `changed=0`.

Partial runs by tag: `--tags zsh,tmux`, `--skip-tags ui`, `--skip-tags become`
(everything sudo-free).

## Secrets (optional)

```sh
cp vars/secrets.yml.example vars/secrets.yml
$EDITOR vars/secrets.yml                 # fill in values (file is gitignored)
ansible-vault encrypt vars/secrets.yml
ansible-playbook main.yml --ask-vault-pass
```

Writes `~/.zsh_secrets` (0600), sourced by the dotfiles zshrc. Without a
vault the step is skipped and `~/.zsh_secrets` can be managed by hand.

## After the playbook

- launch `nvim` once (lazy.nvim bootstraps plugins, Mason pulls LSP servers)
- inside tmux: `prefix + I` if tpm plugins didn't auto-install
- edit the seeded `~/.gitconfig.local` (placeholder email) and other
  `*.local` files (templates come from dotfiles)

## Testing

```sh
docker build -f debian.Dockerfile .     # full playbook + idempotency gate
docker build -f fedora.Dockerfile .
```

macOS can't be containerized: `ansible-playbook main.yml --check` first,
then a real run.
