#!/bin/zsh
# Builds a signed and notarized release DMG and publishes it with the Sparkle feed as a GitHub release.
#
# Usage: scripts/release.sh <version> <build>
# Example: scripts/release.sh 1.0 1
#
# One-time setup:
# - A "Developer ID Application" certificate of the team in the login keychain.
# - Notary credentials: xcrun notarytool store-credentials notary --apple-id <id> --team-id D568Q9VY3L. The profile
#   works for all apps of the team.
# - The Sparkle private key in the login keychain (account "ed25519"). Its public key is SPARKLE_PUBLIC_KEY in
#   project.yml.
# - The GitHub CLI, logged in with write access to the repo.
#
# Environment:
# - NOTARY_PROFILE: notarytool keychain profile (default notary)
# - RELEASE_DIR: keeps all earlier releases, which Sparkle needs for delta updates
#   (default ~/.local/share/16to9-release). It is not in build/, because a clean would delete it.
#
# Optional: release-notes/<version>.html, an HTML fragment that the Sparkle update window shows.
#
# The apps read the feed from https://github.com/zirkelc/16to9/releases/latest/download/appcast.xml, so each release
# has the feed as a file. The release is a draft until all files are up, because "latest" must not point to a
# release that has no feed yet.
set -euo pipefail

version=${1:?version, for example 1.0}
build=${2:?build number, for example 1}
notary_profile=${NOTARY_PROFILE:-notary}
root=${0:A:h:h}
out="$root/build/release/$version"
updates="${RELEASE_DIR:-$HOME/.local/share/16to9-release}/updates"
sparkle_bin="$root/build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin"
repo=zirkelc/16to9
team=D568Q9VY3L
tag="v$version"

# Sparkle offers an update only when its build number is higher than the installed one.
# The release folder keeps the feed of the last release.
if [[ -f $updates/appcast.xml ]]; then
  latest=$(grep -oE '<sparkle:version>[0-9]+<' "$updates/appcast.xml" | grep -oE '[0-9]+' | sort -n | tail -1 || true)
  if [[ -n $latest && $build -le $latest ]]; then
    echo "error: build $build is not higher than build $latest in the feed" >&2
    exit 1
  fi
fi

# The identity is found by the team ID, so the name on the certificate is not in the script.
identity=$(security find-identity -v -p codesigning | grep "Developer ID Application" | grep "($team)" | head -1 | awk '{print $2}' || true)
if [[ -z $identity ]]; then
  echo "error: no Developer ID Application certificate of team $team in the keychain" >&2
  exit 1
fi

cd "$root"
mkdir -p "$out" "$updates"

echo "→ Archive"
xcodegen generate -q
xcodebuild archive -project 16to9.xcodeproj -scheme 16to9 -configuration Release \
  -archivePath "$out/16to9.xcarchive" -derivedDataPath build/DerivedData -destination generic/platform=macOS \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build" -quiet

echo "→ Export with Developer ID"
cat > "$out/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$team</string>
  <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive -archivePath "$out/16to9.xcarchive" -exportPath "$out/export" \
  -exportOptionsPlist "$out/ExportOptions.plist" -quiet
app="$out/export/16to9.app"

if [[ ! -x $sparkle_bin/generate_appcast ]]; then
  echo "error: the Sparkle tools are not in $sparkle_bin" >&2
  exit 1
fi

if [[ -z $(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$app/Contents/Info.plist" 2>/dev/null) ]]; then
  echo "warning: SPARKLE_PUBLIC_KEY is empty, so this build cannot install updates"
fi

echo "→ Notarize the app"
ditto -c -k --keepParent "$app" "$out/16to9-notarize.zip"
xcrun notarytool submit "$out/16to9-notarize.zip" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"

echo "→ Make the DMG"
dmg="$updates/16to9-$version.dmg"
# A read-write image first, so that Finder can store the window layout in it. It has extra space for these settings.
rw="$out/16to9-rw.dmg"
size_kb=$(( $(du -sk "$app" | cut -f1) + 20000 ))
hdiutil create -size "${size_kb}k" -fs HFS+ -volname "16to9" -ov "$rw" -quiet
mount=$(hdiutil attach "$rw" -nobrowse -noautoopen | grep -oE '/Volumes/.*$' | tail -1)
# A mount that stays blocks the volume name for the next run.
trap 'hdiutil detach "$mount" -quiet 2>/dev/null || true' EXIT
ditto "$app" "$mount/16to9.app"
ln -s /Applications "$mount/Applications"
# Only Finder can write the window layout. Without the permission to control Finder, the DMG opens in the default view.
osascript <<APPLESCRIPT >/dev/null 2>&1 || echo "warning: Finder did not set the window layout of the DMG"
tell application "Finder"
  tell disk "$(basename "$mount")"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {240, 160, 840, 520}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set text size of viewOptions to 13
    set position of item "16to9.app" of container window to {150, 170}
    set position of item "Applications" of container window to {450, 170}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT
# The volume icon goes in after the layout, because Finder removes it when it writes the folder settings.
if [[ -f $app/Contents/Resources/AppIcon.icns ]]; then
  cp "$app/Contents/Resources/AppIcon.icns" "$mount/.VolumeIcon.icns"
  SetFile -a C "$mount" 2>/dev/null || echo "warning: the DMG has no volume icon"
fi
sync
hdiutil detach "$mount" -quiet
trap - EXIT
hdiutil convert "$rw" -format UDZO -imagekey zlib-level=9 -ov -o "$dmg" -quiet
codesign --sign "$identity" --timestamp "$dmg"

echo "→ Notarize the DMG"
xcrun notarytool submit "$dmg" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature --verbose "$dmg"

echo "→ Update the Sparkle feed"
# The update window shows the notes of the file with the name of the DMG. Without it, the window has no text.
notes="$root/release-notes/$version.html"
if [[ -f $notes ]]; then
  cp "$notes" "$updates/16to9-$version.html"
else
  echo "warning: no release notes in release-notes/$version.html, so the update window shows no text"
fi
# The feed keeps only the newest version, because the files of each version are in their own GitHub release and
# the download prefix is correct only for this one.
"$sparkle_bin/generate_appcast" --download-url-prefix "https://github.com/$repo/releases/download/$tag/" \
  --link "https://github.com/$repo" --maximum-versions 1 "$updates"
deltas=("${(@f)$(find "$updates" -maxdepth 1 -name '*.delta' -newer "$dmg")}")
deltas=(${deltas:#})

echo "→ Publish the GitHub release $tag"
gh release create "$tag" --repo "$repo" --title "16to9 $version" --generate-notes --draft \
  "$dmg" "${deltas[@]}" "$updates/appcast.xml"
gh release edit "$tag" --repo "$repo" --draft=false --latest
echo "Done: $dmg"
