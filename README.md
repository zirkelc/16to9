<p align="center"><img src="assets/logo/wordmark-adaptive.svg" width="360" alt="16to9"></p>

<p align="center">Resize any Mac window to an exact size or ratio.<br>For screenshots, screen recordings and demos that must have a fixed size.</p>

<p align="center">
  <a href="https://github.com/zirkelc/16to9/releases/latest"><b>Download for macOS</b></a> - macOS 14 or later - Free and open source
</p>

<p align="center"><img src="assets/hero.png" width="860" alt="16to9 shows a guide frame with rulers around a window"></p>

## Features

- **Exact sizes.** Select a preset or type `1920x1080`, and the front window gets this size.
- **Ratios with the smallest change.** Select 16:9, 4:3, 9:16 or type `1.91:1`. 16to9 keeps the width or the height, and changes the window as little as possible.
- **Guide with rulers.** A frame with rulers shows the target size on the screen, so that you can fit a window, or a part of a window such as a canvas or a video player, by hand. Each edge turns green when the window matches. Snap moves the window into the frame. By default, screenshots and screen recordings do not show the guide.
- **Presets.** Built-in sizes for social posts (X, LinkedIn, Instagram, YouTube, Open Graph, Product Hunt), screens (Full HD, 4K, MacBook) and Mac App Store screenshots. Add your own presets and put the ones you use most in Favorites.
- **Pixels, not guesses.** Sizes are in screenshot pixels, so a window screenshot has exactly the size you select, also on a Retina screen. You can change to points in Settings.
- **Shortcuts.** Show the guide from any app with ⌃⌥G, give each preset its own shortcut, and undo the last resize.
- **Preview.** While you point at a size in the menu, a frame on the screen shows the new size before you click.

## Install

1. Download the DMG from [Releases](https://github.com/zirkelc/16to9/releases/latest).
2. Open it and drag 16to9 into Applications.
3. Start 16to9. A short tour shows how to give it the Accessibility permission.

The app is signed with a Developer ID, notarized by Apple, and updates itself with [Sparkle](https://sparkle-project.org).

## Use

Click the 16to9 icon in the menu bar. Select **Resize window** or **Show guide**, then select a preset, or type a size such as `1280x720` or a ratio such as `16:9` and press Return.

https://github.com/user-attachments/assets/ad75ee62-d4e0-408d-b187-e5bd97ae17c4

Use the guide when only a part of a window must have the size, for example a canvas or a video player. The guide shows a frame with rulers in the target size. Move the frame over the area with the mouse or the arrow keys, then resize the window by hand until the area fills the frame. For a whole window, each edge of the frame turns green when it matches, and **Snap** moves the window into the frame.

Esc hides the guide, and ⌃⌥G shows and hides it from any app. You can change the shortcuts in Settings › Shortcuts.

## Why the Accessibility permission?

macOS lets an app move and resize the windows of other apps only with the Accessibility permission. 16to9 uses it only to read and set the position and size of the front window. It does not read the contents of windows. The guide works without the permission.

16to9 collects no data and has no analytics. The only network access is the check for updates. See the [privacy policy](PRIVACY.md).

## FAQ

**Why is 16to9 not in the Mac App Store?** Apps in the Mac App Store must use the App Sandbox, and the sandbox blocks the Accessibility API for other apps.

**Why does a window not get the exact size?** Some apps limit their window size, for example to a minimum size or to full lines of text in a terminal. 16to9 then shows a message with the size that the app accepted.

**Pixels or points?** macOS measures windows in points. On a Retina screen, 1 point is 2 pixels. A screenshot has the size in pixels, so 16to9 uses pixels by default.

## Build from source

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). The app bundles the font JetBrains Mono, which has the [SIL Open Font License 1.1](App/Resources/Fonts/JetBrainsMono-OFL.txt).
