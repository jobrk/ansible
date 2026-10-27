# Desktop migration

The active desktop is AeroSpace 0.21.3-Beta with Window Effects v0.1.1 on
macOS 27.2 (26B123), Apple Silicon. The old daemons and packages are retired.
The implementation, cutover and retirement are complete. Final recovery checks
pass. Ansible now contains fresh-setup provisioning only; the temporary migration
tasks have been removed.

## Completed

- [x] Implement the small Dock backend, loader, CLI and AeroSpace watcher.
- [x] Add restoration, closed-window cleanup, validation and arm64/arm64e tests.
- [x] Publish a reusable Window Effects repository with source comments and
  general installation/compatibility documentation.
- [x] Version AeroSpace bindings and appearance policy in dotfiles.
- [x] Version packages, native preferences, pinned builds and service lifecycle
  in Ansible, with a dedicated desktop CI job.
- [x] Cut over from yabai/skhd and verify the core setup after the macOS 27 upgrade.
- [x] Archive local legacy configuration, uninstall yabai/skhd, remove their
  LaunchAgents and config links, and disable current/historical service labels.
- [x] Remove legacy configuration packages from dotfiles; preserve unrelated
  Neovim, zsh and local Ghostty changes.
- [x] Remove the temporary migration tasks and keep Ansible focused on fresh
  installations. Existing display managers and autoload rules are preserved.
- [x] Install the reviewed CLI, removing the obsolete hardcoded
  `macOS27Tested: false` diagnostic field.
- [x] Install and load the pinned backend; verify artifact signatures, checksums,
  live shadow/opacity changes, restoration and automatic Dock recovery.
- [x] Remove and verify the absence of the root-owned legacy files:
  `/Library/ScriptingAdditions/yabai.osax` and `/etc/sudoers.d/yabai`.
- [x] Repeat app exclusion and AeroSpace exit/restart checks, verify all nine
  workspace bindings, and restore original workspace placement.
- [x] Confirm user-side provisioning and cleanup idempotence (`changed=0`,
  `failed=0`), including check mode with the old packages absent.

## Ownership and revisions

| Repository | Responsibility | Revision |
|---|---|---|
| Window Effects | Source, tests, installer and compatibility evidence | `ba3b65067d27f562d3cf0be8053a3f77bf5cc101` (Ansible pin) |
| dotfiles | Bindings, appearance policy and Stow packages | `bec9b74` |
| Ansible | Installation, preferences and service lifecycle | `cd54c8a` verified the migration; subsequent changes remove migration-only tasks |

The original cutover used helper `332189a`, dotfiles `728257d` and Ansible
`913df41`. The new helper pin includes the source readability cleanup and macOS
27 evidence; its release version remains v0.1.1.

## Verified behavior

On macOS 26.6.2, the live cutover covered all workspace bindings, sending without
following, both resize axes, app exclusion, restoration and independent
AeroSpace/Dock restart recovery. The final closed-window regression was fixed in
v0.1.1 by checking public WindowServer enumeration before private SkyLight state.

On macOS 27.2 (26B123), both applications started after the OS upgrade/reboot.
Arm64 and arm64e test suites pass. Live tests passed for foreign-window shadow
and opacity changes, restoration, closed-window cleanup, watcher shutdown and
restart, focus dimming between Ghostty and Zen, and automatic Dock recovery.
All eleven managed keyboard/desktop preferences survived. Both configuration
files still resolve to the dotfiles checkout.

The final pinned backend was installed and reloaded successfully. App exclusions
and AeroSpace exit/restart also pass on macOS 27: System Settings floats without
appearance changes, AeroSpace exit restores the managed windows, and restart
reconnects the watcher. All nine workspace bindings pass. The final tests restored
the existing workspace assignments and focus.

See the [helper compatibility record](https://github.com/jobrk/window-effects/blob/main/COMPATIBILITY.md)
for the supported scope. The broader workstation CI has an unrelated
Fedora-without-sudo failure in Neovim provisioning (missing Java); it is not a
desktop migration failure.

## Backups and recovery

The pre-retirement archive is private and outside the repositories:
`~/.local/state/window-effects/cleanup-20261027-220639/`. It contains both legacy
config packages, the local yabai patch, LaunchAgents and the scripting addition.
The earlier cutover backup remains under
`~/.local/state/window-effects/migration-20261027-191837/`.

Tracked legacy config is available from dotfiles revision `728257d`. Rollback
now requires reinstalling yabai/skhd and their privileged components; it is not
just a service toggle. The dotfiles AeroSpace README documents the sequence.
Native Spaces were preserved. SIP and arm64e settings were not changed and remain
necessary for Window Effects.

## Validation limits

Physical shortcuts and Ctrl+Cmd dragging, hover focus with browser/video popups
or native fullscreen, sleep/wake and external-display reconnection are not
claimed as tested. Only a built-in display was available. These remain manual
acceptance checks, separate from the implemented migration and cleanup.

The thin top highlight in Zen is AppKit decoration, separate from WindowServer
shadows. A disposable AppKit experiment proved it removable inside its own app,
but applying that to Zen would require application-side code. Browser injection
and rim removal are outside this project's scope.
