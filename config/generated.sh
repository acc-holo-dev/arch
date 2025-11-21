INSTALL_ROOT="/mnt"
TARGET_DISK="/dev/sda"
DEFAULT_USER="archuser"
HOSTNAME="arch-host"
DEFAULT_PROFILE="desktop"
PACMAN_GROUP_BASE=(base linux linux-firmware sudo networkmanager seatd git base-devel)
PACMAN_GROUP_DESKTOP=(pipewire wireplumber pipewire-alsa pipewire-pulse pipewire-jack xdg-desktop-portal xdg-desktop-portal-wlr xdg-user-dirs)
PACMAN_GROUP_HYPRLAND=(hyprland hyprpaper waybar alacritty grim slurp wl-clipboard wofi)
PACMAN_GROUP_DEVTOOLS=(man-db man-pages)
PACMAN_GROUP_FONTS=(noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu)
PACMAN_GROUP_GAMING=(steam gamemode mangohud)
PACMAN_GROUP_UTILS=(firefox htop unzip curl wget)
AUR_GROUP_DEFAULT=()
AUR_GROUP_AMD_GPU=()
AUR_GROUP_INTEL_GPU=()
AUR_GROUP_NVIDIA_GPU=(nvidia-vaapi-driver)
SYSTEM_SERVICES=(NetworkManager.service systemd-timesyncd.service seatd.service)
PROFILE_DESKTOP_PACMAN_GROUPS=(base desktop hyprland devtools fonts utils)
PROFILE_DESKTOP_AUR_GROUPS=(default)
PROFILE_DESKTOP_FLAGS=(ENABLE_DESKTOP=1 ENABLE_HYPRLAND=1 ENABLE_DEVTOOLS=1 ENABLE_FONTS=1 ENABLE_GAMING=0 ENABLE_VIRTUALIZATION=1)
PROFILE_MINIMAL_PACMAN_GROUPS=(base devtools fonts utils)
PROFILE_MINIMAL_AUR_GROUPS=(default)
PROFILE_MINIMAL_FLAGS=(ENABLE_DESKTOP=0 ENABLE_HYPRLAND=0 ENABLE_DEVTOOLS=1 ENABLE_FONTS=1 ENABLE_GAMING=0 ENABLE_VIRTUALIZATION=1)
