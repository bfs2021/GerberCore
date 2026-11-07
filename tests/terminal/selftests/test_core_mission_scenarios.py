from pathlib import Path
import sys
import unittest


TERMINAL_ROOT = Path(__file__).resolve().parents[1]
if str(TERMINAL_ROOT) not in sys.path:
    sys.path.insert(0, str(TERMINAL_ROOT))

from framework.scenario_registry import SCENARIO_REGISTRY  # noqa: E402
from scenarios.core_mission_support import (  # noqa: E402
    assert_confirmation_event,
    assert_http_request,
    assert_mutation_target,
    assert_no_secret_leak,
    assert_preview,
    assert_selected_text,
    strict_http_fixture,
)


class FakeApp:
    def __init__(self, *, visible: str = "", raw: str = "", trace: str = "") -> None:
        self._visible = visible
        self._raw = raw
        self._trace = trace

    def visible_text(self) -> str:
        return self._visible

    def raw_output(self) -> str:
        return self._raw

    def prompt_trace_text(self) -> str:
        return self._trace


class CoreMissionScenarioSupportTests(unittest.TestCase):
    def test_requested_core_mission_scenarios_are_registered(self) -> None:
        scenario_id_set = {item.id for item in SCENARIO_REGISTRY}

        self.assertTrue(
            {
                "core-mission-secrets-lifecycle",
                "core-mission-secrets-storage-recovery",
            }.issubset(scenario_id_set)
        )

    def test_strict_fixture_rejects_unexpected_requests(self) -> None:
        fixture = strict_http_fixture([])

        self.assertEqual(
            fixture["defaultResult"],
            {
                "type": "error",
                "message": "Unexpected Gerber Core terminal HTTP request.",
            },
        )

    def test_http_request_assertion_rejects_wrong_method_uri_and_body(self) -> None:
        request = {
            "method": "Patch",
            "uri": "https://example.test/repositories/1",
            "body": {"defaultBranch": "refs/heads/main"},
        }

        for override in (
            {"method": "Post"},
            {"uri": "https://example.test/repositories/2"},
            {"body": {"defaultBranch": "refs/heads/develop"}},
        ):
            expected = dict(request)
            expected.update(override)
            with self.assertRaises(AssertionError):
                assert_http_request(request, **expected)

    def test_evidence_assertions_reject_wrong_selection_preview_and_target(self) -> None:
        with self.assertRaises(AssertionError):
            assert_selected_text("Selected: Repository A", "Repository B")
        with self.assertRaises(AssertionError):
            assert_preview("Preview: Apply to Repository A", "Repository B")
        with self.assertRaises(AssertionError):
            assert_mutation_target(
                [{"method": "Patch", "uri": "https://example.test/repositories/1"}],
                "https://example.test/repositories/2",
            )

    def test_confirmation_assertion_rejects_missing_confirmation(self) -> None:
        with self.assertRaises(AssertionError):
            assert_confirmation_event('{"Event":"different-event","Data":{}}', "expected-event")

    def test_secret_leak_detection_checks_screen_raw_output_and_trace(self) -> None:
        for app in (
            FakeApp(visible="secret-value"),
            FakeApp(raw="secret-value"),
            FakeApp(trace="secret-value"),
        ):
            with self.assertRaises(AssertionError):
                assert_no_secret_leak(app, "secret-value")

if __name__ == "__main__":
    unittest.main()
