// lib/modules/native/linux_core.dart
// Linux stub engine for compile compatibility

import '../native_bridge.dart';

class LinuxNativeEngine implements NativeEngine {
  @override
  dynamic heavyCompute(dynamic dataInput) {
    return 'Linux Stub Result';
  }
}
