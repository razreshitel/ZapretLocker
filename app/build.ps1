# Builds ..\ZapretLocker.exe; -Shortcut adds desktop link.

param([switch]$Shortcut)

$ErrorActionPreference = 'Stop'

$appDir  = $PSScriptRoot
$rootDir = Split-Path $appDir -Parent
$ico     = Join-Path $appDir "ZapretLocker.ico"
$exe     = Join-Path $rootDir "ZapretLocker.exe"

& (Join-Path $appDir "make-icon.ps1") -Out $ico

$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
& $csc /nologo /target:winexe /optimize+ /codepage:65001 "/win32icon:$ico" "/out:$exe" `
    /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Core.dll /r:System.Web.Extensions.dll `
    (Join-Path $appDir "ZapretLocker.cs")
if ($LASTEXITCODE -ne 0) { throw "csc failed" }
Write-Host "Built $exe"

if ($Shortcut) {
    # hashed name dodges icon cache
    $hash    = (Get-FileHash $ico -Algorithm MD5).Hash.Substring(0, 8).ToLower()
    $lnkIcon = Join-Path $appDir "ZapretLocker-$hash.ico"
    Get-ChildItem $appDir -Filter "ZapretLocker-*.ico" | Where-Object { $_.FullName -ne $lnkIcon } | Remove-Item
    Copy-Item $ico $lnkIcon -Force

    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) "ZapretLocker.lnk"
    $sh  = New-Object -ComObject WScript.Shell
    $s   = $sh.CreateShortcut($lnk)
    $s.TargetPath       = $exe
    $s.WorkingDirectory = $rootDir
    $s.IconLocation     = "$lnkIcon,0"
    $s.Description      = "ZapretLocker"
    $s.Save()
    Write-Host "Shortcut $lnk"
}
