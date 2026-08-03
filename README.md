# Tofu Routine

A university course planner for EWU students with friend class management. Import advising slips, build your schedule, add friends' classes, and export as PNG or PDF.

## Features

- **Import EWU Advising Slip** — Upload your `.xlsx` advising slip and auto-generate your routine table
- **Import Friend's Slip** — Add a friend's advising slip to merge their schedule into your existing routine
- **Manual Editing** — Add/remove time slots, add classes and friends to individual cells
- **Remove Options** — Remove individual time slots, days, courses (across all slots), or clear all data
- **Export** — Save your routine as PNG image or PDF document
- **Sidebar Menu** — The hamburger button in the header opens a left sidebar with **Weekly Calendar**, **Monthly Calendar**, **Import to Calendar**, **Import to Google Calendar**, and **Exit**
- **Persistence** — Your routine data is saved automatically with `SharedPreferences` (zlib-compressed JSON)
- **Responsive Grid** — The whole weekly calendar fits on screen; scrolling is only a fallback on very small screens
- **Accessibility** — Every calendar slot carries a screen-reader label describing its course, room, and friends

## UI & Design

- **Palette** — Deep-navy "planner" theme: `#16213A → #0A0F1C` background gradient, navy header gradient, light-blue `#A9E6F5` accent + warm gold `#F4E04D`
- **Theming** — The brand palette is promoted into a full Material 3 `ColorScheme`; every widget pulls its colors from `Theme.of(context)` instead of hardcoding literals
- **Typography** — JetBrains Mono monospace throughout, Material 3 dark theme
- **Header** — App bar with a compact hamburger menu button, app title, and "EWU COURSE PLANNER" tagline
- **Sidebar** — A rounded left drawer with the app branding and the navigation items listed above; each item closes the drawer before running its action
- **Calendar grid** — Days as rows (3-letter labels: Sun/Mon/Tue/…), time slots as columns. Row heights and column widths are computed from the available space so the entire grid is visible at once.
- **Compact cells** — Each cell shows the base course code (e.g. `PHY109`), room number, and a gold friend-count pill. Tap any cell to open a dialog with the full details (course + section, room, day/time, and each friend's course/room).
- **Color coding** — Every course gets a stable color from the palette; a lecture and its lab share the same color.
- **Empty state** — When the routine is empty, a friendly screen offers **Import Advising Slip** and **Add Time Slot** actions.
- **FABs** — Red **−** (remove), blue **+** (add), green **↓** (save/export), each opening a centered popup menu.
- **Text scaling** — OS text scaling is respected but clamped so the adaptive grid never overflows.

## Quick Start

```bash
flutter pub get
flutter run
```

Select a connected device (Android / iOS / Windows / macOS / Linux) to launch the app.

## Usage

### Sidebar Navigation

Tap the hamburger icon (top-left) to open the sidebar:

| Item | Action |
|------|--------|
| **Weekly Calendar** | Show the weekly grid (current view) |
| **Monthly Calendar** | Monthly view *(coming soon)* |
| **Import to Calendar** | Import routine into a calendar *(coming soon)* |
| **Import to Google Calendar** | Import routine into Google Calendar *(coming soon)* |
| **Exit** | Close the app |

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
- **PDF Generation:** `pdf`
- **File Handling:** `file_picker` + `path_provider`
- **Permissions:** `permission_handler`

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
