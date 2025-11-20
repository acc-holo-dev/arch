#!/usr/bin/env bash
# Центральная конфигурация пакетов и настроек установщика.

# Общие параметры
INSTALL_ROOT="${INSTALL_ROOT:-/mnt}"
TARGET_DISK="${TARGET_DISK:-/dev/sda}"
DEFAULT_USER="${DEFAULT_USER:-archuser}"
HOSTNAME="${HOSTNAME:-arch-host}"
ENABLE_DESKTOP=${ENABLE_DESKTOP:-1}
ENABLE_HYPRLAND=${ENABLE_HYPRLAND:-1}
ENABLE_DEVTOOLS=${ENABLE_DEVTOOLS:-1}
ENABLE_FONTS=${ENABLE_FONTS:-1}
ENABLE_GAMING=${ENABLE_GAMING:-0}
ENABLE_VIRTUALIZATION=${ENABLE_VIRTUALIZATION:-1}

# Базовые пакеты системы (pacstrap). Минимум для чистого Arch + Hyprland.
PACMAN_BASE=(
  base linux linux-firmware sudo networkmanager seatd
  git base-devel
)

# Пользовательские пакеты (pacman)
PACMAN_DESKTOP=(
  pipewire wireplumber pipewire-alsa pipewire-pulse pipewire-jack
  xdg-desktop-portal xdg-desktop-portal-wlr xdg-user-dirs
)
PACMAN_HYPRLAND=(
  hyprland hyprpaper waybar alacritty
  grim slurp wl-clipboard wofi
)
PACMAN_DEVTOOLS=(man-db man-pages)
PACMAN_FONTS=(noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu)
PACMAN_GAMING=(steam gamemode mangohud)
PACMAN_UTILS=(firefox htop unzip curl wget)

# Пакеты AUR (устанавливаются через yay)
AUR_PACKAGES=()
AUR_AMD_GPU=()
AUR_INTEL_GPU=()
AUR_NVIDIA_GPU=(nvidia-vaapi-driver)

# Системные сервисы для включения
SYSTEM_SERVICES=(
  NetworkManager.service
  systemd-timesyncd.service
  seatd.service
)
