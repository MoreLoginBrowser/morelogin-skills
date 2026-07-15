# Install MoreLogin

Use this public entry guide to install or verify MoreLogin Client and
`ml-cli`. Keep CLI and Client state separate: installing `ml-cli` does not prove the
MoreLogin Client is installed.

## Contents

- [Install MoreLogin](#install-morelogin)
  - [Contents](#contents)
  - [Fast Path](#fast-path)
  - [Decision Flow](#decision-flow)
  - [Fallback Downloads](#fallback-downloads)
  - [Verification](#verification)
  - [Guide freshness](#guide-freshness)
  - [Safety Boundaries](#safety-boundaries)
  - [Detailed References](#detailed-references)

## Fast Path

Detect OS and CPU architecture, then choose the bootstrap that matches the
execution context.

Install the CLI first with the dedicated CLI-only bootstrap:

```powershell
irm https://releases.morelogin.com/client/prod/install-cli.ps1 | iex
```

On macOS, use the dedicated CLI-only bootstrap:

```bash
curl -fsSL https://releases.morelogin.com/client/prod/install-cli.sh | bash
```

For macOS, use `ml-cli client status --output-json` after the CLI is available.
Use `ml-cli client install --interactive --output-json` immediately after a
parsed `not_installed` result. Linux Client
installation keeps the legacy CLI+Client download flow; follow the Linux
reference and keep system-package installation manual.

Run the selected bootstrap with a long timeout and continue polling while files
download. If the AI host blocks network, filesystem, localhost, or GUI access,
request the matching host permission and retry the same command. Do not silently
switch tools or restart the flow repeatedly.

## Decision Flow

1. Detect platform and architecture. Stop if the pair is unsupported.
2. Check `ml-cli --version`.
3. If the CLI is missing, install only the CLI with the platform CLI-only
   bootstrap, then check the Client independently.
4. On Windows x64 or macOS Intel/Apple Silicon, run:

   ```bash
   ml-cli client status --output-json
   ```

5. If the response is `installed`, stop the installation flow; do not download or
   launch an installer.
6. If and only if the response is `not_installed`, immediately run
   `ml-cli client install --interactive --output-json`.
7. If the response is `error`, unknown, invalid JSON, or the command fails, stop and
   diagnose. Never treat a failed check as `not_installed`.
8. Open or reveal the installer, then stop at UAC, Gatekeeper, sudo, EULA, login, or
   any other user/security confirmation.
9. After the user reports installation complete, run the verification commands.

Read the matching platform reference before step 4:

- [Windows](./references/windows-installation.md)
- [macOS and Linux](./references/macos-linux-installation.md)

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

## Guide freshness

This repository is a versioned snapshot of the public guide. When a task explicitly
references the GitHub `main` guide, compare the local commit with
`git ls-remote origin refs/heads/main` before treating local instructions as latest.
If the remote cannot be reached or the commits differ, report that limitation and do
not silently present the local snapshot as the current official guide. Do not
overwrite a dirty worktree automatically.

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
