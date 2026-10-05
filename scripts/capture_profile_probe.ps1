param(
    [Parameter(Mandatory = $true)][string]$ArtifactDirectory,
    [Parameter(Mandatory = $true)][int]$TargetProcessId,
    [int]$Samples = 30
)
$ErrorActionPreference = 'Stop'
if (-not ('JaPowerWindowProbe' -as [type])) {
    & (Join-Path $PSScriptRoot 'measure_app_power.ps1') -TargetProcessId $TargetProcessId -Samples 1 | Out-Null
}
$probeLog = (Get-Content (Join-Path $ArtifactDirectory 'stdout.log') -Raw) +
    (Get-Content (Join-Path $ArtifactDirectory 'stderr.log') -Raw)
$probeUri = [regex]::Match($probeLog, 'http://127\.0\.0\.1:\d+/[^\s]+').Value.TrimEnd('/')
if (!$probeUri) { throw 'No authenticated local VM service URL found.' }
function Invoke-ProbeRpc([string]$Method, [hashtable]$Parameters = @{}) {
    $query = ($Parameters.GetEnumerator() | ForEach-Object {
        [uri]::EscapeDataString($_.Key) + '=' + [uri]::EscapeDataString([string]$_.Value)
    }) -join '&'
    $response = Invoke-RestMethod ($probeUri + '/' + $Method + '?' + $query)
    if ($response.error) { throw ($response.error | ConvertTo-Json -Compress) }
    return $response.result
}
$isolateId = (Invoke-ProbeRpc 'getVM').isolates[0].id
$powerClass = (Invoke-ProbeRpc 'getClassList' @{isolateId=$isolateId}).classes |
    Where-Object name -eq 'AppPowerManager' | Select-Object -First 1
$powerInstance = (Invoke-ProbeRpc 'getInstances' @{isolateId=$isolateId; objectId=$powerClass.id; limit=1}).instances[0]
function Get-ProbePowerFlags {
    $powerObject = Invoke-ProbeRpc 'getObject' @{isolateId=$isolateId; objectId=$powerInstance.id}
    return @($powerObject.fields | Where-Object { $_.decl.name -match '^_isWindow|^_isUserIdle' } |
        Select-Object @{n='Field';e={$_.decl.name}},@{n='Value';e={$_.value.valueAsString}})
}
$powerBefore = Get-ProbePowerFlags
$start = (Invoke-ProbeRpc 'getVMTimelineMicros').timestamp
$cpuStart = (Get-Process -Id $TargetProcessId).TotalProcessorTime.TotalMilliseconds
$watch = [Diagnostics.Stopwatch]::StartNew()
Write-Output 'Capturing timeline and GPU; auth URL intentionally omitted.'
$windowStates = [System.Collections.Generic.List[object]]::new()
$gpu = Get-Counter '\GPU Engine(*)\Utilization Percentage' -SampleInterval 1 -MaxSamples $Samples | ForEach-Object {
    $windowStates.Add([pscustomobject]@{Time=$_.Timestamp.ToString('o'); State=[JaPowerWindowProbe]::Snapshot($TargetProcessId)})
    $_
}
$elapsed = $watch.Elapsed.TotalSeconds
$cpuEnd = (Get-Process -Id $TargetProcessId).TotalProcessorTime.TotalMilliseconds
$end = (Invoke-ProbeRpc 'getVMTimelineMicros').timestamp
$timeline = Invoke-ProbeRpc 'getVMTimeline' @{timeOriginMicros=$start; timeExtentMicros=($end-$start)}
$timeline | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $ArtifactDirectory 'timeline.json') -Encoding utf8
$cpu = Invoke-ProbeRpc 'getCpuSamples' @{isolateId=$isolateId; timeOriginMicros=$start; timeExtentMicros=($end-$start)}
$cpu | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $ArtifactDirectory 'cpu_samples.json') -Encoding utf8
$gpuRows = foreach ($sample in $gpu) {
    $engines = @($sample.CounterSamples | Where-Object {
        $_.InstanceName -match "^pid_${TargetProcessId}_" -and $_.Status -eq 0
    })
    [pscustomobject]@{Time=$sample.Timestamp.ToString('o'); Engines=$engines.Count;
        MaxEnginePercent=($engines | Measure-Object CookedValue -Maximum).Maximum}
}
$gpuRows | ConvertTo-Json | Set-Content (Join-Path $ArtifactDirectory 'gpu_samples.json') -Encoding utf8
if ($gpuRows.Count -ne $Samples) { throw 'Incomplete capture; do not use as a full measurement.' }
$windowStates | ConvertTo-Json | Set-Content (Join-Path $ArtifactDirectory 'window_states.json') -Encoding utf8
@{Before=$powerBefore; After=(Get-ProbePowerFlags)} | ConvertTo-Json -Depth 5 |
    Set-Content (Join-Path $ArtifactDirectory 'power_flags.json') -Encoding utf8
[pscustomobject]@{
    PID=$TargetProcessId; DurationSeconds=$elapsed;
    ParentCPUPercentOneCore=(($cpuEnd-$cpuStart)/($elapsed*10));
    TimelineEvents=$timeline.traceEvents.Count; CpuSamples=$cpu.samples.Count;
    GPUMax=($gpuRows | Measure-Object MaxEnginePercent -Maximum).Maximum;
    GPUAverage=($gpuRows | Measure-Object MaxEnginePercent -Average).Average;
    ValidGpuSamples=@($gpuRows | Where-Object Engines -gt 0).Count
    ForegroundSamples=@($windowStates | Where-Object State -Match 'foreground=True').Count
} | ConvertTo-Json | Tee-Object -FilePath (Join-Path $ArtifactDirectory 'summary.json')
