# Release notes

## [Unreleased]

### Changed

- Azure DevOps now belongs to the separate **Gerber.AzureDevOps 0.1.0** plugin,
  included in Core's declared dependencies. Approval and activation remain
  explicit; disabled or declined plugins contribute no ADO commands.
  Existing `/list`, `/repository`, `/branch` and `/pipelines tags` paths remain.
- Core settings use `GerberCore.json`; plugin profiles use
  `Gerber.AzureDevOps.json` through Plugin API v1. The legacy configuration
  transition preserves originals on conflict or failure and never changes
  approval or credentials. Missing plugin PATs are entered again through the
  existing GUID-scoped Secrets API; old credentials remain untouched.
  Publication and live PSGallery/internal-repository qualification are later
  work, not performed by this extraction.
- Gerber requires numeric PSModuleUpdate `0.2.0`, available from PSGallery.
  Dependency installation is a separate approved action, not automatic
  installation or cleanup of local Gerber. An up-to-date `0.1.0` remains visible
  in Available with no install offer.

### Fixed

- Unreadable module-search paths no longer prevent plugin discovery or
  `/update list` from completing.
- Unsupported Core installation layouts now get supported numeric-version
  directory/restart guidance instead of a PSGallery/connection diagnosis.
  No automatic migration, installation or rollback is implied. An existing
  installed Gerber copy needs a separate update to receive this message.
- Locally copied or published Core installations that lack native provider
  metadata now specifically instruct users to reinstall the current Gerber
  version from PSGallery before retrying `/update list`.

### Added

- `/update` opens the shared **list**/**policy** submenu. `/update list`
  checks Gerber Core in its fixed official PSGallery repository and shows
  installed/available versions before asking whether to install. Cancel is the
  default; results explain verification, recovery and when to restart PowerShell.
  Verified success requiring restart, or discovery of a newer Core already
  installed, now offers **Exit Gerber** or **Continue with current version**.
  Continue is the default; Esc also continues with the restart reminder retained.
  Exiting Gerber does not restart PowerShell: restart PowerShell yourself, then
  run `gerber`. Core and plugins are not reloaded in-process.
  Startup can notify about an available version but never installs or asks to
  install or request credentials. No Core repository setup or override is
  supported; old Core update settings are ignored. `/update policy` saves
  **Stable only** (the default) or **Include prereleases** for both startup and
  manual checks. Changing it installs nothing; Enter after saving returns to the
  `/update` menu. Installation still defaults to Cancel.
  Stable promotion from an installed preview remains supported. No eligible
  matching package remains a legitimate result and does not prove Core is current.
  `/update list` also checks eligible installed plugins and offers checkbox
  selection, with a visibly added Core update when required. Core and plugins
  appear together in the same aligned overview table, with a blank line before
  the channel and no per-plugin information lines. When no update is available,
  Enter returns without a chooser or cancellation message. Plugin manifests
  declare `PrivateData.Gerber.Repository` with a display `Name` and canonical `Uri`.
  Names stay visible when lookup fails; PMU and trust prompts retain the URI.
  Absent metadata uses PSGallery; invalid explicit metadata never falls back.
  Legacy `RepositoryUri` still works, with canonical metadata taking precedence.
  Trust/license-gated package
  inspection asks separately before the combined default-Cancel install prompt.
  Updates run sequentially; dependent plugins are blocked on Core failure while
  independent updates continue. Results distinguish installed packages from
  fresh-process activation failures. Credentials last for this operation only.
  No first installation, hot reload or batch rollback is included.
  **Delivery limitation:** the new PMU inspection API is local and unpublished;
  the declared minimum remains 0.2.0. This does not qualify hosted or live plugin
  updates. See [Core and plugin updates](docs/core-updates.md).

- Plugin authors can run `Test-GerberPluginBoundary -Path <project>` from
  installed Gerber to find identifiable private Core dependencies before building
  or installing a plugin. Diagnostics show the source location, dependency and
  public-API resolution; `PublicApi` lists implemented operations.
  Generated projects include `./scripts/Test-PluginBoundary.ps1` and matching
  agent guidance, and creation rejects invalid source before approval.
  This static development check is not a sandbox and does not change existing
  plugin approvals, discovery or execution.

- `/plugins create` creates a working Gerber plugin: enter `MyCompany` to get
  `Gerber.MyCompany`, choose its `mycompany` command namespace, repository and destination parent,
  then let Gerber build and test it before approval. Existing files are never overwritten.
  PSGallery is preselected and writes its name and official URI without extra
  questions. Another repository asks for its name, then URL; blank names can
  be corrected locally. Enter for an unknown URL writes
  `REPLACE_WITH_REPOSITORY_URI` in `Repository.Uri`; replace it in `project.json`
  and rebuild before remote publishing or updates. Esc cancels without generation.
  Local build, tests and local publication remain available.
  Explained, separated fields show actual defaults; the completion summary states
  the repository name and URI, generated metadata and **Installed: No**. Before installation, `/plugins list`
  and `/plugins info` already show the known name/version without loading anything.
  Projects include a canonical manifest GUID, a complete Unreleased changelog and
  Gerber-specific agent resources led by AGENTS.md with thin Claude/Copilot bridges.
  Nova is a required Gerber runtime dependency for plugin development; its
  lifecycle operations run on demand, and the existing missing-tool installation
  fallback requires consent. From the generated project run `Publish-NovaModule -Local`, restart
  Gerber, and try `/mycompany hello`. See [plugin creation](docs/plugins-create.md)
  for cancellation, recovery and local installation details.

### Changed

- Examples and historical notes now use neutral organizations and endpoints. Existing user configuration and credentials are unchanged.

- Clarified the [runtime dependency contract](docs/architecture/G-4A5-update-architecture.md):
  Gerber requires both NovaModuleTools for plugin development and PSModuleUpdate
  for generic update mechanics. Neither dependency's operational workflows run
  merely because Gerber is imported; updates are never installed automatically.

### Fixed

- Corrected Windows credential target formatting without changing existing
  macOS/Linux credential storage or Gerber credential identifiers.

- Fixed local quality validation without changing Gerber's Core update behavior
  or required runtime dependencies. Intentional `Write-Host` output remains allowed.

## New Features

### Persistent plugin approval and lifecycle state

Gerber now asks before loading a plugin whose manifest GUID has not previously been approved. The approval screen identifies the plugin by name, GUID, version, publisher metadata, and location, with decline as the default.

Gerber now also persists plugin association and enabled/disabled state in the same user configuration. The first successful approval approves the GUID, associates the plugin with the user's Gerber environment, and enables it without a second prompt. Existing approved plugins without an explicit association record remain usable and pick up lifecycle state lazily the next time Gerber discovers them.

Declined decisions are now persisted too, so Gerber does not prompt again for the same unknown plugin on the next startup. Users can change that decision explicitly through `/plugins enable`.

Associated disabled plugins stay approved, but Gerber does not import them, execute `Get-GerberPlugin`, or register their commands until `/plugins enable` reenables them. Missing modules do not delete the saved association record. Noninteractive sessions load already approved and enabled plugins and skip unknown plugins without prompting or autoapproval. GUID approval identifies the selected plugin but is not a cryptographic signature or publisher-authenticity guarantee.

### Read-only plugin management

Gerber Core now includes the first user-facing plugin-management commands:

- `/plugins` shows a compact overview of every plugin identity Gerber currently knows about
- `/plugins list` shows the merged plugin inventory across discovered manifests, persisted configuration, and current-session loaded state
- `/plugins info <plugin>` shows detailed metadata and lifecycle state for one plugin by manifest GUID or unique module name

These commands stay read-only. They do not approve, decline, associate, enable, disable, remove, revoke, install, or uninstall anything.

**Key behaviors:**
- **Declined plugins remain visible:** a plugin declined earlier stays visible in `/plugins` even if it was never associated or is not currently discoverable
- **Missing associated plugins remain visible:** Gerber shows the persisted GUID and lifecycle state without inventing missing metadata
- **No unsafe inspection imports:** Gerber uses safe manifest inspection plus the existing registry cache, so unknown, declined, and disabled plugins are not executed just to render plugin management
- **Clear lifecycle distinctions:** approval, association, enabled/disabled state, and current loaded state are shown separately; declined is not disabled, and future revoke semantics remain distinct

`/plugins enable` lists installed inactive plugins, including previously declined plugins. Selecting one counts as approval without another confirmation. `/plugins disable` removes an active plugin's commands while preserving approval and leaving its module installed. Both actions persist across sessions and update menus, completion, and command dispatch immediately without restarting Gerber.

Root browsing and completion show `/exit`, `/help`, `/plugins`, and `/update` first, in that order, followed by all remaining Core and active plugin root commands alphabetically. Submenu ordering is unchanged.

### Enforced interactive regression coverage

Gerber now generates its terminal command inventory from the effective built Core/plugin registry
and verifies executable PTY coverage for command discovery, dispatch, workflows, navigation,
rendering, and error recovery. Full quality runs fail when required coverage is missing, stale, or
did not execute successfully, and publish JSON plus Markdown coverage reports under
`artifacts/terminal/runs/<run-id>/`.

The `/list ado-team-members` detail view also keeps its screen redraw callback bound to Gerber Core,
so selecting a team no longer fails with `Start-GerberScreen is not recognized`.

### First-use Azure DevOps setup

Gerber Core now prepares Azure DevOps access only when a command actually needs it. A missing connection no longer forces users to leave the current workflow, manually edit configuration first, or depend on environment-variable PAT fallbacks.

**Key capabilities:**
- **Inline first-use setup:** Authenticated Azure DevOps commands can configure a missing project URL, named profile, default-profile choice, and PAT inside the same command flow
- **Named-profile aware selection:** Gerber uses the configured default when present, offers the only existing profile when no default exists, lets the user choose among multiple profiles, and configures an explicitly requested missing profile instead of silently switching to another one
- **Secure PAT storage:** PAT entry uses non-echoing input and stores the token only through the native credential service as `gerber:ado:<profile>:pat`
- **Services and Server support:** Reuses the shared Azure DevOps URL parser for `dev.azure.com`, legacy hosted URLs, and self-hosted Azure DevOps Server, including the extra Server-root prompt only when needed
- **Safe recovery:** Decline and cancel stop the pending command cleanly, non-interactive runs fail with setup guidance instead of prompting, and partial config-versus-credential failures are reported explicitly for safe retry
- **Shared Core/plugin path:** Gerber.ExampleOrg and other plugins that open Azure DevOps connections through the Core Plugin API now benefit from the same readiness flow

**Example usage:**
```text
/repository review
```

### Repository Creation from Templates

Gerber now includes `/repository create nuget`, an interactive command for creating NuGet package repositories from the `Template_NuGet` template. This feature brings Azure DevOps repository scaffolding into Gerber's menu flow with full preview-and-confirm UX.

**Key capabilities:**
- **Guided prompts:** Choose project, template (auto-selects Template_NuGet), package name, and owner team through numbered menus and text input
- **Complete file replacement:** All files from template are copied with `PackageName` replaced in paths, folder names, and content
- **Pipeline automation:** Creates pipelines for all YAML files in the `pipelines/` folder with correct naming
- **Branch and policy setup:** Creates missing branches and copies all branch policies from template, including build validation policies correctly linked to new pipelines
- **Team integration:** Creates auto-include reviewer policy with chosen team
- **Resilient execution:** Continues past partial failures and reports them in summary
- **Safe workflow:** Shows preview of all planned mutations before applying changes
- **Familiar navigation:** Esc returns to previous prompt, Enter continues returns to package name prompt

**Example usage:**
```text
/repository create nuget
```

This feature follows the same preview-and-confirm pattern as `/branch set-default`, ensuring safe execution of project-wide mutations through Gerber's interactive flow.s

This file summarizes public cmdlet, CLI, configuration, and migration changes for Gerber.
`CHANGELOG.md` remains the exhaustive record of all changes in each release. **UNRELEASED** changes will be included in the next **stable** release!

## [Unreleased]

### Added

- Added `/plugins enable` and `/plugins disable` to activate inactive plugins, including previously declined plugins, or deactivate active plugins without revoking approval or uninstalling their modules. Explicit enable counts as approval; changes persist and take effect without a restart.
- Root command browsing and completion now prioritize `/exit`, `/help`, `/plugins`, and `/update` in that order, then sort all other Core and active plugin root commands alphabetically.
- Added **G-UX1 — Double Escape to Root** so Gerber users can press `Esc` once to go back one level or press `Esc Esc` within 200 ms to jump directly to the root prompt without exiting Gerber or executing a command. The shortcut now works through the shared Core prompt/menu infrastructure, including nested subcommand prompts, continue screens, Base64 flows, and plugin-driven terminal views that use Gerber's shared prompt handling.
- Added `/branch set-searchable` so users can enter one or more comma-separated branch names, choose between Replace and Merge mode, preview the planned searchable-branches policy changes across all Azure DevOps repositories, apply the changes after confirmation, and review a created/updated/unchanged/failed summary. `Esc` exits cleanly at the branch-name prompt and at the continue screen; `Esc` at the mode chooser returns to branch-name input.
- Added `/branch find` so users can enter a short branch path (e.g. `item/juni2026`), have Gerber normalise it to `refs/heads/item/juni2026`, scan all Azure DevOps repositories in the configured project, see per-repo progress during the scan, and review which repositories contain the branch in a matched-repo list with a found-count summary — or a neutral message when nothing matches. Repositories that cannot be checked are collected into a warning summary shown after the results. `Esc` exits cleanly at the prompt and at the continue screen.
- Introduced the interactive `Invoke-Gerber` / `gerber` DevOps multitool for local terminal sessions.
- Added `/tools`, `/list`, `/secrets`, `/help`, and `/exit` inside the Gerber command palette, now starting from a minimal prompt-first home screen that shows `/ commands · esc back` beneath the empty root prompt, with interactive slash-command autocomplete and plain root action search across executable leaf commands, immediate visual highlighting for the visible default suggestion in chooser prompts such as the root `/` list, root action-search matches, `/tools`, `/list`, and `/secrets`, visual selection highlighting for arrow-key suggestion lists, Enter-to-accept suggestion flow, inline submenu prompts for slash commands such as `/tools`, `/list`, and `/secrets`, submenu-scoped prompt behavior, help previews, and optional prompt tracing through `GERBER_PROMPT_TRACE=1`.
- Added `/tools create-uuid` so users can generate a standard hyphenated UUID immediately, copy it to the clipboard when possible, press `Enter` to generate another, and use `Esc` to go back to `/tools`.
- Added `/tools base-64` with nested `encode` and `decode` actions for one-line UTF-8 text so users can convert Base64 values without leaving Gerber, return directly to the selected action after `Press Enter to continue`, use `Esc` to get back to the main Gerber menu from interactive prompts and continue screens, see the result in the terminal, and copy it to the clipboard when possible.
- Added `/list ado-agents` so users can review Azure DevOps BUILD and DEPLOY pools in one read-only Gerber report, keep empty sections and empty pools visible, retrieve the active profile PAT from secure credential storage only when authentication is required, scan version lines with consistent per-run color coding plus a legend, and return to the main menu after `Press Enter to continue`.
- Added `/list ado-team-members` so users can see all Azure DevOps projects and teams in a compact summary, drill into project → team → members for a focused view, export the full report as JSON, CSV, or HTML (with browser-side row filtering) to the current directory with a timestamped file name, and return to the main menu after `Press Enter to continue`.
- Added `/repository review` improvements so DevOps review skips `package.json` and `package-lock.json` as unsupported files, `appConfig.json` and `appConfig.<env>.json` now follow the same environment, URL, connection-string, and JobId checks as matching `appsettings` files, shared non-Prod `test04*.services.example.test` hosts are accepted without manual DNS confirmation outside `Prod`, and database `DB01` / `DB02` plus `EXAMPLE_ALIAS(<port>)` validation now only applies when the connection string uses an `example-dbank-*` alias.
- Improved `/pipelines release common-data-model` so `Solr Core` now sends the full queue-time parameter set from the selected release context: `environmentName`, `WorkingDirectory`, `SolrVersion`, `JreVersion`, `JrePackageVersion`, `JreDownloadUrl`, `SolrUrl`, `SolrPort`, `SolrServiceName`, and `Cores`. `WorkingDirectory`, `SolrUrl`, and `SolrServiceName` come from the per-environment Solr settings in `src/resources/Properties.json`, `SolrVersion`, `JreVersion`, `JrePackageVersion`, `JreDownloadUrl`, and `SolrPort` come from the shared Solr settings, and `Cores` is still built from the linked release task's `Step by step guide` in configured order. Apply now updates the selected Confluence release-row checkbox/task cell when the page exposes that environment column, still rewrites `Pipeline til PROD` only when the selected environment is `Prod`, leaves Confluence unchanged when the page has no matching environment column, and reports the result as a general release-page update instead of only `Pipeline til PROD`. The flow still replaces exactly one stale matching active run automatically, and when more than one active run matches the same definition / branch / environment Gerber now shows an in-flow checkbox cleanup step so the user can choose which runs to cancel before the release retries.
- Improved the monitored `Prod` release flows so `/pipelines release common-data-model` and `/pipelines release approve-environment` now add the `Production release` tag and ensure an Azure DevOps retention lease on each successfully completed `Prod` run by using the configured PAT-based Azure DevOps helpers. Gerber does not use `SYSTEM_ACCESSTOKEN`, limits the scope to the specific run it just sent to `Prod`, and now de-duplicates repeated apply references so the same run is only retained once.
- Improved `/pipelines release common-data-model` so shared release-planning helpers now normalize missing pending approval lists before branch/environment reconciliation, which prevents the flow from stopping after environment selection with a missing `PendingApprovalList` property error.
- Improved the three release flows so Gerber now reconciles active runs per pipeline definition and branch before it continues: `/pipelines release common-data-model` and `/pipelines release application` now determine the current waiting environment from the active stage or still-pending approvals instead of historical approval maps alone, reuse the same shared approval-stage / environment resolver as `/pipelines release approve-environment`, and keep the timeline-backed fallback that still classifies a pending run when the Azure DevOps approvals API omits that approval. This removes misleading `unknown environment` output when Gerber already has enough timeline data to resolve the waiting environment. The flows still cancel same-branch runs that are waiting in other environments after removing all tags from them, carry those tags forward onto the newly started run when they are not already present there, and then continue with the selected-environment replacement/start behavior, while `/pipelines release approve-environment` performs the same cleanup before approving the unique selected-environment run or opening its in-flow stale-run cleanup step.
- Improved `/pipelines release common-data-model` so apply now uses one checkbox selector for every planned wave before it starts anything: Gerber begins with every pipeline selected, blocks Enter when nothing is selected, ignores `Tab` safely, re-checks dependencies before apply so a selected later-wave pipeline cannot continue when it depends on a deselected earlier-wave pipeline, highlights the focused row with the same selected-row background used elsewhere in Gerber, uses `[✔]` for selected entries, omits the extra activity sub-line, keeps the confirmation summary in wave order, still monitors the selected waves in order, no longer fails when a later-wave pipeline such as `Solr Core` is the only deselected item, now ignores stray non-result output from the apply invocation so the flow does not stop after a completed run with a missing `RestartRequested` property error, and marks each started run's linked Azure DevOps release task environment as completed even when the selected environment is not `Prod`. `Solr Core` remains forced into the final wave and final slot whenever it stays selected.
- Improved `/pipelines release approve-environment` so approval comments now contain only the release task number when one exists, pipelines without a linked release task stay actionable with an explicit warning/confirmation instead of blocking the dry-run, release-task updates are skipped for those pipelines, each apply phase approves the full batch before Gerber starts waiting, the monitored flow keeps tracking the remaining approved runs even if one run in the same phase fails, post-approval waiting now follows the approved run through the same branch + definition run list and treats the selected environment as finished when that run either waits on another environment or completes, temporarily missing branch-list matches keep polling until the normal timeout, the progress view keeps one aligned line per pipeline with the bar first, then the run URL, then the pipeline name while stepping through the visible milestones for pipeline started, waiting on the selected environment, pipeline finished, Confluence updated, and release task updated, now uses plain spaces instead of tab separators so redraws do not leak stray characters before the run URL, keeps sibling runs in the same approval phase updating while another run is being polled so `Pipeline started` lines do not stay stale until their own turn, finalizes sibling rows as soon as they complete even while another run is still being polled, preserves terminal `Confluence updated` / `Release task updated` milestones instead of letting later redraws fall back to `Pipeline finished`, completed rows now update Confluence and the linked release task as soon as that row itself is done instead of waiting for the rest of the phase, digit environments such as `U3` and `U4` now prefer selected-branch-specific Confluence columns like `U3 / Main Branch` or `U3 / Release Branch` before falling back to a plain environment column, Gerber now adds the release `Fixversion` tag only once per unique approved run in the same apply pass and skips re-adding it when the approved run already has that tag, Prod retention now runs only after the run itself completes successfully, the shared environment resolver now falls back to `templateParameters.environment` so runs with generic parallel stage names still resolve to the correct waiting environment instead of surfacing as `unknown environment`, completed historical runs no longer leak stale selected-environment approvals into the actionable dry-run list, the final summary now normalizes mixed apply output before it reads the result, treats Azure DevOps `ApprovalAlreadyCompletedException` responses as reused approvals instead of failing the apply pass, and apply can now continue when the release page has no matching Confluence environment column by warning that Confluence row updates will be skipped while the linked release task still gets updated.
- Improved `/pipelines release approve-environment` so the dry-run now uses the same checkbox-style selection pattern as the other release flows: every pending approval starts selected, users can choose one, many, or all approvals before apply, the final confirm screen shows both the selected approvals and the skipped approvals before anything is approved, and ambiguous selected-environment runs now stay inside Gerber with a checkbox cleanup step so stale runs can be canceled and the dry-run retried without opening Azure DevOps manually. The cached retry path now suppresses the runs just canceled from the immediate replanning pass, so the same stale runs do not reappear in the next ambiguity screen.
- Improved `/pipelines release approve-environment` rendering so the apply flow now redraws from per-run events instead of a single shared terminal line, keeps concurrent sibling runs visible together, marks sibling runs in a completed shared row as `Completed via shared row`, can write separate approval/render diagnostics to `.gerber/release-approval-debug.log` when `GERBER_RELEASE_APPROVAL_TRACE=1`, and now defaults the internal shared-row render list to empty for ordinary single-run progress updates so apply no longer stops on a missing `SharedRowEntryList` property.
- Added `/pipelines release application` so users can load the same Confluence release page, choose branch and environment, watch a planning progress bar while the `Installation` links are resolved, review the planned application pipelines in a checkbox-style batch selector with the same highlighted focused row treatment as the other Gerber menus plus `[✔]` markers for selected items and no extra activity sub-line, and start only the selected application pipelines in one explicit apply batch without post-start monitoring.
- The new application flow reuses the same release `Fixversion` tagging as other pipeline starts, automatically cancels and replaces exactly one stale matching run for the same definition / branch / environment, removes all tags from that stale run before cancel so older non-fixversion tags do not linger, now shows a checkbox-driven stale-run cleanup step when more than one matching active run exists so the user can choose which runs to cancel before Gerber retries that pipeline, keeps trying later runnable pipelines after one start failure, returns to `/pipelines release application` after `Press Enter to continue`, and now keeps the replaced-run summary stable after a successful cancel-and-restart by carrying the pipeline label through the shared stale-run helper contract.
- Added `/pipelines tags update` so users can replace one Azure DevOps build/run tag with another across all currently tagged pipeline runs from one submenu action.
- The new tag-update flow asks for the current tag and replacement tag, finds every matching tagged run, shows those runs in one checkbox selector grouped by pipeline name, removes the old tag and adds the new tag on each selected run, continues across per-run failures, and returns to `/pipelines tags update` after `Press Enter to continue`.
- Added `/pipelines tags delete` so users can remove one Azure DevOps build/run tag across selected tagged pipeline runs from the same submenu family.
- The new tag-delete flow asks for the current tag, finds every matching tagged run, shows those runs in one checkbox selector grouped by pipeline name, removes the tag on each selected run, continues across per-run failures, and returns to `/pipelines tags delete` after `Press Enter to continue`.
- Added `/secrets` with nested `list`, `get`, `test`, `set`, and `remove` actions backed by Gerber secure credential storage so users can manage Gerber-owned credentials inside the same slash-command menu, inspect identifiers without exposing values, copy a selected value to the clipboard before any terminal reveal when possible, confirm before revealing, overwriting, or removing values, and receive actionable errors when secure credential storage is unavailable.
- Improved HTTP resilience with explicit connection timeouts (`5s`) and operation timeouts (`15s`) so unreachable endpoints fail fast instead of hanging indefinitely.
- `/list ado-agents` now shows "Connecting to Azure DevOps..." before the first HTTP call and returns to the `/list` chooser with `ado-agents` pre-selected when a recoverable error occurs, so users can retry quickly without restarting the entire slash-menu flow.
- Gerber now stays inside the interactive menu when a recoverable runtime error happens and shows an actionable in-app error message instead of exiting to the PowerShell prompt.

### Changed

- `/repository review` is now provided by the sibling Gerber.ExampleOrg plugin instead of Gerber Core. Gerber Core keeps the shared `/repository` root and built-in `/repository create` flow, while Gerber.ExampleOrg owns the DevOps review workflow and its review-rule configuration.

### Deprecated

### Removed

### Fixed

- Fixed **G-UX1-FIX1 — Shared Plugin Menu Navigation Regression** so `/plugins` now follows the same shared Core submenu contract as the other nested Gerber menus. Entering `/plugins` keeps plugin navigation inside the shared parent menu, `Esc` from `/plugins list` or `/plugins info` returns to `/plugins`, `Esc` from plugin details returns to the list, and rapid double-`Esc` still jumps directly to the root prompt.

### Security
