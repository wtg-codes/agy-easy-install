# Security Policy

## Supported Versions

Security fixes are applied to the latest minor release line and the `main` branch.

| Version | Supported |
| ------- | --------- |
| `0.3.x` / `main` | Yes |
| `< 0.3.0` | No |

## Reporting a Vulnerability

Please **do not** report security vulnerabilities through public GitHub issues, discussions, or pull requests.

Instead, report vulnerabilities privately using **GitHub Private Vulnerability Reporting**:

- Open a draft advisory at: <https://github.com/wtg-codes/agy-easy-install/security/advisories/new>

When submitting a report, please include:

- A clear description of the vulnerability and its potential impact.
- Affected files, workflow(s), script version, or commit SHA.
- Minimal reproduction steps or a proof of concept.
- Any suggested remediation, if known.

Never include real credentials, OAuth tokens, API keys, or private LAN/infrastructure endpoints in a report.

### Response Process

- We aim to acknowledge receipt of vulnerability reports within **5 business days**.
- Validated issues will be triaged, patched in a private advisory or dedicated security PR, and released with a corresponding entry in `CHANGELOG.md`.
- Please allow time for a fix and release before public disclosure.

## Security Design Notes

- **Installer Integrity:** `antigravity-manager.sh` uses `curl -fSsL` and verifies downloaded Antigravity binary archives against `KNOWN_SHA256` / scraped release checksums before installation.
- **CI Runner Isolation:** Self-hosted DGX Spark ARM64 runners are restricted from executing untrusted fork pull requests; fork PRs automatically run on GitHub-hosted `ubuntu-24.04` runners under least-privilege `contents: read` permissions.
- **Landing Page Safety:** `docs/index.html` renders fetched content via `textContent` rather than `innerHTML`.
