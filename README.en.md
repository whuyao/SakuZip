# YCompress

[简体中文](README.md) | [English](README.en.md) | [日本語](README.ja.md)

YCompress is a native, offline compression and extraction app for macOS. It uses
SwiftUI for the interface, ImageIO for images, AVFoundation for video, and the
built-in macOS tools `ditto`, `unzip`, and `tar` for archives.

Developed and maintained by the [UrbanComp](https://urbancomp.net) team.

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Download and documentation

- [Download the latest Apple Silicon build](https://github.com/whuyao/YCompress/releases/latest/download/YCompress-macOS-arm64.zip)
- [Installation guide](docs/INSTALL.en.md)
- [User guide](docs/USER_GUIDE.en.md)
- [Chinese requirements and repository analysis](REQUIREMENTS.md)

The `dist/` directory contains the ready-to-run `YCompress.app`, ZIP installer,
versioned DMG, and SHA-256 checksums. The installers are also attached to each
GitHub Release.

## Features

- Image compression: JPEG, PNG, HEIC, TIFF, BMP, GIF, and WebP, subject to the
  formats supported by the installed macOS version.
- Video compression: MOV, MP4, M4V, and other AVFoundation-readable formats.
  YCompress analyzes the source and selects a compatible preset expected to
  reduce its size.
- File and folder archiving: create ZIP files while optionally preserving macOS
  resource information.
- Safe extraction: ZIP, TAR, TGZ, and TAR.GZ, with absolute paths and `..`
  traversal rejected before extraction.
- Batch queue: mix images, video, files, folders, and archives.
- Queue controls: per-file percentage and stage details, pause after the current
  item, resume, or cancel processing.
- External input: Finder Open With, dropping files onto the App icon, and
  `open -a YCompress <file>`.
- Workflows: five built-in workflows plus custom workflows, with advanced image,
  video, ZIP, extraction, naming, and failure-handling settings.
- Output management: defaults to the source folder and supports selecting a
  different destination.
- Result comparison: shows the real saving or increase percentage. Video output
  that is not smaller than the source is deleted automatically.
- Cloud files: refreshes source size after hydration instead of retaining a
  stale zero-byte placeholder.
- Localization: the App, installation guide, and user guide support Simplified
  Chinese, English, and Japanese, following the macOS language preference.
- Privacy: all processing is local. YCompress does not upload files or make
  network requests.

## Build

Requires macOS 13 or later and Xcode.

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

The generated App is placed at `.build/YCompress.app`. The script uses an ad-hoc
signature for local use. Public distribution should use an Apple Developer ID
certificate and notarization.

Development:

```bash
swift run YCompress
```

Core checks:

```bash
swift run YCompressCoreChecks
```

Release packaging:

```bash
chmod +x scripts/package-release.sh
./scripts/package-release.sh
```

The release script places the App, ZIP, versioned DMG, and `SHA256SUMS` in
`dist/`. The DMG includes the Chinese, English, and Japanese documentation.

## Design source and licensing boundary

The product scope was informed by
[CompressO](https://github.com/codeforreal1/compressO), especially its batch
queue, quality presets, offline processing, and result comparison concepts.
CompressO is built with Tauri, React, and Rust, bundles tools such as FFmpeg,
pngquant, jpegoptim, and gifski, and is licensed under AGPL-3.0.

YCompress is an independent native Swift implementation. It does not copy or
link CompressO source code or binaries. Any future direct port of CompressO code
must comply with AGPL-3.0.

## Known limitations

- Video compression uses AVFoundation's discrete compatible presets. It does not
  expose exact bitrate, CRF, audio-track, subtitle, or encoder controls.
- Animated GIF or WebP files may be reduced to their first frame by ImageIO.
- Processing history is retained only for the current App session.
- 7z and RAR are not supported because macOS does not include their decoders.

## License

YCompress is released under the [MIT License](LICENSE).
