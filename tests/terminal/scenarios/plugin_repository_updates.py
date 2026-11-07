from __future__ import annotations

from framework.scenario_registry import ScenarioMetadata, scenario

from .updates import (
    _assert_batch_overview_table,
    _open_batch_selection,
    _open_unavailable_batch_overview,
    _seed_batch_update,
    _update_state,
)


PLUGIN_REPOSITORY_NAME = "ExampleFeed"
PLUGIN_REPOSITORY_URI = "https://packages.example.org/feed"
PLUGIN_REPOSITORY_PLACEHOLDER = "REPLACE_WITH_REPOSITORY_URI"


def _seed_named_plugin_update(context, uri: str) -> None:
    _seed_batch_update(context, disposition="UpToDate", startupStatus="Unavailable")
    modules = context.app.runtime_paths.scenario_root / "module-data" / "powershell" / "Modules"
    for index in range(1, 4):
        name = f"Gerber.Batch{index}"
        manifest = modules / name / "1.0.0" / f"{name}.psd1"
        declaration = f"Repository = @{{ Name = '{PLUGIN_REPOSITORY_NAME}'; Uri = '{uri}' }}"
        text = manifest.read_text(encoding="utf-8")
        manifest.write_text(text.replace("Plugin = $true", f"Plugin = $true; {declaration}"), encoding="utf-8")


@scenario(
    "plugin-update-named-repository",
    title="Plugin update overview shows repository names while PMU receives canonical URIs",
    categories=("core", "plugins", "updates", "batch-updates", "navigation"),
    metadata=ScenarioMetadata(
        commands=("update list",), workflows=("command:update list",),
        coverage=("dispatch", "workflow", "rendering", "navigation"),
    ),
)
def plugin_update_named_repository(context) -> None:
    _seed_named_plugin_update(context, PLUGIN_REPOSITORY_URI)
    _open_batch_selection(context)
    context.app.wait_for_text(PLUGIN_REPOSITORY_NAME)
    context.app.expect_text_absent(PLUGIN_REPOSITORY_URI)
    state = _update_state(context)
    assert state["pluginRepositoryUris"] == [PLUGIN_REPOSITORY_URI] * 3, state
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    assert _update_state(context)["installCount"] == 0


@scenario(
    "plugin-update-named-unavailable-repository",
    title="Unavailable named plugin repositories never fall back to Gallery",
    categories=("core", "plugins", "updates", "batch-updates", "recovery", "navigation"),
    metadata=ScenarioMetadata(
        commands=("update list",), workflows=("command:update list",),
        coverage=("workflow", "rendering", "error-recovery", "navigation"),
    ),
)
def plugin_update_named_unavailable_repository(context) -> None:
    _seed_named_plugin_update(context, PLUGIN_REPOSITORY_PLACEHOLDER)
    _open_unavailable_batch_overview(context)
    _assert_batch_overview_table(context)
    context.app.wait_for_text(PLUGIN_REPOSITORY_NAME)
    context.app.wait_for_text("Unavailable")
    context.app.expect_text_absent("Select updates")
    state = _update_state(context)
    assert state.get("pluginRepositoryUris", []) == [], state
    assert state["installCount"] == 0
    context.app.press("ENTER")
    context.app.wait_for_prompt()
