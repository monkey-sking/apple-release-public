#!/bin/bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /absolute/path/to/profile.mobileprovision" >&2
  exit 1
fi

APPLE_RELEASE_HOME="${APPLE_RELEASE_HOME:-$HOME/apple-release}"
# shellcheck disable=SC1091
source "${APPLE_RELEASE_HOME}/lib/common.sh"

PROFILE_PATH="$1"

if [[ ! -f "$PROFILE_PATH" ]]; then
  echo "Profile not found: $PROFILE_PATH" >&2
  exit 1
fi

apple_release_install_profile_if_present "$PROFILE_PATH"

