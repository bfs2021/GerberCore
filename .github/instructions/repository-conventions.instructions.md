---
applyTo: "**"
---

# Repository conventions

## Purpose

Canonical rule source for cross-cutting Gerber conventions that apply to every change. Topic-specific rules live in the other `.instructions.md` files; this file owns the rules that do not belong to one topic.

## Project layering

- Treat `project.json` as the source of truth for project metadata, build output, package settings, and release settings.
- Treat `project.json` `Manifest.PowerShellHostVersion` as the compatibility target for PowerShell code, tests, and examples. If a project targets `5.1`, do not introduce PowerShell 7.x-only syntax, cmdlets, parameters, or APIs unless the work explicitly adds guarded compatibility handling.
- Use Nova commands and repository wrappers for build, test, package, and release workflows; do not replace them with ad hoc PowerShell module build scripts.
- Do not create or maintain hand-written module `.psm1` or module `.psd1` files in source; Nova generates the built module root and manifest under `dist/Gerber/` from `project.json` and `src/**/*.ps1`.

## File ownership

- `src/public/` files own exactly one top-level function each. The file name matches the function name.
- `src/private/` files expose at most one externally called function per file. Additional helpers may stay as sibling top-level functions in the same file only when they are called exclusively by that entry function and have no callers outside the file. The file name matches the externally called function.
- PowerShell functions must not declare nested functions inside their bodies.
- Prefer existing helpers and support files over ad hoc duplication.
- Do not add raw infrastructure calls in public commands when an adapter/helper layer already exists.

## Validation expectations

Use the smallest validation set that proves the change, then run the repository quality loop before finishing code work:

- local quality loop: use the repository quality wrapper when one exists; otherwise run ScriptAnalyzer, build, `Invoke-NovaTest`, and `Test-NovaBuild` in the documented project order
- test validation: `Invoke-NovaTest` for unit-test validation, then `Test-NovaBuild` for build-validation integration coverage
- analyzer only: `./scripts/build/Invoke-ScriptAnalyzerCI.ps1`
- CI-parity coverage flow: use the repository-specific CI helper when one exists

If the repository quality loop or `./scripts/build/Invoke-ScriptAnalyzerCI.ps1` reports findings, fix them before review, handoff, or commit. Do not treat a failing validation run as an acceptable stopping point.

When project-specific quality tooling is available:

- run the configured local safeguard before suggesting a commit
- run the configured branch or change-set check before suggesting a PR
- if quality tooling reports a regression, refactor instead of treating the work as done
- If a quality tooling regression cannot be resolved by refactoring, for example because it appears in generated, vendored, or third-party code, document the exception in the PR description and proceed; do not block the change indefinitely.

If quality tooling is unavailable locally, continue with the normal repository validation flow; pull requests and CI remain the effective gate.

If the only files changed are `.md` files and none of those files contain embedded code blocks that are executed as part of a test or build step, executable validation may be skipped.

For changes that affect Gerber's interactive CLI, command registry, plugin integration, input handling, rendering, or command dispatch, the tracked PTY regression harness is mandatory:

- use `pwsh -NoLogo -NoProfile -File ./scripts/build/Invoke-TerminalRegressionCI.ps1` for Gerber Core and the bundled `Gerber.TerminalFixture` Plugin API contract
- keep Gerber Core's inventory and coverage scoped to Core commands; the fixture's plugin commands have a separate inventory and coverage report
- do not load sibling plugin repositories from Gerber's terminal runner; each plugin repository owns its product-specific terminal scenarios and coverage
- treat PTY regressions the same way as failing tests: fix them before review, handoff, or commit
- new interactive behavior must ship with terminal regression coverage in `tests/terminal/scenarios/`
- every fixed interactive regression must keep a permanent automated reproduction in the PTY suite or a focused deterministic self-test
- failing regression tests must never be removed, weakened, skipped, bypassed, or replaced with looser assertions to obtain a green run
- unexpected PowerShell binding, parameter, parser, or stack-trace exceptions in the terminal surface are test failures even when the screen remains visible
- every executable command must appear in the registry-derived terminal command inventory
- every executable command requires discovery coverage and dispatch coverage or an exact, justified test classification
- every interactive command additionally requires executable workflow, navigation, rendering, and relevant error/recovery coverage
- scenario metadata must name the commands, workflows, and coverage categories the scenario actually executes; a declaration without a passing scenario in the current full run does not count
- missing commands, missing coverage categories, stale command references, duplicate scenario identifiers, and scenarios that did not execute successfully must fail the full terminal gate
- exclusions must be exact command/category records with a narrow classification and reason; do not exclude whole plugins, network commands, credential commands, or interactive menus
- generic Core/Plugin API integration coverage must import and execute the built Gerber module plus `Gerber.TerminalFixture` rather than source-dot-sourcing across the module boundary

## CI parity and readiness

- Before changing code or tests, inspect the active `.github/workflows/` definitions and their owning `scripts/build/ci/` helpers. Identify the required OS, architecture, PowerShell versions, dependency provisioning and checks affected by the change; shared tests can break a platform even when production code did not change.
- Run the focused checks and the required local quality loop. Local `run.ps1` success is not matrix qualification. Use the configured lane entrypoint on a matching host/runtime where available, preserving dependency isolation and failure semantics; never spoof runner identity or bypass host guards.
- Review changed tests for portability, including path separators, casing, filesystem ordering and platform-specific commands. Build expected filesystem paths with `Join-Path` and compare the intended path contract, not a string containing the development host's separator. Preserve exact identity and side-effect assertions.
- Before raising a dependency minimum, verify that CI's configured provider and version-selection rules can supply a compatible artifact. Record the actual imported version and path in the test process, not just the launcher's installed-module inventory; a locally built or installed sibling module does not prove availability on a clean runner. An unavailable dependency blocks consumer readiness until an upstream release or explicit CI artifact-delivery change is separately authorized. Do not lower the minimum, add fallback imports, publish packages or modify global module installations to hide the gap.
- Report local and hosted evidence separately: tested revision/content state, OS/architecture, actual PowerShell and dependency versions, exact commands, test/coverage results and relevant run/job URLs. Mark unavailable hosts/runtimes, skipped required tests, interrupted commands and missing artifacts as unverified, not passed.
- Inspect every required hosted job for the exact revision and run attempt before claiming CI or PR readiness. An earlier revision's green run, passing unit tests or local PTY results cannot qualify unexecuted native-credential lanes. Uncommitted fixes remain pending hosted verification; a local handoff must say so.
- Trace failures to the first failing assertion or provisioning step before changing code. Keep regression assertions and thresholds intact; do not skip platform tests, weaken comparisons, retry until green without diagnosis, or treat downstream missing-artifact errors as the primary defect.

For Gerber, inspect both `.github/workflows/Tests.yml` and
`.github/workflows/Run-Platform-Matrix.yml`. The latter exercises native
credentials on Windows, Linux and macOS; it does not replace the full local
quality loop or PTY coverage. Never execute its guarded native-credential
entrypoint against a workstation vault. Before changing
`project.json` `Manifest.RequiredModules`, check
`.github/workflows/Tests.yml`, `Publish.yml` and the `install-ps-modules` action
of the shared `powershell-ci` repository, which installs `RequiredModules`
from `project.json`, and all explicit imports,
including `Invoke-NativeCredentialPlatformCI.ps1`. A local PMU prerelease can
satisfy the numeric manifest minimum while PSGallery provisioning still cannot;
report that delivery gap instead of claiming a clean-runner import was proven.

## Documentation review

- Review `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, and `RELEASE_NOTE.md` after any change that adds, removes, or alters public-facing behavior, commands, parameters, or documented workflows.
- Update tests when behavior changes.

## File formatting rule

- Before handoff, review every changed or created text file and ensure it ends with exactly one trailing newline and no extra blank lines at the bottom.
- This rule applies to human-authored source files (`.ps1`, `.psm1`, `.psd1`, `.md`, `.json`, `.yml`, `.txt`). Do not apply it to binary files, lock files, or files under `dist/` that are generated by the build.
- Do not leave any edited file with extra blank lines at the end, even if the functional code change is already complete.
- Do not alter internal whitespace just to enforce the trailing newline rule.

## Safety constraints

- Do not publish packages, create tags, or push changes unless explicitly requested.
- Do not modify `Publish.yml` unless the change is explicitly requested and the requester has acknowledged that `Publish.yml` mutates `main` and `develop`.

## Commit message guidance

- When you are asked to suggest or prepare a commit message, answer in English.
- Use Conventional Commit format.
- Extract the ticket number from `$GIT_BRANCH_NAME` and render it as `(#<number>)` immediately after the type when one is available.
- If `$GIT_BRANCH_NAME` is not set or is empty, omit the ticket number entirely and do not add a placeholder.
- Branch prefix takes precedence over change content when selecting the commit type.
- Select the commit type in this order:
    1. If `$GIT_BRANCH_NAME` starts with `hotfix/` or `bug/`, use `fix` as the type. Use `fix!` if that branch change is also breaking. Stop.
    2. Otherwise estimate the type from the actual change:
        - `feat` for feature work
        - `fix` for bug fixes
        - `feat!` for breaking feature work
        - `fix!` for breaking fixes
- Keep the subject short, specific, and free of unnecessary detail.
- If you provide multiple commit message suggestions or summarize multiple change options, use bullet points.
- Do not invent a ticket number when `$GIT_BRANCH_NAME` does not contain one.

## Markdown output

When the output is intended to be copied as Markdown from the UI or written to a Markdown file, follow the `markdown-authoring` skill (`.github/skills/markdown-authoring/SKILL.md`). Apply that rule especially to release summaries, review summaries, contributor-facing Markdown docs, prompt output, and PR-template-shaped text. If `.github/skills/markdown-authoring/SKILL.md` is not accessible, apply standard CommonMark formatting: use ATX headings, fenced code blocks with language identifiers, and no trailing whitespace.
