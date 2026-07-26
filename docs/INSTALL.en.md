# SakuZip Installation Guide

## System requirements

- Apple Silicon Mac (M1, M2, M3, M4, or newer)
- macOS 13 Ventura or later
- No internet connection is required after installation

The current release is arm64-only and does not support Intel Macs.

## Install from ZIP

1. Download
   [`SakuZip-macOS-arm64.zip`](https://github.com/whuyao/SakuZip/releases/latest/download/SakuZip-macOS-arm64.zip).
2. Double-click the ZIP to extract `SakuZip.app`.
3. Drag `SakuZip.app` into the Applications folder.
4. On first launch, Control-click or right-click the App and choose **Open**.
5. Choose **Open** again in the macOS confirmation dialog.

You can then launch SakuZip from Launchpad, Spotlight, or Applications.

## Install from DMG

Download `SakuZip-0.2.1-macOS-arm64.dmg` from the same Release, open it, and
drag `SakuZip.app` onto the Applications shortcut.

## Upgrade from YCompress

On its first launch, SakuZip automatically imports the interface language and
workflow settings saved by YCompress. After confirming that SakuZip works, you
may remove `YCompress.app` from Applications. Removing the old app does not
affect compressed or extracted files.

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
xattr -cr /Applications/SakuZip.app
```

This removes only the downloaded quarantine attributes from SakuZip and does
not change the system-wide Gatekeeper setting.

## Verify the installer

In Terminal, change to the folder containing the downloaded files and run:

```bash
shasum -a 256 SakuZip-macOS-arm64.zip
# Or verify the ZIP and DMG together:
shasum -a 256 -c SHA256SUMS
```

The expected values for version `0.2.1` are included in the `SHA256SUMS` file
attached to the same Release and in the repository's `dist/` directory. Always
use the checksum file generated with the same release package.

If verification fails, download the files again from the GitHub Release and do
not install files from an unknown source.

## Uninstall

1. Quit SakuZip.
2. Move `/Applications/SakuZip.app` to the Trash.
3. To remove custom workflow preferences as well, run:

```bash
defaults delete net.urbancomp.sakuzip
```

Deleting preferences does not remove compressed or extracted output files.

## Build from source

Install Xcode, clone the repository, and run:

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

The generated App is placed at `.build/SakuZip.app`.

## Developer

SakuZip is developed and maintained by the
[UrbanComp](https://urbancomp.net) team. The team website is available from the
App sidebar, Settings, and Help menu.
