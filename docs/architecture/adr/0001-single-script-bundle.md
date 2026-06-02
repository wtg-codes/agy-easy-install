# ADR-0001: Single-Script Bundling Architecture

## Status
Accepted

## Context
The target audience of `agy-easy-install` is developers and students setting up the Google Antigravity environment, often in ephemeral VMs, cloud shells, or clean system environments. For usability, a simple one-liner invocation (`curl -fSsL ... | bash`) is highly desirable. However, writing a single monolithic Bash script exceeding a thousand lines makes development, debugging, testing, and maintenance extremely difficult and error-prone. We need a way to maintain structured, modular, and lintable source files while delivering a single consolidated executable script.

## Decision
We implement a single-script bundling architecture. The codebase is modularized under the `src/` directory, broken down into sequential functional layers:
- `00_config.sh`: Global configuration constants, environment variables, ANSI color definitions, and release fallbacks.
- `10_utils.sh`: Exit handler trap, error logging, and the `gum` TUI bootstrap helper.
- `20_platform.sh`: OS detection (macOS vs. Linux vs. Crostini vs. WSL2), path configuration, and launcher registration.
- `30_installers.sh`: Installation functions for Homebrew, package repositories (APT/DNF), official precompiled binary tarballs/DMGs/EXEs, and dependency installers (podman, distrobox, jules, agy-box).
- `40_ui.sh`: Dynamic user interface elements, menus, headers, and interactive confirmations.
- `50_health.sh`: Verification script to check dependencies and log results.
- `99_main.sh`: Main CLI dispatcher, parameter parser, automatic/non-interactive installer, and sandbox/TUI loops.

A build script `build.sh` concatenates these components in lexicographical order (from config to main) into the final deliverable `antigravity-manager.sh`. The build process strips out redundant shebang declarations from nested scripts to output a valid, executable file. The final script is compiled in the repository and checked in so it can be directly hosted and run.

## Consequences
- **Trade-offs / What becomes easier**:
  - Developers can write modular, cohesive scripts with clear separations of concerns.
  - Verification tools (e.g., `shellcheck`, `bash -n`) can lint individual files, making syntax checking cleaner and more targeted.
  - The build process is simple, deterministic, and fast (just concatenation).
  - Users continue to receive a single, self-contained shell script that can be downloaded and run via a single command, requiring no multiple file downloads or complex unpacking.
- **Trade-offs / What becomes harder**:
  - Developers must remember not to edit `antigravity-manager.sh` directly, as changes will be overwritten by `build.sh` in the next build cycle.
  - Changes in variables or shared helper functions across files are harder to track statically since the files are only integrated at build-time (dynamic shell execution).
  - The developer must run `build.sh` and compile `antigravity-manager.sh` before committing and pushing updates.
