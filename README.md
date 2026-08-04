# Tofu Routine — EWU Course Planner

A university course planner for EWU students. Import your advising slip, build your weekly routine, track friends' classes, and export your schedule as PNG or PDF.

---

## Features

| Feature | Detail |
|---|---|
| 📄 Import advising slip | Upload your EWU `.xlsx` advising slip and auto-generate the weekly routine |
| 👥 Friend slips | Import a friend's slip to merge their classes into your routine |
| ✏️ Manual editing | Add or remove time slots, classes, and friends on individual cells |
| 🗑️ Remove options | Remove a time slot, a day, a course (everywhere), or clear all data |
| 💾 Auto-save | Routine is saved automatically and restored on launch |
| 📅 Fit-to-screen grid | The whole weekly calendar is visible on a phone — no scrolling needed |
| 🖱️ Tap for details | Tap any cell for the full course, room, and friend breakdown |
| 🎨 Color coding | Every course gets a stable color; a lecture and its lab share a color |
| 📱 Sidebar menu | Hamburger button opens a sidebar with Weekly/Monthly calendar, imports, and Exit |
| 🖼️ Export | Save your routine as a PNG image or PDF document |

---

## Requirements

- **Flutter 3.35+ / Dart 3.x** — https://docs.flutter.dev/get-started/install
- **Android, iOS, Windows, macOS, or Linux** device or emulator

---

## Setup

Open a terminal in this folder and run:

```
flutter pub get
```

## Run

```
flutter run
```

Select a connected device to launch the app.

---

## Build

**Android APK:**
```
flutter build apk --release
```

**Windows:**
```
flutter build windows --release
```

**Other platforms:**
```
flutter build ios --release      # macOS only
flutter build macos --release    # macOS only
flutter build linux --release    # Linux only
```

---

## How to Use

1. **Launch** — run the app. The weekly calendar appears with the days of the week and your time slots.

2. **Add your schedule** — tap the blue **+** button → **Advising Slip**, then pick your EWU advising slip `.xlsx` file. Only days with classes are shown.

3. **Add a friend** — tap the blue **+** button → **Friend Slip** and pick your friend's `.xlsx` file. Their classes appear in each cell's **Friends** section.

4. **See full details** — tap any cell to open a dialog with the course, section, room, day/time, and each friend's class.

5. **Remove data** — tap the red **−** button and choose a time slot, day, course, or everything.

6. **Export** — tap the green **↓** button → **Save as PNG** or **Save as PDF**.

7. **Sidebar** — tap the hamburger icon (top-left) for **Weekly Calendar**, **Monthly Calendar**, **Import to Calendar**, **Import to Google Calendar** (coming soon), and **Exit**.

---

## File Structure

```
📁 project folder
├── lib/
│   ├── main.dart           ← app entry, logic, dialogs, FABs, sidebar
│   ├── calendar_view.dart  ← calendar grid and header UI
│   └── planner_core.dart   ← shared state, palette, layout constants, models
├── assets/icon.png         ← app icon and splash screen
├── pubspec.yaml            ← dependencies and app config
└── README.md               ← this file
```

---

## Notes

- The grid auto-sizes so the whole week fits on screen; it only scrolls on very small screens.
- Day labels use 3-letter abbreviations (Sun, Mon, Tue, …).
- Courses are color-coded consistently, so the same course always has the same color.
- Your routine is saved automatically and stored compressed via `SharedPreferences`.
- Monthly view and calendar imports are planned — the sidebar items show a "coming soon" notice for now.
