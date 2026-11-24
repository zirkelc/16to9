# Window Resizer: plan

Mockup: [design/mockup.html](../design/mockup.html). The decision IDs (D1 to D6) refer to section 7 of the mockup.

## Decisions

- D1: both popover layouts, list and grid. A setting and a button in the popover header switch them. List is the default.
- D2: screenshot pixels by default.
- D3: macOS 14.
- D4: open source under the MIT license and free. The signed and notarized DMG is on GitHub Releases, and each release also has the Sparkle feed. The apps read it from `https://github.com/zirkelc/16to9/releases/latest/download/appcast.xml`, which always points to the newest release. Reason: users must give the app the Accessibility permission, and the source code lets them check what the app does with it. The audience (people who make screenshots and videos) is small, and a license check, a trial and a payment provider add more work than the sales would pay for.
- D5: name 16to9 (before: Fitframe), bundle ID `dev.zirkelc.16to9`. A Swift module name cannot start with a digit, so the Xcode target and the module are `SixteenToNine`. Quick check on 2026-11-11: no app with this name in the App Store, the GitHub name is free, and 16to9.app, 16to9.io and get16to9.com are free. 16to9.com is registered. Rejected names: Superframe (superframe.app is an AI video and aspect-ratio tool, superframe.com a funded company) and Golden Ratio (Goldie, a Mac golden-ratio overlay app). Not checked: trademarks and the X handle.
- D7: distribution outside the Mac App Store, as a DMG signed with Developer ID and notarized by Apple. Updates with Sparkle. Reason: the App Sandbox blocks the Accessibility API for other apps (see "Window control"), and the Shortcuts workaround needs too much setup for the user.
- D6: logo and colors. The app icon is a navy blueprint tile with two white rulers (numbered 0 to 16 and 0 to 9) and a 16:9 window in an amber frame. The wordmark uses JetBrains Mono (SIL Open Font License) as paths. Each "16to9" in the app uses the same style: JetBrains Mono ExtraBold (bundled in the app), with "to" in amber (`#D98C00` on a light background, for contrast). Colors: navy `#2350A0` (tile and primary), dark `#0A1C45`, amber `#FFB547` (guide frame and onboarding buttons), white rulers. The source SVG files are in `design/logos/final/`. Amber is the default guide color. An edge that is not at its target is red, so that it differs from the amber guide (orange when the guide is pink).

## Status

Milestones 1 to 7 are done. Milestone 8 is done in part (no sandbox, Sparkle with its public key and feed URL, release script, CI workflow). Checked on this Mac:

- 60 unit tests in `ResizerCore` pass.
- Debug and Release builds have no warnings.
- The app, started with `open` and with its own Accessibility permission, resized a test window to 16:9 and to 1920 × 1080. Snap moved it exactly into the guide (all edges green).
- On a screen with scale 2 (the built-in Retina screen), Snap moved a window exactly into the guide (all edges green), and the menu shows sharp.
- macOS returns no image of the guide panels in screen captures while "Hide the guide in screenshots" is on.
- German: all UI texts and the social preset names have a translation. The popover, all settings panes, the onboarding window and the guide bar were checked in German.
- `scripts/release.sh` archives the app and exports it with the Developer ID certificate (hardened runtime, no entitlements, `codesign --verify --deep --strict` passes). Apple notarizes the app and the DMG, Gatekeeper accepts both ("Notarized Developer ID"), and `generate_appcast` signs the feed entry with the Sparkle key.

Not done or not checked yet:

- A full update from one release to the next.
- The permission card with a real drag and drop into the Accessibility list (all checks ran while the permission was on).
- VoiceOver: the icon buttons, preset rows and section headers have labels, but nobody has used the app with VoiceOver on yet.

## Goal

A small macOS menu bar app that:

1. Resizes the front window to an exact size (for example 1920 × 1080) or to a ratio (for example 16:9) with the smallest change.
2. Shows a guide frame with rulers on the screen, so that the user can move and resize a window by hand.
3. Has built-in presets for social platforms, screens and App Store screenshots, and lets the user add presets.
4. Is minimal, looks native, and ships as a signed and notarized download with automatic updates.

## Scope of version 1.0

- Menu bar icon with a popover (no Dock icon, `LSUIElement`).
- Two actions for each preset: resize the window, or show the guide.
- Field for a one-time size or ratio (`1280x720`, `1280 720`, `4:3`, `1.91:1`).
- Ratio fit with the smallest change (see "Fit algorithm").
- Guide overlay: frame, rulers, guide lines across the screen, live match readout for each edge, Snap button.
- Undo of the last resize for each window.
- Global shortcuts for presets, for the guide, and for undo.
- Settings: General, Presets, Guide, Shortcuts, About.
- Onboarding for the Accessibility permission.
- Launch at login.
- Light and dark mode. English and German.

Not in 1.0 (candidates for later): sizing by content area (for example the browser viewport) instead of the window frame, screenshot capture in the app, window layouts (halves, thirds), sync of presets through iCloud.

## Technology

- Swift 6, SwiftUI for all views, AppKit where SwiftUI is not sufficient (status item, overlay panels, Accessibility).
- Minimum macOS 14 (D3).
- Project file generated with XcodeGen from `project.yml`. This keeps the project file out of merge conflicts and lets agents change targets as text.
- Pure logic in a local Swift package `ResizerCore`. It has no AppKit dependency, so `swift test` runs fast in the terminal.
- Tests with Swift Testing (`import Testing`).
- Dependencies:
  - [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) for global shortcuts and the recorder control.
  - [Sparkle](https://sparkle-project.org) for updates.
  - `SMAppService.mainApp` (system API) for launch at login.

## Architecture

```
project.yml                     XcodeGen project (the .xcodeproj is generated)
App/
  Resources/                    Assets (app icon), PrivacyInfo.xcprivacy, string catalogs (Localizable, Presets)
  Sources/
    main.swift, AppDelegate     app start, status item, windows, debug screens
    Model/
      AppSettings               all settings, stored in UserDefaults
      AppModel                  connects the parts, actions for the views
      Shortcuts                 global shortcuts (KeyboardShortcuts)
      Updater                   update checks (Sparkle), off when the build has no key
      PresetNames               translated names of built-in presets and groups
    Windows/
      AccessibilityPermission   check state, open System Settings, check again each second
      FrontAppTracker           remembers the last front app that is not this app
      AXWindow                  read and write position and size with AXUIElement
      ResizeService             candidates, read back, undo stack
      ScreenInfo                screens in Accessibility coordinates
    Guide/
      GuideController           state, panels, live readout
      GuideOverlayView          frame, guide lines, rulers, edge colors
      GuideControlsView         drag tag and action bar (Snap, nudge, center, hide), hover and tooltips
    UI/
      StatusItemController      menu bar icon and popover
      FloatingPanel             non-activating panels for overlay, bar and toast
      Popover/                  list and grid layouts, search field, rows
      Settings/                 sidebar window, panes, keycap shortcut field, guide preview
      Onboarding/               tour window, demo loop, card to drag the app into the Accessibility list
      Toast/                    result and undo message
Packages/ResizerCore/           pure logic with tests (Swift Testing)
  AspectRatio, PresetTarget     value types and units
  SizeInput                     reads "1280x720", "16:9", "1.91:1"
  FitCalculator                 ratio fit, screen fit, position rules
  GuideGeometry                 ruler ticks, edge match, guide frame
  ScreenGeometry                coordinate conversion, screen of a window
  PermissionCardLayout          position of the permission card next to System Settings
  Preset, PresetLibrary         built-in presets, favorites, custom
scripts/make-icon.sh            renders the app icon and the menu bar glyph from the logo SVG files
scripts/release.sh              archive, Developer ID export, notarization, DMG, Sparkle feed
```

## Key technical points

### Window control

- The macOS Accessibility API (`AXUIElement`) is the only public way to move and resize windows of other apps. The user turns on the app in System Settings › Privacy & Security › Accessibility.
- The App Sandbox blocks these calls, also when the permission is on (tested on macOS 26: `deny mach-lookup com.apple.axserver`). Apple's support staff confirm this. Magnet and Moom are on the Mac App Store without the sandbox, because they were there before the sandbox became a requirement in 2012. Thus 16to9 ships without the sandbox, outside the store.
- Permission flow (idea from Scrawl, MIT licence): the onboarding button opens the Accessibility list in System Settings and shows a card next to its window. The user drags the app from the card into the list. The card finds the System Settings window through the window server (no permission needed), docks below it (else in its empty lower part, else at its side), follows it, hides while another app is in front, and closes with a confirmation when the permission is on. The app does not use the system prompt, because macOS shows it only one time for each app. The app reacts to the `com.apple.TCC.updated` notification and also checks two times a second.
- macOS 27 renames the Accessibility list to "Device Control and Data Access". Texts that name the list must follow this.
- When the popover opens, this app becomes active. Thus `FrontWindowTracker` listens to `NSWorkspace.didActivateApplicationNotification` and keeps the last app that is not this app. The resize goes to the focused window of that app (`kAXFocusedWindowAttribute`).
- Global shortcuts do not activate this app, so the front app is correct there.
- Coordinates: AX uses a top-left origin on the primary screen. AppKit (`NSScreen`) uses a bottom-left origin. One converter in `ResizerCore` does this, with tests for screens above, below and left of the primary screen.
- Set size, then position, then size again. This is the usual order, because apps limit the size by the space on the screen.
- Some apps (Electron, Chrome) animate or resize slowly when `AXEnhancedUserInterface` is on. Turn it off for the resize and turn it on again after.
- Read the frame back after each change. If the app did not accept the size (minimum size, size in steps), try the other ratio candidate, then show the real result in the toast.
- Full screen windows and windows that cannot be resized (`AXUIElementIsAttributeSettable` is false): show a clear message, do nothing.

### Settings window

- The native sidebar of macOS (`NavigationSplitView`), as in System Settings and CleanShot: on macOS 26 a floating glass panel with a colored icon for each pane, and the pane title in the title bar. The window has one fixed size (780 × 600, just large enough that no pane needs a scroll bar) and opens on the screen with the mouse pointer. An empty toolbar gives the title bar its full height, so that the window buttons have a margin. The title bar is transparent, because macOS 26 otherwise draws a line below it. A pane shows at once without a transition.
- Forms are grouped, with a title for each group and a help line under rows that need one. The groups start at the same left edge as the pane title.
- The Accessibility permission shows only when it is missing: an orange callout at the top of General with a Set Up button.
- Presets: the groups are a row of pills, so that the window has only one sidebar. Below the pills are one line about the group and one rounded card in the CleanShot style. A header row names the columns. Each row shows the shape and the name, the size, the ratio, the shortcut, and a star for Favorites in the last column (its title is a star). All values start at the left edge of their column, below the column title. The table measures its cells: the size, ratio and shortcut columns are as wide as their widest cell (title or value), the star column is as narrow as the star, and the gap between all columns is the same. The name column gets the remaining space. The sheet for a custom preset has a switch for Size or Ratio and two number fields. The pane lays out the header and the rows itself and does not use a system list, because a system list gives selectable rows other margins than the header. The card ends below the last row, so it shows no empty rows and no scroll bar. The menu shows all presets, and Favorites at the top. Only custom presets can be selected (to edit or delete them), and only favorites can be dragged to a new order.
- Shortcuts: a grouped form with two groups, so that the pane needs no scroll bar. "Shortcuts" has the global shortcuts (show or hide the guide, undo the last resize). The menu has no shortcut, because a click on the menu bar icon opens it. "While the guide shows" has a row for Escape and a row for the arrow keys, each with fixed keycaps and a switch. Next to the keycaps of a global shortcut: ✕ removes the shortcut, ↺ resets a shortcut that has a default.
- Shortcut fields show the keys as keycaps (idea from Scrawl). Escape cancels, Delete removes the shortcut. The field refuses a shortcut without ⌘, ⌥ or ⌃ (except function keys) and a shortcut that another action uses. While a field listens, the global shortcuts are paused. While it listens, the field keeps its label and width, and a popover below it (Raycast style) shows the held keys, the hint, the errors and a button that removes the shortcut. So the shortcut column of the presets table has a fixed width. The table does not show the ✕ and ↺ buttons next to the field.
- Guide: a live preview shows the color, the dim and the center lines. All shortcuts, also the guide shortcut, are only in the Shortcuts pane.
- Presets: a visible "Add Preset" button, Delete only in the Custom group, and an empty state for the Custom group.
- About (like CleanShot): icon, name, version and copyright; Updates (check now, check automatically); Links (website, privacy policy, support); a button that shows the welcome tour again (like Scrawl); Acknowledgments for KeyboardShortcuts, Sparkle and Scrawl (all MIT licence).
- The General pane reads the login item state in the background, because that call can take more than 100 ms.

### Onboarding

- Six steps in one window (620 × 500, always dark navy, blue glow, amber buttons): Welcome, How it works (a 9 s demo loop, one still frame with Reduce motion), Permission (Allow opens System Settings with the drag card), Try it (an arrow below the menu bar icon; the step ends with the first resize), Show the guide (the guide shortcut and a short loop of the guide with rulers; the step ends when the guide shows) and Done (with the icon and name of the resized app and its new size). The arrow moves with a clock: a repeating SwiftUI animation also repeated the fade-in of its label, which made it flicker.
- The tour opens on the first launch. When the user sets up the permission later (from the menu, Settings or the guide), the window opens only on the Permission step.

### Units

- macOS windows use points. A screenshot has pixels. On a Retina screen, 1 pt = 2 px.
- The setting "Units" (D2) selects how the app shows and reads sizes. Conversion uses `backingScaleFactor` of the screen that has the window.
- A window screenshot (⇧⌘4, then Space) has the size of the window frame. With the shadow, macOS adds a margin. Holding ⌥ removes the shadow. The guide HUD shows this tip one time.

### Fit algorithm

Input: current frame, target ratio, visible frame of the screen (no menu bar, no Dock), mode (smallest change, keep width, keep height).

1. Candidate A keeps the width: `height = width / ratio`. Candidate B keeps the height: `width = height × ratio`. Round to whole pixels in the selected units.
2. In "smallest change" mode, pick the candidate with the smaller absolute change in points. On a tie, pick the smaller window.
3. If the candidate does not fit the visible frame, take the other one. If neither fits, use the largest size with the ratio that fits.
4. Keep the top-left corner. If the new frame goes off the screen, move it inside.
5. Exact sizes use the same steps 3 and 4. A size that cannot fit is gray in the popover.

All of this is pure code in `FitCalculator` with table-driven tests.

### Guide overlay

- `GuideOverlayPanel` is an `NSPanel`: borderless, transparent, `ignoresMouseEvents = true`, level above normal windows and below the menu bar, `collectionBehavior` `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`.
- `sharingType = .none` keeps it out of screen captures. This must be tested on macOS 14, 15 and 26 with the system screenshot tool, because the behavior changed for ScreenCaptureKit in recent versions. If it does not work, the HUD gets a "Hide for 5 s" action.
- The overlay cannot take clicks, because the user must resize the window under it. Thus a second small panel, `GuideHUDPanel`, holds the buttons, and drag handles at the frame corners move the frame.
- While the guide shows, Escape hides it and the arrow keys move the frame by one unit (ten units with Shift), but at least by one point. An event tap takes these keys from all other apps while the guide shows, so that the front app does not also get them. Each key has a switch in Settings › Shortcuts (both on by default), for users who need the keys in their app while the guide shows. The guide shortcut (for example ⌃⌥G) also toggles the guide.
- The arrow buttons and the arrow keys do not move the bar, so that the buttons stay under the mouse.
- The frame is always at whole points, because macOS moves windows only by whole points. On a screen with scale 2, a frame at a half point is 1 px away from each window that the user can make, so Snap could never match it. The frame starts at whole points, and a drag or an arrow key moves it by whole points (on a screen with scale 2, an arrow key moves it by 2 px).
- Rulers: zero is at the top left corner of the visible area, so the rulers stay in place while the frame moves. A marker on each ruler shows the position of each edge of the frame. The tag and the bar show the size.
- Live readout: the guide reads the frame of the front window ten times a second while it shows. This also follows a change of the front window. Each edge is green when it matches to the unit, else orange with the distance and an arrow.
- Snap: the same window control as the resize action, with the frame of the guide as the target.
- The guide shows on the screen that has the front window. It starts centered on that screen.

### Presets

- Built-in presets are defined in code (`PresetCatalog`), so the compiler checks them. Groups: Ratios, Screens, Social, App Store. The user can pin them to Favorites and give them a shortcut, but not hide or delete them.
- User presets and user changes are stored as JSON in `UserDefaults` (small data, no database needed).
- Social sizes change often. Check all values against the platform documentation before each release. First list:

| Group | Name | Size (px) | Ratio |
| --- | --- | --- | --- |
| Ratios | 16:9, 16:10, 4:3, 3:2, 1:1, 4:5, 9:16, 21:9, 2:1, 1.91:1 | | |
| Screens | HD, Full HD, QHD, 4K UHD, MacBook Air 13", MacBook Pro 14" | 1280 × 720, 1920 × 1080, 2560 × 1440, 3840 × 2160, 2560 × 1664, 3024 × 1964 | |
| Social | X post | 1600 × 900 | 16:9 |
| Social | X header | 1500 × 500 | 3:1 |
| Social | LinkedIn post | 1200 × 627 | 1.91:1 |
| Social | LinkedIn square | 1200 × 1200 | 1:1 |
| Social | LinkedIn cover | 1584 × 396 | 4:1 |
| Social | Instagram square | 1080 × 1080 | 1:1 |
| Social | Instagram portrait | 1080 × 1350 | 4:5 |
| Social | Instagram story | 1080 × 1920 | 9:16 |
| Social | YouTube thumbnail | 1280 × 720 | 16:9 |
| Social | Open Graph image | 1200 × 630 | 1.91:1 |
| Social | Product Hunt gallery | 1270 × 760 | |
| App Store | Mac screenshots | 1280 × 800, 1440 × 900, 2560 × 1600, 2880 × 1800 | 16:10 |

## Milestones

1. **Setup.** `project.yml`, app target, `ResizerCore` package, hardened runtime on, `LSUIElement`, signing with the team ID (also for debug builds, because a new ad-hoc signature resets the Accessibility permission on each build).
2. **Core logic.** Size and ratio parsing, units, `FitCalculator`, coordinate converter, `GuideGeometry`, preset catalog. Tests first.
3. **Window control.** Permission check and onboarding, front window tracking, resize with read back, undo, error cases. Manual test list below.
4. **Popover.** Status item, list layout, search field, keyboard control, gray rows for sizes that do not fit, toast.
5. **Guide.** Overlay panel, rulers, guide lines, HUD panel, live readout, Snap, multiple screens.
6. **Settings and About.** All panes, shortcuts, launch at login, restore defaults.
7. **Polish.** App icon and menu bar template icon, animations, VoiceOver labels, German strings.
8. **Distribution.** See the release checklist.

## Tests

- Unit tests (Swift Testing) for all of `ResizerCore`: parsing, rounding, both fit modes, ties, screen limits, coordinate conversion on more than one screen, ruler ticks, edge match.
- Manual test list for window control: Safari, Chrome, Finder, Terminal, Xcode, VS Code or Slack (Electron), a Catalyst app. Two screens with different scale factors. Stage Manager on. A full screen window. A window on another Space.
- UI check of popover and settings in light and dark mode.

## Release checklist

- One time: notary credentials with `xcrun notarytool store-credentials notary --apple-id <id> --team-id D568Q9VY3L` (an app-specific password of the Apple ID). The profile works for all apps of the team.
- One time: the Sparkle private key in the login keychain (account `ed25519`), with a backup in 1Password (`generate_keys -x <file>` from `build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin`), because a lost key stops all updates. The public key is `SPARKLE_PUBLIC_KEY` in `project.yml`.
- One time: the public repo `zirkelc/16to9`, and the GitHub CLI logged in.
- Each release: `scripts/release.sh <version> <build>`. The build number must be higher than before, because Sparkle compares it (the script checks this). The script publishes the DMG, the delta updates and the feed as the GitHub release `v<version>`. The release is a draft until all files are up. Keep the release folder (`~/.local/share/16to9-release`), because Sparkle makes delta updates from the earlier releases, and the script reads the last build number from its feed.
- Each release: test the DMG on a second Mac or user account (Gatekeeper, first start, permission prompt, update from the previous version).

## Risks

- **Trust in a download.** Users must give Accessibility to an app from outside the store. Mitigation: notarization, clear onboarding text, a privacy policy, the guide works without the permission.
- **Lost Sparkle key.** Without the private key, no update can reach existing users. Mitigation: a backup of the key in a password manager.
- **Hidden from screenshots.** `sharingType = .none` can be ignored by some capture paths. Mitigation: test early in milestone 5, fallback "Hide for 5 s".
- **Apps that ignore sizes.** Read back and a clear toast.
- **Name.** Register 16to9.app, and check trademarks (USPTO, EUIPO, classes 9 and 42) and the X handle before the first release.
