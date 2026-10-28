#!/bin/bash

apple_release_require_file() {
    local path="${1:?artifact path required}"
    if [[ ! -f "$path" && ! -d "$path" ]]; then
        echo "❌ Required artifact not found: $path" >&2
        return 1
    fi
}

apple_release_sha256() {
    local path="${1:?artifact path required}"
    apple_release_require_file "$path"
    if [[ -d "$path" ]]; then
        ditto -c -k --sequesterRsrc --keepParent "$path" - | shasum -a 256 | awk '{print $1}'
    else
        shasum -a 256 "$path" | awk '{print $1}'
    fi
}

apple_release_print_artifact_summary() {
    local label="${1:?artifact label required}"
    local path="${2:?artifact path required}"
    apple_release_require_file "$path"
    echo "   ${label}: ${path}"
    echo "   ${label} SHA-256: $(apple_release_sha256 "$path")"
}

apple_release_verify_ipa() {
    local path="${1:?IPA path required}"
    apple_release_require_file "$path"
    [[ "$(file -b "$path")" == *Zip* ]] || { echo "❌ IPA is not a ZIP archive: $path" >&2; return 1; }
    echo "✅ IPA: $path"
    echo "   SHA-256: $(apple_release_sha256 "$path")"
}

apple_release_verify_app() {
    local path="${1:?app path required}"
    apple_release_require_file "$path"
    /usr/bin/codesign --verify --deep --strict "$path"
    echo "✅ Signed app: $path"
    echo "   SHA-256: $(apple_release_sha256 "$path")"
}
