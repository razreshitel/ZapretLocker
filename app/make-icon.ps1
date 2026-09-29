# Draws ZapretLocker.ico: lock over YouTube-style button.

param(
    [Parameter(Mandatory = $true)][string]$Out,
    [string]$PreviewDir,
    [string]$Variant = "blue-solid",
    [string]$Layout = "center"
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-Color([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }

$red   = New-Color "#E52D27"
$white = New-Color "#FFFFFF"
$main  = New-Color "#1E3A5F"
$halo  = $white
if ($Variant -eq "blue-solid") { $inner = $main;  $tick = $white }
else                           { $inner = $white; $tick = $main }

function New-RoundRect([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 2 * $r
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function New-Pen($color, [single]$width) {
    $pen = New-Object System.Drawing.Pen $color, $width
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    return $pen
}

# One frame, drawn on 256 grid
function New-Frame([int]$s) {
    $bmp = New-Object System.Drawing.Bitmap $s, $s, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode   = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.ScaleTransform($s / 256.0, $s / 256.0)
    $small = $s -le 24

    # red button
    $btn = New-RoundRect 6 40 244 176 52
    $g.FillPath((New-Object System.Drawing.SolidBrush $red), $btn)

    # play triangle
    if ($Layout -eq "offset") { $tx = 62.0; $tw = 100.0 } else { $tx = 76.0; $tw = 116.0 }
    $tri = [System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF $tx, 72),
        (New-Object System.Drawing.PointF $tx, 184),
        (New-Object System.Drawing.PointF ($tx + $tw), 128)
    )
    $g.FillPolygon((New-Object System.Drawing.SolidBrush $white), $tri)

    # lock geometry
    if ($Layout -eq "offset") { $cx = 166.0; $cy = 152.0; $k = 0.86 } else { $cx = 128.0; $cy = 152.0; $k = 0.78 }
    if ($small) { $k = $k * 1.12 }
    $R    = 44.0 * $k
    $ring = $(if ($small) { 16.0 } else { 12.0 }) * $k
    $o    = $(if ($small) { 6.0 } else { 5.0 }) * $k
    $sw   = $(if ($small) { 18.0 } else { 14.0 }) * $k
    $half = 23.0 * $k
    $top  = $cy - 90.0 * $k

    # shackle: outline then fill
    $sh = New-Object System.Drawing.Drawing2D.GraphicsPath
    $sh.AddLine([single]($cx - $half), [single]$cy, [single]($cx - $half), [single]($top + $half))
    $sh.AddArc([single]($cx - $half), [single]$top, [single](2 * $half), [single](2 * $half), 180, 180)
    $sh.AddLine([single]($cx + $half), [single]($top + $half), [single]($cx + $half), [single]$cy)
    $g.DrawPath((New-Pen $halo ($sw + 2 * $o)), $sh)
    $g.DrawPath((New-Pen $main $sw), $sh)

    # body: outline, ring, face
    $g.FillEllipse((New-Object System.Drawing.SolidBrush $halo), [single]($cx - $R - $o), [single]($cy - $R - $o), [single](2 * ($R + $o)), [single](2 * ($R + $o)))
    $g.FillEllipse((New-Object System.Drawing.SolidBrush $main), [single]($cx - $R), [single]($cy - $R), [single](2 * $R), [single](2 * $R))
    $ri = $R - $ring
    $g.FillEllipse((New-Object System.Drawing.SolidBrush $inner), [single]($cx - $ri), [single]($cy - $ri), [single](2 * $ri), [single](2 * $ri))

    # dial ticks
    if (-not $small) {
        $tp = New-Pen $tick (7 * $k)
        for ($i = 0; $i -lt 8; $i++) {
            $a = $i * [Math]::PI / 4
            $r1 = $ri * 0.42; $r2 = $ri * 0.74
            $g.DrawLine($tp, [single]($cx + $r1 * [Math]::Cos($a)), [single]($cy + $r1 * [Math]::Sin($a)),
                             [single]($cx + $r2 * [Math]::Cos($a)), [single]($cy + $r2 * [Math]::Sin($a)))
        }
    }

    $g.Dispose()
    return $bmp
}

$sizes = 16, 24, 32, 48, 64, 256
$pngs  = @()
foreach ($s in $sizes) {
    $bmp = New-Frame $s
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    if ($PreviewDir) { $bmp.Save((Join-Path $PreviewDir "icon-$Variant-$s.png")) }
    $bmp.Dispose()
    $pngs += ,$ms.ToArray()
}

$ms = New-Object System.IO.MemoryStream
$w  = New-Object System.IO.BinaryWriter $ms
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
    $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([uint16]1); $w.Write([uint16]32)
    $w.Write([uint32]$pngs[$i].Length); $w.Write([uint32]$offset)
    $offset += $pngs[$i].Length
}
foreach ($p in $pngs) { $w.Write([byte[]]$p) }
$w.Flush()
[System.IO.File]::WriteAllBytes($Out, $ms.ToArray())
