# Platform and Binary Installation Matrix

This document serves as the unified source of truth for all products installed via `agy-easy-install`, detailing the target file paths, directories, configurations, upstream binary URLs, and integrity hashes for every supported platform.

---

## 1. Matrix Overview

| Product | Platform | Default Version | Install Method | Target Binary Path | Installation/App Directory | Config / User State Paths |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Google Antigravity** | **Linux (x64)** | `2.0.0` | Standalone Tarball | `~/.local/bin/antigravity` (symlink) | `~/.local/lib/antigravity/` | `~/.config/Antigravity/` |
| | **macOS (x64 / arm64)** | `2.0.0` | DMG / App Bundle | `/Applications/Google Antigravity.app` | `/Applications/Google Antigravity.app` | `~/Library/Application Support/Antigravity/` |
| | **Windows (x64 / arm64)** | `2.0.0` | Native Installer (`.exe`) | `C:\Users\<user>\AppData\Local\Programs\Antigravity\antigravity.exe` | Same as binary path | `C:\Users\<user>\AppData\Roaming\Antigravity\` |
| **Antigravity IDE** | **Linux (x64)** | `1.23.2` | System Repo (`apt`/`dnf`) | `/usr/bin/antigravity` | `/usr/share/antigravity/` | `~/.config/Antigravity/` |
| | **Linux (x64)** | `1.23.2` | Standalone Tarball | `~/.local/bin/antigravity` (symlink) | `~/.local/lib/antigravity/` | `~/.config/Antigravity/` |
| | **macOS (x64 / arm64)** | `1.23.2` | Homebrew Cask / DMG | `/Applications/Google Antigravity.app` | `/Applications/Google Antigravity.app` | `~/Library/Application Support/Antigravity/` |
| | **Windows (WSL2)** | `1.23.2` | Linux Tarball (WSL) | `~/.local/bin/antigravity` | `~/.local/lib/antigravity/` | `~/.config/Antigravity/` |
| | **Windows (x64 / arm64)** | `1.23.2` | Native Installer (`.exe`) | `C:\Users\<user>\AppData\Local\Programs\Antigravity\antigravity.exe` | Same as binary path | `C:\Users\<user>\AppData\Roaming\Antigravity\` |
| **Antigravity CLI** (`agy`) | **Linux / macOS / WSL2** | `1.3.3` | Direct Download | `~/.local/bin/agy` | Standalone executable | `~/.config/antigravity-cli/`<br>`~/.gemini/antigravity-cli/settings.json` (holds MCP state) |
| | **Windows (Native)** | `1.3.3` | Direct Download | `C:\Users\<user>\.local\bin\agy.exe` | Standalone executable | `C:\Users\<user>\.config\antigravity-cli/`<br>`C:\Users\<user>\.gemini\antigravity-cli\settings.json` |
| **Antigravity SDK** | **All Platforms** | `0.1.21` | Python package (`pip`) | N/A | Target Python's `site-packages/` or active virtualenv | Determined by host Python environment |
| **Jules CLI** (`jules`) | **All Platforms** | `latest` | Node package (`npm`) | `~/.local/bin/jules` or system global node path | Local or global `node_modules` | `~/.config/jules-cli/`<br>`~/.gemini/jules/` |
| **agy-box Sandbox** (`agy-box`) | **Linux (amd64 / arm64) / WSL2** | `v0.6.0` | Distrobox / OCI Container | `~/.local/bin/agy-box-manager` | Distrobox container named `agy-box`<br>Image: `ghcr.io/wtg-codes/agy-box:v0.6.0` (`:latest`) | `~/.config/distrobox/`<br>Container home: `~/.config/agy-box/home/` |

---

## 2. Product-Specific Path Details

### A. Google Antigravity & Antigravity IDE
*   **Desktop Shortcuts:**
    *   **Linux (Standard):** `~/.local/share/applications/google-antigravity.desktop` and copy placed on `~/Desktop`
    *   **macOS:** App bundle registered in `/Applications`
    *   **Windows (Native):** Start Menu shortcut and Desktop link
*   **Log Locations:**
    *   **Linux:** `~/.config/Antigravity/logs/`
    *   **macOS:** `~/Library/Logs/Antigravity/`

### B. Antigravity CLI (`agy`)
*   **Global Path Configs:**
    *   Adds `~/.local/bin` to the active shell configuration (`~/.bashrc`, `~/.zshrc` on Linux; `~/.zprofile` on macOS).
*   **Gemini Settings Integration:**
    *   `~/.gemini/antigravity-cli/settings.json` contains the credentials, tokens, application defaults (ADC), and configured local/remote MCP server mappings.

### C. Jules CLI (`jules`)
*   **Environment Check:**
    *   Requires Node.js >= 18 and NPM. If absent, the manager offers to bootstrap Node.js.
    *   Symlinked into `~/.local/bin/jules` to ensure it is executable without adding additional global NPM directories to the shell PATH.

### D. agy-box Sandbox (`agy-box`)
*   **Virtual Machine Integration (macOS & Windows WSL2):**
    *   On macOS, container runtimes run inside a hypervisor VM (e.g. `colima` or `podman machine`).
    *   On Windows, WSL2 acts as the VM layer.
*   **Host Directories Shared inside Container:**
    *   The user's home folder `~` is mounted to map files directly, allowing IDE instances running on the host to open workspaces inside the sandbox.

---

## 3. Upstream Binary URLs & Integrity Hashes

All binary URLs and cryptographic hashes are tracked in `versions.json` and mirrored in `src/00_config.sh`.

### A. Google Antigravity (`2.0.0`)

| Target | Architecture | Format | Upstream Download URL | Verification Hash (SHA-256) |
|---|---|---|---|---|
| Linux | `x64` | `.tar.gz` | `https://storage.googleapis.com/antigravity-public/antigravity-hub/2.0.0-6324554176528384/linux-x64/Antigravity.tar.gz` | `14bc9cb480a5be8fb3b7dc3e2b0cebfa66d370ad58cc1e0fa01140d1204d4297` |
| macOS | `x64` (Intel) | `.dmg` | `https://storage.googleapis.com/antigravity-public/antigravity-hub/2.0.0-6324554176528384/darwin-x64/Antigravity.dmg` | `7416561b81866656453d51810ff64c19bfdc41b5fabca2ca253e9f835e7b20a6` |
| macOS | `arm64` (Apple Silicon) | `.dmg` | `https://storage.googleapis.com/antigravity-public/antigravity-hub/2.0.0-6324554176528384/darwin-arm/Antigravity.dmg` | `f96c360be0dc419186f987276b0aa1f8c22def1b76eec0892537c193e6bf4fdd` |
| Windows | `x64` | `.exe` | `https://storage.googleapis.com/antigravity-public/antigravity-hub/2.0.0-6324554176528384/windows-x64/Antigravity.exe` | `06e1b95dca9bf14fcbfc72ace0c11b42123c0cb65f35ee3c979b63bab3b56a6a` |
| Windows | `arm64` | `.exe` | `https://storage.googleapis.com/antigravity-public/antigravity-hub/2.0.0-6324554176528384/windows-arm/Antigravity.exe` | `5b8f70548455c61fbc7ddf137b4d74c189444167085fdd6ef29b8cd2feb57b18` |

### B. Antigravity IDE (`1.23.2`)

| Target | Architecture | Format | Upstream Download URL | Verification Hash (SHA-256) |
|---|---|---|---|---|
| Linux | `x64` | `.tar.gz` | `https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.23.2-4781536860569600/linux-x64/Antigravity.tar.gz` | `5232a4048ff4fa15685d9a981ba4fba573e297f3efc9b76f638e794baf775725` |
| macOS | `x64` (Intel) | `.dmg` | `https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.23.2-4781536860569600/darwin-x64/Antigravity.dmg` | `4ec781e8e94ec714c307a06c4ce925bf761dd0e610ba45e173747fbbe3423ad6` |
| macOS | `arm64` (Apple Silicon) | `.dmg` | `https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.23.2-4781536860569600/darwin-arm/Antigravity.dmg` | `caa35ad282741cc9350fb6234e9b86aef54cd4d2f75715a21ef27180182aa50f` |
| Windows | `x64` | `.exe` | `https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.23.2-4781536860569600/windows-x64/Antigravity.exe` | `3874fc761e5c90b3edf8e0365f506ce22241a88f6881cea09713b3f472c4f6ed` |
| Windows | `arm64` | `.exe` | `https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.23.2-4781536860569600/windows-arm64/Antigravity.exe` | `a14aa1971ad801131adcb12afe216522aadea176c141c4b5d793d216bfe02101` |

### C. Antigravity CLI (`1.3.3`)

| Target | Architecture | Format | Upstream Download URL | Verification Hash (SHA-512) |
|---|---|---|---|---|
| Linux | `amd64` | `.tar.gz` | `https://storage.googleapis.com/antigravity-public/antigravity-cli/1.3.3-5524738307653632/linux-x64/cli_linux_x64.tar.gz` | `abe3ddf5cf30d3adaa586acf505221aa19702f5ca71af3c8b1f9b1a5976bd8e5c151c41ea33b39c41675d25843462a3e8c382c054f580e9d7e1688919d3b5110` |
| macOS | `arm64` | `.tar.gz` | `https://storage.googleapis.com/antigravity-public/antigravity-cli/1.3.3-5524738307653632/darwin-arm/cli_mac_arm64.tar.gz` | `05ebb472149ca461e99f7870ce81fbdd48e3844f43b96a778c981d983421627c5bd02596dc8211ccd30b4cee0df8ca4d17b681f587ef22948ea4c703e9c7fcbd` |
| macOS | `amd64` | `.tar.gz` | `https://storage.googleapis.com/antigravity-public/antigravity-cli/1.3.3-5524738307653632/darwin-x64/cli_mac_x64.tar.gz` | `97075ac7ed080928f58ec3e0be83b38057f980d40927a3d0dadc54850ca99a884f38c90bf5c4f6ecb3c6101f31d7560500450390c468208ac7de2560af2df76b` |
| Windows | `amd64` | `.exe` | `https://storage.googleapis.com/antigravity-public/antigravity-cli/1.3.3-5524738307653632/windows-x64/cli_windows_x64.exe` | `ec15855bd5de768232c0aee31d11eac636a9e7d8bc4ad3dbe3887a9797f7fd821cafabba61482cd5515674a05246be2b7f96ca3f17e38c6a3f7431a2a3aff81f` |
| Windows | `arm64` | `.exe` | `https://storage.googleapis.com/antigravity-public/antigravity-cli/1.3.3-5524738307653632/windows-arm/cli_windows_arm64.exe` | `8abcbb02274247830a9669d81cc468ee936958278a46caa825fc4c3b40d0621284cf9cf5d570db5c202c6be353d6410591e5861a27fc3ceb13ac3a687fa2af4b` |

### D. Downstream Sandbox (`agy-box` v0.6.0)

| Component | Target Architecture | Location / URL |
|---|---|---|
| Container Image | `linux/amd64`, `linux/arm64` | `ghcr.io/wtg-codes/agy-box:v0.6.0` (and `ghcr.io/wtg-codes/agy-box:latest`) |
| Manager Script | All | `https://raw.githubusercontent.com/wtg-codes/agy-box/v0.6.0/agy-box-manager` |

---

## 4. Alternative & Cloud Deployment Options for agy-box

Since `agy-box` is compiled as a standard OCI-compliant multi-arch container image (`ghcr.io/wtg-codes/agy-box:latest`), it can be deployed in environments outside of local `distrobox` setups:

*   **Cloud Virtual Machines (GCP Compute Engine, AWS EC2):**
    *   Instead of installing distrobox locally, you can run the container image directly using `podman run` or `docker run` on a persistent cloud VM.
    *   Map container ports (e.g., port `8080` for noVNC browser-based display, or port `22` for SSH connection) to access the fully functional development sandbox remotely.
*   **Web-based IDE Cloud Services (GitHub Codespaces, Coder, Gitpod):**
    *   `ghcr.io/wtg-codes/agy-box:latest` can serve as the default devcontainer configuration base image.
    *   When you launch a GitHub Codespace, it spins up this container on a cloud node, launching a browser-accessible IDE with all CLI and SDK toolchains pre-installed and authenticated via GitHub SSO.
*   **Jules VM Sandbox Parity:**
    *   The `agy-box` container image can be loaded directly inside the secure ephemeral VMs used by Jules for task execution. This guarantees 100% environment parity between the developer's local environment and the agent's cloud container.
