# Publication and runtime boundaries

- Real environment files belong outside this checkout. Preserve local ignored
  compatibility links and their contents.
- Commit sanitized templates only; never copy real IDs, fingerprints, account
  data, machine paths, signing material or operational records into code/docs.
- Before committing: `python3 scripts/check_public_history.py --staged`.
- Before pushing: `python3 scripts/check_public_history.py main`.
- Enable both hooks with `git config core.hooksPath .githooks`.
- Preserve unrelated work and active signing configuration. Signing, certificate
  replacement, keychain changes and remote uploads require explicit authorization.
- A clean repository does not revoke a credential. Keep these acceptance
  conditions separate.
