import 'package:flutter/widgets.dart';
import 'app_power_manager.dart';

/// Suppresses ordinary UI frame requests, not business timers or native drawing.
/// Shared with the test binding so tests exercise the production policy.
mixin PowerFramePolicy on WidgetsBinding {
  @override
  void initInstances() {
    super.initInstances();
    AppPowerManager.instance.indicatorsAnimationNotifier
        .addListener(_onRenderingPolicyChanged);
  }

  @override
  bool get framesEnabled =>
      super.framesEnabled && AppPowerManager.instance.shouldAnimateIndicators;

  void _onRenderingPolicyChanged() {
    if (framesEnabled) scheduleFrame();
  }
}

class PowerWidgetsBinding extends WidgetsFlutterBinding with PowerFramePolicy {}
