import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'state/auth_state.dart';
import 'theme.dart';

/// Launch-time app-version gate (mirrors ANI HRIS / eforward). Asks the backend
/// (GET /api/app-version) for the min/latest version for this platform and
/// decides whether to force (blocking) or offer (dismissible) an update. Any
/// failure resolves to "none" so a version check never keeps a user out.
enum UpdateAction { none, soft, forced }

class UpdateDecision {
  const UpdateDecision(this.action, [this.storeUrl]);
  final UpdateAction action;
  final String? storeUrl;
  static const none = UpdateDecision(UpdateAction.none);
}

class VersionGate {
  VersionGate._();

  static Future<UpdateDecision> check({String? baseUrl}) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      final platform = Platform.isAndroid ? 'android' : 'ios';
      final client = ApiClient(baseUrl: baseUrl ?? AuthState.defaultBase);

      final res = await client
          .get('/api/app-version?platform=$platform')
          .timeout(const Duration(seconds: 6));

      final Map data = (res is Map && res['data'] is Map)
          ? res['data'] as Map
          : (res is Map ? res : const {});

      final min = (data['minSupportedVersion'] ?? '').toString();
      final latest = (data['latestVersion'] ?? '').toString();
      final store = (data['storeUrl'] ?? '').toString();

      if (_isBelow(current, min)) {
        return UpdateDecision(UpdateAction.forced, store);
      }
      if (_isBelow(current, latest)) {
        return UpdateDecision(UpdateAction.soft, store);
      }
      return UpdateDecision.none;
    } catch (_) {
      return UpdateDecision.none;
    }
  }

  /// True when [version] is strictly older than [floor] ("1.2.0" < "1.10.0").
  static bool _isBelow(String version, String floor) {
    final a = _parts(version);
    final b = _parts(floor);
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final ai = i < a.length ? a[i] : 0;
      final bi = i < b.length ? b[i] : 0;
      if (ai != bi) return ai < bi;
    }
    return false;
  }

  static List<int> _parts(String v) => v
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p.trim()) ?? 0)
      .toList();
}

Future<void> _openStore(String? storeUrl) async {
  if (storeUrl == null || storeUrl.isEmpty) return;
  final uri = Uri.tryParse(storeUrl);
  if (uri == null) return;
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Blocking full-screen wall for a forced (mandatory) update.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key, this.storeUrl});

  final String? storeUrl;
  static const _navy = Color(0xFF133341);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: _navy,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update, color: Colors.white, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Update required',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A newer version of Ardent BI is required to continue. '
                  'Please update to keep using the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openStore(storeUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Update now',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dismissible "update available" prompt for a soft update.
Future<void> showSoftUpdateDialog(BuildContext context, {String? storeUrl}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Update available'),
      content: const Text(
        'A newer version of Ardent BI is available with improvements and fixes.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            _openStore(storeUrl);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
          ),
          child: const Text('Update'),
        ),
      ],
    ),
  );
}
