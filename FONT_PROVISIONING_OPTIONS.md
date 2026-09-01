# Private font provisioning options

## Goal

Install the four Berkeley Mono Nerd Font faces used by Alacritty on any personal
machine without publishing the licensed files or leaving a broad credential on
the machine.

## Options

### 1. Private GitHub Release — recommended

- Put one `berkeley-mono-nerd-font.tar.xz` asset in a dedicated private
  `machine-assets` repository. Do not commit the archive to Git history.
- Keep its SHA-256 checksum in Ansible; the checksum is not secret.
- For an interactive setup, authenticate with `gh auth login --web`, download
  the release asset, install it, then optionally run `gh auth logout`.
- For automation, provide a fine-grained `GH_TOKEN` restricted to that one
  repository with read-only Contents access. Ansible downloads the asset with
  `no_log: true`, verifies it, installs it under `~/.local/share/fonts`, removes
  the archive, and refreshes Fontconfig.
- If no token is available, provisioning remains successful and Iosevka stays
  as the fallback.

This is the best balance of availability, automation, and low maintenance for
the current GitHub-based setup.

### 2. Private DigitalOcean Space

- Store the archive as a private object.
- Generate a short-lived presigned URL from any authenticated device.
- Pass only that URL to the provisioning run; Ansible suppresses it from logs,
  verifies the checksum, and discards the downloaded archive.
- This is the best option for an unattended cloud-init run because the URL can
  expire after a few minutes.

Do not put a permanent Spaces key in cloud-init. User data and instance files
are readable by root, and the key would outlive the installation.

### 3. Password-manager attachment

- Store the archive as an attachment in an existing password-manager vault.
- Sign in from the new machine, download it with the provider's CLI or web UI,
  then run a local Ansible font-install tag.
- This has the smallest access scope but requires an interactive vault login
  and adds a password-manager CLI if full automation is wanted.

This is a good choice when the password manager is already the normal recovery
path from an unknown machine.

### 4. Ansible Vault

- A Vault-encrypted variable file can hold a narrowly scoped download token.
- Run with `--ask-vault-pass`, or obtain the Vault password from a password
  manager at runtime.
- Vault protects the token in the repository, but does not solve the bootstrap
  problem: another secret is still required to decrypt it.

Do not store the font archive in the public repository, even encrypted. It adds
large opaque Git history and risks conflicting with the licence's distribution
terms. A private release or object store is a clearer boundary.

## SSH private keys

Do not distribute one SSH private key to every machine, even through Ansible
Vault. Vault only protects the key at rest before provisioning; the same
long-lived key is then present in plaintext on every target. One compromised
machine would require rotating every machine and would make access difficult to
attribute.

Prefer, in order:

1. A fine-grained read-only token for downloading the private asset.
2. A new SSH key generated on each machine, with only its public key registered.
3. Temporary SSH-agent forwarding to a trusted machine for an interactive task.

If a private key must be escrowed for recovery, keep it in a password manager or
hardware-backed secret store and do not install it automatically on every host.

## Proposed automation

1. Build an archive containing only these faces:
   - `ExtraCondensed`
   - `ExtraCondensed ExtraBold`
   - `ExtraCondensed Oblique`
   - `ExtraCondensed ExtraBold Oblique`
2. Upload it as a release asset in a dedicated private repository.
3. Add an optional `private-fonts` Ansible task that accepts `GH_TOKEN`, performs
   a checksum-verified download, installs the faces, and refreshes Fontconfig.
4. Seed the Berkeley Mono Alacritty settings only when the font is present;
   otherwise retain the current Iosevka configuration.
5. Test both paths: public CI verifies the fallback, while a local authenticated
   smoke test verifies Berkeley Mono with `fc-match`.

For routine use, the only extra input would be an interactive GitHub login or a
temporary `GH_TOKEN`. Fully unattended installation necessarily requires giving
the new machine some credential; a short-lived presigned URL is safest for that
case.

## Official references

- [GitHub release assets](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
- [`gh release download`](https://cli.github.com/manual/gh_release_download)
- [GitHub fine-grained access tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
- [DigitalOcean Spaces presigned URLs](https://docs.digitalocean.com/products/spaces/how-to/set-file-permissions/)
- [Bitwarden CLI attachments](https://bitwarden.com/help/cli/)
- [1Password CLI in scripts](https://developer.1password.com/docs/cli/secrets-scripts)
