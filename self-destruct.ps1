# Removes both tasks and config.json.

$configPath = Join-Path $PSScriptRoot "config.json"

try {
    $cfg      = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $deadline = [datetime]::ParseExact($cfg.deadline, 's', [Globalization.CultureInfo]::InvariantCulture)
    if ($deadline -gt (Get-Date).AddSeconds(30)) { exit }   # deadline was extended
} catch { }

Start-Sleep -Seconds 2
Unregister-ScheduledTask -TaskName "ZapretLocker" -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName "ZapretLockerSelfDestruct" -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $configPath -Force -ErrorAction SilentlyContinue
