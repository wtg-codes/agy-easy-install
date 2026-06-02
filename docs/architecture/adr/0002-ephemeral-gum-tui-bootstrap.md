# ADR-0002: Ephemeral Gum TUI Bootstrap

## Status
Accepted

## Context
To provide an elite user experience, the installer uses an interactive Terminal User Interface (TUI) with search filtering, menus, indicators, progress spinners, and confirmation dialogs. Implementing these features natively in pure Bash requires complex terminal control sequences, raw input handling, and terminal cursor control, which are brittle and prone to UI tearing across different terminal emulators.

We want to use Charm's `gum` utility, which provides high-quality, pre-built command-line interface elements. However, requiring users to install `gum` on their systems prior to running the installer degrades the frictionless onboarding experience.

## Decision
We implement an ephemeral bootstrap mechanism for `gum`. When running in interactive mode (i.e., not `--auto` or `--json-out`), the installer checks if `gum` is already available on the system `PATH`. If not, it downloads the precompiled `gum` binary for the user's host OS (Linux, macOS) and CPU architecture (x86_64, arm64/aarch64) from GitHub Releases into a temporary folder (`GUM_DIR=$(mktemp -d)`).

This directory is then temporarily prepended to the script's `PATH`. To ensure clean execution, a cleanup trap is registered (`trap exit_handler EXIT INT TERM`). Upon script termination, normal exit, or interruption, the `cleanup_ui` function executes `rm -rf "$GUM_DIR"`, removing the binary and leaving no permanent modifications or clutter on the host filesystem.

## Consequences
- **Trade-offs / What becomes easier**:
  - Allows the use of rich, styled TUI components (e.g., `gum choose`, `gum filter`, `gum spin`, `gum style`) with robust terminal handling and no UI tearing.
  - Zero pre-requisites for the user; they don't need to manually install any TUI libraries or packages.
  - Zero system pollution: the bootstrapped `gum` binary is completely isolated and deleted on exit.
- **Trade-offs / What becomes harder**:
  - The installer requires internet access during the initial bootstrap step to fetch the `gum` tarball from GitHub. If the user is offline, the script must gracefully fall back to basic text-based interactive prompts.
  - Increases script startup latency slightly due to the dynamic fetch and extract of the binary, although this is mitigated by checking if `gum` is already present.
  - Introduces a runtime dependency on GitHub Releases availability and internet bandwidth.
