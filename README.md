# AcmeBank iOS

An iOS banking app built with SwiftUI, MVVM + Coordinator, and Okta OIDC authentication.

## Quick Start

```bash
./setup.sh
```

This installs [XcodeGen](https://github.com/yonaskolb/XcodeGen) if missing, generates `AcmeBank.xcodeproj` from `project.yml`, and opens the project in Xcode.

**Manual fallback** (for environments that block shell scripts):
```bash
brew install xcodegen
xcodegen generate
open AcmeBank.xcodeproj
```

## Requirements
- macOS 14+
- Xcode 16.0+
- iOS 17+ Simulator

## Running Tests

```bash
xcodebuild test \
  -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

## Project Structure

The Xcode project is **generated** from `project.yml` — never commit `AcmeBank.xcodeproj`. See `CLAUDE.md` / `AGENT.md` for full architecture documentation and planned feature roadmap.

## Okta build configuration

AcmeBank reads its Okta tenant values from **build-machine environment
variables** — never from a committed `Okta.plist`, `.xcconfig`, or `.env`
file.  A `postBuildScripts` Run Script phase in `project.yml` writes the
env-var values (or the sentinel `OKTA_NOT_CONFIGURED` when an env var is
unset) into the bundled `Info.plist` via `plutil -replace`.  At runtime
`OktaConfig.load()` reads those keys and returns `.configured(…)` or
`.notConfigured(reason:)`.  Missing env vars **never hard-fail the
build** — a fresh `git clone && xcodebuild` always succeeds.

### Required env vars

| Var                  | Example                                          |
|----------------------|--------------------------------------------------|
| `OKTA_ISSUER`        | `https://dev-12345.okta.com/oauth2/default`      |
| `OKTA_CLIENT_ID`     | `0oaABCDEF1234567890`                            |
| `OKTA_REDIRECT_URI`  | `com.acmebank.mobile:/callback`                  |
| `OKTA_SCOPES`        | `openid profile offline_access` (space or comma) |

### Three ways to make Xcode / xcodebuild see them

**1. Xcode launched from Finder/Dock (GUI session).**
GUI apps inherit `launchd`'s environment, not your shell's.  Set the
vars at the user-launchd level *once* and they survive logout:
```bash
launchctl setenv OKTA_ISSUER       "https://dev-12345.okta.com/oauth2/default"
launchctl setenv OKTA_CLIENT_ID    "0oaABCDEF1234567890"
launchctl setenv OKTA_REDIRECT_URI "com.acmebank.mobile:/callback"
launchctl setenv OKTA_SCOPES       "openid profile offline_access"
# then fully quit and reopen Xcode
```

**2. Xcode launched from a shell (`xed .`).**  A shell-launched Xcode
inherits the shell's environment, so an `export` in `~/.zshrc` is
enough — but you must launch Xcode from that shell:
```bash
# in ~/.zshrc
export OKTA_ISSUER="https://dev-12345.okta.com/oauth2/default"
export OKTA_CLIENT_ID="0oaABCDEF1234567890"
export OKTA_REDIRECT_URI="com.acmebank.mobile:/callback"
export OKTA_SCOPES="openid profile offline_access"
```
Then from a fresh terminal:
```bash
cd path/to/AcmeBank
xed .
```

**3. Per-command (CI, scripted builds).**  Pass them on the
`xcodebuild` command line so they appear in `xcodebuild`'s own
environment:
```bash
OKTA_ISSUER="$OKTA_ISSUER" \
OKTA_CLIENT_ID="$OKTA_CLIENT_ID" \
OKTA_REDIRECT_URI="$OKTA_REDIRECT_URI" \
OKTA_SCOPES="$OKTA_SCOPES" \
xcodebuild build \
  -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

> **Why the explicit per-command form for CI?**  `xcodebuild` runs each
> Run Script build phase as a subshell via `PhaseScriptExecution`, and
> that subshell does **not** inherit job-level env vars exported only
> in the parent CI process unless they are present in `xcodebuild`'s
> own environment at invocation time.  Exporting in the CI job alone
> ("env: …" or "echo OKTA_ISSUER=… >> $GITHUB_ENV") is not always
> enough — wiring them onto the `xcodebuild` command line guarantees
> the build phase sees them.
