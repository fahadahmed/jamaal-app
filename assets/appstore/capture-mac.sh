#!/bin/sh
# Captures the raw Mac pictures (#362): a Mac UI test launches the app at a fixed size with the store dataset, in Light, and attaches a
# picture of its window (and of the Settings window), which this exports to assets/appstore/raw/mac/. It drives the real desktop:
# keep your hands off the mouse and keyboard while it runs.
#
#   assets/appstore/capture-mac.sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RESULT="${TMPDIR:-/tmp}/jamaal-mac-store-shots.xcresult"
rm -rf "$RESULT" "$HERE/raw/mac"; mkdir -p "$HERE/raw/mac"
TEST_RUNNER_JAMAAL_STORE_SHOTS=1 xcodebuild test -project "$ROOT/Jamaal/Jamaal.xcodeproj" -scheme JamaalMac -destination 'platform=macOS' \
  -resultBundlePath "$RESULT" -only-testing:JamaalMacUITests/MacStoreShotsUITests > /dev/null || true   # a failed shot should not lose the others
EXPORT="$(mktemp -d)"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$EXPORT" > /dev/null
python3 - "$EXPORT" "$HERE/raw/mac" <<'PY'
import json, os, shutil, sys
export, out = sys.argv[1:3]
for test in json.load(open(os.path.join(export, "manifest.json"))):
    for a in test.get("attachments", []):
        name = a["suggestedHumanReadableName"]
        if a["exportedFileName"].endswith(".png") and "_0_" in name:
            shutil.copy(os.path.join(export, a["exportedFileName"]), os.path.join(out, name.split("_0_")[0] + ".png"))
            print("captured", name.split("_0_")[0])
PY
