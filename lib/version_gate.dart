import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'state/auth_state.dart';
import 'theme.dart';

/// Launch-time app-version gate — same contract and behavior as the ARM app
/// (both are UNLISTED distribution). Fetches the latest version + a direct
/// download URL from the backend (GET /api/app-version) and compares it
/// (semver) against the installed build. Fails open: any network/parse error
/// returns null so the app keeps working normally.

enum AppUpdateAction { none, soft, forced }

/// Compares semver only (e.g. `3.1.2`). Build numbers are ignored.
class AppComparableVersion implements Comparable<AppComparableVersion> {
  const AppComparableVersion({
    required this.major,
    required this.minor,
    required this.patch,
  });

  final int major;
  final int minor;
  final int patch;

  static AppComparableVersion? tryParse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return null;

    final normalized = trimmed.startsWith('v') || trimmed.startsWith('V')
        ? trimmed.substring(1)
        : trimmed;
    final core = normalized.split('+').first;
    final parts = core.split('.');
    if (parts.length < 2) return null;

    return AppComparableVersion(
      major: _leadingInt(parts[0]),
      minor: parts.length > 1 ? _leadingInt(parts[1]) : 0,
      patch: parts.length > 2 ? _leadingInt(parts[2]) : 0,
    );
  }

  static AppComparableVersion? fromVersionName(String v) => tryParse(v);

  static int _leadingInt(String s) {
    final m = RegExp(r'^\d+').firstMatch(s.trim());
    return m == null ? 0 : (int.tryParse(m.group(0)!) ?? 0);
  }

  @override
  int compareTo(AppComparableVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(AppComparableVersion other) => compareTo(other) < 0;
  bool operator >(AppComparableVersion other) => compareTo(other) > 0;

  @override
  String toString() => '$major.$minor.$patch';
}

class AppVersionInfo {
  const AppVersionInfo({
    required this.latestVersion,
    required this.downloadUrl,
    this.minSupportedVersion,
  });

  final AppComparableVersion latestVersion;
  final Uri downloadUrl;
  final AppComparableVersion? minSupportedVersion;
}

class AppVersionService {
  AppVersionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Without `platform` the backend defaults to android; iPhones need the iOS URL.
  static Uri get _endpoint => Uri.parse(
      '${AuthState.defaultBase.replaceAll(RegExp(r'/+$'), '')}'
      '/api/app-version?platform=${Platform.isIOS ? 'ios' : 'android'}');

  /// Below min -> forced wall. Below latest (at/above min) -> soft prompt.
  static AppUpdateAction decideUpdate(
    AppComparableVersion installed,
    AppVersionInfo remote,
  ) {
    final min = remote.minSupportedVersion;
    if (min != null && installed < min) return AppUpdateAction.forced;
    if (installed < remote.latestVersion) return AppUpdateAction.soft;
    return AppUpdateAction.none;
  }

  Future<AppVersionInfo?> fetchLatestVersion({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final res = await _client.get(_endpoint).timeout(timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;

      final dynamic decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;
      if (decoded is! Map) return null;
      final payload = decoded['data'] is Map ? decoded['data'] : decoded;

      // Backend shape (same as ARM):
      // { "application": "Ardent BI", "version": "1.0.3", "url": "…", "min_version": "1.0.0" }
      final latestStr = payload['version']?.toString().trim();
      final urlStr = payload['url']?.toString().trim();
      final minStr = (payload['min_version'] ??
              payload['minVersion'] ??
              payload['min_supported_version'] ??
              payload['minSupportedVersion'])
          ?.toString()
          .trim();

      if (latestStr == null || latestStr.isEmpty) return null;
      if (urlStr == null || urlStr.isEmpty) return null;

      final latest = AppComparableVersion.tryParse(latestStr);
      if (latest == null) return null;
      final url = Uri.tryParse(urlStr);
      if (url == null) return null;

      return AppVersionInfo(
        latestVersion: latest,
        downloadUrl: url,
        minSupportedVersion: (minStr == null || minStr.isEmpty)
            ? null
            : AppComparableVersion.tryParse(minStr),
      );
    } catch (e) {
      debugPrint('fetchLatestVersion failed: $e');
      return null;
    }
  }

  Future<AppComparableVersion?> getInstalledVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.trim();
      if (v.isEmpty) return null;
      return AppComparableVersion.fromVersionName(v);
    } catch (e) {
      debugPrint('getInstalledVersion failed: $e');
      return null;
    }
  }

  /// Fire-and-forget: iOS reports launchUrl's result unreliably.
  Future<bool> launchDownload(Uri url) async {
    try {
      // ignore: unawaited_futures
      launchUrl(url, mode: LaunchMode.externalApplication);
      return true;
    } catch (e) {
      debugPrint('launchDownload failed: $e');
      return false;
    }
  }

  void dispose() => _client.close();
}

Color get _brand => AppColors.brand;
Color get _brandDark => AppColors.brandDark;
const Color _muted = Color(0xFF6B7280);

Future<void> _openUpdate(AppVersionInfo remote) async {
  final svc = AppVersionService();
  try {
    await svc.launchDownload(remote.downloadUrl);
  } finally {
    svc.dispose();
  }
}

/// Dismissible "update available" card. Returns true if the user tapped Update.
Future<bool> showSoftUpdateDialog({
  required BuildContext context,
  required AppVersionInfo remote,
}) async {
  var updateInitiated = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) => _SoftUpdateCard(
      onLater: () => Navigator.of(dialogContext).pop(),
      onUpdate: () {
        Navigator.of(dialogContext).pop();
        updateInitiated = true;
        _openUpdate(remote);
      },
    ),
  );
  return updateInitiated;
}

/// Full-screen mandatory-update wall. Never dismisses itself.
Future<bool> showForceUpdateDialog({
  required BuildContext context,
  required AppVersionInfo remote,
}) async {
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    PageRouteBuilder<bool>(
      opaque: true,
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => _ForceUpdateScreen(remote: remote),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
  return result ?? false;
}

class _ForceUpdateScreen extends StatefulWidget {
  const _ForceUpdateScreen({required this.remote});
  final AppVersionInfo remote;

  @override
  State<_ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<_ForceUpdateScreen> {
  bool _busy = false;

  Future<void> _handleUpdate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _openUpdate(widget.remote);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_brand, _brandDark],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    height: 112,
                    width: 112,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(Icons.system_update_rounded,
                        color: Colors.white, size: 56),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Time to update',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'We’ve made important improvements to keep Ardent BI '
                    'running smoothly. Install the latest version to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white, fontSize: 15.5, height: 1.5),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _handleUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _brand,
                        disabledBackgroundColor:
                            Colors.white.withValues(alpha: 0.7),
                        disabledForegroundColor: _brand,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      child: _busy
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(_brand),
                              ),
                            )
                          : const Text('Update Now'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftUpdateCard extends StatelessWidget {
  const _SoftUpdateCard({required this.onUpdate, required this.onLater});

  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_brand, _brandDark],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    height: 72,
                    width: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(Icons.cloud_download_rounded,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'A fresh update is here',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Enjoy a smoother experience with the latest '
                    'improvements and fixes. Update when you’re ready.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 14.5, height: 1.45),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: TextButton(
                            onPressed: onLater,
                            style: TextButton.styleFrom(
                              foregroundColor: _muted,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(
                                    color: Color(0xFFE5E7EB), width: 1.2),
                              ),
                              textStyle: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('Later'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: onUpdate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('Update'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
