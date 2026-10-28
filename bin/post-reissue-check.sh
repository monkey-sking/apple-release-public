#!/bin/bash

set -euo pipefail

APPLE_RELEASE_HOME="${APPLE_RELEASE_HOME:-$HOME/apple-release}"
# shellcheck disable=SC1091
source "${APPLE_RELEASE_HOME}/lib/common.sh"
apple_release_load_project_env ""

KEYCHAIN_PATH="${SIGNING_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
apple_release_unlock_keychain

echo "=== active keychain ==="
apple_release_security default-keychain 2>&1 || true
echo

echo "=== active codesigning identities ==="
apple_release_security find-identity -v -p codesigning "$KEYCHAIN_PATH" 2>&1 || true
echo

echo "=== required live identity fingerprints ==="
echo "Apple Distribution: ${APPLE_DISTRIBUTION_FINGERPRINT:?Configure APPLE_DISTRIBUTION_FINGERPRINT}"
echo "Developer ID Application: ${APPLE_DEVELOPER_ID_FINGERPRINT:?Configure APPLE_DEVELOPER_ID_FINGERPRINT}"
echo

echo "=== notary profiles ==="
for item in AionRelease AetherRelease; do
  echo "--- $item ---"
  apple_release_notarytool history --keychain-profile "$item" --keychain "$KEYCHAIN_PATH" 2>&1 | sed -n '1,8p' || true
done
echo

echo "=== signing keychain password source ==="
if [[ -n "${SIGNING_KEYCHAIN_PASSWORD_FILE:-}" && -r "${SIGNING_KEYCHAIN_PASSWORD_FILE}" ]]; then
  echo "password file present: ${SIGNING_KEYCHAIN_PASSWORD_FILE}"
else
  apple_release_security find-generic-password -s "${SIGNING_KEYCHAIN_PASSWORD_ITEM:-SIGNING_KEYCHAIN_PASSWORD}" -a "${SIGNING_KEYCHAIN_PASSWORD_ACCOUNT:-$USER}" 2>&1 || true
fi
echo

echo "=== recommended next project preflights ==="
echo "onejot: /bin/bash ${APPLE_RELEASE_HOME}/bin/preflight-project.sh onejot"
echo "aion: /bin/bash ${APPLE_RELEASE_HOME}/bin/preflight-project.sh aion"
