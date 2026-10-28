#!/bin/bash

# Shared build-cache contract. Project scripts may override the root with
# APPLE_RELEASE_BUILD_ROOT, but must keep one stable path per project/lane.

apple_release_cache_root() {
    local project="${1:?project name required}"
    local lane="${2:?lane name required}"
    printf '%s\n' "${APPLE_RELEASE_BUILD_ROOT:-$HOME/Library/Caches/apple-release}/${project}/${lane}"
}

apple_release_prepare_cache() {
    local root="${1:?cache root required}"
    mkdir -p "$root/DerivedData" "$root/Archive" "$root/Export" "$root/Logs" "$root/Evidence"
}

apple_release_clean_output() {
    local root="${1:?cache root required}"
    rm -rf "$root/Archive/current.xcarchive" "$root/Export/current" "$root/Evidence/current.xcresult"
}

apple_release_require_stable_cache_path() {
    local path="${1:?cache path required}"
    case "$path" in
        *' '*|*/*/tmp/*|/tmp/*|/private/tmp/*)
            return 0
            ;;
    esac
    if [[ "$path" == *-20[0-9][0-9][0-9][0-9][0-9][0-9]* || "$path" == *v[0-9]-* || "$path" == *review-* ]]; then
        echo "❌ Refusing task-specific permanent build path: $path" >&2
        return 1
    fi
}
