// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sleep_tracker/main.dart';

void main() {
  testWidgets('Sleep tracker app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SleepTrackerApp());

    // Verify that our initial state is correct
    expect(find.text('暂无数据'), findsOneWidget);
    expect(find.text('刷新睡眠数据'), findsOneWidget);

    // Verify that version text is present
    expect(find.text('更新版本 - V1.0.5'), findsOneWidget);
  });
}
