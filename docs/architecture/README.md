# 🏛️ Architecture & Technical Specifications

This directory contains technical specifications, platform matrices, package designs, and architectural decision records for **`agy-easy-install`** and its companion container **`agy-box`**.

---

## 📑 Directory Index

### 1. Platform Specifications
Detailed notes, paths, and platform-specific behaviors:
- **[Platform & Binary Installation Matrix](platform-binary-matrix.md)** — Canonical matrix of official binary download URLs, checksums, target paths, and version tags across Linux, macOS, and Windows.
- **[Linux Architecture Notes](platform-linux.md)** — Linux distro compatibility, system requirements, and package manager selection logic.
- **[Debian / Ubuntu APT Guide](platform-linux-apt.md)** — APT repository configuration, keyrings, and deb packages.
- **[Fedora / RHEL DNF Guide](platform-linux-dnf.md)** — RPM repositories and dnf integration.
- **[Atomic / Immutable Linux Guide](platform-linux-atomic.md)** — Rootless installation on Fedora Silverblue, Kinoite, and Universal Blue (Bluefin / Aurora).
- **[macOS Architecture Notes](platform-macos.md)** — macOS Homebrew vs standalone tarball, Gatekeeper quarantine handling, and permissions.
- **[Windows & WSL2 Notes](platform-windows.md)** — Windows native executable launcher and WSL2 Ubuntu integration.
- **[ChromeOS Crostini Notes](platform-crostini.md)** — ChromeOS Linux container compatibility, font rendering, and Wayland forwarding.

---

### 2. Package Specifications
Technical designs and operational requirements for each component of the Google Antigravity suite:
- **[Antigravity CLI Architecture](package-antigravity-cli.md)** — Standalone Go binary, WebSocket connection to Agent UI, and statusline protocols.
- **[Antigravity IDE Architecture](package-antigravity-ide.md)** — Standalone Electron developer environment, bundled tools, and telemetry defaults.
- **[Antigravity Python SDK Architecture](package-antigravity-sdk.md)** — `google-antigravity` PyPI package, ADC authentication, and local Agent UI API bindings.

---

### 3. Installation Strategies
Mechanisms used by `antigravity-manager.sh` to install and maintain tools:
- **[Official Binary / Tarball Extraction](install-tarball.md)** — Pinned checksum validation, atomic extraction, and symlinking to `~/.local/bin`.
- **[Homebrew Cask / Formula Flow](install-homebrew.md)** — macOS and Linux Homebrew integration.
- **[System Repository Integration](install-repo.md)** — Integration with distribution-managed native package repositories.

---

### 4. System Integrations & Planning
- **[Container Sandbox (`agy-box`) Integration Plan](agy_box_integration_plan.md)** — How `agy-easy-install` launches, detects, and provisions the `agy-box` Distrobox container.
- **[Implementation Plan & Milestone Roadmap](implementation_plan.md)** — Phased development history, test gates, and deliverables.
- **[TUI Rendering Postmortem](ui-tearing-postmortem.md)** — Postmortem on terminal buffer rendering and PTY test verification.

---

### 5. Architectural Decision Records (ADRs)
Formal decisions logged in the [adr/](adr/README.md) subdirectory:
- **[ADR 0001: Single Script Bundle](adr/0001-single-script-bundle.md)** — Bundling `src/*.sh` into single executable `antigravity-manager.sh`.
- **[ADR 0002: Ephemeral Gum TUI Bootstrap](adr/0002-ephemeral-gum-tui-bootstrap.md)** — Downloading Charm `gum` into memory when absent on host.
- **[ADR 0003: Platform-Aware Installation](adr/0003-platform-aware-installation.md)** — Dynamic platform and package manager detection.
- **[ADR 0004: agy-box Installation Paths](adr/0004-agy-box-installation-paths.md)** — Sandboxed home paths and Distrobox integration.
