import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/constants.dart';

// Source contracts guard both startup layers; packaged metadata and native
// Task Manager rendering still require a Windows build/runtime check.
void main() {
  test('Windows caption stays named in native and Dart startup', () {
    final dartStartup = File('lib/main.dart').readAsStringSync();
    final nativeStartup = File('windows/runner/main.cpp').readAsStringSync();
    final window = File('windows/runner/win32_window.cpp').readAsStringSync();

    expect(dartStartup, contains('const windowTitle = appName;'));
    expect(dartStartup, contains('title: windowTitle,'));
    expect(nativeStartup, contains('window.Create(L"$appName"'));
    expect(
        window, contains('window_class, title.c_str(), WS_OVERLAPPEDWINDOW'));
  });

  test('EXE has a friendly display name without renaming its identity', () {
    final resource = File('windows/runner/Runner.rc').readAsStringSync();
    expect(resource, contains('VALUE "FileDescription", "$appName"'));
    expect(resource, contains('VALUE "ProductName", "$appName"'));
    expect(resource, contains('VALUE "OriginalFilename", "$appId.exe"'));
    expect(resource, contains('VALUE "InternalName", "$appId"'));
  });
}
