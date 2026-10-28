#!/bin/bash

set -euo pipefail

APPLE_RELEASE_HOME="${APPLE_RELEASE_HOME:-$HOME/apple-release}"
# shellcheck disable=SC1091
source "${APPLE_RELEASE_HOME}/lib/common.sh"
apple_release_load_project_env ""

BACKUP_ROOT="${APPLE_RELEASE_BACKUP_ROOT:-${APPLE_RELEASE_HOME}/backups}"
SNAPSHOT_DIR="$(apple_release_snapshot_dir "$BACKUP_ROOT" "${1:-apple-assets}")"

mkdir -p "$SNAPSHOT_DIR/profiles-mobiledevice" "$SNAPSHOT_DIR/profiles-xcode" "$SNAPSHOT_DIR/keychains" "$SNAPSHOT_DIR/metadata" "$SNAPSHOT_DIR/private-signing"

if [[ -d "$HOME/Library/MobileDevice/Provisioning Profiles" ]]; then
  cp -R "$HOME/Library/MobileDevice/Provisioning Profiles/." "$SNAPSHOT_DIR/profiles-mobiledevice/"
fi

if [[ -d "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" ]]; then
  cp -R "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/." "$SNAPSHOT_DIR/profiles-xcode/"
fi

if [[ -f "$HOME/Library/Keychains/login.keychain-db" ]]; then
  cp "$HOME/Library/Keychains/login.keychain-db" "$SNAPSHOT_DIR/keychains/login.keychain-db"
fi

if [[ -n "${SIGNING_KEYCHAIN:-}" && -f "$SIGNING_KEYCHAIN" ]]; then
  cp "$SIGNING_KEYCHAIN" "$SNAPSHOT_DIR/keychains/$(basename "$SIGNING_KEYCHAIN")"
fi

if [[ -n "${SIGNING_KEYCHAIN_PASSWORD_FILE:-}" && -f "$SIGNING_KEYCHAIN_PASSWORD_FILE" ]]; then
  cp -p "$SIGNING_KEYCHAIN_PASSWORD_FILE" "$SNAPSHOT_DIR/private-signing/$(basename "$SIGNING_KEYCHAIN_PASSWORD_FILE")"
  chmod 600 "$SNAPSHOT_DIR/private-signing/$(basename "$SIGNING_KEYCHAIN_PASSWORD_FILE")"
fi

for keychain_path in \
  "$HOME/Library/Mobile Documents/.Trash/login_renamed_1.keychain-db" \
  "$HOME/Library/Mobile Documents/.Trash/login_renamed_2.keychain-db" \
  "$HOME/Library/Mobile Documents/.Trash/login_rebuilt_shell_20260723_1.keychain-db" \
  "$HOME/Library/Keychains/login_signing_restore_20260724.keychain-db"; do
  if [[ -f "$keychain_path" ]]; then
    cp "$keychain_path" "$SNAPSHOT_DIR/keychains/$(basename "$keychain_path")"
  fi
done

security list-keychains > "$SNAPSHOT_DIR/metadata/keychains.txt" 2>&1 || true
apple_release_security list-keychains > "$SNAPSHOT_DIR/metadata/keychains.txt" 2>&1 || true
apple_release_security default-keychain > "$SNAPSHOT_DIR/metadata/default-keychain.txt" 2>&1 || true
apple_release_unlock_keychain
apple_release_security find-identity -v -p codesigning "${SIGNING_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}" > "$SNAPSHOT_DIR/metadata/codesigning-identities.txt" 2>&1 || true
apple_release_security find-certificate -a -p > "$SNAPSHOT_DIR/metadata/all-certificates.pem" 2>/dev/null || true
find "$HOME/Library/MobileDevice/Provisioning Profiles" -maxdepth 1 -name '*.mobileprovision' > "$SNAPSHOT_DIR/metadata/mobiledevice-profiles.txt" 2>/dev/null || true
find "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" -maxdepth 1 -name '*.mobileprovision' > "$SNAPSHOT_DIR/metadata/xcode-profiles.txt" 2>/dev/null || true

cat > "$SNAPSHOT_DIR/metadata/README.txt" <<'EOF'
This snapshot is a local backup of Apple signing metadata and provisioning profiles.

It intentionally captures:
- provisioning profiles from both standard local locations
- active and known historical signing keychain database files
- keychain search-list/default-keychain metadata
- visible code-signing identity listings
- certificate PEM exports when available

It does not automatically export private keys.
If exportable signing identities are available, create a separate encrypted .p12 backup manually.
The private-signing directory is sensitive and may include the shared signing keychain password file.
EOF

echo "Backup created at: $SNAPSHOT_DIR"
