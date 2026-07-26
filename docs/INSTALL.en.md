# YCompress Installation Guide

## System requirements

- Apple Silicon Mac (M1, M2, M3, M4, or newer)
- macOS 13 Ventura or later
- No internet connection is required after installation

The current release is arm64-only and does not support Intel Macs.

## Install from ZIP

1. Download
   [`YCompress-macOS-arm64.zip`](https://github.com/whuyao/YCompress/releases/latest/download/YCompress-macOS-arm64.zip).
2. Double-click the ZIP to extract `YCompress.app`.
3. Drag `YCompress.app` into the Applications folder.
4. On first launch, Control-click or right-click the App and choose **Open**.
5. Choose **Open** again in the macOS confirmation dialog.

You can then launch YCompress from Launchpad, Spotlight, or Applications.

## Install from DMG

Download `YCompress-0.1.7-macOS-arm64.dmg` from the same Release, open it, and
drag `YCompress.app` onto the Applications shortcut.

## Why the first launch requires Open

The current build uses an ad-hoc signature and is not notarized with an Apple
Developer ID. Gatekeeper may block a normal double-click on first launch. The
source is publicly auditable, and the App does not upload files or make network
requests.

Do not disable Gatekeeper system-wide. Use the Control-click or right-click
**Open** method above.

If macOS still reports that the App is damaged and the installer came from this
repository's GitHub Release, run:

```bash
xattr -cr /Applications/YCompress.app
```

This removes only the downloaded quarantine attributes from YCompress and does
not change the system-wide Gatekeeper setting.

## Verify the installer

In Terminal, change to the folder containing the downloaded files and run:

```bash
shasum -a 256 YCompress-macOS-arm64.zip
# Or verify the ZIP and DMG together:
shasum -a 256 -c SHA256SUMS
```

The expected values for version `0.1.7` are included in the `SHA256SUMS` file
attached to the same Release and in the repository's `dist/` directory. Always
use the checksum file generated with the same release package.

If verification fails, download the files again from the GitHub Release and do
not install files from an unknown source.

## Uninstall

1. Quit YCompress.
2. Move `/Applications/YCompress.app` to the Trash.
3. To remove custom workflow preferences as well, run:

```bash
defaults delete com.yaoyao.ycompress
```

Deleting preferences does not remove compressed or extracted output files.

## Build from source

Install Xcode, clone the repository, and run:

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

The generated App is placed at `.build/YCompress.app`.

## Developer

YCompress is developed and maintained by the
[UrbanComp](https://urbancomp.net) team. The team website is available from the
App sidebar, Settings, and Help menu.
