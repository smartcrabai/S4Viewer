# Graph Report - fix-e2e  (2026-08-25)

## Corpus Check
- 51 files · ~86,688 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 788 nodes · 1669 edges · 47 communities (38 shown, 9 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 202 edges (avg confidence: 0.81)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6f1bd74e`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- S3BrowserModel
- S3Credentials
- S3HTTPClient
- ContentView.swift
- DemoBucket
- S3BrowserItem
- Screen
- String
- Foundation
- NamePromptView
- .launch
- ContentView
- S3RequestSigner
- IntentAutomationTests
- A11y
- Review Uncommitted Changes
- ConnectionProfileUITests
- String
- ConnectionProfile
- Equatable
- App Sandbox
- Test-Driven Development
- Contribution Workflow
- Sakoku Workflow
- S4 Viewer
- Review Perspective
- Red document file icon
- AWS Signature V4
- iCloud Keychain
- Review Gap Analysis Report
- Reusable Review Check
- Untracked Source File
- App Review Information
- run-intent-tests.sh
- ConnectionProfileDraft
- Improve Review from Session
- XCUITest UI Suite
- AppIntentsTesting
- Release Checklist
- BrowserPreviewContent
- Improve Review from PR Gap
- Remaining
- BrowserTableView
- Contributing
- S4Viewer Agent Rules
- ObjectPreviewKind

## God Nodes (most connected - your core abstractions)
1. `Screen` - 83 edges
2. `S3BrowserModel` - 65 edges
3. `S3HTTPClient` - 38 edges
4. `ConnectionProfile` - 37 edges
5. `S3BrowserItem` - 36 edges
6. `S3Credentials` - 27 edges
7. `DemoBucket` - 21 edges
8. `S3BrowserSortMode` - 21 edges
9. `ContentView` - 19 edges
10. `IntentAutomationTests` - 18 edges

## Surprising Connections (you probably didn't know these)
- `.selectedProfile` --references--> `ConnectionProfile`  [INFERRED]
  S4 Viewer/ContentView.swift → S4 Viewer/ConnectionProfile.swift
- `StoredObject` --references--> `Date`  [EXTRACTED]
  S4 Viewer/DemoMode.swift → S4 ViewerTests/S3RequestSignerTests.swift
- `S3BrowserItem` --references--> `Date`  [EXTRACTED]
  S4 Viewer/S3BrowserItem.swift → S4 ViewerTests/S3RequestSignerTests.swift
- `S3BrowserCoreTests` --references--> `S3BrowserItem`  [EXTRACTED]
  S4 ViewerTests/S3BrowserCoreTests.swift → S4 Viewer/S3BrowserItem.swift
- `Automated Skill-Update Pull Request` --conceptually_related_to--> `Pull Request Diff`  [INFERRED]
  .github/workflows/update-skills.yml → .claude/skills/review-pr/SKILL.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Document icon visual composition** — s4_viewer_s4viewer_icon_assets_gemini_generated_image_blrg2ublrg2ublrg_document_file, s4_viewer_s4viewer_icon_assets_gemini_generated_image_blrg2ublrg2ublrg_folded_page_corner, s4_viewer_s4viewer_icon_assets_gemini_generated_image_blrg2ublrg2ublrg_text_line_motif [EXTRACTED 1.00]
- **Secure Release and Reporting** — readme_app_sandbox, readme_hardened_runtime, release_checklist_least_privilege_credentials, security_private_vulnerability_reporting [INFERRED 0.75]
- **Review Perspective Lifecycle** — _claude_skills_improve_review_from_pr_gap_skill_original_pr, _claude_skills_improve_review_from_pr_gap_skill_fix_pr, _claude_skills_improve_review_from_pr_gap_skill_review_perspective, _claude_skills_review_pr_skill_generic_review_dimensions [INFERRED 0.85]
- **S4 Viewer Validation Layers** — agents_tdd, agents_intent_automation, readme_unit_tests_plan, readme_intent_tests_plan, readme_all_tests_plan, release_checklist_real_s3_endpoint_verification [INFERRED 0.85]

## Communities (47 total, 9 thin omitted)

### Community 0 - "S3BrowserModel"
Cohesion: 0.12
Nodes (14): DemoAutomationContext, S3BrowserModel, .canNavigateUp, .currentLocationTitle, .filteredItems, .isFilterActive, .sortedItems, Bool (+6 more)

### Community 1 - "S3Credentials"
Cohesion: 0.06
Nodes (38): Any, Codable, CustomDebugStringConvertible, CustomStringConvertible, OSStatus, ConnectionCredentialStore, ConnectionCredentialStoreError, .errorDescription (+30 more)

### Community 2 - "S3HTTPClient"
Cohesion: 0.08
Nodes (29): HTTPURLResponse, HTTPMethod, delete, get, post, put, S3ClientError, .errorDescription (+21 more)

### Community 3 - "ContentView.swift"
Cohesion: 0.14
Nodes (24): ByteCountFormatter, BrowserActionBar, .body, .selectedItem, BrowserColumnView, ConnectionSidebarRow, ConnectionSidebarView, .body (+16 more)

### Community 4 - "DemoBucket"
Cohesion: 0.08
Nodes (19): LocalizedError, DemoBucket, DemoMode, .isEnabled, DemoS3Client, DemoS3Error, alreadyExists, .errorDescription (+11 more)

### Community 5 - "S3BrowserItem"
Cohesion: 0.07
Nodes (29): CaseIterable, Kind, folder, .label, object, .systemImageName, S3BrowserItem, .id (+21 more)

### Community 6 - "Screen"
Cohesion: 0.05
Nodes (41): Screen, .addProfileButton, .confirmDeleteItemButton, .confirmDeleteProfileButton, .deleteButton, .deleteProfileButton, .downloadButton, .editProfileButton (+33 more)

### Community 7 - "String"
Cohesion: 0.16
Nodes (27): AppIntent, AppIntents, CustomLocalizedStringResourceConvertible, Error, IntentResult, LocalizedStringResource, ReturnsValue, CreateFolderIntent (+19 more)

### Community 8 - "Foundation"
Cohesion: 0.10
Nodes (17): AppKit, Foundation, PDFKit, S4_Viewer, FilePanelSupport, String, String, .lastS3PathComponent (+9 more)

### Community 9 - "NamePromptView"
Cohesion: 0.07
Nodes (25): App, Context, NSViewRepresentable, OSLog, QLPreviewView, QuickLookUI, Result, .body (+17 more)

### Community 10 - ".launch"
Cohesion: 0.17
Nodes (4): BrowsingUITests, ObjectManagementUITests, PreviewUITests, Bool

### Community 11 - "ContentView"
Cohesion: 0.25
Nodes (6): Identifiable, ContentView, .body, .selectedProfile, ProfileEditorSession, UUID

### Community 12 - "S3RequestSigner"
Cohesion: 0.17
Nodes (10): CryptoKit, DateFormatter, ContiguousBytes, .hexDigest, S3RequestSigner, Data, String, S3RequestSignerTests (+2 more)

### Community 13 - "IntentAutomationTests"
Cohesion: 0.11
Nodes (5): AppIntentsTesting, IntentDefinitions, IntentAutomationTests, String, XCUIApplication

### Community 14 - "A11y"
Cohesion: 0.14
Nodes (12): A11y, Browser, Confirm, ErrorAlert, NamePrompt, Preview, ProfileEditor, Sidebar (+4 more)

### Community 15 - "Review Uncommitted Changes"
Cohesion: 0.07
Nodes (25): Custom Perspective File, Perspective Deduplication, Structured Finding, Generic Review Dimensions, Parallel Reviewers, Pull Request Diff, Report-Only Review, Automated Skill-Update Pull Request (+17 more)

### Community 16 - "ConnectionProfileUITests"
Cohesion: 0.11
Nodes (6): ConnectionProfileUITests, S4_ViewerUITestsLaunchTests, Fixture, TransferUITests, XCTest, XCTestCase

### Community 17 - "String"
Cohesion: 0.22
Nodes (5): String, StaticString, TimeInterval, UInt, XCUIElement

### Community 18 - "ConnectionProfile"
Cohesion: 0.18
Nodes (6): ConnectionProfile, Bool, String, UUID, .body, Date

### Community 19 - "Equatable"
Cohesion: 0.21
Nodes (12): Double, Equatable, Kind, download, upload, Status, failed, running (+4 more)

### Community 20 - "App Sandbox"
Cohesion: 0.25
Nodes (8): AllTests Plan, App Sandbox, DemoBucket, Hardened Runtime, IntentTests Plan, User-Selected Read-Write Entitlement, Real S3 Endpoint Verification, Signed Build

### Community 21 - "Test-Driven Development"
Cohesion: 0.29
Nodes (7): Non-Screen-Occupying Intent Automation, run-intent-tests.sh, Test-Driven Development, AGENTS.md Reference, Unit Tests, xcodebuild Test Command, UnitTests Plan

### Community 22 - "Contribution Workflow"
Cohesion: 0.29
Nodes (7): Contribution Workflow, Focused Pull Request, Issue or Discussion, Security Issue Reporting, Topic Branch, Private Vulnerability Reporting, Public Issue Disclosure

### Community 23 - "Sakoku Workflow"
Cohesion: 0.33
Nodes (6): Actions Checkout, Contents Read Permission, Pull Request Trigger, smartcrabai/sakoku Action, Sakoku Workflow, Workflow Dispatch

### Community 24 - "S4 Viewer"
Cohesion: 0.14
Nodes (13): Architecture, Build and run, Features, Intent automation (no cursor, no keyboard), Multipart Transfers, Native macOS S3 Browser, Requirements, Running the UI suite without losing the desktop (+5 more)

### Community 25 - "Review Perspective"
Cohesion: 0.40
Nodes (5): Companion Review Skills, Fix Pull Request, Original Pull Request, Review Perspective, Review-Time Detectability

### Community 26 - "Red document file icon"
Cohesion: 0.50
Nodes (4): Document file, Folded page corner, Red document file icon, Text line motif

### Community 27 - "AWS Signature V4"
Cohesion: 0.67
Nodes (3): AWS Signature V4, CryptoKit, URLSession

### Community 28 - "iCloud Keychain"
Cohesion: 0.67
Nodes (3): Connection Profiles, iCloud Keychain, iCloud Profile Sync

### Community 34 - "ConnectionProfileDraft"
Cohesion: 0.08
Nodes (28): Hashable, ConnectionProfileDraft, ConnectionProfileValidationError, .errorDescription, invalidEndpoint, missingAccessKey, missingBucket, missingName (+20 more)

### Community 35 - "Improve Review from Session"
Cohesion: 0.25
Nodes (7): Critical constraint: do this inline, never in a subagent, Improve Review from Session, Step 1 — Mine the session, Step 2 — Generalize, Step 3 — Dedupe against existing perspectives, Step 4 — Write perspective files, Step 5 — Report

### Community 39 - "BrowserPreviewContent"
Cohesion: 0.29
Nodes (7): Observation, BrowserPreviewContent, BrowserPreviewState, empty, failed, loading, ready

### Community 40 - "Improve Review from PR Gap"
Cohesion: 0.29
Nodes (6): Improve Review from PR Gap, Step 1 — Identify the PR pair, Step 2 — Gather evidence, Step 3 — Analyze the gap, Step 4 — Write perspective files, Step 5 — Report

### Community 41 - "Remaining"
Cohesion: 0.29
Nodes (6): 1. Verify the signed build against a real S3 endpoint, 2. Prepare App Review information, 3. Submit, Notes, Release Checklist - 1.0 (Mac App Store), Remaining

### Community 42 - "BrowserTableView"
Cohesion: 0.38
Nodes (5): Binding, BrowserTableView, .body, .selectionBinding, Set

### Community 43 - "Contributing"
Cohesion: 0.40
Nodes (4): Contributing, How to Contribute, Pull Request Guidelines, Security Issues

### Community 46 - "ObjectPreviewKind"
Cohesion: 0.27
Nodes (6): ObjectPreviewKind, inlineText, quickLook, unsupported, Bool, String

## Knowledge Gaps
- **207 isolated node(s):** `Preview`, `ProfileEditor`, `NamePrompt`, `Confirm`, `ErrorAlert` (+202 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `S3BrowserModel` connect `S3BrowserModel` to `S3Credentials`, `S3HTTPClient`, `ContentView.swift`, `DemoBucket`, `S3BrowserItem`, `BrowserPreviewContent`, `String`, `BrowserTableView`, `ContentView`, `ConnectionProfile`, `Equatable`?**
  _High betweenness centrality (0.106) - this node is a cross-community bridge._
- **Why does `S3BrowserItem` connect `S3BrowserItem` to `S3BrowserModel`, `S3Credentials`, `ConnectionProfileDraft`, `ContentView.swift`, `DemoBucket`, `S3HTTPClient`, `BrowserPreviewContent`, `BrowserTableView`, `ContentView`, `ConnectionProfile`?**
  _High betweenness centrality (0.060) - this node is a cross-community bridge._
- **Why does `URL` connect `S3HTTPClient` to `S3BrowserModel`, `S3Credentials`, `ConnectionProfileDraft`, `DemoBucket`, `BrowserPreviewContent`, `Foundation`, `NamePromptView`, `S3RequestSigner`, `Equatable`?**
  _High betweenness centrality (0.054) - this node is a cross-community bridge._
- **Are the 24 inferred relationships involving `Screen` (e.g. with `.testDoubleClickEntersFolderAndUpReturns()` and `.testEmptyFolderShowsEmptyState()`) actually correct?**
  _`Screen` has 24 INFERRED edges - model-reasoned connections that need verification._
- **Are the 9 inferred relationships involving `S3BrowserModel` (e.g. with `.activatePrimaryAction()` and `.automationContextDetachesTheLiveBrowserWhenItsViewDisappears()`) actually correct?**
  _`S3BrowserModel` has 9 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `ConnectionProfile` (e.g. with `.selectedProfile` and `.draftFromProfileTakesCredentialsFromArgument()`) actually correct?**
  _`ConnectionProfile` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `S3BrowserItem` (e.g. with `.openFolder()` and `.selectedItem`) actually correct?**
  _`S3BrowserItem` has 4 INFERRED edges - model-reasoned connections that need verification._