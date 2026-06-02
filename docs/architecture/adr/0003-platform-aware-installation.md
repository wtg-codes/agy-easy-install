# ADR-0003: Platform-Aware Installation Target Selection

## Status
Accepted

## Context
The Google Antigravity suite needs to run on diverse development environments: standard macOS, standard Linux (Debian, Ubuntu, Fedora, RHEL), containerized ChromeOS environments (Crostini), and Windows via WSL2. Some of these platforms are atomic/immutable (e.g., Fedora Silverblue, Bluefin, Bazzite), where installing packages using standard system package managers (like `apt` or `dnf`) directly to the root filesystem is discouraged, locked, or impossible.

To ensure the best possible native performance, stability, and updates, the installer must select the most appropriate installation target and method based on the host system's constraints and capabilities.

## Decision
We implement a platform-aware installation strategy that dynamically checks system characteristics and determines the recommended target method:
1. **Homebrew**: Recommended for macOS and atomic Linux distributions (like Bluefin). On macOS, it uses Homebrew Casks (`brew install --cask antigravity`). On Linux, it uses the Ublue-OS experimental tap (`brew install ublue-os/experimental-tap/antigravity-linux`) and manages path configurations/symlinks accordingly.
2. **System Package Repositories (APT / DNF)**: Recommended for standard package-based Linux distros. It configures the official Google Antigravity APT or DNF repositories (writing repository files and signing them with GPG keys via `/etc/apt/keyrings` or `/etc/yum.repos.d`) and installs via native package management. This requires `sudo` privileges.
3. **Standalone Tarball (Binary)**: Used as a fallback or default when package managers are unavailable or when user choices restrict repository access. It downloads precompiled official binaries (tarball for Linux, DMG for macOS, EXE for Windows), verifies integrity using SHA-256 checksum comparison, extracts it to the user's home directory (`~/.local/lib/antigravity`), symlinks the binaries to `~/.local/bin`, extracts icons (using a Python ASAR extraction script if necessary), and registers `.desktop` launcher items.

The platform and package detection logic is run during script initialization, and the TUI presents the user with the most optimal, pre-highlighted recommendation based on their operating system.

## Consequences
- **Trade-offs / What becomes easier**:
  - High degree of compatibility across macOS, standard Linux, immutable Linux, ChromeOS, and WSL2.
  - Users get a native installation matching their distro's packages (automatic updates via `apt update` or `brew upgrade`).
  - Safe extraction to user-space (`~/.local/`) when system-level write access is constrained or when a non-sudo install is preferred.
- **Trade-offs / What becomes harder**:
  - The script must maintain multiple independent code branches in `30_installers.sh` for each installer type, increasing maintenance surface area.
  - Tracking installation states and managing uninstall/updates becomes highly complex, requiring a JSON state tracker (`~/.config/antigravity/install.json`) to remember which method was used to install the software.
  - Testing matrix is significantly larger, requiring validation across multiple operating systems, distros, and container environments.
