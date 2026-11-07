# Plugin API v1 capabilities

This is the implemented public context supplied to approved, enabled Gerber
plugins. Operations are scriptblocks invoked with `&`. `ApiVersion` remains
`"1"`; `PluginId` is the registered manifest GUID.

[`/plugins create`](../plugins-create.md) generates a minimal UI consumer.
Gerber.AzureDevOps is a separate reference plugin for the configuration,
Secrets, UI and HTTP metadata capabilities it actually uses. Azure DevOps
profiles, authentication, REST and product operations belong to that plugin,
not a Core `Ado` capability. Core supplies no historical ADO facade.
Consumers of the new Configuration/UI/Http operations must declare
`MinimumGerberVersion` of at least `0.2.1-preview02`, the Core version supplying
them; API v1 alone does not establish capability availability in older Core.

## Capability inventory

### Configuration

| Operation | Signature | Purpose |
| --- | --- | --- |
| `Read` | `()` | Read the registered plugin's own JSON; missing files return null without creating a file. |
| `Save` | `($Value)` | Serialize and atomically publish the plugin's own JSON. |

Core binds the capability to the discovered, registered module name. Its file is
`<ModuleName>.json` beside the resolved Core file, for example
`Gerber.AzureDevOps.json` beside `GerberCore.json`. Plugins cannot provide a
filename, another module name or an arbitrary path through this API. A collision
with an explicitly selected Core file is rejected.

The plugin owns the JSON structure, defaults and domain validation. Maps,
arrays, scalars and null are supported; no Core schema or metadata is added.
JSON strings remain strings, including ISO timestamps and their original offsets;
Core does not infer a date schema.
Invalid JSON raises an actionable file-specific error and is not replaced by
defaults, including on Save. Serialization failures and failed publication
preserve the previous file; staged files are cleaned up. File writes use the
shared atomic publication and platform permission infrastructure.

```powershell
$settings = & $Gerber.Configuration.Read
if ($null -eq $settings) { $settings = @{ preferredView = 'summary' } }
& $Gerber.Configuration.Save $settings
```

Do not save PATs, passwords or tokens in JSON. Use Secrets instead. This API
does not inspect content for secrets or migrate credentials.
`GERBER_CONFIG_PATH` is an absolute Core-file override; plugin files follow its
directory. A legacy `config.json` override selects sibling `GerberCore.json`.
Core's bounded legacy transition transfers non-ADO fields to Core and the
`ado` section to AzureDevOps JSON, preserving unknown fields. Conflicts retain
originals with guidance; partial failures are retryable. The old file is removed
only after complete verification. Normal plugin reads do not access Core data,
and transition does not approve or activate a plugin.

### UI

| Operation | Signature | Purpose |
| --- | --- | --- |
| `ReadSubcommand` | `($CommandName, $Command, $SubcommandTable, $AutoSelectFirstSuggestionOnSubmit = $false)` | Reuse inline submenu navigation; optionally preserve default Enter selection. |
| `ShowTextBlock` | `($Title, $Text)` | Render result and error screens. |
| `ShowScreenLines` | `($Title, $LineList)` | Render an action screen. |
| `ReadNumberedMenuSelection` | `($Prompt, $ScreenTitle, $ScreenText, $MenuItemList)` | Reuse numbered selection. |
| `ReadNumberedMenuPrompt` | `($Prompt, $ScreenTitle, $ScreenText, $MenuItemList)` | Reuse a numbered prompt. |
| `ReadCheckboxMenuPrompt` | `($PromptRequest)` | Reuse checkbox selection. |
| `ReadConfirmationPrompt` | `($Prompt, $ScreenTitle, $ScreenText, $PromptOptionSet)` | Reuse confirmation. |
| `ReadCommand` | `($Prompt, $SuggestionMode, $InputMode, $PromptContext, $TrimResult)` | Reuse inline command input. |
| `ReadSecretText` | `($Prompt)` | Read secret text with neutral Escape handling. |
| `ReadSecureValue` | `($Prompt)` | Read a SecureString, preserving Escape exceptions for callers that own cancellation. |
| `IsInteractive` | `()` | Check whether interactive prompt input is available. |
| `IsEscapeException` | `($Exception)` | Recognize the shared Escape/back exception. |
| `GetEscapeException` | `()` | Create the shared Escape/back exception. |
| `StartScreen` | `($Name)` | Start a screen region. |
| `WriteScreenLine` | `($Text = '')` | Write a screen line. |
| `WriteStyledPromptText` | `($Text, $Style)` | Render with an existing Gerber prompt-style object. |
| `GetPromptColorPair` | `()` | Read the platform prompt foreground/background colors. |
| `ShowMenuError` | `($Message)` | Render a recoverable Gerber-owned menu error. |
| `WriteProgressBar` | `($Current, $Total, $Prefix, $OverwritePreviousRender)` | Render progress. |
| `WritePromptTrace` | `($EventName, $Data = @{})` | Emit prompt diagnostics; never supply secrets. |
| `WaitForContinue` | `()` | Reuse continue-screen navigation. |

These operations retain existing input, rendering, Escape and pipeline-stop
semantics. Plugins must check interactive availability before first-use setup;
noninteractive missing credentials must not open prompts.

### Http

| Operation | Signature | Purpose |
| --- | --- | --- |
| `GetConfiguration` | `()` | Read shared `ConnectionTimeoutSeconds` and `OperationTimeoutSeconds`. |
| `GetTransportFailureHint` | `($Exception)` | Obtain shared DNS/network or timeout recovery guidance. |
| `IsTimeoutFailure` | `($Exception)` | Recognize nested task-cancellation timeout failures. |

This is platform metadata and error classification, not authenticated HTTP
transport. GET retries, mutations and endpoint-specific pagination remain
product-plugin responsibilities.

### Secrets

| Operation | Signature | Purpose |
| --- | --- | --- |
| `EnsureReady` | `($ActionLabel, $ScreenTitle)` | Verify secure storage availability. |
| `Test` | `($PathSegmentList)` | Check a plugin-owned secret without retrieving it. |
| `GetText` | `($PathSegmentList)` | Retrieve text for immediate in-memory use. |
| `Set` | `($PathSegmentList, $Secret)` | Create or update the secret. |
| `Remove` | `($PathSegmentList)` | Remove the plugin-owned secret. |

Core maps logical paths to `gerber:plugin:<manifest-guid>:<path>`.
AzureDevOps uses `@('ado', $ProfileName, 'pat')` under GUID
`a468dee5-c7a0-43e4-ae88-bb19158fe679`. It does not automatically reuse, migrate
or delete legacy `gerber:ado:<profile>:pat` credentials. A missing PAT is entered
again at interactive authenticated use; metadata-only operations need no PAT.
Never log, trace, display in errors or JSON-store retrieved values.

### Clipboard

| Operation | Signature | Purpose |
| --- | --- | --- |
| `CopyText` | `($Value)` | Copy through the platform clipboard abstraction and fallback messaging. |

## Ownership and lifecycle

Core owns command composition, UI, configuration placement/persistence,
credential infrastructure, clipboard and plugin lifecycle. Plugins own product
semantics. JSON and secret namespaces prevent accidental cross-plugin API
access, not arbitrary PowerShell execution: this is a programming contract,
not process isolation or a sandbox.

Module import does not register commands or imply Gerber approval. Discovery,
GUID approval, association and enable/disable rules are unchanged. Declined
and disabled plugins contribute no commands; non-ADO Core tools remain usable.

The published command tree contains only standalone actions and menus with
available descendants. Plugins may share menu paths; removing one plugin does
not remove another plugin's actions beneath the same root. Empty menu-only
ancestors disappear after the last contribution is disabled and return when a
contributor is enabled. Menu browsing, completion, help and direct resolution
all use that tree, not separate visibility filters.

Mark a menu-only command definition or subcommand catalog entry with
`IsContainer = $true`. It is available only with an available descendant;
its menu handler alone is not a standalone action. Missing ancestors of
registered actions are created as shared containers automatically.
Existing API v1 handlers without this optional flag retain their standalone
behavior, including commands that perform an action and also have subcommands.

## Development-time boundary validation

The exported development command does not start Gerber, read user configuration,
require Nova, install the target plugin or execute its source:

```powershell
Import-Module Gerber
$result = Test-GerberPluginBoundary -Path ./Gerber.MyCompany
$result.PublicApi
$result.Diagnostics | Format-Table File, Line, Dependency, Reason, Resolution -Wrap
if (-not $result.IsValid) { throw 'Fix plugin API boundary diagnostics.' }
```

`PublicApi` lists operation names for `Configuration`, `UI`, `Http`, `Secrets`
and `Clipboard`, derived from the actual API context. It is not a parameter
schema. Private ownership derives from actual Core definitions, including
same-file siblings, minus exports; there is no broad prefix ban.

### Detection and diagnostics

The validator parses authored `.ps1`, `.psm1` and `.psd1` under `src/`,
`scripts/` and root entrypoints/manifests. It does not scan tests, `dist/`,
`artifacts/` or agent prose outside authored roots.
Diagnostics contain project-relative slash-normalized `File`, one-based `Line`
and `Column`, `Dependency`, `Reason` and actionable `Resolution`. They sort
deterministically and deduplicate. Missing project/source directories terminate;
syntax errors become `ParseError` diagnostics. Source is never executed.

| Case | Policy |
| --- | --- |
| Direct private call, literal call operator or `Gerber\PrivateName` | Report `PrivateCoreCommand` and a directly mapped public operation, or explicitly state that no equivalent exists. |
| One prior unconditional literal assignment or literal string concatenation | Resolve conservatively; reassigned, conditional or computed variables remain unresolved. |
| Literal `Get-Command`/`gcm` or `Invoke-Expression`/`iex` target | Report identifiable private names; explicit external module ownership is respected. |
| Core-private source imports or direct Core implementation module import | Report `CoreImplementationImport`; use the public manifest and context. |
| Core module-scope invocation or SessionState access | Report `CoreModuleScope`; ordinary module inspection remains allowed. |
| Public operations, exports, external commands or plugin-owned functions | Allowed; explicit Core qualification cannot be hidden by local declarations. |
| Ordinary strings and comments | Ignored except identifiable execution/lookup contexts. |

### Limits and lifecycle

This static architecture guardrail is not a security scanner or permissions
model. It does not execute aliases/expressions, resolve arbitrary dataflow,
establish load order or prove computed imports safe. External same-name
commands need explicit external qualification; unresolved dependencies require
manual review and a public capability where needed.
It diagnoses identifiable Core module scope/state access, not every possible
configuration access.

Generation validates staged authored source before Nova execution, finalization
and approval. Invalid generation uses existing owned-stage cleanup and never
approves its GUID. Installed discovery, approvals, inventory and registration
retain their existing contracts; this check is not a new runtime approval rule.
