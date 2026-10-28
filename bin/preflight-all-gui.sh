#!/bin/zsh

set -euo pipefail

osascript -e "do shell script \"/bin/bash ${APPLE_RELEASE_HOME:-$HOME/apple-release}/bin/preflight-all.sh\""
