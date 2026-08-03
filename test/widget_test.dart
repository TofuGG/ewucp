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

    expect(find.text('Mon'), findsNothing);
    expect(find.text('Sun'), findsNothing);
  });

  testWidgets('RoutinePage renders days of the week', (WidgetTester tester) async {
    app.days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    await tester.pumpWidget(MaterialApp(home: const app.RoutinePage()));

    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Tue'), findsOneWidget);
    expect(find.text('Wed'), findsOneWidget);
    expect(find.text('Thu'), findsOneWidget);
    expect(find.text('Fri'), findsOneWidget);
    expect(find.text('Sat'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
  });

  testWidgets('header shows time labels after data loads',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: const _GridHost()));
    expect(find.text('10:10'), findsNothing);

    app.times = ['10:10AM-12:10PM', '11:50AM-1:20PM'];
    await tester.pumpWidget(MaterialApp(home: const _GridHost()));

    expect(find.text('10:10'), findsOneWidget);
    expect(find.text('12:10'), findsOneWidget);
    expect(find.text('11:50'), findsOneWidget);
    expect(find.text('1:20'), findsOneWidget);
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

    expect(find.text('Sun'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Tue'), findsNothing);
    expect(find.text('PHY109'), findsOneWidget);
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

    expect(find.text('Sun'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Tue'), findsOneWidget);
    expect(find.text('Wed'), findsNothing);
    expect(find.text('CSE110'), findsOneWidget);
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

    expect(find.text('Sun'), findsNothing);
    expect(find.text('Mon'), findsNothing);
    expect(find.text('10:10'), findsOneWidget);
    expect(find.text('12:10'), findsOneWidget);
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

    expect(find.text('Sun'), findsOneWidget);
    expect(find.text('PHY109'), findsOneWidget);

    await tester.tap(find.text('PHY109'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Sun'), findsNothing);
    expect(find.text('PHY109'), findsNothing);
    expect(find.text('10:10'), findsOneWidget);
    expect(find.text('12:10'), findsOneWidget);
  });

  testWidgets('full 7x8 grid fits a phone screen without overflow',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    app.times = [
      '8:30am-10:00am',
      '10:10am-11:40am',
      '11:50am-1:20pm',
      '1:30pm-3:00pm',
      '3:10pm-4:40pm',
      '4:50pm-6:20pm',
      '4:50pm-6:50pm',
      '4:50pm-7:50pm',
    ];
    app.days = [
      'Sunday', 'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday',
    ];
    for (final t in app.times) {
      app.routine[t] = List.generate(app.days.length, (_) => app.RoutineCellData());
    }
    app.routine['8:30am-10:00am']![0] =
        app.RoutineCellData(course: 'PHY109 (4)', room: '534');
    app.routine['10:10am-11:40am']![1] =
        app.RoutineCellData(course: 'CSE110 (12)', room: 'AB2-302');

    await tester.pumpWidget(MaterialApp(home: const app.RoutinePage()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Sun'), findsOneWidget);
    expect(find.text('PHY109'), findsOneWidget);
    expect(find.text('CSE110'), findsOneWidget);
  });
}
