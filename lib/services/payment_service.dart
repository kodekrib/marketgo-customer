import 'api_client.dart';

class PaymentService {
  PaymentService({ApiClient? api}) : api = api ?? ApiClient();
  final ApiClient api;

  Map<String, String> _auth(String token) => {
        'Authorization': 'Bearer $token',
      };

  /// Initialize a payment with the configured gateway.
  Future<Map<String, dynamic>> initPayment(
    String token, {
    required int orderId,
    required double amount,
    required String email,
  }) async {
    final data = await api.post(
      '/api/v1/customer/payments/init',
      headers: _auth(token),
      body: {
        'order_id': orderId,
        'amount': amount,
        'email': email,
      },
    );
    return data;
  }

  /// Verify a payment reference.
  Future<Map<String, dynamic>> verifyPayment(
    String token, {
    required String reference,
  }) async {
    final data = await api.post(
      '/api/v1/customer/payments/verify',
      headers: _auth(token),
      body: {'reference': reference},
    );
    return data;
  }

  /// Fetch list of banks from the payment gateway.
  Future<List<Map<String, String>>> listBanks() async {
    final data = await api.get('/api/v1/banks');
    final banks = data['banks'] as List<dynamic>? ?? [];
    return banks
        .map((b) => {
              'name': b['name'].toString(),
              'code': b['code'].toString(),
            })
        .toList();
  }

  /// Resolve an account name from bank code and account number.
  Future<Map<String, String>?> resolveAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    final data = await api.get(
      '/api/v1/banks/resolve?bank_code=$bankCode&account_number=$accountNumber',
    );
    if (data['account_name'] != null) {
      return {
        'account_name': data['account_name'].toString(),
        'account_number': data['account_number'].toString(),
        'bank_code': data['bank_code'].toString(),
      };
    }
    return null;
  }
}
