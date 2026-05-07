# agv-easy-install

A simple way for students to install Google Antigravity on Linux.

## Quick Install (Interactive Guide)

Check out our [Setup Guide](https://wtg-codes.github.io/agv-easy-install/) for a step-by-step walkthrough.

## Quick Install (Terminal)

To install Google Antigravity, run the following command in your terminal:

```bash
curl -sL https://raw.githubusercontent.com/wtg-codes/agv-easy-install/main/antigravity-manager.sh | bash
```

## Management Script

The installation script is also a manager that allows you to install or remove the application.

### Reinstalling / Updating (Default)

To reinstall or update to the latest version handled by this script:

```bash
curl -sL https://raw.githubusercontent.com/wtg-codes/agv-easy-install/main/antigravity-manager.sh | bash
```

Or if you have the script locally:

```bash
./antigravity-manager.sh --install
```

### Uninstalling

To remove Google Antigravity and its shortcuts (keeping your workspace safe):

```bash
./antigravity-manager.sh --remove
```
