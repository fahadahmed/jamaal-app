#!/bin/sh
# Captures the raw iPad pictures in landscape (#362): a UI test rotates the simulator and attaches a picture of each screen, which this
# exports to assets/appstore/raw/ipad/ (not committed: build.py makes the final images from them).
#
#   assets/appstore/capture-ipad.sh
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
UDID="${IPAD_UDID:-3C1C0B76-8FD7-4E08-B2A7-E1EF97BDBCC8}"      # iPad Pro 13-inch (M5)
RESULT="${TMPDIR:-/tmp}/jamaal-store-shots.xcresult"
rm -rf "$RESULT" "$HERE/raw/ipad"; mkdir -p "$HERE/raw/ipad"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
TEST_RUNNER_JAMAAL_STORE_SHOTS=1 xcodebuild test -project "$ROOT/Jamaal/Jamaal.xcodeproj" -scheme Jamaal \
  -destination "id=$UDID" -parallel-testing-enabled NO -resultBundlePath "$RESULT" \
  -only-testing:JamaalUITests/StoreShotsUITests > /dev/null

EXPORT="$(mktemp -d)"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$EXPORT" > /dev/null
python3 - "$EXPORT" "$HERE/raw/ipad" <<'PY'
import json, os, shutil, subprocess, sys
export, out = sys.argv[1:3]
for test in json.load(open(os.path.join(export, "manifest.json"))):
    for a in test.get("attachments", []):
        name = a["suggestedHumanReadableName"]
        if a["exportedFileName"].endswith(".png") and "_0_" in name:
            target = os.path.join(out, name.split("_0_")[0] + ".png")
            shutil.copy(os.path.join(export, a["exportedFileName"]), target)
            # The test's picture is the screen's own portrait frame with the landscape content turned a quarter clockwise: turn it back.
            subprocess.run(["sips", "-r", "270", target], check=True, capture_output=True)
            print("captured", name.split("_0_")[0])
PY
