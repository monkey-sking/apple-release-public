#!/bin/bash

set -euo pipefail

APPLE_RELEASE_HOME="${APPLE_RELEASE_HOME:-$HOME/apple-release}"
# shellcheck disable=SC1091
source "${APPLE_RELEASE_HOME}/lib/common.sh"
apple_release_load_project_env ""
KEYCHAIN_PATH="${SIGNING_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"

echo "=== active keychain target ==="
echo "$KEYCHAIN_PATH"
echo

echo "=== active codesigning identities ==="
apple_release_unlock_keychain
apple_release_security find-identity -v -p codesigning "$KEYCHAIN_PATH" 2>&1 || true
echo

echo "=== required current lanes ==="
for env_file in "$APPLE_RELEASE_HOME"/config/projects/*.env; do
  [[ -f "$env_file" ]] || continue
  echo "--- $(basename "$env_file") ---"
  # Show field names only; configuration values may contain credentials.
  sed -nE 's/^[[:space:]]*(export[[:space:]]+)?([A-Z_][A-Z0-9_]*)=.*/\2=<configured>/p' "$env_file"
done
echo

echo "=== local downloadable cert/profile materials ==="
find "${APPLE_RELEASE_DOWNLOADS_DIR:-$HOME/Downloads}" -maxdepth 2 \
  \( -name '*.cer' -o -name '*.mobileprovision' -o -name '*.provisionprofile' -o -name '*.p8' -o -name '*.csr' \) \
  2>/dev/null | sort
echo

echo "=== active login keychain generic-password release items ==="
for item in AionRelease AetherRelease SIGNING_KEYCHAIN_PASSWORD; do
  echo "--- $item ---"
  apple_release_security find-generic-password -s "$item" 2>&1 || true
done
echo

cat <<'EOF'
Next rebuild order:
1. Import or issue Apple Distribution into login.keychain-db.
2. Import or issue Developer ID Application into login.keychain-db.
3. Refresh OneJot / FitBridge / Aura profiles that depend on Apple Distribution.
4. Recreate AionRelease / AetherRelease notarytool profiles in login.keychain-db.
5. Store the login keychain password as a named generic password item for SSH/headless use.
6. Run the shared lane preflight before the next package attempt.
EOF
