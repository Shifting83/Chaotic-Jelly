# Bundled Tools

Chaotic Jelly bundles FFmpeg, FFprobe, and MKVToolNix binaries for macOS.

## Required Binaries

Place the following binaries in this directory before building:

- `ffmpeg` — video processing
- `ffprobe` — media analysis
- `mkvmerge` — MKV-specific stream operations

## Obtaining Binaries

### FFmpeg + FFprobe

Download static builds from https://evermeet.cx/ffmpeg/ (macOS arm64/x86_64)
or build from source.

### MKVToolNix

Download from https://mkvtoolnix.download/downloads.html#macosx
or install via Homebrew: `brew install mkvtoolnix`

## External Override

Users can configure external binary paths in Settings → Tools to use
system-installed versions instead of bundled ones (e.g., Homebrew installs).

## Build Integration

The Xcode build phase copies binaries from this directory into the app bundle
at `Contents/MacOS/Tools/`. The `ToolLocator` service resolves paths at runtime,
checking bundled location first, then user-configured paths, then PATH.
