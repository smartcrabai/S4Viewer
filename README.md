# S4 Viewer

A native macOS browser for Amazon S3 and S3-compatible object stores. Built with SwiftUI and SwiftData, it implements AWS Signature V4 on top of `URLSession` and `CryptoKit` with no dependency on an external AWS SDK.

## Features

- **Connection profiles** - Sync S3 / S3-compatible endpoint metadata with SwiftData and CloudKit while keeping access keys and secret keys in iCloud Keychain. Both path-style and virtual-hosted-style addressing are supported.
- **Object browsing** - Folders pinned on top, sort by name / size / modification date / kind, and incremental filtering.
- **Upload / download** - Files larger than 8 MiB automatically switch to multipart transfers. Multi-file uploads run up to three in parallel.
- **Preview** - Inline rendering for text-like objects, Quick Look for everything else.
- **Editing** - Create folders, rename (recursively rewriting keys under a folder), and delete.
- **Transfer monitor** - Active transfers are listed inline and auto-dismissed shortly after they complete.

## Requirements

- macOS 26.4 or later
- Xcode 26 or later
- Swift 5 (incremental adoption of Swift 6 concurrency)

## Build and run

```sh
# GUI
open "S4 Viewer.xcodeproj"

# CLI
xcodebuild -project "S4 Viewer.xcodeproj" \
           -scheme "S4 Viewer" \
           -destination 'platform=macOS' \
           build
```

The app is built with App Sandbox and Hardened Runtime enabled. The user-selected read-write entitlement (`com.apple.security.files.user-selected.read-write`) is used for upload and download. S3 credentials are stored as synchronizable data-protection Keychain items rather than in the SwiftData store.

## Tests

Three test plans share the `S4 Viewer` scheme:

| Test plan | Targets | Screen | Requires |
|---|---|---|---|
| `UnitTests` (default) | `S4 ViewerTests` | untouched | - |
| `IntentTests` | `S4 ViewerTests` + `IntentAutomationTests` | app window appears, input never captured | Xcode 27, real signing identity |
| `AllTests` | `S4 ViewerTests` + `S4 ViewerUITests` | taken over | - |

`UnitTests` is the scheme default so a local `xcodebuild test` never starts XCUITest, which
drives the real cursor and keyboard and therefore takes over the machine it runs on.

```sh
# Unit tests only (default plan)
xcodebuild -project "S4 Viewer.xcodeproj" \
           -scheme "S4 Viewer" \
           -destination 'platform=macOS' \
           test

# Unit + UI tests. XCUITest takes over the cursor and keyboard of the machine it runs on.
xcodebuild -project "S4 Viewer.xcodeproj" \
           -scheme "S4 Viewer" \
           -destination 'platform=macOS' \
           -testPlan AllTests \
           test
```

Unit tests are written with Swift Testing:

| File | Covers |
|---|---|
| `S3RequestSignerTests.swift` | Signature V4 against AWS reference test vectors |
| `S3ListObjectsResponseParserTests.swift` | `ListObjectsV2` XML parsing |
| `MultipartTransferPlannerTests.swift` | Multipart part planning |
| `ConnectionProfileDraftTests.swift` | Connection input validation |
| `ConnectionCredentialStoreTests.swift` | Keychain credential storage lifecycle |
| `S3BrowserCoreTests.swift` | Sorting, filtering, preview-kind detection |

UI tests are XCTest/XCUITest and run the app in demo mode (`-S4ViewerDemoData`; the harness
also passes `S4VIEWER_DEMO_MODE=1`), where `DemoBucket` replaces the S3 client with an
in-memory bucket, credentials live in memory instead of the Keychain, and both file panels are
replaced by temporary-directory fixtures.
Every element they drive carries an identifier from `AccessibilityIdentifiers.swift`;
`S4 ViewerUITests/Screen.swift` is the page object that mirrors those strings.

| File | Covers |
|---|---|
| `BrowsingUITests.swift` | Root listing, folder entry via double-click and Open, navigate up, empty prefix, every sort mode, filter and clear, refresh |
| `PreviewUITests.swift` | Inline text preview, Quick Look fallback, unsupported type, folder selection, preview cleared on delete |
| `ObjectManagementUITests.swift` | Create folder at root and inside a prefix, duplicate-name error alert, rename object, rename folder with children, delete object, delete folder recursively |
| `TransferUITests.swift` | Download progress row through completion and auto-dismissal, Download disabled for folders, three concurrent uploads, upload into the open prefix |
| `ConnectionProfileUITests.swift` | Add profile, endpoint validation, credential read-back when editing, rename, delete the last profile |
| `S4_ViewerUITestsLaunchTests.swift` | Populated launch window, and the App Store screenshot attachment |

### Running the UI suite without losing the desktop

XCUITest takes over the cursor and keyboard. Run `AllTests` in a VM or on a spare Mac; use
`UnitTests` for normal local work. There is deliberately no CI job for the UI suite.

Still manual: multipart uploads above 8 MiB against a real endpoint, Keychain persistence
across relaunches on a signed build, and iCloud profile sync between Macs. See
`RELEASE_CHECKLIST.md`.

### Intent automation (no cursor, no keyboard)

Debug-only, undiscoverable App Intents drive the live demo model without taking over input.
`S4 ViewerUITests/IntentAutomationTests.swift` covers the launched app through
`AppIntentsTesting`.

Run the suite with Xcode 27 and a real signing identity:

```sh
./Scripts/run-intent-tests.sh
```

XCUITest remains for UI-only behaviour such as sheets, dialogs, transfer-row dismissal,
and Quick Look rendering.

## Architecture

| Layer | Key files |
|---|---|
| Persistence | `ConnectionProfile.swift` (SwiftData `@Model`), `ConnectionCredentialStore.swift` (iCloud Keychain) |
| Input / validation | `ConnectionProfileDraft.swift`, `S3ConnectionConfiguration.swift` |
| Networking | `S3HTTPClient.swift`, `S3RequestSigner.swift` |
| Domain model | `S3BrowserModel.swift`, `S3BrowserItem.swift`, `MultipartTransferPlanner.swift`, `ObjectPreviewKind.swift` |
| UI | `ContentView.swift`, `ConnectionProfileEditorView.swift`, `NamePromptView.swift`, `QuickLookPreviewView.swift` |
