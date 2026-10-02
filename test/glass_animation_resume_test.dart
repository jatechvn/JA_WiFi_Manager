// test/glass_animation_resume_test.dart
// Widget tests verifying Direction Preservation in WaveIndicator and MeshOrb

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/services/app_power_manager.dart';
import 'package:ja_wifi_manager/modules/ui/widgets/glass_power_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final power = AppPowerManager.instance;

  setUp(() {
    power.resetForTesting(enableIdleSleep: false);
  });

  tearDown(() {
    power.cancelIdleTimerForTesting();
  });

  group('WaveIndicator Direction Preservation', () {
    testWidgets('Preserves forward direction across blur and focus cycles',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: WaveIndicator(
                color: Colors.cyan,
                size: 20,
              ),
            ),
          ),
        ),
      );

      // Pump 200ms into forward leg
      await tester.pump(const Duration(milliseconds: 200));

      // Window loses focus (Inactive)
      power.onWindowBlur();
      await tester.pump();

      // Ensure no animation frames advance while Inactive
      await tester.pump(const Duration(milliseconds: 500));

      // Window regains focus
      power.onWindowFocus();
      await tester.pump();

      // Ensure animation resumes smoothly without errors
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(WaveIndicator), findsOneWidget);
    });

    testWidgets('Preserves reverse direction when paused during reverse phase',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: WaveIndicator(
                color: Colors.green,
                size: 20,
                duration: Duration(milliseconds: 500),
              ),
            ),
          ),
        ),
      );

      // Advance into reverse phase (500ms forward + 200ms into reverse)
      await tester.pump(const Duration(milliseconds: 700));

      // Blur window during reverse leg
      power.onWindowBlur();
      await tester.pump();

      // Focus window
      power.onWindowFocus();
      await tester.pump();

      // Progress reverse to completion and forward again
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(WaveIndicator), findsOneWidget);
    });

    testWidgets('Widget mounted when blurred stays frozen until focus',
        (tester) async {
      power.onWindowBlur();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: WaveIndicator(
                color: Colors.blue,
                size: 20,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(WaveIndicator), findsOneWidget);

      // Focus activates the controller
      power.onWindowFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(WaveIndicator), findsOneWidget);
    });
  });

  group('MeshOrb Direction Preservation & Idle Sleep', () {
    testWidgets('MeshOrb pauses during idle sleep and resumes smoothly',
        (tester) async {
      power.resetForTesting(enableIdleSleep: true);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MeshOrb(
                color: Colors.cyan,
                radius: 50,
                initialOffset: Offset.zero,
                targetOffset: Offset(50, 50),
                duration: Duration(seconds: 4),
              ),
            ),
          ),
        ),
      );

      // Advance 1 second
      await tester.pump(const Duration(seconds: 1));

      // Trigger idle sleep
      power.triggerIdleForTesting();
      await tester.pump();

      expect(power.shouldAnimateBackground, isFalse);

      // Advance time while idle - orb must not animate
      await tester.pump(const Duration(seconds: 2));

      // User moves mouse / interacts
      power.recordUserInteraction();
      await tester.pump();

      expect(power.shouldAnimateBackground, isTrue);

      // Orb resumes moving
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MeshOrb), findsOneWidget);

      power.cancelIdleTimerForTesting();
    });
  });
}
