import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';

/// Auth + session, the mobile counterpart of `web/app/stores/auth.js`.
/// Also owns the configurable server URL (persisted on device), which the web
/// client gets from build-time config but a phone must be told at runtime.
class AuthState extends ChangeNotifier {
  static const _kToken = 'ardentbi_jwt';
  // Bumped from `ardentbi_base` so any stale localhost URL saved by an earlier
  // build is discarded and the .env / default is used instead.
  static const _kBase = 'ardentbi_base_v2';
  // Security (HRIS-style): auto sign-out after inactivity and on app termination.
  static const _kLastActive = 'ardentbi_last_active';
  static const _kRememberUser = 'ardentbi_remember_user';

  /// Idle window before the session is dropped, in the foreground and while
  /// backgrounded. Matches the HRIS mobile app's short lock timeout.
  static const sessionTimeout = Duration(minutes: 3);

  Timer? _idleTimer;
  DateTime _lastActive = DateTime.now();
  /// Live Ardent BI API. Read from `.env` (API_BASE_URL) when present, else this
  /// fallback. Overridable at runtime on the login screen (e.g.
  /// `http://<dev-machine-ip>:4000` when running the backend locally).
  static const _fallbackBase = 'https://ardentbi-api.ardentnetworks.com.ph';
  static String get defaultBase {
    final v = dotenv.isInitialized ? (dotenv.maybeGet('API_BASE_URL') ?? '') : '';
    return v.trim().isEmpty ? _fallbackBase : v.trim();
  }

  late ApiClient api;
  Map<String, dynamic>? user;
  Map<String, dynamic>? access;
  bool loading = false;
  bool booting = true;
  String? error;

  ApiClient get client => api;

  AuthState() {
    api = ApiClient(baseUrl: defaultBase);
    api.onUnauthorized = _forceSignedOut;
    _boot();
  }

  bool get isAuthenticated => user != null;
  bool get isAdmin => user?['role'] == 'admin';
  bool get canEdit => user?['role'] == 'admin' || user?['role'] == 'analyst';
  String get baseUrl => api.baseUrl;

  /// Re-Order Point is limited to executives and BU heads. Mirrors the web's
  /// `isBuHeadOrAbove` — presentation gating; the API is the real gate.
  bool get isBuHeadOrAbove =>
      const ['executive', 'salesBuHead', 'marketingBuHead'].contains(access?['level']);

  /// True when the resolved access rules claim no rows for this account.
  bool get hasNoData => (access?['enforced'] == true) && (access?['deny'] == true);

  /// A short description of any row-level narrowing, or null.
  String? get scopeNote {
    final a = access;
    if (a == null || a['enforced'] != true || a['deny'] == true) return null;
    switch (a['level']) {
      case 'salesBuHead':
        return 'Your team — ${a['salesmen']} salesmen';
      case 'marketingBuHead':
        return 'Your brands — ${a['brands']} of them';
      case 'accountManager':
        return 'Your own records';
    }
    return null;
  }

  String get initials {
    final name = (user?['name'] ?? user?['username'] ?? '').toString();
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    final i = parts.map((p) => p[0].toUpperCase()).join();
    return i.isEmpty ? '?' : i;
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kBase);
    // Ignore any stale local/dev URL saved on device; fall back to the
    // configured default so the app reaches the live API out of the box.
    final isLocal = saved != null &&
        (saved.contains('localhost') || saved.contains('127.0.0.1') || saved.contains('10.0.2.2'));
    api.baseUrl = (saved == null || saved.trim().isEmpty || isLocal) ? defaultBase : saved;
    api.token = prefs.getString(_kToken);

    if (api.token != null && api.token!.isNotEmpty) {
      // Idle-timeout gate: keep the session across app restarts/refreshes, and
      // only require a fresh sign-in once it has been idle longer than the
      // timeout window. (A plain restart within the window stays signed in.)
      final lastMs = prefs.getInt(_kLastActive);
      final expired = lastMs != null &&
          DateTime.now().millisecondsSinceEpoch - lastMs >
              sessionTimeout.inMilliseconds;
      if (expired) {
        api.token = null;
        await prefs.remove(_kToken);
        user = null;
      } else {
        await fetchMe();
      }
    }

    await _saveLastActive();
    if (isAuthenticated) _startIdleTimer();
    booting = false;
    notifyListeners();
  }

  // ── Session lifetime / auto-lock ───────────────────────────────────────────

  /// Reset the inactivity countdown. Called on every user interaction.
  void touch() {
    if (!isAuthenticated) return;
    _lastActive = DateTime.now();
    _startIdleTimer();
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(sessionTimeout, expireSession);
  }

  Future<void> _saveLastActive() async {
    _lastActive = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastActive, _lastActive.millisecondsSinceEpoch);
  }

  /// Drop the session locally (no server round-trip) and return to login.
  void expireSession() {
    _idleTimer?.cancel();
    _forceSignedOut();
  }

  /// App sent to the background / app switcher: stop the foreground timer and
  /// remember when we left so [handleResume] can enforce the idle window.
  Future<void> handlePause() async {
    _idleTimer?.cancel();
    if (isAuthenticated) await _saveLastActive();
  }

  /// App brought back to the foreground: sign out if the idle window elapsed
  /// while we were away, otherwise resume the countdown.
  Future<void> handleResume() async {
    if (!isAuthenticated) return;
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kLastActive);
    final expired = lastMs != null &&
        DateTime.now().millisecondsSinceEpoch - lastMs >
            sessionTimeout.inMilliseconds;
    if (expired) {
      expireSession();
    } else {
      touch();
    }
  }

  /// App is being terminated: just record when, so the idle window is enforced
  /// on the next launch. The token is kept, so a quick restart stays signed in.
  Future<void> handleDetached() async {
    if (isAuthenticated) await _saveLastActive();
  }

  /// "Remember me": the last username the user chose to keep (never the
  /// password). Prefilled on the login screen.
  Future<String?> rememberedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRememberUser);
  }

  Future<void> setRememberedUsername(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null || name.trim().isEmpty) {
      await prefs.remove(_kRememberUser);
    } else {
      await prefs.setString(_kRememberUser, name.trim());
    }
  }

  Future<void> setBaseUrl(String url) async {
    api.baseUrl = url.trim().isEmpty ? defaultBase : url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBase, api.baseUrl);
    notifyListeners();
  }

  Future<void> _persistToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (api.token == null) {
      await prefs.remove(_kToken);
    } else {
      await prefs.setString(_kToken, api.token!);
    }
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await api.post('/api/auth/login', {
        'username': username,
        'password': password,
      });
      api.token = res['token']?.toString();
      await _persistToken();
      user = (res['user'] as Map).cast<String, dynamic>();
      await fetchMe();
      await _saveLastActive();
      _startIdleTimer();
      return user;
    } on ApiException catch (e) {
      error = e.message;
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMe() async {
    if (api.token == null || api.token!.isEmpty) {
      user = null;
      return;
    }
    try {
      final res = await api.get('/api/auth/me');
      user = (res['user'] as Map).cast<String, dynamic>();
      access = res['access'] is Map ? (res['access'] as Map).cast<String, dynamic>() : null;
    } on ApiException {
      user = null;
      access = null;
      api.token = null;
      await _persistToken();
    }
    notifyListeners();
  }

  void _forceSignedOut() {
    _idleTimer?.cancel();
    user = null;
    access = null;
    api.token = null;
    _persistToken();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await api.post('/api/auth/logout');
    } catch (_) {
      // token may already be gone
    }
    _forceSignedOut();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }
}
