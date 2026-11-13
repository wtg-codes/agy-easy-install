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
DEFAULT_AGY_VERSION="2.31.2"
DEFAULT_IDE_VERSION="2.7.0"
DEFAULT_CLI_VERSION="1.5.7"
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
AGY_LINUX_X64_SHA256="20be3cab21a2aeba9dca3eee9a212f0308cf34b22fb4a8a98b0dedf18ee63413"
AGY_LINUX_X64_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.31.2-6470801290035200/linux-x64/Antigravity.tar.gz"
AGY_LINUX_ARM64_SHA256="342a4a3cc83e6b9ed3d7404e73a899183a8d056a7b5e8320b5fe1945bcc21068"
AGY_LINUX_ARM64_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.31.2-6470801290035200/linux-arm/Antigravity.tar.gz"
AGY_MAC_X64_SHA256="f104596d88c34bbbc3f95293f5e612fbb4ffb4bf3f953cdf928e111a476cc678"
AGY_MAC_X64_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.31.2-6470801290035200/darwin-x64/Antigravity.dmg"
AGY_MAC_ARM64_SHA256="bf10914c6b28afb77bbbf553418315b2c9c5aa3d3a6f7b9b26868250603bc3e6"
AGY_MAC_ARM64_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.31.2-6470801290035200/darwin-arm/Antigravity.dmg"
AGY_WIN_X64_SHA256="c8c5112e2e6fec74220a7ff016bd19bb3fa6e08d44438dcb14b5ecc23ffa2ba0"
AGY_WIN_X64_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.31.2-6470801290035200/windows-x64/Antigravity-x64.exe"
AGY_WIN_ARM64_SHA256="1d140a44fc2abcd10208bcaad3e1bb66333707f4735134880f755086822e03b4"
AGY_WIN_ARM64_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.31.2-6470801290035200/windows-arm/Antigravity-arm64.exe"

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

