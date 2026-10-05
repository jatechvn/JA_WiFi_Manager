param(
    [Parameter(Mandatory = $true)][string]$Executable,
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [int]$ServicePort = 54321
)
$ErrorActionPreference = 'Stop'
# Run this helper elevated. Environment switches affect this diagnostic child only.
$env:FLUTTER_ENGINE_SWITCHES = '2'
$env:FLUTTER_ENGINE_SWITCH_1 = 'enable-dart-profiling=true'
$env:FLUTTER_ENGINE_SWITCH_2 = "vm-service-port=$ServicePort"
$probeProcess = Start-Process -FilePath $Executable -WorkingDirectory (Split-Path $Executable) `
    -RedirectStandardOutput (Join-Path $OutputDirectory 'stdout.log') `
    -RedirectStandardError (Join-Path $OutputDirectory 'stderr.log') -PassThru
$probeProcess.WaitForExit()
