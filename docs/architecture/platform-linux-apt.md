# Linux (APT) — Debian/Ubuntu Family

> **Status:** ✅ Tested
> **Last updated:** 2026-05-13
> **Parent:** [platform-linux.md](platform-linux.md)

---

## Supported Distributions

| `$DISTRO` (from `/etc/os-release`) | Name | Tested? |
|---|---|---|
| `ubuntu` | Ubuntu | ✅ 22.04, 24.04 |
| `debian` | Debian | ✅ Expected (same APT path) |
| `kali` | Kali Linux | ⚠️ Expected (Debian-based) |
| `linuxmint` | Linux Mint | ⚠️ Expected (Ubuntu-based) |
| `pop` | Pop!_OS | ⚠️ Not in case statement — falls through to tarball |
| `elementary` | elementary OS | ⚠️ Not in case statement — falls through to tarball |

> [!NOTE]
> Pop!_OS (`pop`) and elementary OS (`elementary`) are Ubuntu-based and would work with APT, but their `$ID` values are not in the current `case` match. They will fall through to tarball. To add support, include them in the APT case: `ubuntu|debian|kali|linuxmint|pop|elementary)`.

---

## Install Flow

```bash
# 1. Create keyring directory
sudo mkdir -p /etc/apt/keyrings

# 2. Fetch and dearmor GPG key (scoped via signed-by)
curl -fSsL "https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg" | \
    sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg

# 3. Add repository source
echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] \
    https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ \
    antigravity-debian main" | \
    sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null

# 4. Install
sudo apt update
sudo apt install -y antigravity
```

**Source:** `src/30_installers.sh:40-55`

---

## Security

- **`signed-by` is used** — GPG key scoped to this repo only (modern best practice)
- **Key stored in `/etc/apt/keyrings/`** — not the deprecated global `apt-key` store
- **`gpg --dearmor`** — converts ASCII-armored key to binary format

---

## Removal

```bash
sudo apt remove -y antigravity
sudo rm -f /etc/apt/sources.list.d/antigravity.list
# Also: rm -f /etc/apt/keyrings/antigravity-repo-key.gpg (not currently done)
```

**Source:** `src/30_installers.sh:180-182`

> [!NOTE]
> The GPG key (`antigravity-repo-key.gpg`) is NOT removed during uninstall. This is harmless but leaves a stale key. Consider adding cleanup in a future update.

---

## Rollback on Failure

If `apt install` fails, the `.list` file is removed to prevent broken `apt update` on future runs:

```bash
sudo rm -f /etc/apt/sources.list.d/antigravity.list
```

---

## Ubuntu 24.04+ Note (DEB822 Format)

Ubuntu 24.04 and later prefer the new DEB822 `.sources` format over the one-line `.list` format. Our current `.list` file **still works** on 24.04, but generates a deprecation warning during `apt update`.

**Future improvement:** Detect Ubuntu version and use `.sources` format:

```
# /etc/apt/sources.list.d/antigravity.sources
Types: deb
URIs: https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/
Suites: antigravity-debian
Components: main
Signed-By: /etc/apt/keyrings/antigravity-repo-key.gpg
```

---

## Available Install Methods

| Method | Status | Notes |
|---|---|---|
| **System Repo (APT)** | ✅ Recommended | Auto-updates via `apt upgrade` |
| **Homebrew** | ✅ Works | If brew is installed |
| **Tarball** | ✅ Works | Universal fallback |
