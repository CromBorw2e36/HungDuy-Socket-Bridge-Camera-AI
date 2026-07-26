# Kế hoạch triển khai BridgeWebCamera — Windows + Ubuntu 18.04

> Chốt ngày 2026-07-15, sau 2 vòng kiểm chứng (5 agent research web + 4 agent phản biện).
> Quy tắc bất di bất dịch: **driver == firmware == runtime == pyhailort == 4.21.0** ở mọi nơi.

## Quyết định

**MỘT codebase Python 3.10 duy nhất** — không viết lại C++ (~8–12 tuần, không thêm chức năng), không có Docker image chung (WSL2 không passthrough được PCIe → Docker chỉ dùng phía Linux).

| Nền tảng | Cách chạy |
|---|---|
| Windows 10/11 | Native venv + user kiosk auto-logon + Scheduled Task "At log on" (KHÔNG dùng service/NSSM — service session 0 bị Windows chặn camera) |
| Ubuntu 18.04.6 | Driver + firmware trên host (kernel HWE 5.4) + app trong container Ubuntu 22.04 |

Lý do container (đã thu hẹp sau review): **chỉ vì** binary libhailort/pyhailort của Hailo build cho glibc 22.04. Python stack còn lại (numpy/opencv/faiss/pandas — wheel manylinux2014) chạy được thẳng trên 18.04.

## Gói cài đặt — mỗi OS 1 lệnh

Không thể gom 2 OS vào 1 gói (driver .msi Windows / driver build-trên-host Linux là bước kernel, không exe/container nào thay được), nhưng mỗi OS là **1 thư mục copy vào + 1 lệnh**:

```
BridgeWebCamera/           ← copy nguyên thư mục này (USB/mạng nội bộ)
├── deploy/vendor/         ← nạp 1 lần trên máy có mạng + tài khoản Developer Zone:
│   ├── hailort_4.21.0_windows_installer.msi          (Windows driver+runtime)
│   ├── hailort-4.21.0-cp310-cp310-win_amd64.whl      (Windows pyhailort — KHÔNG có link tải riêng:
│   │                                                  nằm trong bộ cài .msi; cài .msi xong lấy từ
│   │                                                  C:\Program Files\HailoRT\ → dir /s /b *.whl)
│   ├── hailort_4.21.0_amd64.deb                      (Linux runtime, cho build image)
│   ├── hailort-4.21.0-cp310-cp310-linux_x86_64.whl   (Linux pyhailort, cho build image)
│   └── pip/               ← py -3.10 -m pip download -r requirements.txt -d deploy/vendor/pip
│                             (PHẢI chạy bằng Python 3.10 — bản khác sẽ tải nhầm wheel cp313)
│                             (chạy trên Windows lẫn Linux nếu muốn offline cả 2)
│   └── bridgecam-image-4.21.0.tar.gz ← build image 1 lần ở bất kỳ máy Linux/Docker Desktop nào:
│       docker build -t bridgecam:4.21.0 -f deploy/linux/Dockerfile .
│       docker save bridgecam:4.21.0 | gzip > deploy/vendor/bridgecam-image-4.21.0.tar.gz
│       → máy kiosk chỉ docker load, KHỎI build, khỏi cần Developer Zone
└── ...
```

| OS | Cài | Việc tay còn lại |
|---|---|---|
| Windows | Chạy **`deploy\windows\install.bat`** (Admin) | Cài Python 3.10 trước; click `.msi`; bật auto-logon (netplwiz) |
| Ubuntu | **`sudo bash deploy/linux/install.sh`** (chạy lại 1 lần sau reboot nếu script yêu cầu đổi kernel) | Cắm Hailo + camera |

`install.bat` tự làm: venv + pip (offline nếu có vendor/pip) + firewall 8765 + tắt PCIe power + đăng ký task logon. `install.sh` tự làm: kernel-gate → driver+firmware+udev+docker → copy code vào /opt/bridgecam → `docker load` image → cài + bật service.

## G0 — Gate 30 phút (làm TRƯỚC khi build image, trên máy 18.04)

Wheel 4.21 gắn tag `linux_x86_64` trơn → pip cài được trên bionic, chỉ có thể chết lúc import vì glibc:

```bash
# Miniforge python 3.10
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash Miniforge3-Linux-x86_64.sh -b && ~/miniforge3/bin/conda create -n bwc python=3.10 -y
~/miniforge3/envs/bwc/bin/pip install hailort-4.21.0-cp310-cp310-linux_x86_64.whl
~/miniforge3/envs/bwc/bin/python -c "import hailo_platform; print('OK')"
```

- **Import OK + nhận device** → BỎ Docker, chạy native bằng Miniforge (đơn giản hơn, giống Windows).
- **Fail `GLIBC_2.28/2.29 not found`** (dự đoán) → Docker theo P2.

## P0 — Sửa code cross-platform (ĐÃ LÀM 2026-07-15)

- Camera backend theo OS (`CAP_DSHOW`/`CAP_V4L2`), index qua env `CAMERA_INDEX`
- Chế độ headless: env `HEADLESS=1` (mặc định tự bật khi Linux không có DISPLAY); tkinter chỉ import khi có GUI; tiến trình in ra console
- Bỏ gọi API HRM lúc import → chuyển vào main, retry 3 lần; API chết + không cache → báo to
- Mọi đường dẫn (hef, employees_data) neo theo vị trí file script, hết phụ thuộc CWD
- Ghi JSON nhân viên kiểu atomic (tmp + replace); vòng xử lý bulk tôn trọng tín hiệu dừng
- Thread inference chết → thoát process (exit 1) để supervisor restart, thay vì chạy mù
- Camera do detection_loop tự release (hết race segfault V4L2); xả queue giữa các phiên client
- websockets handler bỏ tham số `path` (hỏng từ websockets 14)
- UTF-8 stdout guard (hết chết vì emoji khi redirect log trên Windows)
- Dọn: matplotlib, pyodbc, ImageEnhance, ghi file debug `1.jpg`/`imgs/`; xóa `copymain_api_cam.py` (chứa mật khẩu SA — **nên đổi mật khẩu `sa` của 172.16.10.30 khi tiện**, repo private nên không khẩn)
- requirements.txt → `opencv-python-headless`, bỏ pyodbc/matplotlib
- ⏸ Bỏ qua theo quyết định: bug timeout 1s trong `img_to_vec` (kết quả trễ có thể gán nhầm người — chấp nhận rủi ro; nếu sau này thấy nhận nhầm sau lần chạy đầu, xóa `employees_data/` chạy lại)

## P1 — Windows

1. Python 3.10 (trần của Hailo trên Windows) + HailoRT 4.21 Windows installer (.msi, từ Developer Zone — **lưu bản .msi + wheel vào ổ nội bộ**, không có trên PyPI).
2. `python -m venv venv && venv\Scripts\pip install -r requirements.txt` + cài wheel `hailort-4.21.0-cp310-cp310-win_amd64.whl`.
3. Device Manager → Hailo device → tắt "Allow the computer to turn off this device"; Power plan → PCIe Link State Power Management = Off (4.21 có báo cáo treo trên Windows nếu bật).
4. Firewall (admin): `netsh advfirewall firewall add rule name="BWC 8765" dir=in action=allow protocol=TCP localport=8765`
5. Auto-start: `install.bat` tự đăng ký Scheduled Task "BridgeWebCamera" (trigger At log on, chạy `run_server.bat` — vòng lặp restart + `PYTHONUTF8=1`). Chỉ cần bật auto-logon user kiosk (netplwiz). KHÔNG tự động pull code — cập nhật code là thao tác chủ động (copy bản mới / git pull tay).
6. KHÔNG dùng NSSM/service: session 0 không mở được webcam (Windows chặn camera cho phiên non-interactive).

## P2 — Ubuntu 18.04

### Host (chạy 1 lần — `deploy/linux/host_install.sh`)
```bash
sudo apt install --install-recommends linux-generic-hwe-18.04 linux-headers-generic-hwe-18.04 build-essential dkms
# reboot vào kernel 5.4, kiểm tra: uname -r
git clone --branch v4.21.0 https://github.com/hailo-ai/hailort-drivers && cd hailort-drivers/linux/pcie
make all && sudo make install_dkms
cd ../.. && ./download_firmware.sh
sudo mkdir -p /lib/firmware/hailo && sudo mv hailo8_fw.4.21.0.bin /lib/firmware/hailo/hailo8_fw.bin   # BẮT BUỘC trước modprobe
sudo cp linux/pcie/51-hailo-udev.rules /etc/udev/rules.d/ && sudo udevadm control --reload-rules
sudo modprobe hailo_pci && ls /dev/hailo0 && dmesg | grep -i hailo   # phải thấy dòng nạp firmware
mokutil --sb-state   # nếu Secure Boot enabled → tắt trong BIOS hoặc ký MOK
```
Docker: cài `docker-ce 24.0.2` cho bionic — **tải và lưu .deb về nội bộ ngay** (repo bionic đã đóng băng 5/2023, có thể bị gỡ; chấp nhận rủi ro runc CVE-2024-21626 vì chỉ chạy image tự build). Thêm `/etc/docker/daemon.json`:
```json
{"log-driver":"json-file","log-opts":{"max-size":"10m","max-file":"3"}}
```

### SSH để git pull repo riêng (câu hỏi của bạn)
Khuyến nghị **Deploy Key** (sạch hơn copy id_rsa từ Windows — key riêng cho máy, chỉ đọc, lộ máy nào thu hồi máy đó):
```bash
ssh-keygen -t ed25519 -f ~/.ssh/bwc_deploy -N "" -C "kiosk-ubuntu"
cat ~/.ssh/bwc_deploy.pub
# → github.com/CromBorw2e36/BridgeWebCameraPublic → Settings → Deploy keys → Add (KHÔNG tick write)
printf 'Host github.com\n  IdentityFile ~/.ssh/bwc_deploy\n  IdentitiesOnly yes\n' >> ~/.ssh/config
ssh -T git@github.com   # chấp nhận host key, phải thấy "successfully authenticated"
sudo mkdir -p /opt/bridgecam && sudo chown $USER /opt/bridgecam
git clone git@github.com:CromBorw2e36/BridgeWebCameraPublic.git /opt/bridgecam/app
```
(Cách 2 nhanh gọn: copy `id_rsa` từ Windows vào `~/.ssh/id_rsa`, `chmod 600 ~/.ssh/id_rsa && chmod 700 ~/.ssh` — dùng chung key 2 máy, kém an toàn hơn.)

### Container
- Image chỉ chứa **dependencies** (build từ `deploy/linux/Dockerfile`); **code bind-mount từ host clone** → cập nhật = `git pull` + restart container, giữ đúng thói quen như Windows.
- Vendor 2 file vào `deploy/linux/vendor/` trước khi build (tải từ Developer Zone): `hailort_4.21.0_amd64.deb`, `hailort-4.21.0-cp310-cp310-linux_x86_64.whl`.
- Build: `docker build -t bridgecam:4.21.0 -f deploy/linux/Dockerfile .`
- Volume `employees_data` là **bắt buộc** (không có → mỗi lần restart tải + embed lại toàn bộ ảnh, 10–50 phút).
- Camera pass theo đường dẫn ổn định: `ls /dev/v4l/by-id/` → lấy `...-video-index0`.
- Chạy qua systemd (`deploy/linux/bridgecam.service`): chờ device xuất hiện rồi mới start, `--network host` (tránh trùng dải 172.16/12 nội bộ), restart tự động.
- Cập nhật code: `cd /opt/bridgecam/app && git pull --ff-only && sudo systemctl restart bridgecam`

## P3 — Kiểm chứng

1. Trong container: `hailortcli fw-control identify` → firmware phải báo 4.21.0 (lệch = HAILO_INVALID_DRIVER_VERSION 76).
2. Golden test: cùng 1 ảnh nhân viên → embedding trên Windows và Ubuntu phải khớp (cùng .hef + cùng runtime).
3. End-to-end: mở `Web/ver2/index.html` trỏ `ws://<ip>:8765` → thấy hình + tên.
4. Camera probe nhanh trên host: `python3 -c "import cv2;c=cv2.VideoCapture(0,cv2.CAP_V4L2);print(c.isOpened(),c.read()[0])"`
5. Reboot test cả 2 máy: nguồn điện bật lại → tự chạy, không cần ai logon thao tác.

## Rủi ro còn lại

| Rủi ro | Xử lý |
|---|---|
| Chưa ai build hailo_pci trên đúng 18.04 (mới suy ra từ kernel 5.4 = kernel 20.04) | Smoke build ngay bước đầu P2; fail → cân nhắc nâng host lên 20.04 (LBP2900 vẫn chạy CAPT trên 20.04 i386) |
| Kernel host KHÔNG được nâng quá ~6.5 khi còn driver 4.21 | Ghi chú vào máy; 18.04 HWE 5.4 an toàn |
| Artifact Hailo phải tải qua login Developer Zone | Lưu .deb/.whl/.msi vào ổ nội bộ ngay lần tải đầu |
| Camera USB đổi index sau reboot/replug | Pass theo /dev/v4l/by-id; replug → systemd tự restart container |
