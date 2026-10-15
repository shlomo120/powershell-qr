<#
.SYNOPSIS
  QR Code generator in pure PowerShell. No modules, no Add-Type, no System.Drawing, no admin.
  Long text is split automatically into several QR codes, each prefixed with [i/N].

.EXAMPLE
  .\qr.ps1 -Text "שלום עולם" -Open
.EXAMPLE
  .\qr.ps1 -Path .\long.txt -ErrorCorrection L -MaxVersion 20 -Open
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\qr.ps1 -Path .\notes.txt
#>
[CmdletBinding(DefaultParameterSetName = 'Text')]
param(
    [Parameter(ParameterSetName = 'Text', Mandatory = $true, Position = 0)][string]$Text,
    [Parameter(ParameterSetName = 'File', Mandatory = $true)][string]$Path,
    [ValidateSet('L', 'M', 'Q', 'H')][string]$ErrorCorrection = 'M',
    [ValidateRange(1, 40)][int]$MaxVersion = 25,      # max QR size per code (25 = 117x117 modules)
    [string]$OutDir = (Join-Path (Get-Location) 'QR_Output'),
    [ValidateRange(1, 40)][int]$ModulePx = 6,         # pixel size per module in the SVG
    [ValidateRange(-1, 7)][int]$Mask = -1,            # -1 = auto (best penalty); 0-7 = fixed (faster)
    [switch]$NoHeader,                                # don't add [i/N] prefix when splitting
    [switch]$Eci,                                     # add ECI 26 (UTF-8) header - for old scanners
    [switch]$Open                                     # open the HTML when done
)

$ErrorActionPreference = 'Stop'

# ---------------- Tables (index: [ECC L,M,Q,H][version 0..40]) ----------------
$EccPerBlock = @(
    @(-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30),
    @(-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28),
    @(-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30),
    @(-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30)
)
$NumBlocks = @(
    @(-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25),
    @(-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49),
    @(-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68),
    @(-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81)
)

# ---------------- GF(256) for Reed-Solomon (poly 0x11D) ----------------
$GfExp = New-Object int[] 512
$GfLog = New-Object int[] 256
$t = 1
for ($i = 0; $i -lt 255; $i++) {
    $GfExp[$i] = $t; $GfLog[$t] = $i
    $t = $t -shl 1
    if ($t -ge 256) { $t = $t -bxor 0x11D }
}
for ($i = 255; $i -lt 512; $i++) { $GfExp[$i] = $GfExp[$i - 255] }

function GfMul([int]$a, [int]$b) {
    if ($a -eq 0 -or $b -eq 0) { return 0 }
    return $GfExp[$GfLog[$a] + $GfLog[$b]]
}

function Get-RsDivisor([int]$degree) {
    $r = New-Object int[] $degree
    $r[$degree - 1] = 1
    $root = 1
    for ($i = 0; $i -lt $degree; $i++) {
        for ($j = 0; $j -lt $degree; $j++) {
            $r[$j] = GfMul $r[$j] $root
            if ($j + 1 -lt $degree) { $r[$j] = $r[$j] -bxor $r[$j + 1] }
        }
        $root = GfMul $root 2
    }
    return , $r
}

function Get-RsRemainder($data, $div) {
    $n = $div.Length
    $r = New-Object int[] $n
    foreach ($b in $data) {
        $f = $b -bxor $r[0]
        for ($i = 0; $i -lt $n - 1; $i++) { $r[$i] = $r[$i + 1] }
        $r[$n - 1] = 0
        if ($f -ne 0) {
            $lf = $GfLog[$f]
            for ($i = 0; $i -lt $n; $i++) {
                if ($div[$i] -ne 0) { $r[$i] = $r[$i] -bxor $GfExp[$GfLog[$div[$i]] + $lf] }
            }
        }
    }
    return , $r
}

# ---------------- Capacity helpers ----------------
function Get-RawModules([int]$v) {
    $r = (16 * $v + 128) * $v + 64
    if ($v -ge 2) {
        $na = [int][Math]::Floor($v / 7) + 2
        $r -= (25 * $na - 10) * $na - 55
        if ($v -ge 7) { $r -= 36 }
    }
    return [int]$r
}
function Get-NumDataCw([int]$v, [int]$e) {
    return [int][Math]::Floor((Get-RawModules $v) / 8) - $EccPerBlock[$e][$v] * $NumBlocks[$e][$v]
}
function Get-ByteCapacity([int]$v, [int]$e) {
    $bits = (Get-NumDataCw $v $e) * 8 - 4 - $(if ($v -lt 10) { 8 } else { 16 }) - $(if ($Eci) { 12 } else { 0 })
    return [int][Math]::Floor($bits / 8)
}

# ---------------- Data encoding (byte mode, UTF-8) ----------------
function Add-Bits($list, [int]$val, [int]$len) {
    for ($i = $len - 1; $i -ge 0; $i--) { $list.Add(($val -shr $i) -band 1) }
}

function ConvertTo-DataCodewords([byte[]]$bytes, [int]$v, [int]$e) {
    $cap = (Get-NumDataCw $v $e) * 8
    $bl = New-Object System.Collections.Generic.List[int]
    if ($Eci) { Add-Bits $bl 7 4; Add-Bits $bl 26 8 }          # ECI designator 26 = UTF-8
    Add-Bits $bl 4 4                                          # byte mode
    Add-Bits $bl $bytes.Length $(if ($v -lt 10) { 8 } else { 16 })
    foreach ($b in $bytes) { Add-Bits $bl $b 8 }
    Add-Bits $bl 0 ([Math]::Min(4, $cap - $bl.Count))         # terminator
    Add-Bits $bl 0 ((8 - ($bl.Count % 8)) % 8)                # byte align
    $pad = 0xEC
    while ($bl.Count -lt $cap) { Add-Bits $bl $pad 8; $pad = $pad -bxor 0xEC -bxor 0x11 }
    $cw = New-Object int[] ($cap / 8)
    for ($i = 0; $i -lt $bl.Count; $i++) {
        if ($bl[$i]) { $cw[$i -shr 3] = $cw[$i -shr 3] -bor (1 -shl (7 - ($i -band 7))) }
    }
    return , $cw
}

function Add-EccInterleave($data, [int]$v, [int]$e) {
    $nb = $NumBlocks[$e][$v]; $el = $EccPerBlock[$e][$v]
    $raw = [int][Math]::Floor((Get-RawModules $v) / 8)
    $nShort = $nb - ($raw % $nb)
    $shortLen = [int][Math]::Floor($raw / $nb)
    $div = Get-RsDivisor $el
    $blocks = @(); $k = 0
    for ($i = 0; $i -lt $nb; $i++) {
        $len = $shortLen - $el + $(if ($i -lt $nShort) { 0 } else { 1 })
        $dat = @($data[$k..($k + $len - 1)])
        $k += $len
        $ecc = Get-RsRemainder $dat $div
        if ($i -lt $nShort) { $dat += 0 }
        $blocks += , (@($dat) + @($ecc))
    }
    $res = New-Object System.Collections.Generic.List[int]
    $blen = $blocks[0].Count
    for ($i = 0; $i -lt $blen; $i++) {
        for ($j = 0; $j -lt $nb; $j++) {
            if ($i -ne ($shortLen - $el) -or $j -ge $nShort) { $res.Add($blocks[$j][$i]) }
        }
    }
    return , $res.ToArray()
}

# ---------------- Matrix drawing ----------------
function Get-Bit([int]$val, [int]$i) { return ((($val -shr $i) -band 1) -ne 0) }

function Set-Fn($Q, [int]$x, [int]$y, [bool]$dark) {
    $idx = $y * $Q.Size + $x
    $Q.Mods[$idx] = [int]$dark
    $Q.Fnc[$idx] = 1
}

function Add-Finder($Q, [int]$cx, [int]$cy) {
    for ($dy = -4; $dy -le 4; $dy++) {
        for ($dx = -4; $dx -le 4; $dx++) {
            $d = [Math]::Max([Math]::Abs($dx), [Math]::Abs($dy))
            $xx = $cx + $dx; $yy = $cy + $dy
            if ($xx -ge 0 -and $xx -lt $Q.Size -and $yy -ge 0 -and $yy -lt $Q.Size) {
                Set-Fn $Q $xx $yy ($d -ne 2 -and $d -ne 4)
            }
        }
    }
}

function Get-AlignPos([int]$v) {
    if ($v -eq 1) { return , @() }
    $na = [int][Math]::Floor($v / 7) + 2
    $step = [int][Math]::Floor(($v * 8 + $na * 3 + 5) / ($na * 4 - 4)) * 2
    $r = New-Object int[] $na
    $r[0] = 6
    $pos = $v * 4 + 17 - 7
    for ($i = $na - 1; $i -ge 1; $i--) { $r[$i] = $pos; $pos -= $step }
    return , $r
}

function Set-FormatBits($Q, [int]$eclBits, [int]$maskId) {
    $data = ($eclBits -shl 3) -bor $maskId
    $rem = $data
    for ($i = 0; $i -lt 10; $i++) { $rem = ($rem -shl 1) -bxor (($rem -shr 9) * 0x537) }
    $bits = (($data -shl 10) -bor $rem) -bxor 0x5412
    $s = $Q.Size
    for ($i = 0; $i -le 5; $i++) { Set-Fn $Q 8 $i (Get-Bit $bits $i) }
    Set-Fn $Q 8 7 (Get-Bit $bits 6)
    Set-Fn $Q 8 8 (Get-Bit $bits 7)
    Set-Fn $Q 7 8 (Get-Bit $bits 8)
    for ($i = 9; $i -lt 15; $i++) { Set-Fn $Q (14 - $i) 8 (Get-Bit $bits $i) }
    for ($i = 0; $i -lt 8; $i++) { Set-Fn $Q ($s - 1 - $i) 8 (Get-Bit $bits $i) }
    for ($i = 8; $i -lt 15; $i++) { Set-Fn $Q 8 ($s - 15 + $i) (Get-Bit $bits $i) }
    Set-Fn $Q 8 ($s - 8) $true    # dark module
}

function Set-VersionInfo($Q, [int]$v) {
    if ($v -lt 7) { return }
    $rem = $v
    for ($i = 0; $i -lt 12; $i++) { $rem = ($rem -shl 1) -bxor (($rem -shr 11) * 0x1F25) }
    $bits = ($v -shl 12) -bor $rem
    for ($i = 0; $i -lt 18; $i++) {
        $bit = Get-Bit $bits $i
        $a = $Q.Size - 11 + ($i % 3)
        $b = [int][Math]::Floor($i / 3)
        Set-Fn $Q $a $b $bit
        Set-Fn $Q $b $a $bit
    }
}

function Set-Codewords($Q, $data) {
    $s = $Q.Size; $mods = $Q.Mods; $fnc = $Q.Fnc
    $i = 0; $total = $data.Length * 8
    for ($right = $s - 1; $right -ge 1; $right -= 2) {
        if ($right -eq 6) { $right = 5 }
        for ($vert = 0; $vert -lt $s; $vert++) {
            for ($j = 0; $j -lt 2; $j++) {
                $x = $right - $j
                $up = (($right + 1) -band 2) -eq 0
                $y = if ($up) { $s - 1 - $vert } else { $vert }
                $idx = $y * $s + $x
                if (-not $fnc[$idx] -and $i -lt $total) {
                    $mods[$idx] = ($data[$i -shr 3] -shr (7 - ($i -band 7))) -band 1
                    $i++
                }
            }
        }
    }
}

function Invoke-Mask($Q, [int]$maskId) {
    $s = $Q.Size; $mods = $Q.Mods; $fnc = $Q.Fnc
    for ($y = 0; $y -lt $s; $y++) {
        for ($x = 0; $x -lt $s; $x++) {
            $idx = $y * $s + $x
            if ($fnc[$idx]) { continue }
            $inv = switch ($maskId) {
                0 { (($x + $y) % 2) -eq 0 }
                1 { ($y % 2) -eq 0 }
                2 { ($x % 3) -eq 0 }
                3 { (($x + $y) % 3) -eq 0 }
                4 { (([Math]::Floor($x / 3) + [Math]::Floor($y / 2)) % 2) -eq 0 }
                5 { ((($x * $y) % 2) + (($x * $y) % 3)) -eq 0 }
                6 { (((($x * $y) % 2) + (($x * $y) % 3)) % 2) -eq 0 }
                7 { (((($x + $y) % 2) + (($x * $y) % 3)) % 2) -eq 0 }
            }
            if ($inv) { $mods[$idx] = 1 - $mods[$idx] }
        }
    }
}

function Get-Penalty($Q) {
    $s = $Q.Size; $mods = $Q.Mods; $p = 0
    for ($pass = 0; $pass -lt 2; $pass++) {
        for ($a = 0; $a -lt $s; $a++) {
            $line = New-Object int[] $s
            $run = 0; $prev = -1
            for ($b = 0; $b -lt $s; $b++) {
                $val = if ($pass -eq 0) { $mods[$a * $s + $b] } else { $mods[$b * $s + $a] }
                $line[$b] = $val
                if ($val -eq $prev) { $run++ } else { if ($run -ge 5) { $p += $run - 2 }; $run = 1; $prev = $val }
            }
            if ($run -ge 5) { $p += $run - 2 }
            for ($b = 0; $b -le $s - 7; $b++) {
                if ($line[$b] -eq 1 -and $line[$b + 1] -eq 0 -and $line[$b + 2] -eq 1 -and $line[$b + 3] -eq 1 -and
                    $line[$b + 4] -eq 1 -and $line[$b + 5] -eq 0 -and $line[$b + 6] -eq 1) {
                    $before = $true; for ($k = $b - 4; $k -lt $b; $k++) { if ($k -ge 0 -and $line[$k] -eq 1) { $before = $false } }
                    $after = $true; for ($k = $b + 7; $k -lt $b + 11; $k++) { if ($k -lt $s -and $line[$k] -eq 1) { $after = $false } }
                    if ($before -or $after) { $p += 40 }
                }
            }
        }
    }
    for ($y = 0; $y -lt $s - 1; $y++) {
        for ($x = 0; $x -lt $s - 1; $x++) {
            $c = $mods[$y * $s + $x]
            if ($c -eq $mods[$y * $s + $x + 1] -and $c -eq $mods[($y + 1) * $s + $x] -and $c -eq $mods[($y + 1) * $s + $x + 1]) { $p += 3 }
        }
    }
    $dark = 0; foreach ($val in $mods) { $dark += $val }
    $total = $s * $s
    $p += 10 * [Math]::Floor([Math]::Abs($dark * 20 - $total * 10) / $total)
    return $p
}

function New-QrMatrix([byte[]]$bytes, [int]$e, [int]$eclBits) {
    $v = 0
    for ($tv = 1; $tv -le $MaxVersion; $tv++) {
        if ((Get-ByteCapacity $tv $e) -ge $bytes.Length) { $v = $tv; break }
    }
    if ($v -eq 0) { throw "Chunk of $($bytes.Length) bytes does not fit in version $MaxVersion / ECC $ErrorCorrection" }

    $dataCw = ConvertTo-DataCodewords $bytes $v $e
    $all = Add-EccInterleave $dataCw $v $e

    $s = $v * 4 + 17
    $Q = @{ Size = $s; Version = $v; Mods = (New-Object int[] ($s * $s)); Fnc = (New-Object int[] ($s * $s)) }

    for ($i = 0; $i -lt $s; $i++) { Set-Fn $Q 6 $i ($i % 2 -eq 0); Set-Fn $Q $i 6 ($i % 2 -eq 0) }
    Add-Finder $Q 3 3; Add-Finder $Q ($s - 4) 3; Add-Finder $Q 3 ($s - 4)
    $ap = Get-AlignPos $v; $n = $ap.Length
    for ($i = 0; $i -lt $n; $i++) {
        for ($j = 0; $j -lt $n; $j++) {
            if (($i -eq 0 -and $j -eq 0) -or ($i -eq 0 -and $j -eq $n - 1) -or ($i -eq $n - 1 -and $j -eq 0)) { continue }
            for ($dy = -2; $dy -le 2; $dy++) {
                for ($dx = -2; $dx -le 2; $dx++) {
                    Set-Fn $Q ($ap[$i] + $dx) ($ap[$j] + $dy) ([Math]::Max([Math]::Abs($dx), [Math]::Abs($dy)) -ne 1)
                }
            }
        }
    }
    Set-FormatBits $Q $eclBits 0
    Set-VersionInfo $Q $v

    Set-Codewords $Q $all

    $chosen = $Mask
    if ($chosen -lt 0) {
        $bestP = [int]::MaxValue
        for ($k = 0; $k -lt 8; $k++) {
            Invoke-Mask $Q $k
            Set-FormatBits $Q $eclBits $k
            $pen = Get-Penalty $Q
            if ($pen -lt $bestP) { $bestP = $pen; $chosen = $k }
            Invoke-Mask $Q $k   # undo
        }
    }
    Invoke-Mask $Q $chosen
    Set-FormatBits $Q $eclBits $chosen
    return $Q
}

function ConvertTo-Svg($Q, [int]$px) {
    $border = 4
    $s = $Q.Size; $dim = $s + 2 * $border; $w = $dim * $px
    $sb = New-Object System.Text.StringBuilder
    for ($y = 0; $y -lt $s; $y++) {
        for ($x = 0; $x -lt $s; $x++) {
            if ($Q.Mods[$y * $s + $x]) { [void]$sb.Append("M$($x + $border),$($y + $border)h1v1h-1z") }
        }
    }
    return "<svg xmlns=`"http://www.w3.org/2000/svg`" viewBox=`"0 0 $dim $dim`" width=`"$w`" height=`"$w`" shape-rendering=`"crispEdges`"><rect width=`"100%`" height=`"100%`" fill=`"#fff`"/><path d=`"$($sb.ToString())`" fill=`"#000`"/></svg>"
}

# ---------------- Splitting (never breaks a UTF-8 character) ----------------
function Split-Utf8([string]$str, [int]$budget) {
    $utf8 = [System.Text.Encoding]::UTF8
    $chunks = New-Object System.Collections.Generic.List[string]
    $sb = New-Object System.Text.StringBuilder
    $cur = 0; $i = 0
    while ($i -lt $str.Length) {
        $len = if ([char]::IsHighSurrogate($str[$i]) -and $i + 1 -lt $str.Length) { 2 } else { 1 }
        $piece = $str.Substring($i, $len)
        $b = $utf8.GetByteCount($piece)
        if ($cur + $b -gt $budget -and $cur -gt 0) { $chunks.Add($sb.ToString()); [void]$sb.Clear(); $cur = 0 }
        [void]$sb.Append($piece); $cur += $b; $i += $len
    }
    if ($sb.Length -gt 0) { $chunks.Add($sb.ToString()) }
    return , $chunks
}

# ================= Main =================
if ($PSCmdlet.ParameterSetName -eq 'File') { $Text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 }
if ([string]::IsNullOrEmpty($Text)) { throw 'Empty input.' }

$eIdx = @{ L = 0; M = 1; Q = 2; H = 3 }[$ErrorCorrection]
$eclBits = @{ L = 1; M = 0; Q = 3; H = 2 }[$ErrorCorrection]
$utf8 = [System.Text.Encoding]::UTF8
$maxCap = Get-ByteCapacity $MaxVersion $eIdx
$totalBytes = $utf8.GetByteCount($Text)

if ($totalBytes -le $maxCap) {
    $payloads = @($Text)
} else {
    $digits = 1
    do {
        $budget = $maxCap - $(if ($NoHeader) { 0 } else { 2 * $digits + 3 })   # "[i/N]"
        $chunks = Split-Utf8 $Text $budget
        $retry = (-not $NoHeader) -and ($chunks.Count -ge [Math]::Pow(10, $digits))
        if ($retry) { $digits++ }
    } while ($retry)
    $n = $chunks.Count
    $payloads = for ($i = 0; $i -lt $n; $i++) {
        if ($NoHeader) { $chunks[$i] } else { "[$($i + 1)/$n]" + $chunks[$i] }
    }
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$n = @($payloads).Count
Write-Host "Input: $totalBytes bytes (UTF-8) -> $n QR code(s), ECC $ErrorCorrection, max version $MaxVersion"

$parts = New-Object System.Text.StringBuilder
$idx = 0
foreach ($pl in $payloads) {
    $idx++
    $bytes = $utf8.GetBytes($pl)
    $Q = New-QrMatrix $bytes $eIdx $eclBits
    $svg = ConvertTo-Svg $Q $ModulePx
    $svgFile = Join-Path $OutDir ('QR_{0:D3}.svg' -f $idx)
    Set-Content -LiteralPath $svgFile -Value $svg -Encoding UTF8
    [void]$parts.Append("<div class='q'><h3>QR $idx / $n</h3>$svg<p>Version $($Q.Version) | ECC $ErrorCorrection | $($bytes.Length) bytes</p></div>")
    Write-Host ("  [{0}/{1}] version {2} ({3}x{3}), {4} bytes -> {5}" -f $idx, $n, $Q.Version, $Q.Size, $bytes.Length, $svgFile)
}

$html = "<!DOCTYPE html><html><head><meta charset='utf-8'><title>QR</title><style>body{font-family:Segoe UI,Arial,sans-serif;text-align:center}div.q{page-break-after:always;margin:24px auto}</style></head><body>$($parts.ToString())</body></html>"
$htmlFile = Join-Path $OutDir 'index.html'
Set-Content -LiteralPath $htmlFile -Value $html -Encoding UTF8
Write-Host "HTML: $htmlFile"
if ($Open) { Invoke-Item -LiteralPath $htmlFile }