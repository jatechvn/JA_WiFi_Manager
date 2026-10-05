param(
    [Parameter(Mandatory = $true)][int]$TargetProcessId,
    [int]$Samples = 15
)
$ErrorActionPreference = 'Stop'
if (-not ('JaPowerWindowProbe' -as [type])) {
    Add-Type @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class JaPowerWindowProbe {
  public delegate bool EnumProc(IntPtr hwnd, IntPtr param);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc callback, IntPtr param);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr hwnd);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  public static string Snapshot(uint target) {
    var windows = new List<string>();
    EnumWindows((hwnd, param) => {
      uint pid; GetWindowThreadProcessId(hwnd, out pid);
      if (pid == target) windows.Add(String.Format("hwnd={0} visible={1} minimized={2} foreground={3}",
        hwnd, IsWindowVisible(hwnd), IsIconic(hwnd), hwnd == GetForegroundWindow()));
      return true;
    }, IntPtr.Zero);
    return String.Join("; ", windows);
  }
}
'@
}
$process = Get-Process -Id $TargetProcessId
Write-Output "PID=$TargetProcessId Started=$($process.StartTime)"
Write-Output ([JaPowerWindowProbe]::Snapshot($TargetProcessId))
$measurements = Get-Counter '\GPU Engine(*)\Utilization Percentage' -SampleInterval 1 -MaxSamples $Samples
$rows = foreach ($measurement in $measurements) {
    $engines = @($measurement.CounterSamples | Where-Object {
        $_.InstanceName -match "^pid_${TargetProcessId}_" -and $_.Status -eq 0
    })
    [pscustomobject]@{
        Time = $measurement.Timestamp.ToString('HH:mm:ss')
        Engines = $engines.Count
        MaxEnginePercent = ($engines | Measure-Object CookedValue -Maximum).Maximum
        SumEnginePercent = ($engines | Measure-Object CookedValue -Sum).Sum
    }
}
$rows | Format-Table -AutoSize
$rows | Measure-Object MaxEnginePercent -Average -Maximum
Write-Output ([JaPowerWindowProbe]::Snapshot($TargetProcessId))
Write-Output 'SumEnginePercent is an aggregate of engine counters, not overall GPU utilization.'
if (@($rows | Where-Object Engines -gt 0).Count -ne $Samples) {
    throw 'Missing PID-specific GPU counters; do not interpret missing counters as zero GPU.'
}
