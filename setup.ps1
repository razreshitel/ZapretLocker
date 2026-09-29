# Saves config, registers tasks, starts watcher.
# .\setup.ps1 -Deadline 2026-09-30T18:00 -Keywords "YouTube,Twitch" -Browsers "chrome,msedge" -Interval 2

param(
    [Parameter(Mandatory = $true)][string]$Deadline,
    [string]$Keywords = "YouTube,Twitch",
    [string]$Browsers = "chrome,msedge,firefox,opera,browser,brave,vivaldi",
    [int]$Interval = 2
)

$ErrorActionPreference = 'Stop'

$scriptDir       = $PSScriptRoot
$configPath      = Join-Path $scriptDir "config.json"
$watcherVbs      = Join-Path $scriptDir "run-watcher.vbs"
$selfDestructVbs = Join-Path $scriptDir "run-self-destruct.vbs"

$deadlineDt = [datetime]::Parse($Deadline, [Globalization.CultureInfo]::InvariantCulture)
$now        = Get-Date

if ($now -ge $deadlineDt) { throw "Deadline already passed, not installing." }

$keywordList = @($Keywords -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$browserList = @($Browsers -split ',' | ForEach-Object { $_.Trim() -replace '\.exe$', '' } | Where-Object { $_ })
if ($keywordList.Count -eq 0) { throw "No keywords given." }
if ($browserList.Count -eq 0) { throw "No browsers given." }

$cfg = [ordered]@{
    deadline = $deadlineDt.ToString('s')
    keywords = $keywordList
    browsers = $browserList
    interval = [Math]::Max(1, $Interval)
}
ConvertTo-Json -InputObject $cfg | Set-Content -LiteralPath $configPath -Encoding UTF8

# stop running watcher
Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" |
    Where-Object { $_.CommandLine -match "watcher\.ps1" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Unregister-ScheduledTask -TaskName "ZapretLocker" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "ZapretLockerSelfDestruct" -Confirm:$false -ErrorAction SilentlyContinue

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew

$duration = New-TimeSpan -Start $now -End $deadlineDt
if ($duration.TotalMinutes -lt 2) { $duration = New-TimeSpan -Minutes 2 }   # must exceed interval
$what     = $keywordList -join ", "

$watcherAction  = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$watcherVbs`""
$watcherTrigger = New-ScheduledTaskTrigger -Once -At $now `
    -RepetitionInterval (New-TimeSpan -Minutes 1) `
    -RepetitionDuration $duration

Register-ScheduledTask -TaskName "ZapretLocker" -Action $watcherAction -Trigger $watcherTrigger `
    -Settings $settings -Description "Keeps watcher.ps1 running: auto-closes tabs ($what) until $deadlineDt" -Force | Out-Null

$selfDestructAction  = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$selfDestructVbs`""
$selfDestructTrigger = New-ScheduledTaskTrigger -Once -At $deadlineDt

Register-ScheduledTask -TaskName "ZapretLockerSelfDestruct" -Action $selfDestructAction -Trigger $selfDestructTrigger `
    -Settings $settings -Description "Removes ZapretLocker tasks and config at $deadlineDt" -Force | Out-Null

Start-Process "wscript.exe" -ArgumentList "`"$watcherVbs`""

Write-Host "Installed and started. Checks every $($cfg.interval) s until $deadlineDt, then self-destructs."
