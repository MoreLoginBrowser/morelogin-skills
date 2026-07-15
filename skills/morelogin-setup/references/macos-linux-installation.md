# macOS And Linux Installation

Use this reference only on macOS or Linux. Use the bundled bootstrap script when
possible:

```bash
curl -fsSL https://releases.morelogin.com/client/prod/install_1.0.sh | bash
```

## Contents

- [macOS](#macos)
- [Linux](#linux)
- [Verification](#verification)

## macOS

Check `/Applications/MoreLogin.app` and `~/Applications/MoreLogin.app` before
downloading. A found app must be a usable application bundle, not merely a stale
directory.

For a missing Client:

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

After installation:

```bash
ml-cli --version
ml-cli doctor --output-json
ml-cli agent-bootstrap
```

Verify the installed Client path or application launch separately. Do not claim
Client installation solely because `ml-cli` works.
