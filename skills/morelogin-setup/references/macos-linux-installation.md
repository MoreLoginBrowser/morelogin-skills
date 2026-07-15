# macOS And Linux Installation

Use this reference only on macOS or Linux. On macOS, install or update only
`ml-cli` first with the dedicated bootstrap:

```bash
curl -fsSL https://releases.morelogin.com/client/prod/install-cli.sh | bash
```

## Contents

- [macOS](#macos)
- [Linux](#linux)
- [Verification](#verification)

## macOS

Use `ml-cli client status --output-json` as the authoritative read-only check for
`/Applications/MoreLogin.app` and `~/Applications/MoreLogin.app`. Do not reproduce
bundle scanning, architecture checks, signing checks, or Gatekeeper checks in
ad-hoc shell code.

If the status is `not_installed`, immediately run:

```bash
ml-cli client install --interactive --output-json
```

For macOS, the CLI selects the native architecture and prepares a fresh DMG. A
`detection_inconclusive` result is a failed check, not evidence that the Client is
missing; stop without downloading or opening a DMG.

After `user_action_required` or `launch_requested`, complete the installer and
Gatekeeper prompts manually. `interactiveDesktopAvailable` is advisory in an AI
host: even when it is false, the CLI attempts `/usr/bin/open`. If no window appears
or the command reports an open failure, use the returned verified `installerPath`
and double-click it in Finder. The CLI does not accept licenses, remove quarantine,
copy the App, launch the installed App, or handle login/privacy prompts. Rerun
`ml-cli client status --output-json` after manual completion.

`--output-json` must print one JSON object on a successful command. If a legacy
binary or AI-host wrapper exits successfully with empty stdout, rerun
`ml-cli client install --output-json` without `--interactive`, then open the exact
returned `installerPath`; do not infer that the installer opened.

Legacy/manual fallback only when the unified CLI is unavailable:

1. Resolve the matching `darwin_arm64` or `darwin_x64` package.
2. Validate the URL and downloaded `.dmg` or `.pkg` using
   [release security](./release-security.md).
3. Run `hdiutil verify` for a DMG or `pkgutil --check-signature` for a PKG.
4. Open the installer once with `open <path>`.
5. Check `/Volumes` for the mounted MoreLogin image.
6. If it is not visible, report the exact path and ask the user to open it in Finder.

Do not use `hdiutil attach -agree`, bypass Gatekeeper, enter an administrator
password, or accept privacy/network prompts. After the user completes installation,
check the application path and run `open -a MoreLogin` only when application launch
is within the user's request.

## Linux

Linux intentionally retains the legacy combined bootstrap, which downloads the
CLI and (when needed) the Linux Client package:

```bash
curl -fsSL https://releases.morelogin.com/client/prod/install_1.0.sh | bash
```

Ubuntu is also supported by the standalone CLI-only script when an agent only
needs `ml-cli`:

```bash
curl -fsSL https://releases.morelogin.com/client/prod/install-cli.sh | bash
```

Check `morelogin`/`MoreLogin` on PATH, user application locations, `/opt`, and desktop
entries under `~/.local/share/applications` or `/usr/share/applications`. Resolve a
desktop entry to its executable; a stale entry alone is not proof of installation.

Validate the returned package according to its type:

- `.deb`: `dpkg-deb --info <path>`
- `.rpm`: `rpm -K <path>`
- `.AppImage`: require ELF magic, then `chmod +x <path>`
- `.tar.gz`/`.tgz`: `tar -tzf <path>`
- `.zip`: `unzip -t <path>`

Prepare the artifact in a user-writable location. Do not run `sudo` or install a
system package without explicit approval. Report the exact next command, for example:

```bash
sudo apt install "<downloaded-file.deb>"
```

An instruction containing `sudo` is a user handoff, not permission for the agent to
execute it.

## Verification

After installation on macOS:

```bash
ml-cli --version
ml-cli client status --output-json
ml-cli doctor --output-json
ml-cli agent-bootstrap
```

Verify the installed Client path or application launch separately. Do not claim
Client installation solely because `ml-cli` works.
