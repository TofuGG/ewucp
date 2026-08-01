import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ewucp/calendar_view.dart';
import 'package:ewucp/main.dart' as app;

class _GridHost extends StatefulWidget {
  const _GridHost();
  @override
  State<_GridHost> createState() => _GridHostState();
}

class _GridHostState extends State<_GridHost> {
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return WeeklyCalendarGrid(
      routineKey: _key,
      onCellTap: (_, __) {},
    );
  }
}

String _encodeRoutine(Map<String, dynamic> map) =>
    base64Encode(zlib.encode(utf8.encode(jsonEncode(map))));

void main() {
  tearDown(() {
    app.times = [];
    app.routine.clear();
    app.days = [];
  });

  testWidgets('first launch renders a blank grid', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: const app.RoutinePage()));

    expect(find.text('Monday'), findsNothing);
    expect(find.text('Sunday'), findsNothing);
  });

  testWidgets('RoutinePage renders days of the week', (WidgetTester tester) async {
    app.days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    await tester.pumpWidget(MaterialApp(home: const app.RoutinePage()));

    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('Wednesday'), findsOneWidget);
    expect(find.text('Thursday'), findsOneWidget);
    expect(find.text('Friday'), findsOneWidget);
    expect(find.text('Saturday'), findsOneWidget);
    expect(find.text('Sunday'), findsOneWidget);
  });

  testWidgets('header shows time labels after data loads',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: const _GridHost()));
    expect(find.text('10:10AM-12:10PM'), findsNothing);

    app.times = ['10:10AM-12:10PM', '11:50AM-1:20PM'];
    await tester.pumpWidget(MaterialApp(home: const _GridHost()));

    expect(find.text('10:10AM-12:10PM'), findsOneWidget);
    expect(find.text('11:50AM-1:20PM'), findsOneWidget);
  });

  testWidgets('saved days are restored on launch', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'routine_times': jsonEncode(['10:10AM-12:10PM']),
      'routine_data': _encodeRoutine({
        '10:10AM-12:10PM': [
          {'course': 'PHY109 (4)', 'room': 'AB2-402', 'friends': <dynamic>[]},
        ],
      }),
      'routine_days': jsonEncode(['Sunday', 'Monday']),
    });

    await tester.pumpWidget(MaterialApp(home: const app.RoutinePage()));
    await tester.pumpAndSettle();

    expect(find.text('Sunday'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Tuesday'), findsNothing);
    expect(find.text('PHY109 (4)'), findsOneWidget);
  });

  testWidgets('legacy saves without days reconstruct columns',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'routine_times': jsonEncode(['10:10AM-12:10PM']),
      'routine_data': _encodeRoutine({
        '10:10AM-12:10PM': [
          {'course': 'CSE110 (12)', 'room': 'AB2-302', 'friends': <dynamic>[]},
          {'course': '', 'room': '', 'friends': <dynamic>[]},
          {'course': '', 'room': '', 'friends': <dynamic>[]},
        ],
      }),
    });

    await tester.pumpWidget(MaterialApp(home: const app.RoutinePage()));
    await tester.pumpAndSettle();

    expect(find.text('Sunday'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('Wednesday'), findsNothing);
    expect(find.text('CSE110 (12)'), findsOneWidget);
  });

  testWidgets('saved routine with no content loads blank',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'routine_times': jsonEncode(['10:10AM-12:10PM']),
      'routine_data': _encodeRoutine({
        '10:10AM-12:10PM': [
          {'course': '', 'room': '', 'friends': <dynamic>[]},
        ],
      }),
      'routine_days': jsonEncode(['Sunday', 'Monday', 'Tuesday']),
    });

    await tester.pumpWidget(MaterialApp(home: const app.RoutinePage()));
    await tester.pumpAndSettle();

    expect(find.text('Sunday'), findsNothing);
    expect(find.text('Monday'), findsNothing);
    expect(find.text('10:10AM-12:10PM'), findsOneWidget);
  });

  testWidgets('removing the last course hides the day columns',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    app.times = ['10:10AM-12:10PM'];
    app.routine['10:10AM-12:10PM'] = [
      app.RoutineCellData(course: 'PHY109 (4)', room: 'AB2-402'),
    ];
    app.days = ['Sunday'];

    await tester.pumpWidget(MaterialApp(home: const app.RoutinePage()));
    await tester.pump();

    expect(find.text('Sunday'), findsOneWidget);
    expect(find.text('PHY109 (4)'), findsOneWidget);

    await tester.tap(find.text('PHY109 (4)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Sunday'), findsNothing);
    expect(find.text('PHY109 (4)'), findsNothing);
    expect(find.text('10:10AM-12:10PM'), findsOneWidget);
  });
}
