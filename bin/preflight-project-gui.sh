#!/bin/zsh

set -euo pipefail

project="${1:?Usage: preflight-project-gui.sh <onejot|fitbridge|aura|aion|aether>}"

case "$project" in
  onejot|fitbridge|aura|aion|aether)
    ;;
  *)
    echo "Unknown Apple release project: $project" >&2
    exit 64
    ;;
esac

quoted_project="$(printf "%q" "$project")"
osascript -e "do shell script \"/bin/bash ${APPLE_RELEASE_HOME:-$HOME/apple-release}/bin/preflight-project.sh ${quoted_project}\""
