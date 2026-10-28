#!/bin/bash

set -euo pipefail

PROJECT_NAME="${1:?Usage: preflight-project.sh <project>}"
APPLE_RELEASE_HOME="${APPLE_RELEASE_HOME:-$HOME/apple-release}"

# shellcheck disable=SC1091
source "${APPLE_RELEASE_HOME}/lib/common.sh"
apple_release_load_project_env "$PROJECT_NAME"
apple_release_unlock_keychain

case "${APPLE_RELEASE_LANE:-}" in
  ios-testflight)
    # shellcheck disable=SC1091
    source "${APPLE_RELEASE_HOME}/lib/ios-testflight.sh"
    apple_release_ios_preflight
    ;;
  macos-developer-id)
    # shellcheck disable=SC1091
    source "${APPLE_RELEASE_HOME}/lib/macos-developer-id.sh"
    apple_release_macos_preflight
    ;;
  *)
    echo "Unknown APPLE_RELEASE_LANE for project ${PROJECT_NAME}: ${APPLE_RELEASE_LANE:-<unset>}" >&2
    exit 1
    ;;
esac

echo "Preflight OK: ${PROJECT_NAME} (${APPLE_RELEASE_LANE})"
