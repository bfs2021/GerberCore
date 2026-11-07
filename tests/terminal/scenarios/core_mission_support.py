from __future__ import annotations

import json
from pathlib import Path
from typing import Any
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit


STRICT_HTTP_ERROR = {
    "type": "error",
    "message": "Unexpected Gerber Core terminal HTTP request.",
}


def strict_http_fixture(request_list: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "defaultResult": dict(STRICT_HTTP_ERROR),
        "requests": request_list,
    }


def seed_credential_state(
    path: Path,
    credential_map: dict[str, str],
    failure_map: dict[str, str] | None = None,
) -> None:
    _write_json(
        path,
        {
            "credentials": credential_map,
            "operations": [],
            "failures": failure_map or {},
        },
    )


def assert_http_request(
    request: dict[str, Any],
    *,
    method: str,
    uri: str,
    body: dict[str, Any] | None = None,
) -> None:
    assert request["method"] == method, request
    assert _canonical_uri(request["uri"]) == _canonical_uri(uri), request
    if body is not None:
        assert request["body"] == body, request


def assert_selected_text(source_text: str, expected_text: str) -> None:
    assert expected_text in source_text, source_text


def assert_preview(source_text: str, expected_text: str) -> None:
    assert expected_text in source_text, source_text


def assert_mutation_target(request_list: list[dict[str, Any]], expected_uri: str) -> None:
    assert any(request["uri"] == expected_uri for request in request_list), request_list


def assert_confirmation_event(trace_text: str, event_name: str) -> None:
    event_name_list = [
        json.loads(line).get("Event")
        for line in trace_text.splitlines()
        if line.strip()
    ]
    assert event_name in event_name_list, event_name_list


def assert_no_secret_leak(app, *secret_list: str) -> None:
    source_text = "\n".join((app.visible_text(), app.raw_output(), app.prompt_trace_text()))
    for secret in secret_list:
        assert secret not in source_text


def start_with_credentials(context, credential_map: dict[str, str]) -> None:
    seed_credential_state(context.app.runtime_paths.credential_state_path, credential_map)
    context.app.start(http_fixture=strict_http_fixture([]))
    context.app.wait_for_prompt()


def verify_secret_inventory(context, identifier: str, secret: str) -> None:
    start_with_credentials(context, {identifier: secret})
    context.app.type("/secrets list")
    context.app.press("ENTER")
    context.app.wait_for_text(identifier)
    context.app.press("ENTER")
    context.app.wait_for_text("/secrets")
    context.app.close()


def verify_secret_presence(context, identifier: str, secret: str) -> None:
    start_with_credentials(context, {identifier: secret})
    enter_secret_identifier(context, "test", "Gerber credential identifier", identifier)
    context.app.wait_for_text("Stored")
    context.app.press("ENTER")
    context.app.wait_for_text("Gerber credential identifier")
    context.app.type("gerber:terminal:missing")
    context.app.press("ENTER")
    context.app.wait_for_text("Not stored")
    context.app.close()


def verify_secret_hidden_reveal(context, identifier: str, secret: str) -> None:
    start_with_credentials(context, {identifier: secret})
    enter_secret_identifier(context, "get", "Gerber secret name", identifier)
    context.app.wait_for_text("Reveal")
    context.app.press("DOWN")
    context.app.press("ENTER")
    context.app.wait_for_text("kept the secret value hidden")
    assert context.app.clipboard_state()["values"][-1]["value"] == secret
    context.app.close()


def replace_secret_name_template(context, name: str) -> None:
    context.app.press_many("DELETE", len("<scope>:<name>"))
    context.app.type(name)
    context.app.press("ENTER")


def enter_secret_identifier(
    context,
    action: str,
    prompt_text: str,
    identifier: str,
) -> None:
    context.app.type(f"/secrets {action}")
    context.app.press("ENTER")
    context.app.wait_for_text(prompt_text)
    context.app.type(identifier)
    context.app.press("ENTER")


def verify_secret_creation(context, secret: str) -> None:
    start_with_credentials(context, {})
    context.app.type("/secrets set")
    context.app.press("ENTER")
    context.app.wait_for_text("Gerber secret name")
    replace_secret_name_template(context, "terminal:created")
    context.app.wait_for_text("Secret value")
    context.app.type_secret(secret)
    context.app.press("ENTER")
    context.app.wait_for_text("Stored credential 'gerber:terminal:created'")
    state = context.app.credential_state()
    assert state["credentials"]["gerber:terminal:created"] == secret
    context.app.close()


def verify_secret_removal(context, identifier: str, secret: str) -> None:
    start_with_credentials(context, {identifier: secret})
    enter_secret_identifier(context, "remove", "Gerber secret name", identifier)
    context.app.wait_for_text("Remove")
    context.app.press("ENTER")
    context.app.wait_for_text("Removed credential")
    assert identifier not in context.app.credential_state()["credentials"]
    assert context.app.http_state()["requests"] == []
    assert_no_secret_leak(context.app, secret)


def _write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2), encoding="utf-8")


def _canonical_uri(value: str) -> str:
    parts = urlsplit(value)
    query = urlencode(sorted(parse_qsl(parts.query, keep_blank_values=True)))
    return urlunsplit((parts.scheme, parts.netloc, parts.path, query, parts.fragment))
