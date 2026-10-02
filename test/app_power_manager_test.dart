// test/app_power_manager_test.dart
// Unit tests for AppPowerManager (Single Source of Truth for Flutter Desktop Power)

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/services/app_power_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final power = AppPowerManager.instance;

  setUp(() {
    power.resetForTesting();
  });

  group('AppPowerManager Window State Transitions', () {
    test('Tray hide disables animations without relying on a blur event', () {
      power.onWindowVisibilityChanged(false);
      expect(power.isWindowVisible, isFalse);
      expect(power.isWindowFocused, isFalse);
      expect(power.shouldAnimateBackground, isFalse);
      expect(power.shouldAnimateIndicators, isFalse);
      expect(power.shouldAnimateMarquee, isFalse);

      power.onWindowVisibilityChanged(true);
      expect(power.shouldAnimateIndicators, isFalse);
      power.onWindowFocus();
      expect(power.shouldAnimateIndicators, isTrue);
      power.cancelIdleTimerForTesting();
    });

    test('Initial state is focused, visible, active', () {
      expect(power.isWindowFocused, isTrue);
      expect(power.isWindowVisible, isTrue);
      expect(power.isUserIdle, isFalse);
      expect(power.shouldAnimateBackground, isTrue);
      expect(power.shouldAnimateIndicators, isTrue);
      expect(power.shouldAnimateMarquee, isTrue);
    });

    test('onWindowBlur() stops all 3 animation notifiers immediately', () {
      power.onWindowBlur();

      expect(power.isWindowFocused, isFalse);
      expect(power.shouldAnimateBackground, isFalse);
      expect(power.shouldAnimateIndicators, isFalse);
      expect(power.shouldAnimateMarquee, isFalse);
    });

    test('onWindowFocus() resumes all 3 animation notifiers', () {
      power.onWindowBlur();
      expect(power.shouldAnimateBackground, isFalse);

      power.onWindowFocus();
      expect(power.isWindowFocused, isTrue);
      expect(power.isWindowVisible, isTrue);
      expect(power.shouldAnimateBackground, isTrue);
      expect(power.shouldAnimateIndicators, isTrue);
      expect(power.shouldAnimateMarquee, isTrue);
    });

    test('onWindowMinimize() stops all notifiers and marks invisible', () {
      power.onWindowMinimize();

      expect(power.isWindowVisible, isFalse);
      expect(power.isWindowFocused, isFalse);
      expect(power.shouldAnimateBackground, isFalse);
      expect(power.shouldAnimateIndicators, isFalse);
      expect(power.shouldAnimateMarquee, isFalse);
    });

    test('onWindowRestore() sets visible=true but does NOT assume focused', () {
      power.onWindowMinimize();
      expect(power.isWindowVisible, isFalse);
      expect(power.isWindowFocused, isFalse);

      // Restore from taskbar
      power.onWindowRestore();

      expect(power.isWindowVisible, isTrue);
      expect(power.isWindowFocused, isFalse,
          reason: 'Win32 restore does not guarantee window has focus');
      expect(power.shouldAnimateBackground, isFalse);
      expect(power.shouldAnimateIndicators, isFalse);
      expect(power.shouldAnimateMarquee, isFalse);

      // Once user focuses into the window
      power.onWindowFocus();
      expect(power.isWindowFocused, isTrue);
      expect(power.shouldAnimateBackground, isTrue);
      expect(power.shouldAnimateIndicators, isTrue);
      expect(power.shouldAnimateMarquee, isTrue);
    });
  });

  group('Idle Sleep Mode (12s Policy)', () {
    test(
        'Entering idle sleep pauses background, but keeps indicators and marquee running',
        () {
      expect(power.shouldAnimateBackground, isTrue);
      expect(power.shouldAnimateIndicators, isTrue);
      expect(power.shouldAnimateMarquee, isTrue);

      power.triggerIdleForTesting();

      expect(power.isUserIdle, isTrue);
      expect(power.shouldAnimateBackground, isFalse,
          reason: 'Heavy background orb must freeze during idle');
      expect(power.shouldAnimateIndicators, isTrue,
          reason: 'Indicators must remain responsive during idle');
      expect(power.shouldAnimateMarquee, isTrue,
          reason: 'Marquee text must remain responsive during idle');
    });

    test('User interaction wakes up background immediately', () {
      power.triggerIdleForTesting();
      expect(power.shouldAnimateBackground, isFalse);

      power.recordUserInteraction();

      expect(power.isUserIdle, isFalse);
      expect(power.shouldAnimateBackground, isTrue);
    });

    test('Disabling idle sleep keeps background running continuously', () {
      power.setEnableIdleSleep(false);
      power.triggerIdleForTesting();

      expect(power.shouldAnimateBackground, isTrue,
          reason: 'Background must stay active if idle sleep is disabled');
    });

    test('Customizing idle timeout updates configuration correctly', () {
      power.setIdleTimeoutSeconds(30);
      expect(power.idleTimeoutSeconds, equals(30));

      power.setIdleTimeoutSeconds(60);
      expect(power.idleTimeoutSeconds, equals(60));
    });
  });
}
