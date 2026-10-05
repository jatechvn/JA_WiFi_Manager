# Handoff — 2026-10-03

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
