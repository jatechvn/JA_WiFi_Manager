import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/services/app_power_manager.dart';
import 'package:ja_wifi_manager/modules/ui/widgets/app_ticker_gate.dart';

class _TickProbe extends StatefulWidget {
  const _TickProbe(this.onTick);
  final VoidCallback onTick;

  @override
  State<_TickProbe> createState() => _TickProbeState();
}

class _TickProbeState extends State<_TickProbe>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )
      ..addListener(widget.onTick)
      ..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  final power = AppPowerManager.instance;
  setUp(power.resetForTesting);
  tearDown(power.resetForTesting);

  testWidgets('Hide mutes ordinary UI tickers but not background timers',
      (tester) async {
    var ticks = 0;
    var backgroundRuns = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      backgroundRuns++;
    });
    addTearDown(timer.cancel);
    await tester.pumpWidget(AppTickerGate(child: _TickProbe(() => ticks++)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(ticks, greaterThan(0));

    power.onWindowVisibilityChanged(false);
    await tester.pump(); // Apply TickerMode before checking subsequent frames.
    final frozenTicks = ticks;
    final previousRuns = backgroundRuns;
    await tester.pump(const Duration(seconds: 1));
    expect(ticks, frozenTicks);
    expect(backgroundRuns, greaterThan(previousRuns));

    power.onWindowVisibilityChanged(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(ticks, frozenTicks, reason: 'Showing is not proof of focus');

    power.onWindowFocus();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(ticks, greaterThan(frozenTicks));
    timer.cancel();
    power.cancelIdleTimerForTesting();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Blur and minimize mute tickers, focus resumes them',
      (tester) async {
    var ticks = 0;
    await tester.pumpWidget(AppTickerGate(child: _TickProbe(() => ticks++)));
    for (final pause in [power.onWindowBlur, power.onWindowMinimize]) {
      pause();
      await tester.pump();
      final frozenTicks = ticks;
      await tester.pump(const Duration(milliseconds: 200));
      expect(ticks, frozenTicks);
      power.onWindowFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(ticks, greaterThan(frozenTicks));
    }
    power.cancelIdleTimerForTesting();
    await tester.pumpWidget(const SizedBox());
  });
}
