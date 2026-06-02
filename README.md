# CleanLock

CleanLock is a native macOS app for safely cleaning a Mac keyboard and trackpad. It shows a full-screen overlay across connected displays, temporarily blocks keyboard and pointing-device input, then unlocks with the configured emergency shortcut or an optional timer.

Repository: https://github.com/nxtode/CleanLock

## App Layout

CleanLock is a normal Dock app with an optional menu bar icon. The main window is split into tabs:

- General: status, Start Cleaning Mode, auto-unlock duration, optional menu bar toggle, and overlay appearance.
- Permissions: inline Accessibility and Input Monitoring status with System Settings buttons.
- Hotkey: Raycast-style emergency unlock recorder and reset.
- About & Support: app version, GitHub Releases update checking, support/donation placeholder, and links.

## Permissions

CleanLock requires:

- Accessibility
- Input Monitoring

Permission state is shown inside the Permissions tab. Each row shows `Granted` or `Required`; settings buttons become disabled once access is detected. If either permission is missing, the app status is `Permissions Required` and Start Cleaning Mode is disabled.

After enabling permissions in System Settings, quit and reopen CleanLock if macOS asks you to.

## Hotkey

The default unlock shortcut is Left Command + Right Command, displayed as `⌘ ⌘`.

Shortcut display uses symbol-only formatting:

- Command: `⌘`
- Shift: `⇧`
- Option: `⌥`
- Control: `⌃`
- Caps Lock: `⇪`
- Function: `fn`
- Return: `↩`
- Escape: `⎋`
- Delete: `⌫`
- Forward Delete: `⌦`
- Arrow keys: `↑ ↓ ← →`

Hotkeys must contain at least 2 keys. Single-key shortcuts and reserved shortcuts such as `⌘ Q`, `⌘ W`, `⌘ H`, `⌘ M`, `⌘ Tab`, `⌘ Space`, and Escape alone are rejected.

Pressing the emergency shortcut during Cleaning Mode only stops input blocking and closes the overlay. It must not quit CleanLock, close the main window, or change menu bar state.

## Input Blocking

CleanLock blocks keyboard, mouse, trackpad, scroll, drag, and system-defined media key events while Cleaning Mode is active. Media/system keys are intercepted through CoreGraphics `systemDefined` events when macOS exposes them, including common play/pause, track, volume, mute, brightness, and keyboard illumination controls.

Some hardware-level keys or firmware-handled controls may not be interceptable on every Mac or keyboard.

## Auto-Unlock

The General tab accepts an auto-unlock duration from 0 to 3600 seconds.

- Empty input falls back to 60 seconds.
- Negative values become 0.
- Values over 3600 become 3600.
- Duration 0 disables auto-unlock and the overlay shows `Auto-unlock disabled.`

## Start At Login

The General tab includes `Start CleanLock at login`. It uses the macOS 13+ `ServiceManagement.SMAppService.mainApp` API to register or unregister the app. If registration fails while running from a development/debug bundle, CleanLock shows an inline status message and keeps running.

## Overlay Appearance

The General tab includes overlay appearance options:

- Default: the clean, dark utility overlay.
- Transparent: a semi-transparent tint so the screen remains visible while input is locked.
- Custom Image: choose an image for the overlay background.

Transparent overlay opacity is clamped from 10% to 70%, with a default of 35%. It still shows the essential Cleaning Mode text so the user knows input is locked.

Custom image supports `png`, `jpg`, `jpeg`, `heic`, and `tiff`. CleanLock copies the selected image into `Application Support/CleanLock` and stores that copied path in preferences. If the copied file is missing or unreadable, CleanLock falls back to the Default overlay style without crashing.

## About & Support

The About & Support tab combines:

- About: CleanLock version `0.1.0`, build `1`, bundle identifier, copyright, and description.
- Updates: manual GitHub Releases update checking.
- Support / Donate: GitHub Sponsors state.

Manual update checking calls GitHub Releases at `https://api.github.com/repos/nxtode/CleanLock/releases/latest`, compares the latest `tag_name` against the current version, and shows an Open Release Page button when a newer release exists.

Automatic update checking is enabled by default. When enabled, CleanLock checks once per day shortly after launch without blocking startup or showing modal popups. Manual Check for Updates always runs when clicked. Full automatic downloads/installs via Sparkle are planned later.

Support constants are isolated in `AppInfo.swift`. GitHub Sponsors is pending confirmation, so CleanLock shows `GitHub Sponsors coming soon.` unless a sponsor URL is configured.

## Build And Run

Open this folder in Xcode as a Swift Package, or build from Terminal:

```sh
swift build
```

To build a runnable `.app` bundle locally:

```sh
./script/build_and_run.sh
```

The script creates `dist/CleanLock.app` with bundle identifier `dev.asuncion.cleanlock`, version `0.1.0`, build `1`, and the generated `Resources/AppIcon.icns` icon.

## Manual Test Checklist

1. Launch CleanLock and confirm the main window opens as a normal Dock app.
2. Confirm tabs appear as real tabs: General, Permissions, Hotkey, About & Support.
3. Check permissions before granting access; missing rows should show `Required`.
4. Grant Accessibility and Input Monitoring, refresh, and confirm both rows show `Granted`.
5. Confirm Start Cleaning Mode is disabled until both permissions are granted.
6. Start Cleaning Mode from the General tab.
7. Start Cleaning Mode from the menu bar.
8. Press `⌘ ⌘`; the overlay should close and input should return.
9. Confirm emergency unlock does not close or quit CleanLock.
10. Record Left Command + Left Shift and confirm it unlocks without crashing.
11. Confirm recording applies after releasing the keys.
12. Record one key and confirm it is rejected.
13. Record `⌘ Q` and confirm the app does not quit.
14. Set duration to 0 and confirm auto-unlock is disabled.
15. Toggle the optional menu bar icon off and on without duplicates.
16. Toggle Start CleanLock at login and confirm success or a clear inline failure message.
17. Confirm media keys are blocked during Cleaning Mode when macOS exposes them to the event tap.
18. Confirm brightness keys are blocked or note the documented hardware limitation.
19. Confirm Transparent overlay keeps the screen visible.
20. Confirm Default overlay works.
21. Choose a custom image and confirm it appears behind readable overlay text.
22. Move/delete the copied custom image and confirm fallback is safe.
23. Enable automatic update checks, relaunch, and confirm status updates at most once per day.
24. Disable automatic update checks and confirm only manual checks run.
25. Click Check for Updates with no public release and confirm it reports that state.
26. Click Check for Updates when a release exists and confirm Open Release Page appears.
27. Confirm GitHub Sponsors handles pending or active state safely.
28. Confirm About & Support shows version `0.1.0` build `1`.
29. Use explicit Quit CleanLock and confirm the app exits safely.

## Known Limitations

- macOS may require quitting and reopening CleanLock after granting Accessibility or Input Monitoring permissions.
- Permission prompts and System Settings panes can vary between macOS releases.
- Automatic downloads/installs are not implemented yet; automatic checks and manual checks use GitHub Releases.
- Some hardware-level media keys may not be interceptable depending on macOS and hardware.
- Secure system surfaces may reserve some input behavior outside third-party control.
- CleanLock is intended for brief cleaning sessions, not security locking.
