import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/ui_state.dart';
import '../theme.dart';

/// Full-screen blurred loader shown above every route while [LoadingState] is
/// busy. Mounted once via MaterialApp.builder so it covers tabs and pushed
/// pages alike, blurring the content underneath until data is ready.
class GlobalLoadingOverlay extends StatelessWidget {
  const GlobalLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<LoadingState>().busy;
    return IgnorePointer(
      ignoring: !busy,
      child: AnimatedOpacity(
        opacity: busy ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: busy ? const _Blur() : const SizedBox.shrink(),
      ),
    );
  }
}

class _Blur extends StatelessWidget {
  const _Blur();

  @override
  Widget build(BuildContext context) {
    final t = BiTokens.of(context);
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          color: (t.isDark ? Colors.black : Colors.white).withValues(alpha: 0.25),
          alignment: Alignment.center,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: t.chrome,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.chromeBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: t.isDark ? 0.5 : 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SizedBox(
                height: 38,
                width: 38,
                child: CircularProgressIndicator(strokeWidth: 3, color: t.brand),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
