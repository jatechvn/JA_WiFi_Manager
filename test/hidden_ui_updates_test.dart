import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_wifi_manager/modules/services/app_power_manager.dart';
import 'package:ja_wifi_manager/modules/ui/widgets/visible_ui_listener.dart';

void main() {
  final power = AppPowerManager.instance;
  setUp(power.resetForTesting);
  tearDown(power.resetForTesting);

  test('Native snapshots do not reopen explicit tray hide', () async {
    power.onWindowVisibilityChanged(false);
    expect(
        await power.synchronizeWindowState(
          isVisible: () async => true,
          isFocused: () async => true,
        ),
        isFalse);
    expect(power.shouldAnimateIndicators, isFalse);
    expect(
        await power.synchronizeWindowState(
          isVisible: () async => true,
          isFocused: () async => true,
          reconcileFailedHide: true,
        ),
        isTrue);
    expect(power.shouldAnimateIndicators, isTrue);
  });

  test('Dead owner cannot apply a native reply', () async {
    power.onWindowBlur();
    expect(
        await power.synchronizeWindowState(
          isVisible: () async => true,
          isFocused: () async => true,
          isAlive: () => false,
        ),
        isFalse);
    expect(power.shouldAnimateIndicators, isFalse);
  });

  testWidgets('Repeated focused native checks preserve idle deadline',
      (tester) async {
    await power.initialize(enableIdleSleep: true, idleTimeoutSeconds: 12);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 2));
      await power.synchronizeWindowState(
        isVisible: () async => true,
        isMinimized: () async => false,
        isFocused: () async => true,
      );
    }
    expect(power.isUserIdle, isTrue);
    expect(power.shouldAnimateBackground, isFalse);
    expect(power.shouldAnimateIndicators, isTrue);
  });

  test('Late focus snapshot cannot undo a new hide event', () async {
    final focus = Completer<bool>();
    final query = power.synchronizeWindowState(
      isVisible: () async => true,
      isFocused: () => focus.future,
    );
    await Future<void>.delayed(Duration.zero);
    power.onWindowVisibilityChanged(false);
    focus.complete(true);
    expect(await query, isFalse);
    expect(power.isWindowVisible, isFalse);
    expect(power.shouldAnimateIndicators, isFalse);
  });

  test('Late visibility query and invalidated query never apply', () async {
    final visible = Completer<bool>();
    var queriedFocus = false;
    final query = power.synchronizeWindowState(
      isVisible: () => visible.future,
      isFocused: () async {
        queriedFocus = true;
        return true;
      },
    );
    power.invalidateWindowSnapshot();
    visible.complete(true);
    expect(await query, isFalse);
    expect(queriedFocus, isFalse);
  });

  test('Newer query wins even when older query completes last', () async {
    final oldVisible = Completer<bool>();
    final oldQuery = power.synchronizeWindowState(
      isVisible: () => oldVisible.future,
      isFocused: () async => true,
    );
    expect(
        await power.synchronizeWindowState(
          isVisible: () async => false,
          isFocused: () async => true,
        ),
        isTrue);
    oldVisible.complete(true);
    expect(await oldQuery, isFalse);
    expect(power.isWindowVisible, isFalse);
  });

  test('Hidden burst preserves source updates and flushes UI once on show', () {
    final source = ValueNotifier<int>(0);
    var uiUpdates = 0;
    var businessUpdates = 0;
    source.addListener(() => businessUpdates++);
    final listener = VisibleUiListener(
      source: source,
      visibility: power.windowVisibilityNotifier,
      onUpdate: () => uiUpdates++,
    );
    power.onWindowVisibilityChanged(false);
    for (var i = 1; i <= 100; i++) {
      source.value = i;
    }
    expect(uiUpdates, 0);
    expect(businessUpdates, 100);
    expect(source.value, 100);
    power.onWindowVisibilityChanged(true);
    expect(uiUpdates, 1);
    power.onWindowRestore();
    expect(uiUpdates, 1);
    source.value = 101;
    expect(uiUpdates, 2);
    listener.dispose();
    source.value = 102;
    expect(uiUpdates, 2);
    source.dispose();
  });
}
