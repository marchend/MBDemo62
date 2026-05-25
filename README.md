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
