#!/bin/bash
# ============================================================
# Arch Linux Auto Installer
# ============================================================
# ------------------------------------------------------------
# WIFI (LIVECD MANUAL USE)
# ------------------------------------------------------------
# iwctl
#   device list
#   station wlan0 scan
#   station wlan0 get-networks
#   station wlan0 connect "SSID"
#   exit
# ------------------------------------------------------------
# Setup (LIVECD MANUAL USE)
# ------------------------------------------------------------
# pacman -Sy --noconfirm git
# git clone https://github.com/acc-holo-dev/arch.git
# После установки системы к Wi‑Fi можно подключиться так:
#   nmcli device wifi list
#   nmcli device wifi connect "SSID" password "PASSWORD"
# cd arch
# chmod +x install.sh
# ./install.sh
# ------------------------------------------------------------

set -e

BLUE="\033[34m"
GREEN="\033[32m"
RED="\033[31m"
NC="\033[0m"

msg() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()  { echo -e "${GREEN}[OK]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

# ------------------------------------------------------------
# CHECK UEFI
# ------------------------------------------------------------
msg "Checking for UEFI..."
if [[ ! -d /sys/firmware/efi ]]; then
    err "System is not booted in UEFI mode. This script requires UEFI."
    exit 1
fi
ok "UEFI detected."

# ------------------------------------------------------------
# CHECK INTERNET
# ------------------------------------------------------------
msg "Checking internet connectivity..."
if ping -c 2 archlinux.org >/dev/null 2>&1; then
    ok "Internet connection is active."
else
    err "Internet connection is down. Connect Wi-Fi manually and rerun the script."
    exit 1
fi

# ------------------------------------------------------------
# SELECT DISK
# ------------------------------------------------------------
msg "Select the target disk for installation:"
lsblk -dpno NAME,SIZE,TYPE | grep "disk"
echo
read -rp "Enter disk (e.g. nvme0n1 or /dev/nvme0n1): " DISK

# normalize to /dev/...
if [[ "$DISK" != /dev/* ]]; then
    DISK="/dev/$DISK"
fi

if [ ! -b "$DISK" ]; then
    err "Disk $DISK not found."
    exit 1
fi

DISK_TYPE=$(lsblk -dn -o TYPE "$DISK")
if [[ "$DISK_TYPE" != "disk" ]]; then
    err "$DISK is not a whole disk (TYPE=$DISK_TYPE). Please specify a disk, not a partition."
    exit 1
fi

msg "WARNING: ALL DATA ON $DISK WILL BE ERASED!"
read -rp "Press Enter to confirm or Ctrl+C to cancel..."

# ------------------------------------------------------------
# MAKE PARTITIONS (GPT, EFI + ROOT)
# ------------------------------------------------------------
msg "Creating GPT partition table..."
sgdisk --zap-all "$DISK"
sgdisk --clear \
    --new=1:0:+512M --typecode=1:ef00 --change-name=1:"EFI" \
    --new=2:0:0     --typecode=2:8300 --change-name=2:"ROOT" \
    "$DISK"

if [[ "$DISK" == *"nvme"* || "$DISK" == *"mmcblk"* ]]; then
    EFI="${DISK}p1"
    ROOT="${DISK}p2"
else
    EFI="${DISK}1"
    ROOT="${DISK}2"
fi

msg "Formatting partitions..."
mkfs.fat -F32 -n EFI "$EFI"
mkfs.ext4 -L ROOT "$ROOT"

msg "Mounting root filesystem..."
mount "$ROOT" /mnt
mkdir -p /mnt/boot
mount "$EFI" /mnt/boot

# ------------------------------------------------------------
# CREATE SWAPFILE (20GB)
# ------------------------------------------------------------
msg "Creating 20GB swapfile..."
dd if=/dev/zero of=/mnt/swapfile bs=1M count=20000 status=progress
chmod 600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile

# ------------------------------------------------------------
# INSTALL BASE SYSTEM (linux-zen)
# ------------------------------------------------------------
msg "Installing base system (linux-zen)..."
pacstrap /mnt \
    base linux-zen linux-zen-headers linux-firmware base-devel \
    networkmanager nano amd-ucode intel-ucode efibootmgr git sudo \
    man-db man-pages xdg-user-dirs xdg-utils pacman-contrib

# ------------------------------------------------------------
# FSTAB
# ------------------------------------------------------------
msg "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab

# ------------------------------------------------------------
# CREATE CHROOT INSTALLER
# ------------------------------------------------------------
msg "Creating chroot setup script..."

cat > /mnt/root/chroot-setup.sh << 'EOF'
#!/bin/bash
set -e

BLUE="\033[34m"; GREEN="\033[32m"; RED="\033[31m"; NC="\033[0m"
msg(){ echo -e "${BLUE}[INFO]${NC} $1"; }
ok(){ echo -e "${GREEN}[OK]${NC} $1"; }
err(){ echo -e "${RED}[ERROR]${NC} $1"; }

# ------------------------------------------------------------
# TIMEZONE & LOCALE
# ------------------------------------------------------------
msg "Configuring timezone..."
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

msg "Configuring locale..."
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/#ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf

msg "Setting hostname..."
echo "arch" > /etc/hostname
cat > /etc/hosts << EOFS
127.0.0.1   localhost
::1         localhost
127.0.1.1   arch.localdomain arch
EOFS

# ------------------------------------------------------------
# USER
# ------------------------------------------------------------
msg "Creating user..."
read -p "Enter username: " USERNAME
useradd -m -G wheel,video,audio,storage,input -s /bin/bash "$USERNAME"

echo "Enter root password:"
passwd
echo "Enter password for user $USERNAME:"
passwd "$USERNAME"

echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# Автовход в tty1 для созданного пользователя
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << EOFS
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USERNAME --noclear --keep-baud 115200,38400,9600 %I linux
Type=simple
EOFS
systemctl enable getty@tty1

# ------------------------------------------------------------
# PACMAN TWEAKS
# ------------------------------------------------------------
msg "Tweaking pacman..."
sed -i 's/#Color/Color/' /etc/pacman.conf
sed -i 's/#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf

# ------------------------------------------------------------
# NETWORK
# ------------------------------------------------------------
msg "Enabling NetworkManager..."
systemctl enable NetworkManager

# ------------------------------------------------------------
# BOOTLOADER: SYSTEMD-BOOT (linux-zen)
# ------------------------------------------------------------
msg "Installing systemd-boot..."
bootctl install

msg "Configuring bootloader..."
cat > /boot/loader/loader.conf << EOFL
default arch.conf
timeout 3
console-mode max
editor no
EOFL

msg "Detecting root partition UUID..."
ROOT_DEV=$(findmnt -no SOURCE /)
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_DEV")

if [ -z "$ROOT_UUID" ]; then
    err "Failed to detect root partition UUID."
    exit 1
fi

cat > /boot/loader/entries/arch.conf << EOFL
title Arch Linux (linux-zen)
linux /vmlinuz-linux-zen
initrd /amd-ucode.img
initrd /intel-ucode.img
initrd /initramfs-linux-zen.img
options root=UUID=$ROOT_UUID rw quiet splash amd_pstate=active
EOFL

# ------------------------------------------------------------
# GPU DRIVERS + WAYLAND/HYPRLAND STACK (AMD/Radeon focused)
# ------------------------------------------------------------
msg "Installing GPU drivers and Wayland stack for AMD/Radeon..."
pacman -S --noconfirm \
    mesa vulkan-radeon mesa-utils \
    pipewire pipewire-alsa pipewire-pulse wireplumber \
    hyprland waybar rofi-wayland kitty \
    swaybg swaylock \
    xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    mako wl-clipboard grim slurp brightnessctl \
    polkit-gnome bluez bluez-utils fwupd

systemctl enable bluetooth
systemctl enable --now fwupd.service

# ------------------------------------------------------------
# HYPRLAND CONFIG (MEDIUM)
# ------------------------------------------------------------
msg "Creating Hyprland config..."
mkdir -p /home/$USERNAME/.config/hypr
cat > /home/$USERNAME/.config/hypr/hyprland.conf << 'EOFL'
# Wayland & toolkits ENV
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = GTK_USE_PORTAL,1
env = QT_QPA_PLATFORM,wayland
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = MOZ_ENABLE_WAYLAND,1
env = XDG_SESSION_DESKTOP,Hyprland

# Стабильное окружение по рекомендациям Archinstall/Hyprland
exec-once = dbus-update-activation-environment --systemd --all
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP
exec-once = systemctl --user start pipewire pipewire-pulse wireplumber

env = SDL_VIDEODRIVER,wayland
env = CLUTTER_BACKEND,wayland

monitor=,preferred,auto,1

input {
    kb_layout = us,ru
    kb_options = grp:alt_shift_toggle
    follow_mouse = 1
    accel_profile = flat
    sensitivity = 0
}

general {
    gaps_in = 5
    gaps_out = 8
    border_size = 2
    layout = dwindle
}

decoration {
    rounding = 8
    blur = no
    drop_shadow = no
}

exec-once = waybar
exec-once = mako
exec-once = swaybg -c "#1e1e2e"
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

$mainMod = SUPER

# Запуск терминала
bind = $mainMod, RETURN, exec, kitty
# Меню приложений (drun)
bind = $mainMod, D, exec, rofi -show drun
# Завершить активное окно
bind = $mainMod, Q, killactive
# Переключить плавающее окно
bind = $mainMod, F, togglefloating
# Меню команд (run)
bind = $mainMod, R, exec, rofi -show run
# Псевдоплитка (split/pseudo)
bind = $mainMod, P, pseudo
# Выход из сессии Hyprland
bind = $mainMod, M, exit

# Переключение рабочих столов
bind = $mainMod, 1, workspace,1
bind = $mainMod, 2, workspace,2
bind = $mainMod, 3, workspace,3
bind = $mainMod, 4, workspace,4
bind = $mainMod, 5, workspace,5
bind = $mainMod, 6, workspace,6
bind = $mainMod, 7, workspace,7
bind = $mainMod, 8, workspace,8
bind = $mainMod, 9, workspace,9
bind = $mainMod, 0, workspace,10

# Блокировка экрана
bind = SUPER, L, exec, swaylock --color 1e1e2e
EOFL

chown -R "$USERNAME:$USERNAME" /home/$USERNAME/.config

# ------------------------------------------------------------
# AUR + UTILS
# ------------------------------------------------------------
msg "Installing yay (AUR helper) and Google Chrome из pacman..."
pacman -S --noconfirm --needed git base-devel google-chrome

sudo -u "$USERNAME" bash << 'EOSU'
cd "$HOME"
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
EOSU

# ------------------------------------------------------------
# JOURNALD + PACMAN CACHE
# ------------------------------------------------------------
msg "Limiting journald size..."
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/size.conf << EOFL
[Journal]
SystemMaxUse=64M
EOFL

msg "Enabling pacman cache cleanup timer..."
systemctl enable paccache.timer

ok "Chroot configuration complete."
EOF

chmod +x /mnt/root/chroot-setup.sh

# ------------------------------------------------------------
# RUN CHROOT
# ------------------------------------------------------------
msg "Running chroot setup script..."
arch-chroot /mnt /root/chroot-setup.sh

# ------------------------------------------------------------
# FINISH
# ------------------------------------------------------------
msg "Unmounting target filesystems..."
umount -R /mnt || true

ok "Installation complete! Type 'reboot' to restart."
echo "After reboot, log in normally and start Hyprland manually with 'Hyprland'."
