---
document type: cmdlet
external help file: Gerber-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Gerber
ms.date: 11.01.2026
PlatyPS schema version: 2024-05-01
title: Invoke-Gerber
---

# Invoke-Gerber

## SYNOPSIS

Starts the interactive Gerber DevOps multitool.

## SYNTAX

### __AllParameterSets

```
Invoke-Gerber [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
- gerber


## DESCRIPTION

Gerber.AzureDevOps 0.1.0 is a declared RequiredModules dependency. Import alone does not approve, activate or register its commands. Normal discovery and saved approval/enable/disable rules remain authoritative.

`Invoke-Gerber` opens the interactive Gerber terminal workflow for the current working directory.
Startup attempts a bounded Gerber Core update check through PSModuleUpdate using
the fixed official PSGallery repository. An eligible available-version notification
refers to `/update list`; startup never installs, asks to install or requests credentials.
Offline, timed-out or no-matching-package checks leave the session usable without
claiming it is up to date. A read-only public PMU check on 2026-10-25 returned
installed/target 0.1.0 and UpToDate from PSGallery; no installation was attempted.
The session starts with a minimal prompt-first home screen and reveals matching root commands as you type `/`, or matching executable leaf action commands as you type plain text such as `uuid`, `base`, `ado`, or `help`.
The root prompt supports interactive autocomplete with `Tab`, `Up`, and `Down`, including help previews for matching commands.
Root browsing and completion show `/exit`, `/help`, `/plugins`, and `/update` first, in that order, followed by all remaining Core and active plugin root commands alphabetically. Submenu ordering is unchanged.
Pressing `Enter` accepts the highlighted suggestion and executes it once the selected command is complete, whether you started from slash input or plain root action-search text.
The currently selected suggestion is visually highlighted to stay readable across terminal themes while you navigate with arrow keys.
Bare submenu commands such as `/tools`, `/list`, `/pipelines`, `/branch`, `/repository`, `/plugins`, and `/secrets` open an inline submenu prompt that shows the available subcommands directly on the command line.
Nested submenu flows such as installed plugin tools and `/tools base-64` keep the same arrow-key suggestion behavior while narrowing the prompt to that tool's actions.
After `/tools base-64 encode` or `decode`, continue reopens the same action.
Azure DevOps commands are supplied by the approved, enabled Gerber.AzureDevOps
plugin, not built into Core. Their existing paths remain `/list ado-agents`,
`/list ado-team-members`, `/repository create`, `/branch find`,
`/branch set-searchable`, `/branch set-default`, `/pipelines tags delete`
and `/pipelines tags update`. The plugin owns profile selection, lazy setup,
reports/export, REST, retry and pagination, repositories, branches and pipelines.
Shared Enter, Escape and continue routing remain unchanged. Inactive plugins
contribute no commands; unrelated Core tools and secret management remain usable.
Press `Esc` from an interactive prompt or continue screen to return to the main Gerber menu.
Core retains the shared `/branch`, `/list`, `/pipelines` and `/repository` roots for active plugin contributions; Core tools, `/plugins`, `/update` and `/secrets` remain platform-owned.

`/plugins enable` lists installed inactive plugins, including previously declined or approved-but-disabled plugins. Selecting a plugin counts as explicit approval without an additional approval prompt. `/plugins disable` removes an active plugin's commands while preserving its approval and leaving its PowerShell module installed. Both actions update menus, completion, and dispatch immediately without restarting Gerber.

`/update` opens the shared list/policy submenu, consistent with other slash menus.
`/update list` performs fresh Core and eligible installed-plugin discovery and
shows installed/available versions, repository and status. Core always uses the
official PSGallery endpoint. Only discovered, associated, approved, enabled
plugins participate, using `PrivateData.Gerber.Repository` from the current
installed manifest: `Name` is displayed and canonical `Uri` is sent to PMU.
The name remains visible on unavailable/no-matching-package lookup results.
Absent metadata defaults to PSGallery and its official endpoint; invalid explicit
metadata never falls back. Legacy `RepositoryUri` is supported, mapping the
official Gallery URL to PSGallery and retaining custom raw URL display until a
name is added. Canonical metadata takes precedence when both keys exist.
Trust confirmations retain the actual URL. Startup remains Core-only.

When plugin rows exist, use Up/Down and Space in the shared checkbox to select
available updates, then Enter to review. Exact selected-package inspection checks
GUID, Plugin API v1 and required Core version. Trust/license-gated inspection
requires separate default-Cancel consent for temporary download without
installation. A required Core candidate is visibly added to the combined
default-Cancel installation preview, with full versions, source, scope and
operation-local trust/license choices. Unavailable Core requirements block the
dependent plugin. Empty selection cancels; Esc follows shared back navigation.
Noninteractive views render all status rows without prompting or installing.

After acceptance, PMU installs the original plans sequentially, Core first when
needed. Core failure blocks dependent plugins while independent updates continue;
individual plugin failures do not stop independent later attempts, but user
cancellation does. Results separate installation, verification, recovery and
fresh-process activation. An installed package remains Installed even when
activation fails. There is no first installation, hot reload or batch rollback.
Repository credentials are requested through per-operation secure input, never
saved in metadata or fetched from native storage. Restart PowerShell, then run
`gerber` before using installed components.

Failed discovery is not "up to date". `/update policy` selects Stable only
(default) or Include prereleases for Core startup and Core/plugin manual
discovery. The current choice is preselected; Enter saves,
Esc cancels, and continue returns to the chooser. Selection performs no discovery
or installation and clears an old startup notification only after a channel change.
Esc returns to the update submenu; continuing after list results returns there too.
Gerber requires numeric PSModuleUpdate 0.2.0 or later, currently available from
PSGallery. The local plugin-update implementation additionally uses a new PMU
target-manifest inspection API that is not published in 0.2.0. The declared minimum
is unchanged; source builds and disposable tests do not deploy those APIs or
qualify hosted/live plugin updates. Dependency installation remains a separate,
explicitly approved action. Gerber does not automatically migrate or clean up
local Gerber copies.
When PMU reports installed and available 0.1.0 with disposition UpToDate,
the Available column shows 0.1.0 and no installation is offered. PMU remains
the sole discovery and version-selection authority, using the fixed official
PSGallery endpoint, selected channel and CurrentUser scope. The separate upstream
PackageNotFound classification correction is locally implemented but unpublished;
Gerber uses NoMatchingPackage only for explicit PMU.PackageNotFound. Published
0.2.0 can still report a generic discovery failure. Neither outcome proves Core
is current or establishes complete live-install qualification.
Building this checkout does not replace installed or loaded PMU for an existing
`gerber` launcher. A failed check remains Available `-` / Unavailable.
PMU does not select or migrate flat-only Gerber copies as versioned
installations; an unsupported layout is not a PSGallery failure.
Structured PMU.UnsupportedInstallation errors now receive generic supported
numeric-version module directory guidance: restart PowerShell after arranging
a supported installation, then retry `/update list`. Gerber does not parse provider
text, assume every such error is flat-only, or claim installation/rollback success.
An existing installed Gerber copy needs a separate update to receive this
source diagnostic; no automatic installation migration is performed.

`/plugins create` asks for a module suffix behind a fixed `Gerber.` prefix,
description, unused command namespace, repository choice, and existing
destination parent (current directory by default). The shared repository chooser
appears after the namespace and defaults to PSGallery, which writes an explicit
`Manifest.PrivateData.Gerber.Repository` object with its `Name` and official `Uri`
without further repository questions. Another repository asks for its name,
then a known absolute URI without credentials, query or fragment, or Enter if
unknown. Blank names are corrected locally. Known URIs are stored in
`Repository.Uri`, without an Update intermediary; Enter writes
`REPLACE_WITH_REPOSITORY_URI`. Invalid URI input stays at the prompt with
correction guidance, and shared Esc cancels from the chooser, name or URI input
without creation or approval. It generates and validates a working Plugin API v1 Nova
project in a new child directory without overwriting existing files. Successful
creation approves, associates and enables the generated manifest GUID, but does
not install or load the plugin. Run `Publish-NovaModule -Local` from that project,
restart Gerber and try its namespaced `hello` command. NovaModuleTools and
PSModuleUpdate are mandatory runtime dependencies. Nova lifecycle operations run
on demand; the creation handler's missing-tool fallback requires consent. Shared `Esc`
navigation cancels, and invalid input can be corrected without approval.
Creation fields have separated headings, descriptions, examples and visible
current-directory/project-child defaults. The completion summary shows actual
name, version, namespace, location, repository name and URI, and lifecycle state,
explicitly Installed: No. A placeholder summary requires replacing
`Manifest.PrivateData.Gerber.Repository.Uri` before remote publishing or updates.
Build, tests and isolated local publish still work; update consumption rejects
the explicit placeholder without package lookup or Gallery fallback.
Read-only list/info show the generated name and initial version before installation
using GUID-keyed association display metadata; discovered manifest metadata wins.
Generated projects use only the canonical manifest GUID and include a complete
Unreleased changelog plus AGENTS.md, thin Claude/Copilot bridges, scoped
instructions, a plugin development agent and actionable command/API/Nova skills.

## EXAMPLES

### Example 1

Start the interactive Gerber session.

```powershell
Invoke-Gerber
```

### Example 2

Start the same session through the module alias.

```powershell
gerber
```

### Example 3

Use plain-text root search to jump directly to a leaf action.

```text
uuid
ado
help
```

### Example 4

Use autocomplete inside the root prompt.

```text
/
/to<Tab>
uuid
/tools
```

### Example 5

Use the interactive Base64 tool after Gerber starts.

```text
/tools
/tools base-64
/tools base-64 encode
/tools base-64 decode
/list
/list ado-agents
/pipelines
/pipelines tags delete
/pipelines tags update
/branch
/branch find
/branch set-searchable
/branch set-default
/repository
/repository create
/repository review
/plugins
/plugins list
/plugins info
/plugins enable
/plugins disable
/secrets
/secrets list
/secrets get
/secrets test
/secrets set
/secrets remove
```

### Example 6

Review Core and eligible installed-plugin updates inside Gerber. Use arrow keys
and Space to select available components when plugin rows exist. Review any
automatically added Core requirement before confirming. Cancel is the default;
no installation occurs without acceptance.

```text
/update list
```

## PARAMETERS

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

You cannot pipe input to this cmdlet.

## OUTPUTS

### System.String

Gerber writes terminal-oriented status and help text while the interactive session is running.

## NOTES

Core updates always explicitly use PSGallery and its official endpoint.
This application-owned repository cannot be overridden by user settings,
environment variables or plugin configuration and has no fallback or chooser.
Obsolete `updates.modules.Gerber` settings are ignored without rewriting
unrelated configuration. Core never reports Unconfigured or retrieves credentials.
The channel is saved as optional `coreUpdates.channel` in existing user
configuration: Stable by default, or IncludePrerelease for stable releases and
previews. Plugins share this channel for manual checks only. Startup's Core-only
child process uses the same file, including GERBER_CONFIG_PATH.
Missing values do not create configuration; explicit invalid values are errors.
Save failures and noninteractive policy dispatch do not change the channel.
Changed-policy installation plans require a new `/update list` check.
PMU handles installed prerelease metadata: stable `0.1.0` can supersede
`0.1.0-preview`; Stable excludes newer prereleases.
No matching package is not a configuration error, a currency claim or
permission to install. Disposable fixture checks do not qualify live installation.
Startup retains a 2,000 ms child-process budget with no persistent cache.
Noninteractive update views do not prompt or install.
Module import alone performs no update check or Nova lifecycle operation.

Plugin enable and disable decisions are saved in the existing Gerber user configuration and survive restarts. Disabled plugins cannot execute commands through Gerber until enabled again. Plugin inventory and details remain read-only.
The `/tools base-64` utility is text-focused in v1, shows results in the terminal, and copies them to the clipboard when Gerber finds a supported clipboard command.
Gerber resolves Azure DevOps connections lazily: startup, `/help`, `/secrets`, plugin discovery, and unrelated commands do not prompt for Azure DevOps configuration, while authenticated ADO commands can configure a missing profile or missing PAT inline and then continue the same command.
When no Azure DevOps default profile is configured, Gerber uses the configured default when present, offers to use the single existing profile when exactly one profile exists, lets the user choose when multiple profiles exist, and offers to configure the explicitly requested profile instead of silently switching to a different one.
Core lifecycle/platform settings use GerberCore.json; Azure DevOps profiles use
Gerber.AzureDevOps.json in the same platform-resolved directory. Plugin API v1
provides identity-bound Configuration.Read and Configuration.Save without paths
or Core access. Missing files return null; invalid JSON is reported, not replaced;
writes are atomic. The repeatable legacy config.json transition preserves unknown
and destination settings, retains originals on conflict/failure, and deletes the
old file only after verified transfer. It never changes approval or credentials.
The AzureDevOps plugin uses Secrets under GUID
a468dee5-c7a0-43e4-ae88-bb19158fe679 and logical path ado/<profile>/pat.
Missing PATs are entered again during interactive authenticated use; legacy Core
credentials are never automatically reused, migrated or deleted. Noninteractive
missing credentials do not open prompts. PATs are not stored in JSON or diagnostics.
The `/list ado-agents` report reads Azure DevOps connection settings from `Properties.json`, queries automation and deployment task pools, keeps empty sections and empty pools explicit, color-codes version lines consistently per run, shows a version legend, and retrieves the active profile PAT from secure credential storage only when authentication is required.
The `/pipelines tags delete` workflow asks for the current tag, lists every Azure DevOps build/run that still carries that tag, groups the checkbox selection screen by pipeline name, removes the tag on each selected run, continues across per-run failures, and shows one final deleted / failed / skipped summary before it returns to the same tag-delete flow after `Press Enter to continue`.
The `/pipelines tags update` workflow asks for the current tag and replacement tag, lists every Azure DevOps build/run that still carries the current tag, groups the checkbox selection screen by pipeline name, removes the old tag and adds the new tag on each selected run, continues across per-run failures, and shows one final updated / failed / skipped summary before it returns to the same tag-update flow after `Press Enter to continue`.
The `/repository review` workflow is contributed by the Gerber.ExampleOrg plugin. Gerber Core supplies the shared command registry plus the public Plugin API, while Gerber.ExampleOrg owns the review rules in `Gerber.ExampleOrg/src/resources/Properties.json`, accepts either a PR number in the configured project or a full PR URL, uses the same Gerber-owned Azure DevOps connection-readiness flow as Core commands, reviews the whole relevant file for each changed path, groups results by the standard DevOps review categories, shows that Markdown review in the terminal, and copies the same text for PR notes when clipboard copy is available.
The `/secrets` menu uses secure credential storage, accepts case-insensitive Gerber identifiers such as `gerber:<scope>:<name>`, lists only non-sensitive identifiers, supports existence checks with `/secrets test`, copies a selected value to the clipboard before any terminal reveal when possible, and asks for confirmation before revealing, overwriting, or removing sensitive values.

## RELATED LINKS

- [Gerber project](https://github.com/stiwicourage/GerberCore)
