# Linux (DNF) — Fedora/RHEL Family

> **Status:** ✅ Tested
> **Last updated:** 2026-05-13
> **Parent:** [platform-linux.md](platform-linux.md)

---

## Supported Distributions

| `$DISTRO` (from `/etc/os-release`) | Name | Tested? |
|---|---|---|
| `fedora` | Fedora Workstation | ✅ 40+ |
| `rhel` | Red Hat Enterprise Linux | ⚠️ Expected (untested) |
| `centos` | CentOS Stream | ⚠️ Expected (untested) |
| `amzn` | Amazon Linux 2023 | ⚠️ Expected (untested) |
| `rocky` | Rocky Linux | ⚠️ Not in case statement |
| `alma` | AlmaLinux | ⚠️ Not in case statement |
| `ol` | Oracle Linux | ⚠️ Not in case statement |

> [!NOTE]
> Rocky Linux (`rocky`), AlmaLinux (`alma`), and Oracle Linux (`ol`) are RHEL clones and would work with DNF, but their `$ID` values are not in the current `case` match. They will fall through to tarball. To add support: `fedora|rhel|centos|amzn|rocky|alma|ol)`.

---

## Install Flow

```bash
# 1. Write .repo file
sudo tee /etc/yum.repos.d/antigravity.repo > /dev/null << EOL
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
EOL

# 2. Install
sudo dnf makecache
sudo dnf install -y antigravity
```

**Source:** `src/30_installers.sh:57-71`

---

## Security

> [!WARNING]
> **`gpgcheck=0` is set.** RPM packages are NOT cryptographically verified. This is because the upstream Google Artifact Registry does not provide GPG-signed RPMs.

**What this means:** A compromised mirror or man-in-the-middle could serve a tampered package without detection.

**When this can be fixed:** When the upstream Artifact Registry starts signing RPMs. Then:
```ini
gpgcheck=1
gpgkey=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/RPM-GPG-KEY
```

**Code comment:** There is an explanatory comment in the script per AGENTS.md rule 2.7.

---

## Removal

```bash
sudo dnf remove -y antigravity
sudo rm -f /etc/yum.repos.d/antigravity.repo
```

**Source:** `src/30_installers.sh:183-185`

---

## Rollback on Failure

If `dnf install` fails, the `.repo` file is removed:

```bash
sudo rm -f /etc/yum.repos.d/antigravity.repo
```

---

## DNF5 vs DNF4

Fedora 41+ ships **DNF5** as the default package manager. Key differences:

| Feature | DNF4 | DNF5 |
|---|---|---|
| **Config format** | `.repo` files in `/etc/yum.repos.d/` | Same (compatible) |
| **Add repo command** | `dnf config-manager --add-repo` | `dnf config-manager addrepo` |
| **Our method** | Direct file write to `/etc/yum.repos.d/` | ✅ Works on both |

Our script writes the `.repo` file directly rather than using `config-manager`, which avoids the DNF4/DNF5 syntax differences entirely.

---

## SELinux Considerations

Fedora and RHEL have SELinux enabled by default in enforcing mode:

- **System packages** installed via DNF get correct SELinux contexts automatically
- **Tarball binaries** in `~/.local/bin/` may need context labels if SELinux blocks execution
- **Homebrew binaries** in `~/.linuxbrew/` are typically not affected (user context)

Currently, our installer does **not** set SELinux contexts on tarball installs. This could cause issues on strict RHEL systems.

---

## Available Install Methods

| Method | Status | Notes |
|---|---|---|
| **System Repo (DNF)** | ✅ Recommended | Auto-updates via `dnf upgrade` |
| **Homebrew** | ✅ Works | Popular on Fedora Workstation |
| **Tarball** | ✅ Works | Universal fallback; SELinux may interfere |
