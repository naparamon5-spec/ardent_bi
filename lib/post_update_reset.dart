import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Post-update sign-out. On every launch we compare the installed app version
/// to the one recorded on the last launch. If it changed — the user just
/// installed a new build — we remove the persisted JWT so AuthState starts
/// signed out. New builds may change the auth contract, so stale credentials
/// shouldn't carry across upgrades.
///
/// Fails open: any error just skips the reset. Never blocks launch.
class PostUpdateReset {
  PostUpdateReset._();

  static const _kLastLaunchedVersion = 'ardentbi_last_launched_version';
  // Keys owned by AuthState — kept in sync with lib/state/auth_state.dart.
  static const _kToken = 'ardentbi_jwt';
  static const _kLastActive = 'ardentbi_last_active';

  /// Call once from `main()` BEFORE `runApp`.
  static Future<void> runIfVersionChanged() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version.trim();
      if (current.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(_kLastLaunchedVersion);

      if (last != null && last.isNotEmpty && last != current) {
        debugPrint('[PostUpdateReset] version changed $last → $current, '
            'clearing token');
        await prefs.remove(_kToken);
        await prefs.remove(_kLastActive);
      }
      await prefs.setString(_kLastLaunchedVersion, current);
    } catch (e) {
      debugPrint('[PostUpdateReset] skipped: $e');
    }
  }
}
