# Bootstrap Plan — AcmeBank iOS

## In scope (this PR)

### Project name + tech stack
- **App name:** AcmeBank
- **Platform:** iOS 17+, Swift 5.10
- **UI Framework:** SwiftUI (`@main` App entry point + `ContentView`)
- **Project file:** XcodeGen `project.yml` (never hand-crafted `.xcodeproj`)
- **Test runner:** XCTest (one unit-test target, one minimal test)
- **Minimum Xcode:** 16.0

### Directory structure (bootstrap only)

```
AcmeBank/                          ← iOS app source root
  App/
    AcmeBankApp.swift              ← @main SwiftUI entry point
  ContentView.swift                ← Hello World placeholder view
  Resources/
    Assets.xcassets/
      AppIcon.appiconset/
        Contents.json              ← stub AppIcon set (prevents actool CI error)
      Contents.json
  AcmeBank.entitlements            ← keychain-access-groups stub
  PrivacyInfo.xcprivacy            ← required-reason API privacy manifest

AcmeBankTests/
  AcmeBankTests.swift              ← one smoke test (ContentView initializes)

project.yml                        ← XcodeGen spec (unit-test only; no UI-test target)
.gitignore                         ← standard iOS/XcodeGen ignores
setup.sh                           ← one-shot: installs xcodegen + opens project
bootstrap_plan.md                  ← this file
CLAUDE.md                          ← project context for Anthropic agents
AGENT.md                           ← identical content for other model families
README.md                          ← minimal developer readme
```

### How to run locally
```bash
./setup.sh          # installs xcodegen if missing, generates .xcodeproj, opens Xcode
# or manually:
brew install xcodegen
xcodegen generate
open AcmeBank.xcodeproj
```

### How to run tests
```
xcodebuild test \
  -scheme AcmeBank \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

### Definition of Hello World
The app launches and shows a single SwiftUI screen with the text **"AcmeBank"** centered on a white background. The one unit test verifies `ContentView()` initializes without crashing — proving the test runner wires up correctly.

---

## Out of scope — deferred to future work

- **MVVM + Coordinator pattern** — `AppCoordinator`, `LoginCoordinator`, `TabBarCoordinator`, `HomeCoordinator`, etc. — future PR
- **Authentication (Okta OIDC)** — `okta-mobile-swift` SDK, `AuthService`, `KeychainStore`, `UserSession`, `Okta.plist` — future PR
- **Networking layer** — `APIClient`, `APIRouter`, `APIError`, `RequestInterceptor`, `URLSession` async/await wrapper — future PR
- **Domain models** — `Account`, `Transaction`, `Customer`, `TransferRequest` — future PR
- **Repository protocols** — `AccountRepositoryProtocol`, `TransactionRepositoryProtocol`, etc. — future PR
- **Mock data layer** — `MockAccountRepository`, `MockTransactionRepository`, `MockCustomerRepository` — future PR
- **Remote data layer** — `AccountAPIRepository`, etc. — future PR
- **Feature screens** — Login, Home, Accounts, Transfer, Cards, More — future PR
- **Design system** — `Colors.swift`, `Typography.swift`, named color/font constants — future PR
- **Internal notifications** — `AppNotification`, `NotificationPublisher`, `NotificationKey` — future PR
- **RootView** (auth-state switcher) — future PR
- **XCUITest target** — `AcmeBankUITests/` (no UI-test target in bootstrap; empty test bundles break CI) — future PR when first critical-flow story (login) ships
- **SwiftLint** — `.swiftlint.yml` config — future PR
- **CI workflow** — `ios-build.yml` (xcodebuild + swiftlint + xcconfig injection) — future PR
- **`API_BASE_URL` xcconfig injection** — future PR
- **`Localizable.strings`** — future PR
- **`Okta.plist.example`** — future PR
- **Extensions** (`Decimal+Currency`, `Date+Greeting`, `String+Initials`) — future PR
