// lib/modules/logic_hotspot_part.dart
// Windows Mobile Hotspot WinRT management, ICS service repair, DHCP reset, and watchdog auto-heal.

part of 'logic.dart';

mixin _WifiHotspotMixin on _WifiGuardLogicBase {
  // ─── Windows Mobile Hotspot Control ───────────────────────────────────────

  @override
  Future<void> fetchHotspotConfig() async {
    if (!Platform.isWindows) return;
    try {
      final result = await _runHotspotNative(
          'powershell',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            'Add-Type -AssemblyName System.Runtime.WindowsRuntime; '
                '\$hotspotAdapter = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { \$_.InterfaceDescription -match "Wi-Fi Direct Virtual" -and \$_.Status -eq "Up" }; '
                '\$state = if (\$null -ne \$hotspotAdapter) { "Enabled" } else { "Disabled" }; '
                '\$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile(); '
                'if (\$null -eq \$connectionProfile) { '
                '  \$profiles = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetConnectionProfiles(); '
                '  if (\$null -ne \$profiles) { '
                '    \$activeProfiles = @(\$profiles) | Where-Object { \$null -ne \$_ } | Sort-Object { [int]\$_.GetNetworkConnectivityLevel() } -Descending; '
                '    if (\$activeProfiles.Count -gt 0 -and [int]\$activeProfiles[0].GetNetworkConnectivityLevel() -gt 0) { '
                '      \$connectionProfile = \$activeProfiles[0]; '
                '    } '
                '  } '
                '}; '
                'if (\$null -ne \$connectionProfile) { '
                '  \$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile(\$connectionProfile); '
                '  if (\$null -ne \$tetheringManager) { '
                '    \$config = \$tetheringManager.GetCurrentAccessPointConfiguration(); '
                '    [PSCustomObject]@{ Ssid = \$config.Ssid; Passphrase = \$config.Passphrase; Band = \$config.Band.ToString(); State = \$state; MaxClients = \$tetheringManager.MaxClientCount; ClientCount = \$tetheringManager.ClientCount } | ConvertTo-Json; '
                '  } else { '
                '    [PSCustomObject]@{ Ssid = ""; Passphrase = ""; Band = "Auto"; State = \$state; MaxClients = 8; ClientCount = 0 } | ConvertTo-Json; '
                '  } '
                '} else { '
                '  [PSCustomObject]@{ Ssid = ""; Passphrase = ""; Band = "Auto"; State = \$state; MaxClients = 8; ClientCount = 0 } | ConvertTo-Json; '
                '}'
          ],
          runInShell: false);

      final output = result.stdout.toString().trim();
      if (output.isNotEmpty && output.startsWith('{')) {
        final Map<String, dynamic> decoded = jsonDecode(output);
        _hotspotConfig = HotspotConfig.fromJson(decoded);
      } else {
        _logger.warning(
            'Invalid PowerShell output in fetchHotspotConfig: $output');
        _hotspotConfig = HotspotConfig(
          ssid: 'Offline / No Profile',
          passphrase: '',
          band: 'Auto',
          state: 'Disabled',
          maxClients: 8,
          clientCount: 0,
        );
      }
      notifyListeners();
    } catch (e) {
      _logger.warning('Failed to fetch hotspot config: $e');
      _hotspotConfig = HotspotConfig(
        ssid: 'Error Loading',
        passphrase: '',
        band: 'Auto',
        state: 'Disabled',
        maxClients: 8,
        clientCount: 0,
      );
      notifyListeners();
    }
  }

  /// Explicit ICS/Hotspot recovery; stuck-host termination requires sole ownership.
  @override
  Future<bool> repairIcsService({bool silent = false}) => _exclusiveHotspot(
        () => _repairIcsService(silent: silent),
        type: HotspotOperationType.fixIcs,
        totalSteps: 5,
        initialPhase: 'ics_read_profile',
      );

  void _mapRepairStepToBusyStatus(String step) {
    switch (step) {
      case 'Read Hotspot profile/state':
        _setHotspotPhase('ics_read_profile', stepIndex: 1, totalSteps: 5);
        break;
      case 'Stop icssvc':
      case 'Stop SharedAccess':
        _setHotspotPhase('ics_stop_services', stepIndex: 2, totalSteps: 5);
        break;
      case 'Start SharedAccess':
      case 'Wait SharedAccess Running':
      case 'Start icssvc':
      case 'Wait icssvc Running':
        _setHotspotPhase('ics_start_services', stepIndex: 3, totalSteps: 5);
        break;
      case 'Wait Hotspot stable':
        _setHotspotPhase('ics_wait_stable', stepIndex: 4, totalSteps: 5);
        break;
      case 'Verify services Running':
        _setHotspotPhase('ics_verify_refresh', stepIndex: 5, totalSteps: 5);
        break;
    }
  }

  Future<bool> _repairIcsService({bool silent = false}) async {
    if (!Platform.isWindows) return false;
    _icsRepairError = null;
    try {
      if (!silent) {
        await writeLog(
            'Đang khởi động lại dịch vụ ICS (SharedAccess) qua Win32 API...',
            level: 'WARN');
      }

      final repairFn = nativeIcsRepair ?? WinIcsNativeService.repairIcs;
      final recovery = await repairFn(
        timeout: hotspotCommandTimeout * 2,
        onProgressStep: _mapRepairStepToBusyStatus,
      ).timeout(hotspotCommandTimeout * 2);

      final isRunning = recovery['Ok'] == true &&
          recovery['ServicesRecovered'] == true &&
          const {'On', 'Off'}.contains(recovery['HotspotState']);
      if (!isRunning) {
        final step = (recovery['Step'] as String?)?.trim();
        final reason = (recovery['Error'] as String?)?.trim();
        _icsRepairError =
            '[${(step == null || step.isEmpty) ? 'Verify repair result' : step}] '
            '${(reason == null || reason.isEmpty) ? 'Service/Hotspot state not confirmed' : reason}';
      }

      if (!silent) {
        if (isRunning) {
          await writeLog(
              'Dịch vụ đã phục hồi; Hotspot=${recovery['HotspotState']}. '
              'Hãy bật lại Hotspot và kiểm tra thiết bị nhận IP; DHCP chưa được xác minh.',
              level: 'OK');
        } else {
          await writeLog('Sửa dịch vụ Hotspot/ICS thất bại: $_icsRepairError',
              level: 'WARN');
        }
      }

      if (isRunning) {
        _setHotspotPhase('ics_verify_refresh', stepIndex: 5, totalSteps: 5);
        final rawConfig = recovery['Config'];
        if (rawConfig is Map) {
          final cfgMap = <String, dynamic>{};
          rawConfig.forEach((key, value) {
            if (key != null) cfgMap[key.toString()] = value;
          });
          _hotspotConfig = HotspotConfig.fromJson(cfgMap);
        } else {
          _hotspotConfig = HotspotConfig(
            ssid: 'Offline / No Profile',
            passphrase: '',
            band: 'Auto',
            state: recovery['HotspotState'] == 'On' ? 'Enabled' : 'Disabled',
            maxClients: 8,
            clientCount: 0,
          );
        }
        notifyListeners();
      }
      return isRunning;
    } catch (e) {
      _icsRepairError = e is TimeoutException
          ? '[Repair helper timeout] ${e.message ?? 'Native command timed out'}'
          : '[Repair command] $e';
      if (!silent) {
        await writeLog('Lỗi khi sửa lỗi dịch vụ ICS: $_icsRepairError',
            level: 'WARN');
      }
      _logger.warning('Failed to repair ICS service: $e');
      return false;
    }
  }

  /// Resets the Internet Connection Sharing (ICS) service to clear any DHCP leaks.
  Future<void> resetSharedAccessService() async {
    if (!Platform.isWindows) return;
    try {
      await repairIcsService(silent: true);
    } catch (e) {
      _logger.warning('Failed to reset SharedAccess service: $e');
    }
  }

  Future<bool> updateHotspotConfig(
          String ssid, String passphrase, String band, int maxClients) =>
      _exclusiveHotspot(
        () => _updateHotspotConfig(ssid, passphrase, band, maxClients),
        type: HotspotOperationType.updateConfig,
        totalSteps: 1,
        initialPhase: 'hotspot_configuring',
      );

  Future<bool> _updateHotspotConfig(
      String ssid, String passphrase, String band, int maxClients) async {
    if (!Platform.isWindows) return false;
    const supportedBands = {
      'Auto',
      'TwoPointFourGigahertz',
      'FiveGigahertz',
      'SixGigahertz',
    };
    if (ssid.trim().isEmpty ||
        passphrase.trim().length < 8 ||
        !supportedBands.contains(band) ||
        maxClients < 1 ||
        maxClients > 128) {
      return false;
    }

    final safeSsid = _escapePowerShellSingleQuoted(ssid);
    final safePassphrase = _escapePowerShellSingleQuoted(passphrase);
    try {
      final result = await _runHotspotNative(
          'powershell',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            'Add-Type -AssemblyName System.Runtime.WindowsRuntime; '
                '\$asTaskAction = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { \$_.Name -eq "AsTask" -and \$_.GetParameters().Count -eq 1 -and !\$_.IsGenericMethod -and \$_.GetParameters()[0].ParameterType.Name -eq "IAsyncAction" })[0]; '
                'function AwaitAction(\$WinRtAction) { '
                '  \$netTask = \$asTaskAction.Invoke(\$null, @(\$WinRtAction)); '
                '  if (!\$netTask.Wait(20000)) { \$WinRtAction.Cancel(); throw "Hotspot configuration timed out" } '
                '}; '
                '\$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile(); '
                'if (\$null -eq \$connectionProfile) { '
                '  \$profiles = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetConnectionProfiles(); '
                '  if (\$null -ne \$profiles) { '
                '    \$activeProfiles = @(\$profiles) | Where-Object { \$null -ne \$_ } | Sort-Object { [int]\$_.GetNetworkConnectivityLevel() } -Descending; '
                '    if (\$activeProfiles.Count -gt 0 -and [int]\$activeProfiles[0].GetNetworkConnectivityLevel() -gt 0) { '
                '      \$connectionProfile = \$activeProfiles[0]; '
                '    } '
                '  } '
                '}; '
                'if (\$null -ne \$connectionProfile) { '
                '  \$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile(\$connectionProfile); '
                '  if (\$null -ne \$tetheringManager) { '
                '    \$config = New-Object Windows.Networking.NetworkOperators.NetworkOperatorTetheringAccessPointConfiguration; '
                "    \$config.Ssid = '$safeSsid'; "
                "    \$config.Passphrase = '$safePassphrase'; "
                '    \$config.Band = [Windows.Networking.NetworkOperators.TetheringWiFiBand]::$band; '
                '    AwaitAction (\$tetheringManager.ConfigureAccessPointAsync(\$config)); '
                '    New-ItemProperty -Path "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\icssvc\\Settings" -Name "WifiMaxPeers" -Value $maxClients -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null; '
                '    "Configured"; '
                '  } else { "NoTetheringManager"; exit 1; }'
                '} else { "NoConnectionProfile"; exit 1; }'
          ],
          runInShell: false);

      final statusLines = result.stdout
          .toString()
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      final status = statusLines.isEmpty ? null : statusLines.last;
      final succeeded = result.exitCode == 0 && status == 'Configured';
      if (!succeeded) {
        _logger.warning(
            'Hotspot configuration failed: exit=${result.exitCode}, status=$status, stderr=${result.stderr}');
        return false;
      }
      await writeLog(
          'Updated Mobile Hotspot settings: SSID=$ssid, Band=$band, MaxClients=$maxClients (Registry updated)',
          level: 'OK');
      await fetchHotspotConfig();
      return true;
    } catch (e) {
      _logger.warning('Failed to update hotspot config: $e');
      return false;
    }
  }

  @override
  Future<bool> setHotspotState(bool enable, {bool isUserInitiated = true}) {
    if (isUserInitiated) {
      _userManuallyStoppedHotspot = !enable;
    }
    return _exclusiveHotspot(
      () => _setHotspotState(enable),
      type: HotspotOperationType.toggle,
      totalSteps: 1,
      initialPhase: enable ? 'hotspot_enabling' : 'hotspot_disabling',
    );
  }

  /// Periodically checks if Windows Mobile Hotspot was unexpectedly turned off by OS power-saving
  /// and automatically restarts it when [autoStartHotspotEnabled] is true and the user did not manually stop it.
  Future<bool> checkAndHealHotspotIfNeeded({
    required bool autoStartHotspotEnabled,
    Duration cooldown = const Duration(seconds: 30),
  }) async {
    if (!Platform.isWindows) return false;
    if (!autoStartHotspotEnabled || _userManuallyStoppedHotspot) return false;
    if (_hotspotOperationInProgress) return false;

    final now = DateTime.now();
    if (_lastHotspotAutoHealAttempt != null &&
        now.difference(_lastHotspotAutoHealAttempt!) < cooldown) {
      return false;
    }

    await fetchHotspotConfig();
    final cfg = _hotspotConfig;
    if (cfg == null) return false;
    if (cfg.state == 'Enabled' || cfg.state == 'Enabling') return false;
    if (cfg.ssid.isEmpty ||
        cfg.ssid == 'Offline / No Profile' ||
        cfg.ssid == 'Error Loading') {
      return false;
    }

    _lastHotspotAutoHealAttempt = now;
    await writeLog(
      'Hotspot Watchdog: Phát hiện Mobile Hotspot bị tắt ngoài ý muốn, đang tự động bật lại...',
      level: 'WARN',
    );
    return await setHotspotState(true, isUserInitiated: false);
  }

  Future<bool> _setHotspotState(bool enable) async {
    if (!Platform.isWindows) return false;
    try {
      final action = enable ? "StartTetheringAsync" : "StopTetheringAsync";
      final result = await _runHotspotNative(
          'powershell',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            'Add-Type -AssemblyName System.Runtime.WindowsRuntime; '
                '\$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { \$_.Name -eq "AsTask" -and \$_.GetParameters().Count -eq 1 -and \$_.IsGenericMethod })[0]; '
                'function Await(\$WinRtTask, \$ResultType) { '
                '  \$asTask = \$asTaskGeneric.MakeGenericMethod(\$ResultType); '
                '  \$netTask = \$asTask.Invoke(\$null, @(\$WinRtTask)); '
                '  if (!\$netTask.Wait(20000)) { \$WinRtTask.Cancel(); throw "Hotspot operation timed out" }; '
                '  \$netTask.Result '
                '}; '
                '\$connectionProfile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile(); '
                'if (\$null -eq \$connectionProfile) { '
                '  \$profiles = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetConnectionProfiles(); '
                '  if (\$null -ne \$profiles) { '
                '    \$activeProfiles = @(\$profiles) | Where-Object { \$null -ne \$_ } | Sort-Object { [int]\$_.GetNetworkConnectivityLevel() } -Descending; '
                '    if (\$activeProfiles.Count -gt 0 -and [int]\$activeProfiles[0].GetNetworkConnectivityLevel() -gt 0) { '
                '      \$connectionProfile = \$activeProfiles[0]; '
                '    } '
                '  } '
                '}; '
                'if (\$null -ne \$connectionProfile) { '
                '  \$tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile(\$connectionProfile); '
                '  if (\$null -ne \$tetheringManager) { '
                '    \$res = Await (\$tetheringManager.$action()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult]); '
                '    \$res.Status.ToString(); '
                '  } else { "NoTetheringManager"; exit 1; }'
                '} else { "NoConnectionProfile"; exit 1; }'
          ],
          runInShell: false);

      final statusLines = result.stdout
          .toString()
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      final status = statusLines.isEmpty ? null : statusLines.last;
      final successfulStatuses = {
        'Success',
        if (enable) 'AlreadyOn',
        if (!enable) 'AlreadyOff',
      };
      final succeeded = result.exitCode == 0 &&
          status != null &&
          successfulStatuses.contains(status);
      if (!succeeded) {
        _logger.warning(
            'Failed to set hotspot state: enable=$enable, exit=${result.exitCode}, status=$status, stderr=${result.stderr}');
        return false;
      }
      final stateLabel = enable ? 'Enabled' : 'Disabled';
      await writeLog('Set Mobile Hotspot state -> $stateLabel', level: 'INFO');
      await fetchHotspotConfig();
      return true;
    } catch (e) {
      _logger.warning('Failed to set hotspot state: $e');
      return false;
    }
  }

  Future<bool> fixHotspotDhcp() => _exclusiveHotspot(
        _fixHotspotDhcp,
        type: HotspotOperationType.fixDhcp,
        totalSteps: 3,
        initialPhase: 'dhcp_stop_hotspot',
      );

  Future<bool> _fixHotspotDhcp() async {
    if (!Platform.isWindows) return false;
    try {
      await writeLog(
          'Bắt đầu quy trình tự động sửa lỗi IP/DHCP Mobile Hotspot...',
          level: 'WARN');

      // 1. Stop Hotspot first
      _setHotspotPhase('dhcp_stop_hotspot', stepIndex: 1, totalSteps: 3);
      final stopOk = await _setHotspotState(false);
      if (!stopOk) {
        await writeLog(
            'Không thể xác nhận Hotspot đã dừng; dừng sửa ICS/DHCP để tránh xung đột.',
            level: 'WARN');
        return false;
      }

      // 2. Explicit service-control repair, not a service-host PID kill.
      _setHotspotPhase('dhcp_repair_ics', stepIndex: 2, totalSteps: 3);
      await writeLog(
          'Đang khởi động lại dịch vụ Internet Connection Sharing (ICS) an toàn...',
          level: 'INFO');
      final icsOk = await _repairIcsService(silent: false);
      if (!icsOk) {
        await writeLog(
            'Không thể khởi động lại dịch vụ ICS; dừng quy trình sửa DHCP.',
            level: 'WARN');
        return false;
      }

      // 3. Reset network interface configurations (Winsock and DNS flush)
      _setHotspotPhase('dhcp_reset_winsock', stepIndex: 3, totalSteps: 3);
      await writeLog('Đang đặt lại Winsock và xoá bộ nhớ đệm DNS...',
          level: 'INFO');
      final networkResult = await _runHotspotNative(
          'powershell',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            '\$ErrorActionPreference = "Stop"; '
                'netsh winsock reset; '
                'if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE }; '
                'ipconfig /flushdns; '
                'exit \$LASTEXITCODE'
          ],
          runInShell: false);

      if (networkResult.exitCode != 0) {
        await writeLog(
            'Không thể reset Winsock/DNS (exit=${networkResult.exitCode}).',
            level: 'WARN');
        return false;
      }

      await writeLog(
          'Đã sửa lỗi IP/DHCP thành công! Bạn có thể bật lại Mobile Hotspot.',
          level: 'OK');
      await fetchHotspotConfig();
      return true;
    } catch (e) {
      await writeLog('Lỗi trong quá trình sửa lỗi IP/DHCP: $e', level: 'WARN');
      return false;
    }
  }
}
