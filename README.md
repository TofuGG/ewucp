# Tofu Routine

A university course planner for EWU students with friend class management. Import advising slips, build your schedule, add friends' classes, and export as PNG or PDF.

## Features

- **Import EWU Advising Slip** — Upload your `.xlsx` advising slip and auto-generate your routine table
- **Import Friend's Slip** — Add a friend's advising slip to merge their schedule into your existing routine
- **Manual Editing** — Add/remove time slots, add classes and friends to individual cells
- **Remove Options** — Remove individual time slots, days, courses (across all slots), or clear all data
- **Export** — Save your routine as PNG image or PDF document
- **Persistence** — Your routine data is saved automatically with `SharedPreferences`
- **Responsive Layout** — Adapts to window size via `LayoutBuilder`

## Quick Start

```bash
flutter pub get
flutter run
```

Select a connected device (Android / iOS / Windows / macOS / Linux) to launch the app.

## Usage

### Adding Your Schedule

1. Tap the **+** button → **Advising Slip**
2. Select your EWU advising slip `.xlsx` file
3. The routine is generated automatically — only days with course data are shown

### Adding a Friend

1. Tap the **+** button → **Friend Slip**
2. Select your friend's `.xlsx` file
3. The friend's name is extracted automatically and their classes appear under each cell's **Friends** section

### Removing Data

Tap the **-** button to choose:

| Option | Action |
|--------|--------|
| **Time Slot** | Remove a time column from the table |
| **Day** | Remove a day row and all its cell data |
| **Course** | Select a course name to clear it from every cell |
| **All** | Clear all data and reset days |

### Exporting

Tap the **↓** button → **Save as PNG** or **Save as PDF**.

## Data Format

### EWU Advising Slip Columns

| Field | Column | Index |
|-------|--------|-------|
| Course Name | C | 2 |
| Section | Q | 16 |
| Time + Day | BA | 52 |
| Room | BM | 64 |

### Day Codes

| Code | Day |
|------|-----|
| S | Sunday |
| M | Monday |
| T | Tuesday |
| W | Wednesday |
| R | Thursday |

## Tech Stack

- **Framework:** Flutter 3.35+
- **Language:** Dart 3.x
- **Storage:** `shared_preferences`
- **Excel Parsing:** `spreadsheet_decoder`
- **PDF Generation:** `pdf` + `printing`
- **File Handling:** `file_picker` + `path_provider`

## Building

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

## License

MIT
