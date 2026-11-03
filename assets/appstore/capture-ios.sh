#!/bin/sh
# Captures the raw App Store screenshots of the real app, with the store dataset, in Light appearance (#362). The status bar is
# painted out by build.py, so none is set here.
#
#   assets/appstore/capture-ios.sh <iphone|ipad> [path to Jamaal.app built for the iOS Simulator]
#
# The raw captures go to assets/appstore/raw/<device>/ (not committed: build.py makes the final images from them).
set -eu
DEVICE="${1:?iphone or ipad}"
HERE="$(cd "$(dirname "$0")" && pwd)"
case "$DEVICE" in
  iphone) UDID="${IPHONE_UDID:-59602FFB-69B4-418F-838F-081126245D1A}" ;;   # iPhone 18 Pro Max (6.9")
  ipad)   UDID="${IPAD_UDID:-3C1C0B76-8FD7-4E08-B2A7-E1EF97BDBCC8}" ;;     # iPad Pro 13-inch (M5)
  *) echo "iphone or ipad"; exit 1 ;;
esac
APP="${2:-/tmp/jamaal-sim5/Build/Products/Debug-iphonesimulator/Jamaal.app}"
OUT="$HERE/raw/$DEVICE"
mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl install "$UDID" "$APP"

COMMON="-JamaalInMemory -JamaalStoreShots -JamaalDayStartMinute 0 -JamaalWeekdayLevel medium"
shot() {   # name, then the extra launch arguments
  NAME="$1"; shift
  xcrun simctl terminate "$UDID" dev.fhdamd.Jamaal 2>/dev/null || true
  # shellcheck disable=SC2086
  xcrun simctl launch "$UDID" dev.fhdamd.Jamaal $COMMON "$@" >/dev/null
  sleep 9
  xcrun simctl io "$UDID" screenshot "$OUT/$NAME.png" >/dev/null 2>&1
  echo "captured $NAME"
}

shot 1-today -JamaalWellbeing steady
shot 1b-today-open -JamaalWellbeing steady -JamaalOpenTask
shot 2-night-review -JamaalEvening -JamaalPlan 1
shot 2-night-build -JamaalEvening -JamaalPlan 3
shot 2-night-load -JamaalEvening -JamaalPlan 4
shot 3-habits -JamaalTab habits
shot 4-anchors -JamaalTab habits -JamaalAnchorRules
shot 5-wellbeing -JamaalTab wellbeing -JamaalWellbeing steady
shot 6-focus -JamaalBegin -JamaalOpenFocus
if [ "$DEVICE" = ipad ]; then   # a list beside its detail: start with an item open, so the pane is not empty
  shot 3-habits-open -JamaalTab habits -JamaalOpenHabit
  shot 4-anchors-open -JamaalTab anchors -JamaalOpenRule -JamaalAnchorRules
fi
xcrun simctl terminate "$UDID" dev.fhdamd.Jamaal 2>/dev/null || true
