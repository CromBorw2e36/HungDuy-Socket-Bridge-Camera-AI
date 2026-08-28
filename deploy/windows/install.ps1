# BridgeWebCamera - Windows installer (duoc goi tu install.bat, can quyen Admin)
# Thuan ASCII - PowerShell 5.1 doc file .ps1 theo ANSI, ky tu co dau se pha script.
#
# Tuy chon (truyen qua install.bat, vi du: install.bat -WithBuildTools):
#   -HailoVersion 4.21.0   phien ban Hailo phai dung (driver == runtime == wheel)
#   -NoHailoMsi            KHONG tu dong chay .msi trong vendor khi thieu wheel
#   -AnyHailoVersion       chap nhan wheel cp310 khac phien ban (KHONG khuyen khich)
#   -WithBuildTools        cai san Visual C++ Build Tools truoc khi pip
#   -NoBuildTools          khong bao gio dung toi Build Tools (ke ca khi pip bao thieu)
param(
    [string]$HailoVersion = '4.21.0',
    [switch]$NoHailoMsi,
    [switch]$AnyHailoVersion,
    [switch]$WithBuildTools,
    [switch]$NoBuildTools
)
$ErrorActionPreference = 'Stop'

function Fail($msg) {
    Write-Host ""
    Write-Host ("LOI: " + $msg) -ForegroundColor Red
    exit 1
}
function Step($msg) { Write-Host ""; Write-Host $msg -ForegroundColor Cyan }

# Chay 1 lenh native, VUA hien log VUA giu lai text de bat loi (pip bao thieu compiler...)
function Invoke-Native([string]$Exe, [string[]]$Arguments) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # 2>&1 tren native exe se throw neu de 'Stop'
    try {
        $lines = & $Exe @Arguments 2>&1 | ForEach-Object { Write-Host $_; $_ }
        $code  = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    return @{ Code = $code; Text = ($lines | Out-String) }
}

function Test-NeedsBuildTools([string]$log) {
    if (-not $log) { return $false }
    return ($log -match 'Microsoft Visual C\+\+ 14' -or
            $log -match 'Microsoft C\+\+ Build Tools' -or
            $log -match 'vcvarsall' -or
            $log -match "command 'cl\.exe' failed" -or
            $log -match 'Microsoft Visual Studio.*Build Tools')
}

function Install-BuildTools {
    $s = Join-Path $PSScriptRoot 'install_buildtools.ps1'
    if (-not (Test-Path $s)) { Write-Host "  Thieu install_buildtools.ps1" -ForegroundColor Yellow; return $false }
    & $s
    return ($LASTEXITCODE -eq 0)
}

# ---------- [0] Kiem tra quyen Administrator ----------
$wid = [Security.Principal.WindowsIdentity]::GetCurrent()
$prp = New-Object Security.Principal.WindowsPrincipal($wid)
if (-not $prp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Fail "Phai chay bang quyen Administrator. Chuot phai install.bat -> Run as administrator."
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $root
Write-Host ("Thu muc app: " + $root)

# ---------- [1] Tim Python 3.10 - TU CAI neu chua co ----------
function Find-Py310 {
    try {
        & py -3.10 --version *> $null
        if ($LASTEXITCODE -eq 0) { return @{ exe = 'py'; args = @('-3.10') } }
    } catch {}
    try {
        $v = (& python --version 2>$null) -join ''
        if ($v -match 'Python 3\.10\.') { return @{ exe = 'python'; args = @() } }
    } catch {}
    $direct = Join-Path $env:ProgramFiles 'Python310\python.exe'
    if (Test-Path $direct) { return @{ exe = $direct; args = @() } }
    return $null
}

Step "[1/6] Tim Python 3.10..."
$py = Find-Py310
if (-not $py) {
    Write-Host "  Chua co Python 3.10 - cai tu dong (wheel hailort cp310 + numpy 1.26 CHI chay tren 3.10)..."
    $pyInstaller = Join-Path $root 'deploy\vendor\python-3.10.11-amd64.exe'
    if (-not (Test-Path $pyInstaller)) {
        Write-Host "  Khong co san trong deploy\vendor - tai tu python.org (~28 MB)..."
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.10.11/python-3.10.11-amd64.exe' `
                -OutFile $pyInstaller -UseBasicParsing
        } catch {
            Fail ("Khong tai duoc bo cai Python (may khong co mang?). " +
                  "Copy python-3.10.11-amd64.exe vao deploy\vendor roi chay lai install.bat.")
        }
    }
    Write-Host "  Dang cai Python 3.10.11 (silent, cho 1-2 phut)..."
    $proc = Start-Process -FilePath $pyInstaller -Wait -PassThru -ArgumentList `
        '/quiet', 'InstallAllUsers=1', 'PrependPath=1', 'Include_launcher=1', 'Include_test=0'
    if ($proc.ExitCode -ne 0) {
        Fail ("Cai Python that bai (exit code " + $proc.ExitCode + "). Cai tay tu python.org roi chay lai.")
    }
    $py = Find-Py310
    if (-not $py) { Fail "Da cai Python 3.10 nhung phien lam viec chua nhan - dong cua so nay va chay lai install.bat." }
    Write-Host "  Da cai xong Python 3.10.11"
}
$pyExe = $py.exe; $pyArgs = $py.args
Write-Host ("  Dung: " + $pyExe + " " + ($pyArgs -join ' '))

# ---------- [2] venv + dependencies ----------
Step "[2/6] Tao venv + cai dependencies..."
if (Test-Path 'venv') { Remove-Item -Recurse -Force 'venv' }
& $pyExe @pyArgs -m venv venv
if ($LASTEXITCODE -ne 0) { Fail "Tao venv that bai." }
$venvPy = Join-Path $root 'venv\Scripts\python.exe'

$null = Invoke-Native $venvPy @('-m', 'pip', 'install', '--upgrade', 'pip', '--quiet')

if ($WithBuildTools -and -not $NoBuildTools) {
    Write-Host "  -WithBuildTools: kiem tra / cai Visual C++ Build Tools truoc..."
    Install-BuildTools | Out-Null
}

if (Test-Path 'deploy\vendor\pip') {
    $reqArgs = @('-m', 'pip', 'install', '--no-index', '--find-links', 'deploy\vendor\pip', '-r', 'requirements.txt')
} else {
    $reqArgs = @('-m', 'pip', 'install', '-r', 'requirements.txt')
}
$r = Invoke-Native $venvPy $reqArgs
if ($r.Code -ne 0 -and (Test-NeedsBuildTools $r.Text) -and -not $NoBuildTools) {
    Write-Host ""
    Write-Host "  pip phai build tu source nhung may thieu Visual C++ Build Tools." -ForegroundColor Yellow
    Write-Host "  Tu dong tai + cai Build Tools roi thu lai (dung -NoBuildTools de tat)..." -ForegroundColor Yellow
    if (Install-BuildTools) {
        Write-Host "  Cai lai dependencies..."
        $r = Invoke-Native $venvPy $reqArgs
    }
}
if ($r.Code -ne 0) { Fail "Cai dependencies that bai - xem log ben tren." }

# ---------- [3] Wheel pyhailort: vendor -> tim tren may -> .msi ----------
Step ("[3/6] Wheel pyhailort (hailort " + $HailoVersion + ")...")
$vendor  = Join-Path $root 'deploy\vendor'
$whlName = "hailort-{0}-cp310-cp310-win_amd64.whl" -f $HailoVersion

function Get-VendorWheel {
    $p = Join-Path $vendor $whlName
    if (Test-Path $p) { return $p }
    if ($AnyHailoVersion) {
        # sort theo so, khong theo chuoi (4.9 KHONG duoc cao hon 4.21)
        $byVer = @{ Expression = { (($_.Name -split '[^0-9]+' | Where-Object { $_ } |
                                     ForEach-Object { '{0:D6}' -f [int]$_ }) -join '.') } }
        $alt = @(Get-ChildItem -LiteralPath $vendor -Filter 'hailort-*-cp310-cp310-win_amd64.whl' -File -ErrorAction SilentlyContinue |
                 Sort-Object $byVer -Descending) | Select-Object -First 1
        if ($alt) { return $alt.FullName }
    }
    return $null
}

$whl = Get-VendorWheel
if ($whl) {
    Write-Host ("  Co san trong vendor: " + (Split-Path $whl -Leaf) + " (khong phai tim)")
} else {
    $fetch = Join-Path $PSScriptRoot 'fetch_hailo_wheel.ps1'
    if (Test-Path $fetch) {
        $fa = @('-Version', $HailoVersion, '-VendorDir', $vendor)
        if (-not $NoHailoMsi)  { $fa += '-InstallMsi' }
        if ($AnyHailoVersion)  { $fa += '-AnyVersion' }
        & $fetch @fa
        $whl = Get-VendorWheel
    } else {
        Write-Host "  Thieu fetch_hailo_wheel.ps1" -ForegroundColor Yellow
    }
}

$hailoOk = $false
if ($whl) {
    $r = Invoke-Native $venvPy @('-m', 'pip', 'install', $whl)
    if ($r.Code -ne 0) { Fail "Cai wheel hailort that bai." }
    $chk = Invoke-Native $venvPy @('-c', 'import hailo_platform, sys; sys.stdout.write("pyhailort OK")')
    if ($chk.Code -ne 0) {
        Write-Host "  [CANH BAO] Cai duoc wheel nhung 'import hailo_platform' loi - thuong do thieu driver HailoRT hoac sai phien ban." -ForegroundColor Yellow
    } else {
        $hailoOk = $true
    }
} else {
    Write-Host ""
    Write-Host "  [CANH BAO] Chua cai duoc pyhailort - app se KHONG nhan dien duoc khuon mat." -ForegroundColor Yellow
    Write-Host ("  Cai HailoRT (.msi) roi chay lai:  install.bat   hoac chi rieng buoc nay:") -ForegroundColor Yellow
    Write-Host ("    powershell -NoProfile -ExecutionPolicy Bypass -File " + (Join-Path $PSScriptRoot 'fetch_hailo_wheel.ps1')) -ForegroundColor Yellow
}

# ---------- [4] Firewall ----------
Step "[4/6] Mo firewall TCP 8765..."
try { Remove-NetFirewallRule -DisplayName 'BridgeWebCamera 8765' -ErrorAction Stop } catch {}
New-NetFirewallRule -DisplayName 'BridgeWebCamera 8765' -Direction Inbound -Action Allow `
    -Protocol TCP -LocalPort 8765 | Out-Null
Write-Host "  OK"

# ---------- [5] Tat PCIe power management (HailoRT 4.21 tren Windows treo neu bat) ----------
Step "[5/6] Tat PCIe Link State Power Management..."
try {
    & powercfg /setacvalueindex scheme_current sub_pciexpress ASPM 0 2>$null
    & powercfg /setdcvalueindex scheme_current sub_pciexpress ASPM 0 2>$null
    & powercfg /setactive scheme_current 2>$null
    Write-Host "  OK"
} catch { Write-Host "  (bo qua - chinh tay trong Power Options neu can)" -ForegroundColor Yellow }

# ---------- [6] Scheduled Task: chay khi logon, CHI khi user dang dang nhap ----------
Step "[6/6] Dang ky Scheduled Task 'BridgeWebCamera'..."
$bat = Join-Path $root 'deploy\windows\run_server.bat'
$action  = New-ScheduledTaskAction -Execute $bat -WorkingDirectory $root
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName 'BridgeWebCamera' -Action $action -Trigger $trigger `
    -RunLevel Highest -Force | Out-Null
Write-Host "  OK (chay duoi user hien tai, chi khi dang logon - service khong mo duoc camera)"

Write-Host ""
Write-Host "==== XONG ====" -ForegroundColor Green
Write-Host "Con viec tay:"
if (-not $hailoOk) {
    Write-Host ("  0. QUAN TRONG: cai driver HailoRT (deploy\vendor\*.msi) roi chay lai install.bat - " +
                "chua co pyhailort thi app khong chay duoc") -ForegroundColor Yellow
}
Write-Host "  1. Settings > Privacy > Camera: bat 'Camera access' + 'Let desktop apps access your camera'"
Write-Host "  2. Bat auto-logon cho user kiosk (netplwiz), roi logout/login"
Write-Host "Chay thu ngay:  schtasks /run /tn BridgeWebCamera   roi xem app.log"
