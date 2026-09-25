import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/auth_state.dart';
import '../screens/splash_screen.dart';

/// HRIS-style app-lock layer:
///  • Any tap/scroll resets the inactivity countdown ([AuthState.touch]).
///  • Leaving the foreground paints the brand [SplashScreen] over everything so
///    no data shows in the iOS app switcher / recents.
///  • Lifecycle transitions drive auto sign-out: idle-expiry on resume, and a
///    token wipe on termination.
///  • When the session ends, any pushed screens are popped back to the root so
///    the login screen is what's shown.
class AppLifecycleGuard extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  const AppLifecycleGuard({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  @override
  State<AppLifecycleGuard> createState() => _AppLifecycleGuardState();
}

class _AppLifecycleGuardState extends State<AppLifecycleGuard>
    with WidgetsBindingObserver {
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = context.read<AuthState>();
    switch (state) {
      case AppLifecycleState.resumed:
        auth.handleResume();
        if (mounted) setState(() => _obscured = false);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Cover content before iOS snapshots the app for the switcher.
        if (mounted) setState(() => _obscured = true);
        auth.handlePause();
        break;
      case AppLifecycleState.detached:
        auth.handleDetached();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authed = context.watch<AuthState>().isAuthenticated;
    // If the session ended while deeper screens were open, return to the root.
    if (!authed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.navigatorKey.currentState?.popUntil((r) => r.isFirst);
      });
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => context.read<AuthState>().touch(),
      child: Stack(
        children: [
          widget.child,
          if (_obscured) const Positioned.fill(child: SplashScreen()),
        ],
      ),
    );
  }
}
