import 'package:flutter/material.dart';
import '../app.dart';
import '../services/auth_service.dart';

/// Second-factor verification screen shown after a password sign-in that
/// requires MFA.
///
/// The marketgo-api answers a password login with an MFA challenge instead of
/// a token pair; this screen collects the code delivered over the challenge
/// channels (email, WhatsApp) and hands the completed session back through
/// [onVerified]. Leaving the screen discards the challenge.
class MfaScreen extends StatefulWidget {
  const MfaScreen({
    super.key,
    required this.auth,
    required this.email,
    required this.onVerified,
  });

  final AuthModel auth;
  final String email;
  final VoidCallback onVerified;

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  final _codeController = TextEditingController();
  bool _verified = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Leaves the screen without a verified session, discarding the challenge.
  void _close() {
    if (!_verified) widget.auth.cancelMfa();
    Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final code = _codeController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (code.isEmpty) {
      widget.auth.error = 'Enter the verification code.';
      return;
    }
    final ok = await widget.auth.verifyMfaCode(code);
    if (!mounted || !ok) return;
    _verified = true;
    widget.onVerified();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _close();
      },
      child: ListenableBuilder(
        listenable: widget.auth,
        builder: (context, _) {
          final mfa = widget.auth.pendingMfa;
          final channels = mfa?.channels ?? const <String>[];
          final devCode = mfa?.devCode;
          final error = widget.auth.error;
          final loading = widget.auth.loading;
          return Scaffold(
            backgroundColor: CustomerApp.surfaceMuted,
            appBar: AppBar(
              backgroundColor: CustomerApp.surfaceMuted,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: true,
              title: const Text('Verification code'),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: CustomerApp.brandGreenLight,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.shield_outlined,
                        size: 36, color: CustomerApp.brandGreenDark),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Verification code',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    channels.contains('whatsapp')
                        ? 'We sent a code to ${widget.email} via WhatsApp and email.'
                        : 'We sent a code to ${widget.email}.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  if (devCode != null && devCode.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CustomerApp.brandGreenLight,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 20, color: CustomerApp.brandGreenDark),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Developer preview — your code is $devCode.',
                              style: TextStyle(
                                color: CustomerApp.brandGreenDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 8,
                    maxLines: 1,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      hintText: '123456',
                      counterText: '',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                  if (error != null) _ErrorBanner(message: error),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: loading ? null : _submit,
                      child: loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.6, color: Colors.white),
                            )
                          : const Text('Verify & continue'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: Color(0xFFB3261E), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF8F1D16),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
