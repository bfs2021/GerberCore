from __future__ import annotations

import time

from framework.scenario_registry import ScenarioMetadata, scenario


def _open_base64_flow(context, action: str, prompt: str, value: str) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type(f"/tools base-64 {action}")
    context.app.press("ENTER")
    context.app.wait_for_text(prompt)
    context.app.type(value)
    context.app.press("ENTER")


def _open_tools_parent_menu(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/tools")
    context.app.press("ENTER")
    context.app.wait_for_text("/tools")
    context.app.wait_for_prompt()
    context.app.expect_input("/tools ")
    context.app.expect_selected_suggestion_highlighted("/tools base-64")


def _select_tools_base64_from_parent(context) -> None:
    context.app.press("ENTER")
    context.app.wait_for_text("/tools base-64")
    context.app.wait_for_prompt()
    context.app.expect_input("/tools base-64 ")
    context.app.expect_selected_suggestion_highlighted("/tools base-64 decode")


def _press_double_escape(context) -> None:
    session = context.app._require_session()
    session.send_key("ESCAPE")
    time.sleep(0.1)
    session.send_key("ESCAPE")
    time.sleep(0.05)
    session.wait_for_stable_screen()


def _verify_menu_dispatch_contracts(context, expectation_map: dict[str, str]) -> None:
    expectation_list = list(expectation_map.items())
    for index, (command_name, expected_suggestion) in enumerate(expectation_list):
        context.app.start()
        context.app.wait_for_prompt()
        context.app.type(f"/{command_name}")
        context.app.press("ENTER")
        context.app.expect_suggestion(expected_suggestion)
        if index < len(expectation_list) - 1:
            context.app.close()


def _registry_command_list(inventory: list[dict]) -> list[dict]:
    return [
        item
        for item in inventory
        if item["hasSubcommands"] or " " not in item["canonicalPath"]
    ]


def _verify_registered_command(context, inventory: list[dict], command: dict) -> None:
    display_text = f"/{command['canonicalPath']}"
    input_text = display_text.lower()
    context.app.type(input_text)
    context.app.expect_input(input_text)
    if command["hasSubcommands"]:
        _verify_registered_subcommands(context, inventory, command, display_text)


def _verify_registered_subcommands(
    context,
    inventory: list[dict],
    command: dict,
    display_text: str,
) -> None:
    suggestion_list = context.app.suggestion_list()
    parent_path = command["canonicalPath"]
    expected_child_list = [
        f"/{item['canonicalPath']}"
        for item in inventory
        if " " in item["canonicalPath"]
        and item["canonicalPath"].rsplit(" ", maxsplit=1)[0] == parent_path
    ]
    missing_child_list = [item for item in expected_child_list if item not in suggestion_list]
    if missing_child_list:
        raise AssertionError(
            f"Expected nested suggestions for '{display_text}', missing {missing_child_list}: {suggestion_list}"
        )


@scenario("startup-home-screen", title="Startup home screen", categories=("core", "startup"))
def startup_home_screen(context) -> None:
    context.app.start()
    context.app.wait_for_text("Gerber - DevOps Multitool")
    context.app.wait_for_prompt()
    context.app.wait_for_text("/ commands · esc back")


@scenario(
    "exit-cleanly",
    title="Exit cleanly",
    categories=("core", "submission"),
    metadata=ScenarioMetadata(
        commands=("exit",),
        workflows=("command:exit",),
        coverage=("dispatch", "workflow", "rendering"),
    ),
)
def exit_cleanly(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/exit")
    context.app.press("ENTER")
    context.app.wait_for_text("Exiting Gerber.")
    context.app.wait_for_exit()


@scenario("enter-empty-input-recovers", title="Empty input recovers", categories=("core", "submission", "recovery"))
def enter_empty_input_recovers(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.press("ENTER")
    context.app.wait_for_text("Enter a command like /tools or choose a numbered menu option.")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.wait_for_text("/ commands · esc back")


@scenario("invalid-command-recovers", title="Invalid command recovers", categories=("core", "errors", "recovery"))
def invalid_command_recovers(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/bogus")
    context.app.press("ENTER")
    context.app.wait_for_text("Unknown command '/bogus'")
    context.app.press("ENTER")
    context.app.wait_for_prompt()
    context.app.type("/help")
    context.app.press("ENTER")
    context.app.wait_for_text("/help")


@scenario(
    "basic-root-search-opens-help",
    title="Basic root search opens help",
    categories=("core", "submission"),
    metadata=ScenarioMetadata(
        commands=("help",),
        workflows=("command:help",),
        coverage=("dispatch", "workflow", "rendering"),
    ),
)
def basic_root_search_opens_help(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("help")
    context.app.expect_selected_suggestion("/help")
    context.app.press("ENTER")
    context.app.wait_for_text("/help")
    context.app.wait_for_text("/tools")


@scenario("cursor-left-and-right", title="Cursor left and right", categories=("core", "cursor"))
def cursor_left_and_right(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/help")
    context.app.press("LEFT")
    context.app.expect_cursor_index(4)
    context.app.press("RIGHT")
    context.app.expect_cursor_index(5)


@scenario("cursor-boundaries-clamp", title="Cursor boundaries clamp", categories=("core", "cursor"))
def cursor_boundaries_clamp(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/help")
    context.app.press_many("LEFT", 8)
    context.app.expect_cursor_index(0)
    context.app.press("LEFT")
    context.app.expect_cursor_index(0)
    context.app.press_many("RIGHT", 8)
    context.app.expect_cursor_index(5)
    context.app.press("RIGHT")
    context.app.expect_cursor_index(5)


@scenario("cursor-home-and-end", title="Cursor home and end", categories=("core", "cursor"))
def cursor_home_and_end(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/help")
    context.app.press("HOME")
    context.app.expect_cursor_index(0)
    context.app.press("END")
    context.app.expect_cursor_index(5)


@scenario("insert-at-beginning", title="Insert at beginning", categories=("core", "editing"))
def insert_at_beginning(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("xit")
    context.app.press("HOME")
    context.app.type("e")
    context.app.expect_input("exit")
    context.app.expect_cursor_index(1)


@scenario("insert-in-middle", title="Insert in middle", categories=("core", "editing"))
def insert_in_middle(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/hlp")
    context.app.press_many("LEFT", 2)
    context.app.type("e")
    context.app.expect_input("/help")


@scenario("insert-at-end", title="Insert at end", categories=("core", "editing"))
def insert_at_end(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/hel")
    context.app.press("HOME")
    context.app.press("END")
    context.app.type("p")
    context.app.expect_input("/help")
    context.app.expect_cursor_index(5)


@scenario("backspace-edits-buffer", title="Backspace edits buffer", categories=("core", "editing"))
def backspace_edits_buffer(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/helpp")
    context.app.press("BACKSPACE")
    context.app.expect_input("/help")
    context.app.expect_cursor_index(5)


@scenario("delete-edits-buffer", title="Delete edits buffer", categories=("core", "editing"))
def delete_edits_buffer(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/helpx")
    context.app.press("LEFT")
    context.app.expect_cursor_index(5)
    context.app.press("DELETE")
    context.app.expect_input("/help")
    context.app.expect_cursor_index(5)


@scenario("repeated-deletion-recovers", title="Repeated deletion recovers", categories=("core", "editing"))
def repeated_deletion_recovers(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/helpppp")
    context.app.press_many("BACKSPACE", 3)
    context.app.expect_input("/help")
    context.app.expect_cursor_index(5)


@scenario("unicode-input-renders", title="Unicode input renders", categories=("core", "editing", "unicode"))
def unicode_input_renders(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("æøå")
    context.app.expect_input("æøå")
    context.app.expect_cursor_index(3)
    context.app.press("BACKSPACE")
    context.app.expect_input("æø")


@scenario("escape-restores-home-prompt", title="Escape restores home prompt", categories=("core", "escape"))
def escape_restores_home_prompt(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/")
    context.app.expect_selected_suggestion("/exit")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()
    context.app.expect_input("")
    context.app.wait_for_text("/ commands · esc back")


@scenario("root-suggestions-are-alphabetical", title="Root suggestions are alphabetical", categories=("core", "suggestions"))
def root_suggestions_are_alphabetical(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/")
    context.app.expect_suggestion_order([
        "/exit",
        "/help",
        "/plugins",
        "/update",
        "/branch",
        "/list",
        "/pipelines",
        "/repository",
        "/secrets",
        "/tools",
    ])


@scenario("nested-tools-suggestions", title="Nested tools suggestions", categories=("core", "suggestions"))
def nested_tools_suggestions(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/tools")
    context.app.expect_suggestion("/tools base-64")
    context.app.expect_suggestion("/tools create-uuid")


@scenario("suggestion-navigation-up-and-down", title="Suggestion navigation", categories=("core", "suggestions"))
def suggestion_navigation_up_and_down(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/")
    context.app.expect_selected_suggestion("/exit")
    context.app.press("DOWN")
    context.app.expect_selected_suggestion("/help")
    context.app.press("UP")
    context.app.expect_selected_suggestion("/exit")


@scenario("preview-tracks-selected-suggestion", title="Preview tracks selection", categories=("core", "suggestions"))
def preview_tracks_selected_suggestion(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/repo")
    context.app.expect_selected_suggestion("/repository")
    context.app.expect_preview("Open the interactive repository menu")


@scenario("selection-follows-editing", title="Selection follows editing", categories=("core", "suggestions", "editing"))
def selection_follows_editing(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/repot")
    context.app.press("BACKSPACE")
    context.app.expect_selected_suggestion("/repository")
    context.app.expect_preview("Open the interactive repository menu")


@scenario("selected-suggestion-preview-correspondence", title="Selected suggestion preview correspondence", categories=("core", "suggestions"))
def selected_suggestion_preview_correspondence(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/")
    context.app.expect_selected_suggestion("/exit")
    context.app.expect_preview("Exit the interactive Gerber session")
    context.app.press("DOWN")
    context.app.expect_selected_suggestion("/help")
    context.app.expect_preview("Show the built-in command help")


@scenario(
    "suggestion-selection-opens-command",
    title="Suggestion selection opens command",
    categories=("core", "suggestions", "submission"),
    metadata=ScenarioMetadata(
        commands=("tools",),
        workflows=("command:tools",),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def suggestion_selection_opens_command(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/tool")
    context.app.press("TAB")
    context.app.expect_input("/tools")
    context.app.press("ENTER")
    context.app.expect_suggestion("/tools base-64")


@scenario("duplicate-prompt-prevention", title="Duplicate prompt prevention", categories=("core", "rendering"))
def duplicate_prompt_prevention(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/")
    context.app.press("BACKSPACE")
    snapshot = context.app.snapshot()
    prompt_count = sum(1 for line in snapshot.lines if line.startswith("❯"))
    if prompt_count != 1:
        raise AssertionError(f"Expected exactly one visible prompt line, but saw {prompt_count}:\n{snapshot.text}")


@scenario("repeated-menu-entry-and-escape", title="Repeated menu entry and escape", categories=("core", "escape", "submission"))
def repeated_menu_entry_and_escape(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    for _ in range(2):
        context.app.wait_for_prompt()
        context.app.type("/tools")
        context.app.expect_input("/tools")
        context.app.press("ENTER")
        context.app.expect_suggestion("/tools base-64")
        context.app.press("ESCAPE")
        context.app.wait_for_text("/ commands · esc back")
        context.app.wait_for_prompt()
        context.app.expect_input("")


@scenario(
    "registered-command-discovery",
    title="Registered command discovery",
    categories=("core", "plugin", "inventory", "suggestions"),
    metadata=ScenarioMetadata(
        commands=("*",),
        workflows=("registry-discovery",),
        coverage=("discovery",),
    ),
)
def registered_command_discovery(context) -> None:
    inventory = context.app.command_inventory()
    command_list = _registry_command_list(inventory)
    for index, command in enumerate(command_list):
        context.app.start()
        context.app.wait_for_prompt()
        _verify_registered_command(context, inventory, command)
        if index < len(command_list) - 1:
            context.app.close()


@scenario(
    "root-menu-dispatch-contracts",
    title="Root menu dispatch contracts",
    categories=("core", "navigation", "rendering", "submission"),
    metadata=ScenarioMetadata(
        commands=("tools", "list", "branch", "repository", "plugins", "pipelines", "secrets"),
        workflows=(
            "command:tools",
            "command:list",
            "command:branch",
            "command:repository",
            "command:plugins",
            "command:pipelines",
            "command:secrets",
        ),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def root_menu_dispatch_contracts(context) -> None:
    expectation_map = {
        "tools": "/tools base-64",
        "plugins": "/plugins info",
        "secrets": "/secrets get",
    }
    _verify_menu_dispatch_contracts(context, expectation_map)


@scenario(
    "nested-menu-dispatch-contracts",
    title="Nested menu dispatch contracts",
    categories=("core", "navigation", "rendering", "submission"),
    metadata=ScenarioMetadata(
        commands=("tools base-64",),
        workflows=(
            "command:tools base-64",
        ),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def nested_menu_dispatch_contracts(context) -> None:
    expectation_map = {
        "tools base-64": "/tools base-64 decode",
    }
    _verify_menu_dispatch_contracts(context, expectation_map)


@scenario(
    "create-uuid-workflow",
    title="Create UUID workflow",
    categories=("core", "tools", "rendering", "clipboard"),
    metadata=ScenarioMetadata(
        commands=("tools create-uuid",),
        workflows=("command:tools create-uuid",),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def create_uuid_workflow(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/tools create-uuid")
    context.app.press("ENTER")
    context.app.wait_for_text("Press Enter to generate another, or Esc to go back")
    state = context.app.clipboard_state()
    if len(state["values"]) != 1:
        raise AssertionError(f"Expected one generated UUID in clipboard state: {state}")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()


@scenario(
    "base64-encode-workflow",
    title="Base64 encode workflow",
    categories=("core", "tools", "rendering", "clipboard"),
    metadata=ScenarioMetadata(
        commands=("tools base-64 encode",),
        workflows=("command:tools base-64 encode",),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def base64_encode_workflow(context) -> None:
    _open_base64_flow(context, "encode", "Text to encode", "Gerber")
    context.app.wait_for_text("R2VyYmVy")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()


@scenario(
    "base64-double-escape-to-root",
    title="Base64 double Escape returns to root",
    categories=("core", "tools", "escape", "navigation"),
    metadata=ScenarioMetadata(
        commands=("tools base-64", "tools base-64 encode"),
        workflows=("command:tools base-64 encode", "navigation:double-escape-root"),
        coverage=("workflow", "navigation", "rendering"),
    ),
)
def base64_double_escape_to_root(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/tools base-64 encode")
    context.app.press("ENTER")
    context.app.wait_for_text("Text to encode")
    _press_double_escape(context)
    context.app.wait_for_prompt()
    context.app.expect_input("/")
    context.app.expect_selected_suggestion("/exit")


@scenario(
    "base64-escape-threshold-stays-local",
    title="Escape threshold keeps local back navigation",
    categories=("core", "tools", "escape", "navigation"),
    metadata=ScenarioMetadata(
        commands=("tools base-64", "tools base-64 encode"),
        workflows=("command:tools base-64 encode", "navigation:double-escape-threshold"),
        coverage=("workflow", "navigation", "rendering"),
    ),
)
def base64_escape_threshold_stays_local(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    context.app.type("/tools base-64 encode")
    context.app.press("ENTER")
    context.app.wait_for_text("Text to encode")
    context.app.press("ESCAPE")
    context.app.wait_for_text("/tools base-64")
    context.app.wait_for_prompt()
    context.app.expect_input("/tools base-64 ")
    context.app.expect_selected_suggestion("/tools base-64 decode")
    time.sleep(0.7)
    context.app.press("ESCAPE")
    context.app.wait_for_text("/tools ")
    context.app.wait_for_prompt()
    context.app.expect_input("/tools ")
    context.app.expect_selected_suggestion("/tools base-64")


@scenario(
    "tools-menu-highlight-restores-after-escape",
    title="Tools menu keeps highlight after nested Escape navigation",
    categories=("core", "tools", "escape", "navigation", "rendering"),
    metadata=ScenarioMetadata(
        commands=("tools", "tools base-64"),
        workflows=("command:tools", "command:tools base-64", "navigation:single-escape"),
        coverage=("workflow", "navigation", "rendering"),
    ),
)
def tools_menu_highlight_restores_after_escape(context) -> None:
    _open_tools_parent_menu(context)
    _select_tools_base64_from_parent(context)
    context.app.press("ESCAPE")
    context.app.wait_for_text("/tools")
    context.app.wait_for_prompt()
    context.app.expect_input("/tools ")
    context.app.expect_selected_suggestion_highlighted("/tools base-64")


@scenario(
    "base64-decode-workflow",
    title="Base64 decode workflow",
    categories=("core", "tools", "rendering", "clipboard"),
    metadata=ScenarioMetadata(
        commands=("tools base-64 decode",),
        workflows=("command:tools base-64 decode",),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def base64_decode_workflow(context) -> None:
    _open_base64_flow(context, "decode", "Base64 to decode", "R2VyYmVy")
    context.app.wait_for_text("Gerber")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()


@scenario(
    "base64-invalid-decode-recovers",
    title="Base64 invalid decode recovers",
    categories=("core", "tools", "errors", "recovery"),
    metadata=ScenarioMetadata(
        commands=("tools base-64 decode",),
        workflows=("command:tools base-64 decode", "input:invalid-base64"),
        coverage=("error-recovery",),
    ),
)
def base64_invalid_decode_recovers(context) -> None:
    _open_base64_flow(context, "decode", "Base64 to decode", "not-base64")
    context.app.wait_for_text("That value is not valid Base64")
    context.app.press("ESCAPE")
    context.app.wait_for_prompt()


@scenario(
    "root-double-escape-stability",
    title="Double Escape at root stays in Gerber",
    categories=("core", "escape", "navigation"),
    metadata=ScenarioMetadata(
        commands=(),
        workflows=("navigation:double-escape-root-stability",),
        coverage=("navigation", "rendering"),
    ),
)
def root_double_escape_stability(context) -> None:
    context.app.start()
    context.app.wait_for_prompt()
    _press_double_escape(context)
    context.app.wait_for_prompt()
    context.app.expect_text_absent("Exiting Gerber.")
