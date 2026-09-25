import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// App-wide "something is loading" signal. Screens call [show] when they start
/// fetching and [hide] when done; a reference count keeps the global overlay up
/// while any number of concurrent loads are in flight (the tab shell builds
/// several pages at once, so more than one fetch runs on first launch).
///
/// A minimum on-screen time keeps the blur from flickering when the API answers
/// in a few milliseconds — the loader always stays up long enough to read.
class LoadingState extends ChangeNotifier {
  static const _minVisible = Duration(milliseconds: 500);

  int _count = 0;
  bool _visible = false;
  DateTime? _shownAt;
  Timer? _hideTimer;

  bool get busy => _visible;

  void show() {
    _count++;
    _hideTimer?.cancel();
    _hideTimer = null;
    if (!_visible) {
      _visible = true;
      _shownAt = DateTime.now();
      _notifySafe();
    }
  }

  void hide() {
    if (_count == 0) return;
    _count--;
    if (_count > 0) return; // other loads still running

    final elapsed =
        _shownAt == null ? _minVisible : DateTime.now().difference(_shownAt!);
    final remaining = _minVisible - elapsed;
    if (remaining <= Duration.zero) {
      _finishHide();
    } else {
      _hideTimer?.cancel();
      _hideTimer = Timer(remaining, () {
        // A new load may have started while we were waiting.
        if (_count == 0) _finishHide();
      });
    }
  }

  void _finishHide() {
    _hideTimer = null;
    if (_visible) {
      _visible = false;
      _shownAt = null;
      _notifySafe();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  /// Notifying while the framework is mid-build (a screen calls [show] from
  /// initState) throws. Defer to the next frame in that case.
  void _notifySafe() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }
}
