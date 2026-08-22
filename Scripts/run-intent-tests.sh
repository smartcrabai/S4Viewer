#!/bin/sh
#
# Runs the screen-free end-to-end suite: `IntentTests` drives the app through App Intents,
# so it never takes the cursor or keyboard the way XCUITest does.
#
# The intent build also defines S4VIEWER_INTENT_TESTING below. App Intents testing can invoke
# the app service without forwarding UI-test launch arguments, so that compile-time switch
# keeps the app on the fixture path end to end.
#
# Two requirements the plain `xcodebuild test` invocation does not express:
#
#   * Xcode 27 or later, because `AppIntentsTesting` ships inside `Xcode.app`. Override
#     DEVELOPER_DIR if the beta lives elsewhere.
#   * A real signing identity. App Intents rejects requests aimed at an ad-hoc signed app
#     with `AppIntentsServicesSecurityErrorDomain` code 800; the test runner and the app have
#     to carry the same team. Dropping CODE_SIGN_ENTITLEMENTS avoids needing a provisioning
#     profile for the iCloud and push entitlements. Override S4VIEWER_SIGN_IDENTITY to pick
#     a different certificate (`security find-identity -v -p codesigning` lists them).
#
set -eu

: "${DEVELOPER_DIR:=/Applications/Xcode-beta.app/Contents/Developer}"
: "${S4VIEWER_SIGN_IDENTITY:=Apple Development}"
export DEVELOPER_DIR

cd "$(dirname "$0")/.."

exec xcodebuild test \
    -project "S4 Viewer.xcodeproj" \
    -scheme "S4 Viewer" \
    -testPlan IntentTests \
    -destination 'platform=macOS,arch=arm64' \
    -configuration Debug \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$S4VIEWER_SIGN_IDENTITY" \
    PROVISIONING_PROFILE_SPECIFIER= \
    CODE_SIGN_ENTITLEMENTS= \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG S4VIEWER_INTENT_TESTING' \
    "$@"
