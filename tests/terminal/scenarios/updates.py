from __future__ import annotations

import json
import re
from dataclasses import replace

from framework.scenario_registry import ScenarioMetadata, scenario


def _write_batch_plugin(root, name: str, guid: str) -> None:
    directory = root / name / "1.0.0"
    directory.mkdir(parents=True)
    (directory / f"{name}.psm1").write_text(
        "function Get-GerberPlugin {\n"
        "    param($Gerber)\n"
        "    [pscustomobject]@{\n"
        "        Commands = @()\n"
        "    }\n"
        "}\n",
        encoding="utf-8",
    )
    _write_batch_plugin_manifest(directory, name, guid)


def _write_batch_plugin_manifest(directory, name: str, guid: str) -> None:
    (directory / f"{name}.psd1").write_text(
        "@{\n"
        f"    RootModule = '{name}.psm1'; ModuleVersion = '1.0.0'; GUID = '{guid}'\n"
        "    FunctionsToExport = @('Get-GerberPlugin')\n"
        "    PrivateData = @{\n"
        "        Gerber = @{\n"
        "            Plugin = $true; ApiVersion = '1'; MinimumGerberVersion = '0.1.0-preview'\n"
        "        }\n"
        "    }\n"
        "}\n",
        encoding="utf-8",
    )


def _seed_batch_update(context, **options) -> None:
    original = context.app._options
    root = original.runtime_paths.scenario_root
    data_root = root / "module-data"
    _seed_update(context, moduleDataRoot=str(data_root), **options)
    modules = data_root / "powershell" / "Modules"
    modules.mkdir(parents=True)
    (modules / "Gerber.TerminalFixture").symlink_to(original.synthetic_plugin_root / "Gerber.TerminalFixture", target_is_directory=True)
    plugins = _batch_plugin_identities()
    for name, guid in plugins.items():
        _write_batch_plugin(modules, name, guid)
    _seed_batch_associations(root, plugins)
    context.app._options = replace(original, synthetic_plugin_root=modules)


def _batch_plugin_identities() -> dict[str, str]:
    return {
        f"Gerber.Batch{index}": f"01b01b01-0000-0000-0000-00000000000{index}"
        for index in range(1, 4)
    }


def _seed_batch_associations(root, plugins: dict) -> None:
    config = {
        "schemaVersion": 1,
        "plugins": {
            "approved": list(plugins.values()),
            "declined": ["7dd21b37-e080-4240-b05f-ec727389035e"],
            "associated": _batch_plugin_associations(plugins),
        },
    }
    (root / "GerberCore.json").write_text(json.dumps(config), encoding="utf-8")


def _batch_plugin_associations(plugins: dict) -> dict:
    return {
        guid: {
            "name": name,
            "version": "1.0.0",
            "enabled": True,
        }
        for name, guid in plugins.items()
    }


def _open_batch_selection(context) -> None:
    context.app.start(enable_synthetic_plugin=True)
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Select updates")
    context.app.wait_for_text("Gerber.Batch1: 1.0.0 -> 2.0.0")
    context.app.wait_for_text("Gerber.Batch3: 1.0.0 -> 2.0.0")
    _assert_batch_overview_table(context)


def _assert_batch_overview_table(context) -> None:
    text = context.app.visible_text()
    headers = re.findall(r"(?m)^[^\S\n]*Component\s+Name\s+Installed\s+Available\s+Repository\s+Status\s*$", text)
    core_rows = re.findall(r"(?m)^[^\S\n]*Core\s+Gerber\s+.+$", text)
    plugin_rows = re.findall(r"(?m)^[^\S\n]*Plugin\s+Gerber\.Batch[123]\s+.+$", text)
    assert len(headers) == len(core_rows) == 1, text
    assert len(plugin_rows) == 3, text
    for row in plugin_rows:
        assert row.index("Gerber.Batch") == core_rows[0].index("Gerber"), text
        assert row[headers[0].index("Installed"):].startswith("1.0.0"), text
    assert "Check the declared plugin repository" not in text, text
    assert re.search(r"\n[^\S\n]*\n[^\S\n]*Channel:", text), text


def _seed_unavailable_batch_update(context) -> None:
    _seed_batch_update(context, disposition="UpToDate", startupStatus="Unavailable", installedVersion="0.1.0", targetVersion="0.1.0")
    modules = context.app.runtime_paths.scenario_root / "module-data" / "powershell" / "Modules"
    for name in _batch_plugin_identities():
        manifest = modules / name / "1.0.0" / f"{name}.psd1"
        text = manifest.read_text(encoding="utf-8")
        manifest.write_text(text.replace("Plugin = $true", "Plugin = $true; RepositoryUri = 'invalid'"), encoding="utf-8")


def _open_unavailable_batch_overview(context) -> None:
    context.app.start(enable_synthetic_plugin=True)
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Press Enter to continue")


def _assert_unavailable_batch_overview(context) -> None:
    _assert_batch_overview_table(context)
    context.app.wait_for_text("Unavailable")
    context.app.expect_text_absent("Update selection cancelled")
    context.app.expect_text_absent("Select updates")
    assert _update_state(context)["installCount"] == 0
    events = [json.loads(line)["Event"] for line in context.app.prompt_trace_text().splitlines()]
    assert "update-discovery" in events and "checkbox-open" not in events, events
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.expect_input("/update ")


@scenario(
    "update-batch-unavailable-overview",
    title="Up-to-date Core and unavailable plugins retain aligned rows without a false cancellation",
    categories=("core", "updates", "batch-updates"),
    metadata=ScenarioMetadata(commands=("update list",), workflows=("command:update list",), coverage=("workflow", "rendering", "error-recovery", "navigation")),
)
def update_batch_unavailable_overview(context) -> None:
    _seed_unavailable_batch_update(context)
    _open_unavailable_batch_overview(context)
    _assert_unavailable_batch_overview(context)


def _select_batch_plugins(context, *, include_core: bool = False) -> None:
    if include_core:
        context.app.press("SPACE")
    for _ in range(3):
        context.app.press("DOWN")
        context.app.press("SPACE")
    context.app.press("ENTER")


def _accept_batch(context) -> None:
    context.app.wait_for_text("Install selected updates?")
    context.app.press("DOWN")
    context.app.press("ENTER")


def _assert_batch_plan_identity(context, expected: list[str]) -> None:
    state = _update_state(context)
    assert state["installOrder"] == expected, state
    assert state["planIdentityVerified"] is True, state
    assert state["pluginRepositoryUris"] == ["https://www.powershellgallery.com/api/v2"] * 3, state
    assert state["startupDiscoveryCount"] == 1, state
    assert state["startupPluginDiscoveryCount"] == 0, state


def _seed_batch_core_requirement(context, minimum: str, **options) -> None:
    _seed_batch_update(context, pluginMinimumCore={
        "Gerber.Batch1": minimum,
    }, **options)


def _assert_batch_core_confirmation(context) -> None:
    context.app.wait_for_text("automatically added this required Core")
    context.app.wait_for_text("Scope: CurrentUser")
    context.app.wait_for_text("https://www.powershellgallery.com/api/v2")


def _assert_batch_blocked_plugin_continuation(context, expected: list[str]) -> None:
    context.app.wait_for_text("Gerber.Batch1: Blocked")
    context.app.wait_for_text("Gerber.Batch3: Installed")
    _assert_batch_plan_identity(context, expected)


def _assert_batch_default_cancel(context) -> None:
    context.app.wait_for_text("Install selected updates?")
    context.app.press("ENTER")
    context.app.wait_for_text("Nothing was installed")
    assert _update_state(context)["installCount"] == 0


def _assert_batch_selection_escape(context) -> None:
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Select updates")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    assert _update_state(context)["installCount"] == 0


def _assert_batch_plugin_failure_results(context) -> None:
    context.app.wait_for_text("Gerber.Batch1: Installed")
    context.app.wait_for_text("Gerber.Batch2: Failed")
    context.app.wait_for_text("Gerber.Batch3: Installed")
    _assert_batch_plan_identity(context, ["Gerber.Batch1", "Gerber.Batch2", "Gerber.Batch3"])


def _assert_noninteractive_batch_overview(context) -> None:
    state = _update_state(context)
    assert state["installCount"] == 0, state
    for name in ("Gerber.Batch1", "Gerber.Batch2", "Gerber.Batch3"):
        assert name in context.app.raw_output(), name
    events = [json.loads(line)["Event"] for line in context.app.prompt_trace_text().splitlines()]
    assert "update-discovery" in events, events
    assert "checkbox-open" not in events and "update-confirmation" not in events, events


@scenario(
    "update-batch-selection-core-autoaddition",
    title="Plugin multi-selection visibly adds required Core before combined consent",
    categories=("core", "updates", "batch-updates"),
    metadata=ScenarioMetadata(commands=("update list",), workflows=("command:update list",), coverage=("workflow", "rendering")),
)
def update_batch_selection_core_autoaddition(context) -> None:
    _seed_batch_core_requirement(context, "0.2.0")
    _open_batch_selection(context)
    _select_batch_plugins(context)
    _assert_batch_core_confirmation(context)
    _accept_batch(context)
    context.app.wait_for_text("Gerber.Batch3: Installed")
    _assert_batch_plan_identity(context, ["Gerber", "Gerber.Batch1", "Gerber.Batch2", "Gerber.Batch3"])
    _assert_trace_order(context, "checkbox-submit", "update-confirmation", "update-install-complete")


@scenario(
    "update-batch-partial-failure-continuation",
    title="Failed Core blocks its dependent plugin while independent plugins continue",
    categories=("core", "updates", "batch-updates"),
    metadata=ScenarioMetadata(commands=("update list",), workflows=("command:update list",), coverage=("workflow", "error-recovery")),
)
def update_batch_partial_failure_continuation(context) -> None:
    _seed_batch_core_requirement(context, "0.2.0", failModules=["Gerber"])
    _open_batch_selection(context)
    _select_batch_plugins(context)
    _accept_batch(context)
    context.app.wait_for_text("Gerber: Failed")
    _assert_batch_blocked_plugin_continuation(context, ["Gerber", "Gerber.Batch2", "Gerber.Batch3"])
    _assert_trace_order(context, "update-confirmation", "update-install-complete")


@scenario(
    "update-batch-activation-failure-truthful-install",
    title="Fresh-process activation failure does not relabel an installed package",
    categories=("core", "updates", "batch-updates"),
    metadata=ScenarioMetadata(commands=("update list",), workflows=("command:update list",), coverage=("workflow", "error-recovery")),
)
def update_batch_activation_failure_truthful_install(context) -> None:
    _seed_batch_update(context, activationFailures=["Gerber.Batch2"])
    _open_batch_selection(context)
    _select_batch_plugins(context, include_core=True)
    _accept_batch(context)
    context.app.wait_for_text("Gerber.Batch2: Installed")
    context.app.wait_for_text("Activation: Failed")
    context.app.wait_for_text("Gerber.Batch3: Installed")
    _assert_batch_plan_identity(context, ["Gerber", "Gerber.Batch1", "Gerber.Batch2", "Gerber.Batch3"])


@scenario(
    "update-batch-default-cancel-and-escape",
    title="Combined confirmation defaults to Cancel and checkbox Escape returns locally",
    categories=("core", "updates", "batch-updates"),
    metadata=ScenarioMetadata(commands=("update list",), workflows=("command:update list",), coverage=("workflow", "navigation")),
)
def update_batch_default_cancel_and_escape(context) -> None:
    _seed_batch_update(context)
    _open_batch_selection(context)
    _select_batch_plugins(context)
    _assert_batch_default_cancel(context)
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    _assert_batch_selection_escape(context)
    _assert_trace_order(context, "checkbox-submit", "update-confirmation", "checkbox-cancel")


@scenario(
    "update-batch-unsatisfied-core-requirement",
    title="Unsatisfied Core requirement stays visible as Blocked and independent plugins install",
    categories=("core", "updates", "batch-updates"),
    metadata=ScenarioMetadata(commands=("update list",), workflows=("command:update list",), coverage=("workflow", "error-recovery")),
)
def update_batch_unsatisfied_core_requirement(context) -> None:
    _seed_batch_core_requirement(context, "9.0.0")
    _open_batch_selection(context)
    _select_batch_plugins(context)
    context.app.wait_for_text("no permitted Core target")
    context.app.wait_for_text("Blocked")
    _accept_batch(context)
    _assert_batch_blocked_plugin_continuation(context, ["Gerber.Batch2", "Gerber.Batch3"])


@scenario(
    "update-batch-plugin-failure-continuation",
    title="A failed plugin does not prevent later independent installations",
    categories=("core", "updates", "batch-updates"),
    metadata=ScenarioMetadata(commands=("update list",), workflows=("command:update list",), coverage=("workflow", "error-recovery")),
)
def update_batch_plugin_failure_continuation(context) -> None:
    _seed_batch_update(context, failModules=["Gerber.Batch2"])
    _open_batch_selection(context)
    _select_batch_plugins(context)
    _accept_batch(context)
    _assert_batch_plugin_failure_results(context)
    assert "raw-update-token" not in context.app.raw_output()
    _assert_trace_order(context, "update-confirmation", "update-install-complete")


@scenario(
    "update-batch-noninteractive-no-install",
    title="Noninteractive update boundary renders every component without prompts or installation",
    categories=("core", "updates", "batch-updates"),
    metadata=ScenarioMetadata(commands=("update list",), workflows=("command:update list",), coverage=("workflow", "rendering")),
)
def update_batch_noninteractive_no_install(context) -> None:
    _seed_batch_update(context, nonInteractiveUpdates=True)
    context.app.start(enable_synthetic_plugin=True)
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_prompt()
    _assert_noninteractive_batch_overview(context)


@scenario(
    "update-batch-cancellation-stops-future",
    title="User cancellation retains earlier successes and stops later attempts",
    categories=("core", "updates", "batch-updates"),
    metadata=ScenarioMetadata(commands=("update list",), workflows=("command:update list",), coverage=("workflow", "navigation")),
)
def update_batch_cancellation_stops_future(context) -> None:
    _seed_batch_update(context, cancelModules=["Gerber.Batch2"])
    _open_batch_selection(context)
    _select_batch_plugins(context)
    _accept_batch(context)
    context.app.wait_for_text("Gerber.Batch1: Installed")
    context.app.wait_for_text("Gerber.Batch2: Cancelled")
    context.app.wait_for_text("Gerber.Batch3: Cancelled")
    _assert_batch_plan_identity(context, ["Gerber.Batch1", "Gerber.Batch2"])


def _seed_update(context, **options) -> None:
    root = context.app.runtime_paths.scenario_root
    (root / "GerberCore.json").write_text(
        json.dumps({"schemaVersion": 1}),
        encoding="utf-8",
    )
    fixture = {"disposition": "UpdateAvailable", "startupStatus": "Available", **options}
    (root / "update-fixture.json").write_text(json.dumps(fixture), encoding="utf-8")


def _open_update(context) -> None:
    context.app.type("/upd")
    context.app.expect_suggestion("/update")
    context.app.type("ate list")
    context.app.press("ENTER")


def _update_state(context) -> dict:
    path = context.app.runtime_paths.scenario_root / "update-state.json"
    return json.loads(path.read_text(encoding="utf-8"))


def _assert_trace_order(context, *names: str) -> None:
    events = [json.loads(line)["Event"] for line in context.app.prompt_trace_text().splitlines() if line.strip()]
    offset = 0
    for name in names:
        offset = events.index(name, offset) + 1


@scenario(
    "update-accept-and-startup-notification",
    title="Core update acceptance and persistent startup notification",
    categories=("core", "updates", "startup"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
        coverage=("discovery", "dispatch", "workflow", "rendering"),
    ),
)
def update_accept_and_startup_notification(context) -> None:
    _seed_update(context)
    context.app.start()
    context.app.wait_for_text("0.2.0 is available. Run /update")
    context.app.wait_for_prompt()
    assert _update_state(context)["installCount"] == 0
    _open_update(context)
    context.app.wait_for_text("Install Core update?")
    context.app.wait_for_text("PSGallery")
    context.app.expect_text_absent("Unconfigured")
    state = _update_state(context)
    assert state["startupDiscoveryCount"] == 1 and state["repository"] == "PSGallery", state
    context.app.press("DOWN")
    context.app.press("ENTER")
    context.app.wait_for_text("Restart PowerShell")
    context.app.wait_for_text("Continue with current version")
    context.app.wait_for_text("Exit Gerber")
    context.app.wait_for_text("does not restart PowerShell")
    context.app.wait_for_text("Verification: Verified. Recovery: NotRequired.")
    assert _update_state(context)["installCount"] == 1
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.expect_input("/update ")
    context.app.wait_for_text("Restart PowerShell, then run gerber")
    context.app.expect_text_absent("0.2.0 is available")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("")
    context.app.wait_for_text("Restart PowerShell, then run gerber")
    _assert_trace_order(context, "update-discovery", "update-confirmation", "update-install-complete", "numbered-submit", "update-restart-choice", "screen-transition")


def _accept_restart_exit(context, *, install: bool) -> None:
    if install:
        context.app.wait_for_text("Install Core update?")
        context.app.press("DOWN")
        context.app.press("ENTER")
    context.app.wait_for_text("Continue with current version")
    context.app.wait_for_text("Exit Gerber")
    context.app.wait_for_text("does not restart PowerShell")
    context.app.press("DOWN")
    context.app.press("ENTER")
    context.app.wait_for_exit()
    assert _update_state(context)["installCount"] == int(install)
    _assert_trace_order(context, "update-discovery", "numbered-submit", "update-restart-choice")
    assert '"Selection":"exit"' in context.app.prompt_trace_text()
    assert "Restart PowerShell, then run gerber" in context.app.raw_output()


@scenario(
    "update-verified-install-exit",
    title="Verified Core update exits Gerber through the nested menu contract",
    categories=("core", "updates", "navigation"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def update_verified_install_exit(context) -> None:
    _seed_update(context)
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/update")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.expect_input("/update ")
    context.app.press("ENTER")
    _accept_restart_exit(context, install=True)


@scenario(
    "update-restart-required-exit",
    title="Previously installed Core update offers exit without installing again",
    categories=("core", "updates", "navigation"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def update_restart_required_exit(context) -> None:
    _seed_update(context, disposition="AlreadyInstalledRestartRequired", startupStatus="RestartRequired")
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    _accept_restart_exit(context, install=False)
    assert "update-confirmation" not in context.app.prompt_trace_text()


@scenario(
    "update-restart-required-escape",
    title="Escape safely continues the current Core with restart guidance retained",
    categories=("core", "updates", "navigation"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def update_restart_required_escape(context) -> None:
    _seed_update(context, disposition="AlreadyInstalledRestartRequired", startupStatus="RestartRequired")
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Continue with current version")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("/update ")
    context.app.wait_for_text("Restart PowerShell, then run gerber")
    assert _update_state(context)["installCount"] == 0
    _assert_trace_order(context, "update-discovery", "numbered-cancel", "update-restart-choice", "screen-transition")


@scenario(
    "update-default-cancel-and-escape",
    title="Core update safe default and local Escape navigation",
    categories=("core", "updates", "navigation"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def update_default_cancel_and_escape(context) -> None:
    _seed_update(context)
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Install Core update?")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update cancelled")
    context.app.expect_text_absent("Continue with current version")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.expect_input("/update ")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("")
    _open_update(context)
    context.app.wait_for_text("Install Core update?")
    context.app.press("ESCAPE")
    context.app.wait_for_text("Gerber - DevOps Multitool")
    context.app.wait_for_prompt()
    state = _update_state(context)
    assert state["installCount"] == 0 and state["discoveryCount"] == 2, state
    _assert_trace_order(context, "update-discovery", "update-confirmation", "update-discovery")


@scenario(
    "update-discovery-error-recovers",
    title="Offline update discovery recovers without leaking backend errors",
    categories=("core", "updates", "recovery"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
        coverage=("dispatch", "workflow", "error-recovery", "rendering"),
    ),
)
def update_discovery_error_recovers(context) -> None:
    _seed_update(context, failDiscoveryCount=1, startupStatus="Unavailable")
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Update unavailable")
    context.app.expect_text_absent("raw-update-token")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.expect_input("/update ")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("")
    _open_update(context)
    context.app.wait_for_text("Install Core update?")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update cancelled")
    assert _update_state(context)["installCount"] == 0
    _assert_trace_order(context, "update-discovery", "screen-transition", "update-discovery", "update-confirmation")
    assert "raw-update-token" not in context.app.prompt_trace_text()


@scenario(
    "update-install-error-recovers",
    title="Core install failure remains recoverable with truthful rollback guidance",
    categories=("core", "updates", "recovery"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
        coverage=("dispatch", "workflow", "navigation", "error-recovery"),
    ),
)
def update_install_error_recovers(context) -> None:
    _seed_update(context, installError="PMU.RollbackFailed")
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Install Core update?")
    context.app.press("DOWN")
    context.app.press("ENTER")
    context.app.wait_for_text("Installation and rollback failed")
    context.app.wait_for_text("Preserve PMU journals")
    context.app.expect_text_absent("Continue with current version")
    context.app.expect_text_absent("raw-update-token")
    context.app.press("ENTER")
    context.app.wait_for_text("Gerber - DevOps Multitool")
    context.app.wait_for_prompt()
    _assert_trace_order(context, "update-discovery", "update-confirmation", "update-install-complete", "screen-transition")


@scenario(
    "update-missing-provider-metadata-recovers",
    title="Locally copied Core installation receives actionable recovery guidance",
    categories=("core", "updates", "recovery"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
        coverage=("dispatch", "workflow", "navigation", "error-recovery", "rendering"),
    ),
)
def update_missing_provider_metadata_recovers(context) -> None:
    _seed_update(
        context, installError="PMU.UnsupportedInstallation",
        installErrorMessage="The selected installation has no native provider metadata.",
    )
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Install Core update?")
    context.app.press("DOWN")
    context.app.press("ENTER")
    context.app.wait_for_text("no native provider metadata")
    context.app.wait_for_text("locally copied or published")
    context.app.wait_for_text("Press Enter to continue")
    screen = context.app.visible_text().replace("\n", "")
    assert "Reinstall the current Gerber version from PSGallery" in screen, screen
    context.app.expect_text_absent("supported numeric-version module directory")
    context.app.expect_text_absent("raw-update-token")
    context.app.press("ENTER")
    context.app.wait_for_text("Gerber - DevOps Multitool")
    _assert_trace_order(context, "update-discovery", "update-confirmation", "update-install-complete", "screen-transition")


@scenario(
    "update-no-update-overview",
    title="Core equal-version overview preserves PMU availability without an install offer",
    categories=("core", "updates"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
        coverage=("dispatch", "workflow", "rendering"),
    ),
)
def update_no_update_overview(context) -> None:
    _seed_update(
        context, disposition="UpToDate", startupStatus="UpToDate",
        installedVersion="0.1.0", targetVersion="0.1.0",
    )
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("Core is up to date")
    context.app.wait_for_text("Installed")
    context.app.wait_for_text("Available")
    context.app.wait_for_text("PSGallery")
    context.app.wait_for_text("UpToDate")
    row = next(line for line in context.app.visible_text().splitlines() if "PSGallery" in line)
    assert row.split() == ["Core", "Gerber", "0.1.0", "0.1.0", "PSGallery", "UpToDate"], row
    context.app.expect_text_absent("Install Core update?")
    context.app.expect_text_absent("Continue with current version")
    assert _update_state(context)["installCount"] == 0
    _assert_trace_order(context, "update-discovery")
    assert "update-confirmation" not in context.app.prompt_trace_text()


@scenario(
    "update-no-core-config-no-matching-package",
    title="Unconfigured startup regression uses PSGallery without a Core binding",
    categories=("core", "updates", "startup"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
        coverage=("discovery", "dispatch", "workflow", "rendering"),
    ),
)
def update_no_core_config_no_matching_package(context) -> None:
    _seed_update(context, noMatchingPackage=True)
    context.app.start()
    context.app.wait_for_prompt()
    assert _update_state(context)["startupDiscoveryCount"] == 1
    _open_update(context)
    context.app.wait_for_text("No eligible Gerber package")
    context.app.wait_for_text("PSGallery")
    context.app.expect_text_absent("Unconfigured")
    context.app.expect_text_absent("Core is up to date")
    context.app.expect_text_absent("Install Core update?")
    assert _update_state(context)["installCount"] == 0
    _assert_trace_order(context, "update-discovery")


@scenario(
    "update-unsupported-installation",
    title="Unsupported installation gives layout guidance without blaming PSGallery",
    categories=("core", "updates", "recovery"),
    metadata=ScenarioMetadata(
        commands=("update", "update list"), workflows=("command:update", "command:update list"),
        coverage=("dispatch", "workflow", "navigation", "error-recovery", "rendering"),
    ),
)
def update_unsupported_installation(context) -> None:
    _seed_update(context, discoveryError="PMU.UnsupportedInstallation", startupStatus="Unavailable")
    context.app.start()
    context.app.wait_for_prompt()
    _open_update(context)
    context.app.wait_for_text("current installation layout")
    context.app.wait_for_text("supported numeric-version")
    context.app.wait_for_text("restart PowerShell")
    assert "supported numeric-version module directory" in context.app.visible_text().replace("\n", "")
    context.app.expect_text_absent("registration and connection")
    context.app.expect_text_absent("raw-update-token")
    context.app.expect_text_absent("Install Core update?")
    context.app.expect_text_absent("Core is up to date")
    assert _update_state(context)["installCount"] == 0
    _assert_trace_order(context, "update-discovery")
    assert "update-confirmation" not in context.app.prompt_trace_text()
    context.app.press("ENTER")
    context.app.wait_for_prompt()


def _open_policy(context) -> None:
    context.app.type("/update ")
    _choose_policy(context)


def _choose_policy(context) -> None:
    context.app.type("pol")
    context.app.expect_suggestion("/update policy")
    context.app.press("TAB")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update channel (Esc to go back)")


def _continue_to_update_menu(context) -> None:
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.expect_input("/update ")
    context.app.wait_for_text("[list|policy]")
    context.app.expect_selected_suggestion_highlighted("/update list")
    context.app.expect_text_absent("Core update channel (Esc to go back)")


@scenario(
    "update-policy-persistence-and-navigation",
    title="Core channel selection persists, invalidates notification and keeps update safety",
    categories=("core", "updates", "policy"),
    metadata=ScenarioMetadata(
        commands=("update policy", "update", "update list"),
        workflows=("command:update policy", "command:update", "command:update list"),
        coverage=("discovery", "dispatch", "workflow", "navigation", "rendering"),
    ),
)
def update_policy_persistence_and_navigation(context) -> None:
    _seed_update(context)
    context.app.start()
    context.app.wait_for_prompt()
    _open_policy(context)
    context.app.wait_for_text("Current Core update policy: Stable only")
    before = _update_state(context)
    context.app.press("DOWN")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update policy saved: Include prereleases")
    context.app.wait_for_text("Nothing was installed")
    config = context.app.runtime_paths.scenario_root / "GerberCore.json"
    assert json.loads(config.read_text())["coreUpdates"]["channel"] == "IncludePrerelease"
    assert _update_state(context)["discoveryCount"] == before["discoveryCount"]
    _continue_to_update_menu(context)
    _choose_policy(context)
    context.app.wait_for_text("Current Core update policy: Include prereleases")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update policy unchanged: Include prereleases")
    _continue_to_update_menu(context)
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("")
    context.app.expect_text_absent("0.2.0 is available. Run /update")
    _open_policy(context)
    context.app.wait_for_text("Current Core update policy: Include prereleases")
    context.app.press("DOWN")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("/update ")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("")
    assert json.loads(config.read_text())["coreUpdates"]["channel"] == "IncludePrerelease"
    _open_update(context)
    context.app.wait_for_text("Install Core update?")
    context.app.wait_for_text("Channel: Include prereleases")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update cancelled")
    state = _update_state(context)
    assert state["channel"] == "IncludePrerelease" and state["installCount"] == 0, state
    _assert_trace_order(context, "numbered-submit", "update-policy-saved", "screen-transition",
                        "numbered-open", "numbered-submit", "update-policy-saved", "screen-transition",
                        "numbered-open",
                        "numbered-cancel", "update-discovery", "update-confirmation")


@scenario(
    "update-policy-save-error-recovers",
    title="Failed Core channel save preserves configuration and retries from the update menu",
    categories=("core", "updates", "policy", "recovery"),
    metadata=ScenarioMetadata(
        commands=("update policy", "update"), workflows=("command:update policy", "command:update"),
        coverage=("dispatch", "workflow", "navigation", "rendering", "error-recovery"),
    ),
)
def update_policy_save_error_recovers(context) -> None:
    _seed_update(context, failPolicySaveCount=1)
    context.app.start()
    context.app.wait_for_prompt()
    _open_policy(context)
    context.app.press("DOWN")
    context.app.press("ENTER")
    context.app.wait_for_text("Gerber could not save the Core update policy")
    context.app.wait_for_text("write permissions")
    context.app.expect_text_absent("Core update policy saved:")
    config = context.app.runtime_paths.scenario_root / "GerberCore.json"
    assert "coreUpdates" not in json.loads(config.read_text())
    _continue_to_update_menu(context)
    _choose_policy(context)
    context.app.wait_for_text("Current Core update policy: Stable only")
    context.app.press("DOWN")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update policy saved: Include prereleases")
    assert json.loads(config.read_text())["coreUpdates"]["channel"] == "IncludePrerelease"
    assert _update_state(context)["installCount"] == 0
    _continue_to_update_menu(context)
    _assert_trace_order(context, "numbered-submit", "update-policy-save-failed", "screen-transition",
                        "numbered-open", "numbered-submit", "update-policy-saved", "screen-transition")


@scenario(
    "update-shared-submenu",
    title="Update uses the shared list/policy chooser with local back navigation",
    categories=("core", "updates", "navigation"),
    metadata=ScenarioMetadata(
        commands=("update", "update list", "update policy"),
        workflows=("command:update", "command:update list", "command:update policy"),
        coverage=("discovery", "dispatch", "workflow", "navigation", "rendering"),
    ),
)
def update_shared_submenu(context) -> None:
    _seed_update(context)
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/update")
    context.app.press("ENTER")
    context.app.expect_input("/update ")
    context.app.wait_for_text("[list|policy]")
    context.app.expect_suggestion("/update list")
    context.app.expect_suggestion("/update policy")
    context.app.expect_selected_suggestion_highlighted("/update list")
    assert _update_state(context)["discoveryCount"] == 0
    context.app.press("ENTER")
    context.app.wait_for_text("Install Core update?")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update cancelled")
    context.app.press("ENTER")
    context.app.expect_input("/update ")
    context.app.expect_selected_suggestion_highlighted("/update list")
    context.app.press("ENTER")
    context.app.wait_for_text("Install Core update?")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("/update ")
    context.app.expect_selected_suggestion_highlighted("/update list")
    context.app.type("pol")
    context.app.press("TAB")
    context.app.press("ENTER")
    context.app.wait_for_text("Core update channel (Esc to go back)")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("/update ")
    context.app.expect_selected_suggestion_highlighted("/update list")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("")
    assert _update_state(context)["installCount"] == 0
