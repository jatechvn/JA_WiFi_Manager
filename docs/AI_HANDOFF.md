# Handoff — 2026-10-03

## 2026-11-16 (Update 2): Native Win32 SCM + WinRT C++ ICS Recovery (Zero PowerShell / Symantec SONAR Fix)

- **Root Cause Eliminated**:
  - Previously, Fix ICS (`repairIcsService`) spawned `powershell.exe -NonInteractive -WindowStyle Hidden` with inline `Stop-Process -Force` in the legacy PowerShell repair script, triggering Symantec Endpoint Protection SONAR (`SONAR.Powershell` / `AGR.Terminate` on `ja_wifi_manager.exe` and `powershell.exe`).
- **Native Win32 SCM + WinRT C++ Migration**:
  - Replaced PowerShell ICS execution with native C++ (`windows/runner/ics_service_repair.h`, `windows/runner/ics_service_repair.cpp`) using `advapi32` Service Control Manager APIs (`OpenSCManagerW`, `OpenServiceW`, `QueryServiceStatusEx`, `ControlService(..., SERVICE_CONTROL_STOP, ...)`, `StartServiceW`) and exception-free (`_HAS_EXCEPTIONS=0`) WinRT ABI (`INetworkInformationStatics`, `INetworkOperatorTetheringManagerStatics2`, `INetworkOperatorTetheringAccessPointConfiguration2`), completely free of `TerminateProcess` / `taskkill` / `powershell.exe`.
  - Added `IcsRepairChannel` (`windows/runner/ics_repair_channel.h`, `windows/runner/ics_repair_channel.cpp`) wired into `FlutterWindow` (`windows/runner/flutter_window.cpp`, `windows/runner/flutter_window.h`, `windows/runner/CMakeLists.txt`) over `MethodChannel('ja_wifi_manager/ics_repair')`, running live repair on a worker thread and marshaling live progress steps + completion onto the Win32 UI thread via `PostMessageW` (`kWmIcsRepairStep` / `kWmIcsRepairDone`) with clean `Shutdown()` teardown.
  - Added `WinIcsNativeService` (`lib/modules/native/win_ics_service.dart`), wired `nativeIcsRepair` into `WifiGuardLogic` (`lib/modules/logic.dart`, `lib/modules/logic_hotspot_part.dart`) hydrating `_hotspotConfig` directly from the returned `Config` map (0 PowerShell spawns during ICS repair), and removed `-NonInteractive -WindowStyle Hidden` from the remaining Hotspot PowerShell helpers.
  - Deleted legacy PowerShell ICS repair script files (`hotspot_repair_script.dart` and `hotspot_repair_script_test.ps1` — approved by user) and added MSVC C++17 unit tests in `test/native/ics_service_repair_test.cpp` alongside updated `test/hotspot_operations_test.dart` and `test/ics_progress_banner_test.dart`.

## 2026-11-16 (Update): Fix ICS Freeze Elimination & Inline Progress Banner (Style 1)

- **Root Cause Fix (No UI Freeze During ICS / Hotspot Recovery)**:
  - Added interactive operation lease (`beginInteractiveOperation` / `endInteractiveOperation`) on `AppPowerManager` (`lib/modules/services/app_power_manager.dart`) inside `_exclusiveHotspot` (`lib/modules/logic.dart`) so a visible window keeps indicator/spinner rendering active even across transient OS/focus flickers while `SharedAccess`/`icssvc` resets, restoring full 0% tray/blur GPU gating immediately on completion.
  - Resolved `AppLifecycleState.resumed` vs `onWindowFocus` revision cancellation race in `lib/modules/ui/main_window.dart`.
  - Deferred periodic 5s/Guard ARP/WMI PowerShell queries (`_performSingleGuardCheckPass`, `scanConnectedClients`, and `MainWindow` refresh timer) while `isHotspotBusy` is `true`, and switched `readLogLines`/`writeLog`/`clearLogs` in `lib/modules/logic_logs_admin_part.dart` to serialized async I/O (`_logIoChain`) so slow cloud/OneDrive folders never stall the UI isolate.
  - Note: Legacy `-NonInteractive -WindowStyle Hidden` flags and the PowerShell hotspot repair script were removed in Update 2 (above).
- **Live PowerShell Step Streaming & Inline Bento Progress Banner**:
  - Originally streamed `JA_STEP:<phase>` from PowerShell hotspot_repair_script.dart (superseded in Update 2 by native Win32/WinRT C++ `onProgress` events).
  - Added `HotspotOperationType` & `HotspotBusyStatus` in `lib/modules/models/wifi_models.dart`, wired real-time step updates across 5 ICS phases and 3 DHCP phases, and created `lib/modules/ui/widgets/hotspot_operation_progress_banner.dart` embedded inline inside `MonitorTab` (`monitor_hotspot_banner.dart`) and `HotspotTab` (`hotspot_tab.dart`) with VI/EN/ZH step labels, animated progress bar, and live `00:XXs` elapsed timer.
  - Added regression & widget tests in `test/ics_progress_banner_test.dart`.

## 2026-11-16: Project AI Optimizer (Docs Map, Handoff Sync & Modular Extraction)

- **Navigation & Documentation**:
  - Added [AI_CONTEXT.md](AI_CONTEXT.md) covering all source directories, module owners, runtime state files (`config.ini`, `whitelist.json`, `blacklist.json`, `device_names.json`, `blocked_session.json`, `update_config.json`), and verification commands.
  - Added root shim [CLAUDE.md](../CLAUDE.md) and 6 targeted `MODULE.md` boundary guides (`lib/modules/`, `lib/modules/services/`, `lib/modules/ui/`, `lib/modules/ui/widgets/`, `windows/runner/`, `test/`).
  - Fixed missing `skills_guide.md` references in [AGENTS.md](../AGENTS.md), updated stale forced-PID-kill ICS docs to safe bounded `ServiceController` recovery in [README.md](../README.md) & [USERGUIDE.md](../USERGUIDE.md), and qualified `windows/runner/single_instance.h`.
- **Cohesive Modular Refactoring (Zero Breaking API Changes)**:
  - Extracted `WifiGuardLogic` domain parts (`lib/modules/models/wifi_models.dart` + 6 `part` mixins: `logic_logs_admin_part.dart`, `logic_device_store_part.dart`, `logic_blacklist_part.dart`, `logic_guard_engine_part.dart`, `logic_scanner_part.dart`, `logic_hotspot_part.dart`) while preserving subclass `@override` support and test contracts.
  - Extracted `lib/modules/services/ota_update_models.dart`, `lib/modules/ui/widgets/power_optimizer_card.dart`, `ota_settings_card.dart`, `ota_settings_form.dart`, `monitor_hotspot_banner.dart`, `monitor_kpi_row.dart`, `monitor_bento_device_card.dart`, and `monitor_compact_device_table.dart`; removed unreferenced legacy `StatCard`/`ClientRow` stubs.
- **Prior Uncommitted Stability & Resilience Upgrade (Verified in Full Suite)**:
  - Added `AtomicFileStore` (`.tmp` -> `.bak` atomic persistence & corruption auto-recovery), `blocked_session.json` session persistence surviving log clears/pruning, guard/scan re-entrancy coalescing + 12s bounded native timeouts + idempotent ARP/Firewall blocking, 30s Hotspot Watchdog (`checkAndHealHotspotIfNeeded`), and `trayManager.destroy()` cleanup prior to OTA `exit(0)`.

## 2026-10-14: bounded Hotspot settling and phase-specific repair failures

- User tested a separately built Release (AOT SHA256
  51A1E86FA30AF2928BE57183A7C4D0BC573067D4303EC29A34B6BB27F5731AF0).
  Release wifi_guard.log reported InTransition after service recovery at
  09:30:21.936, then second manual repair succeeded with Off at 09:30:34.674.
  Installed Programs copy still has old AOT hash; distinguish these runtime paths.
- Added Wait-HotspotStable: read a fresh native manager every 500 ms for at most
  60 reads (~30 seconds). On/Off settles; InTransition waits; unknown/no-manager
  fails. No repeat stop/start/kill is issued by the polling loop. Outer explicit
  repair deadline remains 90 seconds. No automatic second repair attempt.
- Structured failure JSON carries Step and Error for profile lookup, service
  stop/start/wait, Hotspot settling and final verification. Dart retains the
  current repair error and passes it to both Monitor and Hotspot UI snackbars.
  Helper timeout and malformed helper response are separately labeled. Logging
  no longer embeds the full PowerShell source/error dump for expected failures.
- Failed recovery no longer does an extra config refresh before returning to UI;
  successful recovery still refreshes. New operation clears stale repair error.
- Verification: analyzer clean, dart format . passed (52 files), full suite 98
  Flutter tests passed; PowerShell syntax + 8 fully mocked recovery scenarios
  passed; diff check passed. Tests cover delayed settling without repeat service
  operations, timeout phase, structured error propagation/clearing, helper timeout
  and actual Monitor banner snackbar showing the exact phase-specific error.
- Source only: no new Release build/install, live repair or network changes in
  this turn. User's running Release does not yet contain the latest settling/UI
  changes. Actual native responsiveness, SSID broadcast and DHCP remain open.

## 2026-10-14: integrate explicit InTransition recovery into Fix ICS

- Read D:/JA_TESTER/CONFIG/repair_hotspot_services.ps1 and its BAT wrapper; embedded
  the scoped service recovery in lib/modules/services/hotspot_repair_script.dart
  so portable app builds need neither external file. External originals unchanged.
- Explicit Fix ICS reads native TetheringOperationalState. If InTransition, stops
  icssvc before SharedAccess, starts SharedAccess before icssvc, and rereads native
  Hotspot state. Normal repair does not stop icssvc. Active profile fallback is
  supported; missing profile/manager fails rather than guessing a repair target.
- Graceful stops first. Only after bounded stop wait fails, Stop Pending with a
  nonzero PID and sole service ownership can authorize terminating that host.
  PID/state AND owner list are rechecked immediately before Stop-Process. Co-hosted
  services, changed PID/owners or non-StopPending state fail closed. This scoped
  explicit-repair exception supersedes the earlier blanket no-host-kill statement;
  normal Hotspot enable still never restarts/kills ICS.
- Per-service waits 8 seconds (5 after scoped termination); explicit repair helper
  timeout 90 seconds at default settings, while ordinary Hotspot commands stay at
  30 seconds. Existing shared operation lock remains. Failure attempts to restart
  originally running services that were stopped; it does not force other hosts.
- Structured JSON service result requires ServicesRecovered and native On/Off,
  rejecting still InTransition, malformed and unknown state. Success text now says
  to turn Hotspot on and verify client DHCP; DHCP is explicitly not verified.
- Did not integrate BAT firewall/ARP deletion, full network reset, or auto-enable.
  Guard/OTA unchanged. Repair may disconnect hotspot clients by design.
- Verification: PowerShell parser + 7 fully mocked native-script scenarios passed
  (normal/transition ordering, co-host refusal, PID and ownership races, continued
  transition failure, isolated stuck-host recovery). Analyzer clean, format 52
  files passed, full Flutter suite 95 tests passed, git diff --check passed.
- No real repair/service commands executed and no network/runtime data changed.
  New Release not built/installed; live broadcast, DHCP/device bc4cd33a, helper
  timeout cancellation and UI responsiveness remain runtime acceptance work.

## 2026-10-14: Hotspot lifecycle safety fix (source verified)

- Removed default SharedAccess reset from setHotspotState(true) and the extra
  reset in auto-start. Normal enable only calls StartTetheringAsync.
- Explicit ICS repair now uses ServiceController stop/start with 10-second
  bounded waits, checks successful exit code and rejects pending transitions.
  No taskkill/service-host PID kill remains in the Hotspot implementation.
- Hotspot start/stop/config WinRT waits now have a 20-second deadline and request
  Cancel on timeout. Hotspot native helper commands (including config refresh and
  explicit DHCP repair) have a 30-second Dart deadline; timeout terminates only
  the owned PowerShell helper and waits up to 3 seconds for its exit. Windows may
  still need time to settle an already submitted service/network operation; a
  timeout is failure, not proof of cancellation or a prompt to retry automatically.
- Shared logic lock covers toggle, config apply, ICS repair and DHCP repair across
  screens/auto-start; overlap fails without submitting another native command.
  Internal DHCP sequence uses private steps to avoid self-deadlock. If Hotspot
  stop cannot be confirmed, DHCP repair aborts before ICS or Winsock changes.
- Updated ICS working messages VI/EN/ZH and Monitor/Hotspot busy guards. Guard
  timers, OTA and their native-command runner were not changed.
- Six fake-native regression tests cover no default ICS reset, shared concurrency,
  timeout/late result, native error/exception, safe repair script, stop failure and
  successful internal DHCP sequence. Analyzer clean; format 51 files passed; full
  Flutter suite 94 tests passed; git diff --check passed.
- No actual network commands, service restart or process termination performed
  during verification. Source tests do not prove native helper cancellation, SSID
  broadcast, DHCP or driver recovery. No release build/install/commit/push run.
  Existing handoff edits preserved. Next: build a new Release after user exits the
  installed app normally; validate actual broadcast plus client DHCP separately.

## 2026-10-14: read-only Hotspot/ICS incident diagnosis

- User reports overnight Hotspot freeze persisting after reboot; no repair or
  network configuration change authorized/performed in this turn.
- Current boot at 01:52:18 +07; WiFi app PID 20900 started 07:38:19 (path unavailable).
  SharedAccess, icssvc, WlanSvc and BFE all Running during observation. Wi-Fi Direct
  adapter #2 is Up. These snapshots do not prove SSID broadcast or client DHCP.
- SCM 7031 records ICS terminated unexpectedly at 08:10:32.355 and 08:10:36.619.
  Installed wifi_guard.log records app repairIcsService PID-force-kill actions at
  08:10:32 and 08:10:36, then reports Running at 08:10:34 and 08:10:38. Strong direct
  temporal/code evidence that these two terminations were caused by app repair,
  not independent evidence of an ICS crash. No overnight Oct 13 daily log found
  at inspected installed path; cannot establish the cause of the overnight event.
- Source defect/risk: repairIcsService unconditionally taskkill /F of SharedAccess
  host PID without checking StopPending or co-hosted services. Every Hotspot enable
  calls this through resetSharedAccessService; auto-start procedure also resets
  before setHotspotState, so it can reset twice. WinRT start/stop awaits Wait(-1),
  and Process.run has no timeout, leaving a hung operation/UI possible.
- App is plausibly contributing and confirmed to forcibly terminate ICS today,
  but persistence after reboot alone does not prove app is the sole original cause.
  No implementation changes. Next: authorize safe service lifecycle/timeout fix,
  then separately verify native Windows Hotspot with app normally exited, checking
  actual SSID and client DHCP address rather than merely service Running.

## 2026-10-05: diagnostic of reported OTA 1.2.1 to 1.2.2 freeze

- User clarified symptom: update dialog stays at 100%. Diagnosis only; no updater,
  application launch, process termination, configuration change or app patch run.
- Actual staging: C:/Users/FT/AppData/Local/Temp/JA_WiFi_Manager_Update_1818af13.
  Generated batch targets C:/Users/FT/AppData/Local/Programs/JA_WiFi_Manager and
  old PID 54956. ZIP SHA256 matches dist/version.json:
  497679753a65c11c774fcc9f6c587866bf370db7e4299e00310873932bd05ba4.
- Backup and apply logs ended 2026-10-05 09:24:34 with zero failed files. Installed
  EXE version is 1.2.2+13. EXE, app.so, flutter_windows.dll, window_manager,
  tray_manager and flutter_acrylic plugin hashes match extracted staging exactly.
  Daily log shows initialization at 09:24:34 and Guard start at 09:24:36. Guard
  activity continues through 09:27 before normal stop. No matching Application
  error/WER event was returned in the queried 09:23-09:30 window; this is not proof
  that no failure occurred. Cannot determine whether user intervention preceded
  these transitions from existing logs.
- Updater handoff/apply code is unchanged between release commits 1951966 (1.2.1)
  and d0481d8 (1.2.2); only SHA256SUMS fallback was added to the service. UI emits
  100% before launching installer. There is no installer completion/startup health
  acknowledgement and no handoff phase log; two-second wait is not health proof.
- Hypothesis that Process.run waits for inherited child stdout, creating an old-PID
  deadlock, was NOT reproduced: temporary harmless Dart probe baseline 158 ms,
  Start-Process cmd hidden with four-second sleeping child 177 ms, both code zero.
  Probe source removed after use; no runtime/staging/log files removed. Do not
  report this rejected hypothesis as the incident's cause.
- Conclusion: payload/hash/copy failure ruled out for this retained attempt;
  misleading 100%/missing handoff observability confirmed. Exact cause of the
  visible freeze remains unconfirmed. Manual 1.2.2 install bypasses 1.2.1 handoff,
  but does not fix unchanged updater for future OTAs. Next needs controlled
  reproduction with phase/PID/installer exit/startup acknowledgement diagnostics,
  authorized separately before any actual installed-app update.

## 2026-10-05: scheduler power gate (native acceptance pending)

- Used current explicitly requested global gpt-flutter-power-optimizer and its
  policy, workflow, scheduler/remote lifecycle, tests and acceptance references.
  Production had TickerMode and hidden rebuild coalescing but no scheduler gate.
- Added PowerWidgetsBinding with shared PowerFramePolicy, installed before plugins.
  framesEnabled ANDs the superclass lifecycle policy with the coordinator's
  active indicator gate. Reactivation requests one ordinary frame to replay dirty
  UI; focused idle does not gate frames. Forced/warm-up/native frames are outside
  this suppression policy, so no universal zero-GPU claim is supported.
- Coordinator now starts muted until native visibility/minimized/foreground checks.
  Explicit tray hide rejects stale focus/resumed/native snapshots until genuine
  show/restore (or verified reconciliation of failed hide). Snapshots check owner
  liveness and preserve the idle deadline when native state is unchanged.
- MainWindow verifies focus/restore/resumed against window_manager native state
  (Windows IsFocused compares GetForegroundWindow), polls every 2 seconds with
  poll coalescing, cancels polling on disposal and invalidates late replies. Native
  event checks supersede old snapshots. UI refresh timer is no longer restarted
  on unchanged active snapshots. No Guard or OTA code was changed.
- Added tests exercising production policy on an AutomatedTestWidgets binding:
  real periodic setState/business timer advances with no ordinary frame request
  while blurred; focus schedules accumulated dirty UI; focused idle retains frames;
  hidden/resumed and minimized are gated; superclass paused lifecycle wins.
  Additional coordinator tests cover failed hide reconciliation, dead owners and
  preservation of the 12-second idle deadline across 2-second native checks.
- Verification: analyzer clean, dart format . passed (50 files), full suite 88
  tests passed, git diff --check passed. No dependency added. The initial new test
  left its idle timer pending; explicit test cleanup fixed it before the full pass.
- Native runtime currently has ja_wifi_manager.exe PID 33444 (path unavailable
  through current process query). Do not identify it as the new code or reuse old
  GPU results as evidence for this patch. No process was stopped; no outputs,
  runtime config, whitelist, blacklist, dist or backups were deleted.
- Awaiting user exit via tray before new Release build/launch and Guard-on native
  measurements (focused, blurred, minimized, tray-hidden, restore without focus).
  Native UI responsiveness, remote session behavior, live Guard enforcement and
  OTA progress remain unverified. No packaging/release publishing requested.

## Latest fix: friendly Windows caption and EXE display identity

- User approved restoring a named caption on Windows 10 and requested the app
  name instead of the executable name. Dart startup now uses appName on all OS
  versions; native CreateWindow preserves the supplied non-empty caption.
- Runner.rc FileDescription and ProductName now read JA WiFi Hotspot Guard.
  InternalName/OriginalFilename remain ja_wifi_manager/ja_wifi_manager.exe so OTA,
  launch paths and single-instance identity are unchanged. Task Manager's Details
  image-name column may still show the actual filename, by design.
- Added two source-contract tests in test/windows_app_identity_test.dart. Analyzer
  clean; format 48 files (2 changed); full suite 82 tests passed; diff check passed.
  Release build passed. Read-back of built EXE confirms friendly FileDescription
  and ProductName, version 1.2.1+12. SHA256:
  11455E715696B63A25B28C506905DAB0EB0912A100E9C18CAEE7ACCF31E2EB2F.
- Profile PID 56700 was not closed or replaced. New Release was not launched;
  actual Task Manager display and Windows 10 glass-caption appearance still need
  runtime QA after the user normally exits Profile and opens the new Release.
  Windows 10 may again draw a solid background behind native caption text.

## Latest diagnostic: visible Guard-on lag (not yet reproduced in foreground)

- Profile build passed without clean. User exited Release normally; elevated
  Profile PID 56700 was launched with an authenticated loopback VM service.
  Guard active was confirmed via VM state; no Guard/OTA configuration was changed.
- Added diagnostic scripts launch_profile_probe.ps1 and capture_profile_probe.ps1.
  Capture invokes measure_app_power.ps1 in child scope to avoid overwriting its
  sample count. An earlier one-sample capture is incomplete and not evidence.
- Valid second capture: build/profile-lag-verified-41505238c1ee4dc2867a3c52519369e5.
  30 valid GPU samples over 31.385 seconds; maximum engine utilization average
  0.049835%, peak 0.267379%. Parent CPU averaged 0.398279% of one core; this excludes
  child processes and is not a Release responsiveness benchmark.
- Native main HWND was visible and not minimized in all 30 samples, but foreground
  in zero samples. App focus was false before and after, consistent with native
  observations. A subsequent read-only foreground query identified PID 24668,
  ja_lan_messenger, in the same session. This does not prove focus stealing or that
  the user interacted with the wrong app. Foreground interaction lag remains OPEN.
- The first capture recorded only six Frame/raster events in about 31 seconds;
  sparse samples cannot establish the cause of the user's reported interaction lag.
  Do not attribute it to antivirus from sparse native CPU symbol samples.
- No application source changed in this diagnostic continuation. Profile remains
  running with Guard enabled; do not force-stop it. VM service URLs/auth tokens in
  local stdout/stderr artifacts must not be published.
- Next: user explicitly focuses JA WiFi Hotspot Guard (not JA LAN Messenger), then
  collect another timeline with native foreground verification while Guard stays on.

## Latest continuation: snapshot race + hidden presentation coalescing

- AppPowerManager now assigns revisions to native visibility/focus queries and
  invalidates them on window/lifecycle changes and MainWindow disposal. Late or
  superseded snapshots cannot overwrite newer state. Tray show/hide/close requests
  use one serialized queue, with error reconciliation.
- VisibleUiListener delays only presentation callbacks while hidden, then flushes
  once using current source state. Integrated into MainWindow, MonitorTab and
  HotspotTab; all business notifications still run. Console post-frame scroll
  checks current visibility and mounted state. Lifecycle events also reconcile
  UI-only refresh timer state. Guard/OTA service logic is unchanged.
- Regression tests cover late focus, invalidated visibility, query completion
  ordering, 100 hidden source notifications with one UI flush and 100 business
  deliveries, plus the real MonitorTab showing only the newest hidden update.
- Analyzer clean, format completed, full suite 80 tests passed, Release build
  passed, diff check passed. Prior native mutex changes were preserved.

Runtime: user exited the previous instance normally. New Release PID 82028,
EXE SHA256 unchanged (native runner unchanged in this continuation):
0BF63A389E34E547C3A6FF200F1C20088940EA04E1F624E9F72A85064B553B94.
New Dart AOT data/app.so SHA256:
468679BD4A2ED267B3762C58C98518B7A0E65AB8F75B113BDA899ACFB64CEC3A.

User confirmed Guard enabled and tray-hidden. Guard log latest start at
2026-10-03 07:58:08; a powershell.exe child of PID 82028 was observed at
07:59:50 while hidden (PID 49820). This is evidence of background execution,
not proof of correct firewall enforcement or client connectivity.

Stable hidden sample window: 07:59:40–07:59:59 Asia/Bangkok, 20 valid samples,
13 PID-specific GPU engine counters per sample, max-engine mean/max 0. Native
HWND snapshots confirmed hidden and not foreground before/after. Do not extrapolate
to guaranteed zero GPU or zero frames outside the observation window.

Earlier 15-sample window mixed minimized/show/hide transitions: average max-engine
1.4776%, peak 12.1303%; do NOT label it stable hidden or a comparable focused
baseline. A separate 2-sample foreground observation measured mean 1.1263%, peak
2.0002%, too short for a savings claim. Parent CPU snapshots 2.21875 and 2.28125
total CPU seconds are snapshots, not a controlled CPU utilization benchmark.

User reported severe interaction lag before tray hide. Root cause remains OPEN:
hidden GPU readings do not prove visible UI responsiveness. Next investigation
should profile visible frame times/native calls and child-process overhead with
Guard active; avoid speculative changes to security behavior. App remains running
with Guard enabled; do not force-stop it or rebuild over locked artifacts.

## Earlier mutex verification (historical)

## Completed scope

- Windows runner now requests Administrator via embedded manifest and matching
  linker MANIFESTUAC option, before creating any Flutter window. This removes
  the transient unelevated window from the self-elevation/single-instance path.
- Mutex creation requests SYNCHRONIZE only and reports failure instead of running
  without a mutex. Preserve the existing session-local name for compatibility.
- Native test uses isolated PID-specific names: duplicate, handle lifetime,
  fresh restart and conflicting event-object failure all passed with MSVC /W4 /WX.
- Analyzer clean; format 45 files unchanged; full Flutter suite 75 tests passed;
  git diff --check passed. Release build passed. mt.exe extraction verified the
  embedded requireAdministrator level.

## Runtime evidence

Binary: build/windows/x64/runner/Release/ja_wifi_manager.exe, version 1.2.1+12.
SHA256: 0BF63A389E34E547C3A6FF200F1C20088940EA04E1F624E9F72A85064B553B94.
Started elevated PID 57024 after the user exited their earlier app. No process
was force-terminated and no build/runtime data was deleted.

GPU tool: scripts/measure_app_power.ps1, Windows GPU Engine performance counters
filtered by PID with valid status; snapshot via EnumWindows/IsWindowVisible.
Tray-hidden: 15 samples at approximately one-second intervals, 13 valid engine
counters per sample, max-engine average/max 0. All target HWNDs hidden before and
after sampling, with user confirmation of tray hide. This is scoped sampling,
not proof of zero render frames or universal zero GPU.

Earlier baseline: 12 PID-specific samples were zero too. The user confirmed the
app ran, but focus was not independently captured for those samples; do not claim
a measured GPU reduction relative to focused animation workload.

Second launch of the same Release through UAC: PID 73012 exited code 0, only
PID 57024 remained. Subsequent snapshot showed the original main window visible,
not minimized, but not foreground. Single-instance and show-from-tray succeeded;
foreground acquisition is not verified. App remains running for the user.

## Power audit / open checks

- Actual continuous animation: sidebar BlinkingDot while Guard active, covered
  by AppTickerGate in MaterialApp.builder. ThemeReveal is a finite theme animation.
- MeshOrb/WaveIndicator/GlassMarquee are still not production call sites; their
  standalone tests are not proof of coverage for the actual app.
- Explicit hide/tray paths update power state and stop UI-only refresh. Guard
  and OTA service code was not changed. Live enforcement/OTA progress was not
  exercised; timer-isolation tests alone cannot prove those service behaviors.
- Resolved in latest continuation: _syncWindowPowerState previously awaited native visibility/focus without an epoch guard;
  a delayed snapshot can apply obsolete state after a new hide/show transition.
- Resolved in latest continuation: MainWindow._onLogicChange and MonitorTab._onLogicChanged previously rebuilt on
  business notifications while hidden. TickerMode does not suppress these frames.
- CPU, Flutter raster/frame timeline, foreground active-animation workload,
  minimize, hidden startup, UAC cancellation and separate-user/session behavior
  remain open. No percentage savings claim is supported by this run.

Next: investigate the reported visible interaction lag using profile/frame timing;
verify live Guard enforcement and OTA separately from UI/GPU sampling.
