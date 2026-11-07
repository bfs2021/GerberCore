from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, call

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from scenarios.plugins import approve_synthetic_plugin, synthetic_plugin_discovery


class PluginFixtureContractTests(unittest.TestCase):
    def test_approval_waits_for_rendered_focus_after_exactly_one_down_key(self):
        app = Mock()

        def check_selection(text):
            if text == "2. Approve":
                app.wait_for_text.assert_any_call("  ❯ 2. Approve")

        app.expect_selected_suggestion.side_effect = check_selection
        approve_synthetic_plugin(SimpleNamespace(app=app))
        self.assertEqual([call("DOWN"), call("ENTER")], app.press.call_args_list)
        self.assertEqual([call("1. Decline"), call("2. Approve")], app.expect_selected_suggestion.call_args_list)
        app.wait_for_prompt.assert_called_once()

    def test_discovery_retains_all_generic_leaves_and_rejects_product_ownership(self):
        app = Mock()
        synthetic_plugin_discovery(SimpleNamespace(app=app))
        self.assertEqual([
            call("/repository empty-text"), call("/repository explode"),
            call("/repository fixture-api"), call("/repository fixture-status"),
        ], app.expect_suggestion.call_args_list)
        app.expect_text_absent.assert_any_call("/repository create")
        app.expect_text_absent.assert_any_call("/synthetic")


if __name__ == "__main__":
    unittest.main()
