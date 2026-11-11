#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYS_DIR="$DOTFILES_DIR/system"
ETC_DIR="$SYS_DIR/etc"

STOW_PKGS=(
  bg
  environment.d
  fcitx5
  fish
  foot
  fuzzel
  gtk-3.0
  gtk-4.0
  gtkrc-2.0
  helix
  mimeapps
  pacseek
  pcmanfm
  sway
  xsettingsd
  yazi
  zed
)

echo "=========================================================="
echo "  KHÔI PHỤC CẤU HÌNH HỆ THỐNG & DOTFILES (ARCH LINUX)"
echo "=========================================================="

# 1. Cài đặt gói chính thức + tự động nhận diện CPU microcode (AMD / Intel)
if [ -f "$SYS_DIR/pkglist.txt" ]; then
  echo "==> [1/6] Cài đặt các gói chính thức từ pkglist.txt..."
  sudo pacman -Syu --needed --noconfirm - < "$SYS_DIR/pkglist.txt"
fi

if grep -q "AuthenticAMD" /proc/cpuinfo 2>/dev/null; then
  echo "  -> Phát hiện CPU AMD: cài đặt amd-ucode..."
  sudo pacman -S --needed --noconfirm amd-ucode
elif grep -q "GenuineIntel" /proc/cpuinfo 2>/dev/null; then
  echo "  -> Phát hiện CPU Intel: cài đặt intel-ucode..."
  sudo pacman -S --needed --noconfirm intel-ucode
fi

# 2. Cài đặt paru (AUR helper) và các gói AUR từ aurlist.txt
if ! command -v paru >/dev/null 2>&1; then
  echo "==> [2/6] Đang cài đặt paru (AUR helper)..."
  sudo pacman -S --needed --noconfirm base-devel git
  tmp_paru="$(mktemp -d)"
  git clone https://aur.archlinux.org/paru.git "$tmp_paru/paru"
  (cd "$tmp_paru/paru" && makepkg -si --noconfirm)
  rm -rf "$tmp_paru"
fi

if [ -f "$SYS_DIR/aurlist.txt" ] && [ -s "$SYS_DIR/aurlist.txt" ]; then
  echo "==> [2/6] Cài đặt các gói AUR từ aurlist.txt..."
  paru -S --needed --noconfirm - < "$SYS_DIR/aurlist.txt"
fi

# 3. Triển khai dotfiles bằng GNU Stow
echo "==> [3/6] Liên kết dotfiles vào $HOME bằng GNU Stow..."
mkdir -p "$HOME/.config"
for pkg in "${STOW_PKGS[@]}"; do
  if [ -d "$DOTFILES_DIR/$pkg" ]; then
    echo "  -> stow $pkg"
    stow --restow --adopt -d "$DOTFILES_DIR" -t "$HOME" "$pkg"
  fi
done
git -C "$DOTFILES_DIR" checkout -- . 2>/dev/null || true

# 4. Khôi phục các file cấu hình hệ thống trong /etc (tự thích ứng phần cứng)
if [ -d "$ETC_DIR" ]; then
  echo "==> [4/6] Khôi phục các file tinh chỉnh hệ thống trong /etc..."
  while IFS= read -r -d '' file; do
    rel="${file#"$ETC_DIR"/}"
    # Bỏ qua các file mẫu/tham số
    if [[ "$rel" == "fstab.template" || "$rel" == "kernel/cmdline.params" ]]; then
      continue
    fi
    target="/etc/$rel"
    echo "  -> Copy $target"
    sudo install -Dm644 "$file" "$target"
  done < <(find "$ETC_DIR" -type f -print0)

  # Tự động nhận diện GPU (amdgpu / i915) và ổ cứng NVMe cho MODULES=() trong /etc/mkinitcpio.conf
  if [ -f /etc/mkinitcpio.conf ]; then
    mods=()
    if lspci 2>/dev/null | grep -qiE "VGA.*AMD|Display.*AMD|3D.*AMD" || lsmod | grep -q "^amdgpu"; then
      mods+=("amdgpu")
    elif lspci 2>/dev/null | grep -qiE "VGA.*Intel|Display.*Intel" || lsmod | grep -q "^i915"; then
      mods+=("i915")
    fi
    if lsblk -dno NAME 2>/dev/null | grep -q "^nvme"; then
      mods+=("nvme")
    fi
    mod_str="${mods[*]}"
    echo "  -> Cấu hình MODULES=($mod_str) trong /etc/mkinitcpio.conf"
    sudo sed -i "s/^MODULES=.*/MODULES=($mod_str)/" /etc/mkinitcpio.conf
  fi

  # Tự động lấy PARTUUID và FSTYPE của phân vùng root (/) trên máy hiện tại để tạo /etc/kernel/cmdline
  if [ -f "$ETC_DIR/kernel/cmdline.params" ]; then
    root_partuuid="$(findmnt -no PARTUUID / || true)"
    root_fstype="$(findmnt -no FSTYPE / || echo ext4)"
    custom_params="$(cat "$ETC_DIR/kernel/cmdline.params")"
    if [ -n "$root_partuuid" ]; then
      echo "  -> Tạo /etc/kernel/cmdline với PARTUUID của máy hiện tại..."
      echo "root=PARTUUID=$root_partuuid rootfstype=$root_fstype $custom_params" \
        | sudo tee /etc/kernel/cmdline >/dev/null
    fi
  fi

  echo "  -> Tạo lại locale và initramfs (mkinitcpio -P)..."
  sudo locale-gen
  sudo mkinitcpio -P
fi

# 5. Tinh chỉnh hệ thống phụ & bật systemd services
echo "==> [5/6] Bật các dịch vụ hệ thống (systemd services)..."
sudo rm -f /usr/share/applications/pcmanfm-desktop-pref.desktop

if getent group seat >/dev/null 2>&1; then
  sudo usermod -aG seat "$USER" || true
fi

SYS_SERVICES=(
  auto-cpufreq.service
  earlyoom.service
  fstrim.timer
  getty@tty1.service
  iwd.service
  paccache.timer
  rtkit-daemon.service
  systemd-networkd.service
  systemd-resolved.service
  systemd-timesyncd.service
  upower.service
)
for svc in "${SYS_SERVICES[@]}"; do
  sudo systemctl enable "$svc" 2>/dev/null || true
done

USER_SERVICES=(
  p11-kit-server.socket
  pipewire-pulse.socket
  pipewire.socket
  wireplumber.service
)
for usvc in "${USER_SERVICES[@]}"; do
  systemctl --user enable "$usvc" 2>/dev/null || true
done

# 6. Cài đặt Fisher & plugin cho Fish shell
if command -v fish >/dev/null 2>&1; then
  echo "==> [6/6] Cài đặt Fisher & plugins cho Fish shell..."
  fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher update' || true
fi

echo "=========================================================="
echo "  HOÀN TẤT! Khởi động lại máy (sudo reboot) để áp dụng."
echo "=========================================================="
