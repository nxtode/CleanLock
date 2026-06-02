# CleanLock

Lock your keyboard and trackpad while cleaning your Mac.

CleanLock is a native macOS utility that starts a temporary Cleaning Mode, blocks input, and shows a full-screen overlay so you can wipe down your keyboard and trackpad without accidental typing, clicks, scrolling, or media-key presses.

Repository: https://github.com/nxtode/CleanLock

## Features

- Native macOS app window with General, Permissions, and About & Support tabs.
- Optional menu bar icon.
- Custom unlock shortcut.
- Auto-unlock duration, including `0` to disable auto-unlock.
- Overlay styles: Default, Transparent, and Custom Image.
- Start at Login.
- Manual and automatic update checks through GitHub Releases.
- Accessibility and Input Monitoring permission detection.

## Installation

1. Download the latest DMG or ZIP from GitHub Releases.
2. Recommended: open the DMG.
3. Drag `CleanLock.app` into Applications.
4. Open CleanLock.
5. Go to the Permissions tab and enable the required macOS permissions.

Unsigned or unnotarized builds may trigger macOS security warnings.

## Required Permissions

CleanLock needs two macOS privacy permissions:

- Accessibility: needed to control and block input.
- Input Monitoring: needed to observe and intercept keyboard/input events.

macOS requires manual approval for Accessibility and Input Monitoring. CleanLock cannot automatically grant these permissions during installation. The app opens the correct System Settings pages and detects when permissions are granted.

## Usage

1. Open CleanLock.
2. Configure General, Permissions, and About & Support.
3. Click Start Cleaning Mode.
4. Clean your keyboard and trackpad.
5. Use the configured emergency shortcut to exit Cleaning Mode.

## Default Shortcut

The default unlock shortcut is Left Command + Right Command, displayed as:

```text
⌘ ⌘
```

This shortcut exits Cleaning Mode only. It does not quit CleanLock.

## Overlay Styles

- Default: a clean dark overlay.
- Transparent: a tinted overlay that lets you keep watching the screen while input is locked.
- Custom Image: choose an image to use as the overlay background.

Custom images are copied into `Application Support/CleanLock` so the overlay can still load them if the original file moves. If a custom image is missing or unreadable, CleanLock falls back safely to the default overlay.

## Start At Login

The General tab includes `Start CleanLock at login`. CleanLock uses the macOS `ServiceManagement.SMAppService.mainApp` API on macOS 13 or later to register or unregister the app.

## Optional Menu Bar Access

The General tab includes `Show CleanLock in menu bar`. When enabled, the menu bar item can start Cleaning Mode, open CleanLock, or quit the app.

## Update Checking

CleanLock checks GitHub Releases:

```text
https://api.github.com/repos/nxtode/CleanLock/releases/latest
```

Manual update checks are available in About & Support. Automatic update checks can be enabled or disabled and run at most once per day. CleanLock does not auto-install updates; use the release page to download the newest DMG or ZIP.

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

## Known Limitations

- macOS requires manual Accessibility and Input Monitoring approval.
- Some media, brightness, or hardware-level keys may be handled by macOS before apps can intercept them.
- Unsigned or unnotarized builds may trigger macOS security warnings.
- Permissions may require quitting and reopening CleanLock after approval.
- CleanLock is intended for brief cleaning sessions, not as a security lock.

## License

License: Not yet specified.
