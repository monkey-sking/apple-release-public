#!/bin/bash

set -euo pipefail

APPLE_RELEASE_HOME="${APPLE_RELEASE_HOME:-$HOME/apple-release}"
# shellcheck disable=SC1091
source "${APPLE_RELEASE_HOME}/lib/common.sh"
apple_release_load_project_env ""
: "${APPLE_DISTRIBUTION_FINGERPRINT:?Configure APPLE_DISTRIBUTION_FINGERPRINT}"
: "${APPLE_DEVELOPER_ID_FINGERPRINT:?Configure APPLE_DEVELOPER_ID_FINGERPRINT}"

MATERIAL_DIR="${APPLE_RELEASE_REISSUE_DIR:-${APPLE_RELEASE_HOME}/private/20260725-reissue}"
SIGNING_DIR="${APPLE_RELEASE_SIGNING_DIR:-${APPLE_RELEASE_HOME}/private/signing}"
KEYCHAIN_PATH="${SIGNING_KEYCHAIN:-${SIGNING_DIR}/apple-release-signing.keychain-db}"
PASSWORD_FILE="${SIGNING_KEYCHAIN_PASSWORD_FILE:-${SIGNING_DIR}/apple-release-signing.password}"

required_files=(
  "${MATERIAL_DIR}/apple-distribution.key"
  "${MATERIAL_DIR}/apple-distribution.cer"
  "${MATERIAL_DIR}/developer-id-application.key"
  "${MATERIAL_DIR}/developer-id-application.cer"
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "$required_file" ]]; then
    echo "Missing signing material: $required_file" >&2
    exit 1
  fi
done

mkdir -p "$SIGNING_DIR"
chmod 700 "$SIGNING_DIR"

if [[ ! -f "$PASSWORD_FILE" ]]; then
  openssl rand -hex 16 > "$PASSWORD_FILE"
  chmod 600 "$PASSWORD_FILE"
fi

SIGNING_KEYCHAIN_PASSWORD="$(tr -d '\r\n' < "$PASSWORD_FILE")"
export SIGNING_KEYCHAIN="$KEYCHAIN_PATH"
export SIGNING_KEYCHAIN_PASSWORD

if [[ ! -f "$KEYCHAIN_PATH" ]]; then
  apple_release_log "Creating shared signing keychain: $KEYCHAIN_PATH"
  apple_release_security create-keychain -p "$SIGNING_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
fi

apple_release_unlock_keychain

apple_release_log "Importing Apple Distribution identity..."
apple_release_security import "${MATERIAL_DIR}/apple-distribution.key" -k "$KEYCHAIN_PATH" -P "" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
apple_release_security import "${MATERIAL_DIR}/apple-distribution.cer" -k "$KEYCHAIN_PATH" >/dev/null

apple_release_log "Importing Developer ID Application identity..."
apple_release_security import "${MATERIAL_DIR}/developer-id-application.key" -k "$KEYCHAIN_PATH" -P "" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
apple_release_security import "${MATERIAL_DIR}/developer-id-application.cer" -k "$KEYCHAIN_PATH" >/dev/null

apple_release_security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
apple_release_security set-key-partition-list -S apple-tool:,apple: -s -k "$SIGNING_KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
apple_release_configure_keychain_search_list "$KEYCHAIN_PATH" >/dev/null

apple_release_require_identity "${APPLE_DISTRIBUTION_FINGERPRINT:?Configure APPLE_DISTRIBUTION_FINGERPRINT}"
apple_release_require_identity "${APPLE_DEVELOPER_ID_FINGERPRINT:?Configure APPLE_DEVELOPER_ID_FINGERPRINT}"

echo "Shared signing keychain OK:"
echo "  keychain: $KEYCHAIN_PATH"
echo "  password file: $PASSWORD_FILE"
