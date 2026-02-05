#!/bin/bash
#
# NVIDIA GPU Fix Script for openSUSE Tumbleweed
# Installs open-source signed NVIDIA drivers with hybrid graphics support
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

Print_Status()
{
	echo -e "${GREEN}[+]${NC} $1"
}

Print_Warning()
{
	echo -e "${YELLOW}[!]${NC} $1"
}

Print_Error()
{
	echo -e "${RED}[-]${NC} $1"
}

Check_Root()
{
	if [[ $EUID -ne 0 ]]; then
		Print_Error "This script requires root privileges."
		Print_Warning "Run with: sudo $0"
		exit 1
	fi
}

Detect_GPU()
{
	Print_Status "Detecting NVIDIA GPU..."

	GPU_Info=$(lspci | grep -i nvidia || true)

	if [[ -z "$GPU_Info" ]]; then
		Print_Error "No NVIDIA GPU detected."
		exit 1
	fi

	echo "  $GPU_Info"
	echo ""
}

Detect_Driver_Series()
{
	# Determine driver series based on GPU generation
	# G07: RTX 50xx (Blackwell+)
	# G06: GTX 10xx, 16xx, RTX 20xx/30xx/40xx (Turing+)
	# G05: GTX 600-900 series (Kepler/Maxwell)
	if echo "$GPU_Info" | grep -qiE 'RTX 5[0-9]{3}'; then
		Driver_Series="G07"
	elif echo "$GPU_Info" | grep -qiE 'RTX|GTX 1[0-9]{3}|GTX 16[0-9]{2}'; then
		Driver_Series="G06"
	else
		Print_Warning "Could not auto-detect driver series from GPU info."
		echo ""
		echo "  G07 - Newest GPUs (RTX 50xx)"
		echo "  G06 - Modern GPUs (GTX 10xx, 16xx, RTX 20xx/30xx/40xx)"
		echo "  G05 - Older GPUs (GTX 600-900 series)"
		echo ""
		read -p "Which driver series? (G07/G06/G05): " Driver_Series
		Driver_Series="${Driver_Series:-G06}"
	fi

	Print_Status "Using driver series: $Driver_Series"
}

Check_Secure_Boot()
{
	if command -v mokutil &>/dev/null; then
		SB_State=$(mokutil --sb-state 2>/dev/null || true)
		if echo "$SB_State" | grep -qi "enabled"; then
			Print_Status "Secure Boot is ENABLED."
			Print_Status "Using signed open-source NVIDIA drivers (compatible with Secure Boot)."
			echo ""
		fi
	fi
}

Add_NVIDIA_Repo()
{
	Print_Status "Checking NVIDIA repository..."

	if zypper lr -u 2>/dev/null | grep -q "download.nvidia.com"; then
		Print_Warning "NVIDIA repository already added."
	else
		zypper addrepo --refresh \
			https://download.nvidia.com/opensuse/tumbleweed \
			NVIDIA
		Print_Status "NVIDIA repository added."
	fi

	zypper ref
}

Install_Driver()
{
	Print_Status "Installing NVIDIA open driver ($Driver_Series)..."

	# Kernel module (from Oss repo)
	local Kmp_Pkg="nvidia-open-driver-${Driver_Series}-signed-kmp-default"

	if rpm -q "$Kmp_Pkg" &>/dev/null; then
		Print_Warning "$Kmp_Pkg already installed."
	else
		zypper install -y "$Kmp_Pkg"
		Print_Status "Kernel module installed."
	fi

	# Userspace packages (from NVIDIA repo)
	local Video_Pkg="nvidia-video-${Driver_Series}"
	local Compute_Pkg="nvidia-compute-utils-${Driver_Series}"

	for Pkg in "$Video_Pkg" "$Compute_Pkg" nvidia-settings; do
		if rpm -q "$Pkg" &>/dev/null; then
			Print_Warning "$Pkg already installed."
		else
			zypper install -y "$Pkg"
			Print_Status "$Pkg installed."
		fi
	done
}

Blacklist_Nouveau()
{
	Print_Status "Checking nouveau blacklist..."

	# Modprobe blacklist
	local Modprobe_Conf="/etc/modprobe.d/50-nvidia-default.conf"
	if [[ -f "$Modprobe_Conf" ]] && grep -q "blacklist nouveau" "$Modprobe_Conf"; then
		Print_Warning "Nouveau already blacklisted in modprobe."
	else
		echo "blacklist nouveau" > "$Modprobe_Conf"
		Print_Status "Nouveau blacklisted in modprobe."
	fi

	# Dracut omit to prevent nouveau from being included in the initrd
	local Dracut_Conf="/etc/dracut.conf.d/50-nvidia.conf"
	if [[ -f "$Dracut_Conf" ]] && grep -q 'omit_drivers.*nouveau' "$Dracut_Conf"; then
		Print_Warning "Nouveau already omitted from dracut."
	else
		echo 'omit_drivers+=" nouveau "' > "$Dracut_Conf"
		Print_Status "Nouveau omitted from dracut."
	fi
}

Setup_Hybrid_Graphics()
{
	echo ""
	read -p "Is this a laptop with hybrid graphics (Intel/AMD + NVIDIA)? (y/N): " Is_Hybrid

	if [[ "$Is_Hybrid" =~ ^[Yy]$ ]]; then
		Print_Status "Installing PRIME support..."

		if rpm -q suse-prime &>/dev/null; then
			Print_Warning "suse-prime already installed."
		else
			zypper install -y suse-prime
			Print_Status "suse-prime installed."
		fi

		echo ""
		Print_Status "Use 'sudo prime-select nvidia' or 'sudo prime-select intel' to switch GPUs."
	fi
}

Rebuild_Initrd()
{
	Print_Status "Rebuilding initrd..."
	dracut -f
	Print_Status "Initrd rebuilt."

	# On BLS systems, also rebuild the EFI initrd
	if rpm -q grub2-x86_64-efi-bls &>/dev/null; then
		local KVER
		KVER=$(uname -r)
		local Vmlinuz="/usr/lib/modules/${KVER}/vmlinuz"

		if [[ -f "$Vmlinuz" ]]; then
			Print_Status "BLS detected. Rebuilding EFI initrd..."
			kernel-install add "${KVER}" "$Vmlinuz"
			Print_Status "EFI initrd rebuilt."
		fi
	fi
}

Verify_Installation()
{
	Print_Status "Verifying installation..."

	echo ""
	echo "Installed NVIDIA packages:"
	rpm -qa | grep -i nvidia | sort || echo "  None found"

	echo ""
	echo "Nouveau blacklist:"
	if [[ -f /etc/modprobe.d/50-nvidia-default.conf ]]; then
		echo "  Active"
	else
		echo "  Missing"
	fi

	echo ""
}

Main()
{
	echo "========================================"
	echo " NVIDIA Fix Script for openSUSE Tumbleweed"
	echo "========================================"
	echo ""

	Check_Root
	Detect_GPU
	Detect_Driver_Series
	Check_Secure_Boot
	Add_NVIDIA_Repo
	Install_Driver
	Blacklist_Nouveau
	Setup_Hybrid_Graphics
	Rebuild_Initrd

	echo ""
	Verify_Installation

	Print_Status "Setup complete! Reboot to load the NVIDIA driver."
	echo ""
}

Main "$@"
