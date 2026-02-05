#!/bin/bash
#
# NVIDIA GPU Fix Script for openSUSE Tumbleweed
# Installs drivers from the hardware repo with hybrid graphics support
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
	# Determine G05 vs G06 based on GPU generation
	# G06: GTX 10xx, 16xx, RTX 20xx/30xx/40xx/50xx (Turing+)
	# G05: GTX 600-900 series (Kepler/Maxwell)
	if echo "$GPU_Info" | grep -qiE 'RTX|GTX 1[0-9]{3}|GTX 16[0-9]{2}'; then
		Driver_Series="G06"
	else
		Print_Warning "Could not auto-detect driver series from GPU info."
		echo ""
		echo "  G06 - Modern GPUs (GTX 10xx, 16xx, RTX series)"
		echo "  G05 - Older GPUs (GTX 600-900 series)"
		echo ""
		read -p "Which driver series? (G06/G05): " Driver_Series
		Driver_Series="${Driver_Series:-G06}"
	fi

	Print_Status "Using driver series: $Driver_Series"
}

Check_Secure_Boot()
{
	if command -v mokutil &>/dev/null; then
		SB_State=$(mokutil --sb-state 2>/dev/null || true)
		if echo "$SB_State" | grep -qi "enabled"; then
			Print_Warning "Secure Boot is ENABLED."
			Print_Warning "NVIDIA drivers are unsigned on openSUSE and will not load."
			Print_Warning "Disable Secure Boot in BIOS/UEFI before rebooting."
			echo ""
		fi
	fi
}

Add_Hardware_Repo()
{
	Print_Status "Checking hardware repository..."

	if zypper lr -u 2>/dev/null | grep -q "download.opensuse.org/repositories/hardware"; then
		Print_Warning "Hardware repository already added, skipping."
	else
		zypper addrepo --refresh \
			https://download.opensuse.org/repositories/hardware/openSUSE_Tumbleweed/ \
			hardware
		Print_Status "Hardware repository added."
	fi

	zypper ref
}

Install_Driver()
{
	Print_Status "Installing NVIDIA driver ($Driver_Series)..."

	Packages="nvidia-driver-${Driver_Series} nvidia-gl-${Driver_Series}"

	for Pkg in $Packages; do
		if rpm -q "$Pkg" &>/dev/null; then
			Print_Warning "$Pkg already installed."
		fi
	done

	zypper install -y $Packages
	Print_Status "NVIDIA driver packages installed."
}

Blacklist_Nouveau()
{
	Print_Status "Checking nouveau blacklist..."

	Conf="/etc/modprobe.d/50-nvidia-default.conf"

	if [[ -f "$Conf" ]] && grep -q "blacklist nouveau" "$Conf"; then
		Print_Warning "Nouveau already blacklisted."
	else
		echo "blacklist nouveau" > "$Conf"
		Print_Status "Nouveau blacklisted."
	fi
}

Setup_Hybrid_Graphics()
{
	echo ""
	read -p "Is this a laptop with hybrid graphics (Intel/AMD + NVIDIA)? (y/N): " Is_Hybrid

	if [[ "$Is_Hybrid" =~ ^[Yy]$ ]]; then
		Print_Status "Installing PRIME support..."

		if rpm -q nvidia-prime &>/dev/null; then
			Print_Warning "nvidia-prime already installed."
		else
			zypper install -y nvidia-prime
			Print_Status "nvidia-prime installed."
		fi

		echo ""
		Print_Status "Run GPU-intensive apps with: prime-run <application>"
	fi
}

Rebuild_Initrd()
{
	Print_Status "Rebuilding initrd..."
	dracut -f
	Print_Status "Initrd rebuilt."
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
	Add_Hardware_Repo
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
