# Changelog

All notable changes to Chaotic Jelly will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-07

### Added
- Initial project scaffold with SwiftUI + SwiftData (macOS 14+)
- Recursive folder scanning for video files (MKV, MP4, M4V, AVI, MOV, TS, M2TS)
- FFprobe-based media analysis with full JSON stream parsing
- Language detection with confidence levels (high/medium/low/unknown)
- AnalysisEngine with configurable language rules and conservative mode
- Non-English subtitle and audio track removal via FFmpeg
- MKVToolNix (mkvmerge) integration for safer MKV stream operations
- Network-share-safe processing pipeline (copy-local, process, validate, replace)
- Post-process validation (duration check, stream counts, integrity)
- Local working cache with space management and orphan cleanup
- SwiftData job persistence with full state machine transitions
- Job history tracking with space savings metrics
- Crash-safe job recovery on app restart
- Dry-run preview mode
- Forced subtitle preservation
- SDH and commentary track preservation options
- Secure token storage via macOS Keychain
- Structured logging with OSLog and file-based export
- Full SwiftUI interface: Dashboard, Scan, Review, Queue, History, Settings, Logs
- XcodeGen project configuration
- GitHub Actions CI/CD workflow
- Unit tests for FFprobe parsing, analysis engine, job states, language utils

[Unreleased]: https://github.com/Shifting83/Chaotic-Jelly/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.1.0

## [0.1.1] - 2026-04-07

### Changes
- fix: repair YAML syntax error in release workflow line 151 (098625d)
- fix: resolve 5 remaining Swift compiler errors from CI build log (593836c)
- fix: resolve Swift compilation errors for Xcode build (912e2d0)

[0.1.1]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.1.1

## [0.2.0] - 2026-04-07

### Changes
- feat: add app icon — film strip with foreign language/audio prohibition badge (d354b77)

[0.2.0]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.2.0

## [0.2.1] - 2026-04-07

### Changes
- fix: build runnable .app with ad-hoc signing instead of unsigned archive (fcdadbf)

[0.2.1]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.2.1

## [0.2.2] - 2026-04-07

### Changes
- fix: separate build/package/DMG steps, remove silent failure fallback (6f63831)

[0.2.2]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.2.2

## [0.2.3] - 2026-04-07

### Changes
- fix: CFBundleExecutable name mismatch — app wouldn't launch (0edbb2b)

[0.2.3]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.2.3

## [0.3.0] - 2026-04-07

### Changes
- fix: add DEVELOPMENT_TEAM to xcodebuild for Developer ID signing (4765ab6)
- feat: enable Developer ID code signing and Apple notarization (7783c04)

[0.3.0]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.0

## [0.3.1] - 2026-04-07

### Changes
- fix: app icon (remove transparency) and add Help book (5365830)

[0.3.1]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.1

## [0.3.2] - 2026-04-07

### Changes
- fix: replace multi-file icons with single 1024px AppIcon.png (3ae8fa9)

[0.3.2]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.2

## [0.3.3] - 2026-04-07

### Changes
- fix: improve ffprobe reliability for network share files (bfdbd3e)

[0.3.3]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.3

## [0.3.4] - 2026-04-07

### Changes
- fix: path construction for filenames with multiple dots (e.g., P.M.mkv) (1e58818)

[0.3.4]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.4

## [0.3.5] - 2026-04-07

### Changes
- fix: use individual icon files per size slot for asset catalog (3fa96ae)

[0.3.5]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.5

## [0.3.6] - 2026-04-07

### Changes
- fix: add hardened runtime entitlements for external tool execution (86c731c)

[0.3.6]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.6

## [0.3.7] - 2026-04-07

### Changes
- Fix Help Book and file replacement permission errors (#2) (a5e0732)
- fix: make file detail sheet scrollable for files with many streams (c5d2e59)

[0.3.7]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.7

## [0.3.8] - 2026-04-07

### Changes
- Fix Help Viewer, DMG icon, and implement update checker (#3) (50e4efa)

[0.3.8]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.8

## [0.3.9] - 2026-04-07

### Changes
- Fix app icon not showing in built app (#4) (1da319e)

[0.3.9]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.9

## [0.3.10] - 2026-04-07

### Changes
- Fix: create Resources dir before copying AppIcon.icns (#6) (5a2e64b)
- Fix app icon by injecting .icns into bundle (#5) (34349d5)

[0.3.10]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.10

## [0.3.11] - 2026-04-07

### Changes
- Fix Jellyfin profile picker not selectable (#7) (8b8b063)

[0.3.11]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.11

## [0.3.12] - 2026-04-07

### Changes
- Concurrent file analysis for faster scanning (#8) (c11597d)

[0.3.12]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.12

## [0.3.13] - 2026-04-07

### Changes
- Use VideoToolbox hardware encoding for transcoding (#9) (8c1cf8a)

[0.3.13]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.13

## [0.3.14] - 2026-04-07

### Changes
- Faster ffprobe analysis and in-place app updates (#10) (b85867c)

[0.3.14]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.14

## [0.3.15] - 2026-04-07

### Changes
- Retry ffprobe on transient network share failures (#11) (4b11586)

[0.3.15]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.15

## [0.3.16] - 2026-04-07

### Changes
- Add pipeline mode: scan and process without review (#12) (f0f6cf9)

[0.3.16]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.16

## [0.3.17] - 2026-04-07

### Changes
- Scale ffprobe timeout for large MP4s on network shares (#13) (0d67024)

[0.3.17]: https://github.com/Shifting83/Chaotic-Jelly/releases/tag/v0.3.17
