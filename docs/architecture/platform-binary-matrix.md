# Platform and Binary Installation Matrix

This document serves as the unified source of truth for all products installed via `agy-easy-install`, detailing the target file paths, directories, and configurations for every supported platform.

---

## 1. Matrix Overview

| Product | Platform | Default Version | Install Method | Target Binary Path | Installation/App Directory | Config / User State Paths |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Antigravity IDE** | **Linux (x64)** | `1.23.2` | System Repo (`apt`/`dnf`) | `/usr/bin/antigravity` | `/usr/share/antigravity/` | `~/.config/Antigravity/` |
| | **Linux (x64)** | `1.23.2` | Standalone Tarball | `~/.local/bin/antigravity` (symlink) | `~/.local/lib/antigravity/` | `~/.config/Antigravity/` |
| | **macOS (x64 / arm64)** | `1.23.2` | Homebrew Cask / DMG | `/Applications/Google Antigravity.app` | `/Applications/Google Antigravity.app` | `~/Library/Application Support/Antigravity/` |
| | **Windows (WSL2)** | `1.23.2` | Linux Tarball (WSL) | `~/.local/bin/antigravity` | `~/.local/lib/antigravity/` | `~/.config/Antigravity/` |
| | **Windows (x64 / arm64)** | `1.23.2` | Native Installer (`.exe`) | `C:\Users\<user>\AppData\Local\Programs\Antigravity\antigravity.exe` | Same as binary path | `C:\Users\<user>\AppData\Roaming\Antigravity\` |
| **Antigravity CLI** (`agy`) | **Linux / macOS / WSL2** | `1.0.0` | Direct Download | `~/.local/bin/agy` | Standalone executable | `~/.config/antigravity-cli/`<br>`~/.gemini/antigravity-cli/settings.json` (holds MCP state) |
| | **Windows (Native)** | `1.0.0` | Direct Download | `C:\Users\<user>\.local\bin\agy.exe` | Standalone executable | `C:\Users\<user>\.config\antigravity-cli/`<br>`C:\Users\<user>\.gemini\antigravity-cli\settings.json` |
| **Antigravity SDK** | **All Platforms** | `0.1.0` | Python package (`pip`) | N/A | Target Python's `site-packages/` or active virtualenv | Determined by host Python environment |
| **Jules CLI** (`jules`) | **All Platforms** | `latest` | Node package (`npm`) | `~/.local/bin/jules` or system global node path | Local or global `node_modules` | `~/.config/jules-cli/`<br>`~/.gemini/jules/` |
| **Ag-Box Sandbox** (`agy-box`) | **Linux / WSL2** | `v0.5.0` | Distrobox Container | `~/.local/bin/agy-box-manager` | Distrobox container named `agy-box`<br>Image: `ghcr.io/wtg-codes/agy-box-image:latest` | `~/.config/distrobox/`<br>Container home: `~/.local/share/agy-box/` |

---

## 2. Product-Specific Path Details

### A. Antigravity IDE
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

### D. Ag-Box Sandbox (`agy-box`)
*   **Virtual Machine Integration (macOS & Windows WSL2):**
    *   On macOS, container runtimes run inside a hypervisor VM (e.g. `colima` or `podman machine`).
    *   On Windows, WSL2 acts as the VM layer.
*   **Host Directories Shared inside Container:**
    *   The user's home folder `~` is mounted to map files directly, allowing IDE instances running on the host to open workspaces inside the sandbox.
