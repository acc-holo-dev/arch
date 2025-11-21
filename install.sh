#!/usr/bin/env bash
# Full Arch Linux installer (single-file)
# All configuration lives here. Script is intended to run from Arch ISO.

# --- User and host ------------------------------------------------------------
HOSTNAME="archbox"
USERNAME="alice"
# Passwords, hostname, and username are requested interactively during install.

# --- Locale and keymap --------------------------------------------------------
TIMEZONE="Europe/Moscow"
LOCALES=("ru_RU.UTF-8" "en_US.UTF-8")
DEFAULT_LANG="ru_RU.UTF-8"
VCONSOLE_KEYMAP="us"               # primary console layout (English first)
ALT_KEYMAP="ru"                    # secondary console layout

# --- Pacman mirrors & tuning --------------------------------------------------
MIRROR_COUNTRIES=("Germany" "Netherlands" "Finland")
PACMAN_PARALLEL_DOWNLOADS=10

# --- Package sets -------------------------------------------------------------
PACMAN_SYSTEM_PACKAGES=(
  base base-devel linux linux-headers linux-firmware
  networkmanager openssh sudo git vim man-db man-pages bash-completion
  pipewire pipewire-pulse wireplumber alsa-utils
  grub efibootmgr mtools dosfstools
  pacman-contrib reflector rsync
  sof-firmware lsb-release
)

PACMAN_ENV_PACKAGES=(
  hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
  waybar rofi-wayland kitty wlogout mako
  swaybg swayidle swaylock
  wl-clipboard grim slurp wf-recorder
  brightnessctl playerctl pavucontrol network-manager-applet
  bluez bluez-utils power-profiles-daemon upower
  zram-generator seatd
)

PACMAN_APP_PACKAGES=(
  firefox code fastfetch btop
)

AUR_PACKAGES=(
  google-chrome auto-cpufreq ttf-jetbrains-mono-nerd
)

# --- Services to enable -------------------------------------------------------
SYSTEM_SERVICES=(
  NetworkManager.service
  sshd.service
  bluetooth.service
  power-profiles-daemon.service
  fstrim.timer
  seatd.service
)

# --- Behavior flags -----------------------------------------------------------
ENABLE_AUR=true
DRY_RUN=false

# --- Internal settings --------------------------------------------------------
set -o errexit
set -o nounset
set -o pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

info()    { echo -e "${BLUE}INFO${RESET}  - $*"; }
success() { echo -e "${GREEN}OK${RESET}    - $*"; }
warn()    { echo -e "${YELLOW}WARN${RESET}  - $*"; }
error()   { echo -e "${RED}ERROR${RESET} - $*"; }

run_step() {
  local description=$1
  shift
  local cmd=("$@")
  info "$description"
  if [[ ${DRY_RUN} == true ]]; then
    warn "DRY RUN -> ${cmd[*]}"
    return 0
  fi

  set +e
  "${cmd[@]}"
  local status=$?
  set -e

  if [[ ${status} -eq 0 ]]; then
    success "$description"
  else
    error "$description (exit ${status})"
    return ${status}
  fi
}

prompt_value() {
  local label=$1
  local default=$2
  local value
  read -rp "Enter ${label} [${default}]: " value
  if [[ -z "$value" ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    error "Run the script as root"
    exit 1
  fi
}

parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --dry-run) DRY_RUN=true ;;
      *) error "Unknown argument: $arg"; exit 1 ;;
    esac
  done
}

prompt_password() {
  local prompt_label=$1
  local pass1 pass2
  while true; do
    read -rsp "Enter password for ${prompt_label}: " pass1; echo
    read -rsp "Re-enter password for ${prompt_label}: " pass2; echo
    if [[ -z "$pass1" ]]; then
      warn "Password cannot be empty"
      continue
    fi
    if [[ "$pass1" == "$pass2" ]]; then
      echo "$pass1"
      return 0
    fi
    warn "Passwords do not match, try again"
  done
}

choose_disk() {
  local disk
  while true; do
    info "Available disks:" >&2
    local disks_output
    disks_output=$(lsblk -dpno NAME,SIZE,TYPE | grep "disk" || true)

    if [[ -z "$disks_output" ]]; then
      warn "No disks detected, please check the connection" >&2
      read -rp "Rescan for disks? (yes/NO): " rescan
      if [[ "$rescan" != "yes" ]]; then
        warn "Connect a disk and try again" >&2
      fi
      continue
    fi

    echo "$disks_output" >&2
    read -rp "Enter target disk (e.g., /dev/sda): " disk
    if [[ -b "$disk" ]]; then
      read -rp "All data on ${disk} will be wiped. Continue? (yes/NO): " confirm
      if [[ "$confirm" == "yes" ]]; then
        echo "$disk"
        return 0
      else
        warn "Disk selection cancelled"
      fi
    else
      warn "${disk} is not a block device"
    fi
  done
}

preflight() {
  run_step "Check root privileges" true
  run_step "Check pacman availability" pacman -V >/dev/null
  run_step "Check network connectivity" ping -c1 -W2 archlinux.org >/dev/null
}

configure_mirrors() {
  if ! command -v reflector >/dev/null 2>&1; then
    run_step "Install reflector on live system" pacman -Sy --noconfirm reflector
  fi
  local countries_csv
  countries_csv=$(IFS=","; echo "${MIRROR_COUNTRIES[*]}")
  run_step "Refresh pacman mirrors" reflector --country "$countries_csv" --age 24 --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
}

detect_cpu_microcode() {
  local vendor
  vendor=$(lscpu | awk -F: '/Vendor ID/ {gsub(/^[ \t]+/,"",$2); print $2}')
  case "$vendor" in
    GenuineIntel) echo "intel-ucode" ;;
    AuthenticAMD) echo "amd-ucode" ;;
    *) echo "intel-ucode" ;;
  esac
}

prepare_package_list() {
  local microcode
  microcode=$(detect_cpu_microcode)
  local vendor
  vendor=$(lscpu | awk -F: '/Vendor ID/ {gsub(/^[ \t]+/,"",$2); print $2}')
  local cpu_extras=()
  case "$vendor" in
    GenuineIntel)
      cpu_extras=(thermald)
      SYSTEM_SERVICES+=(thermald.service)
      ;;
    *) ;;
  esac
  info "System packages: ${PACMAN_SYSTEM_PACKAGES[*]}"
  info "Desktop packages: ${PACMAN_ENV_PACKAGES[*]}"
  info "App packages: ${PACMAN_APP_PACKAGES[*]}"
  ALL_PACMAN_PACKAGES=(
    "${PACMAN_SYSTEM_PACKAGES[@]}"
    "${PACMAN_ENV_PACKAGES[@]}"
    "${PACMAN_APP_PACKAGES[@]}"
    "$microcode"
    "${cpu_extras[@]}"
  )
  info "Resolved CPU microcode package: ${microcode}"
}

partition_disk() {
  local disk=$1
  run_step "Wipe partition table" sgdisk --zap-all "$disk"
  run_step "Create new GPT" sgdisk -og "$disk"
  run_step "Create EFI partition" sgdisk -n1:0:+512M -t1:ef00 -c1:EFI "$disk"
  run_step "Create ROOT partition" sgdisk -n2:0:0 -t2:8300 -c2:ROOT "$disk"
  run_step "Reload partition table" partprobe "$disk"
}

format_partitions() {
  local disk=$1
  local esp="${disk}1"
  local rootp="${disk}2"
  run_step "Format EFI (FAT32)" mkfs.fat -F32 "$esp"
  run_step "Format ROOT (ext4)" mkfs.ext4 -F "$rootp"
}

mount_partitions() {
  local disk=$1
  local esp="${disk}1"
  local rootp="${disk}2"
  run_step "Mount root" mount "$rootp" /mnt
  run_step "Create /mnt/boot" mkdir -p /mnt/boot
  run_step "Mount EFI" mount "$esp" /mnt/boot
}

tune_pacman_conf() {
  local conf=/mnt/etc/pacman.conf
  run_step "Enable pacman Color & VerbosePkgLists" sed -i 's/^#Color/Color/; s/^#VerbosePkgLists/VerbosePkgLists/' "$conf"
  run_step "Set ParallelDownloads=${PACMAN_PARALLEL_DOWNLOADS}" sed -i "s/^#ParallelDownloads.*/ParallelDownloads = ${PACMAN_PARALLEL_DOWNLOADS}/" "$conf"
  run_step "Keep sync info longer" sed -i 's/^#\?CheckSpace/CheckSpace/' "$conf"
}

configure_makepkg() {
  chroot_run "Disable debug/strip for makepkg" bash -c "sed -i.bak '/^OPTIONS=/s/strip/!strip/; /^OPTIONS=/s/debug/!debug/' /etc/makepkg.conf"
}

configure_zram() {
  chroot_run "Configure zram" bash -c "cat > /etc/systemd/zram-generator.conf <<'EOT'\n[zram0]\ncompression=zstd\nzram-size=ram/2\nEOT"
}

bootstrap_system() {
  run_step "Install base system and packages" pacstrap /mnt "${ALL_PACMAN_PACKAGES[@]}"
  run_step "Copy mirrorlist to target" cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
  run_step "Generate fstab" bash -c "genfstab -U /mnt >> /mnt/etc/fstab"
}

chroot_run() {
  local description=$1
  shift
  local cmd=("$@")
  run_step "$description" arch-chroot /mnt "${cmd[@]}"
}

configure_inside_chroot() {
  local user_pass=$1
  local root_pass=$2

  configure_time_locale
  configure_host
  configure_user
  configure_passwords "$user_pass" "$root_pass"
  configure_makepkg
  configure_zram
  enable_services
  install_bootloader
  setup_aur
}

configure_time_locale() {
  chroot_run "Set timezone" ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
  chroot_run "Sync hardware clock" hwclock --systohc

  for loc in "${LOCALES[@]}"; do
    chroot_run "Enable locale ${loc}" sed -i "s/^#${loc}/${loc}/" /etc/locale.gen
  done
  chroot_run "Generate locales" locale-gen
  chroot_run "Write locale.conf" bash -c "echo LANG=${DEFAULT_LANG} > /etc/locale.conf"
  chroot_run "Configure vconsole" bash -c "echo -e 'KEYMAP=${VCONSOLE_KEYMAP}\nFONT=cyr-sun16' > /etc/vconsole.conf"
  chroot_run "Add optional secondary keymap" bash -c "echo 'loadkeys ${ALT_KEYMAP} # secondary' > /usr/local/bin/loadkeys-secondary && chmod +x /usr/local/bin/loadkeys-secondary"
}

configure_host() {
  chroot_run "Set hostname" bash -c "echo ${HOSTNAME} > /etc/hostname"
  chroot_run "Configure hosts" bash -c "cat > /etc/hosts <<EOT\n127.0.0.1   localhost\n::1         localhost\n127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}\nEOT"
}

configure_passwords() {
  local user_pass=$1
  local root_pass=$2
  chroot_run "Set root password" bash -c "echo 'root:${root_pass}' | chpasswd"
  chroot_run "Set user password" bash -c "echo '${USERNAME}:${user_pass}' | chpasswd"
}

configure_user() {
  chroot_run "Create user ${USERNAME}" useradd -m -G wheel,video,audio,storage,input,seat -s /bin/bash "${USERNAME}"
  chroot_run "Configure sudoers" bash -c "echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel"
}

enable_services() {
  for svc in "${SYSTEM_SERVICES[@]}"; do
    chroot_run "Enable ${svc}" systemctl enable "$svc"
  done
}

install_bootloader() {
  chroot_run "Install GRUB" bash -c "grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch"
  chroot_run "Generate grub.cfg" grub-mkconfig -o /boot/grub/grub.cfg
}

setup_aur() {
  if [[ ${ENABLE_AUR} == true ]]; then
    chroot_run "Prepare yay build dir" bash -c "rm -rf /tmp/yay-build && mkdir -p /tmp/yay-build && chown ${USERNAME}:${USERNAME} /tmp/yay-build"
    chroot_run "Clone yay" sudo -u "${USERNAME}" git clone https://aur.archlinux.org/yay.git /tmp/yay-build
    chroot_run "Build yay" sudo -u "${USERNAME}" bash -c "cd /tmp/yay-build && makepkg -si --noconfirm"
    if ((${#AUR_PACKAGES[@]} > 0)); then
      chroot_run "Install AUR packages" sudo -u "${USERNAME}" yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
      chroot_run "Enable auto-cpufreq if present" bash -c "systemctl enable auto-cpufreq.service 2>/dev/null || true"
    else
      warn "AUR package list is empty"
    fi
  else
    warn "AUR disabled"
  fi
}

cleanup_and_reboot() {
  run_step "Unmount /mnt" umount -R /mnt
  run_step "Reboot" reboot
}

main() {
  parse_args "$@"
  require_root
  preflight
  configure_mirrors

  local install_disk
  install_disk=$(choose_disk)
  info "Selected disk: ${install_disk}"

  HOSTNAME=$(prompt_value "hostname" "$HOSTNAME")
  USERNAME=$(prompt_value "username" "$USERNAME")
  local USER_PASSWORD
  USER_PASSWORD=$(prompt_password "user ${USERNAME}")
  local ROOT_PASSWORD
  ROOT_PASSWORD=$(prompt_password "root")

  prepare_package_list

  partition_disk "$install_disk"
  format_partitions "$install_disk"
  mount_partitions "$install_disk"
  bootstrap_system
  tune_pacman_conf
  configure_inside_chroot "$USER_PASSWORD" "$ROOT_PASSWORD"
  cleanup_and_reboot
}

main "$@"
