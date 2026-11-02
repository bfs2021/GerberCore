# Gerber

Gerber is an interactive DevOps multitool for local PowerShell workflows. It runs as a lightweight terminal command palette with a minimal prompt-first home screen, then expands into interactive tools, reports, and secret-management flows on demand.

Gerber Core owns the shared platform; **Gerber.AzureDevOps** owns Azure DevOps
operations. Other organization-specific names and endpoints in examples are illustrative.

## Run Gerber locally

Build and import the module, then start the multitool:

```powershell
Invoke-NovaBuild
Import-Module ./dist/Gerber/Gerber.psd1 -Force
Invoke-Gerber
```

If aliases are available in the imported session, you can also start it with:

```powershell
gerber
```

Gerber targets PowerShell `7.4` and is designed to work on macOS, Windows, and Linux terminals without any extra TUI library.

### Runtime dependencies

Gerber requires **NovaModuleTools** for its plugin-development functionality
(creation, build, packaging and local publication) and **PSModuleUpdate** for
integrated update management. **Gerber.AzureDevOps 0.1.0** is also declared in
`project.json` `RequiredModules`, so it follows the existing distribution model.
Importing that dependency does not approve or enable it in Gerber. Unknown
plugins retain the normal default-decline approval flow; saved decline and
disable decisions remain authoritative. Unrelated Core tools do not require
an active Azure DevOps plugin.
Nova build/package/publish operations do not run at startup. Gerber now performs a
bounded, notification-only Core update check when `Invoke-Gerber` starts, and
`/update list` checks afresh and installs only after explicit confirmation;
no repository setup is required. Core always uses the official **PSGallery**
repository; user settings, environment variables and plugins cannot override it,
and there is no fallback.
The minimum PMU dependency is numeric **0.2.0**, available from PSGallery.
Dependency installation is a separate, explicitly approved action; `/update` does
not bootstrap PMU or automatically migrate or clean up local Gerber
installations. When PMU reports installed and available `0.1.0` as `UpToDate`,
the overview retains available `0.1.0` and offers no installation.
The scan ignores legacy resource directories beside numeric installations;
it does not select a flat-only copy as a versioned installation.
A source build does not replace installed/loaded PMU; failed checks remain
`Unavailable`, not an inferred currency result. A user-confirmed live Core update
on 2026-10-27 completed with verified installation; this does not qualify every
platform or recovery path. Published PMU 0.2.0 still reports provider
`PackageNotFound` exceptions as a generic discovery failure. Gerber shows
`NoMatchingPackage` only when PMU supplies the explicit `PMU.PackageNotFound`
identifier; neither result offers installation or proves Core is up to date.
The upstream correction is implemented and tested locally, but is not yet
published or deployed; the dependency minimum remains unchanged. See the
[current qualification evidence](PLAN.md#g-4a7r-closure-evidence-and-remaining-work).
`PMU.UnsupportedInstallation` normally gives generic supported
numeric-version layout/restart guidance without claiming installation or
rollback success. When the selected numeric installation specifically lacks
native provider metadata, Gerber identifies it as locally copied or published
and instructs the user to reinstall the current version from PSGallery before
retrying `/update list`. Gerber never manufactures provider metadata or
automatically removes the existing installation.
The local G-4A9 implementation adds installed-plugin updates to `/update list`.
Core and plugins appear in one aligned table, followed by a blank line and the
shared channel, without per-plugin information lines. Available updates support
multi-selection. With no available update, Enter returns without a chooser or
a misleading cancellation message.
Its new PMU target-manifest inspection capability is **not published**: published PMU
0.2.0 satisfies the unchanged declared minimum but does not deliver those APIs.
Building this checkout alone does not deploy them. See
[update policy and dependency delivery](docs/core-updates.md).
[Disposable build/import qualification](docs/architecture/G-4A6-runtime-dependency-qualification.md)
passed on macOS/PowerShell 7.4.21 and 7.6.6; normal Nova builds now regenerate both
requirements in the ignored local manifest. See the
[runtime dependency and update contract](docs/architecture/G-4A5-update-architecture.md).

### Configuration files

Core settings, including plugin approval, association and enabled state, live in
`GerberCore.json`. Each plugin can use its own module-named JSON file in the same
directory; Azure DevOps profiles live in `Gerber.AzureDevOps.json`.
The directory follows the existing APPDATA, XDG_CONFIG_HOME or HOME resolution,
not one hard-coded macOS/Linux path.

`GERBER_CONFIG_PATH` remains an absolute **Core file** override. Plugins use its
directory, not its filename. An override ending in legacy `config.json` selects
the sibling `GerberCore.json` instead.
Other explicit filenames are retained, including case-distinct filenames on
Unix-like systems; Windows legacy filename matching remains case-insensitive.
On the first Core configuration read, a sibling legacy `config.json` is split:
non-ADO settings, including unknown fields, go to Core; `ado` goes to the Azure
DevOps file. Existing disjoint or identical data is merged. Conflicts or invalid
JSON stop the transfer with file-specific guidance and retain the originals.
After a partial failure, retry is safe; the legacy file is deleted only after
all transferred data is verified. This transition never approves or enables a
plugin and never reads, migrates or deletes credentials.

PATs must be re-entered at the first authenticated ADO use if the plugin's own
secret is missing. Old Core credentials remain untouched. The plugin uses
Secrets under GUID `a468dee5-c7a0-43e4-ae88-bb19158fe679`, never JSON.
This checkout's new plugin dependency still needs publication for later clean
PSGallery installation; local development uses built artifacts in isolated
module paths, without global module installation.

## Interactive commands

Gerber opens as a minimal prompt with inline root guidance:

```text
Gerber - DevOps Multitool

❯

/ commands · esc back
```

Type `/` to reveal the available root commands, or start typing plain text directly to search executable leaf action commands without a slash:

Root commands and completion suggestions show `/exit`, `/help`, `/plugins`, and `/update` first, in that order, followed by all remaining Core and active plugin root commands alphabetically. Submenu ordering is unchanged.

Menu-only roots and nested submenus appear only while they contain available
actions. `/branch`, `/list`, `/pipelines` and `/repository` are therefore absent
when no active plugin contributes beneath them. Several plugins can share a
root: disabling one removes only its contribution, and disabling the last
removes the empty menu. Enabling a contributor restores its commands immediately.
Menus, completion, help and direct command lookup use the same active tree;
standalone Core actions remain available without plugin contributions.

| Command | Purpose |
| --- | --- |
| `/exit` | Exit the interactive session cleanly |
| `/help` | Show the built-in command help |
| `/plugins` | Inspect, enable or disable plugins, or generate a working plugin with `/plugins create` |
| `/update` | Open the Core and plugin update submenu with list and policy actions |
| `/update list` | Check Core and eligible installed plugins, select updates and confirm installation |
| `/update policy` | Choose the shared Stable only (default) or Include prereleases update channel |
| `/branch` | Shared root; active AzureDevOps contributes `find`, `set-searchable` and `set-default` |
| `/list` | Shared report root; active AzureDevOps contributes `ado-agents` and `ado-team-members` |
| `/pipelines` | Shared pipeline root; active AzureDevOps contributes `tags update` and `tags delete` |
| `/repository` | Shared repository root; active AzureDevOps contributes `create` |
| `/secrets` | Manage Gerber credentials through Gerber secure credential storage |
| `/tools` | Open an inline submenu for interactive tools such as `create-uuid` and `base-64` |

Autocomplete is available directly in the slash-command prompt:

- type `/` to reveal the available Gerber commands
- type plain text such as `uuid`, `base`, `ado`, or `help` at the root prompt to search matching leaf action commands without a leading slash
- the empty root prompt shows `/ commands · esc back` so the first move is visible without opening help
- press `Tab` to complete a matching command such as `/to` -> `/tools`
- use `Up` and `Down` to browse matching commands and subcommands
- press `Enter` to accept the highlighted suggestion and execute it when the selected command is complete, whether you started with `/` or plain root action-search text
- the currently selected arrow-key suggestion is visually highlighted to stay readable across terminal themes, and chooser prompts such as the root `/` list, `/tools`, and `/secrets` now keep the visible default action highlighted immediately
- bare submenu commands such as `/tools`, `/list`, and `/secrets` open an inline submenu prompt with the available subcommands shown on the command line
- `/tools` previews `create-uuid` first, so bare `Enter` at the chooser generates a UUID immediately
- nested tool prompts such as `/tools` and `/tools base-64` use the same arrow-key submenu behavior as the existing slash menus
- after you choose `/tools base-64 encode` or `/tools base-64 decode`, Gerber reopens that same action after `Press Enter to continue` so repeated conversions stay fast
- `/tools create-uuid` generates one UUID immediately, then lets you press `Enter` to generate another or `Esc` to go back to `/tools`
- `/secrets list` returns to the `/secrets` chooser after `Press Enter to continue`, while the input-driven `/secrets` actions reopen their selected flow
- press `Esc` from an interactive prompt or continue screen to go back one Gerber menu level at a time; backing out of a top-level submenu returns to the visible root `/` chooser before the blank home prompt
- press `Esc` twice within 200 ms from shared Gerber prompts, menus, and continue screens to return directly to the root prompt without exiting Gerber
- type `/tools` to preview `create-uuid`, `base-64` and `/tools base-64` previews `encode` and `decode`
- with AzureDevOps active, type `/list` to preview `ado-agents` and `ado-team-members`, plus any other active plugin-provided list actions
- with AzureDevOps active, type `/pipelines` to preview `tags delete` and `tags update`
- with AzureDevOps active, type `/branch` to preview `find` and `set-searchable`
- with AzureDevOps active, type `/repository` to preview `create`
- type `/plugins` to preview `create`, `disable`, `enable`, `info` and `list`
- type `/secrets` to preview `list`, `get`, `test`, `set`, and `remove`
- the selected suggestion shows a short help preview before you submit it

Examples inside the palette:

```text
/tools create-uuid
/tools base-64 encode
/tools base-64 decode
/list ado-agents
/pipelines tags delete
/pipelines tags update
/branch find
/branch set-searchable
/repository create
/plugins
/plugins list
/plugins info Gerber.Example
/plugins create
/update list
/help
/secrets list
/secrets test
/secrets set
```

### `/update`

`/update` opens the shared submenu with **list** and **policy**, like `/secrets`.
`/update list` shows installed/available versions, repository and status for Core
and installed, associated, approved, enabled plugins. Core always uses PSGallery.
Plugins use their installed manifest's `PrivateData.Gerber.Repository = { Name, Uri }`:
the table shows `Name`, while PMU receives the canonical `Uri`. The name remains
visible when lookup is unavailable or finds no matching package. Absent repository
metadata defaults to PSGallery and its official endpoint; invalid explicit metadata
never falls back. Legacy `RepositoryUri` remains supported: the official Gallery
URL shows PSGallery, while custom URLs keep their raw display until a name is added.
The canonical object takes precedence when both keys exist.
When plugin rows exist, use arrow keys and Space to select available updates,
then Enter to review. A required Core update is visibly added before the combined
confirmation. Trust/license-gated package inspection needs separate consent for
a temporary download without installation. **Cancel is the default** at both
consent prompts. PMU installs sequentially, Core first when required; dependent
plugins are blocked on Core failure while independent updates continue.
Results keep installation, verification, recovery and fresh-process activation
separate; activation failure does not turn an installed package into a failed
installation. Cancellation stops future attempts. There is no first installation,
hot reload or batch rollback. Repository credentials are requested per operation,
never read from native storage or saved in plugin metadata.
After a verified successful update requiring restart, or discovery of an
already-installed newer Core, choose **Exit Gerber** or **Continue with current
version** (the default; Esc also continues). Exiting Gerber does not restart
PowerShell: restart PowerShell yourself, then run `gerber`. Continuing retains
the restart reminder; Core and plugins are not reloaded in this session.
An unreachable repository is not reported as "up to date". Startup checks never
install, request installation consent or access native credential storage.
An unpublished package is reported without inventing an available version.

See [Core and plugin updates](docs/core-updates.md) for repository binding,
channel selection, dependency delivery and qualification limits.

`/update policy` saves **Stable only** (default) or **Include prereleases** in
your user configuration. Core startup checks and Core/plugin `/update list`
checks use the same choice; plugin discovery remains manual-only.
The current choice is preselected: `Enter` saves it, and `Esc` leaves it unchanged.
Changing the policy performs no update check or installation, clears any old
startup notification and takes effect on the next `/update list`. After saving,
press `Enter` to return to the `/update` submenu.

### `/tools create-uuid`

Gerber includes a UUID generator under `/tools`:

- `/tools create-uuid` generates a standard hyphenated UUID with no braces
- the UUID is shown in the terminal and copied to the clipboard when possible
- after each UUID, `Enter` generates another and `Esc` returns to the `/tools` chooser

### `/tools base-64`

Gerber now includes a text-focused Base64 utility under `/tools`:

- `/tools base-64 encode` reads one line of UTF-8 text and returns its Base64 value
- `/tools base-64 decode` reads one line of Base64 text, ignores surrounding whitespace and line breaks, and returns decoded UTF-8 text
- results are shown in the terminal and copied to the clipboard when Gerber finds a supported clipboard command
- invalid decode input stays inside Gerber and shows a recoverable in-app error
- `Esc` backs out one level and `Esc Esc` within 200 ms returns straight to the Gerber root prompt

### `/list ado-agents`

The active **Gerber.AzureDevOps** plugin contributes this report under `/list`:

- `/list ado-agents` shows BUILD pools first and DEPLOY pools second
- Azure DevOps connection settings come from `Gerber.AzureDevOps.json` under `ado.defaultProfile` and `ado.profiles`
- when no suitable profile exists, Gerber can configure one inline, continue the same command, and store the chosen project URL under a named profile
- when exactly one profile exists without a default, Gerber offers to use it now; when multiple profiles exist without a default, Gerber lets you choose one and optionally save it as the default
- The plugin retrieves the PAT only when authentication is required, through its GUID-scoped Secrets capability and logical path `ado/<profile>/pat`
- when the profile exists but the PAT is missing, Gerber prompts for the token without re-asking for the project URL or profile name
- Azure DevOps PATs remain in secure credential storage, never environment variables or JSON
- pools and agents are sorted for predictable scanning
- pools with no agents still appear with an explicit empty-pool message
- missing BUILD or DEPLOY pool sections are called out explicitly
- agent versions are color-coded consistently per run and followed by a version legend
- after `Press Enter to continue`, Gerber returns to the main menu

### `/list ado-team-members`

The active **Gerber.AzureDevOps** plugin contributes this report under `/list`:

- `/list ado-team-members` shows all projects and their teams with member counts in a compact summary
- drill-in navigation lets you explore project → team → members without leaving the Gerber session
- export the full report as JSON, CSV, or HTML to the current directory with a timestamped file name (e.g. `gerber-ado-team-members-20250101-120000.json`)
- the HTML export includes a browser-side input that filters all rows in real time
- export can be triggered at the summary level or after viewing a team's members; multiple formats can be exported in a single session
- Azure DevOps connection settings come from `Gerber.AzureDevOps.json` under `ado.defaultProfile` and `ado.profiles`
- Gerber retrieves the active profile's PAT from secure credential storage only when the report needs authentication
- first use follows the same inline Azure DevOps setup flow as the other authenticated ADO commands
- non-interactive runs do not prompt; they fail with guidance to configure the profile and native credential first
- after `Press Enter to continue`, Gerber returns to the main menu

### `/pipelines`

`/pipelines` is available while an active plugin contributes a pipeline action.
Gerber.AzureDevOps contributes tag-maintenance commands only when approved and
enabled. Additional plugins may share the root; empty intermediate menus such
as `/pipelines tags` disappear when their last available action is removed.

### `/pipelines tags delete`

The active **Gerber.AzureDevOps** plugin contributes this flow under `/pipelines`:

- `/pipelines tags delete` asks for the current tag, finds every Azure DevOps build/run that still carries that tag, and shows those matches in one checkbox selector grouped by pipeline name
- each tagged run starts selected, so you can delete the tag from one, many, or all matching runs in the same batch
- the confirm step shows both the runs that will be changed and the runs that will be skipped before Gerber removes anything
- apply removes the current tag from each selected run; failures are collected per run while the rest of the selected batch continues
- after `Press Enter to continue`, Gerber returns to the `/pipelines tags delete` flow so another tag batch can be cleaned up without leaving the submenu

### `/pipelines tags update`

The active **Gerber.AzureDevOps** plugin contributes this flow under `/pipelines`:

- `/pipelines tags update` asks for the current tag and the replacement tag, finds every Azure DevOps build/run that currently carries the old tag, and shows those matches in one checkbox selector grouped by pipeline name
- each tagged run starts selected, so you can update one, many, or all matching runs in the same batch
- the confirm step shows both the runs that will be updated and the runs that will be skipped before Gerber changes anything
- apply removes the old tag and adds the new tag on each selected run; failures are collected per run while the rest of the selected batch continues
- after `Press Enter to continue`, Gerber returns to the `/pipelines tags update` flow so another tag batch can be updated without leaving the submenu

### Shared product roots

Gerber composes `/branch`, `/list`, `/repository` and `/pipelines` from available
plugin contributions instead of exposing empty historical Core menus.
AzureDevOps owns `/repository create`, `/branch find`,
`/branch set-searchable` and `/branch set-default`, alongside the reports and
tag flows above. Their placement, arguments and navigation remain unchanged;
they are not relocated under `/ado`. Other plugins own and qualify their own
product commands; Core supplies no historical Azure DevOps API facade.

### `/plugins`

Gerber includes a plugin administration surface under `/plugins`:

- `/plugins` shows one overview table for all plugin identities known to Gerber
- `/plugins list` shows discovered manifest data plus persisted lifecycle records in one merged inventory; generated plugins show their known name/version even before installation
- `/plugins info <plugin>` shows detailed metadata and lifecycle state for one plugin, looked up by manifest GUID or unique module name
- `/plugins enable` approves and enables an installed inactive plugin (including declined ones) and loads its commands immediately
- `/plugins disable` disables an active plugin, keeps its approval, and removes its commands immediately; it never uninstalls the module
- `/plugins create` asks for a module suffix (fixed `Gerber.` prefix), description, collision-free command namespace, repository and destination parent (current directory by default), then generates and validates a working Plugin API v1 Nova project
- PSGallery is preselected and generates an explicit `Manifest.PrivateData.Gerber.Repository` object with `Name: PSGallery` and `Uri: https://www.powershellgallery.com/api/v2`, without extra questions. Another repository asks for its name, then URL. Blank names can be corrected locally; Enter for an unknown URL records `REPLACE_WITH_REPOSITORY_URI` in `Repository.Uri`. Replace it in `project.json` and rebuild before remote publishing or updates. Local build, tests and local publication still work. Invalid metadata never falls back to PSGallery
- successful creation approves, associates and enables the new manifest GUID without installing/loading the module; run `Publish-NovaModule -Local` from the generated project, restart Gerber and try its `/mycompany hello` example
- creation never overwrites a destination; invalid input can be corrected and `Esc` cancels without approval. The creation handler retains a Nova availability check and consent-based installation fallback; that on-demand safeguard does not make Nova optional in `RequiredModules`
- explained, separated creation fields show the actual cwd and project-child defaults; completion shows name/version/namespace/location, repository name and URI, and explicitly says Installed: No
- generated projects include a complete Unreleased changelog and agent-first development resources, with AGENTS.md as the canonical self-contained guide and thin Claude/Copilot bridges
- selecting a plugin to enable is explicit approval; there is no additional approval prompt
- enable and disable decisions persist across sessions, and menus, completion, and dispatch update without restarting Gerber
- `list` and `info` remain read-only
- opening `/plugins` does not trigger plugin approval prompts and does not import unknown, declined, or disabled plugins just to inspect them
- declined plugins remain visible even when they were never associated or are no longer discovered on disk
- missing associated plugins remain visible through persisted configuration; cached generated name/version are display-only fallback, installed manifest metadata takes precedence, and older associations retain their GUID-only fallback. Gerber never invents publisher or path metadata

`/plugins` keeps four lifecycle concepts separate in the terminal output:

- **Approval** — `Approved`, `Declined`, or `Unknown`
- **Association** — whether Gerber tracks the plugin in `plugins.associated`
- **Enabled state** — whether an associated plugin is enabled or disabled
- **Loaded state** — whether this Gerber session actually imported and registered the plugin

Current read-only commands also keep these terms distinct:

- **Declined** means Gerber persisted a decision not to load the plugin automatically
- **Disabled** means the plugin is still approved and associated, but its commands are unavailable until `/plugins enable` activates it again
- **Revoked** is a future security-management concept and is not the same as declined or disabled

If multiple discovered plugins share the same module name, `/plugins info` requires the manifest GUID instead of guessing. Gerber rejects activation of a different GUID that conflicts with an active plugin's module name. Plugins can add commands beneath Core commands or their own commands, but not beneath another plugin's commands.

See [Create a Gerber plugin](docs/plugins-create.md) for the exact generated tree,
validation/rollback behavior, isolated local publish and the working hello example.

Plugin authors can validate an uninstalled project with
`Test-GerberPluginBoundary -Path ./Gerber.MyCompany` from installed Gerber.
The result includes `IsValid`, deterministic source diagnostics and a `PublicApi`
operation inventory. Generated projects run `./scripts/Test-PluginBoundary.ps1`
before the normal Nova workflow, and creation checks staged source before
execution/approval. This is a development-time architecture check, not a sandbox
or a change to installed-plugin permissions. See the
[detection contract and limits](docs/architecture/plugin-api-v1-capabilities.md#development-time-boundary-validation).

### `/secrets`

Gerber includes a credential-management surface backed by secure credential storage:

- `/secrets list` shows Gerber-managed credential identifiers without reading secret values
- `/secrets get` shows the stored Gerber keys first, copies the selected secret to the clipboard when possible, and then asks for explicit confirmation before revealing the value in the terminal
- `/secrets test` reports whether an identifier exists without retrieving its value
- `/secrets set` reads a value without terminal echo, stores it under a Gerber-owned identifier, and asks before overwriting an existing value
- `/secrets remove` shows the stored Gerber keys first, then removes a stored Gerber-owned credential with Gerber-owned confirmation and messaging
- secure storage remains OS-backed and never falls back to plaintext files or environment variables
- when secure credential storage is unavailable, Gerber fails with actionable guidance and never falls back to plaintext storage
- pressing `Enter` at the bare `/secrets` chooser opens `list`

Gerber restricts identifiers to the case-insensitive `gerber:<scope>:<name>`
namespace. Plugin credentials use `gerber:plugin:<plugin-guid>:<path>`.
AzureDevOps uses its own GUID and the logical `ado/<profile>/pat` path.
Legacy `gerber:ado:<profile>:pat` entries remain untouched and are not reused.
This naming prevents accidental collisions but is not process isolation.

See [Credential service architecture](docs/architecture/credential-service.md) and [Native credential-store verification](docs/credential-store-verification.md) for backend prerequisites, packaging details, and manual cross-platform checks.

## Plugin approval and lifecycle

Gerber identifies plugins by the GUID in their PowerShell module manifest. Before an unknown plugin is imported, Gerber shows its name, GUID, version, publisher metadata, and manifest location, then asks whether to approve it. Decline is the default and leaves the module installed without registering its commands.

Gerber persists three separate lifecycle concepts:

- **Approved** — the plugin GUID is allowed to run
- **Associated** — Gerber tracks that plugin as part of the user's Gerber environment
- **Enabled** — Gerber may import the module and register its commands

Approved GUIDs and associated plugin state are stored in the existing user configuration:

```json
{
  "schemaVersion": 1,
  "plugins": {
    "approved": [
      "977537c5-b7f5-4f2f-9dd4-5ec0e28d2618"
    ],
    "declined": [
      "11111111-2222-3333-4444-555555555555"
    ],
    "associated": {
      "977537c5-b7f5-4f2f-9dd4-5ec0e28d2618": {
        "enabled": true
      }
    }
  }
}
```

Approvals survive ordinary plugin updates because identity is GUID-based rather than version- or content-hash-based. The first successful approval also associates and enables the plugin without a second confirmation prompt. Existing approved plugins without an explicit association record remain usable and pick up the associated+enabled record the next time Gerber discovers them. Declined GUIDs are also persisted, so Gerber does not ask again for the same unknown plugin on the next startup; `/plugins enable` lets users explicitly change that decision. During noninteractive startup, Gerber loads approved and enabled plugins, skips unknown plugins without prompting or autoapproving them, and keeps associated disabled-plugin records even when the module is temporarily unavailable. GUID approval records user intent for a plugin identity; it does not prove publisher identity or code authenticity.

The read-only `/plugins list` and `/plugins info` commands surface those persisted states directly:

- approved + enabled + loaded plugins appear as available and loaded
- approved + disabled plugins remain visible but not loaded
- declined plugins remain visible and inspectable, even without an association record
- associated plugins that are currently missing from disk remain visible through their persisted GUID record

Use `/plugins enable` to approve and activate a previously declined plugin, or `/plugins disable` to deactivate an approved plugin without revoking approval.

## Azure DevOps first-use setup

Gerber.AzureDevOps prepares access lazily, only when its active command needs a
connection or PAT. The plugin owns profile validation, setup and ADO transport.

- startup, `/help`, `/secrets`, plugin discovery, and unrelated commands do not trigger Azure DevOps setup
- if no profile exists, Gerber offers to create one inline by asking only for the Azure DevOps project URL, connection name, optional default-profile choice, and PAT when the command needs authentication
- if a named profile is requested and missing, Gerber offers to configure that exact profile instead of silently switching to another one
- plugin ADO operations keep the selected connection context explicit, so multiple named profiles can coexist in one session without switching a global current connection
- Azure DevOps Services and Server both use the existing URL parser; when a Server URL needs an explicit root, Gerber asks for the minimum extra server-root input and still applies the existing HTTP safety rules
- PAT entry uses a non-echoing prompt and the plugin's existing Secrets capability under its manifest GUID
- Gerber resolves PATs lazily for plugin ADO operations; metadata-only plugin calls do not trigger PAT lookup or PAT setup prompts
- cancellation leaves existing configuration unchanged and stops the pending command cleanly
- if configuration saves but credential storage fails, Gerber reports the incomplete state clearly so the same command can be retried safely
- if Azure DevOps rejects a stored token later, Gerber distinguishes an invalid/rejected PAT from insufficient PAT permissions instead of treating every 401/403 as "missing PAT"

## Public PowerShell commands

Gerber exposes the interactive entry point as a PowerShell command:

- `Invoke-Gerber`

Command help for each entry point lives under `docs/Gerber/en-US/`.

## Test strategy

Gerber uses source-mirrored Pester tests under `tests/` plus a shared test helper in `tests/TestHelpers/`.
Interactive terminal regressions live under `tests/terminal/` and run the real built app through a PTY-backed Python harness that reconstructs ANSI screens, answers cursor-position requests, and writes sanitized failure artifacts.

The current suite covers:

- command parsing and invalid commands
- interactive menu behavior
- secret-management flows
- tool-specific interactions such as Base64 flows
- PTY-backed prompt rendering and cursor movement
- generic Plugin API discovery, dispatch, configuration, credential, clipboard and recovery contracts through `Gerber.TerminalFixture`
- error formatting and prompt behavior

Azure DevOps domain tests and product terminal scenarios live in the
Gerber.AzureDevOps repository. It can be built and tested independently through
Nova; built-module integration uses the required Core API without private
module-scope shortcuts. Later distribution qualification still requires the
published PSGallery plugin and a separately owned internal-repository plugin.

Run the zero-finding validation flow with:

```powershell
./scripts/build/Invoke-ScriptAnalyzerCI.ps1
Invoke-NovaBuild
Invoke-NovaTest
Test-NovaBuild
./scripts/build/Invoke-TerminalRegressionCI.ps1 -Category core
./scripts/build/Invoke-TerminalRegressionCI.ps1 -Category synthetic
```

Or run the repository quality loop in the same order:

```powershell
pwsh -NoLogo -NoProfile -File ./run.ps1
```

Run the tracked PTY regression suite explicitly with:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/build/Invoke-TerminalRegressionCI.ps1
```

Gerber's terminal suite inventories and covers Gerber Core commands only. The bundled
`Gerber.TerminalFixture` separately verifies the generic Plugin API contract; product plugins own
their command and workflow regressions in their own repositories.

## Prompt tracing

If slash-command autocomplete still behaves differently in your terminal, enable prompt tracing before you start Gerber:

```powershell
$env:GERBER_PROMPT_TRACE = '1'
Invoke-Gerber
```

Gerber writes JSON trace lines to `.gerber/prompt-debug.log` in the current working directory. The trace records:

- whether Gerber used the interactive prompt or fell back to `Read-Host`
- each key read from the terminal
- suggestion refreshes and applied completions

Clear the environment variable when you are done tracing:

```powershell
Remove-Item Env:GERBER_PROMPT_TRACE
```

## Known limitations

- The UI uses simple terminal rendering with `Clear-Host`; it is not a full-screen TUI framework.
- `/tools base-64` is text-focused in v1 and does not cover file or arbitrary binary workflows.
- slash-command autocomplete focuses on the built-in Gerber commands and their known subcommands.
- Linux credential operations require a desktop Secret Service session, D-Bus, and `libsecret`; headless systems without that backend fail clearly.
