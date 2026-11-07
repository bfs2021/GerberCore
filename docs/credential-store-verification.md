# Native credential-store verification

Run these checks on each supported platform after installing the published Gerber module. Use a disposable identifier such as `gerber:test:manual:<platform>` and a non-production value.

The separate native-platform CI lane runs isolated Core and Plugin API credential round trips; see [Contributing](../CONTRIBUTING.md) for setup and the feature-branch rollout. Those checks do not replace the interactive, new-session, and authenticated-command checks below.

## Common procedure

1. Install and import Gerber:

   ```powershell
   Install-Module Gerber
   Import-Module Gerber -Force
   Invoke-Gerber
   ```

2. Run `/secrets set`, enter the disposable identifier, and enter a test value at the non-echoing prompt.
3. Run `/secrets list` and confirm the identifier is listed without its value.
4. Run `/secrets test` and confirm the status is `Stored`.
5. Run `/secrets get`, confirm the clipboard/reveal prompt behavior, and verify the value.
6. Run `/secrets set` again, approve overwrite, and store a different value.
7. Start a new PowerShell session, import Gerber, and confirm `/secrets get` returns the updated value.
8. Run `/secrets remove`, then confirm `/secrets test` reports `Not stored`.
9. In a disposable environment with Gerber.AzureDevOps approved and enabled,
   configure a profile at authenticated first use. Its PAT belongs to the
   plugin GUID's Secrets namespace, not the legacy Core identifier.
10. Remove that disposable plugin PAT and confirm interactive ADO use requests
    it again, while noninteractive use reports missing credentials without
    prompts. Unrelated Core commands must still work. Do not remove or migrate
    pre-existing Core credentials; product checks belong to the plugin.

## macOS

Expected backend: Apple Keychain.

- Run the common procedure in a normal logged-in macOS user session.
- If macOS displays a Keychain security prompt, review and answer the native prompt; Gerber does not bypass it.
- Optionally confirm that Keychain Access contains an entry in the `Gerber` application namespace.

## Windows

Expected backend: Windows Credential Manager.

- Run the common procedure in PowerShell 7.4 or later under the intended Windows user account.
- Optionally inspect Windows Credential Manager after creation and after removal.
- Confirm no additional PowerShell SecretManagement or SecretStore module is required.

## Ubuntu with Secret Service

Expected backend: Secret Service through `libsecret`.

- Use a graphical user session with D-Bus and a supported Secret Service provider, such as GNOME Keyring.
- Install the distribution's `libsecret` runtime package when it is not already present.
- Run the common procedure from PowerShell 7.4 or later in that user session.

## Ubuntu without Secret Service

On a headless session or a system without D-Bus, `libsecret`, or a Secret Service provider:

1. Import Gerber and start `Invoke-Gerber`; both should work without credential initialization.
2. Run `/secrets list` or another explicit credential operation.
3. Confirm Gerber reports that native credential storage is unavailable and identifies the Linux Secret Service prerequisites.
4. Confirm Gerber does not create a plaintext credential file or fall back to configuration or environment-variable storage.
