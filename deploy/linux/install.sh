#!/bin/bash
# ============================================================
#  BridgeWebCamera — cài đặt 1 lệnh trên Ubuntu 18.04:
#     sudo bash deploy/linux/install.sh
#  Nếu chưa ở kernel 5.4: script cài kernel HWE rồi yêu cầu REBOOT,
#  reboot xong chạy lại đúng lệnh trên là xong.
# ============================================================
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$(cd "$DIR/../.." && pwd)"

# 0) Kernel gate: cần HWE 5.4 trước khi build driver
KVER=$(uname -r | cut -d. -f1-2)
if [ "$(printf '%s\n' 5.4 "$KVER" | sort -V | head -1)" != "5.4" ]; then
    echo "== Kernel hiện tại $(uname -r) < 5.4 — cài kernel HWE =="
    while fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock >/dev/null 2>&1; do
        echo "   Đang đợi tiến trình apt nhả khóa..."; sleep 5
    done
    apt-get update
    apt-get install -y --install-recommends linux-generic-hwe-18.04 linux-headers-generic-hwe-18.04
    echo ""
    echo ">>> REBOOT rồi chạy lại: sudo bash deploy/linux/install.sh <<<"
    exit 0
fi

# 1) Host: driver + firmware + udev + docker (idempotent)
if [ ! -e /dev/hailo0 ]; then
    bash "$DIR/host_install.sh"
else
    echo "== /dev/hailo0 đã có — bỏ qua bước driver =="
fi

# 2) Code vào /opt/bridgecam (giữ nguyên nếu đã là git clone)
mkdir -p /opt/bridgecam/employees_data
if [ ! -d /opt/bridgecam/app ]; then
    echo "== Copy code vào /opt/bridgecam/app =="
    cp -r "$APP_SRC" /opt/bridgecam/app
    # An toàn: không bao giờ để private key / backup cũ nằm trong bản deploy
    rm -rf /opt/bridgecam/app/id_rsa* /opt/bridgecam/app/id_ed25519* /opt/bridgecam/app/_old_backup
    echo "   (Cập nhật code là thao tác chủ động: copy bản mới rồi restart — KHÔNG tự pull)"
fi

# 3) Image: ưu tiên tarball đóng gói sẵn (docker load — kiosk khỏi cần build/Developer Zone)
if docker image inspect bridgecam:4.21.0 >/dev/null 2>&1; then
    echo "== Image bridgecam:4.21.0 đã có =="
elif [ -f "$DIR/../vendor/bridgecam-image-4.21.0.tar.gz" ]; then
    echo "== Nạp image từ tarball =="
    docker load < "$DIR/../vendor/bridgecam-image-4.21.0.tar.gz"
else
    echo "== Không có tarball — build image tại chỗ (cần vendor/.deb + .whl) =="
    docker build -t bridgecam:4.21.0 -f "$DIR/Dockerfile" "$APP_SRC"
fi

# 4) Service
cp "$DIR/bridgecam.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now bridgecam
sleep 3
systemctl --no-pager status bridgecam || true

echo ""
echo "==== XONG ===="
echo "Theo dõi log:   docker logs -f bridgecam"
echo "Camera ổn định: sửa BWC_CAMERA trong /etc/systemd/system/bridgecam.service"
echo "                theo ls /dev/v4l/by-id/ rồi: systemctl daemon-reload && systemctl restart bridgecam"
