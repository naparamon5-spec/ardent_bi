import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';

/// Auth + session, the mobile counterpart of `web/app/stores/auth.js`.
/// Also owns the configurable server URL (persisted on device), which the web
/// client gets from build-time config but a phone must be told at runtime.
class AuthState extends ChangeNotifier {
  static const _kToken = 'ardentbi_jwt';
  static const _kBase = 'ardentbi_base';
  static const defaultBase = 'http://localhost:4000';

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
    api.baseUrl = prefs.getString(_kBase) ?? defaultBase;
    api.token = prefs.getString(_kToken);
    if (api.token != null && api.token!.isNotEmpty) {
      await fetchMe();
    }
    booting = false;
    notifyListeners();
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
      return user;
    } on ApiException catch (e) {
      error = e.message;
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Bypass sign-in and browse the UI with canned data. No network, no token
  /// persisted — logging out returns to the login screen cleanly.
  void enterDemo() {
    api.demo = true;
    api.token = 'demo-token';
    user = {'id': 0, 'username': 'demo', 'name': 'Demo User', 'role': 'admin'};
    access = {'enforced': false, 'deny': false, 'level': 'executive'};
    notifyListeners();
  }

  bool get isDemo => api.demo;

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
    user = null;
    access = null;
    api.token = null;
    api.demo = false;
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
}
