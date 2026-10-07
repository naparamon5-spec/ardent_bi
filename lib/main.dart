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

class _RootState extends State<_Root> {
  AppUpdateAction _action = AppUpdateAction.none;
  AppVersionInfo? _remote;
  bool _versionChecked = false;
  bool _promptShown = false;

  @override
  void initState() {
    super.initState();
    _runVersionCheck();
  }

  Future<void> _runVersionCheck() async {
    final svc = AppVersionService();
    try {
      final current = await svc.getInstalledVersion();
      final remote = await svc.fetchLatestVersion();
      if (!mounted) return;
      final action = (current != null && remote != null)
          ? AppVersionService.decideUpdate(current, remote)
          : AppUpdateAction.none;
      setState(() {
        _action = action;
        _remote = remote;
        _versionChecked = true;
      });
    } finally {
      svc.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    if (auth.booting || !_versionChecked) {
      return const SplashScreen();
    }

    // Show the gate once, after the destination is on screen. A forced update
    // pushes an opaque full-screen wall (blocks the app); a soft update is a
    // dismissible card. Mirrors the ARM app.
    if (_remote != null && !_promptShown && _action != AppUpdateAction.none) {
      _promptShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_action == AppUpdateAction.forced) {
          showForceUpdateDialog(context: context, remote: _remote!);
        } else {
          showSoftUpdateDialog(context: context, remote: _remote!);
        }
      });
    }

    return auth.isAuthenticated ? const HomeShell() : const LoginScreen();
  }
}
