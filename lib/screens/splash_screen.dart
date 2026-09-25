import 'package:flutter/material.dart';
import '../theme.dart';

/// Brand splash — shown while the app boots and, for security, painted over the
/// whole app whenever it leaves the foreground so no data is visible in the iOS
/// app switcher / recents. Matches the app icon: white circle mark on navy.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const _navy = Color(0xFF133341);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _navy,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Image.asset('assets/logo_mark.png', width: 58),
            ),
            const SizedBox(height: 22),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
                children: [
                  TextSpan(text: 'Ardent'),
                  TextSpan(text: 'BI', style: TextStyle(color: AppColors.brand)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'BUSINESS INTELLIGENCE',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
