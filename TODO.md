# TODO — AGY Easy Install

> **Last updated:** 2026-10-10 · Branch: `main`
> This file is the single source of truth for all pending work.
> It MUST be updated at the end of every coding session.

---

## ✅ Completed

### Core Installer
- [x] Modular `src/` → `build.sh` bundler architecture
- [x] `detect_platform()` — OS, arch, package manager, glibc
- [x] `install_brew()` — Homebrew install path (Linux + macOS code)
- [x] `install_repo()` — APT/DNF system repo install
- [x] `do_install_tarball()` — standalone tarball with SHA-256 verification
- [x] `do_remove()` — uninstall Antigravity and CLI binary
- [x] `install_cli()` — install and configure the new Antigravity CLI
- [x] `save_manager_locally()` — persist the manager script
- [x] AGY detection at startup — check if Antigravity is already installed
- [x] Chrome browser detection + auto-configuration prompt
- [x] Official Google Antigravity VS Code Extension (`Google.antigravity`) support for VS Code / VSCodium / Code Insiders
- [x] Multi-IDE extension installers: JetBrains plugin CLI installation, Zed settings.json configuration, unified host IDE detection
- [x] CLI flags for IDE extensions: `--install-vscode`, `--install-jetbrains`, `--install-zed`, `--install-extensions`
- [x] ChromeOS Crostini container support for sandbox prerequisites and tarball installation
- [x] Upstream sync and version tracking for `agy-box` releases (v0.6.0) in scraper and config
- [x] Jules CLI bootstrapping (`--install-jules`) with zero-dependency Node.js and Homebrew setup
- [x] `agy-box` v0.6.0 multi-arch container integration (`--install-agy-box`, `--install-sandbox`)

### Terminal UI
- [x] Ephemeral `gum` bootstrap (download → temp dir → cleanup)
- [x] Colorful ASCII art banner with version + repo link
- [x] System info dashboard (OS, AGY status, recommendation)
- [x] Hierarchical Cancel-first menu (main → install / cleanup sub-menus)
- [x] `--demo-ui` sandbox mode with mock actions for every path
- [x] Fallback plain-text menu when `gum` unavailable
- [x] Tool-first installation flow (IDE, CLI, SDK) with secondary IDE method picker

### CLI Interface
- [x] `--version`, `--help`, `--remove`, `--verbose`, `--quiet`, `--json`
- [x] `--auto` headless auto-install (CI/provisioning)
- [x] `--install-brew`, `--install-repo`, `--install-tarball`, `--install-cli` direct flags
- [x] `--install-jules`, `--install-sandbox`, `--install-agy-box` flags
- [x] `--demo-ui` sandbox mode

### Security & Integrity
- [x] `KNOWN_SHA256` constant + `sha256sum` verification on tarball downloads
- [x] Nightly CI syncs both `DOWNLOAD_URL` and `KNOWN_SHA256` together
- [x] `curl -fSsL` everywhere (never swallows HTTP errors)
- [x] `textContent` only in landing page (no `innerHTML` XSS risk)
- [x] `trap ... EXIT` cleanup for all temp files
- [x] Contributor Covenant 2.1 Code of Conduct (`CODE_OF_CONDUCT.md`)

### CI/CD
- [x] `nightly-update.yml` — scrape URL, validate, update script, lint, commit
- [x] Fix nightly scraper to handle semantic versioning and 'Antigravity IDE' filename matching for version 2+
- [x] Dual Release Distribution Channels: Stable `v0.3.0` and rolling `nightly` pre-release with checksums and `.github/workflows/release.yml`
- [x] `deploy-pages.yml` — GitHub Pages from `docs/`
- [x] Pinned action versions (`checkout@v4`, `setup-python@v5`)
- [x] `sed` uses `#` delimiter (safe for URLs)
- [x] `shellcheck` lint step before commit

### Documentation
- [x] README with hero screenshot, platform table, roadmap, troubleshooting
- [x] Interactive landing page (`docs/index.html`) with embedded screenshots
- [x] Corp/CloudTop warning as collapsible `<details>`
- [x] Screenshot tooling (`docs/images/render.html` + `capture.py`)
- [x] AGENTS.md with complete file map and rules
- [x] CONTRIBUTING.md with `src/` → `build.sh` workflow
- [x] CHANGELOG.md
- [x] Package architecture specifications (`package-antigravity-*.md`) for IDE, CLI, and SDK
- [x] Platform architecture guides (`platform-linux.md`, `platform-macos.md`, `platform-crostini.md`, `platform-windows.md`)
- [x] Platform & binary installation matrix (`platform-binary-matrix.md`)

### Testing
- [x] 102-gate test suite across 8 phases (all verified)
- [x] Phase 0: Documentation bootstrap (5 gates)
- [x] Phase 1: Scaffolding & hygiene (9 gates)
- [x] Phase 2: Shell hardening + Homebrew (14 gates)
- [x] Phase 3: Pipeline fixes (11 gates)
- [x] Phase 4: Docs & polish (13 gates)
- [x] Phase 5: Bundler & tooling (14 gates)
- [x] Phase 6: Jules CLI & Bootstrapping (19 gates)
- [x] Phase 7: IDE Extensions Support (VS Code, JetBrains, Zed - 17 gates)

---

## ⚠️ In Progress — macOS (Beta)

> macOS code paths exist but have NOT been end-to-end validated.
> See **[docs/architecture/platform-macos.md](docs/architecture/platform-macos.md)** for implementation details.

### Code Fixes Needed
- [x] Fix TUI tearing/scrolling artifacts on macOS by providing sufficient gum filter height
- [x] Document macOS TUI bug and test suite auto-downgrade issue in `docs/architecture/ui-tearing-postmortem.md`
- [x] `sha256sum` → `shasum -a 256` fallback (macOS has no `sha256sum`)
- [x] PATH setup: detect shell, write to `~/.zprofile` (Zsh) not `~/.bashrc`
- [x] Mock UI references `~/.bashrc` — should be shell-aware
- [x] Easter egg: implement `open` vs `xdg-open` platform-aware opener

### Validation Needed (Code Exists)
- [x] `gum` bootstrap on macOS (arm64 binary download)
- [x] `gum` bootstrap on macOS (x86_64 binary download)
- [x] Skip `.desktop` file creation on Darwin — code at `src/30_installers.sh:131`
- [x] Chrome detection at `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`
- [x] `brew install --cask antigravity` actually works
- [x] `brew uninstall --cask antigravity` cleanup
- [x] `save_manager_locally()` in `~/.local/bin/` with correct PATH

### End-to-End Testing
- [x] Full flow on macOS Sonoma (Apple Silicon)
- [x] Full flow on macOS Sonoma (Intel)
- [x] `--demo-ui` sandbox mode works
- [x] GitHub Actions macOS runner smoke test

---

## 📋 Planned — New Platforms

### Crostini (ChromeOS)

> See **[docs/architecture/platform-crostini.md](docs/architecture/platform-crostini.md)** for implementation details.

- [x] Add Crostini detection: `test -f /dev/.cros_milestone` in `detect_platform()`
- [x] Show ChromeOS milestone in system info dashboard
- [x] Handle Chrome-not-in-container: detect `garcon-url-handler`
- [x] Test APT install in Crostini Debian container
- [x] Test tarball install in Crostini
- [x] Test `gum` binary on ARM Chromebooks (`Linux_arm64`)
- [x] Document in README platform table
- [x] End-to-end test on ChromeOS (x86_64)
- [x] End-to-end test on ChromeOS (ARM)

### Windows — WSL2

> See **[docs/architecture/platform-windows.md](docs/architecture/platform-windows.md)** for implementation details.

- [x] Add WSL detection: `$WSL_DISTRO_NAME` or `uname -r | grep microsoft`
- [x] Show "(WSL)" in system info dashboard
- [x] Skip `.desktop` file creation in WSL
- [x] Browser opening: use `wslview` or `cmd.exe /c start` instead of `xdg-open`
- [x] Test APT install in WSL2 Ubuntu
- [x] Test tarball install in WSL2
- [x] Document in README platform table

### Windows — Git Bash

> See **[docs/architecture/platform-windows.md](docs/architecture/platform-windows.md)** for implementation details.

- [x] Add Git Bash detection: `$OSTYPE = msys` or `uname -s | grep MINGW`
- [x] Implement graceful redirect: show message suggesting WSL2 instead
- [x] Verify no crashes or syntax errors when script runs
- [x] Document as "not supported — use WSL2" in README

---

## 🔍 Discrepancies (Docs vs. Codebase)

> **Identified during Architecture Deep-Dive Review**

- [x] **macOS Tarball Fallback Blocked:** `src/30_installers.sh:7` actively blocks tarball installation on Darwin, but `platform-macos.md` describes how to install and bypass Gatekeeper via `xattr`. We need to unblock this and implement the Gatekeeper quarantine bypass instructions.
- [x] **macOS `sha256sum` Missing:** `src/30_installers.sh:88` hardcodes `sha256sum`. macOS requires `shasum -a 256`. Tarball installation will fail immediately.
- [x] **macOS PATH Injection:** `src/20_platform.sh:8` writes the PATH to `~/.zshrc`. As per `platform-macos.md`, this should be `~/.zprofile` to avoid `path_helper` overwrites.
- [x] **Crostini Detection Missing:** `platform-crostini.md` relies on `/dev/.cros_milestone`, but `src/20_platform.sh` does not implement this check yet.
- [x] **Windows/MSYS2 Missing:** `platform-windows.md` mandates a hard redirect for Git Bash users, but the script currently doesn't check for `$OSTYPE = msys`.

---

## 📋 Planned — Features

- [x] **Official Binary Installers (macOS / Windows)**: Scrape the official release site for macOS (`mac-x64`, `mac-arm64`) and Windows (`windows-x64`) binaries alongside the Linux tarball. Add `DOWNLOAD_URL` and `KNOWN_SHA256` constants for each.
- [x] Offer official binaries as an install option, and set it as the recommended default on macOS and Windows (keeping Homebrew / WSL Tarball as secondary options).
- [x] macOS `.dmg` download fallback (for users without Homebrew)
- [x] Automated CI testing on macOS (GitHub Actions macOS runner)
- [x] Auto-update mechanism for the manager script itself
- [x] `--check` flag to verify existing installation health
- [x] **Antigravity CLI Support (`agy`)**: Add helper functions and UI/headless flags to install/uninstall the new command-line helper tool.
- [x] **Gemini CLI Support**: Rebranded and transitioned to Antigravity CLI (`agy`) as per developers blog post.
- [x] **Multi-Product Re-Imagining**: Offer Google Antigravity IDE, CLI, and SDK in the install helper with version checking and custom version choosing.
- [x] **Jules-cli Support**: Add installer support for the Jules-cli developer tool (`--install-jules`).
- [x] **Dependency Bootstrapping**: Automated Homebrew and Node.js/NPM bootstrapping for zero-dependency execution.
- [x] **VS Code Extension Installer**: Automated installation of `Google.antigravity` extension across VS Code, VSCodium, and Code Insiders.
- [x] **`agy-box` Sandbox Integration**: Multi-arch container image orchestration (`v0.6.0`) with `--install-agy-box` and `--install-sandbox`.
- [ ] Localization / i18n (stretch goal)

---

## ✅ Maintenance — Complete

- [x] Review and update screenshots when menu text changes — verified all menu text matches between `src/40_ui.sh` and `docs/images/render.html`
- [x] Keep landing page screenshots in sync with `render.html` — landing page (`docs/index.html`) references `main_menu.png`, `install_submenu.png`, `cleanup_submenu.png`; README references all 4 PNGs
- [x] Regenerate screenshots: ran `python3 docs/images/capture.py` — 4 PNGs updated
- [x] Gate count in implementation plan — verified: 85 gates across 7 phases
- [x] Architecture Documentation Deep-Dive — researched and enhanced all 10 platform and install architecture documents with tool skills and background logic.

---

## 🗺️ Master Plan Workstreams (Active Plan)

### Workstream 3: Repo Rename Migration (agv -> agy)
- [x] Create new GitHub repo `wtg-codes/agy-easy-install`
- [x] Sync git history and push to the new repository
- [x] Run bulk URL and string replacements across all script files (replace `agv-easy-install` with `agy-easy-install`)
- [x] Update documentation references and self-updater check URLs
- [x] Configure new GitHub Pages and trigger test CI run
- [x] Add deprecation warning banners to the old `agv-easy-install` and `agv-easy-install-ink` README files
- [x] Set up minimal redirect page in `docs/index.html` on the old repository, then archive the old repositories

### Workstream 4: Downstream Integration (agy-box)
- [x] Rebase and finish integration testing on branch `feature/agy-box-install`
- [x] Implement `agy-box-manager` script download lock strategy (pin to release tag vs fetching `main`)
- [x] Integrate agy-box version tracking inside `versions.json`
- [x] Implement error handling for Docker/Podman install failures, missing dependencies, or unsupported macOS environment blocks
