# Tao goi cai dat: BridgeWebCamera-setup.zip (chay tren may dev)
#   powershell -ExecutionPolicy Bypass -File deploy\make_package.ps1
$root  = Split-Path $PSScriptRoot -Parent
$stage = Join-Path $env:TEMP "bwc_package\BridgeWebCamera"
$zip   = Join-Path (Split-Path $root -Parent) "BridgeWebCamera-setup.zip"

Remove-Item -Recurse -Force (Split-Path $stage -Parent) -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $stage | Out-Null

# Chi dong goi nhung gi may kiosk can (khong log, __pycache__, cmd1 cu, venv, id_rsa...)
$include = @(
    "main_api_cam.py", "Utils.py", "hailo_inference.py", "websocket_server.py",
    "requirements.txt", "README_TRIENKHAI.md", ".dockerignore",
    "scrfd_2.5g.hef", "arcface_r50.hef",
    "deploy", "Web"
)
foreach ($item in $include) {
    $src = Join-Path $root $item
    if (Test-Path $src) { Copy-Item -Recurse -Force $src $stage }
    else { Write-Warning "Thieu: $item" }
}

# Kem cache embedding neu co (may moi khoi phai tai + embed lai, do 10-50 phut cold start)
$emp = Join-Path $root "employees_data"
if (Test-Path $emp) { Copy-Item -Recurse -Force $emp $stage }

# Loai junk trong staging neu lo dinh
Get-ChildItem -Recurse (Split-Path $stage -Parent) -Include "__pycache__", "*.pyc", "*.log", "1.jpg" -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# LUOI AN TOAN: khong bao gio dong goi private key
$secrets = Get-ChildItem -Recurse $stage -Force -File -ErrorAction SilentlyContinue | Where-Object {
    ($_.Name -match '^(id_rsa|id_ed25519)') -or
    ($_.Extension -eq '.pem') -or
    ($_.Extension -eq '.ppk') -or
    (((Get-Content $_.FullName -TotalCount 1 -ErrorAction SilentlyContinue) -join '') -match 'PRIVATE KEY')
}
if ($secrets) {
    Write-Warning "PHAT HIEN private key trong goi, da loai bo (KHONG dong goi):"
    foreach ($s in $secrets) { Write-Warning ("   " + $s.FullName); Remove-Item -Force $s.FullName }
}

Remove-Item -Force $zip -ErrorAction SilentlyContinue
Compress-Archive -Path $stage -DestinationPath $zip
Remove-Item -Recurse -Force (Split-Path $stage -Parent)

$sizeMB = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host "Da tao: $zip"
Write-Host "Dung luong: $sizeMB MB"
