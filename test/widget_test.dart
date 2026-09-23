import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer/app.dart';
import 'package:customer/widgets/route_animation.dart';

void main() {
  setUpAll(() => kRouteAnimationEnabled = false);

  testWidgets('Customer marketplace is visible before login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CustomerApp());

    expect(find.text('Good morning!'), findsOneWidget);
    expect(find.text('Popular Stores'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('Orders tab prompts for sign in while browsing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CustomerApp());

    await tester.tap(find.text('Orders'));
    await tester.pump();

    expect(find.text('Track your orders'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('Account tab prompts for sign in while browsing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CustomerApp());

    await tester.tap(find.text('Account'));
    await tester.pump();

    expect(find.text('Sign in to your account'), findsOneWidget);
  });

  testWidgets('Login screen can be reached from browse shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CustomerApp());

    await tester.tap(find.text('Account'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);
  });
}