# BridgeWebCamera - tai + cai Visual C++ Build Tools (silent), khong can mo Visual Studio
# Thuan ASCII - PowerShell 5.1 doc file .ps1 theo ANSI, ky tu co dau se pha script.
#
# Chi can khi pip PHAI build wheel tu source ("Microsoft Visual C++ 14.0 or greater is required").
# Voi requirements.txt hien tai (numpy/opencv/pandas/faiss/pillow deu co wheel cp310 win_amd64)
# thi KHONG can - install.ps1 chi goi script nay khi pip that su bao thieu compiler.
#
# Dung rieng:
#   powershell -NoProfile -ExecutionPolicy Bypass -File deploy\windows\install_buildtools.ps1
#   ... -Force                     cai lai du da co
#   ... -Layout D:\vslayout        CHI tai bo cai offline (may co mang), khong cai
#   ... -BootstrapperPath X.exe    dung file vs_BuildTools.exe da tai san
#
# Can: quyen Administrator, ~2 GB tai ve, ~5-7 GB o dia. May kiosk khong mang -> dung -Layout
# tren may co mang roi copy thu muc layout sang, chay:
#   <layout>\vs_BuildTools.exe --quiet --wait --norestart --noweb --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended

[CmdletBinding()]
param(
    [string] $VendorDir        = '',
    [string] $BootstrapperPath = '',
    [string] $Url              = 'https://aka.ms/vs/17/release/vs_BuildTools.exe',
    [string] $Layout           = '',
    [switch] $CheckOnly,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot rong khi script duoc goi kieu khac -> tu suy ra
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $VendorDir) { $VendorDir = Join-Path (Split-Path $ScriptDir -Parent) 'vendor' }

function Info($m) { Write-Host $m }
function Warn($m) { Write-Host $m -ForegroundColor Yellow }
function Good($m) { Write-Host $m -ForegroundColor Green }
function Bad($m)  { Write-Host $m -ForegroundColor Red }

$Workload  = 'Microsoft.VisualStudio.Workload.VCTools'
$VcCompId  = 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
$InstDir   = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer'
$VsWhere   = Join-Path $InstDir 'vswhere.exe'
$VsInstall = Join-Path $InstDir 'vs_installer.exe'

# ---------- Da co compiler chua? ----------
function Get-VcInstallPath {
    if (-not (Test-Path $VsWhere)) { return $null }
    try {
        $p = & $VsWhere -products '*' -latest -requires $VcCompId -property installationPath 2>$null
    } catch { return $null }
    if ($LASTEXITCODE -ne 0) { return $null }
    $p = ($p | Select-Object -First 1)
    if ($p -and (Test-Path $p)) { return $p }
    return $null
}

# Instance BuildTools da co (co the thieu workload VC) -> modify thay vi cai moi
function Get-BuildToolsPath {
    if (-not (Test-Path $VsWhere)) { return $null }
    try {
        $p = & $VsWhere -products 'Microsoft.VisualStudio.Product.BuildTools' -latest -property installationPath 2>$null
    } catch { return $null }
    $p = ($p | Select-Object -First 1)
    if ($p -and (Test-Path $p)) { return $p }
    return $null
}

if (-not $Layout) {
    $have = Get-VcInstallPath
    if ($have -and -not $Force) {
        Good ("  Da co Visual C++ Build Tools: " + $have)
        exit 0
    }
    if ($CheckOnly) {
        Warn "  CHUA co Visual C++ Build Tools (vswhere khong thay VC.Tools.x86.x64)."
        exit 1
    }
}

# ---------- Quyen Admin ----------
$wid = [Security.Principal.WindowsIdentity]::GetCurrent()
$prp = New-Object Security.Principal.WindowsPrincipal($wid)
if (-not $prp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -and -not $Layout) {
    Bad "  Can quyen Administrator de cai Build Tools."
    exit 2
}

# ---------- Lay bootstrapper (vendor -> tai ve) ----------
if (-not $BootstrapperPath) {
    if (-not (Test-Path $VendorDir)) { New-Item -ItemType Directory -Force $VendorDir | Out-Null }
    $BootstrapperPath = Join-Path $VendorDir 'vs_BuildTools.exe'
}
if (-not (Test-Path $BootstrapperPath)) {
    Info ("  Tai vs_BuildTools.exe (~4 MB) tu " + $Url + " ...")
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $tmp = $BootstrapperPath + '.part'
        Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing
        Move-Item -Force $tmp $BootstrapperPath
    } catch {
        Remove-Item -Force ($BootstrapperPath + '.part') -ErrorAction SilentlyContinue
        Bad ("  Khong tai duoc bootstrapper: " + $_.Exception.Message)
        Warn ("  May khong co mang -> tai tay tu " + $Url)
        Warn ("  roi dat file vao " + $BootstrapperPath + " va chay lai.")
        exit 3
    }
    Good "  Da tai xong bootstrapper."
} else {
    Info ("  Dung bootstrapper co san: " + $BootstrapperPath)
}

# ---------- Chi tao layout offline ----------
if ($Layout) {
    Info ("  Tao bo cai offline tai: " + $Layout + " (~2 GB, cho 10-30 phut)...")
    $p = Start-Process -FilePath $BootstrapperPath -Wait -PassThru -ArgumentList @(
        '--layout', ('"' + $Layout + '"'), '--add', $Workload, '--includeRecommended', '--lang', 'en-US', '--quiet')
    if ($p.ExitCode -eq 0) {
        Good ("  Xong. Copy thu muc " + $Layout + " sang may kiosk roi chay:")
        Info  "    vs_BuildTools.exe --quiet --wait --norestart --noweb --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
        exit 0
    }
    Bad ("  Tao layout that bai (exit code " + $p.ExitCode + ").")
    exit 4
}

# ---------- Cai ----------
$bt = Get-BuildToolsPath
if ($bt -and (Test-Path $VsInstall)) {
    Info ("  Da co Build Tools nhung thieu workload C++ -> modify: " + $bt)
    $exe  = $VsInstall
    $args = @('modify', '--installPath', ('"' + $bt + '"'), '--add', $Workload, '--includeRecommended',
              '--quiet', '--wait', '--norestart', '--nocache')
} else {
    Info "  Cai Visual C++ Build Tools (tai ~2 GB, chiem ~5-7 GB o dia, cho 10-40 phut)..."
    $exe  = $BootstrapperPath
    $args = @('--add', $Workload, '--includeRecommended',
              '--quiet', '--wait', '--norestart', '--nocache')
}

$p = Start-Process -FilePath $exe -Wait -PassThru -ArgumentList $args
$code = $p.ExitCode

switch ($code) {
    0     { Good "  Cai Build Tools thanh cong." }
    3010  { Warn "  Cai xong nhung Windows yeu cau REBOOT (3010) - neu pip van bao thieu compiler, reboot roi chay lai install.bat." }
    1602  { Bad  "  Nguoi dung huy cai dat (1602)." }
    1618  { Bad  "  Dang co bo cai khac chay (1618) - doi xong roi chay lai." }
    5007  { Bad  "  Bi chan boi dieu kien may (5007) - xem log trong %TEMP%\dd_setup_*.log." }
    default { Bad ("  Cai Build Tools that bai (exit code " + $code + ") - log: %TEMP%\dd_bootstrapper_*.log, %TEMP%\dd_setup_*.log") }
}

if ($code -eq 0 -or $code -eq 3010) {
    $now = Get-VcInstallPath
    if ($now) { Good ("  Kiem tra lai: co VC compiler tai " + $now) }
    else { Warn "  Cai xong nhung vswhere chua thay VC.Tools.x86.x64 - co the can reboot." }
    exit 0
}
exit 5
