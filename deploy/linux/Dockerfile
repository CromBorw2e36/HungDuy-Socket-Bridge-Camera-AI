# Image CHỈ chứa dependencies — code bind-mount từ host clone vào /app
# Build từ repo root:  docker build -t bridgecam:4.21.0 -f deploy/linux/Dockerfile .
# Trước khi build: tải 2 file từ Hailo Developer Zone vào deploy/vendor/
#   - hailort_4.21.0_amd64.deb
#   - hailort-4.21.0-cp310-cp310-linux_x86_64.whl
# YÊU CẦU HOST 18.04: Docker Engine >= 20.10.10 (glibc 2.35 trong image 22.04 dùng
#   syscall clone3; docker cũ hơn trả EPERM -> python/threads crash ngẫu nhiên).
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive PYTHONUNBUFFERED=1 PYTHONUTF8=1 \
    TZ=Asia/Ho_Chi_Minh HEADLESS=1

# python3-netifaces: dependency của wheel hailort — netifaces không có wheel cp310,
# lấy bản dựng sẵn của Ubuntu để khỏi phải cài gcc vào image
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3.10 python3-pip python3-netifaces ca-certificates tzdata libglib2.0-0 libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY deploy/vendor/hailort_4.21.0_amd64.deb /tmp/
COPY deploy/vendor/hailort-4.21.0-cp310-cp310-linux_x86_64.whl /tmp/

# postinst của deb chỉ cấu hình hailort_service (systemd) mà container KHÔNG dùng —
# nó gọi systemctl/đọc stdin nên luôn chết trong docker build (thử shim systemctl vẫn fail exit 1).
# Giải pháp dứt điểm: unpack rồi BỎ HẲN postinst, configure "chay".
# App chạy 1 process, VDevice group_id=SHARED truy cập driver trực tiếp — không cần service.
RUN dpkg --unpack /tmp/hailort_4.21.0_amd64.deb \
    && rm -f /var/lib/dpkg/info/hailort.postinst \
    && dpkg --configure hailort \
    && ldconfig

COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt \
        /tmp/hailort-4.21.0-cp310-cp310-linux_x86_64.whl \
    && rm -f /tmp/*.whl /tmp/*.deb /tmp/requirements.txt

WORKDIR /app
EXPOSE 8765
CMD ["python3", "-u", "main_api_cam.py"]
