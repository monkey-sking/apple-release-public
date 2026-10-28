#!/bin/bash

set -euo pipefail

APPLE_RELEASE_HOME="${APPLE_RELEASE_HOME:-$HOME/apple-release}"
# shellcheck disable=SC1091
source "${APPLE_RELEASE_HOME}/lib/common.sh"

apple_release_macos_load() {
  apple_release_load_project_env "${1:?default project name required}"

  export APPLE_RELEASE_LANE="${APPLE_RELEASE_LANE:-macos-developer-id}"
  export APPLE_TEAM_ID="${APPLE_TEAM_ID:-${TEAM_ID:-}}"
  export APP_BUNDLE_ID="${APP_BUNDLE_ID:-${BUNDLE_ID:-}}"
}

apple_release_macos_preflight() {
  : "${APPLE_DEVELOPER_ID_FINGERPRINT:?Configure APPLE_DEVELOPER_ID_FINGERPRINT in your private shared.env}"
  security find-identity -v -p codesigning "${SIGNING_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}" 2>&1 | grep -F "${APPLE_DEVELOPER_ID_FINGERPRINT:?Configure APPLE_DEVELOPER_ID_FINGERPRINT in your private shared.env}" >/dev/null
}
