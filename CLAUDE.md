# AcmeBank — Project Context

## Overview
AcmeBank is an iOS banking app (iOS 17+, Swift 5.10, SwiftUI) that lets customers view accounts and transactions, initiate transfers, pay bills, and manage their profile — secured by Okta OIDC. The Login screen UI + ViewModel is shipped; all subsequent feature screens follow in later PRs.

## Tech Stack
| Concern | Choice |
|---|---|
| Platform | iOS 17+, Swift 5.10, Xcode 16.0+ |
| UI Framework | SwiftUI |
| Architecture | MVVM + Coordinator (`NavigationStack`) |
| Auth | Okta OIDC (`okta-mobile-swift` 2.x) |
| Networking | `URLSession` + async/await |
| Dependency Injection | Constructor injection (no service locator) |
| Notifications | `NotificationCenter` with typed wrappers |
| Project file | XcodeGen `project.yml` (never hand-craft `.xcodeproj`) |
| Test framework | XCTest (unit) + XCUITest (critical flows only) |
| Bundle ID | `com.acmebank.mobile` |

## How to Run Locally
```bash
./setup.sh          # installs xcodegen if missing, generates .xcodeproj, opens Xcode
# or manually:
brew install xcodegen
xcodegen generate
open AcmeBank.xcodeproj
```

## How to Run Tests
```bash
xcodebuild test \
  -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

## Key Directory Structure
```
AcmeBank/                      ← app source root (XcodeGen glob picks up all .swift)
  App/
    AcmeBankApp.swift          ← @main SwiftUI entry — presents LoginView on launch (implemented)
  ContentView.swift            ← Hello World placeholder (superseded; kept for bootstrap test ref)
  AcmeBank.entitlements        ← keychain-access-groups stub (implemented)
  PrivacyInfo.xcprivacy        ← required-reason API manifest (implemented)
  Resources/
    Assets.xcassets/           ← asset catalog with stub AppIcon (implemented)
  Features/Login/              ← LoginView, LoginViewModel, LoginView+Accessibility (implemented)
  Core/Auth/                   ← AuthService, KeychainStore, UserSession (deferred)
  Core/Networking/             ← APIClient, APIRouter, APIError, RequestInterceptor (deferred)
  Core/Notifications/          ← AppNotification, NotificationPublisher (deferred)
  Core/Extensions/             ← Decimal+Currency, Date+Greeting, String+Initials (deferred)
  Domain/Models/               ← Account, Transaction, Customer, TransferRequest (deferred)
  Domain/Repositories/         ← protocol-only repository interfaces (deferred)
  Data/Remote/                 ← APIRepository implementations (deferred)
  Data/Mock/                   ← MockRepository implementations (deferred)
  Features/Home/               ← HomeView, HomeViewModel, HomeCoordinator (deferred)
  Features/Accounts/           ← (deferred)
  Features/Transfer/           ← (deferred)
  Features/Cards/              ← (deferred)
  DesignSystem/                ← Colors.swift, Typography.swift (deferred)
AcmeBankTests/
  AcmeBankTests.swift          ← bootstrap smoke test (implemented)
  LoginViewModelTests.swift    ← LoginViewModel unit tests (implemented)
AcmeBankUITests/               ← XCUITest target (implemented — login smoke tests)
  LoginScreenUITests.swift     ← login screen reachability + field/button presence (implemented)
project.yml                    ← XcodeGen spec (implemented; includes AcmeBankUITests target)
setup.sh                       ← one-shot project materialisation (implemented)
```

## Planned Architecture

### MVVM + Coordinator (deferred — future PR)
- **View**: SwiftUI struct; renders from ViewModel `@Published` state; zero business logic.
- **ViewModel**: `final class: ObservableObject`; calls repositories; posts `AppNotification`s; no SwiftUI imports.
- **Coordinator**: `ObservableObject`; owns `NavigationStack` path; creates child Views + ViewModels; no imperative `push`/`present`.
- **Repository protocols** in `Domain/`; concrete implementations in `Data/`.

### Coordinator hierarchy (deferred — future PR)
```
AppCoordinator → LoginCoordinator (no session)
              → TabBarCoordinator → HomeCoordinator
                                  → TransferCoordinator
                                  → CardsCoordinator
                                  → MoreCoordinator
```

### Authentication — Okta OIDC (deferred — future PR)
`AuthService` wraps `okta-mobile-swift`. `signIn` runs browser-based OIDC, persists tokens to Keychain via `KeychainStore`, returns `UserSession`. `RequestInterceptor` refreshes tokens before every request; on failure posts `AppNotification.sessionExpired`.

### Keychain usage — REQUIRED pattern for all future Keychain calls
Any Keychain query dictionary MUST include `kSecUseDataProtectionKeychain: true` so CI simulator builds (which run `CODE_SIGNING_ALLOWED=NO`) work without provisioning profiles:
```swift
var query: [String: Any] = [
  kSecClass as String:                      kSecClassGenericPassword,
  kSecAttrService as String:                "com.acmebank.mobile",
  kSecAttrAccount as String:                "accessToken",
  kSecUseDataProtectionKeychain as String:  true,  // ← required for CI
]
```

### Networking (deferred — future PR)
`APIClient` wraps `URLSession` with `JSONDecoder` (`.convertFromSnakeCase`, `.iso8601`). HTTP 401 posts `AppNotification.sessionExpired`. `API_BASE_URL` injected via xcconfig; never hardcoded.

### Design System (deferred — future PR)
`DesignSystem/Colors.swift` — `Color.acmeNavy`, `.acmeBackground`, etc.
`DesignSystem/Typography.swift` — `Font.acmeTitle`, `.acmeHeadline`, etc. All sizes paired with Dynamic Type relative styles.

## Deferred Work
- Okta OIDC auth (`AuthService`, `KeychainStore`, `UserSession`, `Okta.plist`) — future PR
- MVVM + Coordinator scaffold (`AppCoordinator`, `RootView`, coordinators) — future PR
- Networking layer (`APIClient`, `APIRouter`, `APIError`, `RequestInterceptor`) — future PR
- Domain models (`Account`, `Transaction`, `Customer`, `TransferRequest`) — future PR
- Repository protocols + mock/remote implementations — future PR
- Feature screens (Home, Accounts, Transfer, Cards, More) — future PR
- Design system tokens (`Colors.swift`, `Typography.swift`) — future PR
- Internal notifications (`AppNotification`, `NotificationPublisher`) — future PR
- Login → real Okta auth wiring (replace stub `signIn` closure) — future PR
- SwiftLint (`.swiftlint.yml`) — future PR
- CI workflow (`ios-build.yml`, xcconfig injection, `API_BASE_URL`) — future PR
- `Localizable.strings`, `Okta.plist.example`, extensions — future PR

## Git Workflow

> **Default PR target branch: `develop`.** Every feature/refactor/docs PR
> opens against `develop`. PRs are only opened against `qa`, `uat`, or
> `main` for explicit promotion PRs.

**Branch model (`develop` → `qa` → `uat` → `main`):**

| Branch  | Role                                 | Receives PRs from              | Promotes to |
|---------|--------------------------------------|--------------------------------|-------------|
| develop | Default integration branch           | feature branches               | qa          |
| qa      | First quality gate                   | develop (promotion PR)         | uat         |
| uat     | Pre-prod acceptance                  | qa (promotion PR)              | main        |
| main    | Production / release tags            | uat (promotion PR)             | tagged only |

All feature PRs MUST target `develop`. Never open a feature PR against
`qa`, `uat`, or `main`. Promotions happen via dedicated promotion PRs.
