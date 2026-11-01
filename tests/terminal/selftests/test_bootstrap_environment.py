from pathlib import Path
import os
import sys
import unittest
from unittest.mock import patch

TERMINAL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TERMINAL_ROOT))

from framework.gerber_app import GerberTerminalApp, LaunchOptions


class BootstrapEnvironmentTests(unittest.TestCase):
    def test_retains_caller_dependencies_without_broadening_fixture_discovery(self):
        options = LaunchOptions(Path("/core"), Path("/fixture"), None, 120, 40)
        app = GerberTerminalApp(options)
        with patch.dict(os.environ, {"PSModulePath": "/runtime/dependencies"}):
            environment = app._build_environment(enable_synthetic_plugin=True)
        self.assertEqual("/runtime/dependencies", environment["GERBER_TERMINAL_RUNTIME_MODULE_PATH"])
        self.assertEqual(os.pathsep.join(("/fixture", "/core/dist")), environment["PSModulePath"])


if __name__ == "__main__":
    unittest.main()
