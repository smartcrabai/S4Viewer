# Graph Report - S4Viewer  (2026-08-22)

## Corpus Check
- 54 files · ~86,143 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 734 nodes · 1617 edges · 40 communities (28 shown, 12 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 202 edges (avg confidence: 0.81)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Connection Profile Models
- Swift Foundation Types
- S3 HTTP Networking
- SwiftUI Browser Interface
- Object Operations Transfers
- Profile Field Definitions
- UI Test Screen Helpers
- App Intent Actions
- Framework Preview Support
- App Shell Preview
- Browsing UI Tests
- Credential Persistence
- AWS Signature V4
- Intent Automation Tests
- Accessibility UI Components
- Review Skill Concepts
- UI Test Suites
- Test Interaction Helpers
- Object Preview Resolution
- Connection Profile Tests
- Build Entitlement Plans
- Intent Test Pipeline
- Contribution Security Workflow
- CI Workflow Actions
- S4 Viewer Architecture
- Review Gap Analysis
- Document Icon Asset
- Request Signing Dependencies
- iCloud Profile Sync
- Runtime Review Gaps
- Review Lesson Mining
- Working Tree Review
- Review Credential Security
- Intent Test Script Variants
- PR Gap Skill
- Session Review Skill
- XCUITest UI Suite
- AppIntents Testing
- Release Checklist
- Security Policy

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
10. `ConnectionProfileDraft` - 17 edges

## Surprising Connections (you probably didn't know these)
- `.selectedProfile` --references--> `ConnectionProfile`  [INFERRED]
  S4 Viewer/ContentView.swift → S4 Viewer/ConnectionProfile.swift
- `StoredObject` --references--> `Date`  [EXTRACTED]
  S4 Viewer/DemoMode.swift → S4 ViewerTests/S3RequestSignerTests.swift
- `S3BrowserItem` --references--> `Date`  [EXTRACTED]
  S4 Viewer/S3BrowserItem.swift → S4 ViewerTests/S3RequestSignerTests.swift
- `Automated Skill-Update Pull Request` --conceptually_related_to--> `Pull Request Diff`  [INFERRED]
  .github/workflows/update-skills.yml → .claude/skills/review-pr/SKILL.md
- `Test-Driven Development` --conceptually_related_to--> `Unit Tests`  [INFERRED]
  AGENTS.md → CONTRIBUTING.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Review Perspective Lifecycle** — _claude_skills_improve_review_from_pr_gap_skill_original_pr, _claude_skills_improve_review_from_pr_gap_skill_fix_pr, _claude_skills_improve_review_from_pr_gap_skill_review_perspective, _claude_skills_review_pr_skill_generic_review_dimensions [INFERRED 0.85]
- **S4 Viewer Validation Layers** — agents_tdd, agents_intent_automation, readme_unit_tests_plan, readme_intent_tests_plan, readme_all_tests_plan, release_checklist_real_s3_endpoint_verification [INFERRED 0.85]
- **Secure Release and Reporting** — readme_app_sandbox, readme_hardened_runtime, release_checklist_least_privilege_credentials, security_private_vulnerability_reporting [INFERRED 0.75]
- **Document icon visual composition** — s4_viewer_s4viewer_icon_assets_gemini_generated_image_blrg2ublrg2ublrg_document_file, s4_viewer_s4viewer_icon_assets_gemini_generated_image_blrg2ublrg2ublrg_folded_page_corner, s4_viewer_s4viewer_icon_assets_gemini_generated_image_blrg2ublrg2ublrg_text_line_motif [EXTRACTED 1.00]

## Communities (40 total, 12 thin omitted)

### Community 0 - "Connection Profile Models"
Cohesion: 0.07
Nodes (38): Double, Observation, ConnectionProfile, Bool, String, UUID, DemoAutomationContext, navigate() (+30 more)

### Community 1 - "Swift Foundation Types"
Cohesion: 0.06
Nodes (44): Codable, CustomDebugStringConvertible, CustomStringConvertible, Equatable, ConnectionProfileDraft, ConnectionProfileValidationError, .errorDescription, invalidEndpoint (+36 more)

### Community 2 - "S3 HTTP Networking"
Cohesion: 0.08
Nodes (28): HTTPURLResponse, HTTPMethod, delete, get, post, put, S3ClientError, .errorDescription (+20 more)

### Community 3 - "SwiftUI Browser Interface"
Cohesion: 0.07
Nodes (40): Binding, ByteCountFormatter, Identifiable, BrowserActionBar, .body, .selectedItem, BrowserColumnView, .body (+32 more)

### Community 4 - "Object Operations Transfers"
Cohesion: 0.08
Nodes (22): LocalizedError, DemoBucket, DemoMode, .isEnabled, DemoS3Client, DemoS3Error, alreadyExists, .errorDescription (+14 more)

### Community 5 - "Profile Field Definitions"
Cohesion: 0.06
Nodes (32): CaseIterable, Hashable, Field, accessKey, bucket, endpoint, name, region (+24 more)

### Community 6 - "UI Test Screen Helpers"
Cohesion: 0.05
Nodes (41): Screen, .addProfileButton, .confirmDeleteItemButton, .confirmDeleteProfileButton, .deleteButton, .deleteProfileButton, .downloadButton, .editProfileButton (+33 more)

### Community 7 - "App Intent Actions"
Cohesion: 0.17
Nodes (26): AppIntent, AppIntents, CustomLocalizedStringResourceConvertible, Error, IntentResult, LocalizedStringResource, ReturnsValue, CreateFolderIntent (+18 more)

### Community 8 - "Framework Preview Support"
Cohesion: 0.09
Nodes (19): AppKit, Foundation, PDFKit, S4_Viewer, FilePanelSupport, S3ListObjectsPage, S3ListObjectsResponseParser, Bool (+11 more)

### Community 9 - "App Shell Preview"
Cohesion: 0.08
Nodes (21): App, Context, NSViewRepresentable, OSLog, QLPreviewView, QuickLookUI, Result, .body (+13 more)

### Community 10 - "Browsing UI Tests"
Cohesion: 0.17
Nodes (4): BrowsingUITests, ObjectManagementUITests, PreviewUITests, Bool

### Community 11 - "Credential Persistence"
Cohesion: 0.17
Nodes (14): Any, OSStatus, ConnectionCredentialStore, ConnectionCredentialStoreError, .errorDescription, invalidCredentials, keychain, missingCredentials (+6 more)

### Community 12 - "AWS Signature V4"
Cohesion: 0.17
Nodes (10): CryptoKit, DateFormatter, ContiguousBytes, .hexDigest, S3RequestSigner, Data, String, S3RequestSignerTests (+2 more)

### Community 13 - "Intent Automation Tests"
Cohesion: 0.12
Nodes (5): AppIntentsTesting, IntentDefinitions, IntentAutomationTests, String, XCUIApplication

### Community 14 - "Accessibility UI Components"
Cohesion: 0.14
Nodes (12): A11y, Browser, Confirm, ErrorAlert, NamePrompt, Preview, ProfileEditor, Sidebar (+4 more)

### Community 15 - "Review Skill Concepts"
Cohesion: 0.13
Nodes (15): Custom Perspective File, Perspective Deduplication, Structured Finding, Generic Review Dimensions, Parallel Reviewers, Pull Request Diff, Report-Only Review, Review PR (+7 more)

### Community 16 - "UI Test Suites"
Cohesion: 0.14
Nodes (5): S4_ViewerUITestsLaunchTests, Fixture, TransferUITests, XCTest, XCTestCase

### Community 17 - "Test Interaction Helpers"
Cohesion: 0.24
Nodes (5): String, StaticString, TimeInterval, UInt, XCUIElement

### Community 18 - "Object Preview Resolution"
Cohesion: 0.27
Nodes (6): ObjectPreviewKind, inlineText, quickLook, unsupported, Bool, String

### Community 20 - "Build Entitlement Plans"
Cohesion: 0.25
Nodes (8): AllTests Plan, App Sandbox, DemoBucket, Hardened Runtime, IntentTests Plan, User-Selected Read-Write Entitlement, Real S3 Endpoint Verification, Signed Build

### Community 21 - "Intent Test Pipeline"
Cohesion: 0.29
Nodes (7): Non-Screen-Occupying Intent Automation, run-intent-tests.sh, Test-Driven Development, AGENTS.md Reference, Unit Tests, xcodebuild Test Command, UnitTests Plan

### Community 22 - "Contribution Security Workflow"
Cohesion: 0.29
Nodes (7): Contribution Workflow, Focused Pull Request, Issue or Discussion, Security Issue Reporting, Topic Branch, Private Vulnerability Reporting, Public Issue Disclosure

### Community 23 - "CI Workflow Actions"
Cohesion: 0.33
Nodes (6): Actions Checkout, Contents Read Permission, Pull Request Trigger, smartcrabai/sakoku Action, Sakoku Workflow, Workflow Dispatch

### Community 24 - "S4 Viewer Architecture"
Cohesion: 0.33
Nodes (6): Multipart Transfers, Native macOS S3 Browser, S4 Viewer, SwiftData, SwiftUI, Multipart Upload Above 8 MiB

### Community 25 - "Review Gap Analysis"
Cohesion: 0.40
Nodes (5): Companion Review Skills, Fix Pull Request, Original Pull Request, Review Perspective, Review-Time Detectability

### Community 26 - "Document Icon Asset"
Cohesion: 0.50
Nodes (4): Document file, Folded page corner, Red document file icon, Text line motif

### Community 27 - "Request Signing Dependencies"
Cohesion: 0.67
Nodes (3): AWS Signature V4, CryptoKit, URLSession

### Community 28 - "iCloud Profile Sync"
Cohesion: 0.67
Nodes (3): Connection Profiles, iCloud Keychain, iCloud Profile Sync

## Knowledge Gaps
- **173 isolated node(s):** `Preview`, `ProfileEditor`, `NamePrompt`, `Confirm`, `ErrorAlert` (+168 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `S3BrowserModel` connect `Connection Profile Models` to `Swift Foundation Types`, `SwiftUI Browser Interface`, `Object Operations Transfers`, `Profile Field Definitions`, `App Intent Actions`?**
  _High betweenness centrality (0.121) - this node is a cross-community bridge._
- **Why does `S3BrowserItem` connect `Profile Field Definitions` to `Connection Profile Models`, `Swift Foundation Types`, `S3 HTTP Networking`, `SwiftUI Browser Interface`, `Object Operations Transfers`, `Framework Preview Support`?**
  _High betweenness centrality (0.069) - this node is a cross-community bridge._
- **Why does `URL` connect `Object Operations Transfers` to `Connection Profile Models`, `Swift Foundation Types`, `S3 HTTP Networking`, `App Shell Preview`, `AWS Signature V4`?**
  _High betweenness centrality (0.062) - this node is a cross-community bridge._
- **Are the 24 inferred relationships involving `Screen` (e.g. with `.testDoubleClickEntersFolderAndUpReturns()` and `.testEmptyFolderShowsEmptyState()`) actually correct?**
  _`Screen` has 24 INFERRED edges - model-reasoned connections that need verification._
- **Are the 9 inferred relationships involving `S3BrowserModel` (e.g. with `.activatePrimaryAction()` and `.automationContextDetachesTheLiveBrowserWhenItsViewDisappears()`) actually correct?**
  _`S3BrowserModel` has 9 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `ConnectionProfile` (e.g. with `.selectedProfile` and `.draftFromProfileTakesCredentialsFromArgument()`) actually correct?**
  _`ConnectionProfile` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `S3BrowserItem` (e.g. with `.openFolder()` and `.selectedItem`) actually correct?**
  _`S3BrowserItem` has 4 INFERRED edges - model-reasoned connections that need verification._