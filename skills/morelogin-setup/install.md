# Install MoreLogin

Use this public entry guide to install, update, or verify MoreLogin Client and
`ml-cli`. Keep CLI and Client state separate: installing `ml-cli` does not prove the
MoreLogin Client is installed.

## Contents

- [Install MoreLogin](#install-morelogin)
  - [Contents](#contents)
  - [Fast Path](#fast-path)
  - [Decision Flow](#decision-flow)
  - [CLI Update](#cli-update)
  - [Fallback Downloads](#fallback-downloads)
  - [Verification](#verification)
  - [Safety Boundaries](#safety-boundaries)
  - [Detailed References](#detailed-references)

## Fast Path

Detect OS and CPU architecture, then run the matching official bootstrap.

Windows x64 PowerShell:

```powershell
irm https://releases.morelogin.com/client/prod/install_1.2.ps1 | iex
```

macOS or Linux:

```bash
curl -fsSL https://releases.morelogin.com/client/prod/install_1.0.sh | bash
```

Run the command with a long timeout and continue polling while files download. If
the AI host blocks network, filesystem, localhost, or GUI access, request the
matching host permission and retry the same command. Do not silently switch tools or
restart the flow repeatedly.

For CLI-only installation or automated bootstrap testing:

```powershell
$env:MORELOGIN_SKIP_CLIENT="1"; irm https://releases.morelogin.com/client/prod/install_1.2.ps1 | iex
```

```bash
curl -fsSL https://releases.morelogin.com/client/prod/install_1.0.sh | MORELOGIN_SKIP_CLIENT=1 bash
```

## Decision Flow

1. Detect platform and architecture. Stop if the pair is unsupported.
2. Check `ml-cli --version`.
3. If the CLI exists, preview latest with `ml-cli self-update --dry-run`; update only
   when latest is newer.
4. Check MoreLogin Client independently.
5. On Windows x64, use:

   ```powershell
   ml-cli client status --output-json
   ml-cli client install --interactive --output-json
   ```

6. If Client is installed, do not download or launch an external updater. Tell the
   user to update inside MoreLogin when needed.
7. If Client is missing, download or reuse only a fully validated current installer.
8. Open or reveal the installer, then stop at UAC, Gatekeeper, sudo, EULA, login, or
   any other user/security confirmation.
9. After the user reports installation complete, run the verification commands.

Read the matching platform reference before step 4:

- [Windows](./references/windows-installation.md)
- [macOS and Linux](./references/macos-linux-installation.md)

## CLI Update

Preview first:

```bash
ml-cli self-update --dry-run
```

Compare installed and resolved versions:

- `latest > installed`: run `ml-cli self-update`.
- `latest <= installed`: skip. Do not downgrade via the default latest flow.
- Explicit user request for a version: run
  `ml-cli self-update --version <version>`; this is the only flow that may
  intentionally downgrade.

After an update:

```bash
ml-cli --version
ml-cli --help
```

If persistent agent rules were installed, refresh them:

```bash
ml-cli agent-init --agent <agent> --scope user --write
```

## Fallback Downloads

Use a fallback only when the bootstrap or unified CLI flow is unavailable after the
required host permission has been requested.

Windows x64 latest shortcuts:

- Client: `https://cb-gateway.morelogin.com/app/ver/public/latest/redirect?identify=MoreLogin_AirDrop_window_x64`
- CLI: `https://cb-gateway.morelogin.com/app/ver/public/latest/redirect?identify=MoreLogin_AirDrop_window_x64_cli`

These two URLs are explicitly approved redirect entry points. Follow at most one
redirect and validate its `Location` before downloading: require HTTPS, an allowlisted
MoreLogin host, the expected platform and architecture, and the expected artifact
type. Do not treat this exception as permission to follow redirects from the JSON
release API or from an artifact URL.

Save the Windows CLI as `%USERPROFILE%\.morelogin\bin\ml-cli.exe`. Save Client
installers in `%USERPROFILE%\Downloads`. Do not modify machine PATH or install into
system directories without explicit approval.

For all URL, artifact, reuse, and signer requirements, read
[release and artifact security](./references/release-security.md).

## Verification

Run:

```bash
ml-cli --version
ml-cli doctor --output-json
ml-cli agent-bootstrap
ml-cli agent-guide
```

Do not report setup complete until both are true:

- the expected `ml-cli` version executes successfully; and
- MoreLogin Client installation/connectivity has been checked separately.

If `doctor` reports `EPERM`, connection refused, or timeout on `127.0.0.1`, request
the AI host's localhost/outside-sandbox permission and retry the same check once.

## Safety Boundaries

The agent may download a validated file, set executable permission on a downloaded
CLI binary, and request that an installer be opened or revealed. It must not:

- accept UAC, Gatekeeper, sudo, EULA, Terms of Service, administrator, privacy,
  firewall, login, CAPTCHA, or verification-code prompts;
- bypass security controls or use silent installer flags without an explicit user
  request and official MoreLogin documentation;
- claim that a successful launch request proves installation completed; or
- repeatedly trigger UAC or launch duplicate installers.

Show the exact installer path and keep the task open while the user completes manual
steps. Continue verification only after the user confirms completion.

## Detailed References

- [Release and artifact security](./references/release-security.md)
- [Windows installation and status contract](./references/windows-installation.md)
- [macOS and Linux installation](./references/macos-linux-installation.md)
