#!/bin/zsh
# Carousel 6: "The beta is open" (4 slides, 1080x1350). Run from the repo root.
set -euo pipefail
FONT_DIR=${FONT_DIR:-/Applications/Jamaal.app/Contents/Resources/ThreadsKit_ThreadsTokens.bundle/Contents/Resources}
OUT=$(dirname $0)
ICON=Jamaal/Jamaal/Assets.xcassets/AppIcon.appiconset/AppIcon-default.png
TMP=$(mktemp -d)
R=$FONT_DIR/FrauncesDisplay-Regular.ttf; I=$FONT_DIR/FrauncesDisplay-Italic.ttf
H=$FONT_DIR/HankenGrotesk-Regular.ttf; M=$FONT_DIR/JetBrainsMono-Medium.ttf
BLUE='#0C4767'; PAPER='#EFF4F0'; MINT='#8FCBB8'

magick $ICON -resize 200x200 \
  \( +clone -alpha extract -fill black -colorize 100 -fill white -draw "roundrectangle 0,0 199,199 46,46" \) \
  -alpha off -compose CopyOpacity -composite \
  \( -size 200x200 xc:none -fill none -stroke $MINT -strokewidth 3 -draw "roundrectangle 2,2 197,197 45,45" \) -compose Over -composite $TMP/icon.png

# phone: a screenshot scaled to 800 wide with rounded top corners, bleeding off the bottom
phone() { magick $1 -filter Lanczos -resize 800x \
  \( +clone -alpha extract -fill black -colorize 100 -fill white -draw "roundrectangle 0,0 799,1735 60,60" \) \
  -alpha off -compose CopyOpacity -composite $2; }
phone docs/images/app-iphone-today.png $TMP/today.png
phone docs/images/app-iphone-plan-load.png $TMP/plan.png

# 1 cover
magick -size 1080x1350 xc:$BLUE $TMP/icon.png -geometry +88+150 -composite \
  -font $M -pointsize 32 -kerning 5 -fill $MINT -annotate +88+470 'TESTFLIGHT · BETA' \
  -kerning 0 -font $R -pointsize 160 -fill $PAPER -annotate +80+650 'The beta is' \
  -font $I -fill $MINT -annotate +80+810 'open.' \
  -font $H -pointsize 44 -fill $PAPER -annotate +88+940 'One list. Just today.' -annotate +88+1000 'Beautifully ordered.' \
  -font $M -pointsize 30 -kerning 4 -fill $MINT -annotate +88+1230 'SWIPE  →' \
  $OUT/01-cover.png

# 2 today
magick -size 1080x1350 xc:$BLUE \
  -font $M -pointsize 30 -kerning 5 -fill $MINT -annotate +88+120 '01 · TODAY' \
  -kerning 0 -font $R -pointsize 82 -fill $PAPER -annotate +80+235 'One list for the' \
  -font $I -fill $MINT -annotate +80+330 'whole day.' \
  $TMP/today.png -geometry +140+440 -composite $OUT/02-today.png

# 3 night planning
magick -size 1080x1350 xc:$BLUE \
  -font $M -pointsize 30 -kerning 5 -fill $MINT -annotate +88+120 '02 · NIGHT PLANNING' \
  -kerning 0 -font $R -pointsize 82 -fill $PAPER -annotate +80+235 'Plan tomorrow' \
  -font $I -fill $MINT -annotate +80+330 'tonight.' \
  $TMP/plan.png -geometry +140+440 -composite $OUT/03-night-planning.png

# 4 join
magick -size 1080x1350 xc:$BLUE $TMP/icon.png -geometry +88+150 -composite \
  -font $R -pointsize 120 -kerning 0 -fill $PAPER -annotate +80+560 'Join the' \
  -font $I -fill $MINT -annotate +80+700 'beta.' \
  -font $H -pointsize 44 -fill $PAPER -annotate +88+820 'On iPhone, iPad and Mac.' -annotate +88+882 'Free while in beta.' \
  -font $H -pointsize 44 -kerning 0 -fill $MINT -annotate +88+1100 'Join the beta · link in bio' \
  $OUT/04-join.png
rm -r $TMP
