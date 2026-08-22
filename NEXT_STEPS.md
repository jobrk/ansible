# Completed improvements

Keep the setup focused while making the supported development workflows work
completely on a new macOS, Ubuntu, or Fedora machine.

## Neovim

- [x] Remove the bulk Tree-sitter build. Let the existing `FileType` hook
  install each parser the first time that language is opened, avoiding 37
  parser builds and their logs during the first Neovim launch.
- [x] Keep Mason's current tool list. Remove something only when it is a true
  duplicate with no separate editor role.
- [x] Add `jdtls` to Mason's installed tools. The Java configuration currently
  enables it but a fresh machine does not install its executable.

## Toolchains

- [x] Provision the .NET 10 LTS SDK using the platform package manager. The SDK
  already includes the .NET and ASP.NET Core runtimes, so do not install those
  separately.
  - macOS: Homebrew `dotnet` formula.
  - Ubuntu: `dotnet-sdk-10.0` from Ubuntu's package feed.
  - Fedora: `dotnet-sdk-10.0` from Fedora's package feed.
  - Verify with `dotnet --info` and `dotnet --list-sdks`.
- [x] Provision Java 25 LTS as the default development JDK.
  - macOS: Homebrew `openjdk@25` formula, selected in `.zshrc`.
  - Ubuntu: `openjdk-25-jdk`.
  - Fedora: `java-25-openjdk-devel`.
  - Verify both `java -version` and `javac -version`.
  - Use each project's Maven or Gradle wrapper; do not add global Maven or
    Gradle installations. The macOS migration removes an old global Gradle and
    unversioned OpenJDK formula before installing Java 25.
- [x] Explicitly provision Python and standard virtual-environment support.
  - macOS: Homebrew `python@3.14`.
  - Ubuntu: `python3` and `python3-venv`.
  - Fedora: `python3`.
  - Use a project virtual environment or the existing `uv`; never install
    project dependencies globally or with `sudo pip`.
  - Keep `pipx` for standalone Python command-line applications.

## Testing

- [x] Extend the Ubuntu and Fedora container smoke tests to verify:
  - Go and Tree-sitter are executable.
  - .NET, Java/Javac, and Python are executable and report the intended major
    versions.
  - Python can create and run a temporary virtual environment.
  - Bat recognizes `Catppuccin-mocha` without warnings.
  - A fresh Neovim launch succeeds.
  - The dotfiles repository and Neovim submodule remain clean afterward.

## Tmux sessionizer

- [x] Remove `eval` and read configured search paths safely as an array.
- [x] Handle spaces, blank lines, comments, and missing directories.
- [x] Keep the full-screen FZF workflow; do not move it into a tmux popup.
- [x] Avoid leaving behind a temporary tmux window when switching sessions.

## Not planned

- Pre-cloning repositories
- Trimming Mason merely to reduce the installation count
- Ansible Vault or another secrets system
- Backup logic
- Another runtime-manager abstraction
- Elaborate CI or macOS VM testing

## References

- [.NET installation on Ubuntu](https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu-decision)
- [.NET installation on Fedora](https://learn.microsoft.com/en-us/dotnet/core/install/linux-fedora)
- [.NET installation on macOS](https://learn.microsoft.com/en-us/dotnet/core/install/macos)
- [Oracle Java support roadmap](https://www.oracle.com/uk/java/technologies/java-se-support-roadmap.html)
- [Python virtual environments](https://docs.python.org/3/library/venv.html)
