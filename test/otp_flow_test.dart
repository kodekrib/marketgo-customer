import 'dart:convert';

import 'package:customer/screens/otp_screen.dart';
import 'package:customer/services/api_client.dart';
import 'package:customer/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final length in [4, 8]) {
    testWidgets(
        '$length-digit phone challenge completes once with a resend cooldown',
        (tester) async {
      var verifications = 0;
      var completed = 0;
      String? submittedCode;
      final code = List.filled(length, '1').join();
      final api = ApiClient(httpClient: MockClient((request) async {
        switch (request.url.path) {
          case '/api/v1/auth/otp/send':
            return http.Response(
                jsonEncode({
                  'expires_in': 600,
                  'code_length': length,
                  'channels': ['whatsapp'],
                }),
                200);
          case '/api/v1/auth/otp/verify':
            verifications++;
            submittedCode = jsonDecode(request.body)['code'] as String;
            return http.Response(
                jsonEncode(
                    {'access_token': 'access', 'refresh_token': 'refresh'}),
                200);
          case '/api/v1/auth/me':
            return http.Response(
                jsonEncode({
                  'user': {'id': 7, 'name': 'Shopper', 'role': 'customer'}
                }),
                200);
          default:
            throw StateError('Unexpected request: ${request.url}');
        }
      }));
      final auth = AuthModel(api: api);
      await tester.pumpWidget(MaterialApp(
          home: OtpScreen(auth: auth, onVerified: () => completed++)));
      await tester.enterText(find.byType(TextField).first, '08031234567');
      await tester.tap(find.text('Send code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
          find.text(
              'We sent a $length-digit code to 08031234567 via WhatsApp.'),
          findsOneWidget);
      expect(find.text('Resend code in 0:60'), findsOneWidget);
      expect(find.text('Resend code'), findsNothing);
      final codeField = find.byWidgetPredicate(
          (widget) => widget is TextField && widget.maxLength == length);
      expect(codeField, findsOneWidget);
      await tester.enterText(codeField, code);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(verifications, 1);
      expect(submittedCode, code);
      expect(completed, 1);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    });
  }
}
