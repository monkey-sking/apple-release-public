# Apple Release

<!-- badges:start -->
[![Stars](https://img.shields.io/github/stars/monkey-sking/apple-release-public?style=flat-square)](https://github.com/monkey-sking/apple-release-public/stargazers) [![Forks](https://img.shields.io/github/forks/monkey-sking/apple-release-public?style=flat-square)](https://github.com/monkey-sking/apple-release-public/network/members) [![Last commit](https://img.shields.io/github/last-commit/monkey-sking/apple-release-public?style=flat-square)](https://github.com/monkey-sking/apple-release-public/commits/main)
<!-- badges:end -->

Reusable shell helpers for Apple signing, provisioning, package verification,
build-cache layout, TestFlight and Developer ID release workflows.

## What is included

- `lib/`: environment loading, signing helpers, lane preflight and artifact checks.
- `bin/`: profile installation, local backup, preflight and onboarding tools.
- `config/`: sanitized templates only.

This is release infrastructure, not a shipped app. Actual signing, notarization
and upload require your own Apple account, certificates and project configuration.
The public repository does not include the author's operational records or assets.

## Configuration boundary

Store real configuration outside the checkout, for example:

```text
~/.config/apple-release/shared.env
~/.config/apple-release/projects/myapp.env
```

Set the directory to mode `0700` and files to `0600`. Use ignored compatibility
links at `config/shared.env` and `config/projects/myapp.env`, or set
`APPLE_RELEASE_SHARED_ENV` and `APPLE_RELEASE_PROJECT_ENV`. Existing app entry
points can continue loading the same paths.

Start from `config/shared.example.env` and `config/projects/_template.env`.
Supply your own team, bundle, certificate fingerprint and notary profile values.
Missing fingerprints fail with a configuration error instead of matching an
empty string or falling back to someone else's certificate.

Keep certificates, private keys, keychains, password files, provisioning profiles,
logs and backups private. Existing ignored `private/`, `backups/` and `logs/`
directories remain supported; never publish their contents.

## Validation

```bash
python3 -m unittest discover -s tests -v
git config core.hooksPath .githooks
python3 scripts/check_public_history.py --staged
python3 scripts/check_public_history.py main
```

Tests use temporary fixtures and stubs. Passing them does not establish a
successful real signing, notarization, TestFlight upload or device installation.
Run the lane-specific preflight on your own machine before a release. Keychain
setup and release commands can change local state; inspect their inputs first.

## License

MIT for this repository's code. Apple tools and third-party software retain
their own licenses.
