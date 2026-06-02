# CleanLock

Lock your keyboard and trackpad while cleaning your Mac.

CleanLock is a native macOS utility that starts a temporary Cleaning Mode, blocks input, and shows a full-screen overlay so you can wipe down your keyboard and trackpad without accidental typing, clicks, scrolling, or media-key presses.

Repository: https://github.com/nxtode/CleanLock

## What It Does

- Locks keyboard, mouse, and trackpad input during Cleaning Mode.
- Shows a full-screen overlay across connected displays.
- Supports an emergency unlock hotkey.
- Supports an optional auto-unlock timer.
- Provides optional menu bar access.

## Features

- Normal macOS app window with four tabs: General, Permissions, Hotkey, About & Support.
- Optional menu bar icon.
- Custom unlock shortcut.
- Auto-unlock duration, including `0` to disable auto-unlock.
- Overlay styles: Default, Transparent, and Custom Image.
- Start at Login.
- Manual and automatic update checks via GitHub Releases.
- Accessibility and Input Monitoring permission detection.

## Installation

1. Download the latest DMG or ZIP from GitHub Releases.
2. Recommended: use the DMG.
3. Open the DMG and drag `CleanLock.app` into Applications.
4. Open CleanLock.
5. Go to the Permissions tab and enable the required macOS permissions.

Unsigned or unnotarized builds may trigger macOS Gatekeeper warnings.

## Required Permissions

CleanLock needs two macOS privacy permissions:

- Accessibility: needed to control and block input.
- Input Monitoring: needed to observe and intercept keyboard/input events.

macOS requires the user to manually approve these permissions. CleanLock cannot and should not bypass Apple’s privacy controls. The app can open the correct System Settings pages and detect when permissions are granted.

For normal users, a DMG, ZIP, or PKG cannot silently grant Accessibility or Input Monitoring permissions. Enterprise-managed Macs may use MDM/PPPC profiles, but that is outside normal app installation.

## Usage

1. Open CleanLock.
2. Configure settings in General, Permissions, Hotkey, and About & Support.
3. Click Start Cleaning Mode.
4. Clean your keyboard and trackpad.
5. Use the configured emergency shortcut to exit Cleaning Mode.

## Default Shortcut

The default unlock shortcut is:

```text
Left Command + Right Command
```

It is displayed in the app as:

```text
⌘ ⌘
```

This shortcut exits Cleaning Mode only. It does not quit CleanLock.

## Overlay Styles

- Default: a clean dark overlay.
- Transparent: a tinted overlay that lets you keep watching the screen while input is locked.
- Custom Image: choose an image to use as the overlay background.

Custom images are copied into `Application Support/CleanLock` so the overlay can still load them if the original file moves. If a custom image is missing or unreadable, CleanLock falls back safely to the default overlay.

## Update Checking

CleanLock checks GitHub Releases:

```text
https://api.github.com/repos/nxtode/CleanLock/releases/latest
```

Manual update checks are available in About & Support. Automatic update checks can be enabled or disabled and run at most once per day. CleanLock does not auto-install updates yet; use the release page to download the newest DMG or ZIP.

Full automatic updates via Sparkle are planned later.

## Known Limitations

- Some media, brightness, or hardware-level keys may be handled by macOS or firmware before CleanLock can intercept them.
- Unsigned or unnotarized builds may trigger Gatekeeper warnings.
- Permissions may require quitting and reopening CleanLock after approval.
- CleanLock is intended for brief cleaning sessions, not as a security lock.

## Build From Source

```sh
swift build
./script/build_and_run.sh --verify
./script/package_release.sh
```

## Release Packaging

`script/package_release.sh` creates release artifacts in `dist/`:

- `dist/CleanLock.app`
- `dist/CleanLock-v0.1.0.zip`
- `dist/CleanLock-v0.1.0.dmg`

The DMG includes `CleanLock.app` and an Applications symlink so users can drag the app into Applications.

## Support

- GitHub Issues: https://github.com/nxtode/CleanLock/issues
- Support options may be added later.

## License

License: Not yet specified.
