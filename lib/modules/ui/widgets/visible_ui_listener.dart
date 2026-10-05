import 'package:flutter/foundation.dart';

/// Defers presentation callbacks, not source notifications or business work.
class VisibleUiListener {
  VisibleUiListener({
    required this.source,
    required this.visibility,
    required this.onUpdate,
  }) {
    source.addListener(_onSourceChanged);
    visibility.addListener(_onVisibilityChanged);
  }

  final Listenable source;
  final ValueListenable<bool> visibility;
  final VoidCallback onUpdate;
  bool _pending = false;

  void _onSourceChanged() {
    if (!visibility.value) {
      _pending = true;
      return;
    }
    onUpdate();
  }

  void _onVisibilityChanged() {
    if (!visibility.value || !_pending) return;
    _pending = false;
    onUpdate();
  }

  void dispose() {
    source.removeListener(_onSourceChanged);
    visibility.removeListener(_onVisibilityChanged);
  }
}
