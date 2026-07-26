# BridgeWebCamera - Windows installer (duoc goi tu install.bat, can quyen Admin)
# Thuan ASCII - PowerShell 5.1 doc file .ps1 theo ANSI, ky tu co dau se pha script.
$ErrorActionPreference = 'Stop'

function Fail($msg) {
    Write-Host ""
    Write-Host ("LOI: " + $msg) -ForegroundColor Red
    exit 1
}
function Step($msg) { Write-Host ""; Write-Host $msg -ForegroundColor Cyan }

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

Step "[1/5] Tim Python 3.10..."
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
Step "[2/5] Tao venv + cai dependencies..."
if (Test-Path 'venv') { Remove-Item -Recurse -Force 'venv' }
& $pyExe @pyArgs -m venv venv
if ($LASTEXITCODE -ne 0) { Fail "Tao venv that bai." }
$venvPy = Join-Path $root 'venv\Scripts\python.exe'

& $venvPy -m pip install --upgrade pip --quiet 2>$null
if (Test-Path 'deploy\vendor\pip') {
    & $venvPy -m pip install --no-index --find-links deploy\vendor\pip -r requirements.txt
} else {
    & $venvPy -m pip install -r requirements.txt
}
if ($LASTEXITCODE -ne 0) { Fail "Cai dependencies that bai - xem log ben tren." }

$whl = 'deploy\vendor\hailort-4.21.0-cp310-cp310-win_amd64.whl'
if (Test-Path $whl) {
    & $venvPy -m pip install $whl
    if ($LASTEXITCODE -ne 0) { Fail "Cai wheel hailort that bai." }
} else {
    Write-Host "  [CANH BAO] Thieu wheel hailort trong deploy\vendor - wheel nam TRONG bo cai .msi:" -ForegroundColor Yellow
    Write-Host "    1. Cai deploy\vendor\hailort_4.21.0_windows_installer.msi truoc"
    Write-Host "    2. Chay:  dir /s /b `"C:\Program Files\HailoRT\*.whl`""
    Write-Host "    3. Copy file .whl vao deploy\vendor roi chay lai install.bat"
}

# ---------- [3] Firewall ----------
Step "[3/5] Mo firewall TCP 8765..."
try { Remove-NetFirewallRule -DisplayName 'BridgeWebCamera 8765' -ErrorAction Stop } catch {}
New-NetFirewallRule -DisplayName 'BridgeWebCamera 8765' -Direction Inbound -Action Allow `
    -Protocol TCP -LocalPort 8765 | Out-Null
Write-Host "  OK"

# ---------- [4] Tat PCIe power management (HailoRT 4.21 tren Windows treo neu bat) ----------
Step "[4/5] Tat PCIe Link State Power Management..."
try {
    & powercfg /setacvalueindex scheme_current sub_pciexpress ASPM 0 2>$null
    & powercfg /setdcvalueindex scheme_current sub_pciexpress ASPM 0 2>$null
    & powercfg /setactive scheme_current 2>$null
    Write-Host "  OK"
} catch { Write-Host "  (bo qua - chinh tay trong Power Options neu can)" -ForegroundColor Yellow }

# ---------- [5] Scheduled Task: chay khi logon, CHI khi user dang dang nhap ----------
Step "[5/5] Dang ky Scheduled Task 'BridgeWebCamera'..."
$bat = Join-Path $root 'deploy\windows\run_server.bat'
$action  = New-ScheduledTaskAction -Execute $bat -WorkingDirectory $root
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName 'BridgeWebCamera' -Action $action -Trigger $trigger `
    -RunLevel Highest -Force | Out-Null
Write-Host "  OK (chay duoi user hien tai, chi khi dang logon - service khong mo duoc camera)"

Write-Host ""
Write-Host "==== XONG ====" -ForegroundColor Green
Write-Host "Con viec tay:"
Write-Host "  1. Cai driver: deploy\vendor\hailort_4.21.0_windows_installer.msi (neu chua)"
Write-Host "  2. Settings > Privacy > Camera: bat 'Camera access' + 'Let desktop apps access your camera'"
Write-Host "  3. Bat auto-logon cho user kiosk (netplwiz), roi logout/login"
Write-Host "Chay thu ngay:  schtasks /run /tn BridgeWebCamera   roi xem app.log"
