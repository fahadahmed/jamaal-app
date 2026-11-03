#!/bin/sh
# Captures the raw iPhone Duo pictures for one pose (#362). Poses are set in Xcode's Device Hub only, so switch the simulator to the pose
# first, then run this:
#
#   assets/appstore/capture-duo.sh <outer|inner-landscape|inner-portrait|tabletop|half-open> [path to Jamaal.app built for the iOS Simulator]
#
# `outer` is the closed Duo's outer display; the others are the inner display. The pictures go to assets/appstore/raw/duo/<pose>/.
set -eu
POSE="${1:?outer, inner-landscape, inner-portrait, tabletop or half-open}"
HERE="$(cd "$(dirname "$0")" && pwd)"
UDID="${DUO_UDID:-4ABE2C59-8B3C-46A8-BB48-EAEF53EF2368}"
APP="${2:-/tmp/jamaal-shots/Build/Products/Debug-iphonesimulator/Jamaal.app}"
OUT="$HERE/raw/duo/$POSE"
mkdir -p "$OUT"

# The two displays of the Duo: the outer is the one 1398 wide, the inner 2007 wide (as pixels; they are class 0 in the enumeration).
DISPLAYS="$(xcrun simctl io "$UDID" enumerate | python3 -c "
import re, sys
for block in sys.stdin.read().split('UUID:')[1:]:
    if 'framebuffer' in block and re.search(r'Display class: 0', block):
        print(block.split()[0], re.search(r'Default width: (\d+)', block).group(1))")"
OUTER="$(echo "$DISPLAYS" | awk '$2==1398{print $1}')"
INNER="$(echo "$DISPLAYS" | awk '$2==2007{print $1}')"
case "$POSE" in outer) DISPLAY_ID="$OUTER" ;; *) DISPLAY_ID="$INNER" ;; esac

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance light
xcrun simctl install "$UDID" "$APP"

# A first launch after an install is slow and its picture comes out blank: launch once and let it settle.
xcrun simctl launch "$UDID" dev.fhdamd.Jamaal -JamaalInMemory -JamaalStoreShots >/dev/null; sleep 12

COMMON="-JamaalInMemory -JamaalStoreShots -JamaalDayStartMinute 0 -JamaalWeekdayLevel medium"
shot() {   # name, then the extra launch arguments
  NAME="$1"; shift
  xcrun simctl terminate "$UDID" dev.fhdamd.Jamaal 2>/dev/null || true
  # shellcheck disable=SC2086
  xcrun simctl launch "$UDID" dev.fhdamd.Jamaal $COMMON "$@" >/dev/null
  sleep 10
  timeout 60 xcrun simctl io "$UDID" screenshot --display "$DISPLAY_ID" "$OUT/$NAME.png" >/dev/null 2>&1 || echo "no picture for $NAME"
  echo "captured $POSE/$NAME"
}

case "$POSE" in
  outer)
    shot 1-today -JamaalWellbeing steady
    shot 2-habits -JamaalTab habits
    shot 3-anchors -JamaalTab habits -JamaalAnchorRules
    shot 4-focus -JamaalBegin -JamaalOpenFocus
    shot 5-wellbeing -JamaalTab wellbeing -JamaalWellbeing steady ;;
  inner-landscape)
    shot 1-today-open -JamaalWellbeing steady -JamaalOpenTask
    shot 2-night-build -JamaalEvening -JamaalPlan 3
    shot 3-habits-open -JamaalTab habits -JamaalOpenHabit
    shot 4-anchors-open -JamaalTab habits -JamaalAnchorRules -JamaalOpenRule
    shot 5-wellbeing -JamaalTab wellbeing -JamaalWellbeing steady ;;
  inner-portrait)
    shot 1-today -JamaalWellbeing steady
    shot 2-night-build -JamaalEvening -JamaalPlan 3
    shot 3-habits -JamaalTab habits ;;
  tabletop)
    shot 1-focus -JamaalBegin -JamaalOpenFocus ;;
  half-open)
    shot 1-today-open -JamaalWellbeing steady -JamaalOpenTask
    shot 2-habits-open -JamaalTab habits -JamaalOpenHabit ;;
  *) echo "unknown pose"; exit 1 ;;
esac
xcrun simctl terminate "$UDID" dev.fhdamd.Jamaal 2>/dev/null || true
