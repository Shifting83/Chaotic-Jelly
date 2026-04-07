# Chaotic Jelly — Architecture Decisions

## ADR-001: macOS 14 (Sonoma) Minimum Target
**Date:** 2026-04-07
**Status:** Accepted

**Context:** Need to choose minimum macOS version. SwiftData and `@Observable` macro require macOS 14+.

**Decision:** Target macOS 14 Sonoma as minimum.

**Rationale:** SwiftData eliminates significant SQLite boilerplate. `@Observable` is cleaner than Combine for SwiftUI integration. Home-lab users typically keep macOS reasonably current.

**Trade-offs:** Excludes macOS 13 users. Acceptable for target audience.

---

## ADR-002: SwiftData over Raw SQLite
**Date:** 2026-04-07
**Status:** Accepted

**Context:** Need persistent storage for jobs, file entries, and history.

**Decision:** Use SwiftData (backed by SQLite) instead of raw SQLite or GRDB.

**Rationale:** Native SwiftUI integration, automatic schema management, less boilerplate. Still backed by SQLite for reliability.

**Trade-offs:** Newer framework, potentially less battle-tested. Migration path exists if needed.

---

## ADR-003: Bundle FFmpeg/FFprobe/MKVToolNix in App
**Date:** 2026-04-07
**Status:** Accepted

**Context:** Users need FFmpeg, FFprobe, and optionally MKVToolNix to process files.

**Decision:** Bundle static binaries in the app bundle. Allow user override via Settings to use external (e.g., Homebrew) installations.

**Rationale:** Eliminates "works on my machine" issues. Users who want a specific version can override. ToolLocator resolves: user path → bundled → Homebrew → PATH.

**Trade-offs:** Increases app size (~80MB for FFmpeg static builds). Binary licensing requires attention (FFmpeg is LGPL/GPL depending on build flags).

---

## ADR-004: Non-Sandboxed App with Hardened Runtime
**Date:** 2026-04-07
**Status:** Accepted

**Context:** App needs to access arbitrary file paths (including network shares), execute external binaries (ffmpeg), and access Keychain.

**Decision:** Ship as non-sandboxed app with hardened runtime enabled.

**Rationale:** Sandboxing would require Security-Scoped Bookmarks for every folder access and would complicate Process execution. Hardened runtime still provides security benefits. Most media management apps (HandBrake, MakeMKV) are non-sandboxed.

**Trade-offs:** Cannot distribute via Mac App Store. Fine for GitHub-hosted distribution.

---

## ADR-005: MKVToolNix for MKV Stream Removal
**Date:** 2026-04-07
**Status:** Accepted

**Context:** Need to remove streams from MKV files safely.

**Decision:** Prefer mkvmerge over ffmpeg for pure stream removal from MKV files. Fall back to ffmpeg when mkvmerge is unavailable or when transcoding is needed.

**Rationale:** mkvmerge is purpose-built for MKV manipulation, preserves all MKV-specific metadata (chapters, attachments, tags), and handles MKV quirks better than ffmpeg's matroska muxer.

**Trade-offs:** Additional binary dependency. Made optional — ffmpeg works as fallback.

---

## ADR-006: Actor-Based Concurrency
**Date:** 2026-04-07
**Status:** Accepted

**Context:** Services handle file I/O, process execution, and shared state. Need thread safety.

**Decision:** Use Swift actors for services that manage mutable state (ProcessRunner, FFprobeService, CacheManager, etc.). Use `@Observable` for ViewModels on MainActor.

**Rationale:** Actors provide compile-time thread safety. Aligns with modern Swift concurrency model.

---

## ADR-007: Copy-Local Processing Model
**Date:** 2026-04-07
**Status:** Accepted

**Context:** Files may live on network shares (SMB/NFS) which are unreliable for in-place processing.

**Decision:** Always copy source file to local cache before processing. Process locally. Validate output. Atomically replace original.

**Rationale:** Network shares can disconnect mid-write, have high latency, and don't support atomic operations. Local processing is faster and safer.

**Trade-offs:** Requires 2x file size in local cache space. Acceptable for reliability.

---

## ADR-008: MVVM without TCA
**Date:** 2026-04-07
**Status:** Accepted

**Context:** Need an app architecture pattern.

**Decision:** Simple MVVM with `@Observable` ViewModels and service injection via ServiceContainer. No TCA.

**Rationale:** TCA adds significant complexity (reducers, effects, stores) that isn't justified for this app's scale. Simple MVVM with `@Observable` is idiomatic SwiftUI and easier to maintain.

---

## ADR-009: XcodeGen for Project Generation
**Date:** 2026-04-07
**Status:** Accepted

**Context:** Need a reproducible Xcode project. Hand-maintaining pbxproj is error-prone.

**Decision:** Use XcodeGen with project.yml to generate the .xcodeproj.

**Rationale:** project.yml is human-readable, merge-friendly, and the generated xcodeproj is always consistent. Standard practice for non-trivial Swift projects.

---

## ADR-010: Sparkle 2.x for Updates (Phase 3)
**Date:** 2026-04-07
**Status:** Planned

**Context:** Need auto-update from private GitHub repo.

**Decision:** Use Sparkle 2.x with EdDSA signing. Custom SUUpdaterDelegate for authenticated appcast/download from private GitHub releases.

**Rationale:** Sparkle is the de facto standard for macOS app updates. EdDSA signing prevents supply-chain attacks. Private repo support via auth headers.
