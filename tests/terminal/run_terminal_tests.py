from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import datetime, UTC
import json
import os
from pathlib import Path
import shlex
import signal
import sys
import time
import traceback
from uuid import uuid4

from framework.artifacts import (
    FailureArtifacts,
    create_runtime_paths,
    remove_runtime_artifacts,
    write_failure_artifacts,
)
from framework.coverage import (
    build_coverage_report,
    export_command_inventory,
    load_exclusion_list,
    write_coverage_report,
)
from framework.gerber_app import GerberTerminalApp, LaunchOptions, ScenarioContext
from framework.scenario_registry import SCENARIO_REGISTRY
import scenarios  # noqa: F401


@dataclass
class ScenarioResult:
    id: str
    title: str
    status: str
    categories: tuple[str, ...]
    duration_seconds: float
    failure: str | None = None


@dataclass(frozen=True)
class RunnerContext:
    args: argparse.Namespace
    gerber_root: Path
    artifact_root: Path
    run_root: Path
    failure_root: Path


@dataclass(frozen=True)
class FailureCapture:
    snapshot: object
    module_state: dict
    harness_diagnostics: dict
    raw_output: str
    input_event_list: list
    session_diagnostic_event_list: list[dict]
    timeout_details: dict | None
    prompt_trace_text: str
    sensitive_value_list: list[str]
    process_status: dict
    python_traceback_text: str


@dataclass(frozen=True)
class CoverageReports:
    core: dict
    plugin_contract: dict


class SuiteTimeoutError(TimeoutError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Gerber PTY terminal regression scenarios.")
    parser.add_argument("--gerber-root", required=True)
    parser.add_argument("--artifact-root", required=True)
    parser.add_argument("--scenario-id")
    parser.add_argument("--category")
    parser.add_argument("--suite-timeout-seconds", type=float, default=900.0)
    parser.add_argument("--keep-success-artifacts", action="store_true")
    parser.add_argument("--list", action="store_true")
    return parser.parse_args()


def select_scenarios(args: argparse.Namespace) -> list:
    scenario_list = sorted(SCENARIO_REGISTRY, key=lambda item: item.id)
    if args.scenario_id:
        scenario_list = [item for item in scenario_list if item.id == args.scenario_id]
    if args.category:
        scenario_list = [item for item in scenario_list if args.category in item.categories]
    if not scenario_list:
        raise SystemExit("No matching terminal scenarios were found.")
    return scenario_list


def list_scenarios(scenario_list: list) -> int:
    for scenario_definition in scenario_list:
        print(f"{scenario_definition.id}: {scenario_definition.title}")
    return 0


def sanitize_run_component(value: str | None) -> str:
    if not value:
        return "all"
    return "".join(character if character.isalnum() else "-" for character in value).strip("-") or "all"


def prepare_run_root(artifact_root: Path, args: argparse.Namespace) -> tuple[Path, Path]:
    run_id = (
        datetime.now(UTC).strftime("%Y%m%dT%H%M%S.%fZ")
        + f"-pid{os.getpid()}-{sanitize_run_component(args.category or args.scenario_id)}-{uuid4().hex[:8]}"
    )
    run_root = artifact_root / "runs" / run_id
    failure_root = run_root / "failures"
    failure_root.mkdir(parents=True, exist_ok=True)
    return run_root, failure_root


def create_app(gerber_root: Path, run_root: Path, scenario_definition) -> GerberTerminalApp:
    runtime_paths = create_runtime_paths(run_root, scenario_definition.id)
    columns, rows = scenario_definition.viewport
    return GerberTerminalApp(
        LaunchOptions(
            gerber_root=gerber_root,
            synthetic_plugin_root=gerber_root / "tests/terminal/fixtures/modules",
            runtime_paths=runtime_paths,
            columns=columns,
            rows=rows,
        )
    )


def create_pass_result(scenario_definition, duration_seconds: float) -> ScenarioResult:
    return ScenarioResult(
        id=scenario_definition.id,
        title=scenario_definition.title,
        status="passed",
        categories=scenario_definition.categories,
        duration_seconds=duration_seconds,
    )


def create_failure_result(scenario_definition, failure_message: str, duration_seconds: float) -> ScenarioResult:
    return ScenarioResult(
        id=scenario_definition.id,
        title=scenario_definition.title,
        status="failed",
        categories=scenario_definition.categories,
        duration_seconds=duration_seconds,
        failure=failure_message,
    )


def build_reproduction_command(runner_context: RunnerContext, scenario_definition) -> str:
    command_part_list = [
        "pwsh",
        "-NoLogo",
        "-NoProfile",
        "-File",
        str(runner_context.gerber_root / "scripts/build/Invoke-TerminalRegressionCI.ps1"),
        "-ScenarioId",
        scenario_definition.id,
        "-KeepSuccessArtifacts",
    ]
    return " ".join(shlex.quote(item) for item in command_part_list)


def get_powershell_stack_trace(module_state: dict, raw_output: str, prompt_trace_text: str) -> str:
    if module_state.get("failureStackTrace"):
        return str(module_state["failureStackTrace"])
    for line in reversed(prompt_trace_text.splitlines()):
        try:
            trace_event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if trace_event.get("Event") != "menu-loop-exception":
            continue
        trace_data = trace_event.get("Data", {})
        stack_trace = str(trace_data.get("ScriptStackTrace", ""))
        position_message = str(trace_data.get("PositionMessage", ""))
        if stack_trace or position_message:
            return "\n".join(item for item in (stack_trace, position_message) if item)
    return raw_output


def capture_failure(app: GerberTerminalApp) -> FailureCapture:
    snapshot = app.snapshot()
    module_state = app.module_state()
    harness_diagnostics = app.harness_diagnostic_state()
    raw_output = app.raw_output()
    input_event_list = app.input_event_list()
    session_diagnostic_event_list = app.session_diagnostic_event_list()
    timeout_details = app.timeout_details()
    prompt_trace_text = app.prompt_trace_text()
    sensitive_value_list = app.sensitive_value_list
    app.close()
    return FailureCapture(
        snapshot=snapshot,
        module_state=module_state,
        harness_diagnostics=harness_diagnostics,
        raw_output=raw_output,
        input_event_list=input_event_list,
        session_diagnostic_event_list=session_diagnostic_event_list,
        timeout_details=timeout_details,
        prompt_trace_text=prompt_trace_text,
        sensitive_value_list=sensitive_value_list,
        process_status=app.process_status(),
        python_traceback_text=traceback.format_exc(),
    )


def record_failure_artifacts(runner_context: RunnerContext, scenario_definition, failure_capture: FailureCapture, exc: Exception) -> str:
    failure_message = "".join(traceback.format_exception_only(type(exc), exc)).strip()
    write_failure_artifacts(
        paths=create_runtime_paths(runner_context.run_root, scenario_definition.id),
        artifacts=FailureArtifacts(
            scenario_id=scenario_definition.id,
            scenario_title=scenario_definition.title,
            expected=f"Scenario '{scenario_definition.id}' ({scenario_definition.title}) should complete without assertion failures or unexpected PowerShell exceptions.",
            actual=failure_message,
            screen=failure_capture.snapshot,
            raw_output=failure_capture.raw_output,
            input_event_list=failure_capture.input_event_list,
            prompt_trace_text=failure_capture.prompt_trace_text,
            sensitive_value_list=failure_capture.sensitive_value_list,
            failure_message=failure_message,
            python_traceback_text=failure_capture.python_traceback_text,
            powershell_stack_trace_text=get_powershell_stack_trace(
                failure_capture.module_state,
                failure_capture.raw_output,
                failure_capture.prompt_trace_text,
            ),
            reproduction_command=build_reproduction_command(runner_context, scenario_definition),
            module_state=failure_capture.module_state,
            harness_diagnostic_event_list=list(failure_capture.harness_diagnostics.get("events", [])),
            session_diagnostic_event_list=failure_capture.session_diagnostic_event_list,
            process_status=failure_capture.process_status,
            timeout_details=failure_capture.timeout_details,
        ),
    )
    return failure_message


def run_scenario(runner_context: RunnerContext, scenario_definition) -> ScenarioResult:
    start_time = time.monotonic()
    app = create_app(runner_context.gerber_root, runner_context.run_root, scenario_definition)
    scenario_context = ScenarioContext(app, artifact_description=scenario_definition.title)
    try:
        scenario_definition.run(scenario_context)
        app.assert_no_unexpected_exception()
        if not runner_context.args.keep_success_artifacts:
            remove_runtime_artifacts(app.runtime_paths)
        return create_pass_result(scenario_definition, time.monotonic() - start_time)
    except Exception as exc:  # noqa: BLE001
        failure_capture = capture_failure(app)
        failure_message = record_failure_artifacts(
            runner_context,
            scenario_definition,
            failure_capture,
            exc,
        )
        return create_failure_result(scenario_definition, failure_message, time.monotonic() - start_time)
    finally:
        scenario_context.close()


def write_summary(
    artifact_root: Path,
    result_list: list[ScenarioResult],
    *,
    duration_seconds: float,
    coverage_reports: CoverageReports,
) -> None:
    summary = {
        "runId": artifact_root.name,
        "runRoot": str(artifact_root),
        "scenarioCount": len(result_list),
        "passedCount": len([item for item in result_list if item.status == "passed"]),
        "failedCount": len([item for item in result_list if item.status == "failed"]),
        "durationSeconds": duration_seconds,
        "coverage": {
            "core": summarize_coverage(coverage_reports.core),
            "pluginContract": summarize_coverage(coverage_reports.plugin_contract),
        },
        "results": [asdict(item) for item in result_list],
    }
    artifact_root.mkdir(parents=True, exist_ok=True)
    (artifact_root / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")


def summarize_coverage(coverage_report: dict) -> dict:
    return {
        "commandCount": coverage_report["commandCount"],
        "coveredCommandCount": coverage_report["coveredCommandCount"],
        "excludedCommandCount": coverage_report["excludedCommandCount"],
        "uncoveredCommandCount": coverage_report["uncoveredCommandCount"],
        "issueCount": len(coverage_report["issues"]),
    }


def print_results(result_list: list[ScenarioResult]) -> None:
    for item in result_list:
        prefix = "PASS" if item.status == "passed" else "FAIL"
        print(f"[{prefix}] {item.id} - {item.title}")
        if item.failure:
            print(f"       {item.failure}")


def run_scenario_list(
    runner_context: RunnerContext,
    scenario_list: list,
) -> list[ScenarioResult]:
    deadline = time.monotonic() + runner_context.args.suite_timeout_seconds
    return [
        run_scenario_with_deadline(runner_context, item, deadline)
        for item in scenario_list
    ]


def run_scenario_with_deadline(
    runner_context: RunnerContext,
    scenario_definition,
    deadline: float,
) -> ScenarioResult:
    remaining_seconds = deadline - time.monotonic()
    if remaining_seconds <= 0:
        raise SuiteTimeoutError("The terminal regression suite exceeded its overall timeout.")
    if not hasattr(signal, "SIGALRM"):
        return run_scenario(runner_context, scenario_definition)
    signal.setitimer(signal.ITIMER_REAL, remaining_seconds)
    try:
        return run_scenario(runner_context, scenario_definition)
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)


def handle_suite_timeout(_signal_number, _frame) -> None:
    raise SuiteTimeoutError("The terminal regression suite exceeded its overall timeout.")


def create_runner_context(args) -> RunnerContext:
    gerber_root = Path(args.gerber_root).resolve()
    artifact_root = Path(args.artifact_root).resolve()
    run_root, failure_root = prepare_run_root(artifact_root, args)
    return RunnerContext(
        args=args,
        gerber_root=gerber_root,
        artifact_root=artifact_root,
        run_root=run_root,
        failure_root=failure_root,
    )


def configure_suite_timeout() -> None:
    if hasattr(signal, "SIGALRM"):
        signal.signal(signal.SIGALRM, handle_suite_timeout)


def run_selected_scenarios(args, started_at: float) -> int:
    runner_context = create_runner_context(args)
    configure_suite_timeout()
    core_inventory_path = runner_context.run_root / "command-inventory.json"
    core_inventory = export_command_inventory(
        gerber_root=runner_context.gerber_root,
        output_path=core_inventory_path,
    )
    plugin_registry_inventory_path = runner_context.run_root / "plugin-registry-inventory.json"
    plugin_registry_inventory = export_command_inventory(
        gerber_root=runner_context.gerber_root,
        fixture_module_root=runner_context.gerber_root / "tests/terminal/fixtures/modules",
        output_path=plugin_registry_inventory_path,
    )
    plugin_inventory = select_plugin_contract_inventory(plugin_registry_inventory)
    plugin_inventory_path = runner_context.run_root / "plugin-command-inventory.json"
    plugin_inventory_path.write_text(json.dumps(plugin_inventory, indent=2), encoding="utf-8")
    scenario_list = select_scenarios(args)
    result_list = run_scenario_list(runner_context, scenario_list)
    core_scenario_list = [item for item in SCENARIO_REGISTRY if "core" in item.categories]
    plugin_scenario_list = [item for item in SCENARIO_REGISTRY if "plugin" in item.categories]
    core_coverage_report = build_coverage_report(
        inventory=core_inventory,
        scenario_list=core_scenario_list,
        result_list=result_list,
        exclusion_list=load_exclusion_list(
            runner_context.gerber_root / "tests/terminal/coverage-exclusions.json"
        ),
    )
    plugin_coverage_report = build_coverage_report(
        inventory=plugin_inventory,
        scenario_list=plugin_scenario_list,
        result_list=result_list,
        exclusion_list=load_exclusion_list(
            runner_context.gerber_root / "tests/terminal/plugin-coverage-exclusions.json"
        ),
    )
    coverage_reports = CoverageReports(
        core=core_coverage_report,
        plugin_contract=plugin_coverage_report,
    )
    write_run_reports(
        runner_context,
        result_list,
        coverage_reports,
        started_at,
    )
    print_results(result_list)
    return evaluate_run(args, result_list, coverage_reports)

def select_plugin_contract_inventory(inventory: list[dict]) -> list[dict]:
    return [
        item for item in inventory
        if item["ownerType"] == "Plugin" or item.get("conditionalContainer", False)
    ]


def write_run_reports(
    runner_context: RunnerContext,
    result_list: list[ScenarioResult],
    coverage_reports: CoverageReports,
    started_at: float,
) -> None:
    write_coverage_report(runner_context.run_root, coverage_reports.core)
    write_coverage_report(
        runner_context.run_root,
        coverage_reports.plugin_contract,
        report_name="plugin-command-coverage",
    )
    write_summary(
        runner_context.run_root,
        result_list,
        duration_seconds=time.monotonic() - started_at,
        coverage_reports=coverage_reports,
    )
    latest_summary = runner_context.run_root / "summary.json"
    (runner_context.artifact_root / "latest-summary.json").write_text(
        latest_summary.read_text(encoding="utf-8"),
        encoding="utf-8",
    )


def evaluate_run(
    args,
    result_list: list[ScenarioResult],
    coverage_reports: CoverageReports,
) -> int:
    enforce_coverage = args.scenario_id is None and args.category is None
    coverage_report_map = {
        "core-command-coverage": coverage_reports.core,
        "plugin-contract-coverage": coverage_reports.plugin_contract,
    }
    if enforce_coverage:
        print_coverage_issues(coverage_report_map)
    overall_success = all(item.status == "passed" for item in result_list)
    if enforce_coverage:
        overall_success = overall_success and all(
            not report["issues"] for report in coverage_report_map.values()
        )
    return 0 if overall_success else 1


def print_coverage_issues(coverage_report_map: dict[str, dict]) -> None:
    for report_name, coverage_report in coverage_report_map.items():
        if not coverage_report["issues"]:
            continue
        print(f"[FAIL] {report_name} - {len(coverage_report['issues'])} issue(s)")
        for issue in coverage_report["issues"]:
            print(f"       {issue['command']} [{issue['category']}]: {issue['detail']}")


def main() -> int:
    started_at = time.monotonic()
    args = parse_args()
    scenario_list = sorted(SCENARIO_REGISTRY, key=lambda item: item.id)
    if args.list:
        return list_scenarios(scenario_list)
    return run_selected_scenarios(args, started_at)


if __name__ == "__main__":
    sys.exit(main())
