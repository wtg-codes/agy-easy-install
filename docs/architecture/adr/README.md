# Architectural Decision Records (ADRs)

This directory contains the Architectural Decision Records for the `agy-easy-install` project. They document the key design choices, context, decisions, and consequences of our architecture.

## Index of ADRs

| ADR | Title | Status | Description |
| :--- | :--- | :--- | :--- |
| [ADR-0001](./0001-single-script-bundle.md) | Single-Script Bundling Architecture | **Accepted** | Modular script design combined into a single executable delivery script (`antigravity-manager.sh`). |
| [ADR-0002](./0002-ephemeral-gum-tui-bootstrap.md) | Ephemeral Gum TUI Bootstrap | **Accepted** | Zero-dependency bootstrapping of Charm's `gum` binary for rich terminal interfaces. |
| [ADR-0003](./0003-platform-aware-installation.md) | Platform-Aware Installation Target Selection | **Accepted** | Dynamically selecting Homebrew, package repositories (APT/DNF), or standalone binaries based on OS. |
| [ADR-0004](./0004-agy-box-installation-paths.md) | agy-box Sandbox Installation Paths | **Accepted** | Prerequisite validation, active socket verification, and OS-specific path routing for agy-box. |
