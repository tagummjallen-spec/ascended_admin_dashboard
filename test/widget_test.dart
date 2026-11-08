import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Admin dashboard placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Ascended Admin Dashboard')),
      ),
    ));
    expect(find.text('Ascended Admin Dashboard'), findsOneWidget);
  });
}
