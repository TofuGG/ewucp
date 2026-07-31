import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  tearDown(() {
    app.times = [];
    app.routine.clear();
  });

  testWidgets('RoutinePage renders days of the week', (WidgetTester tester) async {
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
}
