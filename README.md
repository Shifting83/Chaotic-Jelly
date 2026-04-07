# Chaotic Jelly

A macOS desktop app for managing video files on local disks and network shares. Scans folders, detects non-English subtitle and audio tracks, removes them, and optionally optimizes files for Jellyfin direct play.

## Features

- Recursive folder scanning for video files (MKV, MP4, M4V, AVI, MOV, TS, M2TS)
- FFprobe-based media analysis with language detection
- Non-English subtitle and audio track removal
- Network-share-safe processing (copy-local, process, validate, replace)
- MKVToolNix integration for safer MKV stream operations
- Job history with space savings tracking (SwiftData/SQLite)
- Dry-run preview mode
- Structured logging with export
- Conservative mode for ambiguous language tags
- Crash-safe job recovery

## Requirements

- macOS 14 (Sonoma) or later
- FFmpeg and FFprobe (bundled or installed via Homebrew)
- MKVToolNix (optional, for MKV-specific operations)

## Building

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Generate the Xcode project:
   ```bash
   cd ChaoticJelly
   xcodegen generate
   ```
3. Open `ChaoticJelly.xcodeproj` in Xcode
4. Build and run

## Project Structure

```
ChaoticJelly/
├── Sources/
│   ├── App/             — App entry point, service container
│   ├── Models/          — SwiftData models, value types, enums
│   ├── Services/        — Core business logic
│   ├── ViewModels/      — @Observable view models
│   ├── Views/           — SwiftUI views
│   └── Utilities/       — Language utils, extensions, constants
├── Tests/               — Unit tests
├── Resources/           — Info.plist, entitlements, assets
├── Tools/               — Bundled binary location
└── project.yml          — XcodeGen project definition
```

## Architecture

- **MVVM** with `@Observable` view models
- **SwiftData** for job/file persistence
- **Actor-based** services for thread safety
- **Process-based** FFmpeg/FFprobe/MKVToolNix execution
- Non-sandboxed with hardened runtime

See [DECISIONS.md](DECISIONS.md) for architecture decision records.

## License

Private repository. All rights reserved.
