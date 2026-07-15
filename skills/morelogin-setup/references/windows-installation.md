# Windows Installation

Use this reference for Windows x64 MoreLogin Client detection, installation, UAC,
and verification. The unified `ml-cli client` workflow currently supports Windows
x64 only.

## Contents

- [Installed-state detection](#installed-state-detection)
- [Unified CLI workflow](#unified-cli-workflow)
- [Host and UAC gates](#host-and-uac-gates)
- [Legacy fallback](#legacy-fallback)
- [Verification](#verification)

## Installed-State Detection

Check candidates in this order:

1. HKCU/HKLM uninstall entries, including WOW6432Node, and
   `App Paths\MoreLogin.exe`.
2. `%LOCALAPPDATA%\Programs\MoreLogin`, `%PROGRAMFILES%\MoreLogin`, and
   `%PROGRAMFILES(X86)%\MoreLogin`.
3. Exact `MoreLogin.lnk` shortcuts in current/all-users Start Menu and Desktop.

Resolve every candidate to an actual `MoreLogin.exe`. Require MoreLogin product
metadata, valid Authenticode, and signer `EASYANT PTE. LTD.` as specified in
[release security](./release-security.md). A registry entry, directory, or shortcut
alone is not proof of installation. Registry absence is not proof of absence because
a custom/per-user installation may only expose a trusted shortcut target.

If installed, do not resolve, download, or launch an external Client updater. Return
or explain `nextAction: "update_in_client"` when an update is available.

## Unified CLI Workflow

Run:

```powershell
ml-cli client status --output-json
ml-cli client install --interactive --output-json
```

Parse the single JSON object:

| `status` / `nextAction` | Required action |
|---|---|
| `installed` / `none` | Stop external installation; continue connectivity verification. |
| `installed` / `update_in_client` | Tell the user to update inside MoreLogin. |
| `not_installed` / `install` | Continue only when installation was requested. |
| `installer_ready` / `install` | Installer is verified but not launched; request interactive execution if desired. |
| `launch_requested` / `approve_uac` | Tell the user to approve UAC and complete the wizard; keep the task open. |
| `user_action_required` / `double_click_installer` | Try one approved outside-sandbox run, otherwise report `installerPath` for manual double-click. |
| `unsupported` | Stop and report the unsupported OS/architecture. |
| `error` / `retry` | Show `reason`; retry only after correcting that condition. |

When `installerVerified` is true, report `signatureStatus` and `publisher`.
`launchRequested` means Windows accepted the request; it does not prove UAC approval,
wizard completion, or successful installation.

## Host And UAC Gates

Treat these as separate manual gates:

1. The AI host may require permission for GUI or outside-sandbox execution.
2. Windows UAC may appear on the secure desktop.

File-write or network permission is not GUI-launch permission. After host approval,
rerun exactly:

```powershell
ml-cli client install --interactive --output-json
```

Never automate UAC or infer cancellation merely because the AI cannot see the secure
desktop. Do not rerun after `launch_requested`, and do not launch a duplicate after a
timeout. Wait for the user to confirm whether the wizard completed.

## Legacy Fallback

Use only when the installed CLI lacks `ml-cli client`:

1. Resolve and fully validate the latest installer.
2. Request launch with:

   ```powershell
   Start-Process -FilePath "<installer-path>" -Verb RunAs
   ```

3. Do not use `MainWindowHandle` as success proof; bootstrap installers may create a
   different process and UAC may be on the secure desktop.
4. If launch throws an error, reveal the verified file:

   ```powershell
   explorer.exe /select,"<installer-path>"
   ```

5. Report the exact path and ask the user to double-click it.

Do not pass silent-install flags unless the user explicitly requests unattended
installation and official MoreLogin documentation supplies those flags.

## Verification

After the user says installation is complete:

```powershell
ml-cli client status --output-json
ml-cli doctor --output-json
```

Require `status: "installed"` from the first command. If `doctor` cannot access
localhost, request the AI host's localhost/outside-sandbox permission and retry once.
