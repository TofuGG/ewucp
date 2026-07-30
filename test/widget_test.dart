import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ewucp/main.dart' as app;

void main() {
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
}
