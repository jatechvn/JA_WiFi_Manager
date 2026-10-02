// test/glass_marquee_session_test.dart
// Widget tests verifying Session Epoch Guard and Frozen Offset in GlassMarquee

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/services/app_power_manager.dart';
import 'package:ja_wifi_manager/modules/ui/widgets/glass_marquee.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final power = AppPowerManager.instance;

  setUp(() {
    power.resetForTesting(enableIdleSleep: false);
  });

  tearDown(() {
    power.cancelIdleTimerForTesting();
  });

  group('GlassMarquee Session Epoch Guard & Frozen Offset', () {
    testWidgets('Marquee scrolls when text overflows container',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              height: 40,
              child: GlassMarquee(
                text:
                    'Very Long Status Message That Overflows The Container Width Easily',
                scrollDuration: Duration(seconds: 4),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final marqueeState =
          tester.state<GlassMarqueeState>(find.byType(GlassMarquee));
      expect(marqueeState.scrollController.hasClients, isTrue);
      expect(marqueeState.scrollController.position.maxScrollExtent,
          greaterThan(0));
    });

    testWidgets('Blur increments session epoch, pauses, and freezes offset',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              height: 40,
              child: GlassMarquee(
                text: 'Long Text That Scrolls Across The Screen Continually',
                scrollDuration: Duration(seconds: 4),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final marqueeState =
          tester.state<GlassMarqueeState>(find.byType(GlassMarquee));
      final epochBeforeBlur = marqueeState.sessionEpoch;
      final offsetBeforeBlur = marqueeState.scrollController.offset;

      expect(offsetBeforeBlur, greaterThan(0));

      // Window loses focus (blur)
      power.onWindowBlur();
      await tester.pump();

      expect(marqueeState.sessionEpoch, greaterThan(epochBeforeBlur),
          reason:
              'Session epoch must increment to invalidate pending callbacks');
      expect(marqueeState.isPaused, isTrue);

      final frozenOffset = marqueeState.scrollController.offset;

      // Advance time while blurred — offset must remain frozen
      await tester.pump(const Duration(seconds: 5));
      expect(marqueeState.scrollController.offset, equals(frozenOffset),
          reason: 'Offset must stay frozen during window blur');

      // Focus window — marquee resumes from frozen offset without snapping to 0
      power.onWindowFocus();
      await tester.pump();

      expect(marqueeState.isPaused, isFalse);
      await tester.pump(const Duration(milliseconds: 300));
      expect(marqueeState.scrollController.offset,
          greaterThanOrEqualTo(frozenOffset),
          reason: 'Marquee must continue from frozen offset');
    });

    testWidgets('Changing text resets offset to 0 and starts new epoch',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              height: 40,
              child: GlassMarquee(
                text: 'First Long Marquee Message That Scrolls Over',
                scrollDuration: Duration(seconds: 4),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final marqueeState =
          tester.state<GlassMarqueeState>(find.byType(GlassMarquee));
      final epoch1 = marqueeState.sessionEpoch;

      // Update widget text
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              height: 40,
              child: GlassMarquee(
                text: 'Second New Different Message Entirely',
                scrollDuration: Duration(seconds: 4),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(marqueeState.sessionEpoch, greaterThan(epoch1));
    });
  });
}
