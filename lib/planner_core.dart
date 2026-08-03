import 'package:flutter/material.dart';

// =============================================================================
// planner_core.dart — shared planner state, palette and layout constants.
//
// Hosts the data models, the global routine state, the brand palette and the
// adaptive layout constants that BOTH the logic layer (main.dart) and the
// presentation layer (calendar_view.dart) depend on. Keeping these in a single
// core file removes the circular import that previously existed between
// main.dart and calendar_view.dart, so the two layers only ever depend on this
// shared core.
// =============================================================================

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
// These constants are the single source of truth for the brand. They are
// mapped onto the Material 3 ColorScheme roles in main.dart so every widget
// consumes them through Theme.of(context).colorScheme instead of hardcoding
// raw Colors.* literals inside build methods.
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
// The grid is sized adaptively so the whole calendar fits on screen: the
// day-label column grows with leftover width while time-slot columns and
// day-row heights split the remaining space, clamped to comfortable minimums.
// Used by both the RoutinePage state (logic) and the WeeklyCalendarGrid
// (pure UI, see calendar_view.dart) so both stay in sync.
const double kDayColWidth = 32; // min width of the day-label column
const double kMaxDayColWidth = 56; // max width of the day-label column
const double kMinTimeColWidth = 40; // min width of a time-slot column (40px so tap targets approach the 48px standard)
const double kMinRowHeight = 40; // min height of a day row (raised 36 -> 40 for touch targets)
const double kMaxRowHeight = 48; // max height of a day row
const double kCellMargin = 2; // gutter between adjacent cells
// ==================================================

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
