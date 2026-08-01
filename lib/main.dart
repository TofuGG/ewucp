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
import 'calendar_view.dart';

// ======= Global routine data =======
Map<String, List<RoutineCellData>> routine = {};
List<String> times = [];
const List<String> kAllDays = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];
List<String> days = [];

// Shared day abbreviation map used for EWU advising slip parsing
const Map<String, String> kDayMap = {
  'S': 'Sunday',
  'M': 'Monday',
  'T': 'Tuesday',
  'W': 'Wednesday',
  'R': 'Thursday',
};
// ===================================

// ======= Shared UI palette (base theme only) =======
// A deep-navy "planner" palette with a warm highlighter-gold accent.
// Note: the +/- / download FloatingActionButtons and the menus/dialogs
// they open keep their original colors and are untouched by this palette.
const Color kBgTop = Color(0xFF16213A);
const Color kBgBottom = Color(0xFF0A0F1C);
const Color kHeaderTop = Color(0xFF1C2C4E);
const Color kHeaderBottom = Color(0xFF10182C);
const Color kRowEven = Color(0xFF121B30);
const Color kRowOdd = Color(0xFF0D1424);
const Color kCellBg = Color(0xFF19233C);
const Color kCellBorder = Color(0xFF2C3A5C);
const Color kAccent = Color(0xFFA9E6F5);   // splash screen's light-blue circle
const Color kAccentBlue = Color(0xFFF4E04D);   // splash screen's yellow circle
const Color kTextMuted = Color(0xFFAEB8CE);
// ===================================================

// ======= Shared calendar layout constants =======
// Used by both the RoutinePage state (logic) and the WeeklyCalendarGrid
// (pure UI, see calendar_view.dart) so both stay in sync.
const double kDayColWidth = 120;
const double kTimeColWidth = 150;
const double kCellMargin = 4;
// ==================================================

void main() {
  runApp(MaterialApp(
    home: const StartupScreen(),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBgBottom,
      fontFamily: 'JetBrains Mono',
      colorScheme: ColorScheme.fromSeed(
        seedColor: kAccent,
        brightness: Brightness.dark,
      ).copyWith(surface: kCellBg),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    ),
  ));
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
        MaterialPageRoute(builder: (_) => const RoutinePage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgBottom,
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
                color: Color(0xFFA9E6F5),
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
                color: Color(0xFFF4E04D),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Centered logo + app name
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.history_toggle_off,
                  color: Colors.white,
                  size: 56,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tofu Routine',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    color: Colors.white,
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
  final GlobalKey _saveFabKey = GlobalKey();
  final GlobalKey _routineKey = GlobalKey();
  final GlobalKey _addFabKey = GlobalKey();
  final GlobalKey _removeFabKey = GlobalKey();

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
      builder: (context) => DropdownMenuTheme(
        data: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(Colors.blueGrey[900]),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            elevation: const WidgetStatePropertyAll(2),
          ),
        ),
        child: StatefulBuilder(
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
                style: TextButton.styleFrom(foregroundColor: kAccent),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final timeToAdd =
                  selectedTime == 'Custom' ? customTime.trim() : selectedTime;
                  if (timeToAdd.isEmpty || times.contains(timeToAdd)) {
                    Navigator.pop(context);
                    return;
                  }
                  Navigator.pop(context, '$timeToAdd|$insertIndex');
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: kAccent,
                  backgroundColor: Colors.blue,
                ),
                child: const Text('Add'),
              ),
            ],
          ),
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
              style: TextButton.styleFrom(foregroundColor: kAccent),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                times.removeWhere((t) => t == selectedTime);
                routine.remove(selectedTime);
                removed = true;
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: kAccent,
                backgroundColor: Colors.red,
              ),
              child: const Text('Remove'),
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

  // Estimates the rendered width of a popup menu from its item labels, so
  // the menu can be centered on its FAB instead of assuming a fixed width.
  double _estimateMenuWidth(List<String> labels) {
    double maxTextWidth = 0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > maxTextWidth) maxTextWidth = painter.width;
    }
    // icon (24) + icon/text gap (8) + item's own horizontal padding (12*2)
    // + a small buffer so the text never touches the pill's edge.
    return maxTextWidth + 24 + 8 + 24 + 10;
  }

  void _showRemoveOptions() async {
    final fabBox =
    _removeFabKey.currentContext!.findRenderObject() as RenderBox;
    final fabOffset = fabBox.localToGlobal(Offset.zero);
    final fabSize = fabBox.size;
    final screenSize = MediaQuery.of(context).size;
    const double menuHeight = 208; // 4 items (48px/item + 16px menu padding)
    const double gap = 12;
    const double menuWidthStep = 56; // Material menu widths snap to this step
    final menuWidth = (_estimateMenuWidth(['Manual', 'Advising Slip', 'Friend Slip']) / menuWidthStep).ceil() * menuWidthStep;
    final buttonCenterX = fabOffset.dx + fabSize.width / 2;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonCenterX - menuWidth / 2,
        fabOffset.dy - menuHeight - gap,
        screenSize.width - (buttonCenterX + menuWidth / 2),
        screenSize.height - fabOffset.dy + gap,
      ),
      constraints: BoxConstraints.tightFor(width: menuWidth),
      elevation: 8,
      color: Colors.blueGrey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        _buildPopupItem('time', Icons.schedule, 'Time Slot', Colors.red,
            width: menuWidth),
        _buildPopupItem('day', Icons.calendar_view_day, 'Day', Colors.orange,
            width: menuWidth),
        _buildPopupItem('course', Icons.book, 'Course', Colors.purple,
            width: menuWidth),
        _buildPopupItem('all', Icons.delete_forever, 'All', Colors.grey,
            width: menuWidth),
      ],
    );
    if (!mounted) return;
    if (selected == 'time') _showRemoveTimeSlotDialog();
    if (selected == 'day') await _showRemoveDayDialog();
    if (selected == 'course') await _showRemoveCourseDialog();
    if (selected == 'all') await _showRemoveAllDialog();
  }

  Future<void> _showRemoveDayDialog() async {
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
              style: TextButton.styleFrom(foregroundColor: kAccent),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
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
              style: ElevatedButton.styleFrom(
                foregroundColor: kAccent,
                backgroundColor: Colors.red,
              ),
              child: const Text('Remove'),
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

  Future<void> _showRemoveCourseDialog() async {
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
              style: TextButton.styleFrom(foregroundColor: kAccent),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
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
              style: ElevatedButton.styleFrom(
                foregroundColor: kAccent,
                backgroundColor: Colors.red,
              ),
              child: const Text('Remove'),
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

  Future<void> _showRemoveAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove All'),
        content: const Text('Clear all routine data, time slots, and days?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: kAccent),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              foregroundColor: kAccent,
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear All'),
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

  // ---------------------------------------------------------------------------
  // Dialogs — Cell info / Add class / Add friend
  // ---------------------------------------------------------------------------

  void _showCellDialog(int dayIdx, String time) async {
    final cells = routine[time];
    if (cells == null || dayIdx >= cells.length) return;

    if (cells[dayIdx].isEmpty) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No class'),
          content: const Text('No class info for this slot.'),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _showAddClassDialog(dayIdx, time);
                  },
                  style: TextButton.styleFrom(foregroundColor: kAccent),
                  child: const Text('Add Class'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _showAddFriendDialog(dayIdx, time);
                  },
                  style: TextButton.styleFrom(foregroundColor: kAccent),
                  child: const Text('Add Friend'),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            // Re-read cell every rebuild so deletions are reflected immediately
            final cell = routine[time]![dayIdx];
            final infoWidgets = <Widget>[];

            if (cell.course.isNotEmpty) {
              infoWidgets.add(ListTile(
                title: const Text('Class'),
                subtitle: Text('${cell.course}\n${cell.room}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    routine[time]![dayIdx] =
                        cell.copyWith(course: '', room: '');
                    setState(() {});
                    setStateDialog(() {});
                    await _saveRoutineData();
                  },
                ),
              ));
            }

            if (cell.friends.isNotEmpty) {
              infoWidgets.add(const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text('Friends:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ));
              for (int i = 0; i < cell.friends.length; i++) {
                final friend = cell.friends[i];
                infoWidgets.add(ListTile(
                  title: Text(friend.name),
                  subtitle: Text('${friend.course}\n${friend.room}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      routine[time]![dayIdx].friends.removeAt(i);
                      setState(() {});
                      setStateDialog(() {});
                      await _saveRoutineData();
                    },
                  ),
                ));
              }
            }

            return AlertDialog(
              title: const Text('Class Info'),
              content: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min, children: infoWidgets),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (cell.course.isEmpty)
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _showAddClassDialog(dayIdx, time);
                        },
                        style:
                        TextButton.styleFrom(foregroundColor: kAccent),
                        child: const Text('Add Class'),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _showAddFriendDialog(dayIdx, time);
                      },
                      style:
                      TextButton.styleFrom(foregroundColor: kAccent),
                      child: const Text('Add Friend'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }
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
            style: TextButton.styleFrom(foregroundColor: kAccent),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
            style: TextButton.styleFrom(foregroundColor: kAccent),
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
            style: TextButton.styleFrom(foregroundColor: kAccent),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
            style: TextButton.styleFrom(foregroundColor: kAccent),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FAB menus
  // ---------------------------------------------------------------------------

  void _showSaveOptions() async {
    final fabBox =
    _saveFabKey.currentContext!.findRenderObject() as RenderBox;
    final fabOffset = fabBox.localToGlobal(Offset.zero);
    final fabSize = fabBox.size;
    final screenSize = MediaQuery.of(context).size;
    const double menuHeight = 112; // 2 items (48px/item + 16px menu padding)
    const double gap = 12;
    final menuWidth = _estimateMenuWidth(['Save as PNG', 'Save as PDF']);
    final buttonCenterX = fabOffset.dx + fabSize.width / 2;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonCenterX - menuWidth / 2,
        fabOffset.dy - menuHeight - gap,
        screenSize.width - (buttonCenterX + menuWidth / 2),
        screenSize.height - fabOffset.dy + gap,
      ),
      elevation: 8,
      color: Colors.blueGrey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        _buildPopupItem('save_png', Icons.image, 'Save as PNG', Colors.green),
        _buildPopupItem(
            'save_pdf', Icons.picture_as_pdf, 'Save as PDF', Colors.blue),
      ],
    );
    if (!mounted) return;
    if (selected == 'save_png') await _saveRoutineAsPng();
    if (selected == 'save_pdf') await _saveRoutineAsPdf();
  }

  void _showAddOptions() async {
    final fabBox =
    _addFabKey.currentContext!.findRenderObject() as RenderBox;
    final fabOffset = fabBox.localToGlobal(Offset.zero);
    final fabSize = fabBox.size;
    final screenSize = MediaQuery.of(context).size;
    const double menuHeight = 160; // 3 items (48px/item + 16px menu padding)
    const double gap = 12;
    final menuWidth = _estimateMenuWidth(['Manual', 'Advising Slip', 'Friend Slip']);
    final buttonCenterX = fabOffset.dx + fabSize.width / 2;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonCenterX - menuWidth / 2,
        fabOffset.dy - menuHeight - gap,
        screenSize.width - (buttonCenterX + menuWidth / 2),
        screenSize.height - fabOffset.dy + gap,
      ),
      elevation: 8,
      color: Colors.blueGrey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        _buildPopupItem('manual', Icons.edit, 'Manual', Colors.green),
        _buildPopupItem(
            'advising', Icons.receipt_long, 'Advising Slip', Colors.blue),
        _buildPopupItem(
            'friend_slip', Icons.person_add, 'Friend Slip', Colors.teal),
      ],
    );
    if (!mounted) return;
    if (selected == 'manual') _showAddTimeDialog();
    if (selected == 'advising') await _pickAdvisingSlipFile();
    if (selected == 'friend_slip') await _pickFriendSlipFile();
  }

  PopupMenuItem<String> _buildPopupItem(
      String value,
      IconData icon,
      String label,
      MaterialColor color,
      {
      double? width,
      }) {
    return PopupMenuItem(
      value: value,
      padding: EdgeInsets.zero,
      child: Material(
        color: color[100],
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: color[200],
          highlightColor: color[300],
          onTap: () => Navigator.pop(context, value),
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              children: [
                Icon(icon, color: color[700]),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: color[900])),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  InputDecoration _dropdownDecoration() => InputDecoration(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    filled: true,
    fillColor: Colors.blueGrey[50],
  );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgBottom,
      appBar: const CalendarHeaderBar(),
      body: WeeklyCalendarGrid(
        routineKey: _routineKey,
        onCellTap: _showCellDialog,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, right: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              key: _removeFabKey,
              heroTag: 'remove',
              onPressed: _showRemoveOptions,
              backgroundColor: Colors.red[700],
              child: const Icon(Icons.remove, color: Colors.white),
            ),
            const SizedBox(width: 16),
            FloatingActionButton(
              key: _addFabKey,
              heroTag: 'add',
              onPressed: _showAddOptions,
              backgroundColor: Colors.blue[900],
              child: const Icon(Icons.add, color: Colors.white),
            ),
            const SizedBox(width: 16),
            FloatingActionButton(
              key: _saveFabKey,
              heroTag: 'save',
              onPressed: _showSaveOptions,
              backgroundColor: Colors.green[700],
              child: const Icon(Icons.arrow_downward, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Data models
// =============================================================================

class RoutineCellData {
  final String course;
  final String room;
  final List<FriendData> friends;

  RoutineCellData({
    this.course = '',
    this.room = '',
    List<FriendData>? friends,
  }) : friends = friends ?? [];

  bool get isEmpty =>
      course.trim().isEmpty && room.trim().isEmpty && friends.isEmpty;

  RoutineCellData copyWith({
    String? course,
    String? room,
    List<FriendData>? friends,
  }) =>
      RoutineCellData(
        course: course ?? this.course,
        room: room ?? this.room,
        friends: friends ?? List<FriendData>.from(this.friends),
      );

  Map<String, dynamic> toJson() => {
    'course': course,
    'room': room,
    'friends': friends.map((f) => f.toJson()).toList(),
  };

  factory RoutineCellData.fromJson(Map<String, dynamic> json) =>
      RoutineCellData(
        course: json['course'] as String? ?? '',
        room: json['room'] as String? ?? '',
        friends: (json['friends'] as List<dynamic>? ?? [])
            .map((f) => FriendData.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
}

class FriendData {
  final String name;
  final String course;
  final String room;

  const FriendData({this.name = '', this.course = '', this.room = ''});

  Map<String, dynamic> toJson() =>
      {'name': name, 'course': course, 'room': room};

  factory FriendData.fromJson(Map<String, dynamic> json) => FriendData(
    name: json['name'] as String? ?? '',
    course: json['course'] as String? ?? '',
    room: json['room'] as String? ?? '',
  );
}

// =============================================================================
// Routine cell presentation widget
// =============================================================================
// Note: RoutineCell now lives in calendar_view.dart alongside the rest of
// the calendar's UI layer.
// =============================================================================

class _PendingSlot {
  final String time;
  final String room;
  const _PendingSlot(this.time, this.room);
}
