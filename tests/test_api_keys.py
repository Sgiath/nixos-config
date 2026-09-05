import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "modules/nixos/sgiath/load-api-keys.py"


class ApiKeyEnvironmentTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.secret = self.root / "token"
        self.value = "spaces ' quotes \" $HOME $(false) \\ and\nnewlines"
        self.secret.write_text(self.value)
        self.mapping = self.root / "mapping.json"
        self.mapping.write_text(json.dumps({"TEST_API_TOKEN": str(self.secret)}))

    def invoke(self, *arguments):
        return subprocess.run(
            [sys.executable, str(SCRIPT), str(self.mapping), *arguments],
            capture_output=True, text=True,
        )

    def test_shell_output_preserves_values_without_executing_them(self):
        result = self.invoke("--shell")
        self.assertEqual(result.returncode, 0, result.stderr)
        shell = subprocess.run(
            ["bash", "-c", result.stdout + '\nexec "$PYTHON" -c "import os; print(repr(os.environ[\'TEST_API_TOKEN\']))"'],
            env={**os.environ, "PYTHON": sys.executable}, capture_output=True, text=True,
        )
        self.assertEqual(shell.returncode, 0, shell.stderr)
        self.assertEqual(shell.stdout.strip(), repr(self.value))

    def test_command_receives_credentials_and_keeps_exit_status(self):
        result = self.invoke(
            sys.executable, "-c",
            "import os, sys; print(repr(os.environ['TEST_API_TOKEN'])); sys.exit(23)",
        )
        self.assertEqual(result.returncode, 23)
        self.assertEqual(result.stdout.strip(), repr(self.value))

    def test_missing_secret_fails_before_starting_command(self):
        self.secret.unlink()
        result = self.invoke(sys.executable, "-c", "print('started')")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertIn("TEST_API_TOKEN", result.stderr)

    def test_null_byte_fails_without_echoing_secret(self):
        self.secret.write_text("sensitive\x00token")
        result = self.invoke("--shell")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("sensitive", result.stderr)
        self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
