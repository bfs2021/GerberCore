from __future__ import annotations

from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import time
from typing import Any

from .artifacts import RuntimePaths
from .pty_session import PtySession, ScreenTimeoutError, SessionLaunchOptions
from .screen import ScreenSnapshot


@dataclass(frozen=True)
class LaunchOptions:
    gerber_root: Path
    synthetic_plugin_root: Path
    runtime_paths: RuntimePaths
    columns: int
    rows: int


UNEXPECTED_EXCEPTION_MARKERS = (
    "Cannot bind argument",
    "Cannot process argument transformation on parameter",
    "A positional parameter cannot be found",
    "Missing an argument for parameter",
    "NamedParameterNotFound",
    "ParameterArgumentValidationError",
    "ParameterBindingException",
    "ParameterBindingValidationException",
    "CategoryInfo",
    "FullyQualifiedErrorId",
    "ScriptStackTrace",
)
POWERSHELL_STACK_TRACE_PATTERN = re.compile(r"^\s*at .+, .+line \d+$", re.MULTILINE)
SUGGESTION_PATTERN = re.compile(r"^\s+(?:❯\s)?(/[^\r\n]+)$")
INPUT_PROCESSING_DELAY_SECONDS = 0.04
STATE_READ_RETRY_SECONDS = 0.02
STATE_READ_TIMEOUT_SECONDS = 1.0


def find_exception_marker(source_text: str) -> str | None:
    return next((marker for marker in UNEXPECTED_EXCEPTION_MARKERS if marker in source_text), None)


def contains_powershell_stack_trace(source_text: str) -> bool:
    return POWERSHELL_STACK_TRACE_PATTERN.search(source_text) is not None


def find_unexpected_exception(raw_output: str, visible_text: str) -> str | None:
    for source_name, source_text in (("screen", visible_text), ("raw output", raw_output)):
        if not source_text:
            continue
        marker = find_exception_marker(source_text)
        if marker is not None:
            return f"Unexpected PowerShell exception detected in {source_name}: {marker}"
        if contains_powershell_stack_trace(source_text):
            return f"Unexpected PowerShell stack trace detected in {source_name}."
    return None


class GerberTerminalApp:
    def __init__(self, options: LaunchOptions) -> None:
        self._options = options
        self._session: PtySession | None = None
        self._sensitive_value_list: list[str] = []
        self._last_process_status: dict[str, Any] = {
            "isAlive": False,
            "exitStatus": None,
            "signalStatus": None,
        }

    @property
    def sensitive_value_list(self) -> list[str]:
        return list(self._sensitive_value_list)

    @property
    def runtime_paths(self) -> RuntimePaths:
        return self._options.runtime_paths

    def start(
        self,
        *,
        enable_synthetic_plugin: bool = False,
        http_fixture: dict[str, Any] | None = None,
    ) -> None:
        self._reset_process_state()
        http_fixture = self._resolve_http_fixture(http_fixture)
        self._options.runtime_paths.http_fixture_path.write_text(json.dumps(http_fixture, indent=2), encoding="utf-8")
        environment = self._build_environment(
            enable_synthetic_plugin=enable_synthetic_plugin,
        )
        arguments = self._build_harness_arguments(
            enable_synthetic_plugin=enable_synthetic_plugin,
        )

        self._session = PtySession(
            SessionLaunchOptions(
                command="pwsh",
                arguments=arguments,
                environment=environment,
                columns=self._options.columns,
                rows=self._options.rows,
                timeout_seconds=15.0,
            )
        )
        self.wait_for_module_validation()

    def _resolve_http_fixture(self, http_fixture: dict[str, Any] | None) -> dict[str, Any]:
        if http_fixture is not None:
            return http_fixture
        return {
            "defaultResult": {"type": "error", "message": "No terminal HTTP fixture matched this request."},
            "requests": [],
        }

    def _reset_process_state(self) -> None:
        path_list = (
            self.runtime_paths.clipboard_state_path,
            self.runtime_paths.http_state_path,
            self.runtime_paths.module_state_path,
            self.runtime_paths.diagnostic_state_path,
            self.runtime_paths.prompt_trace_path,
        )
        for path in path_list:
            path.unlink(missing_ok=True)

    def _build_environment(
        self,
        *,
        enable_synthetic_plugin: bool,
    ) -> dict[str, str]:
        environment = os.environ.copy()
        environment["GERBER_TERMINAL_RUNTIME_MODULE_PATH"] = environment.get("PSModulePath", "")
        environment["PSModulePath"] = self._build_module_path(
            enable_synthetic_plugin=enable_synthetic_plugin,
        )
        environment["GERBER_PROMPT_TRACE"] = "1"
        return environment

    def _build_module_path(
        self,
        *,
        enable_synthetic_plugin: bool,
    ) -> str:
        module_path_list = [str(self._options.gerber_root / "dist")]
        if enable_synthetic_plugin:
            module_path_list.insert(0, str(self._options.synthetic_plugin_root))
        return os.pathsep.join(module_path_list)

    def _build_harness_arguments(
        self,
        *,
        enable_synthetic_plugin: bool,
    ) -> list[str]:
        harness_path = self._options.gerber_root / "tests/terminal/fixtures/TestHarness.ps1"
        arguments = [
            "-NoLogo",
            "-NoProfile",
            "-File",
            str(harness_path),
            "-GerberRoot",
            str(self._options.gerber_root),
            "-SecretStoreStatePath",
            str(self._options.runtime_paths.credential_state_path),
            "-ClipboardStatePath",
            str(self._options.runtime_paths.clipboard_state_path),
            "-HttpFixturePath",
            str(self._options.runtime_paths.http_fixture_path),
            "-HttpStatePath",
            str(self._options.runtime_paths.http_state_path),
            "-ModuleStatePath",
            str(self._options.runtime_paths.module_state_path),
            "-DiagnosticStatePath",
            str(self._options.runtime_paths.diagnostic_state_path),
            "-PromptTracePath",
            str(self._options.runtime_paths.prompt_trace_path),
        ]
        if enable_synthetic_plugin:
            arguments += ["-FixtureModuleRoot", str(self._options.synthetic_plugin_root)]
        return arguments

    def close(self) -> None:
        if self._session is not None:
            self._last_process_status = self._session.close()
            self._session = None

    def register_sensitive_value(self, value: str) -> None:
        if value and value not in self._sensitive_value_list:
            self._sensitive_value_list.append(value)

    def type(self, value: str) -> ScreenSnapshot:
        return self._send_text(value, sensitive=False)

    def type_secret(self, value: str) -> ScreenSnapshot:
        self.register_sensitive_value(value)
        return self._send_text(value, sensitive=True)

    def _send_text(self, value: str, *, sensitive: bool) -> ScreenSnapshot:
        session = self._require_session()
        session.send_text(value, sensitive=sensitive)
        time.sleep(INPUT_PROCESSING_DELAY_SECONDS)
        return session.wait_for_stable_screen()

    def press(self, key_name: str) -> ScreenSnapshot:
        session = self._require_session()
        session.send_key(key_name)
        time.sleep(INPUT_PROCESSING_DELAY_SECONDS)
        return session.wait_for_stable_screen()

    def press_many(self, key_name: str, count: int) -> ScreenSnapshot:
        snapshot = self.snapshot()
        for _ in range(count):
            snapshot = self.press(key_name)
        return snapshot

    def snapshot(self) -> ScreenSnapshot:
        return self._require_session().snapshot()

    def visible_text(self) -> str:
        return self.snapshot().text

    def wait_for_text(self, text: str, *, timeout_seconds: float = 5.0) -> ScreenSnapshot:
        return self._require_session().wait_for(
            lambda snapshot: text in snapshot.text,
            description=f"text '{text}'",
            timeout_seconds=timeout_seconds,
        )

    def wait_for_prompt(self) -> ScreenSnapshot:
        return self._require_session().wait_for(
            lambda snapshot: any(line.startswith("❯") for line in snapshot.lines),
            description="prompt line",
        )

    def prompt_row(self) -> int:
        snapshot = self.snapshot()
        for index, line in enumerate(snapshot.lines):
            if line.startswith("❯"):
                return index
        raise AssertionError(f"Could not locate a prompt row in the screen:\n{snapshot.text}")

    def prompt_line(self) -> str:
        row_index = self.prompt_row()
        return self.snapshot().lines[row_index]

    def expect_input(self, value: str) -> ScreenSnapshot:
        snapshot = self.snapshot()
        prompt_line = self.prompt_line()
        expected = f"❯ {value}"
        alternate_expected = "❯" if not value else expected
        if not (prompt_line.startswith(expected) or prompt_line == alternate_expected):
            raise AssertionError(f"Expected prompt input '{expected}', but rendered '{prompt_line}'.")
        return snapshot

    def expect_cursor_index(self, index: int) -> ScreenSnapshot:
        snapshot = self.snapshot()
        expected_column = 2 + index
        prompt_row = self.prompt_row()
        if snapshot.cursor_row != prompt_row or snapshot.cursor_column != expected_column:
            raise AssertionError(
                f"Expected cursor at row {prompt_row}, column {expected_column}, "
                f"but was at row {snapshot.cursor_row}, column {snapshot.cursor_column}."
            )
        return snapshot

    def expect_selected_suggestion(self, display_text: str) -> ScreenSnapshot:
        snapshot = self.snapshot()
        needle = f"  ❯ {display_text}"
        if needle not in snapshot.lines:
            raise AssertionError(f"Expected selected suggestion '{needle}' in screen:\n{snapshot.text}")
        return snapshot

    def expect_selected_suggestion_highlighted(self, display_text: str) -> ScreenSnapshot:
        snapshot = self.expect_selected_suggestion(display_text)
        row_index = self._find_line_index(snapshot, f"  ❯ {display_text}")
        if row_index >= len(snapshot.line_has_highlight) or not snapshot.line_has_highlight[row_index]:
            raise AssertionError(
                f"Expected selected suggestion '  ❯ {display_text}' to keep its highlight, "
                f"but the terminal row had no highlight state.\n{snapshot.text}"
            )
        return snapshot

    def expect_suggestion(self, display_text: str) -> ScreenSnapshot:
        snapshot = self.snapshot()
        if not any(display_text in line for line in snapshot.lines):
            raise AssertionError(f"Expected suggestion '{display_text}' in screen:\n{snapshot.text}")
        return snapshot

    def suggestion_list(self) -> list[str]:
        suggestion_list: list[str] = []
        for line in self.snapshot().lines:
            match = SUGGESTION_PATTERN.match(line)
            if match is not None:
                suggestion_list.append(match.group(1))
        return suggestion_list

    def preview_text(self) -> str:
        for line in self.snapshot().lines:
            if "Preview:" in line:
                return line.split("Preview:", maxsplit=1)[1].strip()
        raise AssertionError(f"Expected a preview line in the screen:\n{self.snapshot().text}")

    def expect_suggestion_order(self, expected_suggestion_list: list[str]) -> ScreenSnapshot:
        snapshot = self.snapshot()
        actual_suggestion_list = self.suggestion_list()
        if actual_suggestion_list != expected_suggestion_list:
            raise AssertionError(
                "Expected suggestions in order "
                f"{expected_suggestion_list}, but rendered {actual_suggestion_list}.\n{snapshot.text}"
            )
        return snapshot

    def expect_preview(self, preview_text: str) -> ScreenSnapshot:
        snapshot = self.snapshot()
        needle = f"Preview: {preview_text}"
        if not any(needle in line for line in snapshot.lines):
            raise AssertionError(f"Expected preview '{needle}' in screen:\n{snapshot.text}")
        return snapshot

    def expect_text_absent(self, text: str) -> ScreenSnapshot:
        snapshot = self.snapshot()
        if text in snapshot.text:
            raise AssertionError(f"Did not expect text '{text}' in screen:\n{snapshot.text}")
        return snapshot

    def wait_for_exit(self) -> None:
        self._require_session().wait_for_exit()

    def raw_output(self) -> str:
        return self._require_session().raw_output

    def prompt_trace_text(self) -> str:
        if not self.runtime_paths.prompt_trace_path.exists():
            return ""
        return self.runtime_paths.prompt_trace_path.read_text(encoding="utf-8")

    def http_state(self) -> dict[str, Any]:
        return self._read_json_state(self.runtime_paths.http_state_path, {"requests": []})

    def credential_state(self) -> dict[str, Any]:
        return self._read_json_state(
            self.runtime_paths.credential_state_path,
            {"credentials": {}, "operations": []},
        )

    def clipboard_state(self) -> dict[str, Any]:
        return self._read_json_state(self.runtime_paths.clipboard_state_path, {"values": []})

    def command_inventory(self) -> list[dict[str, Any]]:
        inventory_path = self.runtime_paths.run_root / "command-inventory.json"
        return json.loads(inventory_path.read_text(encoding="utf-8-sig"))

    def module_state(self) -> dict[str, Any]:
        return self._read_json_state(
            self.runtime_paths.module_state_path,
            {"validationStatus": "missing", "modules": {}},
        )

    def harness_diagnostic_state(self) -> dict[str, Any]:
        return self._read_json_state(self.runtime_paths.diagnostic_state_path, {"events": []})

    def input_event_list(self) -> list[Any]:
        return self._require_session().input_event_list

    def session_diagnostic_event_list(self) -> list[dict[str, Any]]:
        return self._require_session().diagnostic_event_list

    def process_status(self) -> dict[str, Any]:
        if self._session is not None:
            return self._require_session().process_status()
        return dict(self._last_process_status)

    def timeout_details(self) -> dict[str, Any] | None:
        if self._session is None:
            return None
        return self._require_session().last_timeout_details

    def wait_for_module_validation(self, *, timeout_seconds: float = 5.0) -> dict[str, Any]:
        deadline = time.monotonic() + timeout_seconds
        while time.monotonic() < deadline:
            module_state = self.module_state()
            validation_status = module_state.get("validationStatus")
            if validation_status == "passed":
                return module_state
            if validation_status == "failed":
                failure_message = module_state.get("failureMessage", "Terminal module validation failed.")
                raise AssertionError(failure_message)
            time.sleep(0.05)
        raise AssertionError("Timed out while waiting for terminal module validation to complete.")

    def assert_no_unexpected_exception(self) -> None:
        failure_message = find_unexpected_exception(self.raw_output(), self.visible_text())
        if failure_message is not None:
            raise AssertionError(failure_message)

    def _require_session(self) -> PtySession:
        if self._session is None:
            raise RuntimeError("The terminal session has not been started yet.")
        return self._session

    @staticmethod
    def _find_line_index(snapshot: ScreenSnapshot, line_text: str) -> int:
        for index, line in enumerate(snapshot.lines):
            if line == line_text:
                return index

        raise AssertionError(f"Expected line '{line_text}' in screen:\n{snapshot.text}")

    def _read_json_state(self, path: Path, default_value: dict[str, Any]) -> dict[str, Any]:
        deadline = time.monotonic() + STATE_READ_TIMEOUT_SECONDS
        while time.monotonic() < deadline:
            if not path.exists():
                return default_value
            try:
                return json.loads(path.read_text(encoding="utf-8-sig"))
            except json.JSONDecodeError:
                time.sleep(STATE_READ_RETRY_SECONDS)
        return json.loads(path.read_text(encoding="utf-8-sig"))


class ScenarioContext:
    def __init__(self, app: GerberTerminalApp, *, artifact_description: str) -> None:
        self.app = app
        self.artifact_description = artifact_description

    def close(self) -> None:
        self.app.close()
