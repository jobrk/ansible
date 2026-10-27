# Window Effects and desktop migration

Build a small macOS companion to AeroSpace for window shadows and opacity, then
make the complete desktop reproducible through the existing repository suite.
Window Effects owns appearance; AeroSpace owns tiling, workspaces and shortcuts.

## Repository responsibilities

| Repository | Owns |
|---|---|
| `~/projects/window-effects` | Source, tests, releases, installation interface and compatibility evidence |
| `~/projects/dotfiles` | AeroSpace bindings, Window Effects appearance policy, Stow selection and user documentation |
| `~/projects/ansible` | Package installation, pinned Window Effects build, macOS preferences and service lifecycle |

## Completed implementation

1. [x] Prove direct SkyLight access against an owned window and a separate process.
   Direct cross-process writes returned success but readback did not change.
   Own-process opacity works; no-shadow tags require Dock even for owned windows.
   The one-off probe was retired after this investigation; integration tests cover
   the rejected setter and rollback behavior.
2. [x] Implement a narrow Dock payload and loader with attributed
   upstream code, keeping all window policy outside Dock.
3. [x] Add apply/restore/doctor/watch commands and installation instructions.
4. [x] Finish tests and perform a live Dock test (administrator-authenticated loading).
   Own backend changed and restored a separate process's shadow and alpha with
   yabai's daemon stopped. Arm64 and arm64e integration tests pass.
5. [x] Commit a usable release with explicit compatibility evidence and limits.

## Repository integration and cutover

6. [x] Complete and commit the **dotfiles** profile.
   AeroSpace and Window Effects policies are Stow-managed on macOS. Smoke tests
   pass and runtime config validation corrected a quoted regex. Ghostty's local
   settings and unrelated Neovim, zsh and yabai edits were preserved. Rollback is
   documented in `dotfiles/aerospace/README.md`.

7. [x] Complete and commit **Ansible** provisioning.
   `https://github.com/jobrk/window-effects` is public. Ansible fetches an immutable
   source revision, builds signed artifacts, installs root-owned backend files,
   stows policy before installing the user watcher, and supports explicit autoload
   and service activation. Administrator-authenticated installation succeeded.
   It neither changes SIP nor removes the old packages.

8. [x] Finish **combined desktop CI verification**.
   Helper arm64/arm64e tests, GitHub helper/dotfiles checks, Stow smoke tests,
   Ansible lint/syntax/check mode and local user-side installation/idempotence pass.
   The dedicated macOS desktop job passed root installation and idempotence
   (`changed=0`, `failed=0`) in run 40561726184 (including the 0.1.1 pin). CI selects Python 3.14 after the
   original runner Python 3.15 crashed Ansible before provisioning. The broader
   Fedora-without-sudo job separately fails Neovim provisioning because Java is
   missing; that is outside this desktop migration.

9. [x] Perform the **live cutover on macOS 26.6.2**.
   The old services are stopped and disabled, their resident Dock code is unloaded,
   and AeroSpace plus the watcher are active. Tested actual shadow/opacity readback,
   all workspace bindings, send-without-following, both resize axes, app exclusion,
   appearance restoration and independent AeroSpace/Dock restart recovery. Details
   are recorded below. Existing packages, native Spaces,
   configuration and the old sudoers rule remain available for rollback.

The final cleanup check exposed stale private API data for closed windows.
Version 0.1.1 validates journal entries against the public WindowServer list; its
arm64/arm64e regression tests and helper CI pass. Ansible is pinned to that fix.
The 0.1.1 payload is installed and active; live foreign-window cleanup, automatic
Dock recovery and focus/opacity updates pass with no stale journal entries.

## Remaining acceptance work

10. [ ] Complete daily-use checks on this Mac.
    Verify physical shortcuts, hover focus with popups/native video fullscreen,
    Ctrl+Cmd dragging after app relaunch, logout/login, sleep/wake and external
    display reconnection. Only one built-in display was connected during testing.

11. [ ] Verify **macOS 27** on the actual target build.
    Core checks now pass on **macOS 27.2 (26B123)**; details are below and in the
    [Window Effects compatibility record](https://github.com/jobrk/window-effects/blob/main/COMPATIBILITY.md).
    App exclusions, AeroSpace exit/restart and the remaining daily-use checks
    still need to be repeated on this build.

12. [ ] Retire the old setup after acceptance.
    Remove obsolete yabai/skhd packages, scripting addition files and their own
    sudoers rule after daily-use acceptance. Keep documented rollback until then.
    **Do not re-enable SIP while using this backend**; it still needs Dock injection.

## Tested revision set

The live v0.1.1 cutover used Window Effects source
`332189a4e9e1ddc98ecab230717a5a27b84b96a3`, dotfiles `728257d` and Ansible
`913df41`. The helper remains pinned to that tested implementation. Its public
repository now carries general installation and compatibility documentation;
workstation-specific migration history is kept here.

The native top highlight visible in Zen is separate from the WindowServer shadow.
An isolated AppKit experiment on macOS 26.6.2 removed that highlight with
`drawsDecorationView = NO` on the titlebar container and restored the original
value. Applying it to Zen would require an application-side change. No browser
injection or rim-removal mechanism is part of the deployed helper.

## macOS 27 update verification

After the upgrade to macOS 27.2 (26B123), AeroSpace 0.21.3-Beta and the Window
Effects v0.1.1 watcher started automatically. The installed backend still matches
the signed artifacts built from `332189a4e9e1ddc98ecab230717a5a27b84b96a3`.
Verification used helper checkout `174599a`, dotfiles `728257d` and Ansible
`0bed8a6`; the provisioning pin remains unchanged.

Both arm64 and arm64e test suites pass. Live checks passed for foreign-window
shadow/opacity changes, restoration, closed-window cleanup, watcher shutdown and
restart, focus dimming between Ghostty and Zen, and automatic backend recovery
after Dock restart. Window Effects is loaded in Dock; yabai's payload is absent. All eleven
managed keyboard/desktop preferences retained their expected values, and both
configuration files still resolve to the dotfiles checkout.

The installed CLI's `macOS27Tested: false` field is historical hardcoded metadata,
not a runtime failure; its removal is already in the helper's newer source.
Yabai 7.1.25 and skhd 0.3.9 remain installed, with their current services disabled
and neither daemon running. No legacy files were removed during this check.
