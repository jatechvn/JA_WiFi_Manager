---
name: gpt-flutter-power-optimizer
description: >-
  Diagnose and reduce Flutter Desktop UI rendering and CPU/GPU load when hidden,
  minimized, unfocused, or idle. Audit actual animation consumers and tray lifecycle,
  preserve background business tasks, and verify changes with regression tests and
  native measurements. Use for power optimizer, giảm GPU khi inactive, or idle sleep.
---

# Codex execution notes

Use current Codex tools and session approvals. Antigravity hooks/tool names do not
apply to Codex. This adapter follows the canonical skills/flutter-power-optimizer
runbook below. Preserve scope, unrelated changes and user data; do not save memory
unless explicitly requested.

# Flutter Desktop Power Optimizer

Reduce unnecessary UI work in the existing application, not a demonstration widget
library. Follow project instructions, preserve dirty changes and runtime data. This
skill does not authorize packaging, publishing, process termination, deletion, or
disabling security/network/update tasks. Do not redesign the UI for this task.

## Audit before patching

1. Identify the executable the user tested, its build mode and whether it includes
   current source changes. A stale Release binary cannot validate a source patch.
2. Trace every route: close-to-tray, tray toggle/menu, explicit hide/show, minimize,
   restore, start-minimized, focus/blur and Flutter lifecycle. Read actual callers.
3. Search the mounted UI and direct dependencies for AnimationController, repeat,
   Ticker, animated/implicit widgets, progress indicators, marquee/scroll animations,
   Timer.periodic, async rescheduling, setState and notifyListeners. Include old
   widgets such as blinking dots, not just MeshOrb/WaveIndicator examples.
4. Record each source of recurring UI work, its real call site, current pause policy
   and verification. New helper widgets with no production call sites do not count
   as integration. RepaintBoundary isolates repaint scope; it does not stop work.

## Implement the smallest integrated fix

Reuse the application's coordinator/state management; introduce one shared power
coordinator only if missing. Focus, visibility and idle have distinct meanings:

| State | UI ticker policy | Background business tasks |
| --- | --- | --- |
| Visible, focused, interacting | Normal | Unchanged |
| Visible, focused, idle | Pause heavy decoration; keep necessary indicators | Unchanged |
| Unfocused | Mute continuous UI animation under the chosen app policy | Unchanged |
| Hidden/minimized | Mute UI animation; stop UI-only polling | Unchanged |

Idle timeout is configurable using existing settings; 12 seconds is a default,
not a requirement to introduce a new settings screen or config file.

### Global ticker coverage

Place a reactive TickerMode gate above the actual Navigator/routes/overlays (e.g.
MaterialApp.builder child). Derive enabled from focused AND visible. Exercise an
ordinary existing ticker that does not know the coordinator. Check nested gates
and additional windows/root trees rather than assuming one gate covers everything.

TickerMode mutes compliant tickers; it does not cancel timers, Futures, business
notifications or all native rendering. Muted controllers can advance their elapsed
time when unmuted. Where phase/offset continuity matters, explicitly stop/resume
the existing controller and test both forward and reverse legs. Do not claim
TickerMode alone preserves exact phase. Check the project's actual Flutter SDK
behavior before making blanket claims about repeat(reverse: true).

### Native visibility and tray transitions

- Explicit hide must update coordinator visibility and stop UI-only polling without
  waiting for blur/lifecycle delivery. If native hide fails, reconcile actual native
  visibility/focus so a visible window is not left permanently muted.
- Show/restore establishes visibility, not focus. Resume only after verified focus
  or a trusted focus event. Centralize tray/close paths; do not duplicate policies.
- Start-minimized must start muted. Initial synchronization checks visibility AND
  focus, not focus alone. Protect async snapshots from dispose and stale ordering
  (e.g. an old focus query completing after hide). Serialize conflicting transitions
  or invalidate stale completions as appropriate.
- Reconcile window-manager and Flutter lifecycle events through the coordinator.
  Handle failure paths without unhandled async errors. Only change Win32 focus code
  when evidence shows that native handler is wrong; it is not a mandatory template.

### Non-ticker work and background isolation

Cancel UI-only timers and invalidate stale marquee callbacks on pause/dispose.
Session epochs must guard every completion capable of rescheduling. Freeze offset
and resume in the intended direction. Audit repeated UI rebuilds from business
notifications: if significant, defer/coalesce presentation updates while hidden,
then refresh from current state on return without discarding business events.

Keep Guard/firewall enforcement, OTA, queues, network connections and other
required background tasks independent of the UI gate. Never silence business
notifications globally or pause all timers just to reduce GPU usage. Reuse the
existing persistence/localization and settings Save/Cancel semantics.

## Regression verification

Follow the project's formatter/analyzer/test sequence. Tests must exercise the
integrated gate and real application consumers, not only fresh sample widgets:

- Ordinary repeating ticker stops after hide/blur/minimize, stays muted after show
  without focus, and resumes after focus; also cover initially hidden mounting.
- Mock native tray/close/start-minimized paths including hide failure, show without
  focus, repeated transitions and delayed/stale focus results where applicable.
- Marquee callbacks cannot restart after pause/dispose. Phase-sensitive animations
  preserve direction/offset under repeated transitions; test only those in use.
- A background timer continues under the gate. This proves timer isolation only;
  use service-specific fake tests for Guard/OTA progress if making those claims.
- Tests clean up their own timers/controllers before framework invariant checks;
  do not delete user runtime data or disable assertions to obtain a pass.

## Native acceptance and reporting

Use the intended rebuilt Release/profile executable for native checks when
authorized. Compare focused, blurred, taskbar-minimized, tray-hidden, restored
without focus and refocused states. Include hidden startup. Keep the same workload
and observe each state long enough for idle/transitions to settle.

Record executable path/build identity, measurement tool, observation duration,
process-specific GPU engine/CPU and available Flutter frame/timeline evidence.
Task Manager totals or DWM activity alone do not identify app rendering. Verify
background business progress independently. If native instrumentation or launch is
unavailable, mark runtime/GPU verification OPEN; tests/builds cannot close it.

Completion report separates source integration, automated regression results,
native tray/UI validation and measured GPU/CPU results. Never promise 0% GPU,
100% savings or zero draw calls without scoped measured evidence. Native composition,
new data and resizing may produce frames even after continuous tickers stop.
If the user still sees load, revisit uncovered consumers, rebuild churn, native
effects, plugins and binary identity instead of adding another unused helper.

Packaging/checksums apply only to a requested release workflow: preserve runtime
data and update only the intended artifact entries using that project's scripts.
