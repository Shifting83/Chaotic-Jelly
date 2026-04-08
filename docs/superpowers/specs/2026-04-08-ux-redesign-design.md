# Chaotic Jelly — UX Redesign Spec

**Date:** 2026-04-08
**Approach:** Connected Workflow (Approach B)
**Mood:** Clean & Professional

## Overview

Holistic UX redesign covering navigation, all major screens, onboarding, and a unified visual design system. The goal is to make Chaotic Jelly feel cohesive, polished, and professionally built while keeping every screen functional and power-user friendly.

## 1. Sidebar Navigation

**Current:** Flat list of 6 items (Dashboard, New Scan, Review, Queue, History, Logs).

**Redesign:** Grouped sidebar with section headers.

- **Dashboard** sits at the top, ungrouped — the home screen
- **Workflow** section header, containing:
  - New Scan
  - Review — with a badge showing pending file count (e.g., "24")
  - Processing (renamed from "Queue") — with a progress badge (e.g., "3/24")
- **Reference** section header, containing:
  - History
  - Logs
- **Settings removed from sidebar** — accessed via ⌘, (standard macOS pattern)

Sidebar items under section headers are slightly indented. Section headers use 11px uppercase semibold text in secondary color. Badges use pill-shaped indicators: blue for pending counts, green for progress.

## 2. Dashboard

**Current:** 3 stat cards (Space Saved, Files Processed, Cache Usage) + Tool Status GroupBox + Recent Jobs list.

**Redesign:** Hybrid hub — status overview, primary action, and live job progress.

### Layout (top to bottom):

**Top row:**
- **New Scan card** (left, flex: 1) — prominent primary action with icon, title, and subtitle. Clickable, navigates to Scan screen.
- **Space Saved card** (center) — lifetime total with trend indicator (e.g., "↑ 2.1 GB this week") in green
- **Files Processed card** (right) — lifetime total with job count subtitle

**Active Job panel** (appears only when a job is running):
- Green pulsing dot + job folder path + elapsed time
- Animated progress bar with blue gradient and shimmer effect
- Stats row: progress count, current filename, space saved (green), ETA

**Recent Jobs list:**
- Last 3-5 completed jobs
- Each row: folder path, file count + savings + duration, relative date, status badge
- Status badges: green "Completed", red "X Failed"

**When no job is active:** The Active Job panel disappears, Recent Jobs moves up.

**Tool Status** moves to Settings (Tools pane) and the first-run wizard. No longer on Dashboard.

## 3. Workflow Stepper

A persistent breadcrumb bar at the top of Scan, Review, and Processing screens showing the current position in the Scan → Review → Processing flow.

### Visual design:
- Horizontal bar with 3 steps connected by lines
- **Completed steps:** Green circle with checkmark + green label + summary stat (e.g., "86 files found")
- **Active step:** Blue circle with step number or icon + blue bold label + contextual count
- **Pending steps:** Gray circle with number + gray label
- **Connectors:** 2px lines that fill with color (green for completed, gradient for transitioning)

### Behavior:
- Only appears on workflow screens (Scan, Review, Processing) — not Dashboard, History, or Logs
- Completed steps are clickable — navigate back to see results
- Disappears when no active job exists
- Summary stats update as each stage completes

## 4. Review Screen

**Current:** Summary bar with counts + toolbar + file list with modal detail sheet.

**Redesign:** Scannable rows with inline expand-to-reveal detail.

### Layout (top to bottom):

**Summary bar:**
- Left: count pills — Total (bold), To Process (blue), Skipped (gray), Warnings (orange)
- Right: estimated savings in green + "Start Processing" button (always visible, no scrolling to find it)

**Filter toolbar:**
- Search field + filter pills: All, To Process, Warnings, Skipped
- Consistent with History and Logs filter pattern

**File list** (white card with rounded corners):

**Collapsed row:**
- Disclosure triangle (▶) + status dot (blue=to process, orange=warning, gray=skipped) + filename + one-line action summary (e.g., "Remove 3 subtitle tracks, 1 audio track") + estimated savings in green + file size

**Expanded row:**
- Disclosure triangle (▼) + same header with light gray background
- Detail panel below with two-column grid:
  - **Removing** column: red ✕ for each track being removed, showing type, language, codec, channel info
  - **Keeping** column: green ✓ for each track being kept, same detail level

**Warning rows:** Orange ⚠ icon with inline explanation text (e.g., "Ambiguous language tag on 2 tracks — conservative mode kept them").

**Skipped rows:** Dimmed (opacity ~0.5) with gray ○ icon and explanation (e.g., "English only — nothing to remove"). Present but don't compete for attention.

The modal detail sheet is eliminated — inline expansion is faster for scanning multiple files.

## 5. Processing Screen

**Current:** Active job header with progress bar + sectioned file list (processing, queued, completed, failed).

**Redesign:** Lively feedback with animations and real-time counters.

### Layout (top to bottom):

**Hero stats panel** (white card):
- Top: glowing blue dot (pulsing animation) + job folder path + Cancel button (red outline, understated)
- Progress bar: 12px height, blue gradient fill with shimmer animation overlay
- 4 big counters in a grid: Progress (15/24), Space Saved (1.8 GB, green), Elapsed (12:34), Remaining (~8 min)
- All counters use tabular-nums for smooth ticking without layout jumps

**Current file card:**
- Spinning circle indicator + filename + size transformation (e.g., "14.6 GB → ~13.5 GB")
- Per-file mini progress bar (4px height)
- Subtitle: action description + tool being used (e.g., "Removing 5 subtitle tracks via mkvmerge")

**File feed** (reverse-chronological activity stream):
- Header with inline counts: "✓ 14 done · ○ 9 queued · ✕ 1 error"
- **Completed files:** Green ✓ + filename + savings in green + duration
- **Error files:** Red ✕ + filename + error type, with pink background (#fff5f5) and inline error detail below
- **Queued files:** Gray ○ + filename + file size, dimmed (opacity ~0.4)

### Animations:
- Glowing blue dot: alternating opacity 1.0 ↔ 0.4 on 1.5s cycle
- Progress bar shimmer: translucent white gradient sweeping left to right on 2s cycle
- Current file spinner: rotating circle border on 1s linear cycle
- Space saved counter: ticks up as each file completes (the most satisfying metric)

## 6. Settings Window

**Current:** Tab view with 7 tabs in a 600x450 fixed window.

**Redesign:** macOS-standard preferences window with toolbar icon strip.

### Structure:
- Standard macOS window with traffic lights and "Chaotic Jelly Settings" title
- Toolbar icon strip with 7 panes:
  1. 🌐 Language — primary language, additional languages, conservative mode, subtitle/audio removal toggles
  2. ⚙️ Processing — concurrency, backup settings, overwrite behavior
  3. 📺 Jellyfin — direct-play profiles, codec settings
  4. 🔧 Tools — FFmpeg/FFprobe/MKVmerge paths, version info, status
  5. 💾 Cache — cache location, size limits, cleanup
  6. 📡 Arr — Sonarr/Radarr instance management (consolidated from separate tabs)
  7. 🔄 Updates — Sparkle settings, GitHub token

### Pane design:
- **40px horizontal padding**, 28px between sections — generous breathing room
- **Section headers:** 14px semibold
- **Grouped controls** in white cards with 1px border, 8px radius
- **Each setting** has a title (13px medium) + description subtitle (12px secondary color)
- **Native macOS toggles** instead of checkboxes
- **Window resizes per pane** — each pane determines its own natural height

### Access:
- Opened via ⌘, (standard macOS keyboard shortcut)
- Removed from sidebar navigation
- Implemented as a separate SwiftUI Window (not a sheet)

## 7. First-Run Wizard

**Current:** No onboarding. Blank Dashboard on first launch.

**Redesign:** 3-step wizard presented as a sheet on the main window.

### Step 1 — Tool Detection:
- Title: "Let's get set up"
- Subtitle: "Chaotic Jelly needs a few tools to process your video files."
- Auto-discovers tools and shows status:
  - Found tools: green ✓ + tool name + detected path + "Found" label
  - Missing required tools: red ✕ with install guidance
  - Missing optional tools (MKVToolNix): orange ⚠ + "Locate..." button
- Continue button

### Step 2 — Language Preferences:
- Title: "Which languages do you want to keep?"
- Subtitle: "Chaotic Jelly will remove subtitle and audio tracks in other languages."
- Primary language dropdown (default: English)
- Checkboxes: Remove subtitle tracks, Remove audio tracks (both checked by default)
- Conservative mode toggle (on by default)
- Back + Continue buttons

### Step 3 — Ready to Go:
- Title: "You're all set"
- Summary card confirming: Tools found, Language, Removing types, Mode
- Two exit buttons: "Go to Dashboard" (secondary) + "Start First Scan →" (primary CTA)

### Behavior:
- Thin progress bars at top (not numbered circles) — 3 segments, colored green/blue/gray
- Sheet presentation — cannot be dismissed without completing
- All settings configured here are editable later in Settings (⌘,)
- Only shows on first launch (track with UserDefaults flag)

## 8. History Screen

**Current:** Header with stat cards + search/filter + job list with context menus.

**Redesign:** Consistent with Review screen patterns.

### Layout:

**Summary stats row:** 3 compact cards — Total Jobs, Total Saved, Files Processed.

**Filter toolbar:** Search + pills: All, Completed, Failed, Cancelled. Same pattern as Review and Logs.

**Job list** with expandable rows:
- **Collapsed:** Disclosure triangle + status dot (green=completed, red=failed) + folder path + "42 files · Subtitles + Audio · 45 min" + savings in green + relative date
- **Expanded:** Completed/failed file counts + preview of individual files with savings/errors + "Show all X files →" link
- Context menu actions retained: retry failed files, delete job

## 9. Empty States

Contextual empty states for every screen when there's no data.

### Pattern:
- Centered vertically in the content area
- Large semi-transparent icon (40px, 0.6 opacity)
- Heading (16px semibold)
- One-line explanation (13px secondary color)
- Optional action button

### Per screen:
- **Dashboard:** 📁 "No scans yet" / "Scan a folder to find video files to clean up" / [New Scan] button (primary)
- **Review:** 🔍 "Nothing to review" / "Run a scan to analyze files before processing" / [Go to New Scan] button (secondary)
- **Processing:** ⚡ "No active jobs" / "Start processing from the Review screen" / (no button)
- **History:** 📋 "No history yet" / "Completed jobs will appear here" / (no button)
- **Logs:** 📝 "No logs yet" / "Logs will appear when you start processing" / (no button)

## 10. Logs Screen

**Current:** Toolbar with search/filter/export + monospaced log entries with color-coded severity.

**Redesign:** Dark terminal panel inside the light app.

### Toolbar:
- Search field + filter pills: All, Info, Warning, Error (warning/error pills use semantic colors in their text)
- Diagnostics checkbox
- Export + Clear buttons

### Log panel:
- Dark background (#1E1E1E) with 10px radius — visually distinct terminal area
- Monospaced font (SF Mono / Menlo, 11.5px, line-height 1.7)
- Three-column layout: timestamp (gray #666), level (colored), message (colored to match level)
- Level colors: INFO=#4EC9B0 (teal), WARN=#DCDCAA (yellow), ERROR=#F44747 (red)
- Auto-scrolls to bottom, text selectable

## 11. Visual Design System

Consistent design tokens used across every screen.

### Semantic Colors:
| Token | Value | Usage |
|-------|-------|-------|
| Primary | #007AFF | Buttons, active states, links, selected items |
| Success | #34C759 | Completed status, savings, kept tracks |
| Warning | #FF9500 | Ambiguous states, warnings |
| Error | #C62828 | Failures, removed tracks, errors |
| Text Primary | #1D1D1F | Headings, filenames, primary content |
| Text Secondary | #86868B | Descriptions, timestamps, metadata |

### Surfaces:
| Token | Value | Usage |
|-------|-------|-------|
| Background | #F5F5F7 | Page background |
| Card | #FFFFFF | Content cards, list containers |
| Expanded Row | #F8F9FA | Active/expanded row background |
| Border | #E0E0E0 | Card borders, separators |
| Row Divider | #F0F0F0 | Between list rows |
| Log Terminal | #1E1E1E | Logs dark panel |

### Spacing:
| Token | Value |
|-------|-------|
| Page padding | 24px |
| Card padding | 16–20px |
| Section gap | 16px |
| Row padding (vertical) | 12–14px |
| Settings padding (horizontal) | 40px |

### Corner Radii:
| Token | Value |
|-------|-------|
| Card | 10px |
| Button | 6px |
| Badge/pill | 4px |
| Toggle | 12px |
| Progress bar | 6px (large), 3px (small) |

### Typography Scale (SF Pro):
| Role | Size | Weight | Color |
|------|------|--------|-------|
| Hero counter | 22px | Bold | Primary, tabular-nums |
| Page title | 15px | Semibold | Primary |
| Section header | 14px | Semibold | Primary |
| Body / row text | 13px | Regular | Primary |
| Secondary text | 12px | Regular | Secondary |
| Section label | 11px | Semibold | Secondary, uppercase, 0.5px tracking |
| Log text | 11.5px | Regular | SF Mono, varies by level |

### Interaction Patterns:
- **Filter pills:** Consistent across Review, History, and Logs. Active pill: blue background, white text. Inactive: white background, gray border.
- **Expandable rows:** Disclosure triangle (▶/▼) + click to expand inline detail. Used in Review, History.
- **Status dots:** Blue (to process), green (completed/success), orange (warning), red (failed/error), gray (skipped/pending).
- **Badges:** Pill-shaped, colored background with white text in sidebar. Flat colored text in status positions.
- **Action buttons:** Primary: #007AFF fill, white text, 6px radius. Secondary: white fill, gray border, colored text. Destructive: red outline.

### SwiftUI Implementation Notes:
- Extract colors into a `Color` extension (e.g., `Color.cjPrimary`, `Color.cjSuccess`)
- Extract typography into `Font` extension (e.g., `Font.cjHeroCounter`, `Font.cjSectionLabel`)
- Create reusable view modifiers: `.cjCard()`, `.cjExpandableRow()`, `.cjFilterPill()`
- Create shared components: `FilterToolbar`, `ExpandableRow`, `StatusDot`, `EmptyStateView`, `WorkflowStepper`
- Settings window: use `Window` scene with `id: "settings"` and `defaultSize` per-pane via `onChange`
