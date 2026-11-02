from pathlib import Path
import json
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scenarios.active_containers import _assert_lifecycle_trace, _expect_root_inventory
from run_terminal_tests import select_plugin_contract_inventory


class ActiveContainerContractTests(unittest.TestCase):
    def test_absent_roots_keep_exact_standalone_discovery(self):
        app = Mock()
        _expect_root_inventory(SimpleNamespace(app=app), False)
        app.expect_suggestion_order.assert_called_once_with([
            "/exit", "/help", "/plugins", "/update", "/secrets", "/tools",
        ])
        self.assertEqual(4, app.expect_text_absent.call_count)
        app.expect_input.assert_called_once_with("")

    def test_fixture_inventory_includes_conditional_core_containers_without_reclassifying_core_leaves(self):
        standalone = {"canonicalPath": "help", "ownerType": "Core"}
        container = {"canonicalPath": "generic", "ownerType": "Core", "conditionalContainer": True}
        leaf = {"canonicalPath": "generic leaf", "ownerType": "Plugin"}
        self.assertEqual([container, leaf], select_plugin_contract_inventory([standalone, container, leaf]))
        self.assertEqual("Core", container["ownerType"])

    def test_lifecycle_trace_requires_ordered_happy_escape_recovery_disable_and_reenable(self):
        records = self._trace_records()
        self._assert_trace(records)
        records[2], records[3] = records[3], records[2]
        with self.assertRaises(AssertionError):
            self._assert_trace(records)

    @staticmethod
    def _assert_trace(records):
        app = Mock()
        app.prompt_trace_text.return_value = "\n".join(json.dumps(item) for item in records)
        _assert_lifecycle_trace(SimpleNamespace(app=app))

    @staticmethod
    def _trace_records():
        return [
            {"Event": "prompt-submit", "Data": {"Buffer": "/repository fixture-status"}},
            {"Event": "prompt-escape", "Data": {"Buffer": "/repository "}},
            {"Event": "prompt-submit", "Data": {"Buffer": "/repository explode"}},
            {"Event": "menu-loop-exception-path", "Data": {"Path": "recoverable-error"}},
            {"Event": "prompt-submit", "Data": {"Buffer": "/plugins disable"}},
            {"Event": "prompt-submit", "Data": {"Buffer": "/plugins enable"}},
            {"Event": "prompt-submit", "Data": {"Buffer": "/repository fixture-status"}},
            {"Event": "prompt-escape", "Data": {"Buffer": "/repository "}},
        ]
