#!/bin/bash

set -euo pipefail

summarize_dir() {
  local profile_dir="${1:?profile dir required}"
  local label="${2:?label required}"

  echo "=== ${label}: ${profile_dir} ==="
  if [[ ! -d "$profile_dir" ]]; then
    echo "(missing)"
    echo
    return 0
  fi

  local profile
  for profile in "$profile_dir"/*.mobileprovision "$profile_dir"/*.provisionprofile; do
    [[ -e "$profile" ]] || continue
    security cms -D -i "$profile" > /tmp/apple_release_profile.plist 2>/dev/null || continue
    local name uuid app_identifier
    name="$(/usr/libexec/PlistBuddy -c 'Print Name' /tmp/apple_release_profile.plist 2>/dev/null || true)"
    uuid="$(/usr/libexec/PlistBuddy -c 'Print UUID' /tmp/apple_release_profile.plist 2>/dev/null || true)"
    app_identifier="$(/usr/libexec/PlistBuddy -c 'Print Entitlements:application-identifier' /tmp/apple_release_profile.plist 2>/dev/null || true)"
    printf '%s | %s | %s | %s\n' "${name:-<unknown>}" "${uuid:-<no-uuid>}" "${app_identifier:-<no-app-id>}" "$profile"
  done | sort
  echo
}

summarize_dir "$HOME/Library/MobileDevice/Provisioning Profiles" "MobileDevice"
summarize_dir "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" "Xcode UserData"

cat <<'EOF'
Review rules:
- Keep the newest live App Store profile per active project.
- Keep active Aura / FitBridge / OneJot automatic profiles only if current builds still rely on them.
- Remove local Aether development profiles only after live signing is restored and no script references them.
EOF

