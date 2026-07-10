---
name: morelogin-setup
description: Install, update, configure, verify, and route MoreLogin operations through ml-cli. Use when an agent needs MoreLogin Client or ml-cli setup, browser environment or cloud phone selection, local API diagnostics, agent bootstrap guidance, or MoreLogin command safety rules.
---

# MoreLogin Setup Skill

Use this skill when a user wants an AI agent to operate MoreLogin browser environments, cloud phones, proxies, groups, tags, local API commands, or browser automation workflows.

This is a setup and agent-routing skill. It does not define one business workflow. It teaches an agent how to install, verify, and use `ml-cli` as the execution interface for other MoreLogin industry skills.

## Execution Contract

The agent should use `ml-cli` as the stable local execution interface.

Required commands:

```bash
ml-cli --version
ml-cli doctor --output-json
ml-cli agent-bootstrap
ml-cli agent-package
ml-cli agent-guide
ml-cli env find --keyword "P-1"
ml-cli env open --keyword "P-1"
ml-cli cloudphone find --keyword "CP-204"
ml-cli cloudphone open --keyword "CP-204" --headless false
```

## Install Or Update

If `ml-cli` is missing, ask the user for their operating system if it is not obvious, then use the official install command from MoreLogin documentation or from:

```bash
ml-cli install-prompt
```

For full MoreLogin Client plus CLI setup, platform-specific download handling, installer reveal/open steps, and safety boundaries, follow `skills/morelogin-setup/install.md`.

After installation, verify:

```bash
ml-cli --version
ml-cli doctor --output-json
ml-cli agent-bootstrap
```

To update an existing installation:

```bash
ml-cli self-update                   # query latest API and update to latest
ml-cli self-update --dry-run         # preview latest lookup URL, download URL, and target path
ml-cli self-update --version 2.7.0   # install specific version
```

Without `--version`, `self-update` queries the official latest-version API for the current OS/architecture, validates that the returned `data` URL points to a matching `ml-cli` artifact on an official MoreLogin download host, then downloads and replaces the current binary.

If `self-update` is not available in older versions, re-run the platform install command to overwrite the binary after confirming the target path.

After updating, refresh persistent agent rules if installed:

```bash
ml-cli agent-init --agent <agent> --scope user --write
```

## Setup Discovery

After installation, run this command to load the full command reference:

```bash
ml-cli agent-guide
```

The output contains complete command mappings, natural language examples, timeout guidelines, safety rules, and troubleshooting instructions. Treat it as the authoritative reference for all `ml-cli` commands.

For a structured JSON bootstrap payload:

```bash
ml-cli agent-bootstrap
```

Before operating MoreLogin in a new agent session, run both:

```bash
ml-cli agent-bootstrap
ml-cli agent-guide
```

## Operation Timing

The default `--timeout` is 15 seconds. Some operations require higher values:

| Operation | Recommended `--timeout` |
|---|---|
| `env open` / `env start` | `--timeout 30` |
| `cloudphone open` / `cloudphone power-on` | `--timeout 120` |
| `cloudphone close` / `cloudphone power-off` | `--timeout 30` |
| All other API calls | default (15s) |

**Always pass `--timeout 120` when powering on a cloud phone.** Example:

```bash
ml-cli --timeout 120 cloudphone open --keyword CP-1
ml-cli --timeout 30 env open --keyword P-1
```

## Environment Selection

When the user gives a browser environment name, group name, tag name, remark, or keyword, find candidates first:

```bash
ml-cli env find --keyword "<keyword>" --output-json
```

If exactly one candidate is found, use it. If zero or multiple candidates are found, show a concise candidate list and ask the user to choose. Never invent an environment ID, API field, or command format.

Open a selected environment:

```bash
ml-cli --timeout 30 env open --keyword "<keyword>" --output-json
```

Use `--timeout 30` for `env open` and `env start`, which usually take 3-5 seconds.

## Cloud Phone Selection

Find cloud phones by name, group, tag, remark, or keyword:

```bash
ml-cli cloudphone find --keyword "<keyword>" --output-json
```

Open a selected cloud phone:

```bash
ml-cli --timeout 120 cloudphone open --keyword "<keyword>" --headless false --output-json
```

Close a selected cloud phone:

```bash
ml-cli --timeout 30 cloudphone close --keyword "<keyword>" --output-json
```

`--headless false` means display the cloud phone window. `--headless true` means do not display it.

Only open or close a cloud phone when exactly one candidate matches. Use `--timeout 120` for `cloudphone open` and `cloudphone power-on`, because boot can take 30-90 seconds.

## Confirmation Gates

Always pause and ask for confirmation before:

- logging in with user credentials
- sending messages, comments, follows, likes, or connection requests
- posting or publishing content
- purchasing, ordering, bidding, or paying
- deleting or modifying accounts, environments, proxies, tags, groups, files, or app data
- exporting sensitive personal data
- running large-scale actions that may affect platform accounts

Read-only inspection, listing, screenshots, and report generation can proceed unless the user has set stricter rules.

## Localhost And Sandbox Errors

MoreLogin Desktop exposes local APIs on `127.0.0.1:<port>`. Some AI clients sandbox localhost access.

If a command or browser connection fails with messages like:

```text
connect EPERM 127.0.0.1:40000
connect EPERM 127.0.0.1:<debugPort>
```

treat it as a client sandbox permission issue first. Ask for local network or elevated execution permission according to the user's AI client. Then retry the same command.

Do not repeatedly start the same profile after an `EPERM` error; check status first.

## Automation Flags

For automation scripts and CI pipelines, use `--fail-on-business-error` to exit with code `1` when the server returns a business error. This does not require a local error-code table; it preserves and prints the original server response.

```bash
ml-cli --fail-on-business-error env list --page-no 1 --page-size 20
```

Exit code `0` only means the HTTP request completed. Always inspect the JSON response for business success or failure.

## Privacy

Do not hide raw MoreLogin response fields by default if the user asks for detailed output. When summarizing, avoid unnecessary exposure of credentials, tokens, proxy passwords, phone numbers, and device identifiers unless the user explicitly needs those fields for the task.

## References

- [Install and update guide](./install.md)
