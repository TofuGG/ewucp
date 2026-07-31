import 'package:flutter/material.dart';
import 'main.dart';

// Palette assigned to courses. Kept distinct/high-contrast against the dark
// navy background; colors are stable per course name so the same course is
// always the same color across the whole grid.
const List<Color> _coursePalette = [
  kAccent,          // light blue
  kAccentBlue,      // gold
  Color(0xFF9EDB8E), // green
  Color(0xFFC7A6F5), // purple
  Color(0xFFFFAE7A), // orange
  Color(0xFF8ED4C8), // teal
];

// Reduces a course label to its base code so a lecture and its lab share a
// color: "PHY109 (4)", "PHY109 Lab" and "PHY109-01" all key to "PHY109".
String _courseKey(String course) {
  final t = course.trim();
  if (t.isEmpty) return '';
  final code = RegExp(r'^[A-Za-z]+\s*\d+').firstMatch(t);
  if (code != null) return code.group(0)!.replaceAll(RegExp(r'\s+'), '');
  return t.split(RegExp(r'\s+')).first;
}

// Maps every distinct course code in the routine to a palette color, sorted
// alphabetically so the assignment is deterministic across rebuilds.
Map<String, Color> _courseColors() {
  final names = <String>{};
  for (final cells in routine.values) {
    for (final c in cells) {
      final n = _courseKey(c.course);
      if (n.isNotEmpty) names.add(n);
    }
  }
  final sorted = names.toList()..sort();
  return {
    for (var i = 0; i < sorted.length; i++)
      sorted[i]: _coursePalette[i % _coursePalette.length],
  };
}

// =============================================================================
// Calendar UI layer
//
// This file contains ONLY presentation / layout widgets for the weekly
// calendar. It reads the shared app state (routine / times / days) and the
// shared color palette from main.dart, but holds no business logic itself —
// all data mutation, persistence, dialogs, and FAB behavior stay in
// main.dart's _RoutinePageState untouched.
// =============================================================================

// ------------------------------------------------------------------------
// App bar
// ------------------------------------------------------------------------
class CalendarHeaderBar extends StatelessWidget
    implements PreferredSizeWidget {
  const CalendarHeaderBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kHeaderTop, kHeaderBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: kAccent.withAlpha(130), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(90),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: kAccent.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kAccent.withAlpha(90)),
                ),
                child:
                    const Icon(Icons.calendar_month_rounded, color: kAccent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Tofu Routine',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 21,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'EWU COURSE PLANNER',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        color: kAccent.withAlpha(210),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------
// Weekly calendar grid
// ------------------------------------------------------------------------
class WeeklyCalendarGrid extends StatelessWidget {
  final GlobalKey routineKey;
  final void Function(int dayIndex, String time) onCellTap;

  const WeeklyCalendarGrid({
    super.key,
    required this.routineKey,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final double totalTimeColWidth =
        times.length * (kTimeColWidth + kCellMargin);
    final double tableWidth = kDayColWidth + totalTimeColWidth;
    final Map<String, Color> courseColors = _courseColors();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kBgTop, kBgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double minWidth = constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth > minWidth ? tableWidth : minWidth,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: RepaintBoundary(
                  key: routineKey,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 24),
                    child: Column(
                      children: [
                        _CalendarColumnHeader(),
                        const SizedBox(height: 10),
                        ...days.asMap().entries.map((entry) {
                          return _CalendarDayRow(
                            dayIndex: entry.key,
                            dayName: days[entry.key],
                            courseColors: courseColors,
                            onCellTap: onCellTap,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CalendarColumnHeader extends StatelessWidget {
  const _CalendarColumnHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kHeaderTop, kHeaderBottom],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccent.withAlpha(60)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: kDayColWidth,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: kAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Day',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      color: kAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...times.map((t) => Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: kCellMargin / 2),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.white.withAlpha(18)),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t,
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.4,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _CalendarDayRow extends StatelessWidget {
  final int dayIndex;
  final String dayName;
  final Map<String, Color> courseColors;
  final void Function(int dayIndex, String time) onCellTap;

  const _CalendarDayRow({
    required this.dayIndex,
    required this.dayName,
    required this.courseColors,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: dayIndex.isEven ? kRowEven : kRowOdd,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: kDayColWidth,
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  dayName,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
          ),
          ...times.map((t) {
            final cells = routine[t];
            final cell = (cells != null && dayIndex < cells.length)
                ? cells[dayIndex]
                : RoutineCellData();
            return Expanded(
              child: _CalendarCell(
                cell: cell,
                accent: courseColors[_courseKey(cell.course)] ?? kAccent,
                onTap: () => onCellTap(dayIndex, t),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  final RoutineCellData cell;
  final Color accent;
  final VoidCallback onTap;

  const _CalendarCell({
    required this.cell,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool filled = !cell.isEmpty;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 64,
        child: Stack(
          children: [
            if (!filled)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: kCellMargin / 2,
                    vertical: 4,
                  ),
                  child:
                      CustomPaint(painter: _DashedBorderPainter(color: kCellBorder)),
                ),
              ),
            Container(
              margin: EdgeInsets.symmetric(
                horizontal: kCellMargin / 2,
                vertical: 4,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: filled
                    ? Color.alphaBlend(accent.withAlpha(20), kCellBg)
                    : kCellBg.withAlpha(140),
                borderRadius: BorderRadius.circular(12),
                border: filled
                    ? Border(left: BorderSide(color: accent, width: 3))
                    : null,
                boxShadow: filled
                    ? [
                        BoxShadow(
                          color: accent.withAlpha(25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: RoutineCell(cell, accent: accent),
            ),
          ],
        ),
      ),
    );
  }
}

// A light-weight dashed rounded-rect border used for empty calendar slots,
// to visually distinguish them from filled ones without relying on a solid
// outline.
class _DashedBorderPainter extends CustomPainter {
  final Color color;

  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 12.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const dashWidth = 5.0;
    const dashGap = 4.0;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

// =============================================================================
// Routine cell content (course / room / friends)
// =============================================================================
class RoutineCell extends StatelessWidget {
  final RoutineCellData data;
  final Color accent;
  const RoutineCell(this.data, {this.accent = kAccent, super.key});

  static const _monoStyle = TextStyle(fontFamily: 'JetBrains Mono');

  @override
  Widget build(BuildContext context) {
    if (data.course.trim().isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.course,
            style: _monoStyle.copyWith(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (data.room.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place_outlined, size: 11, color: kTextMuted),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      data.room,
                      style: _monoStyle.copyWith(color: kTextMuted, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          if (data.friends.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: kAccentBlue.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${data.friends.length} friend${data.friends.length > 1 ? 's' : ''}',
                  style: _monoStyle.copyWith(
                      color: kAccentBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
        ],
      );
    } else if (data.friends.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: kAccentBlue.withAlpha(30),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${data.friends.length} friend${data.friends.length > 1 ? 's' : ''}',
          style: _monoStyle.copyWith(
              color: kAccentBlue, fontSize: 13, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      );
    } else {
      return Icon(Icons.add_circle_outline, color: kCellBorder, size: 18);
    }
  }
}
