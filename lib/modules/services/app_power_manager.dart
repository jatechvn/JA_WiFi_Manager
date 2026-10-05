// lib/modules/services/app_power_manager.dart
// Single Source of Truth for Flutter Desktop Power & GPU Optimization.
// Manages window focus, visibility, and user idle sleep mode (12s default)
// to eliminate unnecessary continuous rendering when the app is inactive.

import 'dart:async';
import 'package:flutter/material.dart';
import '../app_config.dart';

class AppPowerManager {
  static final AppPowerManager instance = AppPowerManager._internal();

  AppPowerManager._internal();

  bool _isWindowFocused = false;
  bool _isWindowVisible = false;
  bool _explicitlyHidden = false;
  bool _isUserIdle = false;
  int _windowRevision = 0;

  final ValueNotifier<bool> windowVisibilityNotifier =
      ValueNotifier<bool>(false);

  /// Ignore snapshots completed after a newer window event or another query.
  Future<bool> synchronizeWindowState({
    required Future<bool> Function() isVisible,
    required Future<bool> Function() isFocused,
    Future<bool> Function()? isMinimized,
    bool Function()? isAlive,
    bool reconcileFailedHide = false,
  }) async {
    final revision = ++_windowRevision;
    final visible = await isVisible();
    if (revision != _windowRevision || isAlive?.call() == false) return false;
    final minimized = isMinimized != null && await isMinimized();
    if (revision != _windowRevision || isAlive?.call() == false) return false;
    final focused = visible && !minimized && await isFocused();
    if (revision != _windowRevision || isAlive?.call() == false) return false;
    if (reconcileFailedHide) _explicitlyHidden = false;
    if (_explicitlyHidden) return false;
    final wasActive = _isWindowVisible && _isWindowFocused;
    _isWindowVisible = visible && !minimized;
    _isWindowFocused = focused;
    if (focused && !wasActive) {
      _isUserIdle = false;
      _resetIdleTimer();
    } else if (!focused) {
      _cancelIdleTimer();
    }
    _updateNotifiers();
    return true;
  }

  void invalidateWindowSnapshot() => _windowRevision++;

  bool _enableIdleSleep = true;
  int _idleTimeoutSeconds = 12;

  Timer? _idleTimer;
  DateTime? _lastInteractionTime;

  /// Notifier for heavy background effects (e.g. MeshOrb gradient drifting).
  /// Pauses when Inactive, Minimized, or when User is Idle (>= 12s).
  final ValueNotifier<bool> backgroundAnimationNotifier =
      ValueNotifier<bool>(false);

  /// Notifier for real-time status indicators (e.g. WaveIndicator, BorderBeam).
  /// Pauses when Inactive or Minimized; continues running during User Idle
  /// so status and live telemetry remain responsive.
  final ValueNotifier<bool> indicatorsAnimationNotifier =
      ValueNotifier<bool>(false);

  /// Notifier for scrolling marquee text.
  /// Freezes offset and pauses timers when Inactive or Minimized.
  final ValueNotifier<bool> marqueeAnimationNotifier =
      ValueNotifier<bool>(false);

  // Getters
  bool get isWindowFocused => _isWindowFocused;
  bool get isWindowVisible => _isWindowVisible;
  bool get isUserIdle => _isUserIdle;
  bool get enableIdleSleep => _enableIdleSleep;
  int get idleTimeoutSeconds => _idleTimeoutSeconds;

  bool get shouldAnimateBackground => backgroundAnimationNotifier.value;
  bool get shouldAnimateIndicators => indicatorsAnimationNotifier.value;
  bool get shouldAnimateMarquee => marqueeAnimationNotifier.value;

  /// Initializes power manager with saved preferences from AppConfig.
  Future<void> initialize({
    bool? enableIdleSleep,
    int? idleTimeoutSeconds,
  }) async {
    if (enableIdleSleep != null) {
      _enableIdleSleep = enableIdleSleep;
    } else {
      final savedEnable =
          AppConfig.get('enable_idle_sleep', defaultValue: 'true');
      _enableIdleSleep = savedEnable.toLowerCase() != 'false';
    }

    if (idleTimeoutSeconds != null) {
      _idleTimeoutSeconds = idleTimeoutSeconds;
    } else {
      final savedTimeout =
          AppConfig.get('idle_timeout_seconds', defaultValue: '12');
      _idleTimeoutSeconds = int.tryParse(savedTimeout) ?? 12;
    }

    _updateNotifiers();
    if (_isWindowFocused && _isWindowVisible) {
      _resetIdleTimer();
    }
  }

  /// Called when the window gains focus.
  void onWindowFocus() {
    invalidateWindowSnapshot();
    if (_explicitlyHidden) return;
    _isWindowFocused = true;
    _isWindowVisible = true;
    _isUserIdle = false;
    _updateNotifiers();
    _resetIdleTimer();
  }

  /// Called when the window loses focus (inactive/blur).
  void onWindowBlur() {
    invalidateWindowSnapshot();
    _isWindowFocused = false;
    _cancelIdleTimer();
    _updateNotifiers();
  }

  /// Called when the window is minimized to the taskbar.
  void onWindowMinimize() {
    invalidateWindowSnapshot();
    _isWindowVisible = false;
    _isWindowFocused = false;
    _cancelIdleTimer();
    _updateNotifiers();
  }

  /// Called when the window is restored from taskbar or tray.
  /// CAUTION: On Windows, restoring does NOT guarantee that the window is focused.
  void onWindowRestore() {
    invalidateWindowSnapshot();
    _explicitlyHidden = false;
    _isWindowVisible = true;
    _updateNotifiers();
    // Do not set _isWindowFocused = true here; wait for onWindowFocus()
  }

  /// Called when visibility changes directly.
  void onWindowVisibilityChanged(bool isVisible) {
    invalidateWindowSnapshot();
    _explicitlyHidden = !isVisible;
    _isWindowVisible = isVisible;
    if (!isVisible) {
      _isWindowFocused = false;
      _cancelIdleTimer();
    }
    _updateNotifiers();
  }

  /// Called on Flutter AppLifecycleState change.
  void onLifecycleStateChanged(AppLifecycleState state) {
    invalidateWindowSnapshot();
    switch (state) {
      case AppLifecycleState.resumed:
        // A resumed hint is not proof that a tray-hidden window was shown.
        _updateNotifiers();
        break;
      case AppLifecycleState.inactive:
        _isWindowFocused = false;
        _cancelIdleTimer();
        _updateNotifiers();
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _isWindowVisible = false;
        _isWindowFocused = false;
        _cancelIdleTimer();
        _updateNotifiers();
        break;
      case AppLifecycleState.detached:
        _isWindowVisible = false;
        _isWindowFocused = false;
        _cancelIdleTimer();
        _updateNotifiers();
        break;
    }
  }

  /// Records user interaction (pointer move/click, key event, scroll)
  /// with a 600ms throttle to prevent overwhelming the event loop.
  void recordUserInteraction() {
    final now = DateTime.now();
    if (_lastInteractionTime != null &&
        now.difference(_lastInteractionTime!).inMilliseconds < 600) {
      return;
    }
    _lastInteractionTime = now;

    if (_isUserIdle) {
      _isUserIdle = false;
      _updateNotifiers();
    }

    if (_isWindowFocused && _isWindowVisible) {
      _resetIdleTimer();
    }
  }

  /// Updates whether Idle Sleep mode is active.
  void setEnableIdleSleep(bool enable) {
    if (_enableIdleSleep == enable) return;
    _enableIdleSleep = enable;
    AppConfig.set('enable_idle_sleep', enable.toString());

    if (!enable) {
      _isUserIdle = false;
      _cancelIdleTimer();
    } else if (_isWindowFocused && _isWindowVisible) {
      _resetIdleTimer();
    }
    _updateNotifiers();
  }

  /// Updates the idle timeout duration in seconds (12s, 30s, 60s).
  void setIdleTimeoutSeconds(int seconds) {
    if (_idleTimeoutSeconds == seconds || seconds <= 0) return;
    _idleTimeoutSeconds = seconds;
    AppConfig.set('idle_timeout_seconds', seconds.toString());

    if (_isWindowFocused && _isWindowVisible && _enableIdleSleep) {
      _resetIdleTimer();
    }
  }

  void _resetIdleTimer() {
    _cancelIdleTimer();
    if (!_enableIdleSleep || !_isWindowFocused || !_isWindowVisible) return;

    _idleTimer = Timer(Duration(seconds: _idleTimeoutSeconds), () {
      _isUserIdle = true;
      _updateNotifiers();
    });
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void _updateNotifiers() {
    windowVisibilityNotifier.value = _isWindowVisible;
    final activeAndVisible = _isWindowFocused && _isWindowVisible;

    // Background animation stops when not active/visible, or when user is idle
    final shouldBg = activeAndVisible && (!_enableIdleSleep || !_isUserIdle);
    if (backgroundAnimationNotifier.value != shouldBg) {
      backgroundAnimationNotifier.value = shouldBg;
    }

    // Indicators continue running even during idle, but stop when inactive/minimized
    final shouldInd = activeAndVisible;
    if (indicatorsAnimationNotifier.value != shouldInd) {
      indicatorsAnimationNotifier.value = shouldInd;
    }

    // Marquee freezes when inactive/minimized
    final shouldMarquee = activeAndVisible;
    if (marqueeAnimationNotifier.value != shouldMarquee) {
      marqueeAnimationNotifier.value = shouldMarquee;
    }
  }

  @visibleForTesting
  void resetForTesting({
    bool isWindowFocused = true,
    bool isWindowVisible = true,
    bool isUserIdle = false,
    bool enableIdleSleep = true,
    int idleTimeoutSeconds = 12,
  }) {
    invalidateWindowSnapshot();
    _cancelIdleTimer();
    _lastInteractionTime = null;
    _explicitlyHidden = false;
    _isWindowFocused = isWindowFocused;
    _isWindowVisible = isWindowVisible;
    _isUserIdle = isUserIdle;
    _enableIdleSleep = enableIdleSleep;
    _idleTimeoutSeconds = idleTimeoutSeconds;
    _updateNotifiers();
  }

  @visibleForTesting
  void triggerIdleForTesting() {
    _isUserIdle = true;
    _updateNotifiers();
  }

  @visibleForTesting
  void cancelIdleTimerForTesting() {
    _cancelIdleTimer();
  }
}
