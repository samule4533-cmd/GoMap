import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gomap/main.dart';

void main() {
  testWidgets('GoMapApp boots', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GoMapApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
