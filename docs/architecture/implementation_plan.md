# AGY Easy Install — Implementation Plan

> **Last updated:** 2026-10-10 · Branch: `main`
> This is a living document. It reflects the current architecture and roadmap.
> For pending work items, see [`TODO.md`](../../TODO.md) in the project root.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  src/                                               │
│  ├── 00_config.sh     Constants, version, colors    │
│  ├── 10_utils.sh      Logging, cleanup, gum boot    │
│  ├── 20_platform.sh   OS detect, banner, sys info   │
│  ├── 30_installers.sh Brew, repo, tarball install   │
│  ├── 40_ui.sh         Hierarchical menus            │
│  ├── 50_health.sh     Health check verification     │
│  └── 99_main.sh       CLI dispatch, sandbox loop    │
└──────────┬──────────────────────────────────────────┘
           │ ./build.sh
           ▼
┌─────────────────────────────────────────────────────┐
│  antigravity-manager.sh  (compiled — v0.3.0)        │
│  ├── DOWNLOAD_URL  ← updated nightly by CI          │
│  └── KNOWN_SHA256  ← MUST be updated alongside URL  │
└──────────┬──────────────────────────────────────────┘
           │ curl | bash
           ▼
┌─────────────────────────────────────────────────────┐
│  User's terminal                                    │
│  ├── Banner + system info dashboard                 │
│  ├── Main menu (Cancel / Install → / Cleanup →)     │
│  ├── Install sub-menu (★ Brew / Repo / Tarball)     │
│  └── Cleanup sub-menu (Uninstall / Save / Demo)     │
└─────────────────────────────────────────────────────┘
```

### Key Design Decisions

| Decision | Rationale |
|---|---|
| **Source-first bundler** (`src/` → `build.sh`) | Keeps modules small; the compiled script is the deliverable |
| **Ephemeral `gum`** | Zero permanent dependencies; downloaded to temp dir, cleaned up on exit |
| **Cancel-first menus** | Pressing Enter without thinking = safe exit (student audience) |
| **Hierarchical sub-menus** | Reduces top-level noise; signals "more choices ahead" with `→` arrows |
| **`curl \| bash` pattern** | Intentional — target audience is students on ephemeral VMs. SHA-256 check inside the script handles integrity |
| **`DOWNLOAD_URL` + `KNOWN_SHA256` coupling** | If one changes, the other MUST change. Nightly CI enforces this |
| **Dual distribution channels** | Stable tagged releases (`v0.3.0`) for production reliability alongside rolling `nightly` pre-releases |
| **`agy-box` container integration** | Pinned `v0.6.0` multi-arch OCI image (`ghcr.io/wtg-codes/agy-box`) for immutable sandbox environments |

---

## Completed Phases (0–6)

All phases (0–6) are complete and validated by the 85-gate test suite.

| Phase | Name | Gates | Status |
|---|---|---|---|
| 0 | Documentation Bootstrap | 5 | ✅ Complete |
| 1 | Scaffolding & Hygiene | 9 | ✅ Complete |
| 2 | Shell Hardening + Homebrew | 14 | ✅ Complete |
| 3 | Pipeline Fixes | 11 | ✅ Complete |
| 4 | Docs & Polish | 13 | ✅ Complete |
| 5 | Bundler & Tooling | 14 | ✅ Complete |
| 6 | Jules CLI & Bootstrapping | 19 | ✅ Complete |
| **Total** | | **85** | ✅ All passing |

### Gate Runner

```bash
# Run all gates
bash tests/run_gates.sh --phase all

# Run a specific phase
bash tests/run_gates.sh --phase 6
```

---

## Current Gate Summary

### Phase 0 — Documentation Bootstrap (5 gates)
- Architecture docs exist (`implementation_plan.md`)
- `AGENTS.md` exists
- Gate runner exists (`tests/run_gates.sh`)
- `TODO.md` rule documented in `AGENTS.md`

### Phase 1 — Scaffolding & Hygiene (9 gates)
- LICENSE (MIT), `.gitignore`, `requirements.txt`
- `CONTRIBUTING.md`, PR template
- `docs/index.html` exists, root `index.html` removed
- Pages scoped to `docs/`

### Phase 2 — Shell Hardening + Homebrew (14 gates)
- `bash -n` + `shellcheck` clean
- `--version`, `--help` flags work
- Core functions exist: `detect_platform`, `install_brew`, `check_brew`
- `trap` cleanup, SHA-256 verification, `LINUX_X64_SHA256` constant
- Old `$0` bash detection removed
- Hierarchical menu system (`main_menu`, `install_submenu`, `cleanup_submenu`)
- Auto-detect recommendation

### Phase 3 — Pipeline Fixes (11 gates)
- Pinned action versions (`checkout@v4`, `setup-python@v5`)
- `requirements.txt` used, URL validation (`raise_for_status`), `shellcheck` in CI
- Safe `sed` delimiter (`#`), SHA-256 sync step (`update_config.py`)
- Scraper: compiles, has docstring, type hints, stderr error reporting

### Phase 4 — Docs & Polish (13 gates)
- Landing page: Lucide pinned, meta tags, OG tags, favicon, aria labels
- Homebrew in landing page, `aria-expanded` toggle
- README: architecture, Homebrew, troubleshooting, roadmap, changelog, scope claim

### Phase 5 — Bundler & Tooling (14 gates)
- `build.sh` exists and produces output
- `src/` structure: `00_config.sh`, `40_ui.sh`, `99_main.sh`
- `--demo-ui` flag and sandbox loop exist
- Screenshot tooling: `render.html`, `capture.py`
- Screenshot PNGs: `main_menu`, `install_submenu`, `cleanup_submenu`
- `AGENTS.md` documents `src/`

### Phase 6 — Jules CLI & Bootstrapping (19 gates)
- Syntax validation (`bash -n`) and `shellcheck` clean
- CLI flags: `--install-jules`, `--install-sandbox`, `--install-agy-box` with comprehensive `--help` output
- Jules configuration constants (`DEFAULT_JULES_VERSION`)
- Dependency bootstrapping functions: `ensure_brew()`, `ensure_node()`, `install_jules()`
- Health check verification integration for Google Jules CLI
- Sandbox mock support for `@google/jules` npm package and `jules_menu`
- `agy-box` v0.6.0 multi-arch container orchestration (`DEFAULT_AGY_BOX_VERSION`, `install_agy_box()`, `uninstall_agy_box()`)
- `versions.json` entry and tracking for `agy-box` releases

---

## Release & Distribution Model

The project employs a dual-channel release architecture:

1. **Stable Channel (`v*`, current release `v0.3.0`)**:
   - Pushing semver release tags triggers [`.github/workflows/release.yml`](../../.github/workflows/release.yml).
   - Automatically runs full test suite (`bash tests/run_gates.sh --phase all`) and builds standalone `antigravity-manager.sh`.
   - Generates SHA-256 checksums (`SHA256SUMS`).
   - Publishes GitHub Releases with release notes, marked as `latest`.
   - Install URL:
     ```bash
     curl -fSsL "https://github.com/wtg-codes/agy-easy-install/releases/latest/download/antigravity-manager.sh" | bash
     ```

2. **Nightly Rolling Channel (`nightly`)**:
   - Scheduled daily workflow ([`.github/workflows/nightly-update.yml`](../../.github/workflows/nightly-update.yml)) executes at 06:00 UTC.
   - Scrapes Google's latest download endpoints for Antigravity IDE, CLI, and SDK binaries and computes verified SHA-512/SHA-256 hashes.
   - Automatically runs full 85-gate test suite, compiles manager, and validates shell scripts.
   - Updates the rolling `nightly` pre-release tag with new checksums.
   - Install URL:
     ```bash
     curl -fSsL "https://github.com/wtg-codes/agy-easy-install/releases/download/nightly/antigravity-manager.sh" | bash
     ```

3. **Containerized Sandbox (`agy-box` v0.6.0)**:
   - Deep integration with downstream multi-arch container image `ghcr.io/wtg-codes/agy-box:v0.6.0` (and `:latest`).
   - Supports distrobox, Podman, and Docker container environments across Linux (amd64, arm64) and Windows WSL2.

---

## Upcoming Work

See [`TODO.md`](../../TODO.md) for the detailed, structured task list. Key areas:

### macOS Validation (Beta → Stable)

> 📄 **[platform-macos.md](platform-macos.md)** — full architecture reference

**Completed:** `shasum -a 256` fallback, `~/.zprofile` PATH injection, tarball fallback unblocked, Gatekeeper `xattr` warning, platform-aware URL opener (easter egg).
**Remaining:** End-to-end testing on physical Apple Silicon + Intel hardware, `gum` arm64 bootstrap validation, Homebrew cask formula testing.

### Crostini (ChromeOS) — ⚠️ Beta

> 📄 **[platform-crostini.md](platform-crostini.md)** — full architecture reference

**Completed:** `/dev/.cros_milestone` detection, ChromeOS milestone in system info dashboard, `garcon-url-handler` Chrome-not-in-container warning.
**Remaining:** End-to-end testing on ChromeOS hardware (x86_64 and ARM), `gum` arm64 bootstrap on Chromebooks.

### Windows (WSL2 + Git Bash) — ⚠️ Beta

> 📄 **[platform-windows.md](platform-windows.md)** — full architecture reference

**Completed:** WSL2 detection (`/proc/version`), `(WSL)` label in dashboard, `.desktop` skip in WSL, `wslview` browser opener, MSYS2/Git Bash hard-exit redirect to WSL2.
**Remaining:** End-to-end testing in WSL2 Ubuntu.

### Official Precompiled Binaries (macOS / Windows)
- Scraper `scrape_latest.py` and nightly CI now scrape and track official release URLs and hashes across macOS (`mac-x64`, `mac-arm64`) and Windows (`windows-x64`, `windows-arm64`) binaries alongside the Linux tarball.
- `versions.json` maintains full multi-platform release maps for Antigravity 2.0.0, IDE 1.23.2, CLI 1.3.3, SDK 0.1.21, and `agy-box` v0.6.0.

### CI & Quality
- ✅ GitHub Actions CI workflow (`ci.yml`) — runs phase gates on `ubuntu-latest` and `macos-latest`
- ✅ Dual-channel release automation (`release.yml` and `nightly-update.yml`)
- `--check` flag for installation health verification (planned)

---

## Screenshot Regeneration

When the terminal UI changes, update the screenshots:

```bash
# 1. Edit docs/images/render.html to match new menu text
# 2. Regenerate PNGs
python3 docs/images/capture.py
# 3. Verify in README and landing page
```

---

## Architecture Reference Index

### Platform Docs

| Platform | Doc | Status |
|---|---|---|
| Linux (umbrella) | [platform-linux.md](platform-linux.md) | ✅ Tested |
| ↳ Debian/Ubuntu (APT) | [platform-linux-apt.md](platform-linux-apt.md) | ✅ Tested |
| ↳ Fedora/RHEL (DNF) | [platform-linux-dnf.md](platform-linux-dnf.md) | ✅ Tested |
| ↳ Atomic/Immutable | [platform-linux-atomic.md](platform-linux-atomic.md) | ✅ Tested |
| macOS | [platform-macos.md](platform-macos.md) | ⚠️ Beta |
| Crostini (ChromeOS) | [platform-crostini.md](platform-crostini.md) | ⚠️ Beta |
| Windows (WSL2 + Git Bash) | [platform-windows.md](platform-windows.md) | ⚠️ Beta |

### Install Method Docs

| Method | Doc | Needs sudo? |
|---|---|---|
| Homebrew | [install-homebrew.md](install-homebrew.md) | No |
| System Repo (APT/DNF) | [install-repo.md](install-repo.md) | Yes |
| Tarball (standalone) | [install-tarball.md](install-tarball.md) | No |

### Package Specification Docs

| Package | Doc | Scope |
|---|---|---|
| Antigravity IDE | [package-antigravity-ide.md](package-antigravity-ide.md) | GUI Desktop IDE |
| Antigravity CLI | [package-antigravity-cli.md](package-antigravity-cli.md) | Command line `agy` tool |
| Antigravity SDK | [package-antigravity-sdk.md](package-antigravity-sdk.md) | `google-antigravity` Python library |

### Architectural Decision Records (ADRs)

We document major architectural decisions and trade-offs. Read the detailed ADR files:
* **[ADR Index](adr/README.md)**
* **[ADR-0001: Single-Script Bundling Architecture](adr/0001-single-script-bundle.md)**
* **[ADR-0002: Ephemeral Gum TUI Bootstrap](adr/0002-ephemeral-gum-tui-bootstrap.md)**
* **[ADR-0003: Platform-Aware Installation Target Selection](adr/0003-platform-aware-installation.md)**

---

## File Map

See `AGENTS.md` for the complete, authoritative file map.
