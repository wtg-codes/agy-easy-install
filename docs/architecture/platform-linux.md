# Linux Support — Architecture Notes

> **Status:** ✅ Tested — primary platform.
> **Last updated:** 2026-05-13

---

## Overview

Linux is the primary and fully-tested platform. All three install methods work. This is the umbrella doc; see the sub-platform docs for distro-specific details:

| Sub-Platform | Doc | Package Manager | Status |
|---|---|---|---|
| Debian/Ubuntu family | [platform-linux-apt.md](platform-linux-apt.md) | APT | ✅ Tested |
| Fedora/RHEL family | [platform-linux-dnf.md](platform-linux-dnf.md) | DNF | ✅ Tested |
| Atomic/Immutable | [platform-linux-atomic.md](platform-linux-atomic.md) | Homebrew / Tarball | ✅ Tested |

---

## Detection

```bash
PLATFORM=$(uname -s)  # Returns "Linux"
```

### Distribution Detection (`detect_distro`)

Reads `/etc/os-release` to identify the distribution:

```bash
# Source the file and grab $ID
. /etc/os-release
DISTRO="$ID"
```

### Recommendation Logic (`detect_platform`)

The script auto-recommends the best install method:

```
Is Atomic?
├── YES → Homebrew (if available), else Tarball
└── NO
    ├── Has Homebrew? → Homebrew
    ├── Has APT or DNF? → System Repo
    └── Default → Tarball
```

---

## Shared Linux Behavior

### Chrome Detection Priority

1. **Flatpak Chrome** (system) → `/var/lib/flatpak/app/com.google.Chrome/.../chrome`
2. **Flatpak Chrome** (user) → `~/.local/share/flatpak/app/com.google.Chrome/.../chrome`
3. **System package** → `google-chrome-stable`, `google-chrome`, `chromium`, `chromium-browser`

### PATH Setup

Shell detection (`src/20_platform.sh:1-49`):
- Zsh → `~/.zshrc`
- Fish → `~/.config/fish/config.fish`
- Bash (default) → `~/.bashrc`
- Idempotent — checks before writing

### `.desktop` File

Created at:
- `~/.local/share/applications/google-antigravity.desktop` (system apps)
- `$(xdg-user-dir DESKTOP)/google-antigravity.desktop` (desktop shortcut)

Post-install trust: `chmod +x`, `gio set metadata::trusted true`, `update-desktop-database`.

### `gum` Bootstrap

- `Linux_x86_64` for Intel/AMD
- `Linux_arm64` for ARM

### SHA-256

Uses `sha256sum` from GNU Coreutils (always available).

---

## Known Quirks (All Linux)

| Quirk | Detail |
|---|---|
| **Flatpak Chrome sandboxing** | Must use raw binary path, not `flatpak run` |
| **Wayland** | Some Electron apps need `--ozone-platform-hint=auto` |
| **SELinux (Fedora/RHEL)** | Tarball binaries in `~/.local` may need context labels |
