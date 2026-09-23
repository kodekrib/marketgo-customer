import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// The signed-in shopper profile returned by /api/v1/auth/me.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  final String id;
  final String email;
  final String name;
  final String role;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: '${json['id']}',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
    );
  }

  String get firstName {
    final trimmed = name.trim();
    final space = trimmed.indexOf(' ');
    return space == -1 ? trimmed : trimmed.substring(0, space);
  }
}

class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
    );
  }
}

/// Result of requesting an OTP code, including the delivery channels used
/// and how long the code stays valid. `devCode` is only returned when the
/// platform has developer preview enabled.
class SendOtpResult {
  const SendOtpResult({
    required this.expiresIn,
    required this.channels,
    this.devCode,
  });

  final int expiresIn;
  final List<String> channels;
  final String? devCode;

  factory SendOtpResult.fromJson(Map<String, dynamic> json) {
    return SendOtpResult(
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 600,
      channels: (json['channels'] as List?)?.map((e) => '$e').toList() ??
          const <String>[],
      devCode: json['dev_code'] as String?,
    );
  }
}

/// Calls the marketgo-api auth endpoints.
class AuthService {
  AuthService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Future<TokenPair> signIn(String email, String password) async {
    final data = await api.post(
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    return TokenPair.fromJson(data);
  }

  /// Requests a one-time code delivered over WhatsApp and/or email. The phone
  /// is sent as typed; the backend normalises it to international format.
  Future<SendOtpResult> sendOtp({
    required String phone,
    String? email,
    String? name,
    String role = 'customer',
  }) async {
    final data = await api.post(
      '/api/v1/auth/otp/send',
      body: <String, dynamic>{
        'phone': phone,
        'role': role,
        if (email != null && email.isNotEmpty) 'email': email,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
    return SendOtpResult.fromJson(data);
  }

  /// Exchanges the received code for a token pair, creating the account on
  /// first sign-in for the given role.
  Future<TokenPair> verifyOtp({
    required String phone,
    required String code,
    String? name,
    String role = 'customer',
  }) async {
    final data = await api.post(
      '/api/v1/auth/otp/verify',
      body: <String, dynamic>{
        'phone': phone,
        'code': code,
        'role': role,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    );
    return TokenPair.fromJson(data);
  }

  Future<AuthUser> me(String accessToken) async {
    final data = await api.get(
      '/api/v1/auth/me',
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final user = data['user'];
    if (user is Map<String, dynamic>) return AuthUser.fromJson(user);
    throw const ApiException('Unexpected profile payload');
  }

  Future<void> signOut(String accessToken, String refreshToken) async {
    await api.post(
      '/api/v1/auth/logout',
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'refresh_token': refreshToken},
    );
  }
}

/// Reactive auth state owned by the app shell so the storefront, account,
/// orders and cart all read from the same source of truth.
///
/// Shoppers can browse the catalogue while signed out; sign-in is only
/// required for checkout, orders and account.
class AuthModel extends ChangeNotifier {
  AuthModel({AuthService? service, ApiClient? api, this.onOfflineChanged})
      : _service = service ?? AuthService(api: api),
        _api = api;

  final AuthService _service;
  final ApiClient? _api;

  /// Called whenever the network availability flips (demo session on/off) so
  /// the app shell can short-circuit API calls sharing the [_api] client.
  final void Function(bool offline)? onOfflineChanged;

  AuthUser? _user;
  String? _accessToken;
  String? _refreshToken;
  bool _loading = false;
  String? _error;

  AuthUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;
  String? get error => _error;

  /// The bearer token used to call authenticated endpoints. Null while signed
  /// out. Demo sessions carry a placeholder token that services treat as
  /// offline (screens fall back to local demo data until a real login).
  String? get accessToken => _accessToken;

  /// The shared network client so screens build services with the same offline
  /// state and base URL as this session.
  ApiClient get api => _service.api;

  /// Server-less login so the app can be explored before the backend (or its
  /// database) is up. Enters an authenticated demo session immediately.
  void enterDemoMode() {
    _user = const AuthUser(
      id: 'demo-customer',
      email: 'customer@test.marketgo',
      name: 'Demo Customer',
      role: 'customer',
    );
    _accessToken = 'demo.access';
    _refreshToken = 'demo.refresh';
    _loading = false;
    _error = null;
    _api?.isOffline = true;
    onOfflineChanged?.call(true);
    notifyListeners();
  }

  /// Surface client-side validation messages (e.g. missing email).
  set error(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final tokens = await _service.signIn(email.trim(), password);
      final user = await _service.me(tokens.accessToken);
      _api?.isOffline = false;
      onOfflineChanged?.call(false);
      _accessToken = tokens.accessToken;
      _refreshToken = tokens.refreshToken;
      _user = user;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Requests an OTP code for the given phone. Loading/error state for the
  /// code request lives on the OTP screen; the result carries the dev code.
  Future<SendOtpResult> sendOtp(String phone, {String? email}) {
    return _service.sendOtp(phone: phone, email: email, role: 'customer');
  }

  /// Completes phone sign-in: verifies the code, loads the profile and enters
  /// an authenticated session (same state transitions as [signIn]).
  Future<bool> signInWithOtp(String phone, String code) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final tokens =
          await _service.verifyOtp(phone: phone, code: code, role: 'customer');
      final user = await _service.me(tokens.accessToken);
      _api?.isOffline = false;
      onOfflineChanged?.call(false);
      _accessToken = tokens.accessToken;
      _refreshToken = tokens.refreshToken;
      _user = user;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final token = _accessToken;
    final refresh = _refreshToken;
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _error = null;
    notifyListeners();
    if (token != null && refresh != null) {
      // Best-effort server-side revocation.
      try {
        await _service.signOut(token, refresh);
      } catch (_) {}
    }
  }
}