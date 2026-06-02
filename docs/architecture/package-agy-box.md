# Package Specification: Antigravity Developer Sandbox (agy-box)

> **Status:** ✅ Active
> **Last updated:** 2026-05-20
> **Parent:** [implementation_plan.md](implementation_plan.md)

---

## Overview

The **Antigravity Developer Sandbox (`agy-box`)** is an isolated, containerized laboratory environment for developers and students. It provides a secure space to run Antigravity applications and extensions without polluting the host operating system.

Under the hood, `agy-box` uses **Distrobox** to spin up mutable, tightly integrated Linux containers that feel native to the host.

---

## Package Metadata

| Property | Value / Description |
|---|---|
| **Package Name** | `agy-box` |
| **Manager Binary** | `agy-box-manager` |
| **Execution** | Containerized (Podman / Docker via Distrobox) |
| **Distribution** | Shell script installer fetching container images |

---

## Target Installation Directories

The manager script is installed to user-space, while the container image is managed by the host's container runtime:
- **Manager Script:** `~/.local/bin/agy-box-manager`
- **Container Storage:** Managed via `~/.local/share/containers` (Podman) or `/var/lib/docker` (Docker)
- **Host Integration:** Exported apps/binaries are mapped to `~/.local/bin/` and `~/.local/share/applications/` on the host.

---

## Dependencies & Prerequisites

`agy-box` requires the following dependencies to be present on the host system:

1. **Container Runtime:** `podman` (recommended) or `docker`.
2. **Container Wrapper:** `distrobox`.

### Platform-Specific Prerequisite Paths

- **Linux (APT/DNF):** The `agy-easy-install` script can automatically attempt to install `podman` and `distrobox` using `sudo apt install` or `sudo dnf install`.
- **Linux (Atomic/Immutable):** Podman and Distrobox are pre-installed. The installer only needs to verify the user has permission to use the container socket.
- **Windows (WSL2):** The user must manually install Docker or Podman within their WSL2 Linux distribution, and then install Distrobox via its raw install script. The installer will halt and provide guidance if these are missing.
- **macOS:** Not natively supported by standard Linux packages. The user must install a hypervisor-based container runtime like Podman Desktop or Docker Desktop, and install Distrobox via Homebrew. The installer provides a guidance card outlining these steps.

---

## Maintenance & Version Rules

1. **Manager Script Installation:**
   - The installer uses the `get_agy_box_release_url` function to resolve the target version of `agy-box-manager` based on `versions.json`.
   - The script is downloaded to `~/.local/bin/agy-box-manager` and made executable.
2. **Version Pinning:**
   - The default `agy-box` version is controlled by `DEFAULT_AGY_BOX_VERSION` in `src/00_config.sh` (e.g., `v0.5.0`).
   - The `versions.json` file tracks valid releases of `agy-box-manager`. If the target version is not listed, the installer falls back to guessing the release tag URL.
3. **Sandbox Initialization:**
   - After the manager is downloaded, the installer executes `agy-box-manager install` to actually pull the container image and initialize the Distrobox environment.

---

## Uninstallation

To cleanly remove `agy-box`, the installer provides an `uninstall_agy_box` function which invokes:
```bash
agy-box-manager clean
agy-box-manager uninstall-global
rm -f ~/.local/bin/agy-box-manager
```
This ensures the container, any exported host wrappers, and the manager script itself are completely removed.
