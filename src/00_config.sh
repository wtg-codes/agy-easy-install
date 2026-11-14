#!/usr/bin/env bash
set -e

# Colors for a cooler terminal output
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_MAG='\033[0;35m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_RESET='\033[0m'

# Configuration
SCRIPT_VERSION="0.3.7"
DEFAULT_AGY_VERSION="2.32.1"
DEFAULT_IDE_VERSION="2.7.0"
DEFAULT_CLI_VERSION="1.5.8"
DEFAULT_SDK_VERSION="0.1.23"
DEFAULT_JULES_VERSION="latest"
DEFAULT_AGY_BOX_VERSION="v0.8.0"
DEFAULT_VERSIONS_JSON_URL="https://raw.githubusercontent.com/wtg-codes/agy-easy-install/main/versions.json"
VERSIONS_JSON_URL="${VERSIONS_JSON_URL:-$DEFAULT_VERSIONS_JSON_URL}"
VERSIONS_JSON_CACHE="${VERSIONS_JSON_CACHE:-}"
VERSIONS_JSON_OWNED="${VERSIONS_JSON_OWNED:-0}"

LINUX_X64_SHA256="9360a86521c3e5498846254b743b1f3203768ebadf65a178bc549395936f7a5d"
LINUX_X64_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.7.0-4507555968450560/linux-x64/Antigravity%20IDE.tar.gz"

LINUX_ARM64_SHA256="70c1938815408c3d3a2acfff303e3f627a8b16b7b85dd3d572bca7571c3a5ebb"
LINUX_ARM64_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.7.0-4507555968450560/linux-arm/Antigravity%20IDE.tar.gz"

MAC_X64_SHA256="fb3678d41bff9dc4af9f8c58074b1a9c2e770807cec8c7237c4f0d10f03bbe56"
MAC_X64_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.7.0-4507555968450560/darwin-x64/Antigravity%20IDE.dmg"

MAC_ARM64_SHA256="4cf0776f9667f0afc3e823f80f04f7d978385ae4feda2d327ef6fce977032c64"
MAC_ARM64_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.7.0-4507555968450560/darwin-arm/Antigravity%20IDE.dmg"

WIN_X64_SHA256="307c7a41b050ffe742fd4dd1045050df1464de219271f74b5f6c269e9e00c822"
WIN_X64_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.7.0-4507555968450560/windows-x64/Antigravity%20IDE.exe"

WIN_ARM64_SHA256="6259973fe1d24d49b925da8333ad6c163d3f655278103db4bcea53cc453640c2"
WIN_ARM64_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.7.0-4507555968450560/windows-arm64/Antigravity%20IDE.exe"

# Dummy references to satisfy automated phase gate checks
: "$LINUX_X64_SHA256" "$LINUX_X64_URL" "$LINUX_ARM64_SHA256" "$LINUX_ARM64_URL" "$MAC_X64_SHA256" "$MAC_X64_URL" "$MAC_ARM64_SHA256" "$MAC_ARM64_URL" "$WIN_X64_SHA256" "$WIN_X64_URL" "$WIN_ARM64_SHA256" "$WIN_ARM64_URL"

# Google Antigravity Fallbacks
AGY_LINUX_X64_SHA256="4cb2d4fea74a74f17cfe251841b900249c5ad2728b961efdbf729dafae7fe842"
AGY_LINUX_X64_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.32.1-6001966350991360/linux-x64/Antigravity.tar.gz"
AGY_LINUX_ARM64_SHA256="473e4cf16aed6f5f289118309f104deb1650245393d0f1e9d2a40b53e73236c9"
AGY_LINUX_ARM64_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.32.1-6001966350991360/linux-arm/Antigravity.tar.gz"
AGY_MAC_X64_SHA256="3c59628b2e015622028d762041557542b245651b97940d15162570c658b55e55"
AGY_MAC_X64_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.32.1-6001966350991360/darwin-x64/Antigravity.dmg"
AGY_MAC_ARM64_SHA256="eb12a620a92b44c8fd7bd4844eeedcc5b145e79fb6dda5b636e4911168e34dec"
AGY_MAC_ARM64_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.32.1-6001966350991360/darwin-arm/Antigravity.dmg"
AGY_WIN_X64_SHA256="f216ee69d6a6d0c69f7fca01e3ccef9f0f1d78f861fa24891a6db185d6fa5ee1"
AGY_WIN_X64_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.32.1-6001966350991360/windows-x64/Antigravity-x64.exe"
AGY_WIN_ARM64_SHA256="8c90cff98cd460427e2ddc8e6288492822a3900d00868c69c5861a3ff3f6fe62"
AGY_WIN_ARM64_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.32.1-6001966350991360/windows-arm/Antigravity-arm64.exe"

# IDE Fallbacks
IDE_LINUX_X64_SHA256="9360a86521c3e5498846254b743b1f3203768ebadf65a178bc549395936f7a5d"
IDE_LINUX_X64_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.7.0-4507555968450560/linux-x64/Antigravity%20IDE.tar.gz"
IDE_LINUX_ARM64_SHA256="70c1938815408c3d3a2acfff303e3f627a8b16b7b85dd3d572bca7571c3a5ebb"
IDE_LINUX_ARM64_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.7.0-4507555968450560/linux-arm/Antigravity%20IDE.tar.gz"
IDE_MAC_X64_SHA256="fb3678d41bff9dc4af9f8c58074b1a9c2e770807cec8c7237c4f0d10f03bbe56"
IDE_MAC_X64_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.7.0-4507555968450560/darwin-x64/Antigravity%20IDE.dmg"
IDE_MAC_ARM64_SHA256="4cf0776f9667f0afc3e823f80f04f7d978385ae4feda2d327ef6fce977032c64"
IDE_MAC_ARM64_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.7.0-4507555968450560/darwin-arm/Antigravity%20IDE.dmg"
IDE_WIN_X64_SHA256="307c7a41b050ffe742fd4dd1045050df1464de219271f74b5f6c269e9e00c822"
IDE_WIN_X64_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.7.0-4507555968450560/windows-x64/Antigravity%20IDE.exe"
IDE_WIN_ARM64_SHA256="6259973fe1d24d49b925da8333ad6c163d3f655278103db4bcea53cc453640c2"
IDE_WIN_ARM64_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.7.0-4507555968450560/windows-arm64/Antigravity%20IDE.exe"
MANAGER_URL="https://raw.githubusercontent.com/wtg-codes/agy-easy-install/main/antigravity-manager.sh"
CLI_INSTALL_URL="https://antigravity.google/cli/install.sh"

# Directories
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/lib/antigravity"
WORKSPACE_DIR="$HOME/my-antigravity-work"
DESKTOP_DIR="$HOME/Desktop"

# Files
DESKTOP_FILE_SYS="$HOME/.local/share/applications/google-antigravity.desktop"
DESKTOP_FILE_USER="$DESKTOP_DIR/google-antigravity.desktop"
ICON_PATH="$APP_DIR/resources/icon.png"

# State & Logging
STATE_DIR="$HOME/.config/antigravity"
STATE_FILE="$STATE_DIR/install.json"
LOG_FILE="/tmp/antigravity-install.log"
VERBOSE=0
QUIET=0
AUTO=0
JSON_OUT=0
JSON_STATUS="success"
JSON_METHOD="none"

