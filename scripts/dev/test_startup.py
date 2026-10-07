"""Test the portable startup boundary without starting services or deploying."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class StartupInputTest(unittest.TestCase):
    def test_help_and_missing_input_work_without_neighboring_repositories(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            script = directory / "relocated contracts" / "scripts/dev/start.sh"
            script.parent.mkdir(parents=True)
            script.write_bytes(
                (ROOT / "scripts/dev/start-local-gl1-stack.sh").read_bytes()
            )
            environment = {"PATH": os.environ["PATH"], "HOME": temporary}
            help_result = subprocess.run(
                ["bash", str(script), "--help"],
                env=environment,
                capture_output=True,
                check=False,
                text=True,
            )
            self.assertEqual(help_result.returncode, 0)
            result = subprocess.run(
                ["bash", str(script), "check"],
                env=environment,
                capture_output=True,
                check=False,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("demo.env", result.stderr)
            self.assertFalse((script.parents[2] / "runs").exists())

    def test_preflight_accepts_explicit_relocated_asset_directories(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            oracle = directory / "oracle assets"
            keripy = directory / "witness assets"
            schemas = directory / "schema assets"
            assets = {
                oracle
                / "protocol/external-association-v1/association.schema.json": json.dumps(
                    {"$id": "fixture-schema"}
                ),
                keripy / "scripts/demo/data/rules.json": "{}",
                schemas
                / "samples/acdc/qualified-vLEI-issuer-vLEI-credential.json": "{}",
            }
            for path, value in assets.items():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(value)
            environment = {
                "PATH": os.environ["PATH"],
                "HOME": temporary,
                "ORACLE_DIR": str(oracle),
                "KERIPY_DIR": str(keripy),
                "VLEI_SCHEMA_TOOLS_DIR": str(schemas),
                "KLI": "true",
                "VLEI_SERVER": "true",
                "VLEI_ORACLE": "true",
                "FORGE": "true",
                "CAST": "true",
                "ANVIL": "true",
            }
            result = subprocess.run(
                ["bash", str(ROOT / "scripts/dev/start-local-gl1-stack.sh"), "check"],
                env=environment,
                capture_output=True,
                check=False,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Dependency inputs are ready", result.stdout)

    def test_stack_environment_preserves_shell_sensitive_checkout_paths(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            contracts = directory / "contracts.json"
            contracts.write_text(
                json.dumps(
                    {
                        name: "0x01"
                        for name in [
                            "adminControls",
                            "identityRegistry",
                            "credentialRegistry",
                            "oracleRegistry",
                            "usdcToken",
                            "wrapper",
                        ]
                    }
                )
            )
            selected = str(directory / "oracle's $literal; path")
            environment = {
                "PATH": os.environ["PATH"],
                "HOME": temporary,
                "ORACLE_DIR": selected,
                "KERIPY_DIR": selected,
                "VLEI_SCHEMA_TOOLS_DIR": selected,
                "CONTRACTS_JSON": str(contracts),
                "STACK_ENV": str(directory / "stack.env"),
            }
            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1" help >/dev/null; write_stack_env; source "$STACK_ENV"; printf "%s" "$ORACLE_DIR"',
                    "_",
                    str(ROOT / "scripts/dev/start-local-gl1-stack.sh"),
                ],
                env=environment,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, selected)


if __name__ == "__main__":
    unittest.main()
