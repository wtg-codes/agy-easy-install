"""
Scrapes the latest Google Antigravity Hub, IDE, CLI, Extensions, SDK, and agy-box
versions and binary checksums from official upstream endpoints.
"""
import concurrent.futures
import hashlib
import json
import re
import sys
from typing import Any, Dict, List, Optional, Tuple

import requests

SITE_ROOT = "https://antigravity.google"
DOWNLOAD_PAGE = "https://antigravity.google/download"
HUB_RELEASES_API = "https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases"
IDE_RELEASES_API = "https://antigravity-ide-auto-updater-974169037036.us-central1.run.app/releases"
IDE_UPDATE_BASE = "https://antigravity-ide-auto-updater-974169037036.us-central1.run.app/api/update"
CLI_RELEASES_API = "https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/releases"
CLI_MANIFEST_BASE = "https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests"
PYPI_SDK_API = "https://pypi.org/pypi/google-antigravity/json"
OPENVSX_VSCODE_API = "https://open-vsx.org/api/Google/google-antigravity"
AGY_BOX_RELEASES_API = "https://api.github.com/repos/wtg-codes/agy-box/releases"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
    "Accept-Encoding": "gzip, deflate",
}

IDE_TARGETS = ["LINUX_X64", "LINUX_ARM64", "MAC_X64", "MAC_ARM64", "WIN_X64", "WIN_ARM64"]

CLI_PLATFORMS: Dict[str, Tuple[str, str]] = {
    "linux_amd64": ("linux-x64", "cli_linux_x64.tar.gz"),
    "linux_arm64": ("linux-arm", "cli_linux_arm64.tar.gz"),
    "linux_amd64_musl": ("linux-x64-musl", "cli_linux_x64_musl.tar.gz"),
    "linux_arm64_musl": ("linux-arm-musl", "cli_linux_arm64_musl.tar.gz"),
    "darwin_arm64": ("darwin-arm", "cli_mac_arm64.tar.gz"),
    "darwin_amd64": ("darwin-x64", "cli_mac_x64.tar.gz"),
    "windows_amd64": ("windows-x64", "cli_windows_x64.exe"),
    "windows_arm64": ("windows-arm", "cli_windows_arm64.exe"),
}

CLI_OPTIONAL_PLATFORMS = {"linux_amd64_musl", "linux_arm64_musl"}

DEFAULT_EXTENSIONS: Dict[str, Dict[str, str]] = {
    "vscode": {
        "latest": "1.11.0",
        "id": "Google.google-antigravity",
        "marketplace_url": "https://marketplace.visualstudio.com/items?itemName=Google.google-antigravity",
        "vsix_url": "https://open-vsx.org/api/Google/google-antigravity/1.11.0/file/Google.google-antigravity-1.11.0.vsix",
        "changelog_url": "https://antigravity.google/docs/changelog?tab=extensions&ide=vscode",
    },
    "visual-studio": {
        "latest": "1.0.261102.0",
        "id": "Google.GoogleAntigravity",
        "marketplace_url": "https://marketplace.visualstudio.com/items?itemName=Google.GoogleAntigravity",
        "changelog_url": "https://antigravity.google/docs/changelog?tab=extensions&ide=visual-studio",
    },
    "jetbrains": {
        "latest": "1.4.1",
        "id": "Antigravity",
        "docs_url": "https://antigravity.google/docs/ide/extensions/jetbrains",
        "changelog_url": "https://antigravity.google/docs/changelog?tab=extensions&ide=jetbrains",
    },
    "zed": {
        "latest": "1.4.1",
        "id": "antigravity",
        "docs_url": "https://antigravity.google/docs/ide/extensions/zed",
        "changelog_url": "https://antigravity.google/docs/changelog?tab=extensions&ide=zed",
    },
    "xcode": {
        "latest": "1.4.1",
        "id": "Antigravity",
        "docs_url": "https://antigravity.google/docs/ide/extensions/xcode",
        "changelog_url": "https://antigravity.google/docs/changelog?tab=extensions&ide=xcode",
    },
    "eclipse": {
        "latest": "1.0.0",
        "id": "google-antigravity",
        "marketplace_url": "https://marketplace.eclipse.org/content/google-antigravity",
        "changelog_url": "https://antigravity.google/docs/changelog?tab=extensions&ide=eclipse",
    },
}

DEFAULT_AGY_BOX: Dict[str, Dict[str, str]] = {
    "nightly": {
        "url": "https://raw.githubusercontent.com/wtg-codes/agy-box/main/agy-box-manager"
    },
    "v0.7.2": {
        "url": "https://raw.githubusercontent.com/wtg-codes/agy-box/v0.7.2/agy-box-manager"
    },
    "v0.7.1": {
        "url": "https://raw.githubusercontent.com/wtg-codes/agy-box/v0.7.1/agy-box-manager"
    },
    "v0.7.0": {
        "url": "https://raw.githubusercontent.com/wtg-codes/agy-box/v0.7.0/agy-box-manager"
    },
    "v0.6.0": {
        "url": "https://raw.githubusercontent.com/wtg-codes/agy-box/v0.6.0/agy-box-manager"
    },
    "v0.5.0": {
        "url": "https://raw.githubusercontent.com/wtg-codes/agy-box/v0.5.0/agy-box-manager"
    },
    "v0.4.2": {
        "url": "https://raw.githubusercontent.com/wtg-codes/agy-box/v0.4.2/agy-box-manager"
    },
}


def parse_version_key(version: str) -> Tuple[Tuple[int, ...], int, str]:
    """Converts a semantic version string into a sortable tuple key."""
    cleaned = version.strip().lstrip("vV")
    core, _, prerelease = cleaned.partition("-")
    nums: List[int] = []
    for part in core.split("."):
        m = re.match(r"^(\d+)", part)
        nums.append(int(m.group(1)) if m else 0)
    # Stable releases (no prerelease suffix) sort higher than prereleases of the same core version
    is_stable = 1 if not prerelease else 0
    return (tuple(nums), is_stable, prerelease)


def build_hub_platform_urls(version: str, exec_id: str) -> Dict[str, str]:
    """Builds download URLs for a Google Antigravity Hub release across all 6 platforms."""
    base = f"https://storage.googleapis.com/antigravity-public/antigravity-hub/{version}-{exec_id}"
    if version == "2.0.0":
        win_x64 = f"{base}/windows-x64/Antigravity.exe"
        win_arm64 = f"{base}/windows-arm/Antigravity.exe"
    else:
        win_x64 = f"{base}/windows-x64/Antigravity-x64.exe"
        win_arm64 = f"{base}/windows-arm/Antigravity-arm64.exe"

    return {
        "LINUX_X64": f"{base}/linux-x64/Antigravity.tar.gz",
        "LINUX_ARM64": f"{base}/linux-arm/Antigravity.tar.gz",
        "MAC_X64": f"{base}/darwin-x64/Antigravity.dmg",
        "MAC_ARM64": f"{base}/darwin-arm/Antigravity.dmg",
        "WIN_X64": win_x64,
        "WIN_ARM64": win_arm64,
    }


def build_ide_platform_urls(version: str, exec_id: str) -> Dict[str, str]:
    """Builds download URLs for a Google Antigravity IDE release (2.x or legacy 1.x)."""
    base = f"https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/{version}-{exec_id}"
    if parse_version_key(version)[0] >= (2, 0, 0):
        return {
            "LINUX_X64": f"{base}/linux-x64/Antigravity%20IDE.tar.gz",
            "LINUX_ARM64": f"{base}/linux-arm/Antigravity%20IDE.tar.gz",
            "MAC_X64": f"{base}/darwin-x64/Antigravity%20IDE.dmg",
            "MAC_ARM64": f"{base}/darwin-arm/Antigravity%20IDE.dmg",
            "WIN_X64": f"{base}/windows-x64/Antigravity%20IDE.exe",
            "WIN_ARM64": f"{base}/windows-arm64/Antigravity%20IDE.exe",
        }

    return {
        "LINUX_X64": f"{base}/linux-x64/Antigravity.tar.gz",
        "MAC_X64": f"{base}/darwin-x64/Antigravity.dmg",
        "MAC_ARM64": f"{base}/darwin-arm/Antigravity.dmg",
        "WIN_X64": f"{base}/windows-x64/Antigravity.exe",
        "WIN_ARM64": f"{base}/windows-arm64/Antigravity.exe",
    }


def compute_sha(url: str, hash_type: str = "sha256") -> str:
    """Stream downloads the URL and computes its hash (sha256 or sha512) with retry."""
    last_err: Optional[Exception] = None
    for attempt in range(3):
        try:
            h = hashlib.sha256() if hash_type == "sha256" else hashlib.sha512()
            with requests.get(url, headers=HEADERS, stream=True, timeout=120) as r:
                r.raise_for_status()
                for chunk in r.iter_content(chunk_size=262144):
                    if chunk:
                        h.update(chunk)
            return h.hexdigest()
        except Exception as err:
            last_err = err
            if attempt == 2:
                raise
    raise RuntimeError(f"Failed to hash {url}: {last_err}")


def _hash_platform_map(
    label: str,
    version: str,
    plat_urls: Dict[str, str],
    cache: Dict[str, str],
    hash_type: str = "sha256",
    optional_platforms: Optional[set] = None,
    fallback_urls: Optional[Dict[str, str]] = None,
) -> Optional[Dict[str, Dict[str, str]]]:
    """Resolves cached or freshly computed hashes in parallel for a version's platform map."""
    optional = optional_platforms or set()
    fallbacks = fallback_urls or {}
    hash_field = "sha256" if hash_type == "sha256" else "sha512"
    resolved: Dict[str, Tuple[str, str]] = {}
    to_compute: Dict[str, str] = {}

    for plat, url in plat_urls.items():
        if url in cache:
            resolved[plat] = (url, cache[url])
        elif plat in fallbacks and fallbacks[plat] in cache:
            alt = fallbacks[plat]
            resolved[plat] = (alt, cache[alt])
        else:
            to_compute[plat] = url

    if to_compute:
        def _worker(item: Tuple[str, str]) -> Tuple[str, Optional[str], Optional[str]]:
            plat, primary_url = item
            print(f"  Computing {hash_type.upper()} for {label} {version} {plat}...", file=sys.stderr)
            try:
                digest = compute_sha(primary_url, hash_type)
                return (plat, primary_url, digest)
            except Exception as err:
                alt_url = fallbacks.get(plat)
                if alt_url:
                    try:
                        digest = compute_sha(alt_url, hash_type)
                        return (plat, alt_url, digest)
                    except Exception as alt_err:
                        err = alt_err
                print(
                    f"  WARNING: Failed to download/hash {label} {primary_url}: {err}",
                    file=sys.stderr,
                )
                return (plat, None, None)

        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            for plat, final_url, digest in pool.map(_worker, list(to_compute.items())):
                if final_url and digest:
                    cache[final_url] = digest
                    resolved[plat] = (final_url, digest)
                elif plat not in optional:
                    return None

    ordered_out: Dict[str, Dict[str, str]] = {}
    for plat in plat_urls:
        if plat in resolved:
            final_url, digest = resolved[plat]
            ordered_out[plat] = {"url": final_url, hash_field: digest}
        elif plat not in optional:
            return None
    return ordered_out


def scrape_extensions(existing: Optional[Dict[str, Any]] = None) -> Dict[str, Dict[str, str]]:
    """Scrapes latest official IDE extension versions across all 6 supported editors."""
    extensions: Dict[str, Dict[str, str]] = {}
    for slug, defaults in DEFAULT_EXTENSIONS.items():
        entry = dict(defaults)
        if isinstance(existing, dict) and isinstance(existing.get(slug), dict):
            for k, v in existing[slug].items():
                if isinstance(v, str) and v:
                    entry[k] = v
        extensions[slug] = entry

    # 1. Scrape version chips on https://antigravity.google/download
    try:
        dl_resp = requests.get(DOWNLOAD_PAGE, headers=HEADERS, timeout=15)
        dl_resp.raise_for_status()
        chips = re.findall(
            r'href="/docs/changelog\?tab=extensions&(?:amp;)?ide=([a-z-]+)[^"]*"[^>]*>\s*v?([0-9][0-9A-Za-z.-]*)',
            dl_resp.text,
        )
        for slug, ver in chips:
            if slug in extensions:
                extensions[slug]["latest"] = ver
    except Exception as e:
        print(f"WARNING: Failed to scrape extension chips from {DOWNLOAD_PAGE}: {e}", file=sys.stderr)

    # 2. Enrich VS Code extension with OpenVSX version & direct VSIX URL
    try:
        ovsx_resp = requests.get(OPENVSX_VSCODE_API, headers=HEADERS, timeout=15)
        ovsx_resp.raise_for_status()
        ovsx_data = ovsx_resp.json()
        ovsx_ver = ovsx_data.get("version")
        if isinstance(ovsx_ver, str) and ovsx_ver:
            if parse_version_key(ovsx_ver) >= parse_version_key(extensions["vscode"]["latest"]):
                extensions["vscode"]["latest"] = ovsx_ver
        vsix_url = ovsx_data.get("files", {}).get("download")
        if isinstance(vsix_url, str) and vsix_url:
            extensions["vscode"]["vsix_url"] = vsix_url
        else:
            v = extensions["vscode"]["latest"]
            extensions["vscode"]["vsix_url"] = (
                f"https://open-vsx.org/api/Google/google-antigravity/{v}/file/Google.google-antigravity-{v}.vsix"
            )
    except Exception as e:
        print(f"WARNING: Failed to query OpenVSX for Google.google-antigravity: {e}", file=sys.stderr)

    return extensions


def scrape_agy_box(existing: Optional[Dict[str, Any]] = None) -> Dict[str, Dict[str, str]]:
    """Syncs agy-box release tags from GitHub while preserving awk-compatible dictionary layout."""
    merged: Dict[str, Dict[str, str]] = {}
    for source in (DEFAULT_AGY_BOX, existing if isinstance(existing, dict) else {}):
        for tag, info in source.items():
            if isinstance(info, dict) and isinstance(info.get("url"), str):
                merged[tag] = {"url": info["url"]}

    try:
        gh_resp = requests.get(AGY_BOX_RELEASES_API, headers=HEADERS, timeout=10)
        gh_resp.raise_for_status()
        releases = gh_resp.json()
        if isinstance(releases, list):
            for rel in releases:
                tag = rel.get("tag_name") if isinstance(rel, dict) else None
                if isinstance(tag, str) and tag.startswith("v"):
                    merged[tag] = {
                        "url": f"https://raw.githubusercontent.com/wtg-codes/agy-box/{tag}/agy-box-manager"
                    }
    except Exception as e:
        print(f"INFO: Could not refresh agy-box tags from GitHub API: {e}", file=sys.stderr)

    ordered: Dict[str, Dict[str, str]] = {}
    if "nightly" in merged:
        ordered["nightly"] = merged["nightly"]
    version_tags = sorted(
        [k for k in merged.keys() if k != "nightly"],
        key=parse_version_key,
        reverse=True,
    )
    for tag in version_tags:
        ordered[tag] = merged[tag]
    return ordered


def _sort_releases_desc(releases: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Deduplicates and sorts release entries by semantic version descending."""
    seen = set()
    unique: List[Dict[str, Any]] = []
    for rel in sorted(
        releases,
        key=lambda r: parse_version_key(str(r.get("version", "0.0.0"))),
        reverse=True,
    ):
        ver = rel.get("version")
        exec_id = rel.get("execution_id")
        if ver and exec_id and ver not in seen:
            seen.add(ver)
            unique.append(rel)
    return unique


def scrape_urls() -> Optional[Dict[str, Any]]:
    """Scrapes all available Hub, IDE, CLI, Extensions, SDK, and agy-box versions."""
    cache: Dict[str, str] = {}
    old_data: Dict[str, Any] = {}
    try:
        with open("versions.json", "r", encoding="utf-8") as f:
            content = f.read().strip()
            if content:
                loaded = json.loads(content)
                if isinstance(loaded, dict):
                    old_data = loaded
            if isinstance(old_data, dict):
                for section, field in (("antigravity", "sha256"), ("ide", "sha256"), ("cli", "sha512")):
                    sec_data = old_data.get(section)
                    if isinstance(sec_data, dict):
                        for _, platforms in sec_data.items():
                            if isinstance(platforms, dict):
                                for _, info in platforms.items():
                                    if isinstance(info, dict) and "url" in info and field in info:
                                        cache[info["url"]] = info[field]
    except Exception as e:
        print(f"INFO: Could not load existing versions.json for caching: {e}", file=sys.stderr)
        old_data = {}

    results: Dict[str, Any] = {
        "antigravity": {},
        "ide": {},
        "cli": {},
        "extensions": {},
        "sdk": {"latest": "0.1.0", "versions": ["0.1.0"]},
        "agy-box": scrape_agy_box(old_data.get("agy-box") if isinstance(old_data, dict) else None),
    }

    # Step 1: Fetch Google Antigravity Hub releases (tab=hub)
    print("Fetching active Google Antigravity Hub releases from API...", file=sys.stderr)
    try:
        hub_resp = requests.get(HUB_RELEASES_API, headers=HEADERS, timeout=15)
        hub_resp.raise_for_status()
        hub_releases = _sort_releases_desc(hub_resp.json())
    except Exception as e:
        print(f"ERROR: Failed to fetch Hub releases from API: {e}", file=sys.stderr)
        return None

    for release in hub_releases[:5]:
        version = str(release["version"])
        exec_id = str(release["execution_id"])
        print(f"Scraping Hub version {version}...", file=sys.stderr)
        plat_urls = build_hub_platform_urls(version, exec_id)
        base = f"https://storage.googleapis.com/antigravity-public/antigravity-hub/{version}-{exec_id}"
        fallbacks = {
            "WIN_X64": f"{base}/windows-x64/Antigravity.exe",
            "WIN_ARM64": f"{base}/windows-arm/Antigravity.exe",
        }
        version_data = _hash_platform_map(
            "Hub", version, plat_urls, cache, hash_type="sha256", fallback_urls=fallbacks
        )
        if version_data:
            results["antigravity"][version] = version_data

    if not results["antigravity"]:
        print("ERROR: Zero valid Hub releases scraped.", file=sys.stderr)
        return None

    # Step 2: Fetch Google Antigravity IDE releases (tab=ide)
    print("Fetching active Antigravity IDE releases from API...", file=sys.stderr)
    try:
        ide_resp = requests.get(IDE_RELEASES_API, headers=HEADERS, timeout=15)
        ide_resp.raise_for_status()
        ide_releases = _sort_releases_desc(ide_resp.json())
    except Exception as e:
        print(f"ERROR: Failed to fetch IDE releases from API: {e}", file=sys.stderr)
        return None

    # Seed latest IDE SHA-256s from official /api/update endpoints when available
    zero_commit = "0" * 40
    for upd_plat in ("linux-x64", "linux-arm64", "win32-x64-user", "win32-arm64-user"):
        try:
            u_resp = requests.get(
                f"{IDE_UPDATE_BASE}/{upd_plat}/stable/{zero_commit}",
                headers=HEADERS,
                timeout=10,
            )
            if u_resp.status_code == 200:
                u_data = u_resp.json()
                if isinstance(u_data, dict) and u_data.get("url") and u_data.get("sha256hash"):
                    normalized_url = str(u_data["url"]).replace(" ", "%20")
                    cache[normalized_url] = str(u_data["sha256hash"])
        except Exception:
            pass

    for release in ide_releases[:5]:
        version = str(release["version"])
        exec_id = str(release["execution_id"])
        print(f"Scraping IDE version {version}...", file=sys.stderr)
        plat_urls = build_ide_platform_urls(version, exec_id)
        base = f"https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/{version}-{exec_id}"
        fallbacks = {
            "WIN_ARM64": f"{base}/windows-arm/Antigravity%20IDE.exe"
            if parse_version_key(version)[0] >= (2, 0, 0)
            else f"{base}/windows-arm/Antigravity.exe"
        }
        version_data = _hash_platform_map(
            "IDE", version, plat_urls, cache, hash_type="sha256", fallback_urls=fallbacks
        )
        if version_data:
            results["ide"][version] = version_data

    if not results["ide"]:
        print("ERROR: Zero valid IDE releases scraped.", file=sys.stderr)
        return None

    # Step 3: Fetch CLI releases & seed latest SHA-512s from official manifests
    print("Fetching active CLI releases from API...", file=sys.stderr)
    try:
        cli_resp = requests.get(CLI_RELEASES_API, headers=HEADERS, timeout=15)
        cli_resp.raise_for_status()
        cli_releases = _sort_releases_desc(cli_resp.json())
    except Exception as e:
        print(f"ERROR: Failed to fetch CLI releases: {e}", file=sys.stderr)
        return None

    for plat in CLI_PLATFORMS:
        try:
            m_resp = requests.get(f"{CLI_MANIFEST_BASE}/{plat}.json", headers=HEADERS, timeout=10)
            if m_resp.status_code == 200:
                m_data = m_resp.json()
                if isinstance(m_data, dict) and m_data.get("url") and m_data.get("sha512"):
                    cache[m_data["url"]] = m_data["sha512"]
        except Exception:
            pass

    for release in cli_releases[:5]:
        version = str(release["version"])
        exec_id = str(release["execution_id"])
        print(f"Scraping CLI version {version}...", file=sys.stderr)
        cli_urls = {
            plat: f"https://storage.googleapis.com/antigravity-public/antigravity-cli/{version}-{exec_id}/{plat_dir}/{filename}"
            for plat, (plat_dir, filename) in CLI_PLATFORMS.items()
        }
        version_data = _hash_platform_map(
            "CLI",
            version,
            cli_urls,
            cache,
            hash_type="sha512",
            optional_platforms=CLI_OPTIONAL_PLATFORMS,
        )
        if version_data:
            results["cli"][version] = version_data

    if not results["cli"]:
        print("ERROR: Zero valid CLI releases scraped.", file=sys.stderr)
        return None

    # Step 4: Scrape IDE Extensions (tab=extensions)
    print("Scraping IDE extensions metadata...", file=sys.stderr)
    results["extensions"] = scrape_extensions(
        old_data.get("extensions") if isinstance(old_data, dict) else None
    )

    # Step 5: Fetch SDK release from PyPI with semantic version sorting
    print("Fetching SDK release from PyPI...", file=sys.stderr)
    try:
        pypi_resp = requests.get(PYPI_SDK_API, headers=HEADERS, timeout=15)
        pypi_resp.raise_for_status()
        pypi_data = pypi_resp.json()
        latest_sdk = pypi_data["info"]["version"]
        all_sdk_versions = sorted(
            list(pypi_data["releases"].keys()),
            key=parse_version_key,
            reverse=True,
        )
        results["sdk"] = {
            "latest": latest_sdk,
            "versions": all_sdk_versions,
        }
    except Exception as e:
        print(f"WARNING: Failed to fetch SDK release from PyPI: {e}", file=sys.stderr)
        if isinstance(old_data.get("sdk"), dict):
            results["sdk"] = old_data["sdk"]

    return results


if __name__ == "__main__":
    data = scrape_urls()
    if data:
        print(json.dumps(data, indent=2))
    else:
        sys.exit(1)
