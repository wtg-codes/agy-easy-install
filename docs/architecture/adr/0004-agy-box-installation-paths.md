# ADR-0004: agy-box Sandbox Installation Paths and Verification

## Status
**Accepted**

## Context
The Antigravity Developer Sandbox (`agy-box`) runs inside a containerized Distrobox environment. Installing it requires host-level virtualization and container runtimes (Podman or Docker). Because our users operate on a wide variety of platforms (macOS, WSL2 Windows, Atomic Linux, standard Debian/Ubuntu/Fedora Linux), the installation path is highly non-uniform.

If we simply check for the presence of CLI binaries (like `podman` or `distrobox`), we miss critical runtime failures such as:
1. The container daemon is not running (e.g., Docker service stopped).
2. The user has no permission to talk to the container socket (e.g., rootless Podman subuid/subgid misconfiguration or Docker group access required).
3. The directory `~/.local/bin` (where `agy-box-manager` is installed) is not present in the user's shell `$PATH`.

## Decision
To guarantee a robust installation experience, `agy-easy-install` will implement a structured **Prerequisite Decision Matrix** and perform active socket validation before executing `agy-box-manager install`.

### 1. Active Socket Verification
Instead of only checking `command -v podman`, the script will run:
*   `podman info` (or `docker info`) to verify the runtime daemon is actively responding and permissions are correct.
*   If installed but unreachable, it will output targeted platform-specific troubleshooting advice rather than failing during the mid-installation stage of `agy-box-manager`.

### 2. User Path Decision Matrix

| Host Environment | Distrobox State | Container Runtime State | Target Action / Path |
| :--- | :--- | :--- | :--- |
| **Atomic Linux** (Bluefin/wtgOS) | Pre-installed | Pre-installed & Running | Seamless install of `agy-box-manager` and container launch. |
| **Standard Linux** (Ubuntu/Fedora) | Missing | Missing | Offer to install both via host package manager (`apt`/`dnf`). |
| **Standard Linux** | Present | Present but Unreachable | Output group/service guidelines (`systemctl start docker` or check `subuid`). |
| **macOS** (Darwin) | Missing / Any | Any | Exit early with guidance to install Podman Desktop and `brew install distrobox`. |
| **Windows WSL2** | Missing / Any | Any | Exit early with guidance to configure WSL2 integration and install distrobox via curl. |
| **Headless Mode** (`--auto`) | Missing | Missing | Install automatically via package manager if `sudo` is passwordless; otherwise, exit with error code 1 immediately. |

### 3. PATH Validation Check
Before completing the installation, the script will verify if `~/.local/bin` is in the active shell `$PATH`. If it is missing, it will display a clean warning banner with instructions to source their shell profile or run:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Consequences

### Positive
*   **Reduced Support Load:** Detects socket permission and configuration errors early before the script performs partial installations.
*   **Clear Guidance:** Users on macOS and WSL2 receive actionable copy-paste instructions tailored to their OS.
*   **Predictable Automated Runs:** Headless operations exit cleanly instead of hanging or prompting for passwords.

### Negative
*   Adds slightly more logic and testing overhead inside `src/30_installers.sh`.
