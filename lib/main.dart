import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'state/auth_state.dart';
import 'state/filter_state.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load locale data so DateFormat('en_PH') works (Fmt.date on the Sales list).
  await initializeDateFormatting('en_PH');
  runApp(const ArdentBiApp());
}

class ArdentBiApp extends StatelessWidget {
  const ArdentBiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => FilterState()),
      ],
      child: MaterialApp(
        title: 'Ardent BI',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.isAuthenticated ? const HomeShell() : const LoginScreen();
  }
}
