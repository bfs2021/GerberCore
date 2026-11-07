# Gerber — Product Roadmap and Work Register

> Reconstructed 2026-10-10. This roadmap preserves both the original product-phase names and the more granular G-1A implementation IDs. **Statuses distinguish user-reported progress from verified completion.** Do not rename historical phases to make a new plan.

## TL;DR
- G-4A7R Core distribution and ordering are implemented. PMU 0.2.0 is published and satisfies the current dependency minimum; the historical missing-dependency blocker is resolved.
- A live Core update was user-confirmed on 2026-10-27. Hosted tests passed at `d599443`; those jobs and the native credential matrix do not qualify the current local PMU correction or live updates on Windows/Linux.
- The separate PMU cleanup is committed as `9330a8b`. The provider `PackageNotFound` correction is implemented and locally verified in the uncommitted PMU worktree; it is not published or deployed. G-4A7R remains open for corrected-dependency delivery and broader live-update/recovery qualification.
- Gerber's full local loop passed against the corrected isolated PMU build: 1,858 unit tests, 17 integration tests and 84 PTY scenarios; zero analyzer findings. No Gerber production/test changes were needed.
- G-4A9 is implemented locally, including combined selection, visible Core
  dependencies, best-effort installation and fresh-process activation. The
  final local quality loop passed: 1,952 unit tests, 21 integration tests and
  all 92 PTY scenarios; zero analyzer findings. The new PMU target-inspection
  API is unpublished; G-4A7R and hosted/dependency delivery remain separate
  open work.

## Vision
Free, proprietary, cross-platform, agent-first PowerShell DevOps product. Standalone Core; independent plugins; private source and eventual PowerShell Gallery distribution; documentation planned for Gerber.ps. Pre-1.0 breaking changes allowed, without legacy migrations.

## Original product phases (high-level)
| Phase | Original scope | Status |
|---|---|---|
| G-1 | Generic config, PAT, lazy ADO | In progress / parts delivered; inspect |
| G-2 | GitHub Actions, release, PowerShell Gallery | Not verified |
| G-3 | `/update` and self-update | Core implemented in G-4A7; plugins implemented locally in G-4A9; quality readiness below |
| G-4 | `/plugins create` and working scaffolding | G-3D1 + G-3D1-FIX1 implemented; see detailed validation evidence |
| G-5 | Agent-first plugin development (AGENTS.md, skills) | G-3E1 implemented with generated-project validation |
| G-6 | Plugin installation, discovery, private distribution | Partly foundational; management incomplete |
| G-7 | Documentation, Gerber.ps, public launch | Planned |

The original plan explicitly allowed reordering and prioritized plugin creation and agent-first experience.

## Detailed G-1A implementation plan (historical IDs retained)
| ID | Original objective | Current evidence / status |
|---|---|---|
| G-1A | Read-only three-repository architecture analysis | Complete; `G-1A.md`, `G-1A_response.md` |
| G-1B | Runtime dependencies and manifest metadata | Both NovaModuleTools and PSModuleUpdate remain `RequiredModules` (D-002 amendment, D-017). Disposable build/import qualification passed on macOS/PowerShell 7.4.21 and 7.6.6 ([G-4A6](docs/architecture/G-4A6-runtime-dependency-qualification.md)); authorized G-4A7 Nova builds refresh the ignored local manifest |
| G-1C | Local analyzer/quality tooling | Analyzer zero findings reported; task status verify |
| G-1D | Test/publish workflows | Verify |
| G-2A | Persistent user configuration | Worked on; verify exact acceptance criteria |
| G-2B | Generic ADO profile resolution / remove organization defaults | Worked on; verify exact acceptance criteria |
| G-2C | Pure ADO URL parser | Verify |
| G-2D | Credential resolver | Original vault/env design **superseded** by Devlooped abstraction; verify current implementation |
| G-2E | Lazy ADO setup and safe command resume | Verify |
| G-2F | Named connections in Plugin API | Verify |
| G-3A | Plugin GUID identity and isolation | G-3A1 persistent approval implemented; G-3A2 persistent association and enabled/disabled lifecycle implemented; management commands remain planned |
| G-3B | Namespace aliases and conflict resolution | Planned |
| G-3C | `/plugins` overview plus `list/info/enable/disable` | Overview/list/info and enable/disable implemented; separate approve is unnecessary because enable handles declined plugins; remove/decline/revoke are not Core 1 scope |
| G-3D | Transactional `/plugins create` | G-3D1 + FIX1: explained/spaced fields, visible cwd/child defaults, completion metadata; cached pre-install name/version, canonical manifest GUID and complete Unreleased changelog; staged validation/autoapproval preserved |
| G-3E | Generated agent resources | G-3E1: canonical self-contained AGENTS.md, thin Claude/Copilot bridges, three scoped instruction files, plugin developer role and three actionable skills; generated project builds/tests/publishes locally in isolation |
| G-3F | Plugin boundary guardrails | G-3F1 implemented: standalone installed-source AST validation, transactional generation gate and generated development workflow; CodeScene review/safeguard availability remains a separate verification gate. Gerber.ExampleOrg unchanged. |
| G-4A | `/update` and update architecture | Architecture decided ([G-4A5](docs/architecture/G-4A5-update-architecture.md), D-017). Core integration implemented in G-4A7; plugin integration implemented locally in G-4A9; see sub-rows |
| G-4A0–G-4A2 | Update analysis, PMU design, PSResourceGet qualification | Complete as historical analysis; conflicting recommendations superseded by G-4A5 |
| G-4A3 | PSModuleUpdate engine (sibling repository) | Closed 2026-10-23 within its qualified scope (PMU repository evidence) |
| G-4A4 | PMU cross-platform CI | Passed for PMU only (the historical CI run (private evidence)); not Gerber integration |
| G-4A5 | Runtime dependency contract and Gerber Core update integration | Architecture corrected 2026-10-24: both NovaModuleTools and PMU required, with distinct creation/build/publication versus update roles. Core implementation follows in G-4A7; remaining policy questions in G-4A5 section 14 |
| G-4A6 | Runtime dependency and generated manifest qualification | [Historical report](docs/architecture/G-4A6-runtime-dependency-qualification.md): exact Nova 3.4.2 builds both requirements; PMU 0.1.0-preview imports offline under numeric 0.1.0 on macOS/PowerShell 7.4.21 and 7.6.6. Missing/old dependencies rejected. G-4A7 refreshes the original ignored artifact; wider qualification remains |
| G-4A7 | Gerber Core update integration | Core startup notification and fresh `/update` discovery/confirmed PMU installation implemented; [configuration/limits](docs/core-updates.md). Full unit run: 1,674 passed, two unchanged baseline failures (analyzer/`project.json` EOF), 96.25% coverage; integration: 11 passed, two existing opt-in skips; final full PTY run: all 75 scenarios passed. Earlier transient process-start timeouts passed unchanged on isolated reruns. CodeScene: 43 scorable files at 10.0, safeguard passed. Quality readiness was blocked at the G-4A7 handoff by the analyzer/EOF baseline; G-4A8 resolves that baseline below. Live-provider and Gerber Windows/Linux qualification remain unverified |
| G-4A8 | Resolve remaining quality gate failures | Complete: sole owner-approved `PSAvoidUsingWriteHost` exclusion, two named-parameter CI path fixes and newline-only `project.json` correction. Unit: 1,679 passed, zero failed; integration: 11 passed, two existing opt-in skips; full PTY: 75 passed with zero coverage issues. Analyzer: zero findings across 518 files. `run.ps1` passed the complete pipeline with 95.92% coverage against 90%; standalone unit coverage was 96.25%. All four changed PowerShell files remain Code Health 10.0; safeguard passed. Core update behavior and required dependencies unchanged |
| G-4A7R | Correct Core update distribution and ordering | Implemented, closure incomplete; status reviewed 2026-10-30. Permanent application-owned PSGallery binding, CurrentUser scope, Stable default with persisted prerelease opt-in, obsolete Core binding ignored and `/update` fourth after `/exit`, `/help`, `/plugins`. Equal installed/available versions retain PMU's target and UpToDate without an install offer. Published PMU 0.2.0 satisfies the current numeric 0.2.0 minimum; the old unpublished-dependency blocker is resolved. Live happy-path installation is user-confirmed. Upstream PackageNotFound classification is corrected locally, not published or deployed. Remaining: corrected-dependency delivery and broader live-update/recovery qualification; see closure evidence below. No automatic local migration/cleanup |
| G-4A9 | Plugin update integration in `/update`: overview, per-plugin selection, repository association, activation qualification | Implemented and locally qualified, reviewed 2026-10-31. Eligible installed plugins use current on-disk `PrivateData.Gerber.RepositoryUri` metadata, shared channel, exact PMU plans, selected-package inspection and combined confirmation with visible required Core. Sequential best-effort installation and separate activation outcomes; no first install/hot reload/batch rollback. Real isolated installation/activation and the final full quality loop passed: 1,952 unit tests, 21 integration tests, two existing opt-in skips and all 92 PTYs. PMU API delivery and hosted/live qualification remain open. Fixed Core PSGallery binding and G-4A7R closure requirements are unchanged |
| G-4B | Versioned documentation | Planned |
| G-4C | 1.0.0 readiness | Planned |

## G-4A7R closure evidence and remaining work

Status reviewed 2026-10-30. Hosted evidence below is for revision `d599443`; current local consumer verification uses Gerber `4e600ac` and the corrected, uncommitted PMU worktree based on `9330a8b`. Earlier G-4A7/G-4A8 rows preserve their historical handoff evidence; the following supersedes their outstanding dependency/live-update claims only within the stated scope.

| Area | Status and evidence |
|---|---|
| Dependency delivery | Passed: PSGallery lists PMU 0.2.0, its package was inspected read-only, and current-revision CI installed it from PSGallery. `project.json` requires numeric 0.2.0. No new bootstrap/publication is needed to resolve the historical missing-artifact blocker |
| Hosted unit/integration checks | Passed: [Run Tests, attempt 1](https://github.com/stiwicourage/GerberCore/actions/runs/40851789440), 2026-10-29, revision `d599443`: 1,858 unit passes, 17 integration passes, two native-credential opt-in skips and 96.54% coverage against 95%. This is not a fresh local full-quality/PTY run |
| Native credential platforms | Passed for credentials only: [platform matrix, attempt 1](https://github.com/stiwicourage/GerberCore/actions/runs/40847421840), 2026-10-29, revision `d599443`: Windows/X64, Linux/X64 and macOS/ARM64 each passed both selected credential scenarios using Gallery PMU 0.2.0. These jobs do not exercise live Core installation or recovery |
| Live Core happy path | User-reported verification, 2026-10-27: `/update list` installed `0.2.0` to `0.2.1-preview` with `Verification: Verified` and `Recovery: NotRequired`; a subsequent check returned `RestartRequired`. This is not a newly executed qualification of revision `d599443` or every platform/channel/recovery path |
| No-package classification | Corrected locally in PMU, uncommitted on `9330a8b`: exact case-sensitive base `PackageNotFound`, including command suffixes, becomes safe terminating `PMU.PackageNotFound`; unrelated IDs and generic error handling remain unchanged. Six regression cases failed with `PMU.DiscoveryFailed` before the fix; all 14 focused cases passed afterward. Public planning returns no plan, and a disappeared exact installation target still fails without substitution. Full PMU `run.ps1` passed: 868 unit passes, one Windows-only skip; six integration passes, three opt-in live-feed skips; 98.09% coverage; zero analyzer findings. All five touched supported files measured 10.0; safeguard passed. Published 0.2.0 still has the defect; no version/dependency changes, publication or installation occurred |
| Classification prerequisite cleanup | Separately committed by the user as PMU `9330a8b`: behavior-preserving request-parameter extraction reduced `Find-ProviderResource` from 19 to 12 whole-declaration lines; new helper has 15. Characterization passed before/after. PMU `run.ps1` passed on macOS ARM64/PowerShell 7.6.9: 854 unit passes, one Windows-only skip; six integration passes, three opt-in live-feed skips; 98.09% coverage; zero analyzer findings. Four supported files measured 10.0 and the cleanup safeguard passed. Includes only a newline repair to the changelog; PowerShell 7.4 and hosted lanes remain unverified |
| Local Gerber consumer verification | Passed on macOS ARM64/PowerShell 7.6.9: full `run.ps1` against corrected PMU 0.2.1 from sibling `dist` via process-local `PSModulePath`, with parent/child import-path witnesses. 1,858 unit passes; 17 integration passes, two native-credential opt-in skips; 96.53% coverage against 95%; zero analyzer findings across 545 files; all 84 PTY scenarios passed, with zero Core/fixture coverage issues. Existing assertions prove `NoMatchingPackage`, null plan, no confirmation/installation and unrelated failures remaining `Unavailable`; no Gerber code/tests changed. The first attempt stopped on an analyzer null-reference before tests; the diagnostic wrapper and subsequent full loop passed unchanged. Cause unconfirmed; failed attempt retained. This is local consumer verification, not hosted or live-install qualification |
| Remaining qualification | Unverified: live Core update on Windows/Linux and complete failure/recovery flows through Gerber. Define the bounded acceptance scope and retain platform/channel evidence before claiming broader completion. A passing credential matrix or PMU-only qualification is not a substitute |
| Documentation follow-up | Current dependency availability and dated qualification evidence reconciled in `README.md`, `CONTRIBUTING.md`, `docs/core-updates.md` and applicable unreleased release text. PMU documents the corrected error contract in command help and Unreleased Fixed text. Historical release entries are preserved; the local correction is not publication or deployment |

The bounded PMU correction and Gerber consumer verification were authorized separately. Publication, installed-module repair, live installation, dependency-minimum changes, commits and pushes remain outside this task.

## G-4A9 local implementation and qualification

Reviewed 2026-10-31 on macOS ARM64/PowerShell 7.6.9 against the built sibling PMU through process-local `PSModulePath`. Both worktrees remain uncommitted. The following is local evidence, not release or hosted qualification.

| Gate | Status and evidence |
|---|---|
| PMU implementation | Passed locally: generic `Get-PSModuleUpdateTargetManifest` inspects the exact live plan without installation/import and binds manifest bytes to staging before mutation. Gerber passes the repository URI; PMU does not interpret Gerber plugin metadata. PMU `& ./run.ps1`: 919 unit passes, one baseline skip; eight integration passes, three existing opt-in skips; 97.18% coverage; zero analyzer findings |
| Real cross-module update | Passed: an owned native feed exercised actual built PMU/Core discovery, inspection, installation and fresh-process activation. Exact `2.0.0-preview2`, CurrentUser scope and original live-plan identity were preserved; installation and activation were Verified without parent-process plugin import. Private repository records and store bytes were unchanged. Disposable package roots were cleaned; recorded evidence remains in the task session |
| Current Gerber quality loop | Passed: final serial `& ./run.ps1` reported zero analyzer findings across 602 files, 1,952 unit passes and 96.15% coverage against 95%; integration had 21 passes, zero failures and two existing native-credential opt-in skips. The same wrapper then passed all 92 PTY scenarios and 23 harness self-tests |
| Current terminal qualification | Passed: final full run `20261031T052316.674579Z-pid37362-all-9220975a` executed all 92 scenarios, including eight new batch cases. Core and fixture inventories both had zero uncovered commands/coverage issues. The preceding `& ./scripts/build/Invoke-TerminalRegressionCI.ps1 -KeepSuccessArtifacts` run retains reviewed happy-path, default-Cancel/Esc and partial-failure traces; the focused plugin-create reproduction also passed with retained artifacts |
| Maintainability and help | Passed locally: all 69 scorable Gerber files and 58 supported PMU files measured Code Health 10.0; five comment-only Gerber mirrors have no executable code to score. Gerber safeguard checked all 74 eligible files and passed. All 184 modified PowerShell declarations meet the whole-declaration 15-line/four-parameter/four-branch limits; 26 owned Python declarations meet the limits including decorators. Unchanged catalog declarations were not rewritten. Generated command-help and affected user/contributor docs were updated and validated |
| Delivery/platform qualification | Unverified: PMU's six hosted lanes, Gerber hosted checks for the actual revision and live private-feed authentication. The new PMU API is not published through clean-runner provisioning. Gerber's existing numeric PMU minimum remains 0.2.0; no publication, global installation, dependency-minimum change, commit or push occurred |

Earlier failing attempts remain recorded. Profiling separated dependency import cost (about 1,053 ms for Nova) from Core import (about 127 ms). The policy integration now isolates unused Nova APIs with a manifest-only fixture while retaining built Core, its existing PMU stub, every original scenario/input/assertion and the 2,000 ms production contract. All five focused cases passed. Tests requiring actual dependency imports and the real cross-module update retain the real modules; this is fixture isolation, not a production startup-speed claim.

A subsequent full PTY attempt exposed input backlog in the existing plugin-create reproduction: its 152-character destination was still being typed when the unchanged screen-stability deadline expired. The test helper now drains identical input in small batches before pressing Enter. Workflow inputs, scenario metadata, generated destination and assertions remain unchanged; the permanent focused reproduction and final full suite passed. No timeout, assertion, source binding or safety guard was relaxed.

Local implementation work is complete. Resume separately authorized PMU API delivery and actual-revision hosted qualification before release readiness or broader closure. The dependency minimum remains unchanged until clean-runner provisioning can obtain the required artifact; G-4A7R closure is not implied.

## Completed separate quality stream
- G-PTY1: permanent terminal regression framework — reported complete.
- G-PTY2: interactive CLI fixes, command inventory and coverage — reported complete.
- G-PTY3: Core-only terminal coverage and removal of Gerber.ExampleOrg-specific tests — stopped and accepted with known `/repository create` full-provisioning PTY gap; user manually verified actual repository creation.
- G-UX1: double Escape to root — implemented centrally across the shared Gerber terminal prompt/menu infrastructure with focused Pester and PTY coverage.
- G-UX1-FIX1: shared plugin menu navigation regression — `/plugins` now uses the same shared submenu navigation contract as other Core command groups, so single `Esc` returns to the immediate parent menu while the existing double-Escape-to-root behavior remains intact.
- **Do not reopen PTY work solely to eliminate this accepted gap.**

## Bounded task status (G-3D1-FIX1 + G-3E1)
1. **G-PLAN:** save and review these documents; verify existing code vs decisions. Read-only review first; no builds/tests needed.
2. **G-3C4:** no separate approve command; `/plugins enable` already explicitly approves declined plugins.
3. **G-3D1:** implementation delivered; Gerber owns the plugin-specific templates and Nova owns lifecycle. Generated examples and tests belong here, not G-3E1.
4. **G-3D1-FIX1 + G-3E1:** implemented together; focused behavior, generated-project local publication/fresh-host hello and PTY trace validation precede the final full quality loop. Evidence and runtime limitations belong in the task handoff, not inferred from roadmap status.
5. **G-3F1:** development-time Plugin API v1 boundary checks are implemented, not a PowerShell sandbox. `Test-GerberPluginBoundary` works on an uninstalled project using installed Core; generator checks before executing Nova or plugin code. Generated script/agent guidance uses this command, then standard Nova validation. Runtime approval, discovery, inventory, registration and execution semantics remain unchanged. See the task verification artifact/handoff for executed gates and unavailable CodeScene review evidence.

## Agent work constraints
- One bounded objective per Copilot task; avoid multi-hour autonomous iterations and repeated full-suite runs.
- No automatic work on Gerber.ExampleOrg or NovaModuleTools unless explicitly authorized.
- No commits, pushes, publishing, live destructive ADO operations, or actual Keychain changes without explicit authorization.
- New problems: document and stop rather than expand scope.
- Report files changed, tests actually run, limits, unresolved issues and exact stop reason.

## Next review checklist
- Deliver the locally corrected PMU through a separately authorized release/dependency task and complete the remaining G-4A7R live-update qualification before treating Core integration as fully qualified; G-4A9 remains a separate task.
- Compare `PLAN.md`, `ARCHITECTURE.md`, `DECISIONS.md` to source and existing project documentation.
- Confirm G-2A/G-2B and credential abstraction current state.
- Verify G-3A1/G-3A2 against the current loader and persistent configuration tests before adding `/plugins` management commands.
- Agree the **revoked-but-still-usable** warning and user override semantics before coding.
