# Ansible status audit

`ok` means the task inspected state or found the requested state already in
place. `changed` means it mutated the machine. `skipped` means its OS, tag, or
state condition did not apply. Ubuntu and Fedora container runs both converged
to `changed=0` on their second pass.

| Task | Correct status behaviour |
| --- | --- |
| Gathering facts / load OS variables | Always `ok`; read-only. |
| Check for Homebrew | `ok` on macOS; `skipped` elsewhere. |
| Install Homebrew | `changed` only when absent; otherwise `skipped`. |
| apt, dnf, Homebrew and cask packages | `changed` when packages are installed, upgraded, or superseded formulae are removed; `ok` when current; wrong platforms or excluded tags are `skipped`. macOS removes unversioned Java and global Gradle before installing Java 25; projects use their Gradle wrappers. |
| Create `~/.local/bin` and Debian binary links | `changed` when created or corrected; otherwise `ok`; links are `skipped` when the distro has none. |
| Check rustup / git-absorb / Alacritty / Neovim | `ok`; these are read-only existence probes and Linux-only probes are `skipped` on macOS. |
| Download and run Rust installer | `changed` only on first install; otherwise `skipped`. Temporary installer removal is `changed` only if a file remains. |
| Cargo installs for git-absorb and Alacritty | `changed` only when the binary is absent; otherwise `skipped`. |
| Check fnm | Always `ok`, including when absent, because failure is an expected probe result. |
| Download and run fnm installer | `changed` only when fnm is absent; otherwise `skipped`. Installer removal and Linux symlink are normal file-state results. |
| Install Node LTS | `changed` when fnm installs a new LTS; `ok` when fnm reports it is already installed. |
| Check Tree-sitter version | Always `ok`; absence or a wrong version is captured as probe data rather than a task failure. |
| Download, extract and remove Tree-sitter archive | Run only for a missing/wrong version. Mutating steps report `changed`; executable mode may truthfully be `ok` when the archive already supplied mode `0755`. Entire block is `skipped` once the requested version exists. |
| Set Zsh as default shell | `changed` only when the account shell differs; otherwise `ok`; excluded by `--skip-tags become`. |
| Check/install Oh My Zsh | Probe is `ok`; download/install are `changed` only when absent and otherwise `skipped`; installer cleanup reflects actual file removal. |
| Install Zsh plugins/theme | Each Git checkout is `changed` when cloned or updated and `ok` at its requested revision. |
| Generate FZF integration | Always `ok`; it is a read-only command and now also runs in check mode so the following comparison is accurate. |
| Install generated/packaged FZF integration | Exactly one branch applies. Copy is `changed` only when content differs, otherwise `ok`; the other branch is `skipped`. |
| Install Neovim tarball and links | `changed` on first install or explicit `nvim_force`; otherwise the install block is `skipped`. The existence policy intentionally does not auto-upgrade Neovim. |
| Create/download font | Directory uses normal file-state results. Archive is `changed` only if the font is missing, then notifies the cache handler. Entire block is `skipped` on macOS or without the `ui` tag. |
| Refresh font cache | Runs and reports `changed` only after a new font was unpacked. |
| i3 message | Always `ok`; informational and Linux/UI-only. |
| macOS tap, skhd/yabai, and defaults | Homebrew/defaults modules report `changed` only when state differs and `ok` after convergence; all are `skipped` off macOS or without `ui`. |
| Create/clone/configure dotfiles | Directory and Git modules report actual mutations. Git config reports `changed` only when values differ. |
| Stow dotfiles | `changed` only when Stow reports `LINK`/`UNLINK`; otherwise `ok`. Conflicts still fail instead of being mislabeled. |
| Check/build Bat theme cache | Check is always `ok`; build is `changed` only when the named theme is missing, otherwise `skipped`. |
| Install TPM | Git module is `changed` for clone/update and `ok` when current. |
| Install tmux plugins | Always checks every configured plugin; `changed` only when TPM prints an installation, otherwise `ok`. |
| Create local config directories / seed templates | `changed` only for missing directories/files; templates use `force: false`, so user edits remain `ok` and untouched. |

The audit fixed four misleading cases: the FZF dry-run probe, Tree-sitter's
version-blind existence check, TPM checking only one plugin, and an always-run
font-cache command. The remaining `skipped` installer tasks on a converged run
are deliberate: their precondition is already satisfied. In `--check` mode,
command tasks that cannot predict an outcome are also deliberately `skipped`;
their real-run status is covered above.
