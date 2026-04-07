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
