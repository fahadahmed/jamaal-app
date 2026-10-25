#!/bin/zsh
# Story 1: "The beta is open" (1080x1920). Run from the repo root.
# FONT_DIR defaults to the ThreadsKit fonts inside a built Jamaal.app.
set -euo pipefail
FONT_DIR=${FONT_DIR:-/Applications/Jamaal.app/Contents/Resources/ThreadsKit_ThreadsTokens.bundle/Contents/Resources}
OUT=$(dirname $0)
ICON=Jamaal/Jamaal/Assets.xcassets/AppIcon.appiconset/AppIcon-default.png
SHOT=docs/images/app-iphone-today.png
TMP=$(mktemp -d)

# App icon (same blue as the background, so rounded with a thin mint outline)
magick $ICON -resize 168x168 \
  \( +clone -alpha extract -fill black -colorize 100 -fill white -draw "roundrectangle 0,0 167,167 38,38" \) \
  -alpha off -compose CopyOpacity -composite \
  \( -size 168x168 xc:none -fill none -stroke '#8FCBB8' -strokewidth 3 -draw "roundrectangle 2,2 165,165 37,37" \) -compose Over -composite $TMP/icon.png

# Top of the Today screen as a rounded card (skips the status bar); ends above the bottom safe zone
magick $SHOT -crop 560x345+0+88 +repage -filter Lanczos -resize 904x \
  \( +clone -alpha extract -fill black -colorize 100 -fill white -draw "roundrectangle 0,0 903,556 56,56" \) \
  -alpha off -compose CopyOpacity -composite $TMP/card.png

magick -size 1080x1920 xc:'#0C4767' \
  $TMP/icon.png -geometry +88+270 -composite \
  -font $FONT_DIR/JetBrainsMono-Medium.ttf -pointsize 34 -kerning 5 -fill '#8FCBB8' -annotate +88+560 'BETA · NOW OPEN' \
  -kerning 0 -font $FONT_DIR/FrauncesDisplay-Regular.ttf -pointsize 150 -fill '#EFF4F0' -annotate +80+740 'The beta is' \
  -font $FONT_DIR/FrauncesDisplay-Italic.ttf -fill '#8FCBB8' -annotate +80+900 'open.' \
  -font $FONT_DIR/HankenGrotesk-Regular.ttf -pointsize 46 -fill '#EFF4F0' -annotate +88+1010 'Free while we test it. Try it for a week' \
  -annotate +88+1072 'and tell me what feels right.' \
  $TMP/card.png -geometry +88+1110 -composite \
  $OUT/01-beta-open.png
rm -r $TMP
