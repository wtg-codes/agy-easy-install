# Changelog

All notable changes to this project will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/).

---

## [0.3.4] — 2026-11-11

### Added
- **Antigravity Dev Box (`agy-box`) v0.7.0 Support:** Added `v0.7.0` release tag tracking in `versions.json` and `DEFAULT_AGY_BOX_VERSION="v0.7.0"` in `src/00_config.sh`.
- **Whitespace-Tolerant JSON Parsing (`get_agy_box_release_url`):** Upgraded `get_agy_box_release_url()` to dynamically track object nesting depth regardless of indentation (compact, 2-space, 4-space, tabs), eliminating false "not found in versions.json" fallback warnings.
- **Standalone Sandbox Fallback Mode:** Added fallback support in `install_agy_box()` to proceed with standalone container sandbox mode (`--mode sandbox`) when Distrobox is missing but Podman or Docker is available.

### Fixed
- **Live Progress Reporting (`install_agy_box`):** Added explicit status logging during download and setup (`Starting agy-box container setup ($agy_ver) — live progress below...`).
- **Piped Install TTY Starvation (`install_agy_box`):** Redirected stdin from `/dev/tty` for interactive `agy-box-manager install` when running via `curl ... | bash` (`[ ! -t 0 ] && [ -t 1 ] && [ -r /dev/tty ]`), preventing premature stdin starvation on user input.

## [0.3.3] — 2026-11-11

### Added
- **Headless Antigravity IDE 2.x Flag (`--install-ide`):** Added dedicated non-interactive installer flag for Antigravity IDE alongside `--install-binary` (Google Antigravity Hub), plus `agy-ide` convenience symlink and OAuth URL-handler `.desktop` entries (`x-scheme-handler/antigravity`, `x-scheme-handler/antigravity-ide`).
- **Zero-Sudo Python SDK Bootstrap (`install_sdk`):** Added PEP 668 `--user --break-system-packages` support and ephemeral PyPA standalone `pip.pyz` fallback so `google-antigravity` installs cleanly on minimal Ubuntu/Debian/Atomic containers without `python3-pip` or `sudo`.
- **Dual Hub & IDE Version Detection:** Added `read_asar_version()` and `get_installed_agy_version()` alongside `get_installed_ide_version()` (`product.json` `ideVersion`) on both the dashboard and `--check` health report.

### Fixed
- **ASAR Icon Extraction Offset (`do_install_binary`):** Fixed Chromium Pickle ASAR payload offset math (`8 + header_size + offset` instead of `16 + json_size + offset`) that shifted PNG headers by 2 bytes on Google Antigravity Hub 2.x, and added IDE 2.x's unpacked `resources/app/resources/linux/code.png` path.
- **Homebrew Cask & Tap Alignment (`install_brew`, `get_installed_*_version`):** Updated Linux Homebrew installs to `ublue-os/tap/antigravity-linux` and `ublue-os/tap/antigravity-ide-linux`, macOS installs to `antigravity` and `antigravity-ide` casks, and fixed `brew list --cask --versions` detection (`brew info --cask` previously reported uninstalled casks as installed).
- **Temp-File Poisoning & Lifecycle Hygiene (`fetch_versions_json`, `cleanup_ui`):** Replaced predictable `/tmp/versions.json` and unsafe relative `../versions.json` lookups with an owned `mktemp` file cleaned up on exit (passing gate `3.G12`).
- **Self-Save & Self-Update Guards (`save_manager_locally`, `check_for_updates`):** Fixed same-file `cp` crash when re-running `~/.local/bin/antigravity-manager`, added semantic version comparison to prevent local builds from downgrading to older remote `main`, fixed Python SDK namespace (`google.antigravity` / `importlib.metadata`), and changed default Linux recommendation without Homebrew from legacy 1.x APT/RPM repos to Official Binary 2.x (`--install-binary`).

## [0.3.2] — 2026-11-11

### Added
- **Full Multi-Product Nightly Scraping (`scrape_latest.py`):**
  - Migrated to Google's dedicated auto-updater APIs for **Google Antigravity Hub** (`antigravity-hub-auto-updater`, `v2.31.0`), **Antigravity IDE** (`antigravity-ide-auto-updater`, `v2.6.0`), and **Antigravity CLI** (`antigravity-cli-auto-updater`, `v1.5.5` + `/manifests/*.json` fast-path SHA-512 lookup).
  - Added native **Linux ARM64 (`LINUX_ARM64`)** support across Hub, IDE, `src/00_config.sh`, `update_config.py`, and `do_install_binary()`, plus **musl Linux (`linux_amd64_musl`, `linux_arm64_musl`)** support for `agy` CLI.
  - Added **`extensions`** version and marketplace tracking in `versions.json` for all 6 official editor integrations (`vscode`, `visual-studio`, `jetbrains`, `zed`, `xcode`, `eclipse`), plus dynamic `agy-box` release tag syncing and parallel SHA computation.
- **Scraper & Shell Parser Test Suite (`tests/test_scraper.py`):** Added unit and shell integration tests enforced in `tests/run_gates.sh` (`3.G12`) and `.github/workflows/nightly-update.yml`.

### Fixed
- **Hub vs. IDE 2.x Misrouting & Filenames:** Removed legacy `version.startswith("2.")` bucket split that blocked IDE 2.x (`Antigravity IDE.{tar.gz,dmg,exe}`) and fixed Hub `>2.0.0` Windows installer filenames (`Antigravity-x64.exe`, `Antigravity-arm64.exe`).
- **SDK & Release Semantic Version Sorting:** Fixed lexicographical sorting (`"0.1.9"` sorting above `"0.1.23"`) across Hub, IDE, CLI, SDK, and `update_config.py`.
- **Multi-Version `awk` JSON Parsers:** Fixed trailing-comma state bleed in `get_product_release_info()`, `get_cli_release_info()`, `get_agy_box_release_url()`, and `list_*_versions()`.
- **VS Code Extension ID & IDE Binary Symlink:** Updated `install_vscode_ext()` to install the official `Google.google-antigravity` extension ID, fixed interactive IDE version dispatch (`do_install_binary "ide" "$selected_version"`), and linked IDE 2.x's extracted `antigravity-ide` binary accurately.

## [0.3.1] — 2026-10-10

### Added
- **Multi-IDE Extension Support:** Added dedicated installer functions and CLI flags for installing and configuring Google Antigravity extensions across VS Code, JetBrains IDEs, and Zed:
  - `--install-vscode`: Enhanced to support `code`, `codium`, and `code-insiders`.
  - `--install-jetbrains`: Scans PATH and standard JetBrains Toolbox directories for IDEs (`idea`, `pycharm`, `webstorm`, `goland`, `clion`, `rider`, `rustrover`, `studio`), executes CLI plugin installation, and provides running-IDE guidance.
  - `--install-zed`: Auto-configures Zed's `settings.json` (`~/.config/zed` or macOS Application Support) to auto-install the `antigravity` extension idempotently without settings corruption.
  - `--install-extensions`: Detects all installed IDEs on the host system and configures extensions in one command.
- **Interactive Extensions Submenu:** Updated install menu item [4] to `Install IDE Extensions (VS Code, JetBrains, Zed)` with dedicated submenu for granular or unified extension setup.
- **Phase 7 Gate Tests:** Added automated Phase 7 gate checks in `tests/run_gates.sh` verifying all extension flags, functions, menu options, and linter compliance.

## [0.3.0] — 2026-10-10

### Added
- **Dual Release Distribution Channels:** Introduced official Stable releases on `v*` tags (`releases/latest`) alongside automated rolling Nightly pre-releases (`releases/download/nightly/`) with SHA-256 integrity checksums.
- **Release Automation Workflow (`.github/workflows/release.yml`):** Automatically executes all 85 phase gates, bundles `antigravity-manager.sh`, generates `SHA256SUMS`, and publishes GitHub Releases on `v*` tags.
- **Nightly Pre-Release Deployment:** Enhanced `nightly-update.yml` to automatically publish and update the rolling `nightly` pre-release with newly scraped Google Antigravity binary URLs and hashes.
- **Jules CLI Bootstrapping:** Added `--install-jules` argument and interactive wizard integration to bootstrap the Jules CLI agent orchestrator with automatic Homebrew/Node.js dependencies.
- **`agy-box` Sandbox Integration:** Added `--install-sandbox` and `--install-agy-box` flags to provision the multi-arch `ghcr.io/wtg-codes/agy-box` Distrobox developer sandbox.
- **ChromeOS Crostini Compatibility:** Added detection and specialized terminal/desktop path support for ChromeOS Linux containers.
- **VS Code Extension Installer:** Added automated detection and installation of Antigravity IDE and companion VS Code extensions.

### Fixed
- **Nightly Scraper Cache Truncation:** Fixed shell output redirection `>` truncating `versions.json` before Python could read cached hashes, and handled uninitialized `old_data` safely.

## [0.2.14] — 2026-05-20

### Added
- **Package Specifications:** Added detailed architecture specifications (`package-antigravity-*.md`) for Google Antigravity IDE, CLI, and SDK in `docs/architecture/`.
- **Documentation Rules:** Updated `AGENTS.md` and repository guidelines to enforce keeping package specification documentation synced with codebase changes.

### Changed
- **Tool-First Installation Flow:** Refactored specific tool installer menu to show only the three core tools (IDE, CLI, SDK) as options, and prompt for IDE installation method selection subsequently.

## [0.2.13] — 2026-05-20

### Changed
- **Cleaner Screen Flow:** Added `clear || true` at the beginning of all interactive steps/menus (main menu, wizard steps, tool submenus, version selectors, post-install menus) to prevent old terminal output and previous step menus from cluttering the screen.
- **Main Menu simplification:** Removed the "Install/Remove this script locally" option from the main menu to reduce clutter (it remains accessible in the "Manage existing installation" submenu).
- **Terminology:** Renamed "Set up for class" to "Set up for lab" across all user-facing UI screens, logs, and docs.

## [0.2.12] — 2026-05-19

### Added
- **Wizard Flow:** Replaced flat menu with an intent-based wizard. First question asks "What would you like to do?" with options for lab setup, specific tool install, or manage existing installation.
- **Fast-Track Lab Setup:** New "🎓 Set up for lab" option installs selected products (IDE, CLI, SDK) via a multi-select picker, asks for the installation method, and confirms. Also available headlessly via `--fast-track`.
- **Post-Install Follow-up:** After any installation completes, a follow-up menu offers to launch Antigravity, create a workspace folder, or save the installer for later.

### Changed
- **Main Menu:** Menu options are now intent-based ("Set up for lab", "Install or update a specific tool", "Manage existing installation") instead of action-based ("Choose install method", "Cleanup options").
- **Submenus:** Switched from `gum filter` to `gum choose` and implemented compact one-line headers so all options are always visible on smaller terminal buffers.
- **Demo Mode:** Moved the "Demo UI (sandbox mode)" to the main menu.
- **Landing Page:** Updated wizard flow documentation and screenshots to match the new menu structure.

## [0.2.10] — 2026-05-19

### Added
- **Multi-Product Support:** Re-imagined installer interface to support Google Antigravity IDE, Antigravity CLI (`agy`), and Antigravity Python SDK (`google-antigravity`).
- **Dynamic Version Listing & Selection:** Fetches available releases dynamically from `versions.json` (and PyPI API for the SDK), letting users choose historical versions of each product to install.
- **Installed Version Detection:** Checks and displays currently installed versions of the IDE, CLI, and SDK on the startup dashboard alongside the latest available versions.
- **SDK Installation Support:** Added support for installing specific versions of the Antigravity Python SDK directly from PyPI.
- **Improved Scraper & Cache:** Upgraded `scrape_latest.py` with hash caching to prevent redundant file downloads of old versions, PyPI querying, and multi-product JSON manifest generation.
- **Health Check and Sandbox Updates:** Added SDK verification to the health check flow and integrated multi-product selection and mock actions in the sandbox demo mode.

## [0.2.9] — 2026-05-19

### Added
- **Antigravity CLI Support:** Added the command-line helper tool (`agy`) installer support, including the interactive UI option, `--install-cli` headless argument, and automatic removal of `$BIN_DIR/agy` on uninstall.
- **Health Check Integration:** Added optional CLI binary presence and PATH verification to the `--check` health check command.

### Changed
- **Official Release Alignment:** Targeted stable release version `2.0.0` from GCS URLs. Expanded the python scraper regex pattern to support both `/stable/` (edgedl) and `/antigravity-hub/` (GCS) path structures.
- **Documentation and Mock Screenshots:** Added CLI setup card to the landing page and README, updated manual download links, updated `docs/images/render.html` mock menu, and regenerated terminal mock screenshots.

## [0.2.8] — 2026-05-19

### Fixed
- **Nightly Scraper Version 2+ Support:** Updated `scrape_latest.py` to parse semantic versioning from the release page URLs, select the latest version, and matching download paths using a flexible filename pattern (to support files like `Antigravity IDE` in version 2+).

## [0.2.7] — 2026-05-15

### Added
- **Modern Terminal UI:** The interactive installer now features a beautiful arrow-key menu, animated spinners, and status blocks powered by an ephemeral download of `gum`.
- **Chrome Sandbox Bypass:** Added automatic path configuration for Flatpak/Atomic Linux environments to securely connect Antigravity to the browser.
- **Auto PATH Injection:** The installer can now automatically inject `~/.local/bin` into `~/.bashrc`, `~/.zshrc`, `~/.zprofile` (macOS), or `config.fish`.
- **JSON Output Mode:** Added `--json` flag to emit a single machine-readable status object instead of colored logs.
- **Headless Mode:** Added `--auto`, `--install-brew`, `--install-repo`, and `--install-tarball` flags for non-interactive automation.
- **Logging System:** Added robust logging to `/tmp/antigravity-install.log` with `--verbose` and `--quiet` flags.
- **State Management:** Added an `install.json` state file to track the install method for perfectly clean uninstalls.
- **Dependency Checks:** Script now fails fast if `curl`, `tar`, `awk`, or `grep` are missing.
- **WSL2 Detection:** Detects Windows Subsystem for Linux, labels dashboard as `(WSL)`, skips `.desktop` creation, routes browser opening to `wslview`.
- **MSYS2/Git Bash Block:** Hard-exits on MSYS2/Git Bash with a message directing users to WSL2.
- **Crostini (ChromeOS) Detection:** Detects `/dev/.cros_milestone`, displays milestone in dashboard, warns when no Linux browser is installed in the container.
- **macOS `shasum` Fallback:** Tarball verification now uses `shasum -a 256` on macOS when GNU `sha256sum` is unavailable.
- **macOS Tarball Unblocked:** The tarball install path now works on macOS, with a Gatekeeper `xattr` quarantine removal instruction shown post-install.
- **macOS PATH Fix:** PATH injection on macOS now targets `~/.zprofile` instead of `~/.zshrc`, preventing `path_helper` overwrites.
- **Easter Egg Upgrade:** Main menu now uses `gum filter --no-strict`, allowing free-text input to trigger the hidden `Google` Course Catalog opener. Works on all platforms via `xdg-open`/`open`/`wslview`.
- **CI Gate Tests:** Added `ci.yml` workflow to run the full 66-gate test suite on both `ubuntu-latest` and `macos-latest`.

### Changed
- **Rollbacks:** The system repository installer now gracefully cleans up broken repository keys and list files if `apt/dnf install` fails.

### Fixed
- Bootstrapped `KNOWN_SHA256` to the real tarball checksum — standalone installs no longer fail out of the box.
- **`gum filter` UI tearing:** Adjusted `--height=8` to provide exact space for all 4 options, bypassing the macOS alternate screen buffer tearing bug. Also fixed local development test auto-downgrade issue.

### Docs
- Updated README platform table: Crostini and WSL now show ⚠️ Beta, Git Bash shows ❌ Blocked.
- Updated README Roadmap to reflect completed macOS, Crostini, and Windows work.
- Updated platform badge to include WSL and ChromeOS.
- Documented new headless CLI flags in `README.md`.
- Added `CHANGELOG.md`.

---

## [0.2.2] — 2026-05-12

### Added
- **Homebrew install path** — `brew install --cask antigravity` (macOS) / `brew install antigravity` (Linux).
- `--version` and `--help` CLI flags.
- Platform auto-detection with install method recommendation in the interactive menu.
- macOS awareness — skips `.desktop` file creation, uses `open` instead of `xdg-open`.
- SHA-256 checksum verification for tarball downloads.
- `trap` cleanup for temp directories on error.
- Nightly CI now syncs both `DOWNLOAD_URL` **and** `KNOWN_SHA256` in lockstep.
- `shellcheck` lint step in the nightly pipeline before committing.
- URL validation (`HEAD` request) before the nightly commit.
- `AGENTS.md`, `CONTRIBUTING.md`, `LICENSE` (MIT), `.gitignore`, `requirements.txt`.
- Phase gate test runner (`tests/run_gates.sh`).
- Architecture docs (`docs/architecture/`).

### Changed
- All `curl` calls switched to `-fSsL` (fail on HTTP errors).
- `sed` delimiter in nightly CI changed from `|` to `#` to avoid URL injection.
- GitHub Pages deployment scoped to `docs/` instead of the entire repo root.
- Action versions pinned consistently (`checkout@v4`, `setup-python@v5`).
- Lucide icon library pinned to `0.292.0` (was `@latest`).

### Fixed
- Double-quoted all variable expansions to pass `shellcheck`.
- Replaced brittle `*"bash"*` pipe detection with `[ -f "$0" ] && [ -r "$0" ]`.
- Added `gpgcheck=0` explanation comment in the RPM repo block.
- Added `aria-label` attributes and `aria-expanded` toggle to the landing page.
- Added SEO meta tags and Open Graph tags to the landing page.
