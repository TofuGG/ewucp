import 'package:flutter/material.dart';
import 'planner_core.dart';

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

// A lightweight "routine content version" hash. Only course labels affect the
// color assignment, so the version tracks cell counts and course strings. The
// VM caches String.hashCode, so computing this stays cheap, letting
// _courseColors() skip its regex-heavy set/sort/build path on every unrelated
// rebuild (theme change, dialog open, plain setState).
int _routineVersion() {
  var hash = 17;
  hash = hash * 31 + routine.length;
  for (final cells in routine.values) {
    hash = hash * 31 + cells.length;
    for (final c in cells) {
      hash = hash * 31 + c.course.length;
      hash = hash * 31 + c.course.hashCode;
    }
  }
  return hash;
}

int _cachedVersion = -1;
Map<String, Color>? _cachedCourseColors;

// Maps every distinct course code in the routine to a palette color, sorted
// alphabetically so the assignment is deterministic across rebuilds. Results
// are memoized against _routineVersion() so repeated lookups during rebuilds
// don't redo the work.
Map<String, Color> _courseColors() {
  final version = _routineVersion();
  if (_cachedCourseColors == null || version != _cachedVersion) {
    final names = <String>{};
    for (final cells in routine.values) {
      for (final c in cells) {
        final n = _courseKey(c.course);
        if (n.isNotEmpty) names.add(n);
      }
    }
    final sorted = names.toList()..sort();
    _cachedCourseColors = {
      for (var i = 0; i < sorted.length; i++)
        sorted[i]: _coursePalette[i % _coursePalette.length],
    };
    _cachedVersion = version;
  }
  return _cachedCourseColors!;
}

// Public helper so the dialogs in main.dart can color a course card with the
// same palette color that the grid uses for that course.
Color courseColorFor(String course) {
  final colors = _courseColors();
  return colors[_courseKey(course)] ?? kAccent;
}

// =============================================================================
// Calendar UI layer
//
// This file contains ONLY presentation / layout widgets for the weekly
// calendar. It reads the shared app state and brand palette from
// planner_core.dart and the Material 3 ColorScheme from the ambient Theme, but
// holds no business logic itself — all data mutation, persistence, dialogs,
// and FAB behavior stay in main.dart's _RoutinePageState untouched.
//
// Layout model: the calendar is designed to fit the whole grid on screen.
// The day-label column grows from kDayColWidth up to kMaxDayColWidth using
// leftover width; the time-slot columns and day-row heights split the
// remaining space, clamped to comfortable minimums. Scrolling is only a
// fallback when a phone is too small for even the minimum cell sizes.
// =============================================================================

const double _kHeaderHeight = 48;
const double _kRowGap = 6;

// Splits a stored time range into compact start/end labels for the narrow
// header columns: "8:30am-10:00am" -> ["8:30", "10:00"].
List<String> _timeParts(String t) {
  String norm(String s) {
    final trimmed = s.trim();
    final m = RegExp(r'^(\d{1,2}:\d{2})[aApP][mM]$').firstMatch(trimmed);
    return m != null ? m.group(1)! : trimmed;
  }

  final parts = t.split('-');
  if (parts.length == 2) {
    final a = norm(parts[0]);
    final b = norm(parts[1]);
    if (a.isNotEmpty && b.isNotEmpty && a != b) return [a, b];
  }
  return [t.trim()];
}

String _dayShortName(String name) {
  const short = {
    'Sunday': 'Sun',
    'Monday': 'Mon',
    'Tuesday': 'Tue',
    'Wednesday': 'Wed',
    'Thursday': 'Thu',
    'Friday': 'Fri',
    'Saturday': 'Sat',
  };
  return short[name] ?? (name.isEmpty ? name : name.substring(0, 3));
}

// A human-readable accessibility label describing a single calendar slot.
String _cellSemanticsLabel(RoutineCellData cell, String time) {
  if (cell.isEmpty) return 'Empty time slot at $time.';
  final parts = <String>[
    if (cell.course.trim().isNotEmpty) cell.course.trim(),
    if (cell.room.trim().isNotEmpty) 'room ${cell.room.trim()}',
    if (cell.friends.isNotEmpty)
      '${cell.friends.length} friend${cell.friends.length == 1 ? '' : 's'}',
  ];
  return '${parts.join(', ')} at $time.';
}

// ------------------------------------------------------------------------
// App bar
// ------------------------------------------------------------------------
class CalendarHeaderBar extends StatelessWidget
    implements PreferredSizeWidget {
  const CalendarHeaderBar({super.key, this.onMenuTap});

  final VoidCallback? onMenuTap;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.surfaceContainerHighest, scheme.surfaceContainerHigh],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: scheme.primary.withValues(alpha: 0.5), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
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
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onMenuTap,
                  tooltip: 'Menu',
                  icon: Icon(Icons.menu, color: scheme.primary, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Tofu Routine',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        color: scheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 21,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'EWU COURSE PLANNER',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        color: scheme.primary.withValues(alpha: 0.82),
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
  final VoidCallback? onImportSlip;
  final VoidCallback? onAddSlot;

  const WeeklyCalendarGrid({
    super.key,
    required this.routineKey,
    required this.onCellTap,
    this.onImportSlip,
    this.onAddSlot,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.surfaceContainerHigh, scheme.surfaceContainerLowest],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (days.isEmpty && times.isEmpty) {
            return RepaintBoundary(
              key: routineKey,
              child: _EmptyState(
                onImport: onImportSlip,
                onAddSlot: onAddSlot,
              ),
            );
          }

          const double hPad = 12;
          final double availW = constraints.maxWidth - hPad * 2;

          // Day-label column gets ~15% of the leftover width (shrunk so time
          // columns stay readable); time columns split the rest.
          const double dayColShrink = 0.85;
          final double dayColW = times.isEmpty
              ? availW.clamp(kDayColWidth, kMaxDayColWidth)
              : ((availW - times.length * kMinTimeColWidth) * dayColShrink)
                  .clamp(kDayColWidth, kMaxDayColWidth);
          double timeColW =
              times.isEmpty ? 0 : (availW - dayColW) / times.length;
          final bool needHScroll =
              times.isNotEmpty && timeColW < kMinTimeColWidth;
          if (needHScroll) timeColW = kMinTimeColWidth;
          final double tableW = dayColW + times.length * timeColW;

          // Row heights fill the body, clamped to a comfortable range. The
          // bottom padding clears the floating FAB.
          const double vPadTop = 10;
          const double vPadBottom = 88;
          const double rowOuter = 8; // 3 top + 3 bottom padding + 2px border
          final double gaps = days.isEmpty ? 0 : days.length * _kRowGap;
          final double availH = constraints.maxHeight -
              vPadTop -
              vPadBottom -
              _kHeaderHeight -
              gaps -
              days.length * rowOuter;
          final double rowH = days.isEmpty
              ? kMinRowHeight
              : (availH / days.length).clamp(kMinRowHeight, kMaxRowHeight);
          final double totalH = vPadTop +
              _kHeaderHeight +
              gaps +
              days.length * (rowH + rowOuter) +
              vPadBottom;
          final bool needVScroll = totalH > constraints.maxHeight;

          final Map<String, Color> courseColors = _courseColors();

          final Widget grid = Semantics(
            container: true,
            label: 'Weekly course calendar',
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(hPad, vPadTop, hPad, vPadBottom),
              child: Column(
                children: [
                  _CalendarColumnHeader(dayColW: dayColW),
                  const SizedBox(height: _kRowGap),
                  ...days.asMap().entries.map((entry) => _CalendarDayRow(
                        dayIndex: entry.key,
                        dayName: days[entry.key],
                        dayColW: dayColW,
                        rowH: rowH,
                        courseColors: courseColors,
                        onCellTap: onCellTap,
                      )),
                ],
              ),
            ),
          );

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: needHScroll ? null : const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: needHScroll ? tableW + hPad * 2 : constraints.maxWidth,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                physics: needVScroll ? null : const NeverScrollableScrollPhysics(),
                child: RepaintBoundary(
                  key: routineKey,
                  child: grid,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback? onImport;
  final VoidCallback? onAddSlot;

  const _EmptyState({this.onImport, this.onAddSlot});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.surfaceContainerHighest, scheme.surfaceContainerHigh],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: scheme.primary.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(Icons.calendar_month_rounded, color: scheme.primary, size: 44),
            ),
            const SizedBox(height: 22),
            Text(
              'No classes yet',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                color: scheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Import your advising slip to auto-build\nyour weekly routine, or add time slots\nmanually.',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            if (onImport != null) ...[
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text(
                  'Import Advising Slip',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            if (onAddSlot != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onAddSlot,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.secondary,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Add Time Slot',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarColumnHeader extends StatelessWidget {
  final double dayColW;

  const _CalendarColumnHeader({required this.dayColW});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: _kHeaderHeight,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.surfaceContainerHighest, scheme.surfaceContainerHigh],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: dayColW,
              child: Center(
                child: Icon(Icons.schedule_rounded,
                    color: scheme.primary.withValues(alpha: 0.78), size: 16),
              ),
            ),
            ...times.map((t) => Expanded(
                  child: Center(child: _TimeLabel(t)),
                )),
          ],
        ),
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  final String time;

  const _TimeLabel(this.time);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final parts = _timeParts(time);
    if (parts.length == 1) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          parts[0],
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            parts[0],
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              height: 1.15,
            ),
            maxLines: 1,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            parts[1],
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              color: scheme.primary.withValues(alpha: 0.78),
              fontSize: 10,
              height: 1.15,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

class _CalendarDayRow extends StatelessWidget {
  final int dayIndex;
  final String dayName;
  final double dayColW;
  final double rowH;
  final Map<String, Color> courseColors;
  final void Function(int dayIndex, String time) onCellTap;

  const _CalendarDayRow({
    required this.dayIndex,
    required this.dayName,
    required this.dayColW,
    required this.rowH,
    required this.courseColors,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: _kRowGap),
      padding: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: dayIndex.isEven ? scheme.surfaceContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: dayColW,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _dayShortName(dayName),
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: dayIndex.isEven ? scheme.onSurface : scheme.primary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
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
                time: t,
                height: rowH,
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
  final String time;
  final double height;
  final Color accent;
  final VoidCallback onTap;

  const _CalendarCell({
    required this.cell,
    required this.time,
    required this.height,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool filled = !cell.isEmpty;
    // Every slot is described for screen readers so a bare GestureDetector is
    // never the only affordance.
    return Semantics(
      label: _cellSemanticsLabel(cell, time),
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              if (!filled)
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: kCellMargin / 2,
                      vertical: 2,
                    ),
                    child: CustomPaint(
                      painter: _DashedBorderPainter(color: scheme.outlineVariant),
                    ),
                  ),
                ),
              Container(
                margin: EdgeInsets.symmetric(
                  horizontal: kCellMargin / 2,
                  vertical: 2,
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: filled
                      ? Color.alphaBlend(accent.withValues(alpha: 0.08), scheme.surface)
                      : scheme.surface.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                  border: filled
                      ? Border(left: BorderSide(color: accent, width: 3))
                      : null,
                  boxShadow: filled
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.1),
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
    const radius = 10.0;
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
//
// Compact rendering: only the short course code, room number, and a gold
// friend-count pill are shown so the whole grid fits on screen. Full details
// (full course label, section, room) appear in the tap dialog in main.dart.
// =============================================================================
class RoutineCell extends StatelessWidget {
  final RoutineCellData data;
  final Color accent;
  const RoutineCell(this.data, {this.accent = kAccent, super.key});

  static const _monoStyle = TextStyle(fontFamily: 'JetBrains Mono');

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (data.course.trim().isNotEmpty) {
      // Whole block wrapped in a scaling FittedBox so the 10-11px labels never
      // overflow a compact row; each line still ellipsizes as a fallback.
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _courseKey(data.course),
              style: _monoStyle.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                height: 1.15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (data.room.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.place_outlined,
                        size: 10, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text(
                      data.room,
                      style: _monoStyle.copyWith(
                          color: scheme.onSurfaceVariant, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            if (data.friends.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_rounded,
                          size: 10, color: scheme.secondary),
                      const SizedBox(width: 3),
                      Text(
                        '${data.friends.length}',
                        style: _monoStyle.copyWith(
                            color: scheme.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    } else if (data.friends.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_rounded, size: 11, color: scheme.secondary),
            const SizedBox(width: 3),
            Text(
              '${data.friends.length}',
              style: _monoStyle.copyWith(
                  color: scheme.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    } else {
      return Icon(Icons.add_circle_outline, color: scheme.outline, size: 16);
    }
  }
}
