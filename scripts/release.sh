#!/bin/zsh
# Builds a signed and notarized release DMG, publishes it as a GitHub release and updates the Sparkle feed.
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
# - GitHub Pages for the repo, with "GitHub Actions" as the source. It serves site/, which has the feed.
#
# Environment:
# - NOTARY_PROFILE: notarytool keychain profile (default notary)
# - RELEASE_DIR: keeps all earlier releases, which Sparkle needs for delta updates
#   (default ~/.local/share/16to9-release). It is not in build/, because a clean would delete it.
#
# The DMG goes up first and the feed last: the feed goes live only when site/appcast.xml is pushed, so an upload
# that stops halfway does not point users at a missing file.
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
feed="$root/site/appcast.xml"

# Sparkle offers an update only when its build number is higher than the installed one.
if [[ -f $feed ]]; then
  latest=$(grep -oE '<sparkle:version>[0-9]+<' "$feed" | grep -oE '[0-9]+' | sort -n | tail -1 || true)
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

if [[ -z $(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$app/Contents/Info.plist" 2>/dev/null) ]]; then
  echo "warning: SPARKLE_PUBLIC_KEY is empty, so this build cannot install updates"
fi

echo "→ Notarize the app"
ditto -c -k --keepParent "$app" "$out/16to9-notarize.zip"
xcrun notarytool submit "$out/16to9-notarize.zip" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$app"

echo "→ Make the DMG"
dmg="$updates/16to9-$version.dmg"
staging="$out/dmg"
mkdir -p "$staging"
ditto "$app" "$staging/16to9.app"
ln -sfn /Applications "$staging/Applications"
hdiutil create -volname "16to9" -srcfolder "$staging" -format UDZO -ov "$dmg" -quiet
codesign --sign "$identity" --timestamp "$dmg"

echo "→ Notarize the DMG"
xcrun notarytool submit "$dmg" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$dmg"
spctl --assess --type open --context context:primary-signature --verbose "$dmg"

echo "→ Update the Sparkle feed"
# The feed keeps only the newest version, because the files of each version are in their own GitHub release and
# the download prefix is correct only for this one.
"$sparkle_bin/generate_appcast" --download-url-prefix "https://github.com/$repo/releases/download/$tag/" \
  --link "https://github.com/$repo" --maximum-versions 1 "$updates"
deltas=("${(@f)$(find "$updates" -maxdepth 1 -name '*.delta' -newer "$dmg")}")
deltas=(${deltas:#})

echo "→ Publish the GitHub release $tag"
gh release create "$tag" --repo "$repo" --title "16to9 $version" --generate-notes "$dmg" "${deltas[@]}"

mkdir -p "${feed:h}"
cp "$updates/appcast.xml" "$feed"
echo "Done: $dmg"
echo "Next: commit and push site/appcast.xml. Then GitHub Pages publishes the feed and the apps find the update."
