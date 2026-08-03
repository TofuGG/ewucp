import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'planner_core.dart';
import 'calendar_view.dart';

export 'planner_core.dart';

// =============================================================================
// App entry — Material 3 theme
//
// The brand palette from planner_core.dart is promoted into a full Material 3
// ColorScheme. Widgets are expected to pull every color from
// Theme.of(context).colorScheme instead of raw Colors.* literals so the whole
// app stays visually coherent and themable in one place.
// =============================================================================

void main() {
  runApp(const PlannerApp());
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: kAccent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: kAccent,
      onPrimary: kBgBottom,
      secondary: kAccentBlue,
      onSecondary: kBgBottom,
      surface: kCellBg,
      onSurface: const Color(0xFFF2F5FA),
      onSurfaceVariant: kTextMuted,
      surfaceContainerLowest: kBgBottom,
      surfaceContainerLow: kRowOdd,
      surfaceContainer: kRowEven,
      surfaceContainerHigh: kBgTop,
      surfaceContainerHighest: kHeaderTop,
      outline: kCellBorder,
      outlineVariant: kCellBorder,
      error: const Color(0xFFFF6B6B),
      onError: kBgBottom,
    );

    return MaterialApp(
      title: 'Tofu Routine',
      debugShowCheckedModeBanner: false,
      // Respect OS text scaling but clamp it so the adaptive grid never breaks
      // — tiny labels scale up while the whole calendar stays on screen.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.3,
        child: child!,
      ),
      home: const StartupScreen(),
      theme: _buildTheme(scheme),
    );
  }
}

ThemeData _buildTheme(ColorScheme scheme) {
  final TextTheme textTheme =
      ThemeData.dark().textTheme.apply(fontFamily: 'JetBrains Mono');

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    fontFamily: 'JetBrains Mono',
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    dividerColor: scheme.outlineVariant,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: scheme.onSurface,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 17,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface,
        fontSize: 13,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      contentTextStyle: textTheme.bodySmall?.copyWith(
        color: scheme.onSurface,
        fontSize: 12,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontSize: 12,
      ),
      hintStyle: textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        fontSize: 12,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: textTheme.labelLarge?.copyWith(
          fontFamily: 'JetBrains Mono',
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: textTheme.labelLarge?.copyWith(
          fontFamily: 'JetBrains Mono',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStateProperty.all(scheme.surfaceContainerHigh),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      textColor: scheme.onSurface,
      iconColor: scheme.onSurfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// ======= Startup / splash screen =======
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        // Fade transition so the splash hands off to the planner smoothly.
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => const RoutinePage(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            child: child,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: Stack(
        children: [
          // Pastel circle bleeding off the top-left corner
          Positioned(
            top: -70,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                color: kAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Pastel circle bleeding off the bottom-right corner
          Positioned(
            bottom: -80,
            right: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                color: kAccentBlue,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Centered logo + app name
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_toggle_off,
                  color: scheme.primary,
                  size: 56,
                ),
                const SizedBox(height: 18),
                Text(
                  'Tofu Routine',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    color: scheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ========================================

class RoutinePage extends StatefulWidget {
  const RoutinePage({super.key});

  @override
  State<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends State<RoutinePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey _routineKey = GlobalKey();

  final List<String> allTimes = const [
    '8:30am-10:00am',
    '10:10am-11:40am',
    '11:50am-1:20pm',
    '1:30pm-3:00pm',
    '3:10pm-4:40pm',
    '4:50pm-6:20pm',
    '4:50pm-6:50pm',
    '4:50pm-7:50pm',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _loadRoutineData();
  }

  // ---------------------------------------------------------------------------
  // Advising slip parser
  // ---------------------------------------------------------------------------

  Future<void> _applyAdvisingSlipFromFile(Uint8List bytes) async {
    try {
      const int colCourse = 2;
      const int colSection = 16;
      const int colTime = 52;
      const int colRoom = 64;

      final decoder = SpreadsheetDecoder.decodeBytes(bytes.toList());
      final tableName = decoder.tables.keys.first;
      final table = decoder.tables[tableName]!;
      final rows = table.rows;

      routine.clear();
      times.clear();
      days = [...kAllDays];

      // Find header row "Course(s)" in column C
      int dataStart = -1;
      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        final val = row.length > colCourse
            ? (row[colCourse]?.toString().trim() ?? '')
            : '';
        if (val == 'Course(s)') {
          dataStart = i + 1;
          break;
        }
      }
      if (dataStart == -1) {
        _showSnackBar('Could not find course data in the file.');
        return;
      }

      bool applied = false;
      String lastLabel = '';
      final pending = <_PendingSlot>[];

      for (int i = dataStart; i < rows.length; i++) {
        final row = rows[i];
        final courseRaw = row.length > colCourse
            ? (row[colCourse]?.toString().trim() ?? '')
            : '';
        final timeRaw = row.length > colTime
            ? (row[colTime]?.toString().trim() ?? '')
            : '';
        final roomRaw = row.length > colRoom
            ? (row[colRoom]?.toString().trim() ?? '')
            : '';
        final secRaw = row.length > colSection
            ? (row[colSection]?.toString().trim() ?? '')
            : '';

        final lower = courseRaw.toLowerCase();
        if (lower.contains('tuition fee') ||
            lower.contains('grand total') ||
            lower.contains('laboratory fee') ||
            lower.contains('student activity fee')) {
          break;
        }

        if (courseRaw.isNotEmpty) {
          lastLabel = secRaw.isNotEmpty ? '$courseRaw ($secRaw)' : courseRaw;

          // Process any rows that had time but no course yet (forward refs)
          for (final p in pending) {
            _applyTimeSlot(p.time, p.room, lastLabel);
            applied = true;
          }
          pending.clear();

          if (timeRaw.isNotEmpty) {
            _applyTimeSlot(timeRaw, roomRaw, lastLabel);
            applied = true;
          }
        } else if (timeRaw.isNotEmpty) {
          if (lastLabel.isNotEmpty) {
            _applyTimeSlot(timeRaw, roomRaw, lastLabel);
            applied = true;
          } else {
            pending.add(_PendingSlot(timeRaw, roomRaw));
          }
        }
      }

      // Flush any remaining pending rows
      if (lastLabel.isNotEmpty) {
        for (final p in pending) {
          _applyTimeSlot(p.time, p.room, lastLabel);
          applied = true;
        }
      }

      // Sort times chronologically by start time, then by end time
      int toMinutes(String t) {
        final m = RegExp(r'(\d+):(\d+)(AM|PM)').firstMatch(t);
        if (m == null) return 0;
        int h = int.parse(m[1]!), min = int.parse(m[2]!);
        if (m[3]! == 'PM' && h != 12) h += 12;
        if (m[3]! == 'AM' && h == 12) h = 0;
        return h * 60 + min;
      }
      times.sort((a, b) {
        final aStart = toMinutes(a.split('-')[0]);
        final bStart = toMinutes(b.split('-')[0]);
        final cmp = aStart.compareTo(bStart);
        return cmp != 0 ? cmp : toMinutes(a.split('-')[1]).compareTo(toMinutes(b.split('-')[1]));
      });

      // Remove empty days (no course data in any time slot)
      final keepIndices = <int>[];
      for (int i = 0; i < days.length; i++) {
        bool hasContent = false;
        for (final time in times) {
          final cells = routine[time];
          if (cells != null && i < cells.length && !cells[i].isEmpty) {
            hasContent = true;
            break;
          }
        }
        if (hasContent) keepIndices.add(i);
      }
      if (keepIndices.length < days.length) {
        days = keepIndices.map((i) => days[i]).toList();
        for (final time in times) {
          final cells = routine[time];
          if (cells != null) {
            routine[time] = keepIndices.map((i) => cells[i]).toList();
          }
        }
      }

      setState(() {});
      await _saveRoutineData();
      _showSnackBar(
        applied
            ? 'Advising slip applied successfully!'
            : 'No valid routine data found in the file.',
      );
    } catch (e) {
      debugPrint('_applyAdvisingSlipFromFile error: $e');
      _showSnackBar('Failed to apply advising slip: $e');
    }
  }

  void _applyTimeSlot(String timeRaw, String roomRaw, String courseLabel) {
    final spaceIdx = timeRaw.indexOf(' ');
    if (spaceIdx < 0) return;

    final weekdayPart = timeRaw.substring(0, spaceIdx);
    final timeRange = timeRaw.substring(spaceIdx + 1).replaceAll(' ', '');

    // Clean room: strip trailing parenthetical notes like "534 (C. Lab-4)" -> "534"
    String room = roomRaw;
    final parenIdx = room.indexOf(' (');
    if (parenIdx > 0) room = room.substring(0, parenIdx);

    if (!times.contains(timeRange)) {
      times.add(timeRange);
      routine[timeRange] = List.generate(days.length, (_) => RoutineCellData());
    }

    for (int i = 0; i < weekdayPart.length; i++) {
      final dayName = kDayMap[weekdayPart[i]];
      if (dayName == null) continue;
      final dayIndex = days.indexOf(dayName);
      if (dayIndex < 0) continue;

      routine[timeRange]![dayIndex] = routine[timeRange]![dayIndex].copyWith(
        course: courseLabel,
        room: room,
      );
    }
  }

  String _extractFriendName(List<List> rows) {
    const int nameRow = 13;
    const int nameCol = 9;
    if (nameRow >= rows.length) return '';
    final row = rows[nameRow];
    if (nameCol >= row.length) return '';
    final raw = row[nameCol]?.toString().trim() ?? '';
    final parts = raw.split(RegExp(r'\s+'));
    for (final part in parts) {
      final cleaned = part.replaceAll(RegExp(r'[.,;:!?]+$'), '');
      if (cleaned.length <= 3) continue;
      return cleaned;
    }
    return '';
  }

  void _ensureDayExists(String dayName) {
    if (days.contains(dayName)) return;
    final targetIndex = kAllDays.indexOf(dayName);
    if (targetIndex < 0) return;
    int insertAt = days.length;
    for (int i = 0; i < days.length; i++) {
      if (kAllDays.indexOf(days[i]) > targetIndex) {
        insertAt = i;
        break;
      }
    }
    days.insert(insertAt, dayName);
    for (final time in times) {
      routine[time]!.insert(insertAt, RoutineCellData());
    }
  }

  Future<void> _applyFriendSlipFromFile(Uint8List bytes) async {
    try {
      const int colCourse = 2;
      const int colSection = 16;
      const int colTime = 52;
      const int colRoom = 64;

      final decoder = SpreadsheetDecoder.decodeBytes(bytes.toList());
      final tableName = decoder.tables.keys.first;
      final table = decoder.tables[tableName]!;
      final rows = table.rows;

      final friendName = _extractFriendName(rows);
      if (friendName.isEmpty) {
        _showSnackBar('Could not find student name in the file.');
        return;
      }

      // Find header row "Course(s)" in column C
      int dataStart = -1;
      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        final val = row.length > colCourse
            ? (row[colCourse]?.toString().trim() ?? '')
            : '';
        if (val == 'Course(s)') {
          dataStart = i + 1;
          break;
        }
      }
      if (dataStart == -1) {
        _showSnackBar('Could not find course data in the file.');
        return;
      }

      bool added = false;
      String lastLabel = '';
      final pending = <_PendingSlot>[];

      for (int i = dataStart; i < rows.length; i++) {
        final row = rows[i];
        final courseRaw = row.length > colCourse
            ? (row[colCourse]?.toString().trim() ?? '')
            : '';
        final timeRaw = row.length > colTime
            ? (row[colTime]?.toString().trim() ?? '')
            : '';
        final roomRaw = row.length > colRoom
            ? (row[colRoom]?.toString().trim() ?? '')
            : '';
        final secRaw = row.length > colSection
            ? (row[colSection]?.toString().trim() ?? '')
            : '';

        final lower = courseRaw.toLowerCase();
        if (lower.contains('tuition fee') ||
            lower.contains('grand total') ||
            lower.contains('laboratory fee') ||
            lower.contains('student activity fee')) {
          break;
        }

        if (courseRaw.isNotEmpty) {
          lastLabel = secRaw.isNotEmpty ? '$courseRaw ($secRaw)' : courseRaw;

          for (final p in pending) {
            _applyFriendTimeSlot(p.time, p.room, lastLabel, friendName);
            added = true;
          }
          pending.clear();

          if (timeRaw.isNotEmpty) {
            _applyFriendTimeSlot(timeRaw, roomRaw, lastLabel, friendName);
            added = true;
          }
        } else if (timeRaw.isNotEmpty) {
          if (lastLabel.isNotEmpty) {
            _applyFriendTimeSlot(timeRaw, roomRaw, lastLabel, friendName);
            added = true;
          } else {
            pending.add(_PendingSlot(timeRaw, roomRaw));
          }
        }
      }

      if (lastLabel.isNotEmpty) {
        for (final p in pending) {
          _applyFriendTimeSlot(p.time, p.room, lastLabel, friendName);
          added = true;
        }
      }

      if (added) {
        // Sort times chronologically
        int toMinutes(String t) {
          final m = RegExp(r'(\d+):(\d+)(AM|PM)').firstMatch(t);
          if (m == null) return 0;
          int h = int.parse(m[1]!), min = int.parse(m[2]!);
          if (m[3]! == 'PM' && h != 12) h += 12;
          if (m[3]! == 'AM' && h == 12) h = 0;
          return h * 60 + min;
        }
        times.sort((a, b) {
          final aStart = toMinutes(a.split('-')[0]);
          final bStart = toMinutes(b.split('-')[0]);
          final cmp = aStart.compareTo(bStart);
          return cmp != 0 ? cmp : toMinutes(a.split('-')[1]).compareTo(toMinutes(b.split('-')[1]));
        });
      }

      setState(() {});
      await _saveRoutineData();
      _showSnackBar('Added $friendName\'s schedule successfully!');
    } catch (e) {
      debugPrint('_applyFriendSlipFromFile error: $e');
      _showSnackBar('Failed to apply friend slip: $e');
    }
  }

  void _applyFriendTimeSlot(String timeRaw, String roomRaw, String courseLabel, String friendName) {
    final spaceIdx = timeRaw.indexOf(' ');
    if (spaceIdx < 0) return;

    final weekdayPart = timeRaw.substring(0, spaceIdx);
    final timeRange = timeRaw.substring(spaceIdx + 1).replaceAll(' ', '');

    String room = roomRaw;
    final parenIdx = room.indexOf(' (');
    if (parenIdx > 0) room = room.substring(0, parenIdx);

    if (!times.contains(timeRange)) {
      times.add(timeRange);
      routine[timeRange] = List.generate(days.length, (_) => RoutineCellData());
    }

    for (int i = 0; i < weekdayPart.length; i++) {
      final dayName = kDayMap[weekdayPart[i]];
      if (dayName == null) continue;

      _ensureDayExists(dayName);

      final dayIndex = days.indexOf(dayName);
      if (dayIndex < 0) continue;

      routine[timeRange]![dayIndex].friends.add(FriendData(
        name: friendName,
        course: courseLabel,
        room: room,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // File picker
  // ---------------------------------------------------------------------------

  Future<void> _pickAdvisingSlipFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.isEmpty) {
        _showSnackBar('No file selected.');
        return;
      }

      final file = result.files.first;
      if (!(file.name.toLowerCase().endsWith('.xlsx'))) {
        _showSnackBar('Please select a .xlsx file.');
        return;
      }

      final path = file.path;
      if (path == null) {
        _showSnackBar('Could not access file path.');
        return;
      }

      final bytes = await File(path).readAsBytes();
      await _applyAdvisingSlipFromFile(bytes);
    } catch (e) {
      debugPrint('_pickAdvisingSlipFile error: $e');
      _showSnackBar('Error picking file: $e');
    }
  }

  Future<void> _pickFriendSlipFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.isEmpty) {
        _showSnackBar('No file selected.');
        return;
      }

      final file = result.files.first;
      if (!(file.name.toLowerCase().endsWith('.xlsx'))) {
        _showSnackBar('Please select a .xlsx file.');
        return;
      }

      final path = file.path;
      if (path == null) {
        _showSnackBar('Could not access file path.');
        return;
      }

      final bytes = await File(path).readAsBytes();
      await _applyFriendSlipFromFile(bytes);
    } catch (e) {
      debugPrint('_pickFriendSlipFile error: $e');
      _showSnackBar('Error picking friend file: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  Future<void> _loadRoutineData() async {
    final prefs = await SharedPreferences.getInstance();
    final timesStr = prefs.getString('routine_times');
    final routineStr = prefs.getString('routine_data');
    final daysStr = prefs.getString('routine_days');
    if (!mounted) return;
    if (timesStr == null || routineStr == null) return;

    try {
      final loadedTimes = List<String>.from(json.decode(timesStr) as List);
      final compressedBytes = base64Decode(routineStr);
      final decompressedBytes = zlib.decode(compressedBytes);
      final decompressedRoutineStr = utf8.decode(decompressedBytes);
      final loadedRoutineMap =
      json.decode(decompressedRoutineStr) as Map<String, dynamic>;

      final loadedRoutine = <String, List<RoutineCellData>>{};
      loadedRoutineMap.forEach((key, value) {
        loadedRoutine[key] =
            (value as List).map((cell) => RoutineCellData.fromJson(cell as Map<String, dynamic>)).toList();
      });

      List<String> loadedDays;
      if (daysStr != null) {
        loadedDays = List<String>.from(json.decode(daysStr) as List);
      } else {
        // Legacy saves predate day persistence; reconstruct the columns from
        // the saved routine row width, clamped to the known weekdays.
        final first = loadedRoutine.values.isNotEmpty
            ? loadedRoutine.values.first.length
            : kAllDays.length;
        final count = first.clamp(1, kAllDays.length);
        loadedDays = kAllDays.take(count).toList();
      }

      // Same invariant as _saveRoutineData: no content, no days.
      final hasContent = loadedRoutine.values
          .any((cells) => cells.any((c) => !c.isEmpty));
      if (!hasContent) loadedDays = [];

      setState(() {
        times = loadedTimes;
        routine = loadedRoutine;
        days = loadedDays;
      });
    } catch (e) {
      debugPrint('_loadRoutineData error: $e');
    }
  }

  Future<void> _saveRoutineData() async {
    // Invariant: the calendar only shows days while there is content to
    // display. Clearing days here covers every removal path (Remove Course,
    // cell deletes, Remove Time Slot, Remove Day, Remove All).
    final hasContent =
        routine.values.any((cells) => cells.any((c) => !c.isEmpty));
    if (!hasContent && days.isNotEmpty) {
      days = [];
      if (mounted) setState(() {});
    }

    final prefs = await SharedPreferences.getInstance();
    final timesStr = json.encode(times);
    final routineMap = routine.map(
          (key, value) => MapEntry(key, value.map((cell) => cell.toJson()).toList()),
    );
    final routineStr = json.encode(routineMap);
    final compressedRoutine = zlib.encode(utf8.encode(routineStr));
    final compressedRoutineBase64 = base64Encode(compressedRoutine);
    await prefs.setString('routine_times', timesStr);
    await prefs.setString('routine_data', compressedRoutineBase64);
    await prefs.setString('routine_days', json.encode(days));
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _saveRoutineAsPng() async {
    try {
      final boundary =
      _routineKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ImageByteFormat.png);
      if (byteData == null) {
        _showSnackBar('Failed to capture routine image.');
        return;
      }
      final pngBytes = byteData.buffer.asUint8List();
      final dir = await _getDownloadsDir();
      if (dir == null) {
        _showSnackBar('Could not access Downloads folder.');
        return;
      }
      final filePath =
          '${dir.path}/routine_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(filePath).writeAsBytes(pngBytes);
      if (!mounted) return;
      _showSnackBar('Routine saved to Downloads: $filePath');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to save PNG: $e');
    }
  }

  Future<void> _saveRoutineAsPdf() async {
    final pdfDoc = pw.Document();
    pdfDoc.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(children: [
                _pdfCell('Day/Time', bold: true),
                ...times.map((t) => _pdfCell(t, bold: true)),
              ]),
              ...days.asMap().entries.map((entry) {
                final dayIdx = entry.key;
                return pw.TableRow(children: [
                  _pdfCell(days[dayIdx], bold: true),
                  ...times.map((time) {
                    final cells = routine[time];
                    if (cells == null || dayIdx >= cells.length) {
                      return _pdfCell('');
                    }
                    final cell = cells[dayIdx];
                    final parts = <String>[
                      if (cell.course.isNotEmpty) cell.course,
                      if (cell.room.isNotEmpty) cell.room,
                      if (cell.friends.isNotEmpty)
                        '${cell.friends.length} friend${cell.friends.length > 1 ? 's' : ''}',
                    ];
                    return _pdfCell(parts.join('\n'));
                  }),
                ]);
              }),
            ],
          );
        },
      ),
    );
    final bytes = await pdfDoc.save();
    final dir = await _getDownloadsDir();
    if (dir == null) {
      _showSnackBar('Could not access Downloads folder.');
      return;
    }
    final filePath =
        '${dir.path}/routine_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(filePath).writeAsBytes(bytes);
    if (!mounted) return;
    _showSnackBar('Routine saved to Downloads: $filePath');
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs — Add / Remove time slots
  // ---------------------------------------------------------------------------

  void _showAddTimeDialog() async {
    final availableTimes = [
      ...allTimes.where((t) => t == 'Custom' || !times.contains(t)),
    ];
    if (availableTimes.isEmpty) {
      _showSnackBar('All preset time slots are already added.');
      return;
    }

    String selectedTime = availableTimes.first;
    String customTime = '';
    int insertIndex = times.length;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Add Time Slot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedTime,
                isExpanded: true,
                decoration: _dropdownDecoration(),
                items: availableTimes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setLocalState(() => selectedTime = val!),
              ),
              if (selectedTime == 'Custom') ...[
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Custom Time',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) => customTime = val,
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: insertIndex,
                isExpanded: true,
                decoration: _dropdownDecoration(),
                items: [
                  for (int i = 0; i <= times.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                        i == times.length ? 'At end' : 'Before "${times[i]}"',
                      ),
                    ),
                ],
                onChanged: (val) => setLocalState(() => insertIndex = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final timeToAdd =
                selectedTime == 'Custom' ? customTime.trim() : selectedTime;
                if (timeToAdd.isEmpty || times.contains(timeToAdd)) {
                  Navigator.pop(context);
                  return;
                }
                Navigator.pop(context, '$timeToAdd|$insertIndex');
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || result == null || result.isEmpty) return;
    final parts = result.split('|');
    final timeToAdd = parts[0];
    final idx = int.tryParse(parts[1]) ?? times.length;
    if (!times.contains(timeToAdd)) {
      setState(() {
        times.insert(idx, timeToAdd);
        routine[timeToAdd] = List.generate(days.length, (_) => RoutineCellData());
      });
      await _saveRoutineData();
    }
  }

  void _showRemoveTimeSlotDialog() async {
    if (times.isEmpty) {
      _showSnackBar('No time slots to remove.');
      return;
    }

    final uniqueTimes = times.toSet().toList();
    String selectedTime = uniqueTimes.first;
    bool removed = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Remove Time Slot'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedTime,
            isExpanded: true,
            decoration: _dropdownDecoration(),
            items: uniqueTimes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (val) => setLocalState(() => selectedTime = val!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            _destructiveButton(
              label: 'Remove',
              onPressed: () {
                times.removeWhere((t) => t == selectedTime);
                routine.remove(selectedTime);
                removed = true;
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (removed) {
      setState(() {});
      await _saveRoutineData();
    }
  }

  void _showRemoveDayDialog() async {
    if (days.length <= 1) {
      _showSnackBar('At least one day must remain.');
      return;
    }

    String selectedDay = days.first;
    bool removed = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Remove Day'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedDay,
            isExpanded: true,
            decoration: _dropdownDecoration(),
            items: days
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (val) => setLocalState(() => selectedDay = val!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            _destructiveButton(
              label: 'Remove',
              onPressed: () {
                final idx = days.indexOf(selectedDay);
                if (idx < 0) return;
                for (final time in times) {
                  final cells = routine[time];
                  if (cells != null && idx < cells.length) {
                    cells.removeAt(idx);
                  }
                }
                days.removeAt(idx);
                removed = true;
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (removed) {
      setState(() {});
      await _saveRoutineData();
    }
  }

  void _showRemoveCourseDialog() async {
    final allCourses = <String>{};
    for (final entry in routine.entries) {
      for (final cell in entry.value) {
        if (cell.course.trim().isNotEmpty) {
          allCourses.add(cell.course.trim());
        }
      }
    }
    if (allCourses.isEmpty) {
      _showSnackBar('No courses to remove.');
      return;
    }

    final sortedCourses = allCourses.toList()..sort();
    String selectedCourse = sortedCourses.first;
    bool removed = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Remove Course'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedCourse,
            isExpanded: true,
            decoration: _dropdownDecoration(),
            items: sortedCourses
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (val) => setLocalState(() => selectedCourse = val!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            _destructiveButton(
              label: 'Remove',
              onPressed: () {
                for (final time in times) {
                  final cells = routine[time];
                  if (cells == null) continue;
                  for (int i = 0; i < cells.length; i++) {
                    if (cells[i].course.trim() == selectedCourse) {
                      cells[i] = cells[i].copyWith(course: '', room: '');
                    }
                  }
                }
                removed = true;
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (removed) {
      setState(() {});
      await _saveRoutineData();
    }
  }

  void _showRemoveAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove All'),
        content: const Text('Clear all routine data, time slots, and days?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          _destructiveButton(
            label: 'Clear All',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    routine.clear();
    times.clear();
    setState(() {});
    await _saveRoutineData();
    _showSnackBar('All data cleared.');
  }

  // A themed destructive action button so "Remove"/"Clear All" consistently
  // use the error role instead of raw Colors.red.
  Widget _destructiveButton({required String label, required VoidCallback onPressed}) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: scheme.error,
        foregroundColor: scheme.onError,
      ),
      child: Text(label),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs — Cell info / Add class / Add friend
  // ---------------------------------------------------------------------------

  void _showCellDialog(int dayIdx, String time) async {
    final cells = routine[time];
    if (cells == null || dayIdx >= cells.length) return;

    final dayName = dayIdx < days.length ? days[dayIdx] : '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Re-read cell every rebuild so deletions are reflected immediately
          final cell = routine[time]![dayIdx];

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
            title: _buildCellDialogTitle(dayName, time),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (cell.isEmpty)
                    _buildDialogInfoCard(
                      icon: Icons.event_busy_rounded,
                      title: 'Nothing scheduled',
                      subtitle: 'This slot is free. Add a class or a friend.',
                      accent: Theme.of(context).colorScheme.onSurfaceVariant,
                    )
                  else ...[
                    if (cell.course.isNotEmpty)
                      _buildDialogInfoCard(
                        icon: Icons.menu_book_rounded,
                        title: cell.course,
                        subtitle: cell.room.isEmpty ? 'No room' : cell.room,
                        accent: courseColorFor(cell.course),
                        onDelete: () async {
                          routine[time]![dayIdx] =
                              cell.copyWith(course: '', room: '');
                          setState(() {});
                          setStateDialog(() {});
                          await _saveRoutineData();
                        },
                      ),
                    if (cell.friends.isNotEmpty) ...[
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 14, bottom: 4, left: 4),
                        child: Text(
                          'FRIENDS',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            color: Theme.of(context).colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                      for (int i = 0; i < cell.friends.length; i++)
                        _buildDialogInfoCard(
                          icon: Icons.person_rounded,
                          title: cell.friends[i].name,
                          subtitle: [
                            if (cell.friends[i].course.isNotEmpty)
                              cell.friends[i].course,
                            if (cell.friends[i].room.isNotEmpty)
                              cell.friends[i].room,
                          ].join(' · '),
                          accent: Theme.of(context).colorScheme.secondary,
                          onDelete: () async {
                            routine[time]![dayIdx].friends.removeAt(i);
                            setState(() {});
                            setStateDialog(() {});
                            await _saveRoutineData();
                          },
                        ),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              const SizedBox(width: 8),
              if (cell.course.isEmpty)
                TextButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _showAddClassDialog(dayIdx, time);
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Class'),
                ),
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _showAddFriendDialog(dayIdx, time);
                },
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Add Friend'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCellDialogTitle(String dayName, String time) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
          ),
          child: Icon(Icons.class_rounded, color: scheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayName.isEmpty ? 'Class Info' : dayName,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  color: scheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDialogInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    VoidCallback? onDelete,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    color: scheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              tooltip: 'Delete',
              icon: Icon(Icons.delete, color: scheme.error, size: 20),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddClassDialog(int dayIdx, String time) async {
    String course = '';
    String room = '';
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Course Name'),
              onChanged: (val) => course = val,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Room Number'),
              onChanged: (val) => room = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (course.trim().isNotEmpty || room.trim().isNotEmpty) {
                routine[time]![dayIdx] = routine[time]![dayIdx].copyWith(
                  course: course.trim(),
                  room: room.trim(),
                );
                setState(() {});
                await _saveRoutineData();
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddFriendDialog(int dayIdx, String time) async {
    String friendName = '';
    String friendCourse = '';
    String friendRoom = '';
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Friend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Friend Name'),
              onChanged: (val) => friendName = val,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Course Name'),
              onChanged: (val) => friendCourse = val,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Room Number'),
              onChanged: (val) => friendRoom = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (friendName.trim().isNotEmpty ||
                  friendCourse.trim().isNotEmpty ||
                  friendRoom.trim().isNotEmpty) {
                routine[time]![dayIdx].friends.add(FriendData(
                  name: friendName.trim(),
                  course: friendCourse.trim(),
                  room: friendRoom.trim(),
                ));
                setState(() {});
                await _saveRoutineData();
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick actions — single FAB hub (Add / Remove / Save)
  // ---------------------------------------------------------------------------

  // One FAB replaces the old three-FAB cluster. It opens a grouped bottom
  // sheet so every mutation/export action stays one tap away without
  // competing floating buttons.
  void _showQuickActions() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            // Column (not a ListView) so a downward pull on the options
            // overscrolls at the top edge and the modal sheet dismisses,
            // instead of the list swallowing the gesture.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              _sheetSection('Add to routine', scheme),
              _sheetTile(
                icon: Icons.edit_rounded,
                label: 'Manual Entry',
                accent: scheme.primary,
                onTap: () => _runSheetAction(_showAddTimeDialog),
              ),
              _sheetTile(
                icon: Icons.receipt_long_rounded,
                label: 'Advising Slip',
                accent: scheme.tertiary,
                onTap: () => _runSheetAction(_pickAdvisingSlipFile),
              ),
              _sheetTile(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Friend Slip',
                accent: scheme.secondary,
                onTap: () => _runSheetAction(_pickFriendSlipFile),
              ),
              _sheetSection('Remove', scheme),
              _sheetTile(
                icon: Icons.schedule_rounded,
                label: 'Time Slot',
                accent: scheme.error,
                onTap: () => _runSheetAction(_showRemoveTimeSlotDialog),
              ),
              _sheetTile(
                icon: Icons.calendar_view_day_rounded,
                label: 'Day',
                accent: scheme.error,
                onTap: () => _runSheetAction(_showRemoveDayDialog),
              ),
              _sheetTile(
                icon: Icons.book_rounded,
                label: 'Course',
                accent: scheme.error,
                onTap: () => _runSheetAction(_showRemoveCourseDialog),
              ),
              _sheetTile(
                icon: Icons.delete_forever_rounded,
                label: 'All',
                accent: scheme.error,
                onTap: () => _runSheetAction(_showRemoveAllDialog),
              ),
              _sheetSection('Save', scheme),
              _sheetTile(
                icon: Icons.image_rounded,
                label: 'Save as PNG',
                accent: scheme.primary,
                onTap: () => _runSheetAction(_saveRoutineAsPng),
              ),
              _sheetTile(
                icon: Icons.picture_as_pdf_rounded,
                label: 'Save as PDF',
                accent: scheme.primary,
                onTap: () => _runSheetAction(_saveRoutineAsPdf),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _sheetSection(String title, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          color: scheme.secondary,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1.6,
        ),
      ),
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: accent, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      onTap: onTap,
    );
  }

  void _runSheetAction(VoidCallback action) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      action();
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  InputDecoration _dropdownDecoration() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      filled: true,
      fillColor: scheme.surface,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Directory?> _getDownloadsDir() async {
    if (!Platform.isAndroid) return getDownloadsDirectory();
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    if (!status.isGranted) return null;
    final dir = Directory('/storage/emulated/0/Download');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  Widget _buildDrawer() {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.surfaceContainerHighest, scheme.surfaceContainerHigh],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: scheme.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(Icons.history_toggle_off,
                        color: scheme.primary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tofu Routine',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            color: scheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 19,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'EWU COURSE PLANNER',
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  _drawerItem(
                    icon: Icons.calendar_view_week,
                    label: 'Weekly Calendar',
                    color: scheme.primary,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _drawerItem(
                    icon: Icons.calendar_view_month,
                    label: 'Monthly Calendar',
                    color: scheme.tertiary,
                    soon: true,
                  ),
                  _drawerItem(
                    icon: Icons.event_note,
                    label: 'Import to Calendar',
                    color: scheme.secondary,
                    soon: true,
                  ),
                  _drawerItem(
                    icon: Icons.event_available,
                    label: 'Import to Google Calendar',
                    color: scheme.secondary,
                    soon: true,
                  ),
                  _drawerItem(
                    icon: Icons.logout,
                    label: 'Exit',
                    color: scheme.error,
                    onTap: () => _runDrawerAction(() => SystemNavigator.pop()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Drawer item. Unavailable features render disabled with a "Soon" chip so
  // they never behave like dead-end affordances.
  Widget _drawerItem({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool soon = false,
  }) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool enabled = onTap != null;
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: enabled ? color : color.withValues(alpha: 0.55)),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          color: scheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: soon
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Soon',
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : Icon(
              Icons.chevron_right,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              size: 18,
            ),
      onTap: onTap,
    );
  }

  void _runDrawerAction(VoidCallback action) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      action();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: CalendarHeaderBar(
        onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: _buildDrawer(),
      body: WeeklyCalendarGrid(
        routineKey: _routineKey,
        onCellTap: _showCellDialog,
        onImportSlip: _pickAdvisingSlipFile,
        onAddSlot: () => _showAddTimeDialog(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickActions,
        tooltip: 'Actions',
        child: const Icon(Icons.more_horiz_rounded),
      ),
    );
  }
}

class _PendingSlot {
  final String time;
  final String room;
  const _PendingSlot(this.time, this.room);
}
