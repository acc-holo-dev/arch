#!/usr/bin/env bash
# Hardware detection helpers

set -euo pipefail

: "${INSTALL_GPU:=unknown}"
: "${INSTALL_CPU:=unknown}"
: "${INSTALL_VIRT:=unknown}"

_detect_from_lspci() {
  local pattern="$1"
  if command -v lspci >/dev/null 2>&1; then
    lspci | grep -iE "${pattern}" | head -n1 || true
  fi
}

detect_cpu() {
  if command -v lscpu >/dev/null 2>&1; then
    INSTALL_CPU="$(lscpu | awk -F: '/Vendor ID/ {gsub(/ /, "", $2); print tolower($2)}')"
    case "${INSTALL_CPU}" in
      genuineintel) INSTALL_CPU="intel" ;;
      authentica* | amd*) INSTALL_CPU="amd" ;;
      *) INSTALL_CPU="unknown" ;;
    esac
  else
    INSTALL_CPU="$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print tolower($3)}' || true)"
    [[ -z "${INSTALL_CPU}" ]] && INSTALL_CPU="unknown"
  fi
  log_info "Detected CPU vendor: ${INSTALL_CPU}"
}

detect_gpu() {
  local line
  line="$(_detect_from_lspci 'vga|3d')"
  case "${line,,}" in
    *nvidia*) INSTALL_GPU="nvidia" ;;
    *amd*) INSTALL_GPU="amd" ;;
    *intel*) INSTALL_GPU="intel" ;;
    *) INSTALL_GPU="unknown" ;;
  esac
  log_info "Detected GPU vendor: ${INSTALL_GPU}" "${line:+(${line})}"
}

detect_virtualization() {
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    INSTALL_VIRT="$(systemd-detect-virt || echo none)"
  else
    INSTALL_VIRT="$(grep -m1 'hypervisor' /proc/cpuinfo >/dev/null && echo "generic" || echo "none")"
  fi
  log_info "Virtualization: ${INSTALL_VIRT}"
}

hw_gpu_packages() {
  local -n _out=$1
  _out=()
  case "${INSTALL_VIRT}" in
    kvm|qemu) _out+=(qemu-guest-agent spice-vdagent); return ;;
    vmware) _out+=(open-vm-tools xf86-video-vmware xf86-input-vmmouse); return ;;
    oracle) _out+=(virtualbox-guest-utils); return ;;
  esac
  case "${INSTALL_GPU}" in
    amd) _out+=(mesa xf86-video-amdgpu vulkan-radeon) ;;
    intel) _out+=(mesa xf86-video-intel vulkan-intel) ;;
    nvidia) _out+=(nvidia nvidia-utils nvidia-settings) ;;
    *) _out+=() ;;
  esac
}

hw_aur_gpu_packages() {
  local -n _out=$1
  _out=()
  case "${INSTALL_GPU}" in
    amd) [[ ${#AUR_AMD_GPU[@]:-0} -gt 0 ]] && _out+=("${AUR_AMD_GPU[@]}") ;;
    intel) [[ ${#AUR_INTEL_GPU[@]:-0} -gt 0 ]] && _out+=("${AUR_INTEL_GPU[@]}") ;;
    nvidia) [[ ${#AUR_NVIDIA_GPU[@]:-0} -gt 0 ]] && _out+=("${AUR_NVIDIA_GPU[@]}") ;;
  esac
}

hw_microcode_package() {
  case "${INSTALL_CPU}" in
    amd) echo "amd-ucode" ;;
    intel) echo "intel-ucode" ;;
  esac
}
