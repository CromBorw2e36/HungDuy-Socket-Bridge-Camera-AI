#!/bin/bash
# Cài đặt phía HOST Ubuntu 18.04.6 — chạy từng bước, KHÔNG chạy mù cả file lần đầu.
# Yêu cầu: đã reboot vào kernel HWE 5.4 trước khi build driver (bước 1 rồi reboot).
set -euo pipefail

# Đợi unattended-upgrades / apt khác nhả khóa (hay gặp ngay sau khi boot)
wait_apt() {
    while sudo fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock >/dev/null 2>&1; do
        echo "   Đang đợi tiến trình apt/cập nhật nền nhả khóa..."
        sleep 5
    done
}

echo "== [1/6] Kernel HWE 5.4 + toolchain =="
wait_apt
sudo apt-get update
sudo apt-get install -y --install-recommends linux-generic-hwe-18.04 \
    linux-headers-generic-hwe-18.04 build-essential dkms git curl mokutil
echo "Kernel hiện tại: $(uname -r)  (cần 5.4.x — nếu chưa phải, REBOOT rồi chạy tiếp)"

echo "== [2/6] Secure Boot phải OFF (hoặc tự ký MOK) =="
mokutil --sb-state || true

echo "== [3/6] Driver hailo_pci 4.21.0 (DKMS) =="
# Clone tại vị trí cố định (cạnh script) để chạy lại từ đâu cũng dùng lại clone cũ
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -d hailort-drivers ] || git clone --branch v4.21.0 https://github.com/hailo-ai/hailort-drivers

# PATCH bắt buộc trên 18.04: kernel Ubuntu HWE 5.4 đã backport dma_sync_sgtable_* (gốc kernel 5.8)
# nên shim cùng tên trong compact.h của Hailo bị "redefinition". Đổi tên shim -> dùng bản của kernel.
# (sed idempotent: chạy lại không sao)
sed -i 's/static inline void dma_sync_sgtable_for_device/static inline void hailo_unused_sync_sgtable_for_device/' \
    hailort-drivers/linux/utils/compact.h
sed -i 's/static inline void dma_sync_sgtable_for_cpu/static inline void hailo_unused_sync_sgtable_for_cpu/' \
    hailort-drivers/linux/utils/compact.h

cd hailort-drivers/linux/pcie
make all
sudo make install_dkms
cd ../..

echo "== [4/6] Firmware 4.21.0 — BẮT BUỘC trước modprobe =="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FW_LOCAL=$(ls "$SCRIPT_DIR/../vendor/"hailo8_fw*.bin 2>/dev/null | head -1 || true)
sudo mkdir -p /lib/firmware/hailo
if [ -n "$FW_LOCAL" ]; then
    echo "   Dùng firmware offline từ vendor: $FW_LOCAL"
    sudo cp -f "$FW_LOCAL" /lib/firmware/hailo/hailo8_fw.bin
else
    ./download_firmware.sh
    sudo mv -f hailo8_fw*.bin /lib/firmware/hailo/hailo8_fw.bin
fi
sudo cp linux/pcie/51-hailo-udev.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
cd ..

echo "== [5/6] Nạp driver =="
sudo modprobe hailo_pci
sleep 2
if lspci -d 1e60: 2>/dev/null | grep -q .; then
    ls -l /dev/hailo0
    dmesg | grep -i hailo | tail -5 || true
else
    echo "   [CẢNH BÁO] Không thấy thẻ Hailo trên PCI — driver đã cài nhưng bỏ qua kiểm tra /dev/hailo0."
    echo "   (Máy ảo/máy test? Máy triển khai thật PHẢI là máy vật lý cắm thẻ Hailo.)"
fi
dkms status | grep hailo || true

echo "== [6/6] Docker (bionic đóng băng ở 24.0.2 — lưu .deb về nội bộ sau khi cài!) =="
if ! command -v docker >/dev/null; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list
    wait_apt
    sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io
fi
echo '{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"3"}}' \
    | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker

echo "== XONG. Tiếp theo: clone repo vào /opt/bridgecam/app (xem README_TRIEN_KHAI.md mục SSH),"
echo "   build image, cài bridgecam.service =="
