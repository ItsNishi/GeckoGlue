#!/bin/bash
#
# DaVinci Resolve Fix Script for openSUSE Tumbleweed
# Resolves common compatibility issues with DaVinci Resolve on Intel Arc GPUs
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

Install_Dependencies()
{
	Print_Status "Installing DaVinci Resolve dependencies..."

	zypper install -y \
		libxcb-cursor0 libxcb-damage0 libxcb-util1 \
		libxkbcommon-x11-0 libapr1 libaprutil1 libglvnd \
		libgdk_pixbuf-2_0-0 libfuse2 ocl-icd-devel \
		google-noto-sans-fonts liberation-fonts

	Print_Status "Dependencies installed."
}

Install_Intel_GPU_Stack()
{
	Print_Status "Installing Intel GPU compute stack..."

	zypper install -y \
		intel-gpu-tools libva-utils \
		intel-opencl intel-compute-runtime level-zero-loader ocl-icd-devel \
		libvulkan_intel vulkan-tools

	Print_Status "Intel GPU stack installed."
}

Fix_GLib_Mismatch()
{
	Print_Status "Fixing GLib version mismatch..."

	local Resolve_Libs="/opt/resolve/libs"
	local Disabled_Dir="$Resolve_Libs/disabled"

	if [[ ! -d "$Resolve_Libs" ]]; then
		Print_Warning "DaVinci Resolve not found at /opt/resolve. Install Resolve first."
		return 1
	fi

	mkdir -p "$Disabled_Dir"

	# Move bundled GLib libraries to disabled folder
	for Lib in libglib-2.0.so libgobject-2.0.so libgio-2.0.so; do
		if ls "$Resolve_Libs"/${Lib}* 1>/dev/null 2>&1; then
			mv "$Resolve_Libs"/${Lib}* "$Disabled_Dir/" 2>/dev/null || true
			Print_Status "Moved $Lib to disabled folder."
		fi
	done

	Print_Status "GLib fix applied. Resolve will use system libraries."
}

Setup_Permissions()
{
	Print_Status "Setting up permissions..."

	# Add user to video group
	if [[ -n "$SUDO_USER" ]]; then
		usermod -aG video "$SUDO_USER"
		Print_Status "Added $SUDO_USER to video group."
	fi

	# Copy udev rules if they exist
	if [[ -d /opt/resolve/share/etc/udev/rules.d ]]; then
		cp /opt/resolve/share/etc/udev/rules.d/*.rules /etc/udev/rules.d/ 2>/dev/null || true
		udevadm control --reload-rules
		Print_Status "udev rules installed."
	fi
}

Verify_OpenCL()
{
	Print_Status "Verifying OpenCL installation..."

	echo ""
	if command -v clinfo &>/dev/null; then
		local Platform_Count
		Platform_Count=$(clinfo 2>/dev/null | grep -c "Platform Name" || echo "0")
		echo "OpenCL Platforms found: $Platform_Count"

		if [[ "$Platform_Count" -gt 0 ]]; then
			clinfo 2>/dev/null | grep -E "Platform Name|Device Name" | head -10
		else
			Print_Warning "No OpenCL platforms detected. Check GPU drivers."
		fi
	else
		Print_Warning "clinfo not found. Install with: zypper install clinfo"
	fi

	echo ""
	echo "ICD Files:"
	ls /etc/OpenCL/vendors/ 2>/dev/null || echo "  No ICD files found"
	echo ""
}

Verify_VA_API()
{
	Print_Status "Verifying VA-API (hardware video decode)..."

	echo ""
	if command -v vainfo &>/dev/null; then
		vainfo 2>&1 | head -15 || Print_Warning "VA-API check failed"
	else
		Print_Warning "vainfo not found. Install with: zypper install libva-utils"
	fi
	echo ""
}

Print_Post_Install()
{
	echo ""
	echo "========================================"
	echo " Post-Installation Steps"
	echo "========================================"
	echo ""
	echo "1. Launch DaVinci Resolve:"
	echo "   /opt/resolve/bin/resolve"
	echo ""
	echo "2. Configure GPU in Resolve:"
	echo "   - Go to: DaVinci Resolve > Preferences > Memory and GPU"
	echo "   - Select your Intel Arc GPU"
	echo "   - Set GPU Processing Mode to: OpenCL (not CUDA)"
	echo ""
	echo "3. If you get 'Unsupported GPU Processing Mode' error:"
	echo "   Run: sudo zypper install intel-compute-runtime intel-opencl ocl-icd-devel"
	echo ""
}

Main()
{
	echo "========================================"
	echo " DaVinci Resolve Fix Script for openSUSE Tumbleweed"
	echo "========================================"
	echo ""

	Check_Root

	Install_Dependencies
	Install_Intel_GPU_Stack
	Setup_Permissions

	# Only fix GLib if Resolve is installed
	if [[ -d /opt/resolve ]]; then
		Fix_GLib_Mismatch
	else
		Print_Warning "DaVinci Resolve not installed yet. Skipping GLib fix."
		Print_Warning "Run this script again after installing Resolve."
	fi

	Verify_OpenCL
	Verify_VA_API

	Print_Post_Install

	Print_Status "All fixes applied successfully!"
	Print_Warning "Log out and back in for group changes to take effect."
	echo ""
}

Main "$@"
