#!/bin/bash

set -euo pipefail

APPLE_RELEASE_HOME="${APPLE_RELEASE_HOME:-$HOME/apple-release}"
# shellcheck disable=SC1091
source "${APPLE_RELEASE_HOME}/lib/common.sh"
apple_release_load_project_env "${APPLE_RELEASE_PROJECT:-}"

PROFILE_NAME="${NOTARY_PROFILE:?Set NOTARY_PROFILE}"
SIGNING_KEYCHAIN="${SIGNING_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
apple_release_unlock_keychain

if [[ -n "${ASC_KEY_FILEPATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
  apple_release_notarytool store-credentials "$PROFILE_NAME" \
    --key "$ASC_KEY_FILEPATH" \
    --key-id "$ASC_KEY_ID" \
    --issuer "$ASC_ISSUER_ID" \
    --keychain "$SIGNING_KEYCHAIN" \
    --validate
else
  APPLE_ID="${APPLE_ID:?Set APPLE_ID or ASC_KEY_FILEPATH/ASC_KEY_ID/ASC_ISSUER_ID}"
  TEAM_ID="${TEAM_ID:?Set TEAM_ID when using Apple ID credentials}"
  APPLE_APP_PASSWORD="${APPLE_APP_PASSWORD:-${APP_SPECIFIC_PASSWORD:-}}"

  if [[ -z "$APPLE_APP_PASSWORD" ]]; then
    echo "Set APPLE_APP_PASSWORD or APP_SPECIFIC_PASSWORD before running this script." >&2
    exit 1
  fi

  apple_release_notarytool store-credentials "$PROFILE_NAME" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --keychain "$SIGNING_KEYCHAIN" \
    --validate
fi

echo "Stored notary profile: $PROFILE_NAME"
