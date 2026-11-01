#!/bin/sh
#
# Xcode Cloud runs this after it clones the repository, before it builds (#346).
#
# A build made from a `v<version>` tag (the App Store release) is marked in its Info.plist as an App Store build. The app can't tell it
# from a TestFlight beta by itself: App Review runs apps in the sandbox, as TestFlight does, and the app treats the sandbox as a beta
# (full access, no paywall). Builds from `beta-*` tags, and local builds, are not marked and keep the runtime rules.
set -eu

PLIST="${CI_PRIMARY_REPOSITORY_PATH:-.}/Jamaal/Jamaal/Info.plist"

case "${CI_TAG:-}" in
  v[0-9]*)
    /usr/libexec/PlistBuddy -c "Delete :JamaalDistribution" "$PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :JamaalDistribution string appStore" "$PLIST"
    echo "Tag ${CI_TAG}: marked this build as an App Store build."
    ;;
  *)
    echo "Tag '${CI_TAG:-}' is not a v<version> tag: leaving the build unmarked."
    ;;
esac
