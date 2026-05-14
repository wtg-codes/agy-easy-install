# Linux (Atomic/Immutable) — Bluefin, Silverblue, Bazzite

> **Status:** ✅ Tested (Bluefin)
> **Last updated:** 2026-05-13
> **Parent:** [platform-linux.md](platform-linux.md)

---

## What Are Atomic Desktops?

Atomic (immutable) Linux desktops use `rpm-ostree` or similar systems to manage the root filesystem as a versioned, read-only image. The base OS is updated atomically — either the entire update applies or it doesn't.

**Key principle:** Don't install software to the host. Use Homebrew, Flatpak, Distrobox, or `~/.local/` instead.

---

## Supported Distributions

| `$DISTRO` / Detection | Name | Based On | Tested? |
|---|---|---|---|
| `bluefin` | Universal Blue Bluefin | Fedora Atomic | ✅ Tested |
| `bazzite` | Universal Blue Bazzite | Fedora Atomic | ⚠️ Expected |
| `/run/ostree-booted` exists | Fedora Silverblue | Fedora Atomic | ⚠️ Expected |
| `/run/ostree-booted` exists | Fedora Kinoite | Fedora Atomic | ⚠️ Expected |
| NixOS | NixOS | Nix | ❌ Not supported |
| Vanilla OS | Vanilla OS 2 | Debian Atomic | ❌ Not supported |

---

## Detection

```bash
# src/20_platform.sh:198-202
IS_ATOMIC="no"
if [ -d /run/ostree-booted ] || [ "$DISTRO" = "bluefin" ] || [ "$DISTRO" = "bazzite" ]; then
    IS_ATOMIC="yes"
    DISTRO_PRETTY="${DISTRO_PRETTY} (Atomic)"
fi
```

System info dashboard shows:
```
OS:   Bluefin (Version: 43.20260505) (Atomic) (x86_64)
Best: ★ Homebrew
```

---

## Why APT/DNF Don't Work Here

| Problem | Detail |
|---|---|
| **`/usr` is read-only** | Can't write to `/usr/bin/`, `/usr/lib/`, etc. |
| **No `apt`** | These are Fedora-based, not Debian-based |
| **`dnf` is missing or crippled** | Not available on image-based systems |
| **`rpm-ostree install`** | Works but requires a reboot and is strongly discouraged for user apps |
| **Package layering breaks updates** | Each layered package makes OS updates slower and more fragile |

---

## Recommended Install Hierarchy

```
1. Homebrew          ← Our script recommends this
2. Tarball           ← Fallback (installs to ~/.local/)
3. rpm-ostree        ← NEVER (against Atomic philosophy)
```

### Why Homebrew is Best Here

- Installs to `/home/linuxbrew/.linuxbrew/` — writable, user-owned
- No `sudo` needed
- Doesn't touch the immutable root filesystem
- Automatic PATH integration
- Used by Bluefin's official documentation as the primary CLI tool installer

### Tarball Also Works

- Installs to `~/.local/lib/antigravity/` and `~/.local/bin/`
- Both are writable on Atomic systems
- No system modification required

---

## Recommendation Logic

```bash
# src/20_platform.sh:204-205
if [ "$IS_ATOMIC" = "yes" ]; then
    if [ "$HAS_BREW" = "yes" ]; then RECOMMENDED="1"  # Homebrew
    else RECOMMENDED="3"                                # Tarball
    fi
fi
```

**System Repo is NEVER recommended on Atomic.** Even if `dnf` were somehow available, the script skips it.

---

## Distrobox / Toolbox

Some Atomic users run CLI tools inside containers via Distrobox or Toolbox:

```bash
distrobox create --name dev --image ubuntu:24.04
distrobox enter dev
# Inside container: normal Ubuntu — apt works
```

Our script doesn't detect or support this scenario. If a user runs the script inside a Distrobox container, it will behave as if it's running on the container's base distro (e.g., Ubuntu).

**This is fine.** The install will work correctly inside the container.

---

## Flatpak Chrome Handling

Atomic desktops heavily rely on Flatpak for GUI apps. Chrome is often installed as a Flatpak:

```
/var/lib/flatpak/app/com.google.Chrome/current/active/files/extra/chrome
```

Our Chrome detection (`src/20_platform.sh:62-71`) checks Flatpak paths **first**, before system binaries. This is especially important on Atomic systems where a system-installed Chrome is unlikely.

> [!IMPORTANT]
> Antigravity cannot launch Chrome via `flatpak run com.google.Chrome` because the Flatpak sandbox prevents child process communication. The script uses the **raw binary path** inside the Flatpak installation directory instead.

---

## Available Install Methods

| Method | Status | Notes |
|---|---|---|
| **Homebrew** | ✅ Recommended | Best fit for Atomic philosophy |
| **Tarball** | ✅ Works | Fallback; installs to `~/.local/` |
| **System Repo (DNF)** | ❌ Not available | No `dnf` on Atomic hosts |
| **rpm-ostree** | ❌ Not supported | Against best practices |
