# Chaotic Jelly — Task Tracker

## Phase 1 — Foundation (MVP) [IN PROGRESS]

### Completed
- [x] Project scaffold (Xcode project structure, XcodeGen config)
- [x] SwiftData models (Job, FileEntry)
- [x] Value types (MediaInfo, StreamInfo, PlannedAction, Enums)
- [x] AppSettings with UserDefaults persistence
- [x] ProcessRunner — actor-based Process wrapper
- [x] ToolLocator — bundled/external/PATH tool resolution
- [x] FFprobeService — probe + JSON parsing
- [x] FFmpegService — stream removal, remux, transcode argument builder
- [x] MKVToolNixService — MKV-specific stream operations
- [x] ScanService — recursive directory walker
- [x] AnalysisEngine — language classification + action planning
- [x] ValidationService — post-process output validation
- [x] CacheManager — local cache with space management
- [x] ProcessingPipeline — full file processing orchestration
- [x] JobManager — job lifecycle, persistence, recovery
- [x] LoggingService — OSLog + file-based structured logging
- [x] KeychainService — secure token storage
- [x] LanguageUtils — ISO 639 code recognition
- [x] All ViewModels (Dashboard, Scan, Review, Queue, History, Logs)
- [x] All Views (ContentView, Dashboard, Scan, Review, Queue, History, Settings, Logs)
- [x] Unit tests (FFprobe parsing, AnalysisEngine, Job state, LanguageUtils)
- [x] Test fixtures (sample ffprobe JSON)

### Remaining for MVP
- [ ] Wire up `@Bindable` for AppSettings in SettingsView (may need protocol conformance adjustment)
- [ ] Add app icon assets
- [ ] Test on macOS with real video files
- [ ] Bundle FFmpeg/FFprobe/MKVToolNix binaries
- [ ] Add first-run tool check dialog
- [ ] Fix any SwiftUI preview issues
- [ ] Performance testing with large libraries (1000+ files)

## Phase 2 — Jellyfin Optimization
- [ ] Jellyfin direct-play profile engine
- [ ] Codec compatibility detection
- [ ] Remux vs transcode decision logic
- [ ] Transcode progress parsing from ffmpeg stderr
- [ ] Jellyfin profile presets UI
- [ ] Container format conversion (e.g., AVI → MKV)

## Phase 3 — Polish & Distribution
- [ ] Sparkle 2.x integration
- [ ] GitHub appcast hosting
- [ ] Authenticated update downloads (private repo)
- [ ] GitHub Actions CI/CD workflow (build, sign, notarize, DMG, release)
- [ ] macOS notifications (UserNotifications)
- [ ] Watch folder support (FSEvents)
- [ ] Backup retention management
- [ ] Import/export settings
- [ ] LLM-assisted language classification (optional)
- [ ] App icon design
- [ ] Accessibility audit

## Phase 4 — Advanced Features
- [ ] Scheduled scans
- [ ] Duplicate file detection
- [ ] Batch presets
- [ ] Statistics dashboard with charts
- [ ] Dark mode refinements
- [ ] Keyboard shortcuts
- [ ] Drag-and-drop folder support
- [ ] Context menu Finder integration
