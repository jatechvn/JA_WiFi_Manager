// lib/modules/ui/widgets/glass_marquee.dart
// Power-optimized horizontal marquee text with Session Epoch Guard
// and Frozen Offset preservation.

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/app_power_manager.dart';

class GlassMarquee extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration scrollDuration;
  final Duration pauseDuration;
  final double blankSpace;

  const GlassMarquee({
    super.key,
    required this.text,
    this.style,
    this.scrollDuration = const Duration(seconds: 10),
    this.pauseDuration = const Duration(seconds: 2),
    this.blankSpace = 40.0,
  });

  @override
  State<GlassMarquee> createState() => GlassMarqueeState();
}

class GlassMarqueeState extends State<GlassMarquee> {
  final ScrollController _scrollController = ScrollController();
  int _sessionEpoch = 0;
  bool _isPaused = false;
  Timer? _timer;

  double _frozenOffset = 0.0;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    AppPowerManager.instance.marqueeAnimationNotifier
        .addListener(_onPowerStateChanged);

    _isPaused = !AppPowerManager.instance.shouldAnimateMarquee;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isPaused) {
        _startScrollCycle();
      }
    });
  }

  @override
  void didUpdateWidget(GlassMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _sessionEpoch++;
      _timer?.cancel();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      _frozenOffset = 0.0;
      if (!_isPaused) {
        _startScrollCycle();
      }
    }
  }

  @override
  void dispose() {
    _sessionEpoch++;
    _timer?.cancel();
    AppPowerManager.instance.marqueeAnimationNotifier
        .removeListener(_onPowerStateChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onPowerStateChanged() {
    if (!mounted) return;
    final shouldAnimate = AppPowerManager.instance.shouldAnimateMarquee;

    if (!shouldAnimate && !_isPaused) {
      // PAUSE: freeze offset immediately and invalidate in-flight callbacks
      _isPaused = true;
      _sessionEpoch++;
      _timer?.cancel();

      if (_scrollController.hasClients) {
        _frozenOffset = _scrollController.offset;
        _scrollController.jumpTo(_frozenOffset);
      }
    } else if (shouldAnimate && _isPaused) {
      // RESUME: continue scrolling from frozen offset
      _isPaused = false;
      _resumeScrollCycle();
    }
  }

  void _startScrollCycle() {
    if (_isPaused || !mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return; // Content fits; no marquee needed

    final currentEpoch = _sessionEpoch;
    _isScrolling = true;

    // Remaining distance and proportional duration
    final currentOffset = _scrollController.offset;
    final remainingDistance = (maxScroll - currentOffset).clamp(0.0, maxScroll);
    final totalDurationMs = widget.scrollDuration.inMilliseconds;
    final durationMs = maxScroll > 0
        ? ((remainingDistance / maxScroll) * totalDurationMs).round()
        : totalDurationMs;

    _scrollController
        .animateTo(
      maxScroll,
      duration: Duration(milliseconds: durationMs > 100 ? durationMs : 100),
      curve: Curves.linear,
    )
        .then((_) {
      if (currentEpoch != _sessionEpoch || _isPaused || !mounted) return;
      _isScrolling = false;

      // Pause at end
      _timer = Timer(widget.pauseDuration, () {
        if (currentEpoch != _sessionEpoch || _isPaused || !mounted) return;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
          _frozenOffset = 0.0;
        }

        // Pause at start before next cycle
        _timer = Timer(widget.pauseDuration, () {
          if (currentEpoch != _sessionEpoch || _isPaused || !mounted) return;
          _startScrollCycle();
        });
      });
    }).catchError((_) {
      // Ignored on interruption
    });
  }

  void _resumeScrollCycle() {
    if (_isPaused || !mounted) return;
    _startScrollCycle();
  }

  // Exposed for testing
  @visibleForTesting
  ScrollController get scrollController => _scrollController;
  @visibleForTesting
  int get sessionEpoch => _sessionEpoch;
  @visibleForTesting
  bool get isPaused => _isPaused;
  @visibleForTesting
  bool get isScrolling => _isScrolling;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.text, style: widget.style),
            SizedBox(width: widget.blankSpace),
            Text(widget.text, style: widget.style),
          ],
        ),
      ),
    );
  }
}
