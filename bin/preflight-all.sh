#!/bin/bash

set -euo pipefail

APPLE_RELEASE_HOME="${APPLE_RELEASE_HOME:-$HOME/apple-release}"
PROJECTS=("$@")

if [[ ${#PROJECTS[@]} -eq 0 ]]; then
  PROJECTS=(onejot fitbridge aura aion aether)
fi

for project in "${PROJECTS[@]}"; do
  "${APPLE_RELEASE_HOME}/bin/preflight-project.sh" "$project"
done

echo "All Apple release preflights OK: ${PROJECTS[*]}"
