# Create a Gerber plugin

Run `/plugins create` inside Gerber. The command uses Core's existing plugin menu,
shared text inputs and Escape navigation; it is not a general-purpose generator.

## Inputs

| Prompt | Example | Meaning |
| --- | --- | --- |
| Module suffix | `MyCompany` | Creates **Gerber.MyCompany**. `Gerber.` is fixed, not editable. Use letters and numbers, starting with a letter. |
| Description | `My local tools` | Stored as the project and generated manifest description. |
| Command namespace | `mycompany` | A real, lowercase slash namespace. Letters, numbers and hyphens are allowed, starting with a letter. An already registered namespace is rejected. |
| Plugin repository | Enter for **PSGallery**, or select **Another repository** | PSGallery is preselected and writes `Repository.Name = PSGallery` and `Repository.Uri = https://www.powershellgallery.com/api/v2`, without more repository questions. |
| Repository name (another repository only) | `ExampleFeed` | Required display label in `Manifest.PrivateData.Gerber.Repository.Name`. Blank input is corrected at this prompt. |
| Repository URI (another repository only) | `https://packages.example.org/feed`, or Enter if unknown | Canonical endpoint in `Manifest.PrivateData.Gerber.Repository.Uri`. Enter writes the explicit invalid placeholder `REPLACE_WITH_REPOSITORY_URI`. |
| Destination parent | Enter, or an existing directory | Defaults to the current working directory. The final project is always a new **parent/Gerber.MyCompany** child. |

Suffixes and namespaces are limited to 64 characters. Names cannot contain dots,
slashes, whitespace or path traversal. Parent directories must already exist and
must not contain `..` path segments. Existing destinations are never overwritten,
including when another process creates the destination during validation.
Invalid input can be corrected in place; a destination collision lets you choose
another suffix or parent. `Esc` cancels through normal Gerber back navigation.
The repository chooser appears after the namespace and before the destination.
Known URIs must be absolute and must not contain credentials, query parameters or
fragments. Invalid URI input stays at the prompt with correction guidance;
`Esc` from the chooser, name or URI prompt cancels without creating a project.

Generated metadata uses this object in `project.json`:

```json
{
  "Repository": {
    "Name": "ExampleFeed",
    "Uri": "https://packages.example.org/feed"
  }
}
```

Place it under `Manifest.PrivateData.Gerber`; do not add an `Update` intermediary
or credentials. `/update list` shows the name and sends the URI to PMU.

Each field has a heading, description, example and surrounding spacing. The
destination shows the actual current directory and proposed child, not a hardcoded
example path. Enter accepts that parent; an explicit parent still gets the child.
The completion screen shows the actual Name, Version, Namespace, Location, GUID
and repository name and URI,
then Approval: Approved, Associated: Yes, Enabled: Yes and **Installed: No**.
Its `cd` path is PowerShell-single-quoted (including escaped apostrophes), followed
by local publish, restart and the actual namespaced hello command.
An unknown-source summary explicitly requires replacing
`Manifest.PrivateData.Gerber.Repository.Uri` before remote publishing or updates.
Local build, tests and isolated local publish still work with the placeholder;
it is not a usable repository URL.

## Required runtime toolchain

NovaModuleTools is a **required runtime dependency of Gerber**, not only tooling
for developing the Gerber repository: Gerber exposes plugin creation and uses
Nova for build/test, packaging and local publication workflows. Gerber owns
plugin-specific inputs, templates and approval. Both NovaModuleTools and
PSModuleUpdate remain in Gerber's `RequiredModules`; PMU owns generic update
installation, not plugin-project build/publication. See [D-002 / D-017](../DECISIONS.md)
and the [current dependency contract](architecture/G-4A5-update-architecture.md#5-required-runtime-dependencies-decided-declarations-present).

The current command is `/plugins create`; `/create` is not a registered root alias.
Nova lifecycle operations are on demand, not required on every Gerber startup.
The existing creation handler retains an availability check and, if Nova is
missing, offers this installation:

```powershell
Install-Module -Name NovaModuleTools
```

That fallback requires explicit consent; cancel is the default. Declining creates
neither a project nor an approval. It is not a guarantee that Gerber imports
without its required modules. Earlier generated-lifecycle validation used
NovaModuleTools 3.4.1 with PowerShell 7.4-compatible source; it is historical
evidence, not fresh qualification of the current Nova `3.4.2` declaration.

## Generated project

For the example above, Gerber owns these initial sources:

```text
Gerber.MyCompany/
  .gitignore
  project.json
  README.md
  CHANGELOG.md
  AGENTS.md
  CLAUDE.md
  .github/copilot-instructions.md
  .github/instructions/powershell.instructions.md
  .github/instructions/pester.instructions.md
  .github/instructions/nova-project.instructions.md
  .github/agents/plugin-developer.agent.md
  .github/skills/plugin-command-development/SKILL.md
  .github/skills/gerber-plugin-api/SKILL.md
  .github/skills/nova-development/SKILL.md
  scripts/Test-PluginBoundary.ps1
  src/public/Get-GerberPlugin.ps1
  src/private/Get-PluginCommandDefinitionList.ps1
  src/private/Get-PluginHelloHandler.ps1
  src/private/Get-PluginMenuHandler.ps1
  tests/PluginTestSupport.ps1
  tests/public/Get-GerberPlugin.Tests.ps1
  tests/public/Get-GerberPlugin.Integration.Tests.ps1
  tests/private/Get-PluginCommandDefinitionList.Tests.ps1
  tests/private/Get-PluginHelloHandler.Tests.ps1
  tests/private/Get-PluginMenuHandler.Tests.ps1
```

There is no handwritten source module root or manifest. Nova generates:

```text
dist/Gerber.MyCompany/Gerber.MyCompany.psd1
dist/Gerber.MyCompany/Gerber.MyCompany.psm1
docs/schema/v0/project.json        # Nova project schema
artifacts/UnitTestResults.xml
artifacts/TestResults.xml
artifacts/coverage.xml
```

Nova owns build, tests, packaging and publishing. `project.json` owns version,
description, canonical `Manifest.GUID` and `Manifest.PrivateData.Gerber` metadata.
Nova propagates that GUID into the generated manifest; the public definition
matches it and Gerber approval/association use it. Keep it stable through updates.
Do not duplicate it inside `PrivateData.Gerber`:

```json
{
  "Manifest": {
    "GUID": "69a7dd2e-1f6b-4428-9b11-50f57bb8fea6",
    "PrivateData": {
      "Gerber": {
        "Plugin": true,
        "ApiVersion": "1",
        "MinimumGerberVersion": "0.1.0-preview"
      }
    }
  }
}
```

That example represents PSGallery selection: there is no `RepositoryUri` key,
not an empty value or an explicit Gallery override. Another repository adds a
direct `"RepositoryUri": "https://packages.example.org/feed"` entry inside
`Manifest.PrivateData.Gerber`; no `Update` intermediary is generated. If the URI
is unknown, replace `"RepositoryUri": "REPLACE_WITH_REPOSITORY_URI"` in
`project.json` with the actual safe URI, then rebuild before remote publication
or updates. Nova carries this metadata into the generated plugin manifest.
Update discovery defaults to PSGallery only when the key is absent. An explicit
placeholder, empty/relative URI, or unsafe URI is rejected without Gallery
fallback or package lookup.

The GUID above is illustrative; generation creates a unique one. The generated
changelog starts with the product's Keep a Changelog/SemVer introduction,
`[Unreleased]` and all six categories: Added, Changed, Deprecated, Removed, Fixed,
Security. The real `/mycompany hello` example belongs under Added; no stable
release or date is fabricated.

The source-only unit tests and built-module public-entry-point integration tests
exercise the example without Azure, PATs, customer configuration or private Core
calls.

## Agent-first development

**AGENTS.md** is the canonical agent-neutral guide: product/host boundaries,
authored versus generated paths, permanent identity, lifecycle, concrete steps
for adding/registering a handler and tests, the public Configuration/UI/Http/Secrets/Clipboard
contract, Nova commands, coverage/analyzer/CodeScene expectations and docs.
It is usable without access to private Core source.

**CLAUDE.md** and **.github/copilot-instructions.md** are thin bridges, not copies.
Three scoped instruction files use `applyTo` globs for PowerShell source, Pester
tests and project.json. The **plugin-developer** agent defines ownership and
boundaries; the three valid `SKILL.md` workflows provide actionable command,
public-API and Nova lifecycle steps. They do not assume a Core CI/analyzer wrapper
exists in the generated project, or grant permission to commit/release/install.
See generated AGENTS.md for the verified Nova 3.4.1 version/package/release
commands; normal development needs only build and both test commands.

## Name and version before installation

The same successful approval save adds optional `name` and `version` fields to
the normalized-GUID association record, alongside `enabled`. Immediately after
creation, the read-only inventory can show:

```text
Name              Version  GUID                                  Approval  Associated  State    Loaded
Gerber.MyCompany  0.1.0    <generated-manifest-guid>               Approved  Yes         Missing  No
```

The plugin remains approved, associated and enabled, **not installed or loaded**.
`/plugins info Gerber.MyCompany` also works before installation. GUID remains
identity; the cache is display fallback only while installed/loaded metadata is
absent. Discovered manifest metadata takes precedence, and older associations
without display metadata retain the GUID-only fallback without migration.
List/info never import, approve, install or save configuration.

## Validation and approval

Gerber generates into its own temporary staging directory under the chosen parent.
Before executing generated code, it runs the installed Core's AST Plugin API
boundary check on authored source. Private Core dependencies fail with
file/line/dependency/reason/resolution diagnostics and no GUID approval.
Before finalizing, it runs `Invoke-NovaBuild`, `Invoke-NovaTest` and
`Test-NovaBuild`, then checks actual plugin registration against an independent
copy of Core's live registry. It does not replace the live registry or install
the plugin during this check.

Only after all checks pass does Gerber move the project to the final destination
and reuse the existing explicit-approval lifecycle to approve, associate and
enable its GUID. No additional approval question is needed.
**Approved + associated + enabled does not mean installed or loaded.**

Validation failures leave no final project or approval and clean only Gerber's
own staging directory. Cancellation before generation has no such side effects.
If the final directory was created successfully but configuration persistence
fails, Gerber preserves that recoverable project and reports its exact path,
GUID and **not approved** state instead of claiming success. After fixing the
configuration problem, publish locally and use `/plugins enable` to approve it.

## Build, publish locally and try hello

The generated project needs no manual source changes:

```powershell
Set-Location ./Gerber.MyCompany
./scripts/Test-PluginBoundary.ps1
Invoke-NovaBuild
Invoke-NovaTest
Test-NovaBuild
Publish-NovaModule -Local
```

The script imports installed Gerber and calls its public
`Test-GerberPluginBoundary -Path <project>` command; it needs neither a private
Core checkout nor an active Gerber process or plugin installation. Inspect
`(Test-GerberPluginBoundary -Path .).PublicApi` to select an implemented operation,
then consult the [public API reference](architecture/plugin-api-v1-capabilities.md)
for signatures. Fix diagnostics using public operations or request a new public
capability; never import private Core code as a workaround.
The check is static, respects plugin-owned functions and ignores ordinary strings
and comments. Computed commands/imports and aliases still require review.
Passing does not mean runtime isolation, permissions or a PowerShell sandbox.

Local publish builds/tests and installs into the local PowerShell module directory;
it may replace an existing installation of that module. It does not publish
remotely. Use this form for an isolated development installation:

```powershell
Publish-NovaModule -Local -ModuleDirectoryPath /path/to/isolated/modules
```

Make that isolated directory discoverable through `PSModulePath` when testing it.
Restart Gerber with the same Gerber user configuration, then enter:

```text
/mycompany hello
```

Expected result: **Hello from Gerber.MyCompany!** The generated namespace also has
a shared-UI submenu. Startup discovers the same approved manifest GUID without
another approval prompt. Existing `/plugins enable` and `/plugins disable`
behavior is unchanged. Creation does not implement installation management,
remove, decline, revoke, remote distribution, marketplace or update workflows.
