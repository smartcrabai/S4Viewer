# S4 Viewer

A native macOS browser for Amazon S3 and S3-compatible object stores. Built with SwiftUI and SwiftData, it implements AWS Signature V4 on top of `URLSession` and `CryptoKit` with no dependency on an external AWS SDK.

## Features

- **Connection profiles** — Store multiple S3 / S3-compatible endpoints (AWS S3, MinIO, Cloudflare R2, Backblaze B2, and so on) in SwiftData. Both path-style and virtual-hosted-style addressing are supported.
- **Object browsing** — Folders pinned on top, sort by name / size / modification date / kind, and incremental filtering.
- **Upload / download** — Files larger than 8 MiB automatically switch to multipart transfers. Multi-file uploads run up to three in parallel.
- **Preview** — Inline rendering for text-like objects, Quick Look for everything else.
- **Editing** — Create folders, rename (recursively rewriting keys under a folder), and delete.
- **Transfer monitor** — Active transfers are listed inline and auto-dismissed shortly after they complete.

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

The app is built with App Sandbox and Hardened Runtime enabled. The user-selected read-write entitlement (`com.apple.security.files.user-selected.read-write`) is used for upload and download.

## Tests

Unit tests are written with Swift Testing.

```sh
xcodebuild -project "S4 Viewer.xcodeproj" \
           -scheme "S4 Viewer" \
           -destination 'platform=macOS' \
           test
```

Primary test targets:

| File | Covers |
|---|---|
| `S3RequestSignerTests.swift` | Signature V4 against AWS reference test vectors |
| `S3ListObjectsResponseParserTests.swift` | `ListObjectsV2` XML parsing |
| `MultipartTransferPlannerTests.swift` | Multipart part planning |
| `ConnectionProfileDraftTests.swift` | Connection input validation |
| `S3BrowserCoreTests.swift` | Sorting, filtering, preview-kind detection |

## Architecture

| Layer | Key files |
|---|---|
| Persistence | `ConnectionProfile.swift` (SwiftData `@Model`) |
| Input / validation | `ConnectionProfileDraft.swift`, `S3ConnectionConfiguration.swift` |
| Networking | `S3HTTPClient.swift`, `S3RequestSigner.swift` |
| Domain model | `S3BrowserModel.swift`, `S3BrowserItem.swift`, `MultipartTransferPlanner.swift`, `ObjectPreviewKind.swift` |
| UI | `ContentView.swift`, `ConnectionProfileEditorView.swift`, `NamePromptView.swift`, `QuickLookPreviewView.swift` |
