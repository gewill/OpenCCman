#!/usr/bin/env python3
"""Exercise the real shell entrypoints with missing inputs and failing commands."""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class CheckScriptChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="openccman-check-script-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "scripts").mkdir()
        for name in ["check-project.sh", "check-project.py", "check-control-sizing.sh"]:
            shutil.copy2(ROOT / "scripts" / name, self.root / "scripts" / name)
        self.env = dict(os.environ, PATH="/usr/bin:/bin:/usr/sbin:/sbin")

    def run_check(self, name, *arguments):
        return subprocess.run(["/bin/bash", str(self.root / "scripts" / name), *map(str, arguments)],
                              env=self.env, capture_output=True, text=True, timeout=60)

    def project_fixture(self):
        app = self.root / "OpenCCman"
        (app / "en.lproj").mkdir(parents=True)
        (self.root / "OpenCCman.xcodeproj").mkdir()
        for relative in ["OpenCCman.xcodeproj/project.pbxproj", "OpenCCman/Info.plist",
                         "OpenCCman/OpenCCman.entitlements", "OpenCCman/PrivacyInfo.xcprivacy"]:
            (self.root / relative).write_bytes(plistlib.dumps({}))
        (app / "source with spaces.swift").write_text("let number = 1\n")
        (app / "en.lproj/Localizable.strings").write_text('"key" = "value";\n')
        return app

    def test_missing_project_directory_fails(self):
        result = self.run_check("check-project.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing source directory", result.stderr)

    def test_empty_project_directory_fails(self):
        (self.root / "OpenCCman").mkdir()
        result = self.run_check("check-project.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No .swift files", result.stderr)

    def test_project_without_rg_checks_files_with_spaces(self):
        self.project_fixture()
        result = self.run_check("check-project.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS: parsed 1 Swift sources and 1 localization files", result.stdout)

    def test_swift_parse_error_is_fatal(self):
        app = self.project_fixture()
        (app / "source with spaces.swift").write_text("let =\n")
        result = self.run_check("check-project.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("PASS:", result.stdout)

    def test_localization_error_is_fatal(self):
        app = self.project_fixture()
        (app / "en.lproj/Localizable.strings").write_text('"unterminated')
        result = self.run_check("check-project.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("PASS:", result.stdout)

    def test_missing_and_empty_dependency_sources_fail(self):
        dependency = self.root / "dependency"
        result = self.run_check("check-control-sizing.sh", dependency)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing Neumorphic source directory", result.stderr)
        (dependency / "Sources/Neumorphic").mkdir(parents=True)
        result = self.run_check("check-control-sizing.sh", dependency)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No Neumorphic Swift sources", result.stderr)

    def test_dependency_compilation_error_is_fatal(self):
        source = self.root / "dependency/Sources/Neumorphic"
        source.mkdir(parents=True)
        (source / "invalid source\nwith newline.swift").write_text("let =\n")
        result = self.run_check("check-control-sizing.sh", self.root / "dependency")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error:", result.stderr)

    def test_discovery_command_failure_does_not_continue(self):
        tools = self.root / "tools"
        tools.mkdir()
        python = tools / "python3"
        python.write_text("#!/bin/sh\nexit 17\n")
        python.chmod(0o755)
        self.env["PATH"] = str(tools) + ":" + self.env["PATH"]
        result = self.run_check("check-control-sizing.sh", self.root / "dependency")
        self.assertEqual(result.returncode, 17)

    def test_control_test_exit_is_propagated(self):
        # Control checks now bundle the app localizations before running tests.
        # Supply those resources so this fixture reaches the injected executable.
        for locale in ("en", "zh-Hans", "zh-Hant"):
            resources = self.root / "OpenCCman" / f"{locale}.lproj"
            resources.mkdir(parents=True)
            (resources / "Localizable.strings").write_text('"key" = "value";\n')
        source = self.root / "dependency/Sources/Neumorphic"
        source.mkdir(parents=True)
        (source / "fixture.swift").write_text("// synthetic compiler input\n")
        tools = self.root / "tools"
        tools.mkdir()
        # Inject a compiler that succeeds but writes a failing test executable.
        compiler = tools / "xcrun"
        compiler.write_text('''#!/bin/sh
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    shift
    printf '#!/bin/sh\\nexit 19\\n' > "$1"
    chmod +x "$1"
    exit 0
  fi
  shift
done
exit 20
''')
        compiler.chmod(0o755)
        self.env["PATH"] = str(tools) + ":" + self.env["PATH"]
        result = self.run_check("check-control-sizing.sh", self.root / "dependency")
        self.assertEqual(result.returncode, 19, result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
