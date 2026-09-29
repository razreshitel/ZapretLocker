# Loops until the deadline, then self-destructs.

$scriptDir  = $PSScriptRoot
$configPath = Join-Path $scriptDir "config.json"

try {
    $cfg      = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $deadline = [datetime]::ParseExact($cfg.deadline, 's', [Globalization.CultureInfo]::InvariantCulture)
} catch { exit }

$keywords = @($cfg.keywords)
$browsers = @($cfg.browsers)
$interval = [Math]::Max(1, [int]$cfg.interval)

if ((Get-Date) -ge $deadline) {
    Start-Process "wscript.exe" -ArgumentList "`"$(Join-Path $scriptDir 'run-self-destruct.vbs')`""
    exit
}

# single instance
$mutex = New-Object System.Threading.Mutex($false, "Local\ZapretLocker.Watcher")
try { if (-not $mutex.WaitOne(0)) { exit } } catch [System.Threading.AbandonedMutexException] { }

. (Join-Path $scriptDir "close-tabs.ps1")   # defines Close-BlockedTabs

while ((Get-Date) -lt $deadline) {
    try { Close-BlockedTabs $keywords $browsers } catch { }
    Start-Sleep -Seconds $interval
}

Start-Process "wscript.exe" -ArgumentList "`"$(Join-Path $scriptDir 'run-self-destruct.vbs')`""
