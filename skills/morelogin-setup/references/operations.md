# MoreLogin Operation Routing

Load the current command contract before operating MoreLogin:

```bash
ml-cli agent-bootstrap
ml-cli agent-guide
```

Treat `agent-guide` as authoritative when this reference and the installed CLI
differ.

## Timing

| Operation | Timeout |
|---|---:|
| `env open` / `env start` | `--timeout 30` |
| `cloudphone open` / `cloudphone power-on` | `--timeout 120` |
| `cloudphone close` / `cloudphone power-off` | `--timeout 30` |
| Other local API calls | default 15 seconds |

## Candidate Selection

Find browser environments before acting:

```bash
ml-cli env find --keyword "<keyword>" --output-json
```

Find cloud phones before acting:

```bash
ml-cli cloudphone find --keyword "<keyword>" --output-json
```

- Exactly one match: use that candidate.
- Zero matches: report no match; do not invent an ID.
- Multiple matches: show a concise candidate list and ask the user to choose.

Examples after unique selection:

```bash
ml-cli --timeout 30 env open --keyword "<keyword>" --output-json
ml-cli --timeout 120 cloudphone open --keyword "<keyword>" --headless false --output-json
ml-cli --timeout 30 cloudphone close --keyword "<keyword>" --output-json
```

## Mutation And Confirmation

Read-only listing, inspection, screenshots, and reports may proceed unless the user
sets stricter rules. Obtain confirmation before a materially consequential mutation
that the user has not already explicitly authorized, including deletion, publishing,
messaging, payment, account changes, or bulk actions.

Do not add a redundant confirmation when the user's current request already clearly
authorizes the same scoped, reversible operation. Ask again when a new security
boundary, irreversible effect, additional account, or expanded batch appears.

## Errors

Use `--fail-on-business-error` in scripts when a non-zero MoreLogin business code
must fail the process. Otherwise inspect the response body; HTTP/process success is
not necessarily business success.

Preserve the original error response. Avoid unnecessarily repeating credentials,
tokens, proxy passwords, phone numbers, or device identifiers in summaries.

For `EPERM`, connection refused, or timeout on localhost, check Client status and AI
host permission before retrying. Do not repeatedly start the same resource.
