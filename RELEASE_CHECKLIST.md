# Release Checklist - 1.0 (Mac App Store)

Tracks what is left before the first submission. Everything not listed under
"Remaining" is already done: App ID capabilities (App Sandbox, iCloud/CloudKit,
Push Notifications), the `iCloud.ai.smartcrab.s4viewer` container, the Icon
Composer app icon, the CloudKit schema deployed to Production, the uploaded
build, screenshots, App Store metadata, the privacy policy URL, app privacy
answers, age rating, pricing, availability (France excluded, matching the
"standard encryption" export answer), and the encryption declaration.

## Remaining

### 1. Verify the signed build against a real S3 endpoint

None of this has been exercised with real credentials yet. Run it on the
signed build, not a `CODE_SIGNING_ALLOWED=NO` one, because the Keychain
refuses to store items without the app's entitlements.

The `AllTests` test plan already covers these flows against `DemoBucket`, so the
point of repeating them here is the real endpoint, real Keychain, and real
iCloud - not the UI wiring:

- [ ] Create a connection profile and confirm it appears in the sidebar
- [ ] List objects, enter a folder, navigate back up
- [ ] Sort by name / size / modification date / kind, and filter
- [ ] Preview a text-like object inline
- [ ] Preview a binary object through Quick Look
- [ ] Download an object; confirm the transfer row appears and clears
- [ ] Upload a file smaller than 8 MiB
- [ ] Create a folder, rename an object, rename a folder, delete both
- [ ] Edit the profile; confirm the access key and secret key are pre-filled

Not covered by any automated test, because no fixture can stand in for them:

- [ ] Upload a file larger than 8 MiB (exercises the multipart path)
- [ ] Upload several files at once (three run in parallel) at real throughput
- [ ] Quit and relaunch; confirm the profile still connects, which proves the
      credentials were read back from the Keychain
- [ ] Delete the profile; confirm its Keychain item is gone (Keychain Access,
      service `ai.smartcrab.s4viewer.s3-credentials`)
- [ ] Enter a wrong secret key and confirm the error is shown, not swallowed
- [ ] Sign in on a second Mac and confirm the profile syncs through iCloud, and
      that credentials arrive only when iCloud Keychain is enabled

### 2. Prepare App Review information

- [ ] Contact first name, last name, phone number, and email
- [ ] Create a throwaway review bucket: no real data, least-privilege
      credentials limited to List/Get/Put/Delete plus multipart
- [ ] Seed the review bucket with a few objects, including one text file and
      one folder, so the reviewer sees a populated window
- [ ] Fill in the notes with the endpoint, region, bucket, access key, secret
      key, and whether path-style requests must be enabled
- [ ] Explain in the notes that the app has no account of its own: the reviewer
      pastes the supplied S3 credentials into a new connection profile
- [ ] Schedule revoking those credentials once the review is complete

### 3. Submit

- [ ] Confirm the selected build is the one carrying the current source
- [ ] Optional: distribute the build to internal TestFlight testers first
- [ ] Add for Review, then Submit for Review
- [ ] After approval, decide between automatic and manual release

## Notes

- Screenshots can be regenerated without touching a real bucket by launching a
  Debug build with `-S4ViewerDemoData`, which seeds an in-memory profile and the
  `DemoBucket` fixtures. The flag is compiled out of Release builds, and
  `S4_ViewerUITestsLaunchTests` attaches the same screenshot on every run of the
  `AllTests` plan.
- Uploaded screenshots are 2880 x 1800, sRGB, with no alpha channel.
