#!/bin/bash

set -euo pipefail

SERVICE_NAME="${SIGNING_KEYCHAIN_PASSWORD_ITEM:-SIGNING_KEYCHAIN_PASSWORD}"
ACCOUNT_NAME="${SIGNING_KEYCHAIN_PASSWORD_ACCOUNT:-$USER}"
KEYCHAIN_PATH="${SIGNING_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"

if [[ -z "${SIGNING_KEYCHAIN_PASSWORD:-}" ]]; then
  echo "Set SIGNING_KEYCHAIN_PASSWORD before running this script." >&2
  exit 1
fi

security delete-generic-password -s "$SERVICE_NAME" -a "$ACCOUNT_NAME" "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
security add-generic-password \
  -U \
  -s "$SERVICE_NAME" \
  -a "$ACCOUNT_NAME" \
  -w "$SIGNING_KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH"

echo "Stored signing keychain password item:"
echo "  service: $SERVICE_NAME"
echo "  account: $ACCOUNT_NAME"
echo "  keychain: $KEYCHAIN_PATH"

