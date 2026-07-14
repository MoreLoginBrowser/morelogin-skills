# Install MoreLogin Setup

Use this guide when preparing, installing, updating, or verifying MoreLogin Client and `ml-cli` on macOS, Windows, or Linux.

The agent may download files, reveal or open installers, set executable permission on downloaded CLI binaries, and verify installation. It must not accept Terms of Services, EULA, UAC, Gatekeeper, administrator prompts, sudo prompts, privacy permissions, firewall prompts, or other security/user confirmations on behalf of the user.

## Agent Entry Flow

First detect the operating system and CPU architecture, then run the matching official bootstrap command.

Windows x64 PowerShell:

```powershell
irm https://releases.morelogin.com/client/prod/install_1.0.ps1 | iex
```

macOS or Linux:

```bash
curl -fsSL https://releases.morelogin.com/client/prod/install_1.0.sh | bash
```

On Windows, run the PowerShell command directly. Do not replace `Invoke-RestMethod` (`irm`) with `curl.exe`; Codex and other sandboxed agents may run `curl.exe` under a different Windows Schannel or credential context from the user's interactive PowerShell session.

If the Windows agent cannot execute the PowerShell bootstrap after requesting the required permission, use the official x64 direct-download fallback instead of asking the user to copy the same command repeatedly:

- Client: `https://cb-gateway.morelogin.com/app/ver/public/latest/redirect?identify=MoreLogin_AirDrop_window_x64`
- CLI: `https://cb-gateway.morelogin.com/app/ver/public/latest/redirect?identify=MoreLogin_AirDrop_window_x64_cli`

Download only the missing components without changing their contents. Open the Client installer and leave UAC, EULA, and installer confirmation to the user. If the Client installer provides `ml-cli`, verify that copy before downloading the separate CLI. Otherwise, save the CLI as `%USERPROFILE%\.morelogin\bin\ml-cli.exe`, add that directory to the current user's PATH when permitted, and verify the CLI first by its absolute path. A download URL does not automatically authorize or launch an executable; request GUI-launch permission when the agent environment requires it.

Keep the command running while large files download. Use a long-running command session and continue polling until the bootstrap finishes or reaches a prompt that requires the user. Do not report installation as complete merely because `ml-cli` was installed; verify MoreLogin Client separately.

If the agent sandbox blocks external network access, localhost access, file downloads, or GUI application launch, request the required permission and retry the same platform command. Do not silently substitute a different downloader or repeatedly restart the installation.

Platform handoff rules:

- Windows: reveal or open the downloaded Client installer. If it cannot be opened, show its exact path and ask the user to double-click it.
- macOS: open or reveal the downloaded installer. If the installer window is not visible, show its exact path and ask the user to open it in Finder.
- Linux: show the downloaded package path and the required installation command. Do not run `sudo` or perform a system-wide installation without explicit user approval.

Do not accept UAC, sudo, Terms of Service, EULA, Gatekeeper, administrator, firewall, privacy, login, CAPTCHA, or verification-code prompts on the user's behalf.

## Install Source

The bootstrap scripts are published by MoreLogin at the release URLs below. The website can expose short install commands such as:

```bash
curl -fsSL https://releases.morelogin.com/client/prod/install_1.0.sh | bash
```

```powershell
irm https://releases.morelogin.com/client/prod/install_1.0.ps1 | iex
```

By default, the scripts install or update `ml-cli`, then check whether MoreLogin Client is installed. If the Client is already installed, they skip its download and do not externally update it. If it is missing, they resolve the latest Client package, download it, and open or reveal the installer where possible.

For CLI-only installation or automated script testing, skip the Client check explicitly:

```bash
curl -fsSL https://releases.morelogin.com/client/prod/install_1.0.sh | MORELOGIN_SKIP_CLIENT=1 bash
```

```powershell
$env:MORELOGIN_SKIP_CLIENT="1"; irm https://releases.morelogin.com/client/prod/install_1.0.ps1 | iex
```

During the default flow, the script stops at any installer, Terms of Services, EULA, Gatekeeper, UAC, administrator, privacy, or firewall prompt for the user to confirm manually.

On Linux/Ubuntu, the script downloads the Client package and prints the next manual command instead of running privileged installation. For `.deb`, it prints `sudo apt install "<downloaded-file>"`; for `.AppImage`, it marks the file executable and prints the launch command.

For manual installation, resolve the current platform download URL from the MoreLogin release API, then download the returned URL.

Place the downloaded CLI binary in a user-owned installation directory and make it executable (`chmod +x ml-cli` on Unix). The Windows bootstrap script may add its user-owned install directory to the current user's PATH. Do not modify machine-level PATH or install into system directories without explicit user approval.

## Platform Detection

Detect OS and architecture before downloading anything.

Normalize architectures:

- `arm64`, `aarch64` -> `arm64`
- `x86_64`, `amd64`, `x64` -> `x64`

Use these package identifiers when resolving MoreLogin Client and CLI URLs from the release API:

| Platform | Arch | Client identify | CLI identify |
|---|---:|---|---|
| macOS | arm64 | `MoreLogin_AirDrop_darwin_arm64` | `MoreLogin_AirDrop_darwin_arm64_cli` |
| macOS | x64 | `MoreLogin_AirDrop_darwin_x64` | `MoreLogin_AirDrop_darwin_x64_cli` |
| Windows | x64 | `MoreLogin_AirDrop_window_x64` | `MoreLogin_AirDrop_window_x64_cli` |
| Linux | x64 | `MoreLogin_AirDrop_linux_x64` | `MoreLogin_AirDrop_linux_x64_cli` |

If the current OS/arch pair is not listed, stop and tell the user it is unsupported.

## Resolve Latest URLs

For CLI installation/update and Client first-time installation, request:

```text
https://cb-gateway.morelogin.com/app/ver/public/latest?identify=<identify>
```

Expected response:

```json
{
  "code": 0,
  "msg": null,
  "data": "https://releases.morelogin.com/...",
  "success": true
}
```

Rules:

- `success` must be `true`
- `code` must be `0`
- `data` must be a non-empty URL
- If any check fails, stop and show the raw response

Use `data` as the download URL only after all validation below succeeds:

- The release API URL must use HTTPS and the exact host `cb-gateway.morelogin.com` with path `/app/ver/public/latest`.
- The response must contain `success: true`, `code: 0`, and a non-empty `data` URL.
- The download URL must use HTTPS and an explicitly allowed MoreLogin host. Do not accept suffix matches such as `releases.morelogin.com.example.org`.
- For CLI artifacts on `releases.morelogin.com`, require `/prod/<identify>/` and require the filename to contain the same `<identify>`. For Client artifacts, require `/prod/client/<platform>/<arch>/`, a matching `MoreLogin_<os>_<arch>_` filename, and the expected platform package type.
- For artifacts on `get.morelogin.com`, require the `/client/prod/` path, current platform and architecture path, and the expected CLI filename or MoreLogin Client package type. Do not accept another platform's artifact.
- Reject custom ports, user information in URLs, IP addresses, localhost, non-HTTPS URLs, unexpected hosts, and mismatched platform artifacts.
- Do not follow redirects while resolving the API or downloading artifacts. A redirect could leave the validated host; stop and report it instead.

The published `install_1.0.sh` and `install_1.0.ps1` enforce these checks before writing or opening a downloaded artifact.
They also print the platform `identify`, release API request URL, complete JSON response, and validated download URL so version-resolution problems can be diagnosed from installer output.

Do not use this API to force-update an already installed MoreLogin Client. If the Client is already installed, skip external Client package download and tell the user they can update it from inside the MoreLogin Client.

## Download Location

Prefer a user-visible location:

- macOS: `~/Downloads`
- Windows: `%USERPROFILE%\Downloads`
- Linux: `~/Downloads`

If Downloads is unavailable, use the current workspace and tell the user the exact path.

Do not overwrite an existing file silently. If the file exists, either reuse it after confirming it matches the expected file, or download with a unique suffix.

The bootstrap scripts may reuse an existing installer only after confirming it matches the latest validated release URL and is usable:

- Windows requires the exact latest filename, a non-empty file, a valid Authenticode signature, and version metadata that identifies MoreLogin. Pin the official signer Subject or certificate thumbprint before release when the release team provides the authoritative allowlist; do not guess signing identities.
- macOS and Linux require the exact latest filename, a non-empty file, a successful platform-native package or archive validation, and a matching remote size when the server provides one.

When these checks pass, skip the Client download and use the existing installer. Otherwise, preserve the existing file with an `.invalid-<timestamp>` suffix, download to a `.part` file, validate the completed download, and atomically move it to the expected latest filename. An interrupted `.part` download may be resumed, but it must never be opened as an installer.

## CLI Presence And Update Check

Check the configured user-owned install path first, then check whether CLI is globally available:

```bash
ml-cli --help
```

If available:

1. Check the installed version:

   ```bash
   ml-cli --version
   ```

2. Preview the latest update:

   ```bash
   ml-cli self-update --dry-run
   ```

   Without `--version`, `--dry-run` queries the official latest-version API for the current OS/architecture, validates the returned `data` URL, and prints the latest lookup URL, final download URL, and target path without replacing the binary.

3. Compare the installed version with the version resolved from the validated latest download URL. If the installed version is equal to or newer than the API version, skip the download. If the installed version is older, update `ml-cli`:

   ```bash
   ml-cli self-update
   ```

4. Verify the updated CLI:

   ```bash
   ml-cli --version
   ml-cli --help
   ```

5. Continue to Client presence check.

If `self-update` is not available in the installed CLI, resolve the current platform CLI URL and update by downloading the latest CLI binary/package. Do not overwrite or replace the current CLI binary unless the user approves the target path.

If unavailable:

1. Resolve the current platform CLI URL.
2. Download the CLI package or binary.
3. Prepare it according to platform.
4. Verify with `--help`.
5. Use the downloaded CLI path for later verification if it is not installed globally.

Installing into a user-owned directory is part of the requested CLI installation. Do not use machine-level PATH, system directories, administrator privileges, or `sudo` without separate user approval.

### macOS CLI

If the CLI URL points to a raw binary:

- Save as `~/.local/bin/ml-cli` by default
- Run `chmod +x <cli-path>`
- Verify with `<cli-path> --help`

Do not install to `/usr/local/bin` or `/opt/homebrew/bin` as part of the default flow.

### Windows CLI

If the CLI URL points to an `.exe` or raw Windows executable:

- Save as `%USERPROFILE%\.morelogin\bin\ml-cli.exe` by default
- The bootstrap script may add `%USERPROFILE%\.morelogin\bin` to the current user's PATH
- Verify with PowerShell:

```powershell
& "$env:USERPROFILE\.morelogin\bin\ml-cli.exe" --help
```

Do not modify machine-level PATH or copy the CLI to system directories.

### Linux CLI

If the CLI URL points to a raw binary:

- Save as `~/.local/bin/ml-cli` by default
- Run `chmod +x <cli-path>`
- Verify with `<cli-path> --help`

Do not install to `/usr/local/bin`, `/usr/bin`, or other system locations as part of the default flow.

## Client Presence Check

Before resolving or downloading the Client installer, check whether MoreLogin Client is already installed.

Do not use CLI presence as proof that Client is installed. MoreLogin CLI and MoreLogin Client are separate components.

If MoreLogin Client is already installed, do not resolve the latest Client URL and do not download a Client update package. Client updates can be handled by the user inside the MoreLogin Client.

### macOS Client Check

Check common app locations:

```text
/Applications/MoreLogin.app
~/Applications/MoreLogin.app
```

If found:

- Do not download the Client installer.
- Try launching with `open -a MoreLogin`.
- Continue to post-install verification.

### Windows Client Check

Check common install locations:

```text
%LOCALAPPDATA%\Programs\MoreLogin
%PROGRAMFILES%\MoreLogin
%PROGRAMFILES(X86)%\MoreLogin
```

Also check whether a MoreLogin executable is discoverable in those locations.

Do not treat a directory alone as proof of installation. Require an actual `MoreLogin.exe`; application-data or leftover directories may exist after uninstall.

If found:

- Do not download the Client installer.
- Try launching the discovered executable or tell the user it is already installed.
- Continue to post-install verification.

### Linux Client Check

Check common executable/application locations:

```text
which morelogin
which MoreLogin
~/.local/bin
~/Applications
/opt
/usr/local/bin
/usr/bin
```

Also check common desktop entry locations:

```text
~/.local/share/applications
/usr/share/applications
```

If found:

- Do not download the Client installer.
- Try launching only if it does not require elevated privileges.
- Continue to post-install verification.

## Client Installer

Only resolve and download the Client installer if MoreLogin Client is not already installed, or if the user explicitly asks to reinstall.

If the user asks to update an already installed Client, tell them to use the MoreLogin Client's built-in update flow unless official MoreLogin documentation gives a specific external update procedure.

Resolve and download the Client installer for the current platform, then handle it by platform.

### macOS Client Handling

Expected installer is usually `.dmg`.

1. Download the DMG, or reuse the latest validated local copy.
2. Run `open <dmg-path>` to try opening the installer.
3. Run `open -R <dmg-path>` only if opening the installer fails and it needs to be revealed in Finder. Do not run both commands unconditionally.
4. Check whether a MoreLogin volume appears under `/Volumes`.
5. If the DMG does not mount or the user cannot see the window, give the exact DMG path and tell the user to double-click it in Finder.
6. Do not run `hdiutil attach -agree`.
7. If Terms of Services, Gatekeeper, administrator, privacy, or network prompts appear, stop and ask the user to confirm manually.

After the user completes installation:

- Check `/Applications` for MoreLogin.
- Try `open -a MoreLogin`.

### Windows Client Handling

Expected installer is usually `.exe` or `.msi`.

1. Download the installer, or reuse the latest validated local copy. When the bootstrap script cannot run, use the official Client direct-download URL from Agent Entry Flow.
2. Reveal it in Explorer:

```powershell
explorer.exe /select,"<installer-path>"
```

3. Open installer only if appropriate:

```powershell
Start-Process "<installer-path>"
```

4. If UAC, EULA, installer wizard, firewall, or privacy prompts appear, stop and tell the user to confirm manually.
5. Do not pass silent install flags unless official MoreLogin documentation explicitly provides them and the user asks for unattended installation.

If revealing the installer in Explorer fails, still try to launch the installer. Explorer reveal is a convenience and must not block `Start-Process`.

After the user completes installation:

- Check common install locations for verification.
- Try launching MoreLogin through the Start Menu path or installed executable if discoverable.

### Linux Client Handling

The API may return an AppImage, deb, rpm, tar archive, zip archive, or raw binary. Infer from filename or content type when possible.

Rules:

- Do not run `sudo` without explicit user approval.
- Do not install packages system-wide without user approval.
- Prefer preparing the installer/package and showing the next manual step.

Handling:

- `.AppImage`: run `chmod +x <path>` and run it only if the user expects GUI launch.
- `.deb`: reveal or show the download path; tell the user installation may require `sudo apt install ./<file>.deb`.
- `.rpm`: tell the user installation may require `sudo dnf install ./<file>.rpm`.
- `.tar.gz` / `.zip`: extract only to a user-writable location.
- Raw binary: run `chmod +x <path>` and run only if no system installation is required.

After the user completes installation, verify the executable or application launch path if discoverable.

## Verify Installation

```bash
ml-cli --version
ml-cli doctor --output-json
ml-cli agent-bootstrap
ml-cli agent-guide
```

If CLI is only available as a downloaded path:

```bash
<cli-path> agent-bootstrap
<cli-path> agent-guide
```

If localhost errors such as `connect EPERM 127.0.0.1:40000` occur:

- Treat it as AI-client sandbox/localhost permission first.
- Request local access or elevated execution.
- Do not repeatedly restart the same profile.

## Update

```bash
ml-cli self-update                   # query latest API and update to latest
ml-cli self-update --dry-run         # preview latest lookup URL, download URL, and target path
ml-cli self-update --version 2.7.0   # install specific version
```

Run the CLI update check even when `ml-cli` is already installed. Without `--version`, `self-update` queries the official latest-version API and updates to the newest available CLI. Do not externally update an already installed MoreLogin Client; let the user update it inside the Client.

## Configure AI Agent

```bash
ml-cli agent-list
ml-cli agent-init --agent <agent> --scope user --dry-run
ml-cli agent-init --agent <agent> --scope user --write
```

Supported agent names are provided by:

```bash
ml-cli agent-list
```

## Safety Boundaries

Never:

- Accept Terms of Services or EULA for the user.
- Bypass Gatekeeper, UAC, sudo, administrator prompts, privacy prompts, firewall prompts, or security warnings.
- Modify machine-level PATH or install into system directories without explicit user approval.
- Use silent install flags unless the user explicitly requests it and MoreLogin officially documents them.

Always:

- Check CLI and Client separately.
- Check and update `ml-cli` when a newer version is available.
- Skip Client download when Client is already installed.
- Do not externally update an already installed MoreLogin Client.
- Show exact downloaded file paths.
- Open or reveal installers where possible.
- Explain what user confirmation is required.
- Continue verification after the user confirms installation is complete.
