# Release And Artifact Security

Read this reference before resolving, downloading, reusing, or opening a MoreLogin
Client or `ml-cli` artifact.

## Contents

- [Platform identifiers](#platform-identifiers)
- [Resolution modes](#resolution-modes)
- [URL validation](#url-validation)
- [Download and reuse](#download-and-reuse)
- [Windows trust requirements](#windows-trust-requirements)

## Platform Identifiers

Normalize `arm64`/`aarch64` to `arm64` and `x86_64`/`amd64`/`x64` to `x64`.

| Platform | Arch | Client identify | CLI identify |
|---|---:|---|---|
| macOS | arm64 | `MoreLogin_AirDrop_darwin_arm64` | `MoreLogin_AirDrop_darwin_arm64_cli` |
| macOS | x64 | `MoreLogin_AirDrop_darwin_x64` | `MoreLogin_AirDrop_darwin_x64_cli` |
| Windows | x64 | `MoreLogin_AirDrop_window_x64` | `MoreLogin_AirDrop_window_x64_cli` |
| Linux | x64 | `MoreLogin_AirDrop_linux_x64` | `MoreLogin_AirDrop_linux_x64_cli` |

Stop for an unlisted OS/architecture pair.

## Resolution Modes

### JSON release API

Request without following redirects:

```text
https://cb-gateway.morelogin.com/app/ver/public/latest?identify=<identify>
```

Require exact HTTPS host `cb-gateway.morelogin.com`, default port, no user info,
path `/app/ver/public/latest`, `success: true`, `code: 0`, and a non-empty `data`
URL. Show the raw response when validation fails.

Validate `data` before making the artifact request. Do not follow a redirect from the
API or the validated artifact URL.

### Approved latest redirect

The explicit endpoint below is a convenience entry point, not an artifact URL:

```text
https://cb-gateway.morelogin.com/app/ver/public/latest/redirect?identify=<identify>
```

Use it only when the documented bootstrap/CLI flow is unavailable. Accept at most
one HTTP redirect. Validate the `Location` with all artifact rules below before
downloading. Reject a missing, relative, chained, cross-platform, or untrusted
`Location`.

## URL Validation

For every API, redirect target, and artifact URL:

- require HTTPS, default port, no user info, no IP address, and no localhost;
- compare the complete lowercase hostname, never a suffix;
- allow only the documented MoreLogin host and production path;
- require the current platform and architecture in the path;
- require the expected filename or package type; and
- reject query-driven filename changes and another platform's artifact.

For `releases.morelogin.com` CLI artifacts, require
`/prod/<identify>/<version>/` and a filename containing the same identify. For Client
artifacts, require `/prod/client/<platform>/<arch>/<version>/` and the expected
MoreLogin platform package.

For `get.morelogin.com`, require `/client/prod/<platform>/<arch>/<version>/`.
Require `ml-cli.exe` for Windows CLI and `ml-cli` for macOS/Linux CLI. Require a
MoreLogin Client package type appropriate for the current platform.

## Download And Reuse

Use user-owned locations:

- CLI: `%USERPROFILE%\.morelogin\bin` on Windows or `~/.local/bin` on Unix.
- Client installer: the user's Downloads directory.

Download to a `.part` or temporary file, validate it completely, then atomically
move it to the final name. Never open a partial file. Preserve a conflicting invalid
file as `.invalid-<timestamp>` rather than overwriting it silently.

Reuse an installer only when all applicable checks pass:

- exact latest filename and version;
- non-empty regular file;
- expected platform-native file/package format;
- matching remote size when the server provides one; and
- platform trust checks below.

Do not download an external Client update when a trusted installed Client is found.
Tell the user to update inside MoreLogin.

## Windows Trust Requirements

For installed `MoreLogin.exe` and downloaded Client installers require:

- product metadata identifying MoreLogin;
- Authenticode status `Valid`; and
- an exact signer Subject component `CN=EASYANT PTE. LTD.` or
  `O=EASYANT PTE. LTD.`.

Do not use substring matching for the signer Subject. Require the installer product
or file version to match the version resolved from the latest artifact URL before
reusing it.

For the CLI binary, verify that the downloaded file executes and reports the
resolved expected version before replacing the existing binary. Do not downgrade via
the default latest flow; only an explicit `--version` request may downgrade.
