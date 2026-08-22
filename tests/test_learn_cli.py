from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LearnCliTests(unittest.TestCase):
    def build_fixture(self, fixture: Path) -> dict[str, object]:
        shutil.copytree(ROOT / "bin", fixture / "bin")
        shutil.copytree(ROOT / "curriculum", fixture / "curriculum")
        manifest = json.loads((fixture / "curriculum/modules.json").read_text(encoding="utf-8"))
        for module in manifest["modules"]:
            source = ROOT / module["folder"]
            target = fixture / module["folder"]
            target.mkdir(parents=True, exist_ok=True)
            for name in ("README.md", "lesson.md", "walkthrough.md", "checks.md"):
                shutil.copy2(source / name, target / name)
        return manifest

    def run_cli_in_fixture(self, fixture: Path, *args: str) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        return subprocess.run(
            [str(fixture / "bin/learn"), *args],
            cwd=fixture,
            text=True,
            capture_output=True,
            env=environment,
            timeout=10,
        )

    def run_cli(self, *args: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Path(temporary) / "repo"
            self.build_fixture(fixture)
            return self.run_cli_in_fixture(fixture, *args)

    def test_status_and_list(self):
        manifest = json.loads((ROOT / "curriculum/modules.json").read_text(encoding="utf-8"))
        implemented = sum(module["status"] == "implemented" for module in manifest["modules"])
        status = self.run_cli("status")
        self.assertEqual(status.returncode, 0, status.stderr)
        self.assertIn(f"24 total, {implemented} implemented", status.stdout)
        listing = self.run_cli("list")
        self.assertEqual(listing.returncode, 0, listing.stderr)
        self.assertEqual(len([line for line in listing.stdout.splitlines() if line.strip()]), 24)

    def test_implemented_modules_start_and_next_scaffold_refuses(self):
        manifest = json.loads((ROOT / "curriculum/modules.json").read_text(encoding="utf-8"))
        implemented = [module for module in manifest["modules"] if module["status"] == "implemented"]
        for module in implemented:
            with self.subTest(module=module["id"]):
                result = self.run_cli("start", module["id"])
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("Guiding question:", result.stdout)

        scaffolded = next(
            (module for module in manifest["modules"] if module["status"] == "scaffolded"),
            None,
        )
        if scaffolded is not None:
            result = self.run_cli("start", scaffolded["id"])
            self.assertEqual(result.returncode, 2)
            self.assertIn("Activate its governed implementation batch", result.stdout)

    def test_refused_scaffold_does_not_replace_current_module(self):
        with tempfile.TemporaryDirectory() as temporary:
            fixture = Path(temporary) / "repo"
            manifest = self.build_fixture(fixture)
            implemented = [module for module in manifest["modules"] if module["status"] == "implemented"]
            scaffolded = next(
                (module for module in manifest["modules"] if module["status"] == "scaffolded"),
                None,
            )
            self.assertTrue(implemented)
            if scaffolded is None:
                self.skipTest("No scaffolded module remains to exercise rejection recovery.")

            current = implemented[-1]
            started = self.run_cli_in_fixture(fixture, "start", current["id"])
            self.assertEqual(started.returncode, 0, started.stderr)

            refused = self.run_cli_in_fixture(fixture, "start", scaffolded["id"])
            self.assertEqual(refused.returncode, 2)
            self.assertIn("Activate its governed implementation batch", refused.stdout)

            continued = self.run_cli_in_fixture(fixture, "continue")
            self.assertEqual(continued.returncode, 0, continued.stderr)
            self.assertIn(f"{current['id']} — {current['title']}", continued.stdout)
            state = json.loads((fixture / ".learning/progress.json").read_text(encoding="utf-8"))
            self.assertEqual(state["current"], current["id"])


if __name__ == "__main__":
    unittest.main()
