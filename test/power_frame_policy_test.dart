import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/services/app_power_manager.dart';
import 'package:ja_wifi_manager/modules/services/power_widgets_binding.dart';

class _PowerTestBinding extends AutomatedTestWidgetsFlutterBinding
    with PowerFramePolicy {}

class _TimerView extends StatefulWidget {
  const _TimerView({required this.onBuild, required this.onBusinessTick});
  final VoidCallback onBuild;
  final VoidCallback onBusinessTick;

  @override
  State<_TimerView> createState() => _TimerViewState();
}

class _TimerViewState extends State<_TimerView> {
  Timer? timer;
  int value = 0;

  void start() {
    timer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      widget.onBusinessTick();
      setState(() => value++);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return Text('$value', textDirection: TextDirection.ltr);
  }
}

void main() {
  final binding = _PowerTestBinding();
  final power = AppPowerManager.instance;
  setUp(power.resetForTesting);
  tearDown(power.resetForTesting);

  testWidgets('Production frame policy gates timer UI, not business progress',
      (tester) async {
    var builds = 0;
    var businessTicks = 0;
    await tester.pumpWidget(_TimerView(
      onBuild: () => builds++,
      onBusinessTick: () => businessTicks++,
    ));
    power.onWindowBlur();
    await tester.pump(); // Settle the one frame already requested by startup.
    final buildsBefore = builds;
    await tester.runAsync(() async {
      tester.state<_TimerViewState>(find.byType(_TimerView)).start();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(businessTicks, greaterThanOrEqualTo(3));
      expect(builds, buildsBefore);
      expect(binding.framesEnabled, isFalse);
      expect(binding.hasScheduledFrame, isFalse);
      tester.state<_TimerViewState>(find.byType(_TimerView)).timer?.cancel();
    });
    power.onWindowFocus();
    expect(binding.hasScheduledFrame, isTrue);
    await tester.pump();
    expect(find.text('$businessTicks'), findsOneWidget);
    power.triggerIdleForTesting();
    expect(power.shouldAnimateBackground, isFalse);
    expect(binding.framesEnabled, isTrue);
    power.cancelIdleTimerForTesting();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Initially hidden and spurious resumed remain gated',
      (tester) async {
    power.resetForTesting(isWindowFocused: false, isWindowVisible: false);
    expect(binding.framesEnabled, isFalse);
    power.onWindowVisibilityChanged(false);
    power.onLifecycleStateChanged(AppLifecycleState.resumed);
    power.onWindowFocus();
    expect(binding.framesEnabled, isFalse);
    expect(power.isWindowVisible, isFalse);
    power.onWindowVisibilityChanged(true);
    await power.synchronizeWindowState(
      isVisible: () async => true,
      isMinimized: () async => true,
      isFocused: () async => true,
    );
    expect(binding.framesEnabled, isFalse);
  });

  testWidgets('Superclass paused lifecycle still disables focused rendering',
      (tester) async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(binding.framesEnabled, isFalse);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(binding.framesEnabled, isTrue);
    await tester.pump();
  });
}
