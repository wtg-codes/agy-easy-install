"""Unit and integration tests for scrape_latest.py and update_config.py."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
import scrape_latest


SAMPLE_DOWNLOAD_HTML = """
<div class="extensions-grid">
  <div><h3>Visual Studio Code</h3><a class="nav-version-chip" href="/docs/changelog?tab=extensions&amp;ide=vscode">v1.11.0</a></div>
  <div><h3>Visual Studio</h3><a class="nav-version-chip" href="/docs/changelog?tab=extensions&amp;ide=visual-studio">v1.0.261102.0</a></div>
  <div><h3>JetBrains</h3><a class="nav-version-chip" href="/docs/changelog?tab=extensions&amp;ide=jetbrains">v1.4.1</a></div>
  <div><h3>Zed</h3><a class="nav-version-chip" href="/docs/changelog?tab=extensions&amp;ide=zed">v1.4.1</a></div>
  <div><h3>Xcode</h3><a class="nav-version-chip" href="/docs/changelog?tab=extensions&amp;ide=xcode">v1.4.1</a></div>
  <div><h3>Eclipse</h3><a class="nav-version-chip" href="/docs/changelog?tab=extensions&amp;ide=eclipse">v1.0.0</a></div>
</div>
"""


class TestScraperHelpers(unittest.TestCase):
    def test_parse_version_key_sorts_semver_correctly(self):
        versions = ["0.1.9", "0.1.23", "0.1.2", "0.1.10", "2.6.0", "2.31.0", "2.0.0"]
        sorted_vers = sorted(versions, key=scrape_latest.parse_version_key, reverse=True)
        self.assertEqual(
            sorted_vers,
            ["2.31.0", "2.6.0", "2.0.0", "0.1.23", "0.1.10", "0.1.9", "0.1.2"],
        )

    def test_build_hub_platform_urls_modern_and_2_0_0(self):
        urls_231 = scrape_latest.build_hub_platform_urls("2.31.0", "6379060755038208")
        base = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.31.0-6379060755038208"
        self.assertEqual(urls_231["LINUX_X64"], f"{base}/linux-x64/Antigravity.tar.gz")
        self.assertEqual(urls_231["LINUX_ARM64"], f"{base}/linux-arm/Antigravity.tar.gz")
        self.assertEqual(urls_231["MAC_X64"], f"{base}/darwin-x64/Antigravity.dmg")
        self.assertEqual(urls_231["MAC_ARM64"], f"{base}/darwin-arm/Antigravity.dmg")
        self.assertEqual(urls_231["WIN_X64"], f"{base}/windows-x64/Antigravity-x64.exe")
        self.assertEqual(urls_231["WIN_ARM64"], f"{base}/windows-arm/Antigravity-arm64.exe")

        urls_200 = scrape_latest.build_hub_platform_urls("2.0.0", "6324554176528384")
        base_200 = "https://storage.googleapis.com/antigravity-public/antigravity-hub/2.0.0-6324554176528384"
        self.assertEqual(urls_200["WIN_X64"], f"{base_200}/windows-x64/Antigravity.exe")
        self.assertEqual(urls_200["WIN_ARM64"], f"{base_200}/windows-arm/Antigravity.exe")

    def test_build_ide_platform_urls_v2_and_v1(self):
        urls_260 = scrape_latest.build_ide_platform_urls("2.6.0", "5526304964083712")
        base = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/2.6.0-5526304964083712"
        self.assertEqual(urls_260["LINUX_X64"], f"{base}/linux-x64/Antigravity%20IDE.tar.gz")
        self.assertEqual(urls_260["LINUX_ARM64"], f"{base}/linux-arm/Antigravity%20IDE.tar.gz")
        self.assertEqual(urls_260["MAC_X64"], f"{base}/darwin-x64/Antigravity%20IDE.dmg")
        self.assertEqual(urls_260["MAC_ARM64"], f"{base}/darwin-arm/Antigravity%20IDE.dmg")
        self.assertEqual(urls_260["WIN_X64"], f"{base}/windows-x64/Antigravity%20IDE.exe")
        self.assertEqual(urls_260["WIN_ARM64"], f"{base}/windows-arm64/Antigravity%20IDE.exe")

        urls_123 = scrape_latest.build_ide_platform_urls("1.23.2", "4781536860569600")
        base_123 = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.23.2-4781536860569600"
        self.assertEqual(urls_123["LINUX_X64"], f"{base_123}/linux-x64/Antigravity.tar.gz")
        self.assertNotIn("LINUX_ARM64", urls_123)
        self.assertEqual(urls_123["WIN_X64"], f"{base_123}/windows-x64/Antigravity.exe")
        self.assertEqual(urls_123["WIN_ARM64"], f"{base_123}/windows-arm64/Antigravity.exe")

    def test_scrape_extensions_parses_all_six_ides(self):
        def fake_get(url, **kwargs):
            resp = MagicMock()
            resp.status_code = 200
            resp.raise_for_status = MagicMock()
            if url == "https://antigravity.google/download":
                resp.text = SAMPLE_DOWNLOAD_HTML
            elif url == "https://open-vsx.org/api/Google/google-antigravity":
                resp.json.return_value = {
                    "version": "1.11.0",
                    "files": {
                        "download": "https://open-vsx.org/api/Google/google-antigravity/1.11.0/file/Google.google-antigravity-1.11.0.vsix"
                    },
                }
            else:
                resp.json.return_value = {}
                resp.text = ""
            return resp

        with patch("scrape_latest.requests.get", side_effect=fake_get):
            exts = scrape_latest.scrape_extensions()

        self.assertEqual(exts["vscode"]["latest"], "1.11.0")
        self.assertEqual(exts["vscode"]["id"], "Google.google-antigravity")
        self.assertIn("Google.google-antigravity-1.11.0.vsix", exts["vscode"]["vsix_url"])
        self.assertEqual(exts["visual-studio"]["latest"], "1.0.261102.0")
        self.assertEqual(exts["visual-studio"]["id"], "Google.GoogleAntigravity")
        self.assertEqual(exts["jetbrains"]["latest"], "1.4.1")
        self.assertEqual(exts["zed"]["latest"], "1.4.1")
        self.assertEqual(exts["xcode"]["latest"], "1.4.1")
        self.assertEqual(exts["eclipse"]["latest"], "1.0.0")

    def test_scrape_urls_separates_hub_and_ide_2x_and_sorts_sdk(self):
        def fake_get(url, **kwargs):
            resp = MagicMock()
            resp.status_code = 200
            resp.raise_for_status = MagicMock()
            if url == scrape_latest.HUB_RELEASES_API:
                resp.json.return_value = [
                    {"version": "2.6.0", "execution_id": "1111"},
                    {"version": "2.31.0", "execution_id": "6379060755038208"},
                ]
            elif url == scrape_latest.IDE_RELEASES_API:
                resp.json.return_value = [
                    {"version": "2.5.5", "execution_id": "4923483625488384"},
                    {"version": "2.6.0", "execution_id": "5526304964083712"},
                ]
            elif url == scrape_latest.CLI_RELEASES_API:
                resp.json.return_value = [
                    {"version": "1.5.5", "execution_id": "6740358537805824"},
                ]
            elif "/manifests/" in url:
                plat = url.rsplit("/", 1)[-1].replace(".json", "")
                plat_dir, filename = scrape_latest.CLI_PLATFORMS[plat]
                resp.json.return_value = {
                    "version": "1.5.5",
                    "url": f"https://storage.googleapis.com/antigravity-public/antigravity-cli/1.5.5-6740358537805824/{plat_dir}/{filename}",
                    "sha512": f"manifest_sha512_{plat}",
                }
            elif url == "https://pypi.org/pypi/google-antigravity/json":
                resp.json.return_value = {
                    "info": {"version": "0.1.23"},
                    "releases": {"0.1.9": [], "0.1.23": [], "0.1.2": [], "0.1.10": []},
                }
            elif url == "https://antigravity.google/download":
                resp.text = SAMPLE_DOWNLOAD_HTML
            elif url == "https://open-vsx.org/api/Google/google-antigravity":
                resp.json.return_value = {
                    "version": "1.11.0",
                    "files": {
                        "download": "https://open-vsx.org/api/Google/google-antigravity/1.11.0/file/Google.google-antigravity-1.11.0.vsix"
                    },
                }
            elif "api.github.com/repos/wtg-codes/agy-box/releases" in url:
                resp.json.return_value = [{"tag_name": "v0.6.0"}, {"tag_name": "v0.5.0"}]
            return resp

        with patch("scrape_latest.requests.get", side_effect=fake_get), patch(
            "scrape_latest.compute_sha", side_effect=lambda u, h="sha256": f"mock_{h}"
        ), patch("builtins.open", side_effect=FileNotFoundError()):
            result = scrape_latest.scrape_urls()

        self.assertIsNotNone(result)
        # Hub 2.31.0 must be first in antigravity
        self.assertEqual(list(result["antigravity"].keys()), ["2.31.0", "2.6.0"])
        # IDE 2.6.0 must be in "ide" (NOT misrouted to "antigravity"!) and ordered descending
        self.assertEqual(list(result["ide"].keys()), ["2.6.0", "2.5.5"])
        self.assertIn("LINUX_ARM64", result["antigravity"]["2.31.0"])
        self.assertIn("LINUX_ARM64", result["ide"]["2.6.0"])
        # CLI uses manifest sha512 directly for latest version
        self.assertEqual(
            result["cli"]["1.5.5"]["linux_amd64"]["sha512"], "manifest_sha512_linux_amd64"
        )
        self.assertIn("linux_amd64_musl", result["cli"]["1.5.5"])
        # SDK versions sorted semantically, not lexicographically ("0.1.23" > "0.1.9")
        self.assertEqual(result["sdk"]["versions"], ["0.1.23", "0.1.10", "0.1.9", "0.1.2"])
        # Extensions populated
        self.assertEqual(result["extensions"]["vscode"]["latest"], "1.11.0")
        # agy-box structure preserved for awk compatibility
        self.assertIn("url", result["agy-box"]["v0.6.0"])


class TestUpdateConfig(unittest.TestCase):
    def test_update_config_updates_all_products_and_linux_arm64(self):
        sample_versions = {
            "antigravity": {
                "2.6.0": {
                    "LINUX_X64": {"url": "https://old-hub", "sha256": "old"},
                },
                "2.31.0": {
                    "LINUX_X64": {"url": "https://hub/2.31.0/linux-x64.tar.gz", "sha256": "hub_lx64"},
                    "LINUX_ARM64": {"url": "https://hub/2.31.0/linux-arm.tar.gz", "sha256": "hub_larm"},
                    "MAC_X64": {"url": "https://hub/2.31.0/mac-x64.dmg", "sha256": "hub_mx64"},
                    "MAC_ARM64": {"url": "https://hub/2.31.0/mac-arm.dmg", "sha256": "hub_marm"},
                    "WIN_X64": {"url": "https://hub/2.31.0/win-x64.exe", "sha256": "hub_wx64"},
                    "WIN_ARM64": {"url": "https://hub/2.31.0/win-arm.exe", "sha256": "hub_warm"},
                },
            },
            "ide": {
                "2.5.5": {
                    "LINUX_X64": {"url": "https://old-ide", "sha256": "old"},
                },
                "2.6.0": {
                    "LINUX_X64": {"url": "https://ide/2.6.0/Antigravity%20IDE.tar.gz", "sha256": "ide_lx64"},
                    "LINUX_ARM64": {"url": "https://ide/2.6.0/linux-arm.tar.gz", "sha256": "ide_larm"},
                    "MAC_X64": {"url": "https://ide/2.6.0/mac-x64.dmg", "sha256": "ide_mx64"},
                    "MAC_ARM64": {"url": "https://ide/2.6.0/mac-arm.dmg", "sha256": "ide_marm"},
                    "WIN_X64": {"url": "https://ide/2.6.0/win-x64.exe", "sha256": "ide_wx64"},
                    "WIN_ARM64": {"url": "https://ide/2.6.0/win-arm64.exe", "sha256": "ide_warm"},
                },
            },
            "cli": {"1.5.5": {}, "1.5.5-rc1": {}},
            "sdk": {"latest": "0.1.23", "versions": ["0.1.23"]},
            "agy-box": {
                "nightly": {"url": "x"},
                "v0.8.0": {"url": "u"},
                "v0.7.2": {"url": "v"},
                "v0.7.1": {"url": "w"},
                "v0.7.0": {"url": "z"},
                "v0.6.0": {"url": "y"},
            },
        }
        sample_config = "\n".join(
            [
                'DEFAULT_AGY_VERSION="2.0.0"',
                'DEFAULT_IDE_VERSION="1.23.2"',
                'DEFAULT_CLI_VERSION="1.5.4"',
                'DEFAULT_SDK_VERSION="0.1.0"',
                'DEFAULT_AGY_BOX_VERSION="v0.7.2"',
                'LINUX_X64_SHA256="old"',
                'LINUX_X64_URL="old"',
                'LINUX_ARM64_SHA256="old"',
                'LINUX_ARM64_URL="old"',
                'AGY_LINUX_X64_SHA256="old"',
                'AGY_LINUX_X64_URL="old"',
                'AGY_LINUX_ARM64_SHA256="old"',
                'AGY_LINUX_ARM64_URL="old"',
                'IDE_LINUX_X64_SHA256="old"',
                'IDE_LINUX_X64_URL="old"',
                'IDE_LINUX_ARM64_SHA256="old"',
                'IDE_LINUX_ARM64_URL="old"',
            ]
        )

        with tempfile.TemporaryDirectory() as tmp:
            vpath = os.path.join(tmp, "versions.json")
            cpath = os.path.join(tmp, "00_config.sh")
            diag_dir = os.path.join(tmp, "docs", "diagrams", "sources")
            os.makedirs(diag_dir, exist_ok=True)
            diag_path = os.path.join(diag_dir, "installer-architecture.architecture.json")
            with open(diag_path, "w") as f:
                f.write('{"label": "agy-box v0.6.0"}')
            with open(vpath, "w") as f:
                json.dump(sample_versions, f)
            with open(cpath, "w") as f:
                f.write(sample_config)

            repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
            res = subprocess.run(
                [sys.executable, os.path.join(repo_root, "update_config.py"), vpath, cpath],
                cwd=tmp,
                capture_output=True,
                text=True,
            )
            self.assertEqual(res.returncode, 0, msg=res.stderr + res.stdout)
            with open(cpath, "r") as f:
                updated = f.read()
            with open(diag_path, "r") as f:
                updated_diag = f.read()

        self.assertIn("agy-box v0.8.0", updated_diag)

        self.assertIn('DEFAULT_AGY_VERSION="2.31.0"', updated)
        self.assertIn('DEFAULT_IDE_VERSION="2.6.0"', updated)
        self.assertIn('DEFAULT_CLI_VERSION="1.5.5"', updated)
        self.assertIn('DEFAULT_SDK_VERSION="0.1.23"', updated)
        self.assertIn('DEFAULT_AGY_BOX_VERSION="v0.8.0"', updated)
        self.assertIn('AGY_LINUX_ARM64_URL="https://hub/2.31.0/linux-arm.tar.gz"', updated)
        self.assertIn('AGY_LINUX_ARM64_SHA256="hub_larm"', updated)
        self.assertIn('IDE_LINUX_X64_URL="https://ide/2.6.0/Antigravity%20IDE.tar.gz"', updated)
        self.assertIn('IDE_LINUX_ARM64_URL="https://ide/2.6.0/linux-arm.tar.gz"', updated)
        self.assertIn('LINUX_ARM64_URL="https://ide/2.6.0/linux-arm.tar.gz"', updated)


class TestShellParsersAndInstallers(unittest.TestCase):
    def test_shell_json_parsers_handle_multiple_versions_and_products(self):
        sample_versions = {
            "antigravity": {
                "2.31.0": {
                    "LINUX_X64": {"url": "https://hub/2.31.0/x64", "sha256": "hub231_x64"},
                    "LINUX_ARM64": {"url": "https://hub/2.31.0/arm64", "sha256": "hub231_arm"},
                },
                "2.6.0": {
                    "LINUX_X64": {"url": "https://hub/2.6.0/x64", "sha256": "hub260_x64"},
                },
            },
            "ide": {
                "2.6.0": {
                    "LINUX_X64": {"url": "https://ide/2.6.0/x64", "sha256": "ide260_x64"},
                    "LINUX_ARM64": {"url": "https://ide/2.6.0/arm64", "sha256": "ide260_arm"},
                },
                "2.5.5": {
                    "LINUX_X64": {"url": "https://ide/2.5.5/x64", "sha256": "ide255_x64"},
                },
            },
            "cli": {
                "1.5.5": {
                    "linux_amd64": {"url": "https://cli/1.5.5/amd64", "sha512": "cli155_amd64"},
                    "linux_amd64_musl": {"url": "https://cli/1.5.5/musl", "sha512": "cli155_musl"},
                },
                "1.5.4": {
                    "linux_amd64": {"url": "https://cli/1.5.4/amd64", "sha512": "cli154_amd64"},
                },
            },
            "extensions": {
                "vscode": {"latest": "1.11.0", "id": "Google.google-antigravity"},
            },
            "sdk": {"latest": "0.1.23", "versions": ["0.1.23", "0.1.10", "0.1.9"]},
            "agy-box": {
                "nightly": {"url": "https://box/nightly"},
                "v0.8.0": {"url": "https://box/v0.8.0"},
                "v0.7.2": {"url": "https://box/v0.7.2"},
                "v0.7.1": {"url": "https://box/v0.7.1"},
                "v0.7.0": {"url": "https://box/v0.7.0"},
                "v0.6.0": {"url": "https://box/v0.6.0"},
                "v0.4.2": {"url": "https://box/v0.4.2"},
            },
        }
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tf:
            json.dump(sample_versions, tf, indent=2)
            vfile = tf.name
        try:
            script = f"""
            set -e
            export VERSIONS_JSON_CACHE="{vfile}"
            source "{repo_root}/src/00_config.sh"
            source "{repo_root}/src/10_utils.sh"
            source "{repo_root}/src/30_installers.sh"
            source "{repo_root}/src/40_ui.sh"
            echo "HUB231=$(get_product_release_info antigravity 2.31.0 LINUX_X64)"
            echo "HUB231_ARM=$(get_product_release_info antigravity 2.31.0 LINUX_ARM64)"
            echo "HUB260=$(get_product_release_info antigravity 2.6.0 LINUX_X64)"
            echo "IDE260=$(get_product_release_info ide 2.6.0 LINUX_X64)"
            echo "IDE260_ARM=$(get_product_release_info ide 2.6.0 LINUX_ARM64)"
            echo "IDE255=$(get_product_release_info ide 2.5.5 LINUX_X64)"
            echo "CLI155=$(get_cli_release_info 1.5.5 linux_amd64)"
            echo "CLI155_MUSL=$(get_cli_release_info 1.5.5 linux_amd64_musl)"
            echo "CLI154=$(get_cli_release_info 1.5.4 linux_amd64)"
            echo "BOX080=$(get_agy_box_release_url v0.8.0)"
            echo "BOX072=$(get_agy_box_release_url v0.7.2)"
            echo "BOX071=$(get_agy_box_release_url v0.7.1)"
            echo "BOX070=$(get_agy_box_release_url v0.7.0)"
            echo "BOX060=$(get_agy_box_release_url v0.6.0)"
            echo "LIST_AGY=$(list_antigravity_versions | paste -sd, -)"
            echo "LIST_IDE=$(list_ide_versions | paste -sd, -)"
            echo "LIST_CLI=$(list_cli_versions | paste -sd, -)"
            echo "LIST_SDK=$(list_sdk_versions | paste -sd, -)"
            """
            res = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, msg=res.stderr)
            kv = dict(
                line.split("=", 1) for line in res.stdout.strip().splitlines() if "=" in line
            )
            self.assertEqual(kv["HUB231"], "https://hub/2.31.0/x64|hub231_x64")
            self.assertEqual(kv["HUB231_ARM"], "https://hub/2.31.0/arm64|hub231_arm")
            self.assertEqual(kv["HUB260"], "https://hub/2.6.0/x64|hub260_x64")
            self.assertEqual(kv["IDE260"], "https://ide/2.6.0/x64|ide260_x64")
            self.assertEqual(kv["IDE260_ARM"], "https://ide/2.6.0/arm64|ide260_arm")
            self.assertEqual(kv["IDE255"], "https://ide/2.5.5/x64|ide255_x64")
            self.assertEqual(kv["CLI155"], "https://cli/1.5.5/amd64|cli155_amd64")
            self.assertEqual(kv["CLI155_MUSL"], "https://cli/1.5.5/musl|cli155_musl")
            self.assertEqual(kv["CLI154"], "https://cli/1.5.4/amd64|cli154_amd64")
            self.assertEqual(kv["BOX080"], "https://box/v0.8.0")
            self.assertEqual(kv["BOX072"], "https://box/v0.7.2")
            self.assertEqual(kv["BOX071"], "https://box/v0.7.1")
            self.assertEqual(kv["BOX070"], "https://box/v0.7.0")
            self.assertEqual(kv["BOX060"], "https://box/v0.6.0")
            self.assertEqual(kv["LIST_AGY"], "2.31.0,2.6.0")
            self.assertEqual(kv["LIST_IDE"], "2.6.0,2.5.5")
            self.assertEqual(kv["LIST_CLI"], "1.5.5,1.5.4")
            self.assertEqual(kv["LIST_SDK"], "0.1.23,0.1.10,0.1.9")
        finally:
            os.remove(vfile)

    def test_vscode_extension_uses_official_marketplace_id_and_ide_binary_dispatch(self):
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        with open(os.path.join(repo_root, "src", "30_installers.sh"), "r") as f:
            installers = f.read()
        with open(os.path.join(repo_root, "src", "99_main.sh"), "r") as f:
            main_sh = f.read()
        self.assertIn("Google.google-antigravity", installers)
        self.assertNotIn("--install-extension Google.antigravity ", installers)
        self.assertIn('do_install_binary "ide" "$selected_version"', main_sh)

    def test_poisoned_tmp_versions_json_is_ignored_and_cleaned_up(self):
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        with tempfile.TemporaryDirectory() as tmp:
            poisoned = os.path.join(tmp, "versions.json")
            with open(poisoned, "w") as f:
                json.dump(
                    {
                        "antigravity": {
                            "2.31.0": {"LINUX_X64": {"url": "https://hub-231", "sha256": "bad"}}
                        },
                        "ide": {
                            "2.6.0": {"LINUX_X64": {"url": "https://ide-260", "sha256": "bad"}}
                        },
                    },
                    f,
                    indent=2,
                )
            work_dir = os.path.join(tmp, "work")
            os.makedirs(work_dir, exist_ok=True)
            script = f"""
            set -e
            export TMPDIR="{tmp}"
            unset VERSIONS_JSON_CACHE
            cd "{work_dir}"
            source "{repo_root}/src/00_config.sh"
            source "{repo_root}/src/10_utils.sh"
            source "{repo_root}/src/30_installers.sh"
            VERSIONS_JSON_URL="file://{repo_root}/versions.json"
            fetch_versions_json
            echo "CACHE_PATH=$VERSIONS_JSON_CACHE"
            echo "IDE_INFO=$(get_product_release_info ide 2.6.0 LINUX_X64)"
            echo "AGY_INFO=$(get_product_release_info antigravity 2.31.0 LINUX_X64)"
            """
            res = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, msg=res.stderr)
            kv = dict(
                line.split("=", 1) for line in res.stdout.strip().splitlines() if "=" in line
            )
            self.assertNotIn("ide-260", kv["IDE_INFO"])
            self.assertNotIn("hub-231", kv["AGY_INFO"])
            self.assertIn("edgedl.me.gvt1.com", kv["IDE_INFO"])
            self.assertIn("storage.googleapis.com", kv["AGY_INFO"])
            self.assertNotEqual(kv["CACHE_PATH"], poisoned)
            self.assertFalse(os.path.exists(kv["CACHE_PATH"]))

    def test_get_agy_box_release_url_whitespace_tolerance(self):
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        sample_box = {
            "antigravity": {},
            "agy-box": {
                "nightly": {"url": "https://box/nightly"},
                "v0.8.0": {"url": "https://box/v0.8.0"},
                "v0.7.2": {"url": "https://box/v0.7.2"},
                "v0.7.1": {"url": "https://box/v0.7.1"},
                "v0.7.0": {"url": "https://box/v0.7.0"},
                "v0.6.0": {"url": "https://box/v0.6.0"},
            },
        }
        for indent in [None, 2, 4]:
            with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tf:
                json.dump(sample_box, tf, indent=indent)
                vfile = tf.name
            try:
                script = f"""
                set -e
                export VERSIONS_JSON_CACHE="{vfile}"
                source "{repo_root}/src/00_config.sh"
                source "{repo_root}/src/10_utils.sh"
                source "{repo_root}/src/30_installers.sh"
                echo "BOX080=$(get_agy_box_release_url v0.8.0)"
                echo "BOX072=$(get_agy_box_release_url v0.7.2)"
                echo "BOX071=$(get_agy_box_release_url v0.7.1)"
                echo "BOX070=$(get_agy_box_release_url v0.7.0)"
                echo "BOX060=$(get_agy_box_release_url v0.6.0)"
                echo "ABSENT=$(get_agy_box_release_url v9.9.9)"
                """
                res = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
                self.assertEqual(res.returncode, 0, msg=res.stderr)
                kv = dict(
                    line.split("=", 1) for line in res.stdout.strip().splitlines() if "=" in line
                )
                self.assertEqual(kv["BOX080"], "https://box/v0.8.0", f"Failed on indent={indent}")
                self.assertEqual(kv["BOX072"], "https://box/v0.7.2", f"Failed on indent={indent}")
                self.assertEqual(kv["BOX071"], "https://box/v0.7.1", f"Failed on indent={indent}")
                self.assertEqual(kv["BOX070"], "https://box/v0.7.0", f"Failed on indent={indent}")
                self.assertEqual(kv["BOX060"], "https://box/v0.6.0", f"Failed on indent={indent}")
                self.assertEqual(kv["ABSENT"], "", f"Failed on absent version indent={indent}")
            finally:
                if os.path.exists(vfile):
                    os.remove(vfile)

    def test_install_agy_box_headless_flags_and_failure_diagnostics(self):
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        with tempfile.TemporaryDirectory() as tmp:
            mock_bin = os.path.join(tmp, "mockbin")
            home_dir = os.path.join(tmp, "home")
            os.makedirs(mock_bin, exist_ok=True)
            os.makedirs(home_dir, exist_ok=True)

            # Populate mock_bin WITHOUT distrobox to prove podman alone satisfies prerequisites
            import shutil

            for sys_cmd in (
                "awk",
                "bash",
                "cat",
                "chmod",
                "cp",
                "curl",
                "date",
                "dirname",
                "grep",
                "mkdir",
                "mktemp",
                "pwd",
                "rm",
                "sed",
                "tput",
            ):
                real_path = shutil.which(sys_cmd)
                if real_path:
                    os.symlink(real_path, os.path.join(mock_bin, sys_cmd))

            tpath = os.path.join(mock_bin, "podman")
            with open(tpath, "w") as f:
                f.write("#!/usr/bin/env bash\nexit 0\n")
            os.chmod(tpath, 0o755)

            mgr_source = os.path.join(tmp, "mock_agy_box_manager.sh")
            args_log = os.path.join(tmp, "mgr_calls.log")
            with open(mgr_source, "w") as f:
                f.write(
                    "#!/usr/bin/env bash\n"
                    f'echo "NONINT=${{AGY_NONINTERACTIVE:-}} ARGS=$*" >> "{args_log}"\n'
                    'if [ "${MOCK_FAIL:-0}" = "1" ]; then exit 42; fi\n'
                    "exit 0\n"
                )
            os.chmod(mgr_source, 0o755)

            script = f"""
            set -e
            export HOME="{home_dir}"
            export PATH="{mock_bin}"
            export VERSIONS_JSON_CACHE="{repo_root}/versions.json"
            export AGY_BOX_MANAGER_URL="file://{mgr_source}"
            source "{repo_root}/src/00_config.sh"
            LOG_FILE="{tmp}/install.log"
            source "{repo_root}/src/10_utils.sh"
            source "{repo_root}/src/30_installers.sh"
            PLATFORM="Linux"
            HAS_APT="yes"
            AUTO=1
            echo "VER=$SCRIPT_VERSION"
            echo "BOX_VER=$DEFAULT_AGY_BOX_VERSION"
            echo "RESOLVED=$(get_agy_box_release_url v0.8.0)"
            install_agy_box
            set +e
            MOCK_FAIL=1 install_agy_box
            echo "FAIL_RC=$?"
            """
            res = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0, msg=res.stderr + res.stdout)
            self.assertIn("VER=0.3.7", res.stdout)
            self.assertIn("BOX_VER=v0.8.0", res.stdout)
            self.assertIn(
                "RESOLVED=https://raw.githubusercontent.com/wtg-codes/agy-box/v0.8.0/agy-box-manager",
                res.stdout,
            )
            self.assertIn("--mode workstation", res.stdout)
            self.assertIn("agy-box-manager status", res.stdout)
            self.assertIn("FAIL_RC=1", res.stdout)
            self.assertIn("~/.config/agy-box/logs/agy-box-manager.log", res.stdout)
            self.assertIn("agy-box-manager logs", res.stdout)
            with open(args_log, "r") as f:
                calls = f.read()
            self.assertIn("NONINT=1 ARGS=install -y --no-enter", calls)

    def test_uninstall_agy_box_clean_all_and_legacy_fallback(self):
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        with tempfile.TemporaryDirectory() as tmp:
            # 1. Modern v0.8.0 manager supporting clean --all --purge -y
            home_v080 = os.path.join(tmp, "home_v080")
            bin_v080 = os.path.join(home_v080, ".local", "bin")
            os.makedirs(bin_v080, exist_ok=True)
            log_v080 = os.path.join(tmp, "v080_calls.log")
            mgr_v080 = os.path.join(bin_v080, "agy-box-manager")
            with open(mgr_v080, "w") as f:
                f.write(f'#!/usr/bin/env bash\necho "$*" >> "{log_v080}"\nexit 0\n')
            os.chmod(mgr_v080, 0o755)

            # 2. Legacy manager rejecting --all
            home_old = os.path.join(tmp, "home_old")
            bin_old = os.path.join(home_old, ".local", "bin")
            os.makedirs(bin_old, exist_ok=True)
            log_old = os.path.join(tmp, "old_calls.log")
            mgr_old = os.path.join(bin_old, "agy-box-manager")
            with open(mgr_old, "w") as f:
                f.write(
                    "#!/usr/bin/env bash\n"
                    f'echo "$*" >> "{log_old}"\n'
                    'if [ "$1" = "clean" ] && [ "${2:-}" = "--all" ]; then exit 2; fi\n'
                    "exit 0\n"
                )
            os.chmod(mgr_old, 0o755)

            for hdir in (home_v080, home_old):
                script = f"""
                set -e
                export HOME="{hdir}"
                source "{repo_root}/src/00_config.sh"
                LOG_FILE="{tmp}/uninstall.log"
                source "{repo_root}/src/10_utils.sh"
                source "{repo_root}/src/30_installers.sh"
                uninstall_agy_box
                """
                res = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
                self.assertEqual(res.returncode, 0, msg=res.stderr + res.stdout)

            self.assertFalse(os.path.exists(mgr_v080))
            self.assertFalse(os.path.exists(mgr_old))
            with open(log_v080, "r") as f:
                v080_calls = f.read().strip().splitlines()
            self.assertEqual(v080_calls, ["clean --all --purge -y", "uninstall-global"])

            with open(log_old, "r") as f:
                old_calls = f.read().strip().splitlines()
            self.assertEqual(old_calls, ["clean --all --purge -y", "clean", "uninstall-global"])


if __name__ == "__main__":
    unittest.main()
