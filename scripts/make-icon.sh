#!/bin/zsh
# Renders the app icons and the menu bar glyph from the logo SVG files into the asset catalog.
# Run: scripts/make-icon.sh (needs rsvg-convert from librsvg)
set -euo pipefail
cd "$(dirname $0)/.."
src=assets/logo
assets=App/Resources/Assets.xcassets
tmp=$(mktemp -d)

# The dev build has a mark on its icon, so that it is easy to tell apart from the release build:
# a "DEV" label on the full icon, and a dot on the simple icon, where a label is too small to read.
badge_full='<g><rect x="292" y="742" width="440" height="168" rx="84" fill="#FF3B30" stroke="#FFFFFF" stroke-width="18"/><text x="512" y="868" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial, sans-serif" font-weight="800" font-size="118" letter-spacing="10" fill="#FFFFFF">DEV</text></g>'
badge_small='<circle cx="806" cy="218" r="150" fill="#FF3B30" stroke="#FFFFFF" stroke-width="28"/>'
sed "s|</svg>\$|${badge_full}</svg>|" $src/icon.svg > $tmp/icon.svg
sed "s|</svg>\$|${badge_small}</svg>|" $src/icon-small.svg > $tmp/icon-small.svg

# The simple icon reads better at 64 px and below. The full icon is for all larger sizes.
render() {
  local set=$1 dir=$2
  mkdir -p $assets/$set.appiconset
  for spec in 16:16x16:icon-small 32:16x16@2x:icon-small 32:32x32:icon-small 64:32x32@2x:icon-small \
    128:128x128:icon 256:128x128@2x:icon 256:256x256:icon 512:256x256@2x:icon 512:512x512:icon 1024:512x512@2x:icon; do
    IFS=: read px name file <<<"$spec"
    rsvg-convert -w $px -h $px $dir/$file.svg -o $assets/$set.appiconset/icon_$name.png
  done
}
render AppIcon $src
render AppIcon-Dev $tmp
cp $assets/AppIcon.appiconset/Contents.json $assets/AppIcon-Dev.appiconset/Contents.json

cp $src/menubar.svg $assets/MenuBarIcon.imageset/menubar.svg
