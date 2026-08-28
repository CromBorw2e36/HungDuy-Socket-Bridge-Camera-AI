# BridgeWebCamera - tim wheel pyhailort (Windows) va copy vao deploy\vendor
# Thuan ASCII - PowerShell 5.1 doc file .ps1 theo ANSI, ky tu co dau se pha script.
#
# Wheel hailort-<ver>-cp310-cp310-win_amd64.whl KHONG co tren PyPI:
# no nam BEN TRONG bo cai .msi cua Hailo Developer Zone. Script nay:
#   1. Co san trong deploy\vendor  -> DUNG LUON, khong tim gi nua
#   2. Chua co  -> quet cac thu muc cai HailoRT (+ registry) -> copy vao vendor
#   3. Van chua co + co .msi trong vendor + -InstallMsi -> chay .msi roi quet lai
#   4. Van chua co -> in huong dan (cai Hailo truoc), thoat code 1
#
# Chay rieng tren may DEV da cai HailoRT (nap vendor truoc khi dong goi):
#   powershell -NoProfile -ExecutionPolicy Bypass -File deploy\windows\fetch_hailo_wheel.ps1
#
# Quy tac bat di bat dich: driver == firmware == runtime == pyhailort == cung 1 phien ban.

[CmdletBinding()]
param(
    [string]   $Version    = '4.21.0',
    [string]   $VendorDir  = '',
    [string[]] $SearchPath = @(),
    [switch]   $InstallMsi,
    [switch]   $AnyVersion
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot rong khi script duoc goi kieu khac -> tu suy ra
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $VendorDir) { $VendorDir = Join-Path (Split-Path $ScriptDir -Parent) 'vendor' }
$PyTag   = 'cp310'
$PlatTag = 'win_amd64'
$NameRx  = '^hailort-(?<ver>[0-9][0-9A-Za-z._]*)-(?<py>cp\d+)-(?<abi>[^-]+)-(?<plat>[^-]+)\.whl$'

function Info($m) { Write-Host $m }
function Warn($m) { Write-Host $m -ForegroundColor Yellow }
function Good($m) { Write-Host $m -ForegroundColor Green }
function Bad($m)  { Write-Host $m -ForegroundColor Red }

function Get-WheelInfo([System.IO.FileInfo]$f) {
    if ($f.Name -notmatch $NameRx) { return $null }
    return [pscustomobject]@{
        Path = $f.FullName
        Name = $f.Name
        Ver  = $Matches['ver']
        Py   = $Matches['py']
        Plat = $Matches['plat']
    }
}

# ---------- [1] Da co san trong vendor? ----------
if (-not (Test-Path $VendorDir)) { New-Item -ItemType Directory -Force $VendorDir | Out-Null }
$VendorDir = (Resolve-Path $VendorDir).Path
$want = "hailort-{0}-{1}-{1}-{2}.whl" -f $Version, $PyTag, $PlatTag

if (Test-Path (Join-Path $VendorDir $want)) {
    Good ("  Wheel da co san trong vendor: " + $want + " (bo qua buoc tim)")
    exit 0
}

$vendorOther = @(Get-ChildItem -LiteralPath $VendorDir -Filter 'hailort-*.whl' -File -ErrorAction SilentlyContinue |
                 ForEach-Object { Get-WheelInfo $_ } | Where-Object { $_ -and $_.Plat -eq $PlatTag })
if ($vendorOther.Count -gt 0) {
    if ($AnyVersion) {
        $pick = $vendorOther | Where-Object { $_.Py -eq $PyTag } | Select-Object -First 1
        if ($pick) {
            Warn ("  [CANH BAO] Vendor co wheel khac phien ban: " + $pick.Name + " (yeu cau " + $Version + ") - chap nhan vi -AnyVersion")
            exit 0
        }
    }
    Warn "  Vendor co wheel hailort nhung khong khop yeu cau:"
    foreach ($w in $vendorOther) { Warn ("    " + $w.Name) }
    Warn ("  Can: " + $want)
}

Info ("  Chua co wheel trong vendor - dang tim tren may (can " + $want + ")...")

# ---------- [2] Quet cac vi tri cai HailoRT ----------
function Get-SearchRoots {
    $roots = New-Object System.Collections.Generic.List[object]
    function Add-Root($p, $d) {
        if ([string]::IsNullOrWhiteSpace($p)) { return }
        $p = $p.Trim().TrimEnd('\')
        if (-not (Test-Path -LiteralPath $p)) { return }
        $full = (Resolve-Path -LiteralPath $p).Path
        foreach ($r in $roots) { if ($r.Path -eq $full) { return } }
        $roots.Add([pscustomobject]@{ Path = $full; Depth = $d })
    }

    # Duong dan cai mac dinh cua HailoRT Windows installer
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA 'Programs'))) {
        if ($base) {
            Add-Root (Join-Path $base 'HailoRT') 6
            Add-Root (Join-Path $base 'Hailo')   6
        }
    }
    Add-Root 'C:\HailoRT' 6
    Add-Root 'C:\Hailo'   6

    # Registry Uninstall -> InstallLocation cua bat ky goi Hailo nao
    foreach ($k in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                     'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                     'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
        try {
            Get-ItemProperty -Path $k -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like '*Hailo*' -and $_.InstallLocation } |
                ForEach-Object { Add-Root $_.InstallLocation 6 }
        } catch {}
    }

    # Noi ky thuat vien hay de file tai ve
    foreach ($p in @((Join-Path $env:USERPROFILE 'Downloads'), (Join-Path $env:USERPROFILE 'Desktop'),
                     (Join-Path $env:PUBLIC 'Downloads'), (Join-Path $env:PUBLIC 'Desktop'))) {
        Add-Root $p 3
    }

    foreach ($p in $SearchPath) { Add-Root $p 8 }
    return $roots
}

function Find-Wheels {
    $found = New-Object System.Collections.Generic.List[object]
    foreach ($r in (Get-SearchRoots)) {
        Info ("    quet: " + $r.Path)
        $files = @()
        try {
            $files = @(Get-ChildItem -LiteralPath $r.Path -Filter 'hailort-*.whl' -Recurse -Depth $r.Depth -File -Force -ErrorAction SilentlyContinue)
        } catch { $files = @() }
        foreach ($f in $files) {
            $i = Get-WheelInfo $f
            if ($i) { $found.Add($i) }
        }
    }
    return $found
}

function Copy-Best($wheels) {
    $hit = @($wheels | Where-Object { $_.Ver -eq $Version -and $_.Py -eq $PyTag -and $_.Plat -eq $PlatTag })
    if ($hit.Count -eq 0 -and $AnyVersion) {
        # sort theo so, khong theo chuoi (4.9 KHONG duoc cao hon 4.21)
        $byVer = @{ Expression = { (($_.Ver -split '[^0-9]+' | Where-Object { $_ } |
                                    ForEach-Object { '{0:D6}' -f [int]$_ }) -join '.') } }
        $hit = @($wheels | Where-Object { $_.Py -eq $PyTag -and $_.Plat -eq $PlatTag } | Sort-Object $byVer -Descending)
        if ($hit.Count -gt 0) {
            Warn ("  [CANH BAO] Khong co dung " + $Version + " - dung " + $hit[0].Name + " theo -AnyVersion")
        }
    }
    if ($hit.Count -eq 0) { return $null }

    $src = $hit[0]
    $dst = Join-Path $VendorDir $src.Name
    Copy-Item -LiteralPath $src.Path -Destination $dst -Force
    Good ("  Da copy wheel vao vendor: " + $src.Name)
    Info ("    nguon: " + $src.Path)
    return $dst
}

$wheels = Find-Wheels
if (Copy-Best $wheels) { exit 0 }

# ---------- [3] Chua thay -> cai .msi roi quet lai ----------
$msi = @(Get-ChildItem -LiteralPath $VendorDir -Filter 'hailort*windows*installer*.msi' -File -ErrorAction SilentlyContinue |
         Sort-Object @{ Expression = { if ($_.Name -like ('*' + $Version + '*')) { 0 } else { 1 } } }, Name) | Select-Object -First 1

if ($wheels.Count -gt 0) {
    Warn "  Tim thay wheel hailort tren may nhung khong dung tag can dung:"
    foreach ($w in ($wheels | Sort-Object Name -Unique)) { Warn ("    " + $w.Name) }
}

if ($msi -and $InstallMsi) {
    $wid = [Security.Principal.WindowsIdentity]::GetCurrent()
    $prp = New-Object Security.Principal.WindowsPrincipal($wid)
    if (-not $prp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Bad "  Can quyen Administrator de chay bo cai .msi - bo qua buoc tu cai."
    } else {
        Info ("  Chua cai HailoRT -> chay bo cai: " + $msi.Name + " (cho 1-3 phut)...")
        $p = Start-Process -FilePath 'msiexec.exe' -Wait -PassThru -ArgumentList @('/i', ('"' + $msi.FullName + '"'), '/passive', '/norestart')
        if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) {
            if ($p.ExitCode -eq 3010) { Warn "  Bo cai yeu cau REBOOT (3010) - nho khoi dong lai may sau khi cai xong." }
            Good "  Da cai HailoRT - quet lai wheel..."
            if (Copy-Best (Find-Wheels)) { exit 0 }
        } else {
            Bad ("  Cai .msi that bai (exit code " + $p.ExitCode + ").")
        }
    }
}

# ---------- [4] Bo tay -> huong dan ----------
Write-Host ""
Bad ("  KHONG tim thay " + $want)
Warn "  Wheel nay KHONG tai duoc tu PyPI - no nam trong bo cai .msi cua Hailo. Lam theo:"
if ($msi) {
    Warn ("    1. Cai driver truoc (chuot phai -> Install):  " + $msi.FullName)
} else {
    Warn  "    1. Tai + cai HailoRT Windows installer (.msi) tu Hailo Developer Zone"
    Warn ("       (nen luu file .msi vao " + $VendorDir + ")")
}
Warn  '    2. Tim wheel:  dir /s /b "C:\Program Files\HailoRT\*.whl"'
Warn ("    3. Copy file .whl do vao " + $VendorDir)
Warn  "    4. Chay lai install.bat - lan sau thay san trong vendor, khong phai tim nua"
Write-Host ""
Warn  "  Hoac cai Hailo xong roi chay lai rieng script nay:"
Warn ("    powershell -NoProfile -ExecutionPolicy Bypass -File " + (Join-Path $ScriptDir 'fetch_hailo_wheel.ps1'))
exit 1
