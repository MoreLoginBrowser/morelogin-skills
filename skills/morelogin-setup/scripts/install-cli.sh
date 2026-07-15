#!/usr/bin/env bash
set -euo pipefail

# Standalone CLI-only bootstrap for macOS and Ubuntu/Linux. The legacy
# install.sh remains unchanged and is still used for the Linux CLI+Client flow.
API_BASE="https://cb-gateway.morelogin.com/app/ver/public/latest"
API_HOST="cb-gateway.morelogin.com"
INSTALL_DIR="${MORELOGIN_CLI_INSTALL_DIR:-$HOME/.local/bin}"
BIN_PATH="$INSTALL_DIR/ml-cli"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 2
  }
}

detect_identify() {
  local os arch
  case "$(uname -s)" in
    Darwin) os="darwin" ;;
    Linux) os="linux" ;;
    *) echo "Unsupported operating system: $(uname -s)" >&2; exit 2 ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch="arm64" ;;
    x86_64|amd64) arch="x64" ;;
    *) echo "Unsupported CPU architecture: $(uname -m)" >&2; exit 2 ;;
  esac
  printf 'MoreLogin_AirDrop_%s_%s_cli' "$os" "$arch"
}

if [ "$(uname -s)" = "Linux" ] && [ -r /etc/os-release ]; then
  # Ubuntu is explicitly supported; other Linux distributions use the same
  # portable user-local binary path when their libc/architecture is supported.
  . /etc/os-release
  case "${ID:-}" in
    ubuntu) echo "Detected Ubuntu ${VERSION_ID:-unknown}. Installing ml-cli only." ;;
    *) echo "Detected Linux distribution: ${PRETTY_NAME:-unknown}. Installing ml-cli only." ;;
  esac
fi

need_cmd curl
need_cmd sed
need_cmd tr

identify="$(detect_identify)"
case "$API_BASE" in
  "https://$API_HOST/app/ver/public/latest") ;;
  *) echo "Refusing untrusted release API URL: $API_BASE" >&2; exit 2 ;;
esac

response="$(curl -fsS --proto '=https' --max-redirs 0 "$API_BASE?identify=$identify")"
compact="$(printf '%s' "$response" | tr -d '[:space:]')"
case "$compact" in *'"success":true'*) ;; *) echo "Release API did not return success=true." >&2; exit 2 ;; esac
case "$compact" in *'"code":0'*|*'"code":"0"'*) ;; *) echo "Release API did not return code=0." >&2; exit 2 ;; esac

download_url="$(printf '%s' "$response" | sed -n 's/.*"data"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
case "$download_url" in
  https://releases.morelogin.com/prod/$identify/*|https://get.morelogin.com/client/prod/*) ;;
  *) echo "Refusing untrusted CLI download URL: $download_url" >&2; exit 2 ;;
esac

mkdir -p "$INSTALL_DIR"
tmp_path="$BIN_PATH.tmp"
trap 'rm -f "$tmp_path"' EXIT
curl -fS --proto '=https' --max-redirs 0 "$download_url" -o "$tmp_path"
chmod +x "$tmp_path"
"$tmp_path" --version
mv -f "$tmp_path" "$BIN_PATH"
trap - EXIT

echo "Installed ml-cli to $BIN_PATH"
"$BIN_PATH" --version
case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *) echo "Add this directory to PATH for future shells: export PATH=\"$INSTALL_DIR:\$PATH\"" ;;
esac
