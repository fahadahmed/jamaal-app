#!/bin/zsh
# Story 1: "The beta is open" (1080x1920). Run from the repo root.
# FONT_DIR defaults to the ThreadsKit fonts inside a built Jamaal.app.
set -euo pipefail
FONT_DIR=${FONT_DIR:-/Applications/Jamaal.app/Contents/Resources/ThreadsKit_ThreadsTokens.bundle/Contents/Resources}
OUT=$(dirname $0)
ICON=Jamaal/Jamaal/Assets.xcassets/AppIcon.appiconset/AppIcon-default.png
TMP=$(mktemp -d)

# App icon (same blue as the background, so rounded with a thin mint outline)
magick $ICON -resize 240x240 \
  \( +clone -alpha extract -fill black -colorize 100 -fill white -draw "roundrectangle 0,0 239,239 54,54" \) \
  -alpha off -compose CopyOpacity -composite \
  \( -size 240x240 xc:none -fill none -stroke '#8FCBB8' -strokewidth 3 -draw "roundrectangle 2,2 237,237 53,53" \) -compose Over -composite $TMP/icon.png

magick -size 1080x1920 xc:'#0C4767' \
  $TMP/icon.png -geometry +88+300 -composite \
  -font $FONT_DIR/JetBrainsMono-Medium.ttf -pointsize 34 -kerning 5 -fill '#8FCBB8' -annotate +88+650 'TESTFLIGHT · BETA' \
  -kerning 0 -font $FONT_DIR/FrauncesDisplay-Regular.ttf -pointsize 150 -fill '#EFF4F0' -annotate +80+830 'The beta is' \
  -font $FONT_DIR/FrauncesDisplay-Italic.ttf -fill '#8FCBB8' -annotate +80+990 'open.' \
  -font $FONT_DIR/HankenGrotesk-Regular.ttf -pointsize 46 -fill '#EFF4F0' \
  -annotate +88+1110 'Jamaal is on TestFlight for iPhone,' \
  -annotate +88+1172 'iPad and Mac, free while in beta.' \
  -pointsize 40 -fill '#8FCBB8' \
  -annotate +88+1262 'On the waitlist? Check your inbox' \
  -annotate +88+1318 'for your invite from Apple.' \
  -font $FONT_DIR/JetBrainsMono-Medium.ttf -pointsize 34 -kerning 5 -fill '#EFF4F0' -annotate +88+1440 'TAP THE LINK TO JOIN ↓' \
  $OUT/01-beta-open.png
rm -r $TMP
