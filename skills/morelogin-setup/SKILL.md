---
name: morelogin-setup
description: Install, update, configure, and verify MoreLogin Client and ml-cli; diagnose localhost or AI-sandbox connectivity; and safely route browser-environment and cloud-phone commands. Use when MoreLogin or ml-cli is missing, outdated, disconnected, blocked by UAC/Gatekeeper/sandbox permissions, or when an agent needs the authoritative ml-cli workflow before operating MoreLogin.
---

# MoreLogin Setup

Use `ml-cli` as the stable execution interface. Do not invent API fields, IDs,
download URLs, PowerShell, or shell installation flows when the CLI or bundled
scripts already provide the operation.

## Core Workflow

1. Detect the operating system and CPU architecture.
2. Check `ml-cli --version`. If it is missing or setup/update is requested, read
   [install.md](./install.md) and the matching platform reference.
3. Verify the local installation:

   ```bash
   ml-cli --version
   ml-cli doctor --output-json
   ml-cli agent-bootstrap
   ```

4. Before the first MoreLogin operation in a session, load the authoritative
   command guide:

   ```bash
   ml-cli agent-guide
   ```

5. Use structured JSON output where available and preserve the original MoreLogin
   response when reporting errors.

## Windows Client Workflow

On Windows x64, treat `client status` as the authoritative, read-only check.
Do not run the status and install commands unconditionally as one sequence:

```powershell
ml-cli client status --output-json
```

When that response has `status: "not_installed"`, immediately run:

```powershell
ml-cli client install --interactive --output-json
```

Treat `error`, an unknown status, invalid JSON, a timeout, or a non-zero exit code
as a failed check, not as evidence that the Client is missing. A failed check must
stop the flow before any installer download or launch. If the CLI is missing, use
the platform CLI-only bootstrap first, then run `client status`. Linux may use
the documented legacy combined bootstrap.
For macOS interactive installation, `interactiveDesktopAvailable` is advisory; the
CLI must still attempt `/usr/bin/open`, and a missing/empty JSON response is not
proof that the installer opened. Use the returned `installerPath` manually when
the window does not appear.

Do not reproduce their installed-state detection, download, version, architecture,
Authenticode, publisher, or launch checks in agent-generated PowerShell. Read
[Windows installation](./references/windows-installation.md) before installing or
diagnosing the Client.

Treat GUI installation as two separate user-controlled gates:

1. The AI host may require permission to run outside its sandbox or launch a GUI.
2. Windows may then display UAC.

Never approve either gate for the user. If the host cannot launch into the user's
desktop session, report the verified `installerPath` and ask the user to double-click
it. Do not loop or launch duplicate installers.

## CLI Update Rule

Always preview and compare before a default update:

```bash
ml-cli self-update --dry-run
```

- If latest is newer than installed, run `ml-cli self-update` and verify the result.
- If latest is equal to or older than installed, skip the update. Never use the
  default update flow to downgrade a development or pre-release build.
- Use `ml-cli self-update --version <version>` only when the user explicitly asks
  for that version; an explicit version may be a downgrade.

Do not externally update an installed MoreLogin Client. Return or explain
`nextAction: "update_in_client"` and let the user update inside MoreLogin.

## Operation Routing

Run both commands before relying on remembered command syntax:

```bash
ml-cli agent-bootstrap
ml-cli agent-guide
```

For environment or cloud-phone selection, read
[operation routing](./references/operations.md). Operate only when exactly one
candidate matches. Never guess an environment ID, cloud-phone ID, payload field, or
command format.

Use `--fail-on-business-error` in automation when a non-zero MoreLogin business code
must produce a failing process exit code. Otherwise, inspect the JSON business result;
exit code `0` can mean only that the HTTP request completed.

## Confirmation Gates

Pause for user confirmation before an action that would:

- enter credentials or complete login, CAPTCHA, or verification codes;
- accept UAC, Gatekeeper, sudo, administrator, EULA, privacy, firewall, or security
  prompts;
- send, post, publish, purchase, pay, delete, or irreversibly modify user data;
- run a large-scale action affecting accounts; or
- launch a GUI installer outside an AI-host sandbox.

Do not ask again for an action the user has already explicitly authorized unless a
new security boundary or materially different effect appears.

## Localhost And Sandbox Errors

MoreLogin Desktop exposes local APIs on `127.0.0.1:<port>`. For `EPERM`, connection
refused, or timeout errors:

1. Check Client installation and status.
2. Treat AI-host localhost/sandbox permission as a likely cause.
3. Request the host's standard local-network or outside-sandbox permission.
4. Retry the same command once after approval.

Do not repeatedly start the same browser profile or cloud phone after a permission
error; check status first.

## References

- [Installation entry and decision flow](./install.md) — read for any installation,
  update, repair, or verification request.
- [Release and artifact security](./references/release-security.md) — read before
  resolving URLs, downloading, reusing, or validating an artifact.
- [Windows installation](./references/windows-installation.md) — read for Windows
  Client detection, JSON states, GUI handoff, and UAC behavior.
- [macOS and Linux installation](./references/macos-linux-installation.md) — read only
  for those platforms.
- [Operation routing](./references/operations.md) — read for environment, cloud-phone,
  timing, candidate-selection, and mutation rules.
