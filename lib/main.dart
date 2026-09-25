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
/// web's global auth middleware.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    if (auth.booting) {
      return const SplashScreen();
    }
    return auth.isAuthenticated ? const HomeShell() : const LoginScreen();
  }
}
