from __future__ import annotations

import json

from framework.scenario_registry import ScenarioMetadata, scenario
from .plugins import approve_synthetic_plugin


PRODUCT_ROOTS = ("/branch", "/list", "/pipelines", "/repository")


def _expect_root_inventory(context, repository_available: bool) -> None:
    context.app.type("/")
    expected = ["/exit", "/help", "/plugins", "/update", "/secrets", "/tools"]
    if repository_available:
        expected.insert(4, "/repository")
    context.app.expect_suggestion_order(expected)
    for root in PRODUCT_ROOTS:
        if root != "/repository" or not repository_available:
            context.app.expect_text_absent(root)
    context.app.press("ESCAPE")
    context.app.expect_input("")


def _change_fixture_activation(context, action: str, message: str) -> None:
    context.app.type(f"/plugins {action}")
    context.app.press("ENTER")
    context.app.wait_for_text("Select plugin")
    context.app.press("ENTER")
    context.app.wait_for_text(message)
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("/")
    context.app.press("ESCAPE")
    context.app.expect_input("")


def _open_repository_and_escape(context) -> None:
    context.app.type("/repository fixture-status")
    context.app.press("ENTER")
    context.app.wait_for_text("Synthetic plugin command executed.")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.expect_input("/repository ")
    context.app.expect_suggestion("/repository fixture-status")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("/")
    context.app.press("ESCAPE")
    context.app.expect_input("")


def _assert_lifecycle_trace(context) -> None:
    records = [json.loads(line) for line in context.app.prompt_trace_text().splitlines() if line.strip()]
    markers = [
        ("prompt-submit", "/repository fixture-status"),
        ("prompt-escape", "/repository "),
        ("prompt-submit", "/repository explode"),
        ("menu-loop-exception-path", "recoverable-error"),
        ("prompt-submit", "/plugins disable"),
        ("prompt-submit", "/plugins enable"),
        ("prompt-submit", "/repository fixture-status"),
        ("prompt-escape", "/repository "),
    ]
    cursor = 0
    for event, value in markers:
        matches = [
            index for index, record in enumerate(records[cursor:], start=cursor)
            if record["Event"] == event
            and value in (record["Data"].get("Buffer"), record["Data"].get("Path"))
        ]
        assert matches, (event, value, records[cursor:])
        cursor = matches[0] + 1


@scenario(
    "active-core-empty-containers",
    title="Uncontributed product containers are absent from discovery, help and dispatch",
    categories=("core", "regression", "containers"),
    metadata=ScenarioMetadata(
        commands=("help",),
        workflows=("registry:empty-containers", "command:help"),
        coverage=("discovery", "dispatch", "workflow", "rendering"),
    ),
)
def active_core_empty_containers(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    _expect_root_inventory(context, False)
    context.app.type("/help")
    context.app.press("ENTER")
    context.app.wait_for_text("/help")
    for root in PRODUCT_ROOTS:
        context.app.expect_text_absent(root)
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.type("/repository")
    context.app.press("ENTER")
    context.app.wait_for_text("Unknown command '/repository'")
    context.app.press("ENTER")
    context.app.wait_for_prompt()


@scenario(
    "active-plugin-container-lifecycle",
    title="Actual plugin activation prunes/restores shared containers with Escape and failure recovery",
    categories=("core", "plugin", "regression", "containers"),
    metadata=ScenarioMetadata(
        commands=("repository", "repository fixture-status", "repository explode", "plugins enable", "plugins disable"),
        workflows=("registry:conditional-containers", "command:repository", "command:repository fixture-status", "command:repository explode",
                   "command:plugins enable", "command:plugins disable"),
        coverage=("discovery", "dispatch", "workflow", "navigation", "rendering", "error-recovery"),
    ),
)
def active_plugin_container_lifecycle(context) -> None:
    context.app.start(enable_synthetic_plugin=True)
    approve_synthetic_plugin(context)
    _expect_root_inventory(context, True)
    _open_repository_and_escape(context)
    context.app.type("/repository explode")
    context.app.press("ENTER")
    context.app.wait_for_text("Synthetic plugin failure.")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    _change_fixture_activation(context, "disable", "Disabled plugin")
    _expect_root_inventory(context, False)
    _change_fixture_activation(context, "enable", "Enabled and approved plugin")
    _expect_root_inventory(context, True)
    _open_repository_and_escape(context)
    _assert_lifecycle_trace(context)
