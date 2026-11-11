"""Updates src/00_config.sh and diagram metadata from scraped versions.json."""
import json
import os
import re
import sys
from typing import List, Tuple


def parse_version_key(version: str) -> Tuple[Tuple[int, ...], int, str]:
    """Converts a semantic version string into a sortable tuple key."""
    cleaned = version.strip().lstrip("vV")
    core, _, prerelease = cleaned.partition("-")
    nums: List[int] = []
    for part in core.split("."):
        m = re.match(r"^(\d+)", part)
        nums.append(int(m.group(1)) if m else 0)
    is_stable = 1 if not prerelease else 0
    return (tuple(nums), is_stable, prerelease)


def main() -> None:
    if len(sys.argv) < 3:
        print("Usage: python update_config.py <versions.json> <src/00_config.sh>")
        sys.exit(1)

    with open(sys.argv[1], "r", encoding="utf-8") as f:
        data = json.load(f)

    with open(sys.argv[2], "r", encoding="utf-8") as f:
        config = f.read()

    # 1. Parse Google Antigravity Hub releases and find the latest version
    agy_data = data.get("antigravity", {})
    latest_agy_ver = ""
    if agy_data:
        latest_agy_ver = sorted(agy_data.keys(), key=parse_version_key, reverse=True)[0]
        agy_ver_pattern = re.compile(r'^DEFAULT_AGY_VERSION=".*"$', re.MULTILINE)
        if agy_ver_pattern.search(config):
            config = agy_ver_pattern.sub(f'DEFAULT_AGY_VERSION="{latest_agy_ver}"', config)

        for key, info in agy_data[latest_agy_ver].items():
            url = info["url"]
            sha = info["sha256"]

            url_pattern = re.compile(rf'^AGY_{key}_URL=".*"$', re.MULTILINE)
            if url_pattern.search(config):
                config = url_pattern.sub(f'AGY_{key}_URL="{url}"', config)

            sha_pattern = re.compile(rf'^AGY_{key}_SHA256=".*"$', re.MULTILINE)
            if sha_pattern.search(config):
                config = sha_pattern.sub(f'AGY_{key}_SHA256="{sha}"', config)

    # 2. Parse Antigravity IDE releases and find the latest version
    ide_data = data.get("ide", {})
    latest_ide_ver = ""
    if ide_data:
        latest_ide_ver = sorted(ide_data.keys(), key=parse_version_key, reverse=True)[0]
        ide_ver_pattern = re.compile(r'^DEFAULT_IDE_VERSION=".*"$', re.MULTILINE)
        if ide_ver_pattern.search(config):
            config = ide_ver_pattern.sub(f'DEFAULT_IDE_VERSION="{latest_ide_ver}"', config)

        for key, info in ide_data[latest_ide_ver].items():
            url = info["url"]
            sha = info["sha256"]

            url_pattern = re.compile(rf'^{key}_URL=".*"$', re.MULTILINE)
            if url_pattern.search(config):
                config = url_pattern.sub(f'{key}_URL="{url}"', config)
            else:
                print(f"WARNING: {key}_URL not found in config")

            sha_pattern = re.compile(rf'^{key}_SHA256=".*"$', re.MULTILINE)
            if sha_pattern.search(config):
                config = sha_pattern.sub(f'{key}_SHA256="{sha}"', config)
            else:
                print(f"WARNING: {key}_SHA256 not found in config")

            ide_url_pattern = re.compile(rf'^IDE_{key}_URL=".*"$', re.MULTILINE)
            if ide_url_pattern.search(config):
                config = ide_url_pattern.sub(f'IDE_{key}_URL="{url}"', config)

            ide_sha_pattern = re.compile(rf'^IDE_{key}_SHA256=".*"$', re.MULTILINE)
            if ide_sha_pattern.search(config):
                config = ide_sha_pattern.sub(f'IDE_{key}_SHA256="{sha}"', config)

    # 3. Parse CLI releases and find the latest version
    cli_data = data.get("cli", {})
    if cli_data:
        latest_cli_ver = sorted(cli_data.keys(), key=parse_version_key, reverse=True)[0]
        cli_ver_pattern = re.compile(r'^DEFAULT_CLI_VERSION=".*"$', re.MULTILINE)
        if cli_ver_pattern.search(config):
            config = cli_ver_pattern.sub(f'DEFAULT_CLI_VERSION="{latest_cli_ver}"', config)

    # 4. Parse SDK releases and find the latest version
    sdk_data = data.get("sdk", {})
    if sdk_data:
        latest_sdk_ver = sdk_data.get("latest", "0.1.0")
        sdk_ver_pattern = re.compile(r'^DEFAULT_SDK_VERSION=".*"$', re.MULTILINE)
        if sdk_ver_pattern.search(config):
            config = sdk_ver_pattern.sub(f'DEFAULT_SDK_VERSION="{latest_sdk_ver}"', config)

    # 5. Parse agy-box releases and find the latest v* tag
    box_data = data.get("agy-box", {})
    latest_box = ""
    if isinstance(box_data, dict) and box_data:
        if isinstance(box_data.get("latest"), str):
            latest_box = box_data["latest"]
        else:
            v_tags = [k for k in box_data.keys() if k.startswith("v")]
            if v_tags:
                latest_box = sorted(v_tags, key=parse_version_key, reverse=True)[0]
        if latest_box:
            box_ver_pattern = re.compile(r'^DEFAULT_AGY_BOX_VERSION=".*"$', re.MULTILINE)
            if box_ver_pattern.search(config):
                config = box_ver_pattern.sub(f'DEFAULT_AGY_BOX_VERSION="{latest_box}"', config)

    with open(sys.argv[2], "w", encoding="utf-8") as f:
        f.write(config)

    # 6. Keep Archify diagram sources in sync with latest component versions
    diagram_source = "docs/diagrams/sources/installer-architecture.architecture.json"
    if os.path.exists(diagram_source) and latest_box:
        with open(diagram_source, "r", encoding="utf-8") as f:
            diag_content = f.read()
        diag_content = re.sub(
            r"agy-box v[0-9.]+(?:-[a-zA-Z0-9.]+)?",
            f"agy-box {latest_box}",
            diag_content,
        )
        with open(diagram_source, "w", encoding="utf-8") as f:
            f.write(diag_content)

    print(
        f"Updated {sys.argv[2]} successfully with Hub {latest_agy_ver} and IDE {latest_ide_ver}."
    )


if __name__ == "__main__":
    main()
