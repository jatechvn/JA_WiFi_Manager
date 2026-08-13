// lib/modules/native/mac_core.dart
// macOS stub engine for compile compatibility

import '../native_bridge.dart';

class MacNativeEngine implements NativeEngine {
  @override
  dynamic heavyCompute(dynamic dataInput) {
    return 'macOS Stub Result';
  }
}
