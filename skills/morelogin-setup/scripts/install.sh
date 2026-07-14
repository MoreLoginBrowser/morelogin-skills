#!/usr/bin/env bash
set -euo pipefail

API_BASE="https://cb-gateway.morelogin.com/app/ver/public/latest"
API_HOST="cb-gateway.morelogin.com"
RELEASE_HOST="releases.morelogin.com"
INSTALL_HOST="get.morelogin.com"
INSTALL_DIR="${MORELOGIN_CLI_INSTALL_DIR:-$HOME/.local/bin}"
BIN_PATH="$INSTALL_DIR/ml-cli"
SKIP_CLIENT="${MORELOGIN_SKIP_CLIENT:-0}"

detect_platform() {
  local os
  local arch

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

detect_client_identify() {
  local cli_identify="$1"
  printf '%s' "${cli_identify%_cli}"
}

json_get_data_url() {
  sed -n 's/.*"data"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

validate_api_url() {
  if [ "$API_BASE" != "https://$API_HOST/app/ver/public/latest" ]; then
    echo "Refusing untrusted MoreLogin release API URL: $API_BASE" >&2
    exit 2
  fi
}

validate_api_response() {
  local compact
  compact="$(printf '%s' "$1" | tr -d '[:space:]')"

  case "$compact" in
    *'"success":true'*) ;;
    *) echo "MoreLogin release API did not return success=true." >&2; return 1 ;;
  esac

  case "$compact" in
    *'"code":0'*|*'"code":"0"'*) ;;
    *) echo "MoreLogin release API did not return code=0." >&2; return 1 ;;
  esac
}

validate_download_url() {
  local url="$1"
  local expected_identify="$2"
  local rest authority path filename expected_filename platform arch os

  case "$url" in
    https://*) ;;
    *) echo "Refusing non-HTTPS download URL: $url" >&2; return 1 ;;
  esac

  rest="${url#https://}"
  authority="${rest%%/*}"
  if [ "$authority" = "$rest" ]; then
    echo "Refusing download URL without a path: $url" >&2
    return 1
  fi

  path="/${rest#*/}"
  path="${path%%\#*}"
  path="${path%%\?*}"
  filename="${path##*/}"

  case "$authority" in
    "$RELEASE_HOST")
      platform="${expected_identify#MoreLogin_AirDrop_}"
      case "$expected_identify" in
        *_cli)
          case "$path" in
            "/prod/$expected_identify/"*) ;;
            *) echo "Refusing CLI release URL outside the expected $expected_identify path: $url" >&2; return 1 ;;
          esac
          case "$filename" in
            *"$expected_identify"*) ;;
            *) echo "Refusing CLI release filename that does not match $expected_identify: $url" >&2; return 1 ;;
          esac
          ;;
        *)
          arch="${platform##*_}"
          os="${platform%_*}"
          case "$os" in
            darwin)
              case "$path" in /prod/client/mac/"$arch"/*|/prod/client/darwin/"$arch"/*) ;; *) echo "Refusing Client release URL for the wrong platform: $url" >&2; return 1 ;; esac
              case "$filename" in *"MoreLogin_${os}_${arch}_"*.dmg|*"MoreLogin_${os}_${arch}_"*.pkg) ;; *) echo "Refusing unexpected macOS Client release filename: $url" >&2; return 1 ;; esac
              ;;
            window)
              case "$path" in /prod/client/win/"$arch"/*|/prod/client/window/"$arch"/*|/prod/client/windows/"$arch"/*) ;; *) echo "Refusing Client release URL for the wrong platform: $url" >&2; return 1 ;; esac
              case "$filename" in *"MoreLogin_${os}_${arch}_"*.exe) ;; *) echo "Refusing unexpected Windows Client release filename: $url" >&2; return 1 ;; esac
              ;;
            linux)
              case "$path" in /prod/client/linux/"$arch"/*) ;; *) echo "Refusing Client release URL for the wrong platform: $url" >&2; return 1 ;; esac
              case "$filename" in
                *"MoreLogin_${os}_${arch}_"*.deb|*"MoreLogin_${os}_${arch}_"*.rpm|*"MoreLogin_${os}_${arch}_"*.AppImage|*"MoreLogin_${os}_${arch}_"*.appimage|*"MoreLogin_${os}_${arch}_"*.tar.gz|*"MoreLogin_${os}_${arch}_"*.tgz|*"MoreLogin_${os}_${arch}_"*.zip) ;;
                *) echo "Refusing unexpected Linux Client release filename: $url" >&2; return 1 ;;
              esac
              ;;
            *) echo "Refusing Client release URL for unsupported platform '$os': $url" >&2; return 1 ;;
          esac
          ;;
      esac
      ;;
    "$INSTALL_HOST")
      case "$path" in
        /client/prod/*) ;;
        *) echo "Refusing $INSTALL_HOST URL outside /client/prod/: $url" >&2; return 1 ;;
      esac
      platform="${expected_identify#MoreLogin_AirDrop_}"
      case "$expected_identify" in
        *_cli)
          case "$expected_identify" in
            MoreLogin_AirDrop_window_*) expected_filename="ml-cli.exe" ;;
            *) expected_filename="ml-cli" ;;
          esac
          if [ "$filename" != "$expected_filename" ]; then
            echo "Refusing unexpected ml-cli filename from $INSTALL_HOST: $url" >&2
            return 1
          fi
          platform="${platform%_cli}"
          arch="${platform##*_}"
          case "$path" in
            *"/$arch/"*) ;;
            *) echo "Refusing $INSTALL_HOST URL that does not match $expected_identify: $url" >&2; return 1 ;;
          esac
          ;;
        *)
          arch="${platform##*_}"
          os="${platform%_*}"
          case "$os" in
            darwin)
              case "$path" in */mac/"$arch"/*|*/darwin/"$arch"/*) ;; *) echo "Refusing Client URL for the wrong platform: $url" >&2; return 1 ;; esac
              case "$filename" in *MoreLogin*.dmg|*morelogin*.dmg|*MoreLogin*.pkg|*morelogin*.pkg) ;; *) echo "Refusing unexpected macOS Client filename: $url" >&2; return 1 ;; esac
              ;;
            window)
              case "$path" in */win/"$arch"/*|*/window/"$arch"/*|*/windows/"$arch"/*) ;; *) echo "Refusing Client URL for the wrong platform: $url" >&2; return 1 ;; esac
              case "$filename" in *MoreLogin*.exe|*morelogin*.exe) ;; *) echo "Refusing unexpected Windows Client filename: $url" >&2; return 1 ;; esac
              ;;
            linux)
              case "$path" in */linux/"$arch"/*) ;; *) echo "Refusing Client URL for the wrong platform: $url" >&2; return 1 ;; esac
              case "$filename" in
                *MoreLogin*.deb|*morelogin*.deb|*MoreLogin*.rpm|*morelogin*.rpm|*MoreLogin*.AppImage|*morelogin*.AppImage|*MoreLogin*.appimage|*morelogin*.appimage|*MoreLogin*.tar.gz|*morelogin*.tar.gz|*MoreLogin*.tgz|*morelogin*.tgz|*MoreLogin*.zip|*morelogin*.zip) ;;
                *) echo "Refusing unexpected Linux Client filename: $url" >&2; return 1 ;;
              esac
              ;;
            *) echo "Refusing Client URL for unsupported platform '$os': $url" >&2; return 1 ;;
          esac
          ;;
      esac
      ;;
    *)
      echo "Refusing download URL from untrusted host '$authority': $url" >&2
      return 1
      ;;
  esac
}

resolve_release() {
  local lookup_identify="$1"
  local lookup_url="$API_BASE?identify=$lookup_identify"

  echo "MoreLogin release API request:"
  echo "  identify: $lookup_identify"
  echo "  url: $lookup_url"
  release_response="$(curl -fsS --proto '=https' --max-redirs 0 "$lookup_url")"
  echo "MoreLogin release API response:"
  printf '  %s\n' "$release_response"

  validate_api_response "$release_response"
  release_download_url="$(printf '%s' "$release_response" | json_get_data_url)"
  if [ -z "$release_download_url" ]; then
    echo "Could not resolve download URL. Raw response:" >&2
    printf '%s\n' "$release_response" >&2
    exit 2
  fi
  validate_download_url "$release_download_url" "$lookup_identify"
  echo "Resolved latest download URL:"
  echo "  $release_download_url"
}

version_from_download_url() {
  local url_path="${1%%\?*}"
  local parent="${url_path%/*}"
  printf '%s' "${parent##*/}"
}

version_at_least() {
  local left="${1#v}"
  local right="${2#v}"
  local index left_part right_part
  local IFS=.
  local -a left_parts right_parts

  left="${left%%-*}"
  right="${right%%-*}"
  read -r -a left_parts <<< "$left"
  read -r -a right_parts <<< "$right"

  for index in 0 1 2 3; do
    left_part="${left_parts[$index]:-0}"
    right_part="${right_parts[$index]:-0}"
    case "$left_part:$right_part" in
      *[!0-9:]*|:*) return 1 ;;
    esac
    if ((10#$left_part > 10#$right_part)); then
      return 0
    fi
    if ((10#$left_part < 10#$right_part)); then
      return 1
    fi
  done
  return 0
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 2
  fi
}

need_cmd curl
need_cmd sed
need_cmd tr

validate_api_url

identify="$(detect_platform)"
resolve_release "$identify"
cli_download_url="$release_download_url"
latest_cli_version="$(version_from_download_url "$cli_download_url")"

if [ -x "$BIN_PATH" ]; then
  existing_cli="$BIN_PATH"
elif command -v ml-cli >/dev/null 2>&1; then
  existing_cli="$(command -v ml-cli)"
else
  existing_cli=""
fi

if [ -n "$existing_cli" ]; then
  installed_version_output="$("$existing_cli" --version 2>/dev/null || true)"
  installed_cli_version="${installed_version_output##* }"
  echo "Installed ml-cli: $existing_cli"
  echo "Installed version: ${installed_cli_version:-unknown}"
  echo "Latest API version: ${latest_cli_version:-unknown}"

  if [ -n "$installed_cli_version" ] && [ -n "$latest_cli_version" ] && version_at_least "$installed_cli_version" "$latest_cli_version"; then
    echo "ml-cli is already at the latest or a newer version. Skipping download."
    cli_ready=1
  elif "$existing_cli" self-update; then
    "$existing_cli" --version
    cli_ready=1
  else
    cli_ready=0
  fi
  if [ "$cli_ready" = "0" ]; then
    echo "ml-cli self-update failed; falling back to user-local install." >&2
  fi
else
  cli_ready=0
fi

if [ "$cli_ready" = "0" ]; then
  mkdir -p "$INSTALL_DIR"
  tmp_path="$BIN_PATH.tmp"

  echo "Downloading ml-cli from:"
  echo "$cli_download_url"
  curl -fS --proto '=https' --max-redirs 0 "$cli_download_url" -o "$tmp_path"
  chmod +x "$tmp_path"
  "$tmp_path" --version
  mv "$tmp_path" "$BIN_PATH"

  echo "Installed ml-cli to $BIN_PATH"
  "$BIN_PATH" --version

  case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
      echo
      echo "Add this directory to PATH for future shells:"
      echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
      ;;
  esac
fi

client_installed() {
  case "$(uname -s)" in
    Darwin)
      [ -d "/Applications/MoreLogin.app" ] || [ -d "$HOME/Applications/MoreLogin.app" ]
      ;;
    Linux)
      command -v morelogin >/dev/null 2>&1 ||
        command -v MoreLogin >/dev/null 2>&1 ||
        [ -x "$HOME/.local/bin/morelogin" ] ||
        [ -x "$HOME/.local/bin/MoreLogin" ] ||
        [ -x "$HOME/Applications/MoreLogin/MoreLogin" ] ||
        [ -x "$HOME/Applications/MoreLogin/morelogin" ] ||
        [ -x "/opt/MoreLogin/MoreLogin" ] ||
        [ -x "/opt/MoreLogin/morelogin" ] ||
        [ -x "/opt/morelogin/morelogin" ] ||
        [ -x "/usr/local/bin/morelogin" ] ||
        [ -x "/usr/local/bin/MoreLogin" ] ||
        [ -x "/usr/bin/morelogin" ] ||
        [ -x "/usr/bin/MoreLogin" ]
      ;;
    *)
      return 1
      ;;
  esac
}

remote_file_size() {
  local url="$1"
  local headers
  local size

  if ! headers="$(curl -fsSI --proto '=https' --max-redirs 0 "$url" 2>/dev/null)"; then
    return 1
  fi
  size="$(printf '%s\n' "$headers" | awk '
    tolower($1) == "content-length:" {
      gsub("\r", "", $2)
      value = $2
    }
    END {
      if (value ~ /^[0-9]+$/) print value
    }
  ')"
  case "$size" in
    ''|*[!0-9]*) return 1 ;;
  esac
  printf '%s' "$size"
}

client_installer_format_valid() {
  local path="$1"
  local package_name="${2:-$1}"
  local magic

  case "$(uname -s):$package_name" in
    Darwin:*.dmg)
      hdiutil verify "$path" >/dev/null 2>&1
      ;;
    Darwin:*.pkg)
      pkgutil --check-signature "$path" >/dev/null 2>&1
      ;;
    Linux:*.deb)
      command -v dpkg-deb >/dev/null 2>&1 && dpkg-deb --info "$path" >/dev/null 2>&1
      ;;
    Linux:*.rpm)
      command -v rpm >/dev/null 2>&1 && rpm -K "$path" >/dev/null 2>&1
      ;;
    Linux:*.AppImage|Linux:*.appimage)
      magic="$(od -An -tx1 -N4 "$path" 2>/dev/null | tr -d '[:space:]')"
      [ "$magic" = "7f454c46" ]
      ;;
    Linux:*.tar.gz|Linux:*.tgz)
      tar -tzf "$path" >/dev/null 2>&1
      ;;
    Linux:*.zip)
      command -v unzip >/dev/null 2>&1 && unzip -tqq "$path" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

client_installer_reusable() {
  local path="$1"
  local url="$2"
  local package_name="${3:-$1}"
  local local_size
  local expected_size

  [ -f "$path" ] && [ -s "$path" ] || return 1
  local_size="$(wc -c < "$path" | tr -d '[:space:]')"
  if expected_size="$(remote_file_size "$url")"; then
    [ "$local_size" = "$expected_size" ] || return 1
  fi
  client_installer_format_valid "$path" "$package_name"
}

preserve_invalid_file() {
  local path="$1"
  local preserved_path

  [ -e "$path" ] || return 0
  preserved_path="$path.invalid-$(date +%Y%m%d%H%M%S)"
  mv "$path" "$preserved_path"
  echo "Preserved an incomplete or invalid file at $preserved_path" >&2
}

download_with_resume() {
  local url="$1"
  local path="$2"
  local curl_status

  if [ -s "$path" ]; then
    if curl -fS --retry 3 --retry-delay 2 --continue-at - --proto '=https' --max-redirs 0 "$url" -o "$path"; then
      return 0
    else
      curl_status=$?
    fi
    if [ "$curl_status" -ne 33 ]; then
      return "$curl_status"
    fi
    echo "The server does not support resuming this partial download. Restarting it." >&2
    preserve_invalid_file "$path"
  fi

  curl -fS --retry 3 --retry-delay 2 --proto '=https' --max-redirs 0 "$url" -o "$path"
}

download_client_installer() {
  if client_installed; then
    echo "MoreLogin Client appears to be installed. Skipping Client installer download."
    return 0
  fi

  client_identify="$(detect_client_identify "$identify")"
  resolve_release "$client_identify"
  client_url="$release_download_url"

  download_dir="${MORELOGIN_DOWNLOAD_DIR:-$HOME/Downloads}"
  mkdir -p "$download_dir"
  filename="${client_url##*/}"
  client_path="$download_dir/$filename"

  if client_installer_reusable "$client_path" "$client_url"; then
    echo "Found the latest MoreLogin Client installer in the download directory:"
    echo "$client_path"
    echo "The existing installer is valid. Skipping download."
  else
    preserve_invalid_file "$client_path"
    partial_path="$client_path.part"

    if client_installer_reusable "$partial_path" "$client_url" "$filename"; then
      echo "Found a complete validated partial download. Finishing it without downloading again:"
      echo "$partial_path"
    else
      expected_size="$(remote_file_size "$client_url" || true)"
      if [ -n "$expected_size" ] && [ -f "$partial_path" ]; then
        actual_size="$(wc -c < "$partial_path" | tr -d '[:space:]')"
        if [ "$actual_size" -ge "$expected_size" ]; then
          preserve_invalid_file "$partial_path"
        fi
      fi
      echo "Downloading MoreLogin Client installer from:"
      echo "$client_url"
      download_with_resume "$client_url" "$partial_path"
    fi
    if ! client_installer_format_valid "$partial_path" "$filename"; then
      echo "Downloaded MoreLogin Client installer failed package validation: $partial_path" >&2
      return 2
    fi
    expected_size="$(remote_file_size "$client_url" || true)"
    if [ -n "$expected_size" ]; then
      actual_size="$(wc -c < "$partial_path" | tr -d '[:space:]')"
      if [ "$actual_size" != "$expected_size" ]; then
        echo "Downloaded MoreLogin Client installer size does not match the release: $partial_path" >&2
        return 2
      fi
    fi
    mv "$partial_path" "$client_path"
    echo "Downloaded MoreLogin Client installer to $client_path"
  fi

  case "$(uname -s)" in
    Darwin)
      if ! open "$client_path"; then
        echo "Could not open the installer automatically. Revealing it in Finder:"
        echo "$client_path"
        open -R "$client_path" || true
      fi
      echo "If an installer, Gatekeeper, privacy, or network prompt appears, confirm it manually."
      ;;
    Linux)
      case "$client_path" in
        *.deb)
          echo "Ubuntu/Debian package downloaded."
          echo "Install it manually when ready:"
          echo "  sudo apt install \"$client_path\""
          echo "Do not run sudo unless you approve the system package installation."
          ;;
        *.rpm)
          echo "RPM package downloaded."
          echo "Install it manually when ready:"
          echo "  sudo dnf install \"$client_path\""
          echo "Do not run sudo unless you approve the system package installation."
          ;;
        *.AppImage|*.appimage)
          chmod +x "$client_path" || true
          echo "AppImage prepared at $client_path"
          echo "Launch it manually when ready:"
          echo "  \"$client_path\""
          ;;
        *.tar.gz|*.tgz|*.zip)
          echo "Archive downloaded. Extract it to a user-writable directory when ready:"
          echo "  $client_path"
          ;;
        *)
          echo "Open or install this package manually. Do not run sudo unless you approve it:"
          echo "  $client_path"
          ;;
      esac
      ;;
  esac
}

if [ "$SKIP_CLIENT" = "1" ] || [ "$SKIP_CLIENT" = "true" ]; then
  echo
  echo "MoreLogin Client check was skipped because MORELOGIN_SKIP_CLIENT is enabled."
else
  download_client_installer
fi
