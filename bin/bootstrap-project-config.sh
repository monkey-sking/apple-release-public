#!/bin/bash

set -euo pipefail

APPLE_RELEASE_HOME="${APPLE_RELEASE_HOME:-$HOME/apple-release}"
TEMPLATE_PATH="${APPLE_RELEASE_HOME}/config/projects/_template.env"

usage() {
  cat <<'EOF'
Usage: bootstrap-project-config.sh <project> <lane> <bundle-id> [profile-or-notary-name]

Examples:
  bootstrap-project-config.sh myapp ios-testflight com.example.MyApp "MyApp AppStore"
  bootstrap-project-config.sh mymac macos-developer-id com.example.MyMac "MyMacRelease"

Notes:
  - Creates config/projects/<project>.env from the shared template.
  - Refuses to overwrite an existing project config.
  - The generated file contains only non-secret metadata.
EOF
}

PROJECT_NAME="${1:-}"
LANE="${2:-}"
BUNDLE_ID="${3:-}"
FOURTH_ARG="${4:-}"

if [[ -z "$PROJECT_NAME" || -z "$LANE" || -z "$BUNDLE_ID" ]]; then
  usage
  exit 1
fi

if [[ ! "$PROJECT_NAME" =~ ^[a-z][a-z0-9_-]*$ ]] ||
   [[ ! "$BUNDLE_ID" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]; then
  echo "Invalid project name or bundle ID" >&2
  exit 1
fi

case "$LANE" in
  ios-testflight|macos-developer-id) ;;
  *)
    echo "Unsupported lane: $LANE" >&2
    usage
    exit 1
    ;;
esac

if [[ ! -f "$TEMPLATE_PATH" ]]; then
  echo "Template not found: $TEMPLATE_PATH" >&2
  exit 1
fi

DEST_PATH="${APPLE_RELEASE_HOME}/config/projects/${PROJECT_NAME}.env"
if [[ -e "$DEST_PATH" ]]; then
  echo "Project config already exists: $DEST_PATH" >&2
  exit 1
fi

umask 077
mkdir -p "$(dirname "$DEST_PATH")"
cp "$TEMPLATE_PATH" "$DEST_PATH"

python3 - "$DEST_PATH" "$PROJECT_NAME" "$LANE" "$BUNDLE_ID" "$FOURTH_ARG" <<'PY'
import sys
import shlex
from pathlib import Path

dest = Path(sys.argv[1])
project_name = sys.argv[2]
lane = sys.argv[3]
bundle_id = sys.argv[4]
fourth = sys.argv[5]

text = dest.read_text()
text = text.replace('export APPLE_RELEASE_PROJECT="example"', f'export APPLE_RELEASE_PROJECT="{project_name}"')
text = text.replace('export APPLE_RELEASE_LANE="ios-testflight" # or macos-developer-id', f'export APPLE_RELEASE_LANE="{lane}"')
text = text.replace('export APP_BUNDLE_ID="com.example.app"', f'export APP_BUNDLE_ID="{bundle_id}"', 1)
text = text.replace('export ASC_APP_BUNDLE_ID="com.example.app"', f'export ASC_APP_BUNDLE_ID="{bundle_id}"')

if lane == "ios-testflight":
    profile_name = fourth or f"{project_name} AppStore"
    profile_file = f"{project_name}_AppStore.mobileprovision"
    text = text.replace('export PROFILE_NAME="Example AppStore"', f'export PROFILE_NAME={shlex.quote(profile_name)}')
    text = text.replace('export PROFILE_SOURCE_PATH="build/testflight/Example_AppStore.mobileprovision"', f'export PROFILE_SOURCE_PATH="build/testflight/{profile_file}"')
else:
    notary_profile = fourth or f"{project_name}Release"
    text = text.replace('export NOTARY_PROFILE="ExampleRelease"', f'export NOTARY_PROFILE={shlex.quote(notary_profile)}')

dest.write_text(text)
PY

echo "Created: $DEST_PATH"
echo
echo "Next steps:"
echo "1. Review the generated file and remove the lane section you do not use."
echo "2. Load config/shared.env and config/projects/${PROJECT_NAME}.env from the app's release script."
echo "3. Run: ${APPLE_RELEASE_HOME}/bin/preflight-project.sh ${PROJECT_NAME}"
echo "4. If a plain shell sees 0 identities, run: ${APPLE_RELEASE_HOME}/bin/preflight-project-gui.sh ${PROJECT_NAME}"
