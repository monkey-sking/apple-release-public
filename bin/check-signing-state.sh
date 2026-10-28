#!/bin/bash

set -euo pipefail

APPLE_RELEASE_HOME="${APPLE_RELEASE_HOME:-$HOME/apple-release}"
# shellcheck disable=SC1091
source "${APPLE_RELEASE_HOME}/lib/common.sh"
apple_release_load_project_env ""
: "${APPLE_DISTRIBUTION_FINGERPRINT:?Configure APPLE_DISTRIBUTION_FINGERPRINT}"
: "${APPLE_DEVELOPER_ID_FINGERPRINT:?Configure APPLE_DEVELOPER_ID_FINGERPRINT}"

KEYCHAIN_PATH="${SIGNING_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"

apple_release_unlock_keychain
apple_release_security find-identity -v -p codesigning "$KEYCHAIN_PATH" 2>&1 | /usr/bin/grep -F "${APPLE_DISTRIBUTION_FINGERPRINT:?Configure APPLE_DISTRIBUTION_FINGERPRINT}" >/dev/null
apple_release_security find-identity -v -p codesigning "$KEYCHAIN_PATH" 2>&1 | /usr/bin/grep -F "${APPLE_DEVELOPER_ID_FINGERPRINT:?Configure APPLE_DEVELOPER_ID_FINGERPRINT}" >/dev/null

echo "Signing state OK"
