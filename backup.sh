#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYS_DIR="$DOTFILES_DIR/system"
ETC_DIR="$SYS_DIR/etc"

echo "==> Đang sao lưu cấu hình hệ thống (đã ẩn danh & tổng quát hóa) vào: $SYS_DIR"
rm -rf "$ETC_DIR"
mkdir -p "$ETC_DIR"

# 1. Xuất danh sách gói chính thức (loại trừ microcode đặc thù CPU để dùng chung mọi máy) và AUR
echo "  -> Lưu danh sách gói pacman (pkglist.txt) và AUR (aurlist.txt)..."
pacman -Qnqe | grep -vE '^(amd-ucode|intel-ucode)$' | sort > "$SYS_DIR/pkglist.txt"
pacman -Qmq  | sort > "$SYS_DIR/aurlist.txt"

# 2. Xuất danh sách systemd services đang bật
echo "  -> Lưu danh sách systemd services đang bật..."
systemctl list-unit-files --state=enabled --no-legend --no-pager \
  | awk '{print $1}' | sort > "$SYS_DIR/services-system.txt"

systemctl --user list-unit-files --state=enabled --no-legend --no-pager \
  | awk '{print $1}' | sort > "$SYS_DIR/services-user.txt"

# 3. Sao lưu các file cấu hình trong /etc (không chứa thông tin định danh phần cứng)
ETC_FILES=(
  "/etc/environment"
  "/etc/locale.conf"
  "/etc/locale.gen"
  "/etc/vconsole.conf"
  "/etc/makepkg.conf"
  "/etc/mkinitcpio.conf"
  "/etc/mkinitcpio.d/linux-lts.preset"
  "/etc/modprobe.d/audio_disable_powersave.conf"
  "/etc/modprobe.d/disable-pcspkr.conf"
  "/etc/systemd/logind.conf"
  "/etc/systemd/zram-generator.conf"
  "/etc/systemd/network/20-wired.network"
  "/etc/iwd/main.conf"
  "/etc/X11/xorg.conf.d/00-keyboard.conf"
)

echo "  -> Sao lưu và tổng quát hóa các file cấu hình /etc..."
for src in "${ETC_FILES[@]}"; do
  if [ -f "$src" ]; then
    rel="${src#/etc/}"
    dest="$ETC_DIR/$rel"
    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest"
  fi
done

# Tổng quát hóa MODULES=() trong mkinitcpio.conf (restore.sh sẽ tự nhận diện GPU/NVMe của từng máy)
if [ -f "$ETC_DIR/mkinitcpio.conf" ]; then
  sed -i 's/^MODULES=.*/MODULES=()/g' "$ETC_DIR/mkinitcpio.conf"
fi

# 4. Lưu tham số kernel cmdline (đã loại bỏ hoàn toàn root=PARTUUID=... và rootfstype=...)
if [ -f /etc/kernel/cmdline ]; then
  mkdir -p "$ETC_DIR/kernel"
  sed -E 's/\b(root|rootfstype)=[^ ]+\s*//g; s/\s+/ /g; s/^ //; s/ $//' /etc/kernel/cmdline \
    > "$ETC_DIR/kernel/cmdline.params"
fi

# 5. Lưu mẫu fstab đã ẩn danh hoàn toàn UUID và tên ổ cứng
if [ -f /etc/fstab ]; then
  sed -E \
    -e 's|^#\s*/dev/.*|# <device>|g' \
    -e 's|^(PART)?UUID=[^[:space:]]+|<YOUR_PARTITION_UUID>|g' \
    /etc/fstab > "$ETC_DIR/fstab.template"
fi

echo "==> Hoàn tất sao lưu (không chứa UUID hay thông tin nhạy cảm)!"
echo "    - Gói chính thức : $(wc -l < "$SYS_DIR/pkglist.txt") gói"
echo "    - Gói AUR        : $(wc -l < "$SYS_DIR/aurlist.txt") gói"
echo "    - File /etc      : $(find "$ETC_DIR" -type f | wc -l) file"
