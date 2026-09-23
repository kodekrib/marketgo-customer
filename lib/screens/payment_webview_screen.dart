import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens the payment gateway's authorization URL in a WebView.
/// When the user completes payment, the gateway redirects to a callback URL.
/// We detect success/failure by monitoring URL changes.
class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String reference;
  final String gateway; // 'paystack' or 'flutterwave'

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.reference,
    required this.gateway,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            final url = request.url;
            // Detect payment completion redirects.
            if (_isSuccessUrl(url)) {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            if (_isFailureUrl(url)) {
              Navigator.of(context).pop(false);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  bool _isSuccessUrl(String url) {
    final lower = url.toLowerCase();
    if (widget.gateway == 'paystack') {
      return lower.contains('paystack') &&
          (lower.contains('trxref=') || lower.contains('reference='));
    }
    // Flutterwave
    return lower.contains('flutterwave') &&
        (lower.contains('status=successful') || lower.contains('status=success'));
  }

  bool _isFailureUrl(String url) {
    final lower = url.toLowerCase();
    if (widget.gateway == 'paystack') {
      return lower.contains('paystack') && lower.contains('status=failed');
    }
    return lower.contains('flutterwave') &&
        (lower.contains('status=failed') || lower.contains('status=cancelled'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pay with ${widget.gateway == 'paystack' ? 'Paystack' : 'Flutterwave'}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
