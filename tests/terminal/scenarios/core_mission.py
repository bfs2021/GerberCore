from __future__ import annotations

from framework.scenario_registry import ScenarioMetadata, scenario
from .core_mission_support import (
    assert_no_secret_leak, replace_secret_name_template, seed_credential_state,
    start_with_credentials, strict_http_fixture, verify_secret_creation,
    verify_secret_hidden_reveal, verify_secret_inventory, verify_secret_presence,
    verify_secret_removal,
)


@scenario(
    "core-mission-secrets-lifecycle",
    title="Core secrets isolated lifecycle",
    categories=("core", "mission", "credentials"),
    metadata=ScenarioMetadata(
        commands=("secrets list", "secrets get", "secrets test", "secrets set", "secrets remove"),
        workflows=(
            "command:secrets list", "command:secrets get", "command:secrets test",
            "command:secrets set", "command:secrets remove", "credentials:isolated-lifecycle",
        ),
        coverage=("dispatch", "workflow", "navigation", "rendering", "error-recovery"),
    ),
)
def secrets_lifecycle(context) -> None:
    identifier = "gerber:terminal:fixture"
    secret = "terminal-secret-value"
    context.app.register_sensitive_value(secret)
    verify_secret_inventory(context, identifier, secret)
    verify_secret_presence(context, identifier, secret)
    verify_secret_hidden_reveal(context, identifier, secret)
    verify_secret_creation(context, secret)
    verify_secret_removal(context, identifier, secret)


@scenario(
    "core-mission-secrets-storage-recovery",
    title="Core secrets controlled storage failure recovery",
    categories=("core", "mission", "credentials", "recovery"),
    metadata=ScenarioMetadata(
        commands=("secrets list", "secrets get", "secrets test", "secrets set", "secrets remove"),
        workflows=("credentials:controlled-storage-failure",),
        coverage=("error-recovery",),
    ),
)
def secrets_storage_recovery(context) -> None:
    secret = "terminal-never-render-this-secret"
    context.app.register_sensitive_value(secret)
    for command in ("secrets list", "secrets get", "secrets remove"):
        seed_credential_state(
            context.app.runtime_paths.credential_state_path,
            {"gerber:terminal:fixture": secret},
            {"GetAccounts": "Synthetic credential inventory failure."},
        )
        context.app.start(http_fixture=strict_http_fixture([]))
        context.app.wait_for_prompt()
        context.app.type(f"/{command}")
        context.app.press("ENTER")
        context.app.wait_for_text("secure credential storage is unavailable")
        context.app.expect_text_absent("Synthetic credential inventory failure.")
        context.app.press("ENTER")
        assert_no_secret_leak(context.app, secret)
        context.app.close()

    for command, prompt_text in (
        ("secrets test", "Gerber credential identifier"),
        ("secrets set", "Gerber secret name"),
    ):
        seed_credential_state(
            context.app.runtime_paths.credential_state_path, {},
            {"GetAccounts": "Synthetic credential read failure."},
        )
        context.app.start(http_fixture=strict_http_fixture([]))
        context.app.wait_for_prompt()
        context.app.type(f"/{command}")
        context.app.press("ENTER")
        context.app.wait_for_text(prompt_text)
        if command == "secrets set":
            replace_secret_name_template(context, "terminal:failure")
        else:
            context.app.type("gerber:terminal:failure")
            context.app.press("ENTER")
        context.app.wait_for_text("secure credential storage is unavailable")
        context.app.press("ENTER")
        assert_no_secret_leak(context.app, secret)
        context.app.close()
    start_with_credentials(context, {})
    assert_no_secret_leak(context.app, secret)
