#!/bin/bash

set -euo pipefail

APPLE_RELEASE_HOME="${APPLE_RELEASE_HOME:-$HOME/apple-release}"
# shellcheck disable=SC1091
source "${APPLE_RELEASE_HOME}/lib/common.sh"
apple_release_load_project_env ""

show_keychain_identities() {
  local keychain_path="${1:?keychain path required}"
  if [[ ! -f "$keychain_path" ]]; then
    return 0
  fi

  echo "=== keychain: $keychain_path ==="
  apple_release_security find-identity -v -p codesigning "$keychain_path" 2>&1 || true
  echo
}

show_profile_summary() {
  local profile_dir="${1:?profile dir required}"
  local label="${2:?label required}"

  echo "=== profiles: $label ==="
  if [[ ! -d "$profile_dir" ]]; then
    echo "(missing)"
    echo
    return 0
  fi

  local profile
  for profile in "$profile_dir"/*.mobileprovision; do
    [[ -e "$profile" ]] || continue
    security cms -D -i "$profile" > /tmp/apple_release_profile.plist 2>/dev/null || continue
    local name uuid app_identifier
    name="$(/usr/libexec/PlistBuddy -c 'Print Name' /tmp/apple_release_profile.plist 2>/dev/null || true)"
    uuid="$(/usr/libexec/PlistBuddy -c 'Print UUID' /tmp/apple_release_profile.plist 2>/dev/null || true)"
    app_identifier="$(/usr/libexec/PlistBuddy -c 'Print Entitlements:application-identifier' /tmp/apple_release_profile.plist 2>/dev/null || true)"
    echo "${name:-<unknown>} | ${uuid:-<no-uuid>} | ${app_identifier:-<no-app-id>}"
  done
  echo
}

show_notary_item() {
  local service_name="${1:?service name required}"
  echo "=== generic-password: $service_name ==="
  security find-generic-password -s "$service_name" 2>&1 || true
  echo
}

echo "=== default-keychain ==="
apple_release_security default-keychain 2>&1 || true
echo

echo "=== search-list ==="
apple_release_security list-keychains 2>&1 || true
echo

echo "=== active identities ==="
apple_release_security find-identity -v -p codesigning 2>&1 || true
echo

show_keychain_identities "$HOME/Library/Keychains/login.keychain-db"
show_keychain_identities "${SIGNING_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
show_keychain_identities "$HOME/Library/Mobile Documents/.Trash/login_renamed_1.keychain-db"
show_keychain_identities "$HOME/Library/Mobile Documents/.Trash/login_renamed_2.keychain-db"
show_keychain_identities "$HOME/Library/Mobile Documents/.Trash/login_rebuilt_shell_20260723_1.keychain-db"

show_profile_summary "$HOME/Library/MobileDevice/Provisioning Profiles" "MobileDevice"
show_profile_summary "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" "Xcode UserData"

show_notary_item "AionRelease"
show_notary_item "AetherRelease"
show_notary_item "SIGNING_KEYCHAIN_PASSWORD"
