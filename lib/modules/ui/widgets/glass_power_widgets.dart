// lib/modules/ui/widgets/glass_power_widgets.dart
// Power-optimized animated widgets with Direction Preservation
// and RepaintBoundary isolation. Connected to AppPowerManager.

import 'package:flutter/material.dart';
import '../../services/app_power_manager.dart';

/// Animated Wave / Pulse indicator with strict Direction Preservation.
/// Pauses immediately when window is Inactive/Minimized, and resumes
/// in the EXACT same direction (forward/reverse) without snapping.
class WaveIndicator extends StatefulWidget {
  final Color color;
  final double size;
  final int barCount;
  final Duration duration;

  const WaveIndicator({
    super.key,
    required this.color,
    this.size = 18.0,
    this.barCount = 3,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<WaveIndicator> createState() => _WaveIndicatorState();
}

class _WaveIndicatorState extends State<WaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _controller.addStatusListener(_onStatusChanged);
    AppPowerManager.instance.indicatorsAnimationNotifier
        .addListener(_onPowerStateChanged);

    if (AppPowerManager.instance.shouldAnimateIndicators) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    AppPowerManager.instance.indicatorsAnimationNotifier
        .removeListener(_onPowerStateChanged);
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (!AppPowerManager.instance.shouldAnimateIndicators) return;
    if (status == AnimationStatus.completed) {
      _controller.reverse();
    } else if (status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  void _onPowerStateChanged() {
    if (!mounted) return;
    if (AppPowerManager.instance.shouldAnimateIndicators) {
      _resumeAnimation();
    } else {
      _controller.stop();
    }
  }

  /// Resumes the animation preserving the current leg (forward or reverse)
  void _resumeAnimation() {
    if (!mounted) return;
    if (_controller.status == AnimationStatus.reverse ||
        _controller.status == AnimationStatus.completed) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return SizedBox(
            width: widget.size * (widget.barCount * 0.45),
            height: widget.size,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(widget.barCount, (index) {
                final delay = index / widget.barCount;
                final value = ((_controller.value + delay) % 1.0);
                final heightFactor =
                    0.3 + 0.7 * (value <= 0.5 ? value * 2 : (1.0 - value) * 2);

                return Container(
                  width: widget.size * 0.22,
                  height: widget.size * heightFactor,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(widget.size * 0.1),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}

/// Floating gradient orb background element with Direction Preservation.
/// Listens to backgroundAnimationNotifier (stops when Inactive, Minimized, or Idle >= 12s).
class MeshOrb extends StatefulWidget {
  final Color color;
  final double radius;
  final Offset initialOffset;
  final Offset targetOffset;
  final Duration duration;

  const MeshOrb({
    super.key,
    required this.color,
    required this.radius,
    required this.initialOffset,
    required this.targetOffset,
    this.duration = const Duration(seconds: 8),
  });

  @override
  State<MeshOrb> createState() => _MeshOrbState();
}

class _MeshOrbState extends State<MeshOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _offsetAnimation = Tween<Offset>(
      begin: widget.initialOffset,
      end: widget.targetOffset,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.addStatusListener(_onStatusChanged);
    AppPowerManager.instance.backgroundAnimationNotifier
        .addListener(_onPowerStateChanged);

    if (AppPowerManager.instance.shouldAnimateBackground) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    AppPowerManager.instance.backgroundAnimationNotifier
        .removeListener(_onPowerStateChanged);
    _controller.removeStatusListener(_onStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (!AppPowerManager.instance.shouldAnimateBackground) return;
    if (status == AnimationStatus.completed) {
      _controller.reverse();
    } else if (status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  void _onPowerStateChanged() {
    if (!mounted) return;
    if (AppPowerManager.instance.shouldAnimateBackground) {
      _resumeAnimation();
    } else {
      _controller.stop();
    }
  }

  void _resumeAnimation() {
    if (!mounted) return;
    if (_controller.status == AnimationStatus.reverse ||
        _controller.status == AnimationStatus.completed) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _offsetAnimation,
        builder: (context, _) {
          return Transform.translate(
            offset: _offsetAnimation.value,
            child: Container(
              width: widget.radius * 2,
              height: widget.radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.color.withValues(alpha: 0.22),
                    widget.color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
