#!/bin/bash

set -euo pipefail

apple_release_log() {
  echo "[apple-release] $*"
}

apple_release_security() {
  security "$@"
}

apple_release_notarytool() {
  xcrun notarytool "$@"
}

apple_release_codesign() {
  /usr/bin/codesign "$@"
}

apple_release_resolve_keychain_path() {
  if [[ -n "${SIGNING_KEYCHAIN:-}" ]]; then
    printf '%s\n' "$SIGNING_KEYCHAIN"
    return 0
  fi

  apple_release_security default-keychain 2>/dev/null | tr -d '"' | xargs
}

apple_release_resolve_keychain_password() {
  if [[ -n "${SIGNING_KEYCHAIN_PASSWORD:-}" ]]; then
    printf '%s\n' "$SIGNING_KEYCHAIN_PASSWORD"
    return 0
  fi

  if [[ -n "${SIGNING_KEYCHAIN_PASSWORD_FILE:-}" && -r "${SIGNING_KEYCHAIN_PASSWORD_FILE}" ]]; then
    tr -d '\r\n' < "${SIGNING_KEYCHAIN_PASSWORD_FILE}"
    return 0
  fi

  if [[ -n "${SIGNING_KEYCHAIN_PASSWORD_ITEM:-}" ]]; then
    if [[ -n "${SIGNING_KEYCHAIN_PASSWORD_ACCOUNT:-}" ]]; then
      apple_release_security find-generic-password -s "${SIGNING_KEYCHAIN_PASSWORD_ITEM}" -a "${SIGNING_KEYCHAIN_PASSWORD_ACCOUNT}" -w 2>/dev/null || true
    else
      apple_release_security find-generic-password -s "${SIGNING_KEYCHAIN_PASSWORD_ITEM}" -w 2>/dev/null || true
    fi
  fi
}

apple_release_load_project_env() {
  local default_project="${1:-}"
  local home_dir="${APPLE_RELEASE_HOME:-$HOME/apple-release}"
  local project_name="${APPLE_RELEASE_PROJECT:-$default_project}"
  local shared_env_path="${APPLE_RELEASE_SHARED_ENV:-${home_dir}/config/shared.env}"
  local env_path="${APPLE_RELEASE_PROJECT_ENV:-${home_dir}/config/projects/${project_name}.env}"

  if [[ -f "$shared_env_path" ]]; then
    # shellcheck disable=SC1090
    source "$shared_env_path"
    apple_release_log "Loaded shared env: $shared_env_path"
  fi

  if [[ -z "$project_name" ]]; then
    return 0
  fi

  if [[ -f "$env_path" ]]; then
    # shellcheck disable=SC1090
    source "$env_path"
    apple_release_log "Loaded project env: $env_path"
  fi
}

apple_release_configure_keychain_search_list() {
  local keychain_path="${1:?keychain path required}"
  apple_release_security list-keychains -d user -s \
    "$keychain_path" \
    "$HOME/Library/Keychains/login.keychain-db" \
    "/Library/Keychains/System.keychain"
}

apple_release_unlock_keychain() {
  local keychain_path=""
  local keychain_password=""

  keychain_path="$(apple_release_resolve_keychain_path)"
  keychain_password="$(apple_release_resolve_keychain_password)"

  if [[ -n "$keychain_path" && -n "$keychain_password" ]]; then
    apple_release_log "Unlocking signing keychain and setting partition list..."
    apple_release_security unlock-keychain -p "$keychain_password" "$keychain_path" >/dev/null 2>&1 || true
    apple_release_security set-keychain-settings -lut 21600 "$keychain_path" >/dev/null 2>&1 || true
    apple_release_security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain_path" >/dev/null 2>&1 || true
    apple_release_configure_keychain_search_list "$keychain_path" >/dev/null 2>&1 || true
    return 0
  elif [[ -n "$keychain_path" ]]; then
    apple_release_configure_keychain_search_list "$keychain_path" >/dev/null 2>&1 || true
  fi

  apple_release_log "No signing keychain password item available; assuming keychain is already unlocked."
}

apple_release_require_identity() {
  local match_text="${1:?identity match text required}"
  local identity_output=""

  if [[ -n "${SIGNING_KEYCHAIN:-}" ]]; then
    identity_output="$(apple_release_security find-identity -v -p codesigning "$SIGNING_KEYCHAIN" 2>/dev/null || true)"
  else
    identity_output="$(apple_release_security find-identity -v -p codesigning 2>/dev/null || true)"
  fi

  if ! grep -q "$match_text" <<<"$identity_output"; then
    apple_release_log "Missing identity match: $match_text"
    echo "$identity_output"
    return 1
  fi
}

apple_release_install_profile_if_present() {
  local source_path="${1:?profile path required}"
  local legacy_dir="${HOME}/Library/MobileDevice/Provisioning Profiles"
  local xcode_dir="${HOME}/Library/Developer/Xcode/UserData/Provisioning Profiles"
  local uuid=""
  local temp_plist=""

  if [[ ! -f "$source_path" ]]; then
    return 0
  fi

  mkdir -p "$legacy_dir" "$xcode_dir"
  temp_plist="$(mktemp /tmp/apple_release_profile.XXXXXX.plist)"
  security cms -D -i "$source_path" -o "$temp_plist" >/dev/null 2>&1
  uuid="$(/usr/libexec/PlistBuddy -c 'Print UUID' "$temp_plist")"
  rm -f "$temp_plist"

  cp "$source_path" "$legacy_dir/$uuid.mobileprovision"
  cp "$source_path" "$xcode_dir/$uuid.mobileprovision"
  apple_release_log "Installed provisioning profile UUID: $uuid"
}

apple_release_snapshot_dir() {
  local root_dir="${1:?backup root required}"
  local label="${2:-manual}"
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local snapshot_dir="${root_dir}/${timestamp}-${label}"
  mkdir -p "$snapshot_dir"
  printf '%s\n' "$snapshot_dir"
}
