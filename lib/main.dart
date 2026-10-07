import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'state/auth_state.dart';
import 'state/filter_state.dart';
import 'state/ui_state.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/app_lifecycle_guard.dart';
import 'widgets/loading_overlay.dart';
import 'version_gate.dart';
import 'post_update_reset.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load runtime config (API_BASE_URL, etc.) from the bundled .env. Missing or
  // empty is fine — AuthState falls back to its built-in default.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env not bundled; defaults apply.
  }
  // Load locale data so DateFormat('en_PH') works (Fmt.date on the Sales list).
  await initializeDateFormatting('en_PH');
  // Post-update sign-out: if the installed app version changed since the last
  // launch, drop the stored JWT so the user signs in again on the fresh
  // build. Fails open — never blocks launch.
  await PostUpdateReset.runIfVersionChanged();
  runApp(ArdentBiApp());
}

class ArdentBiApp extends StatelessWidget {
  ArdentBiApp({super.key});

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => FilterState()),
        ChangeNotifierProvider(create: (_) => LoadingState()),
      ],
      child: MaterialApp(
        title: 'Ardent BI',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navKey,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        // Security + loading layers wrap every route: the lifecycle guard adds
        // the app-switcher privacy splash and auto-lock; the blurred loader
        // sits on top of content.
        builder: (context, child) => AppLifecycleGuard(
          navigatorKey: _navKey,
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              const Positioned.fill(child: GlobalLoadingOverlay()),
            ],
          ),
        ),
        home: const _Root(),
      ),
    );
  }
}

/// Chooses login vs. app based on auth state — the mobile equivalent of the
/// web's global auth middleware. Also runs the launch-time app-version gate:
/// a forced update replaces everything with a blocking wall; a soft update is
/// shown as a dismissible dialog after routing.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> with WidgetsBindingObserver {
  AppUpdateAction _action = AppUpdateAction.none;
  AppVersionInfo? _remote;
  bool _versionChecked = false;
  bool _promptShown = false;
  // Resume re-check: a version released while the app sat in memory must
  // still prompt without the user killing the app from multitask. Throttled
  // so quick app switches (e.g. copying an OTP) don't re-hit the endpoint.
  static const _recheckInterval = Duration(minutes: 1);
  DateTime? _lastCheckAt;
  bool _checkInProgress = false;
  bool _promptVisible = false;
  // Soft prompt shows at most once per launch; the forced wall always returns.
  bool _softShownThisLaunch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runVersionCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_versionChecked || _checkInProgress || _promptVisible) return;
    final last = _lastCheckAt;
    if (last != null && DateTime.now().difference(last) < _recheckInterval) {
      return;
    }
    _recheckOnResume();
  }

  Future<void> _recheckOnResume() async {
    await _runVersionCheck();
    if (!mounted || _remote == null || _promptVisible) return;
    if (_action == AppUpdateAction.none) return;
    if (_action == AppUpdateAction.soft && _softShownThisLaunch) return;
    _showPrompt();
  }

  Future<void> _runVersionCheck() async {
    if (_checkInProgress) return;
    _checkInProgress = true;
    final svc = AppVersionService();
    try {
      final current = await svc.getInstalledVersion();
      final remote = await svc.fetchLatestVersion();
      if (!mounted) return;
      _lastCheckAt = DateTime.now();
      final action = (current != null && remote != null)
          ? AppVersionService.decideUpdate(current, remote)
          : AppUpdateAction.none;
      setState(() {
        // A failed fetch on resume keeps the last known result (fails open
        // only when nothing is known yet).
        if (remote != null || !_versionChecked) {
          _action = action;
          _remote = remote;
        }
        _versionChecked = true;
      });
    } finally {
      _checkInProgress = false;
      svc.dispose();
    }
  }

  Future<void> _showPrompt() async {
    final remote = _remote;
    if (remote == null || _promptVisible) return;
    _promptVisible = true;
    if (_action == AppUpdateAction.soft) _softShownThisLaunch = true;
    try {
      if (_action == AppUpdateAction.forced) {
        await showForceUpdateDialog(context: context, remote: remote);
      } else {
        await showSoftUpdateDialog(context: context, remote: remote);
      }
    } finally {
      _promptVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    if (auth.booting || !_versionChecked) {
      return const SplashScreen();
    }

    // Show the gate once at launch, after the destination is on screen. A
    // forced update pushes an opaque full-screen wall (blocks the app); a soft
    // update is a dismissible card. Mirrors the ARM app. Later prompts come
    // from [_recheckOnResume].
    if (_remote != null && !_promptShown && _action != AppUpdateAction.none) {
      _promptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPrompt();
      });
    }

    return auth.isAuthenticated ? const HomeShell() : const LoginScreen();
  }
}
