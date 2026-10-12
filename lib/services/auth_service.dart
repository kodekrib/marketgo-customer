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

/// Multi-factor challenge returned by password login when a second factor is
/// required. The code is delivered over [channels]; `devCode` is only returned
/// when the platform has developer preview enabled.
class MfaChallenge {
  const MfaChallenge({
    required this.mfaToken,
    required this.expiresIn,
    required this.channels,
    this.devCode,
  });

  final String mfaToken;
  final int expiresIn;
  final List<String> channels;
  final String? devCode;

  factory MfaChallenge.fromJson(Map<String, dynamic> json) {
    return MfaChallenge(
      mfaToken: json['mfa_token'] as String? ?? '',
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 600,
      channels: (json['channels'] as List?)?.map((e) => '$e').toList() ??
          const <String>[],
      devCode: json['dev_code'] as String?,
    );
  }
}

/// Outcome of a password sign-in: either a full token pair or an MFA
/// challenge the client must satisfy before tokens are issued.
class LoginResult {
  const LoginResult.success(this.tokens) : mfa = null;
  const LoginResult.mfaRequired(this.mfa) : tokens = null;

  final TokenPair? tokens;
  final MfaChallenge? mfa;
}

/// Calls the marketgo-api auth endpoints.
class AuthService {
  AuthService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  /// Signs in with email/password. The server may answer with either a token
  /// pair or an MFA challenge when two-factor verification is enabled.
  Future<LoginResult> signIn(String email, String password) async {
    final data = await api.post(
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    if (data['mfa_required'] == true) {
      return LoginResult.mfaRequired(MfaChallenge.fromJson(data));
    }
    return LoginResult.success(TokenPair.fromJson(data));
  }

  /// Exchanges an MFA challenge token and the received code for a token pair.
  Future<TokenPair> verifyMfa({
    required String mfaToken,
    required String code,
  }) async {
    final data = await api.post(
      '/api/v1/auth/mfa/verify',
      body: {'mfa_token': mfaToken, 'code': code},
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
  AuthModel({AuthService? service, ApiClient? api})
      : _service = service ?? AuthService(api: api),
        _api = api {
    // Transparent token refresh: the shared client consults this session for
    // the live token pair and retries once when the access token expires.
    _api?.tokenSource = TokenSource(
      getAccessToken: () => _accessToken,
      getRefreshToken: () => _refreshToken,
      store: ({required String accessToken, required String refreshToken}) {
        _accessToken = accessToken;
        _refreshToken = refreshToken;
      },
      onExpired: _expireSession,
    );
  }

  final AuthService _service;
  final ApiClient? _api;

  AuthUser? _user;
  String? _accessToken;
  String? _refreshToken;
  MfaChallenge? _pendingMfa;
  bool _loading = false;
  String? _error;

  AuthUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;
  String? get error => _error;

  /// The MFA challenge awaiting a code after a password sign-in that requires
  /// a second factor. Null unless the server interrupted the login.
  MfaChallenge? get pendingMfa => _pendingMfa;

  /// The bearer token used to call authenticated endpoints. Null while signed
  /// out.
  String? get accessToken => _accessToken;

  /// The shared network client so screens build services with the same offline
  /// state and base URL as this session.
  ApiClient get api => _service.api;

  /// Surface client-side validation messages (e.g. missing email).
  set error(String? value) {
    _error = value;
    notifyListeners();
  }

  /// Shared post-token work: loads the profile, stores the session tokens and
  /// flips the shared client back to online mode. Returns false (with [_error]
  /// set) when the profile cannot be loaded.
  Future<bool> _completeSignIn(TokenPair tokens) async {
    // Store the fresh pair before loading the profile: the shared client
    // stamps the live token onto authenticated requests, so `me()` must see
    // this new token (and be able to refresh it) rather than the old one.
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    try {
      final user = await _service.me(tokens.accessToken);
      _api?.isOffline = false;
      _user = user;
      return true;
    } on ApiException catch (e) {
      // Roll back the half-established session so a failed profile load does
      // not leave dangling tokens behind.
      _accessToken = null;
      _refreshToken = null;
      _error = e.message;
      return false;
    }
  }

  /// Signs in with email/password. Returns false without an error when the
  /// server demands a second factor — the screen then checks [pendingMfa] and
  /// routes to the MFA code screen.
  Future<bool> signIn(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _service.signIn(email.trim(), password);
      if (result.mfa != null) {
        _pendingMfa = result.mfa;
        _error = null;
        return false;
      }
      _pendingMfa = null;
      return await _completeSignIn(result.tokens!);
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Completes a login interrupted by an MFA challenge: verifies the code and
  /// enters an authenticated session (same state transitions as [signIn]).
  Future<bool> verifyMfaCode(String code) async {
    final challenge = _pendingMfa;
    if (challenge == null) {
      _error = 'No verification code was requested.';
      notifyListeners();
      return false;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final tokens = await _service.verifyMfa(
        mfaToken: challenge.mfaToken,
        code: code,
      );
      _pendingMfa = null;
      return await _completeSignIn(tokens);
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Discards a pending MFA challenge (e.g. the shopper navigated back).
  void cancelMfa() {
    _pendingMfa = null;
    _error = null;
    notifyListeners();
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
      return await _completeSignIn(tokens);
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Clears the session without a network call, used when a token refresh is
  /// rejected (revoked refresh token, disabled account, or server restart
  /// which rotates the signing key).
  void _expireSession() {
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _error = 'Your session has expired. Please sign in again.';
    notifyListeners();
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