# Changelog

All notable changes to this project will be documented in this file and **UNRELEASED** changes will be included in the next **stable** release!

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added G-4A9 installed-plugin update selection to `/update list`, using the
  existing shared channel and per-plugin `PrivateData.Gerber.Repository`
  descriptors (`Name` for display, canonical `Uri` for PMU). Names survive
  unavailable/no-matching-package lookup results. Absent metadata defaults to
  PSGallery and its official URI; invalid declarations never fall back.
  Legacy `RepositoryUri` remains supported, mapping the official Gallery URL
  to PSGallery and retaining custom raw URL display until a name is added.
  Canonical metadata wins when both keys exist. Current installed manifests
  remain authoritative over cached module metadata; trust prompts retain URLs.
  Only installed, associated, approved, enabled plugins participate; startup
  remains Core-only. Shared checkbox selection, separately confirmed
  trust/license-gated package inspection and a default-Cancel combined install
  preview show versions, source, scope and visibly auto-added required Core.
  Core and plugins share one aligned overview table, including in the selection
  screen, with a blank line before the shared channel and no per-plugin
  information footer. No available updates return through the continue prompt
  without a chooser or misleading cancellation message.
  PMU installs the original plans sequentially, Core first; dependency failures
  block dependent items while independent updates continue, and cancellation
  stops future attempts. Results separate installation, verification, recovery
  and fresh-process activation, retaining Installed when activation fails.
  Credentials are operation-only; no first install, hot reload or batch rollback.
  Added mirrored UI tests, disposable PTY regression fixtures and affected help.
  The new PMU target-manifest inspection API remains locally implemented,
  unpublished and undeployed; numeric minimum stays 0.2.0. No hosted/live
  qualification implied.
- Added repository selection to `/plugins create`. PSGallery is preselected and
  generates an explicit `Manifest.PrivateData.Gerber.Repository` object with
  `Name = PSGallery` and its official `Uri`, without additional questions.
  Another repository asks for a name followed by a safe absolute URL, or writes
  `REPLACE_WITH_REPOSITORY_URI` in `Repository.Uri` when unknown. Requests,
  results, generated JSON and manifests retain the canonical descriptor.
  The completion summary shows name and URI plus placeholder replacement
  guidance. Blank names and unsafe URLs can be corrected locally; Esc at the
  chooser, name or URI cancels without generation.
  An unreplaced placeholder remains invalid for updates without Gallery fallback.

### Changed

- Core update completion now offers **Exit Gerber** or **Continue with current
  version** after verified success requiring restart, or discovery of an
  already-installed newer Core. Continue is the default and Esc also continues.
  Restart guidance remains visible; exiting Gerber does not restart PowerShell.
  Restart PowerShell, then run `gerber`; Core/plugins are not hot reloaded.

### Deprecated

### Removed

### Added

### Fixed

- Plugin discovery now skips unreadable module-search roots instead of
  terminating the plugin inventory or `/update list` with a permission error.
  Accessible plugins and Core update checks remain available; filesystem
  permissions and configured module paths are unchanged.
- Corrected Core update documentation to match the declared PSModuleUpdate
  0.2.0 minimum and its Gallery availability. Recorded user-confirmed live
  installation separately from the locally corrected, unpublished provider
  error classification and outstanding platform/recovery qualification; no
  Gerber dependency or runtime behavior changes are included in this
  documentation correction.

### Security

## [0.2.0] - 2026-10-27

### Added

- Added `/update policy` with persistent **Stable only** (default) and
  **Include prereleases** channels in optional `coreUpdates.channel` user
  configuration. Startup and manual discovery share the validated PMU policy;
  installation rejects plans from a changed channel while retaining the fixed
  PSGallery endpoint, CurrentUser scope and default-Cancel confirmation.
  Selection performs no discovery or installation, preserves unrelated settings
  and ignored legacy bindings, and clears stale startup notifications.
  `/update` now opens the shared **list**/**policy** submenu; `/update list`
  performs the fresh check and returns to that chooser after results.
  Continuing after a policy selection also returns to `/update`, with
  `/update list` highlighted, instead of reopening the policy chooser.

### Changed

- Raised the minimum PSModuleUpdate dependency from numeric `0.1.0` to `0.1.1`
  for upstream mixed-layout installed-copy discovery, without changing Gerber's
  version or its PMU-owned update decisions. Added built-module and terminal
  contracts preserving Available `0.1.0` / `UpToDate` when installed equals
  available, with no installation offer. `/update` does not bootstrap PMU;
  dependency installation remains a separate approved action.
  No automatic local Gerber migration or cleanup is performed. The separate
  upstream `PackageNotFound` issue and complete live-install qualification remain.

### Fixed

- Core update discovery now maps structured `PMU.UnsupportedInstallation` to
  supported numeric-version module directory and restart guidance, rather than
  blaming PSGallery registration/connectivity. It neither parses provider text
  nor assumes every unsupported installation is flat-only, and claims no
  installation or rollback success. Flat-only migration remains unsupported;
  existing installed Gerber copies need a separate update for the diagnostic.
- A Core installation missing native provider metadata now gets explicit
  locally-copied/published diagnosis and PSGallery reinstall guidance instead of
  incorrect numeric-directory guidance. Other unsupported layouts keep the
  generic safe message; provider secrets remain hidden.

## [0.1.0] - 2026-10-25

### Added

- Added Gerber Core update management through `/update`: fresh PSModuleUpdate
  discovery, compact version/repository overview, default-cancel installation
  confirmation and verification/recovery/restart guidance. Startup checks are
  bounded and notification-only. Core is permanently bound to PSGallery and its
  official endpoint, with explicit PMU Stable/CurrentUser policy, no configuration,
  environment or plugin override and no fallback. Obsolete Core update settings
  are ignored without rewriting unrelated configuration. Structured PMU
  no-matching/eligible-package outcomes (Core is not published yet) are
  distinguished from repository
  failure; Core never reports Unconfigured or requests credentials.
  PMU handles installed previews and stable promotion without custom comparisons.
  Plugin updates and their independent repository bindings remain G-4A9.

- Added **G-3F1 — development-time Plugin API v1 boundary guardrails**.
  - Exported `Test-GerberPluginBoundary -Path <project>` validates uninstalled
    authored PowerShell without starting Gerber, invoking plugin code, requiring
    Nova lifecycle operations or a private Core checkout, or reading/writing user
    settings. This functional independence does not waive Gerber's required modules.
  - Derives private function ownership from actual installed module definitions
    and exports, and public capabilities/equivalents from existing API v1
    scriptblocks rather than maintaining a duplicate API list or prefix ban.
  - AST checks known private direct/literal dynamic calls and lookups, explicit
    implementation imports, and identifiable Core module-scope/session-state
    access; respects plugin/local function ownership, comments and ordinary
    strings. Returns deterministic actionable source diagnostics and public API
    operation inventory; documents conservative dynamic-analysis limits.
  - Checks staged generation before Nova execution, finalization and approval,
    preserving cleanup and GUID lifecycle semantics. Generated validation script,
    README, canonical agent guide, developer role, instructions and skills put
    boundary validation before the normal Nova flow and request missing public
    capabilities instead of importing private Core.
  - Adds public PlatyPS help, source-mirrored and installed-module tests,
    transactional invalid-source cleanup and isolated generated-project coverage.
    This is not a PowerShell sandbox or a runtime discovery/permission change.

- Added **G-3D1 / G-3D1-FIX1 — transactional `/plugins create` and G-3E1 agent-first scaffolding** using Core's existing registry, plugin menu and shared inputs.
  - Presents an introduction and separated explained fields for a suffix behind an immutable `Gerber.` prefix, description, unused namespace and destination parent, with dynamic cwd/child defaults and an actual metadata/state/next-steps summary; never overwrites the child or claims installation.
  - Gerber-owned templates generate a complete Plugin API v1 project with one canonical manifest GUID, functional namespaced hello, unit/public API integration tests and Nova lifecycle documentation. Nova generates the manifest and module root; `PrivateData.Gerber` no longer duplicates the GUID.
  - Generated name/initial version persist as optional GUID-keyed association display metadata before installation; installed manifest metadata wins and list/info remain read-only. Old metadata-free associations retain the GUID fallback.
  - Generates the requested full six-category Unreleased changelog and canonical AGENTS.md, thin Claude/Copilot bridges, scoped instructions, a plugin developer role and three actionable command/API/Nova workflow skills without private Core dependencies.
  - Stages generation, runs Nova build/unit/integration checks and isolated Core registry registration, then finalizes and explicitly approves, associates and enables that same GUID. Creation does not install/load the module.
  - Cleans only owned staging data on validation failure; preserves the recoverable final project with an exact partial-state error if configuration persistence fails.
  - Retains an invocation-time Nova availability check and installation with explicit consent when missing; this handler safeguard does not make Nova optional at Gerber import. Adds isolated local-publish/fresh-start discovery and focused PTY cancellation/recovery/trace coverage without changing enable/disable semantics.

- Added **G-3C2 — `/plugins enable` and `/plugins disable`**.
  - `/plugins enable` lists installed plugins that are not active (declined, pending or approved-but-disabled), treats the selection as explicit approval, persists it in the existing plugin lifecycle state, and registers the plugin's commands immediately.
  - `/plugins disable` lists active plugins, persists the disabled state while preserving approval, and removes the plugin's commands immediately; the PowerShell module is not uninstalled.
  - Both actions update menus, completion, and command dispatch without restarting Gerber, and their persisted state survives restarts. Enabling an already-active plugin does not repeat import, initialization, or persistence.
  - Registration rejects cross-plugin parent references and conflicting active module names while preserving valid nested commands and contributions beneath shared Core parents.
  - Registry changes are staged independently of the live command tree. Failed registration or disable operations restore the previous registry and lifecycle configuration where possible, with explicit diagnostics if rollback also fails.

- Added **G-UI2 — prioritized root command ordering**: `/exit`, `/help`, `/plugins` and `/update` always come first in that order, followed by all other root commands (Core and plugin) alphabetically. Submenu ordering is unchanged.

- Added **G-UX1 — Double Escape to Root** across Gerber's shared terminal navigation.
  - A single `Esc` still goes back one menu level at a time.
  - A second `Esc` within 200 milliseconds now returns directly to the Gerber root prompt from shared prompts, menus, continue screens, and plugin-driven terminal flows that use the shared Core prompt infrastructure.
  - The double-Escape state is tracked centrally with monotonic elapsed-time checks, survives ordinary screen transitions, reuses the existing visible-root prompt request path, and clears pending input safely so rapid Escape input does not execute stale commands.

- Added persistent GUID-based plugin approval plus plugin lifecycle state before plugin import or execution.
  - Reads candidate module manifests without executing plugin code and rejects malformed or invalid-GUID candidates with controlled diagnostics.
  - Stores normalized approved GUIDs under `plugins.approved`, normalized declined GUIDs under `plugins.declined`, and associated plugin records under `plugins.associated.<guid>.enabled` in the existing atomic user configuration, preserving unrelated settings and approval across ordinary plugin updates.
  - Newly approved plugins are immediately associated and enabled without a second prompt, while previously approved plugins without an explicit association record stay usable and acquire lifecycle state lazily on rediscovery.
  - Declined plugins now persist that decision too, so Gerber skips the same unknown plugin on later startups instead of prompting again every time.
  - Uses Gerber's existing confirmation UI with decline as the default; declined or noninteractively discovered unknown plugins are skipped without blocking Core startup.
  - Prevents disabled associated plugins from importing, executing `Get-GerberPlugin`, or registering slash commands, while preserving their approval and association records across restarts and temporary module absence.
  - Treats GUID approval as identity and user intent, not as cryptographic proof of publisher or code authenticity.

- Added the first read-only plugin management commands in Gerber Core.
  - `/plugins` now shows one overview of all plugin identities known to Gerber, including approved, declined, disabled, unknown, loaded, and missing entries.
  - `/plugins list` now merges discovered manifest metadata, persisted approval/decline decisions, persisted association state, and current-session loaded state by manifest GUID without duplicate rows.
  - `/plugins info <plugin>` now supports lookup by manifest GUID or unique module name and reports controlled errors for malformed GUIDs, unknown plugins, and ambiguous names.
  - Declined plugins remain visible and inspectable even when they were never associated or are no longer currently discovered.
  - Read-only inspection does not trigger approval prompts, import unknown/declined/disabled plugin code, or modify `config.json`.

- Added registry-derived interactive command inventory and PTY coverage enforcement for Gerber Core,
  with separate discovery, dispatch, workflow, navigation, rendering, and error/recovery categories.
  The bundled `Gerber.TerminalFixture` now has a separate generic Plugin API contract inventory and
  coverage report, while product plugins own their product-specific terminal regressions.

- Added lazy first-use Azure DevOps connection setup in Gerber Core so authenticated ADO commands can configure a missing named profile or missing PAT inline, continue the original command after successful setup, and keep startup plus unrelated commands free of Azure DevOps prompts.
  - Uses the existing `ado.defaultProfile` / `ado.profiles` configuration model and the native credential identifier format `gerber:ado:<profile>:pat`; no environment-variable fallback, duplicate config store, or alternate credential provider was reintroduced.
  - Reuses the existing Azure DevOps Services and Server URL parser, including the explicit Server-root prompt when a self-hosted URL needs that extra context, while preserving the existing insecure-HTTP validation rules.
  - Handles profile selection consistently: uses the default when configured, offers the only existing profile when no default exists, lets the user choose among multiple profiles, and offers to configure an explicitly requested missing profile instead of silently substituting another one.
  - Prompts for a PAT only when the current operation requires authentication, stores that PAT through the native credential service with non-echoing input, asks before overwriting an existing PAT, and leaves unrelated profile metadata untouched when only the PAT is missing.
  - Stops cleanly on decline or cancel, fails clearly without prompting in non-interactive execution, reports partial configuration-versus-credential failures explicitly, and now distinguishes rejected PATs from insufficient PAT permissions in Azure DevOps request failures.
- Interactive `/repository create nuget` command for creating NuGet package repositories from Template_NuGet template
  - Prompts for project first, then fetches and shows only templates found in the selected project
  - Shows preview of all planned mutations before confirmation
  - Creates repository with all files from template
  - Replaces PackageName in paths, folder names, and file content
  - Creates pipelines from all YAML files in pipelines/ folder
  - Dynamically copies all branches from the template; the initial commit targets the template's default branch, all other template branches are created pointing to that default-branch commit, and the new repository's default branch is explicitly set to match the template instead of hardcoding `main`, `develop`, and `release`
  - Copies all branch policies from template to new repository
  - Links build validation policies to new pipelines by matching YAML path
  - Creates auto-include reviewer policy with chosen team
  - Continues past partial failures and reports them in summary
  - Returns to package name prompt after `Press Enter to continue`
  - Supports Esc navigation to return to previous menu at any prompt
  - Shows all known templates (Template_NuGet via `nuget`, Template_Domain via `domain`, Template_CDM via `cdm`) in the template chooser and as autocomplete suggestions; only Template_NuGet is currently implemented — selecting an unimplemented template shows a "not yet implemented" message
- Added `/branch set-default` so users can enter a branch name, preview which repositories would be updated, which are already on target, and which do not contain the branch; apply the default-branch change after one confirmation step; see per-item progress and a final `Updated N  Already on target N  Not found (skipped) N  Failed N` summary; `Esc` at the branch-name prompt returns to the `/branch` chooser; `Esc` at Confirm returns to the branch-name prompt; `Press Enter to continue` after the summary returns to the branch-name prompt; repositories where the target branch does not exist are shown in the preview and skipped silently during apply; repository-level failures do not abort the whole run.
- Added `/branch set-searchable` so users can enter one or more comma-separated branch names, choose between Replace and Merge mode, preview the planned policy changes across all Azure DevOps repositories, apply the changes after confirmation, and review a created/updated/unchanged/failed summary; `Esc` exits cleanly at the branch-name prompt and at the continue screen, and `Esc` at the mode chooser returns to the branch-name prompt; the preview now caps each group at 8 repositories with an `... and N more` line to prevent terminal overflow, and the apply step opens on a clean screen so the progress bar and result summary are always fully visible; repositories whose existing policy has a missing or null `searchBranches` field are treated as having an empty branch list so the scan never fails on malformed or partially created policies; single-branch scope results are always captured as arrays so the scan never triggers a strict-mode property-not-found error on `.Count` when only one branch is in scope; repositories whose requested branches are already searchable through the ADO default branch are correctly classified as `Already aligned` without creating a redundant policy entry; disabled repositories are excluded from the scan so apply never attempts unreachable API writes; the `Already aligned` group in the preview now lists repository names the same way `To create` and `To update` do.
- Added `/branch find` to the interactive Gerber command palette so users can search all Azure DevOps repositories in the configured project for a given branch path, see per-repo progress while the scan runs, and review a matched-repo list with a found-count summary or a neutral completion message when nothing matches; repositories that cannot be checked are collected into a warning summary shown after the results.
- Added `/pipelines release common-data-model` so users can load a Confluence release page, choose branch and environment, review every planned CDM wave in one checkbox-style selection screen, confirm exactly which pipelines stay selected versus skipped, start only the selected pipelines on explicit apply, update the matching Confluence release row when the page exposes the selected environment column, write new run URLs back to `Pipeline til PROD` only when the selected environment is `Prod`, and otherwise leave Confluence unchanged when no matching environment column exists on the page.
  - `Solr Core` now starts with queue-time template parameters derived from the selected release context: `environmentName` uses the chosen environment, `WorkingDirectory`, `SolrUrl`, and `SolrServiceName` come from the per-environment pipeline settings in `src/resources/Properties.json`, `SolrVersion`, `JreVersion`, `JrePackageVersion`, `JreDownloadUrl`, and `SolrPort` come from the shared Solr pipeline settings, and `Cores` is built from the linked release task's `Step by step guide` field by matching the configured `solrCores` values in `src/resources/Properties.json`.
  - When Gerber cannot verify that a Confluence pipeline label matches the Azure DevOps pipeline name, it now shows the mismatch and lets the user approve or cancel instead of forcing an immediate page edit, with `Cancel` as the default confirmation choice.
  - Shared release-planning contract handling now normalizes missing pending approval lists before Common Data Model branch/environment reconciliation, so the flow no longer stops after environment selection with a missing `PendingApprovalList` property error.
  - Re-running the flow now reconciles all active runs on the same definition and branch before it starts anything: Gerber cancels same-branch runs that are waiting in other environments after removing all tags from them, carries those tags forward onto the newly started replacement run when they are not already present there, replaces exactly one older unfinished run in the selected environment automatically, and when more than one active run matches the same definition, branch, and selected environment it now shows those runs in a checkbox-driven stale-run cleanup step so the user can choose which runs to cancel before Gerber retries the release flow.
  - Apply now monitors the selected Common Data Model waves in order: Gerber starts the selected pipelines in the earliest selected wave, waits for that wave to finish, then continues through the later selected waves; the new checkbox selector blocks Enter when nothing is selected, ignores `Tab` safely, re-checks dependencies before apply so a selected later-wave pipeline cannot continue when it depends on a deselected earlier-wave pipeline, keeps the focused row highlighted with the same selected-row background treatment as the other Gerber menus, uses `[✔]` for selected entries, omits the extra activity sub-line, keeps the confirmation summary grouped in wave order, no longer fails when a later-wave pipeline such as `Solr Core` is the only deselected item, now ignores stray non-result output from the apply invocation so the flow does not stop after a completed run with a missing `RestartRequested` property error, updates the selected environment checkbox/task cell on the Confluence release row when that column exists, reports the result as a general release-page update instead of only `Pipeline til PROD`, and marks each started run's linked Azure DevOps release task environment as completed even when the selected environment is not `Prod`.
  - `Solr Core` is now always forced into the final dependency wave and started last in that wave so its approval step cannot block earlier wave progression.
- Added `/pipelines release approve-environment` so users can load the same Confluence release context, choose branch plus environment, review a dry-run of pending Azure DevOps environment approvals, and only mutate on explicit apply.
  - The flow parses both `CDM Pakker` and `Installation`, splits rows with multiple build links into one approve-item per link, only treats approvals for the selected environment as apply candidates, resolves the waiting environment from approval-aware Azure DevOps timeline metadata for both stage-based deployments and deployment-job flows such as `Solr Core`, and shows dry-run warnings grouped as `Common Data Model` and `Applications`, including the actual waiting environment when a pending approval belongs to a different environment.
  - Approval-stage / environment detection is now shared with the other release flows, including the timeline-backed fallback that keeps classifying a still-pending run when the Azure DevOps approvals API omits that pending approval.
  - The dry-run now opens in a checkbox-style approval selector with every pending approval preselected, so users can approve one, many, or all matching runs; the confirm screen shows the selected approvals and skipped approvals before apply, while apply still keeps Confluence row completion scoped to the full original row.
  - Before apply approves anything, Gerber now reconciles active runs on the same definition and branch: it cancels same-branch runs that are waiting in other environments after removing all tags from them, continues with the intended selected-environment approval when that match is unique, and when more than one active run matches the same definition, branch, and selected environment it now stays inside Gerber with a checkbox cleanup step so users can cancel any subset of the stale runs and retry the dry-run without leaving the flow. The cached retry path now suppresses the runs just canceled from the immediate replanning pass, so the same stale runs do not reappear and require a second cleanup before the flow can continue.
  - Approval-plan progress now spans the full link count and resumes from already checked links after a reviewed mismatch instead of restarting from zero on each retry.
  - Approval apply now uses the Azure DevOps approvals update API version that the current server accepts (`7.2-preview.2`) and sends the approval PATCH body in the array shape that the approvals endpoint requires, so valid pending approvals are not rejected with `Value cannot be null. Parameter name: updateParameters`.
  - When Azure DevOps still rejects an approval PATCH, Gerber now keeps the response body alongside the `curl` error line so the failure reason is visible in the terminal.
  - Approval comments now contain only the linked release task number when one exists, pipelines without a linked release task stay actionable with an explicit warning/confirmation instead of blocking the dry-run, release-task updates are skipped for those pipelines, the monitored apply loop no longer stops after the first approved run because the run-status conversion step now uses the current shared pipeline-run helper contract, each phase now approves all pending runs before waiting so Azure DevOps can queue the full batch immediately, Gerber now preloads and reuses the Confluence credential before the monitored run starts so a later Confluence update does not repeat native credential access, automatically replans the same page/branch/environment when one of the originally selected approvals becomes actionable later in the same monitored sequence, adds the release `Fixversion` tag only once per unique run inside the same approve-environment apply pass and skips re-adding it when the approved run already has that tag, the shared environment resolver now falls back to `templateParameters.environment` so runs with generic parallel stage names still resolve to the correct waiting environment instead of surfacing as `unknown environment`, and completed historical runs no longer leak stale selected-environment approvals into the actionable dry-run list.
  - After a `Prod` approval or `Prod` Common Data Model release run completes successfully, Gerber now adds the `Production release` tag and ensures an Azure DevOps retention lease only once per unique run by using the configured PAT-based Azure DevOps helpers instead of `SYSTEM_ACCESSTOKEN`; in approve-environment, Prod retention now waits for the run itself to reach a completed/succeeded state instead of triggering as soon as the selected environment advances.
  - Apply now monitors the full release sequence: CDM approvals first, installation approvals after CDM success, `Unicorn` after `Sitecore` when both are separate build links, and `SSOIDP` last; if one run in a phase fails, Gerber still waits for the rest of that phase and records the rows that did complete.
  - Apply now follows each approved run through the same branch + definition run list after approval instead of relying on stage-progress inference; when the same run starts waiting on another environment or completes, Gerber treats the selected environment as finished and continues with Confluence and release-task updates, while temporarily missing branch-list matches keep polling until the normal timeout.
  - Approval apply progress now reuses one stable terminal line per pipeline with the progress bar first, then the run URL, then the pipeline name, uses plain spaces instead of tab separators so redraws do not leak stray characters before the run URL, clears stale characters when a shorter status replaces a longer one, redraws during active polling with explicit waiting / refresh checks so the view keeps moving while Gerber is still monitoring, keeps sibling runs in the same approval phase moving while another run is being polled so `Pipeline started` lines do not stay stale until their turn, finalizes sibling rows as soon as they complete even while another run is still being polled, preserves terminal `Confluence updated` / `Release task updated` milestones instead of letting later redraws fall back to `Pipeline finished`, and advances through the user-visible milestones for pipeline started, waiting on the selected environment, pipeline finished, Confluence updated, and release task updated.
  - Approval apply progress now renders from per-run events through a small release-flow render layer, keeps concurrent sibling runs such as replayed Azure DevOps runs `72660` and `72661` visible together during redraws, promotes sibling runs in a completed shared row to `Completed via shared row`, and writes dedicated approval/render debug records to `.gerber/release-approval-debug.log` when `GERBER_RELEASE_APPROVAL_TRACE=1`.
  - Approval apply now defaults the internal shared-row render list to empty for ordinary run-started and run-finished progress events, normalizes mixed apply output before the summary view reads the final result, treats Azure DevOps `ApprovalAlreadyCompletedException` responses as reused approvals instead of failing the apply pass, and raises a Gerber-owned workflow error when no valid apply result can be derived, so the flow no longer stops after completed runs with missing `SharedRowEntryList` / `Success` property errors.
  - Successful rows now update the selected Confluence environment checkbox as soon as that row's own approve-items complete instead of waiting for the rest of the current approval phase, digit environments such as `U3` and `U4` now prefer selected-branch-specific Confluence columns like `U3 / Main Branch` or `U3 / Release Branch` before falling back to a plain environment column, rewrite `Pipeline til PROD` only for `PreProd` / `Prod`, and mark the linked Azure DevOps release task environment as completed. When the selected environment column is missing on the release page, Gerber now keeps the flow inside the normal dry-run / confirm loop, warns that Confluence row updates will be skipped, still allows apply, and continues to update the linked release task.
  - When Gerber cannot verify that a Confluence pipeline label matches the Azure DevOps pipeline name, it now shows the mismatch and lets the user approve or cancel before continuing, with `Cancel` as the default confirmation choice; the final apply confirmation also defaults to `Cancel` so bare `Enter` stays non-destructive.
- Added `/pipelines release application` so users can load the same Confluence release context, choose branch plus environment, review the planned application pipelines from `Installation` in a checkbox-style batch selector, and start only the selected pipelines after an explicit `Apply`.
  - While the application plan resolves release-page links and pipeline-name mismatches, Gerber now shows a progress bar instead of only a static loading screen.
  - Apply starts only the checked application pipelines in one batch and stops there; the flow does not monitor after start, update `Pipeline til PROD`, or update linked release tasks, and the selector now uses the same highlighted focused row treatment as the other Gerber menus, `[✔]` markers for selected items, and no extra activity sub-line.
  - Gerber keeps the release `Fixversion` tag behavior for newly started runs, reconciles all active runs on the same definition and branch before it starts anything, now determines the current waiting environment from the active stage or still-pending approvals instead of historical approval maps alone, reuses the same shared approval-stage / environment resolver as `release approve-environment` and `release common-data-model` (including the timeline-backed fallback when the approvals API omits a still-pending approval), cancels same-branch runs that are waiting in other environments after removing all tags from them while carrying those tags forward onto the newly started run when they are not already present there, and if exactly one active run matches the selected environment it removes all tags from that stale run before cancelling it and starting the replacement run.
  - The apply result now renders replaced stale runs with the pipeline label from the shared stale-run helper contract, so successful replacements no longer crash the application flow summary after Gerber has already canceled the old run and started the new one.
  - When more than one active matching run exists for one pipeline, Gerber now keeps the user inside the release flow: it shows those runs oldest first in a checkbox list, starts the older runs selected and the newest run unchecked, lets the user choose exactly which runs to cancel, and retries the release flow after apply instead of stopping immediately with a manual ambiguity error.
  - After `Press Enter to continue`, the flow returns to `/pipelines release application` so another application batch can be started without leaving the release menu.
- Added `/pipelines tags update` so users can replace one Azure DevOps build/run tag with another across all currently tagged pipeline runs from one interactive flow.
- Added `/pipelines tags delete` so users can remove one Azure DevOps build/run tag across selected tagged pipeline runs from the same `/pipelines tags` submenu.
  - Gerber asks for the current tag and replacement tag, finds every matching tagged run, and groups the checkbox selection screen by pipeline name before apply.
  - The confirm step shows both the selected runs and the skipped runs before Gerber changes anything.
  - Apply removes the old tag, adds the new tag, continues across per-run failures, and reports updated / failed / skipped counts in one final summary.
- Added `/repository review` so Team DevOps can review Azure DevOps pull requests from Gerber by PR number or full PR URL, inspect the whole relevant file for each changed path, review findings grouped by YAML, URLs, secrets, connection strings, Trigger Job / JobId, internal packages, and real human review, and show/copy one Markdown checklist for PR notes while keeping environment-sensitive checks explicit as manual confirmation items.
  - The review scope is limited to changed `.json`, `.yml`, and `.yaml` files.
  - Pull requests with no relevant review files now stay inside Gerber and show `There are no files for DevOps to review in PR #<id>.` instead of surfacing a parameter-binding error.
  - Empty review blocks are now omitted from the Markdown output instead of rendering `- None`, and sections with no visible findings are left out entirely.
  - The `Real human review` section now appears only when the automated review found actionable issues or uncertainty; informational success lines such as `Azure DevOps checks - succeeded` no longer force manual confirmation by themselves.
  - YAML syntax validation now falls back to a built-in lightweight syntax check when `ConvertFrom-Yaml` is unavailable, so Azure DevOps pipeline templates such as the ones in PR `17357` no longer get skipped just because that cmdlet is missing in the current shell.
  - Build validation now falls back to Azure DevOps policy evaluations plus merge status when the PR status list is empty, so PRs that show `All required checks succeeded` and `No merge conflicts` no longer fall back to a generic manual confirmation warning.
  - Environment-specific hosts such as `*-uc4.*` in `appsettings.UC4.json` no longer require manual DNS confirmation when the host matches the same environment token and resolves successfully.
  - Environment-specific `idpconfig.<env>.json` files now follow the same host-environment matching rules as `appsettings.<env>.json`, so entries such as `/SSOIdentityServer/idpconfig.T1.json -> service-t1.example.test` no longer fall back to unnecessary manual DNS confirmation.
  - Configured environment aliases are honored, including `Development -> uc1` hosts, shared `appsettings.json -> development`, `PreProd -> pp` / `jaeger.example.test`, `T1` / `T2` and `TC1` / `TC2 -> jaeger-tc.example.test`, and `Prod -> jaeger.example.test` plus host names without an environment token.
  - IP address hosts are treated as valid across environment-specific appsettings files when they resolve successfully.
  - Shared hosts such as `api.data.example.test`, `idp-ucc.*`, `idp-mfa-ucc.*`, `oidc-ucc.*`, and `jaeger-ucc.*` are treated as valid across environment-specific appsettings files when DNS resolves successfully.
  - Environment-specific appsettings files try the file environment token first and then fall back to the environment token in the same appsettings key name when the file token does not match; files without an environment suffix use the configured default environment and then the key-name token when DNS resolves successfully, including composite key names such as `ExampleMfaOidcUC2`, and configured key-specific host exceptions such as `application_archive -> *.example.test`.
  - Environment-specific appsettings files also raise deterministic findings when non-URL scalar values contain conflicting environment tokens, such as `UC1\...` values inside `appsettings.UC4.json`.
  - Connection-string review now limits the database `DB01` / `DB02` plus `EXAMPLE_ALIAS(<port>)` validation to connection strings that use an `example-dbank-*` alias, so ordinary environment hosts such as `sample-db-uc1.cloud.example.test` no longer raise false deterministic findings. `appsettings.Development.json` still accepts local `EXAMPLE_DEV` connections whenever they include a concrete `Database=` value, so local developer databases such as `ConnectionStrings.SampleRegister -> Database=SampleRegister` and `ConnectionStrings.PersonRecord -> Database=Person` pass without UC1 token requirements.
  - Shared non-Prod hosts such as `test04-graphql.services.example.test` and `test04-auth.services.example.test` no longer create manual DNS confirmation findings in environment-specific appsettings files, while `Prod` still requires manual confirmation for the same `test04*.services.example.test` hosts.
  - `package.json` and `package-lock.json` are now skipped as unsupported review files, while `appConfig.json` and `appConfig.<env>.json` follow the same environment, URL, connection-string, and JobId review rules as matching `appsettings` files.
  - Localhost URLs are ignored so local-development endpoints do not create DevOps review findings.
- Added the interactive `Invoke-Gerber` / `gerber` multitool for local terminal workflows.
  - Includes `/tools`, `/list`, `/secrets`, `/help`, and `/exit`
  - Starts with a minimal prompt-first home screen, shows `/ commands · esc back` beneath the empty root prompt, and supports both slash-command root browsing and plain root action search across executable leaf commands, interactive autocomplete, immediate visual highlighting for the visible default suggestion in chooser prompts such as the root `/` list, root action-search matches, `/tools`, and `/secrets`, visual selection highlighting for arrow-key suggestion lists, Enter-to-accept suggestion flow, inline submenu prompts for slash commands such as `/tools`, `/list`, and `/secrets`, one-level-at-a-time `Esc` back-navigation that returns from a top-level submenu to the visible root `/` chooser before the blank home prompt, and help previews in the same terminal session
  - Adds optional `GERBER_PROMPT_TRACE=1` prompt tracing that writes `.gerber/prompt-debug.log` for terminal-specific autocomplete troubleshooting
  - `/tools create-uuid` generates a standard hyphenated UUID with no braces, shows it in the terminal, copies it to the clipboard when possible, makes `create-uuid` the default `/tools` action, and lets `Enter` generate another UUID while `Esc` returns to the `/tools` chooser
  - `/tools base-64` adds nested `encode` and `decode` actions for one-line UTF-8 text, shows results in the terminal, copies them to the clipboard when possible, returns to the selected action after `Press Enter to continue`, supports `Esc` as a return-to-menu shortcut from interactive prompts and continue screens, and keeps recoverable decode errors inside the interactive tool flow
  - `/list ado-agents` adds a read-only Azure DevOps report that shows BUILD pools first and DEPLOY pools second, keeps missing sections and empty pools explicit, sorts pools and agents, color-codes version lines consistently per run, shows a version legend, retrieves the active profile PAT from secure credential storage only when authentication is required, and returns to the main Gerber menu after `Press Enter to continue`
  - `/list ado-team-members` adds a read-only Azure DevOps report that lists all projects and their teams with member counts in a compact summary, supports drill-in navigation from project to team to members, offers per-run JSON/CSV/HTML export to the current directory with timestamped file names, includes browser-side filtering in the HTML export, and returns to the main Gerber menu after `Press Enter to continue`
  - `/repository review` adds a read-only Azure DevOps pull-request review assistant that accepts a PR number or full PR URL, reviews the whole relevant file for each changed path, groups results by the standard DevOps review categories, shows that Markdown review in the terminal, copies it for PR notes when possible, and reopens the review prompt after `Press Enter to continue`
  - `/secrets` adds nested `list`, `get`, `test`, `set`, and `remove` actions backed by secure credential storage, lists only Gerber-owned identifiers, copies a selected secret value to the clipboard before any terminal reveal when possible, confirms before revealing, overwriting, or removing values, and fails clearly without a plaintext fallback when secure credential storage is unavailable
- Added mirrored Pester coverage and PlatyPS command help for the new Gerber command surface
- Improved HTTP resilience for Gerber network calls with explicit connection timeouts (`5s`) and operation timeouts (`15s`) so unreachable endpoints fail fast instead of hanging indefinitely.
- `/list ado-agents` now shows "Connecting to Azure DevOps..." before the first HTTP call and returns to the `/list` chooser with `ado-agents` pre-selected when a recoverable error occurs, so users can retry quickly without restarting the entire slash-menu flow.
- Centralized common HTTP transport error hints for DNS failures and timeouts across Gerber network flows, while keeping caller-specific guidance in the relevant commands.
- Fixed the interactive Gerber menu so recoverable runtime errors show an in-app error and return to Gerber instead of dropping back to the PowerShell prompt.

### Changed

- Replaced identifying example organizations, profiles, endpoints and plugin names with neutral sample data across fixtures, metadata, help and preserved historical documentation. Runtime behavior and credential identities in user-owned storage are unchanged.

- Corrected the runtime dependency architecture: both NovaModuleTools and
  PSModuleUpdate remain required modules. The owner decision supersedes D-002's
  Nova exclusion while preserving Core/plugin boundaries. Nova supports
  application-exposed plugin development/build/package/local publication; PMU
  independently supplies generic updates. Historical recommendations are retained
  with supersession references; current Core behavior and planned plugin updates
  are distinguished explicitly.
- `/repository review` is no longer implemented in Gerber Core. The shared `/repository` root remains in Core, while the DevOps review workflow and review-rule configuration are now provided by the sibling Gerber.ExampleOrg plugin through the public Gerber Plugin API.

### Added

- Added version number to Gerber menu header (now displays "Gerber #0.1.0-preview - DevOps Multitool") so users can confirm the module has been reloaded after rebuilds

### Fixed

- Corrected Windows native credential service names to use the absolute
  `gerber://credentials` URI required by the provider. Writes, reads, listing,
  existence checks and removal share that mapping; macOS and Linux retain their
  existing `credentials` service and stored entries.

- Restored local quality validation: the owner-approved `PSAvoidUsingWriteHost`
  exclusion preserves intentional terminal/CI output, while all other analyzer
  findings still fail the gate. CI path composition now uses named parameters,
  and `project.json` has its required trailing newline without metadata changes.

- Fixed `/list ado-team-members` member-detail navigation failing with
  `Start-GerberScreen is not recognized` after team selection by keeping the redraw callback in the
  Gerber module scope; the built-app PTY regression now covers selection, preview updates, member
  rendering, repeated use, local back-navigation, and controlled network failure recovery.

- Fixed test failures in `/repository create nuget` implementation: removed recursive `ConvertTo-Json` mocks that caused infinite stack overflow in policy configuration tests, and wrapped `Build-GerberAdoCommitChanges` test results in `@()` to ensure PowerShell treats single-hashtable return values as arrays instead of unwrapping them and counting hashtable keys
- Fixed `/repository create` submenu routing by providing the subcommand table directly to `Get-GerberMenuSubcommand` instead of relying on catalog lookup with nested command paths, following the same pattern used by other nested `/tools` flows
- Fixed missing `/repository` menu item by adding `'repository'` to the default ActionList parameter in `Resolve-GerberCommand`, and updated the suggestion test to expect both `/repository` and `/tools` when searching for `/to` since "repository" contains "to"
- Fixed `ConvertTo-GerberSuggestion` parameter validation by adding `[AllowEmptyString()]` to the `PreviewText` parameter so numbered menu items (projects, templates, teams) can have empty preview text without causing binding errors
- Fixed `/repository create nuget` apply flow to abort immediately when repository creation fails, preventing subsequent steps from attempting to use an empty RepoId and causing parameter binding errors
- Fixed `New-GerberAdoRepository` to call `Invoke-RestMethod` directly instead of `Invoke-GerberAdoRestMutation` so it can capture and return the created repository's ID; the mutation helper discards responses by assigning to `$null`, which was causing all repository creations to appear failed even when they succeeded
- Fixed `/repository create nuget` failure reporting to capture and display error details in the summary screen instead of writing warnings that are cleared before the user sees them; ADO helper functions now return `ErrorDetail` properties that flow through to the final failure list so users can see why each step failed
- Fixed `/repository create nuget` initial commit failure by modifying `Get-GerberAdoRepositoryItemTree` to fetch file content for each blob; the Azure DevOps Items API with `recursionLevel=Full` returns only metadata (paths, types) without actual file content, so the function now makes separate requests with `includeContent=true` for each blob and captures the raw string content returned by the API (not an object with a `.content` property)
- Fixed `/repository create nuget` writing literal `System.Xml.XmlDocument` as the content of `.csproj` and other XML files; `Invoke-RestMethod` automatically deserializes responses with an XML content type into an `XmlDocument` object, and casting that to `[string]` returns the type name rather than the file text; the per-file content fetch now uses `Invoke-WebRequest -UseBasicParsing` so the raw response body is always returned as a plain string regardless of content type
- Fixed `/repository create nuget` initial commit "405 Method Not Allowed" error by changing `New-GerberAdoRepositoryInitialCommit` to use `Get-GerberAdoApiUri` instead of `Get-GerberAdoBranchRequestUri`; the branch URI helper was appending preview API versions specific to branch operations, but the pushes endpoint requires the stable API version used by other mutation helpers
- Fixed **G-UX1-FIX1 — Shared Plugin Menu Navigation Regression**.
  - `/plugins` now reuses Gerber's shared submenu navigation contract instead of a plugin-specific dispatch path.
  - Single `Esc` from `/plugins list` and `/plugins info` now returns to `/plugins`, while single `Esc` from plugin details opened through `/plugins list` still returns to the list view first.
  - Double `Esc` within 200 milliseconds still returns directly to the root prompt from nested plugin-management views.
  - Direct `/plugins list` and `/plugins info` execution continues to use Gerber's existing command-resolution behavior without inventing a separate navigation history.
