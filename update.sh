#!/bin/sh
# OpenWrt x86_64 裸机软路由 (Legacy BIOS) 自动更新脚本
# 功能: 显示版本对比、确认下载、确认升级、保留配置、自动重启并清理临时文件

# 1. 获取当前系统版本
CURRENT=$(cat /etc/openwrt_release | grep DISTRIB_RELEASE | cut -d"'" -f2)
echo "[*] 当前系统版本: $CURRENT"

# 2. 自动获取最新稳定版版本号
LATEST=$(wget -qO- https://downloads.openwrt.org/releases/ | grep -Eo '23\.[0-9]+\.[0-9]+' | sort -V | tail -n1)

if [ -z "$LATEST" ]; then
    echo "[!] 无法获取最新版本号，请检查网络。"
    exit 1
fi

echo "[*] 检测到最新版本: $LATEST"
echo "[*] 系统版本对比: $CURRENT → $LATEST"

BASE_URL="https://downloads.openwrt.org/releases/$LATEST/targets/x86/64"
FIRMWARE="openwrt-$LATEST-x86-64-generic-squashfs-combined.img.gz"

# 3. 确认是否下载
read -p "是否下载固件 $FIRMWARE ? (y/n): " confirm_dl
if [ "$confirm_dl" != "y" ]; then
    echo "[*] 已取消操作。"
    exit 0
fi

# 4. 备份配置
echo "[*] 备份配置到 /tmp/backup.tar.gz"
sysupgrade -b /tmp/backup.tar.gz

# 5. 下载固件
echo "[*] 正在下载固件..."
cd /tmp
wget -q --show-progress "$BASE_URL/$FIRMWARE" -O "$FIRMWARE"

# 6. 校验下载结果
if [ ! -s "$FIRMWARE" ]; then
    echo "[!] 固件下载失败，请检查版本/网络。"
    exit 1
fi

# 7. 确认是否升级
read -p "是否立即升级到 $LATEST ? (y/n): " confirm_up
if [ "$confirm_up" != "y" ]; then
    echo "[*] 已取消升级。"
    rm -f "$FIRMWARE"
    exit 0
fi

# 8. 解压固件
echo "[*] 解压固件..."
gunzip -f "$FIRMWARE"
IMG_FILE="${FIRMWARE%.gz}"

# 9. 开始升级
echo "[*] 开始升级 (保留配置)..."
sysupgrade -c "$IMG_FILE"

# 10. 如果 sysupgrade 成功，清理文件并重启
if [ $? -eq 0 ]; then
    echo "[*] 升级完成，清理临时文件..."
    rm -f /tmp/openwrt-*.img /tmp/openwrt-*.gz
    echo "[*] 系统将在 5 秒后重启..."
    sleep 5
    reboot
else
    echo "[!] 升级失败，请检查日志。"
fi
