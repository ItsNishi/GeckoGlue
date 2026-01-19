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

Detect_GPU()
{
	Print_Status "Detecting GPU(s)..."

	local GPU_Info
	GPU_Info=$(lspci | grep -i 'vga\|3d\|display')

	local Detected_GPUs=""

	if echo "$GPU_Info" | grep -iq 'intel'; then
		Detected_GPUs="${Detected_GPUs}intel "
		echo "$GPU_Info" | grep -i 'intel'
	fi

	if echo "$GPU_Info" | grep -iq 'amd\|radeon'; then
		Detected_GPUs="${Detected_GPUs}amd "
		echo "$GPU_Info" | grep -i 'amd\|radeon'
	fi

	if echo "$GPU_Info" | grep -iq 'nvidia'; then
		Detected_GPUs="${Detected_GPUs}nvidia "
		echo "$GPU_Info" | grep -i 'nvidia'
	fi

	if [[ -z "$Detected_GPUs" ]]; then
		echo "unknown"
	else
		echo "$Detected_GPUs" | xargs
	fi
}

Install_Dependencies()
{
	Print_Status "Installing DaVinci Resolve dependencies..."

	zypper install -y \
		libxcb-cursor0 libxcb-damage0 libxcb-util1 \
		libxkbcommon-x11-0 libapr1-0 libapr-util1-0 libglvnd \
		libgdk_pixbuf-2_0-0 libfuse2 ocl-icd-devel \
		google-noto-sans-fonts liberation-fonts

	Print_Status "Dependencies installed."
}

Install_Intel_GPU_Stack()
{
	Print_Status "Installing Intel GPU compute stack..."

	zypper install -y \
		intel-gpu-tools libva-utils \
		intel-opencl ocl-icd-devel \
		libvulkan_intel vulkan-tools

	Print_Status "Intel GPU stack installed."

	# Fix Intel OpenCL ICD registration
	# Tumbleweed's intel-opencl installs ICD to /usr/share but loader checks /etc
	Fix_Intel_OpenCL_ICD
}

Fix_Intel_OpenCL_ICD()
{
	Print_Status "Fixing Intel OpenCL ICD registration..."

	local Intel_ICD_Source="/usr/share/OpenCL/vendors/intel.icd"
	local ICD_Target_Dir="/etc/OpenCL/vendors"
	local Intel_ICD_Target="$ICD_Target_Dir/intel.icd"

	mkdir -p "$ICD_Target_Dir"

	if [[ -f "$Intel_ICD_Source" ]]; then
		if [[ ! -e "$Intel_ICD_Target" ]]; then
			ln -s "$Intel_ICD_Source" "$Intel_ICD_Target"
			Print_Status "Symlinked Intel ICD: $Intel_ICD_Source -> $Intel_ICD_Target"
		else
			Print_Warning "Intel ICD already exists at $Intel_ICD_Target"
		fi
	else
		Print_Error "Intel ICD source not found at $Intel_ICD_Source"
		Print_Warning "Ensure intel-opencl package is installed"
		return 1
	fi

	# NOTE: Do NOT symlink rusticl.icd - it conflicts with Resolve's GPU detection
	# on systems with multiple GPUs (e.g., Intel dGPU + AMD iGPU)

	Print_Status "Intel OpenCL ICD fix applied."
}

Install_AMD_GPU_Stack()
{
	Print_Status "Installing AMD GPU compute stack..."

	zypper install -y \
		libva-utils \
		rocm-opencl rocm-opencl-devel \
		Mesa-libRusticlOpenCL libdrm_amdgpu1 \
		libvulkan_radeon vulkan-tools \
		ocl-icd-devel

	Print_Status "AMD GPU stack installed."
}

Install_NVIDIA_GPU_Stack()
{
	Print_Status "Installing NVIDIA GPU compute stack..."

	# Check if NVIDIA proprietary driver is already installed
	if ! command -v nvidia-smi &>/dev/null; then
		Print_Warning "NVIDIA proprietary driver not detected."
		Print_Warning "Installing NVIDIA driver..."

		zypper install -y \
			nvidia-driver-G06-kmp-default \
			nvidia-compute-G06 \
			nvidia-gl-G06 \
			ocl-icd-devel

		Print_Status "NVIDIA driver installed."
		Print_Warning "You may need to reboot for the driver to load properly."
	else
		Print_Status "NVIDIA driver already installed."
		zypper install -y ocl-icd-devel
	fi

	Print_Status "NVIDIA GPU stack configured."
}

Install_GPU_Stack()
{
	local GPU_Vendors="$1"

	if [[ "$GPU_Vendors" == "unknown" ]]; then
		Print_Warning "Could not detect GPU vendor automatically."
		Print_Warning "Please install GPU drivers manually:"
		Print_Warning "  Intel: sudo zypper install intel-opencl"
		Print_Warning "  AMD:   sudo zypper install rocm-opencl Mesa-libRusticlOpenCL"
		Print_Warning "  NVIDIA: sudo zypper install nvidia-driver-G06-kmp-default nvidia-compute-G06"
		return
	fi

	# Handle multiple GPUs - install drivers for all detected vendors
	for Vendor in $GPU_Vendors; do
		case "$Vendor" in
			intel)
				Print_Status "Installing drivers for Intel GPU..."
				Install_Intel_GPU_Stack
				;;
			amd)
				Print_Status "Installing drivers for AMD GPU..."
				Install_AMD_GPU_Stack
				;;
			nvidia)
				Print_Status "Installing drivers for NVIDIA GPU..."
				Install_NVIDIA_GPU_Stack
				;;
		esac
	done
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
	for Lib in libgmodule-2.0.so libgobject-2.0.so libgio-2.0.so libglib-2.0.so; do
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

	if command -v vainfo &>/dev/null; then
		local VA_Output
		VA_Output=$(vainfo 2>&1)

		if echo "$VA_Output" | grep -q "va_openDriver() returns 0"; then
			local Driver_Name
			Driver_Name=$(echo "$VA_Output" | grep "Trying to open" | sed 's/.*\/\([^\/]*\)$/\1/' | head -1)
			echo "  VA-API driver loaded: $Driver_Name"
		else
			Print_Warning "VA-API driver failed to load"
		fi
	else
		Print_Warning "vainfo not found. Install with: zypper install libva-utils"
	fi
}

Print_Post_Install()
{
	local GPU_Vendors="$1"

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

	# Check if multiple GPUs detected
	local GPU_Count
	GPU_Count=$(echo "$GPU_Vendors" | wc -w)

	if [[ $GPU_Count -gt 1 ]]; then
		echo "   - Multiple GPUs detected! Choose your preferred GPU:"
		for Vendor in $GPU_Vendors; do
			case "$Vendor" in
				intel)
					echo "     * Intel GPU: Use OpenCL mode"
					;;
				amd)
					echo "     * AMD GPU: Use OpenCL mode"
					;;
				nvidia)
					echo "     * NVIDIA GPU: Use CUDA (preferred) or OpenCL mode"
					;;
			esac
		done
		echo ""
		echo "3. Troubleshooting 'Unsupported GPU Processing Mode' errors:"
		for Vendor in $GPU_Vendors; do
			case "$Vendor" in
				intel)
					echo "   Intel: sudo zypper install intel-opencl"
					;;
				amd)
					echo "   AMD: sudo zypper install rocm-opencl Mesa-libRusticlOpenCL"
					;;
				nvidia)
					echo "   NVIDIA: Check nvidia-smi, reboot if needed"
					;;
			esac
		done
	else
		# Single GPU
		case "$GPU_Vendors" in
			intel)
				echo "   - Select your Intel GPU"
				echo "   - Set GPU Processing Mode to: OpenCL"
				echo ""
				echo "3. If you get 'Unsupported GPU Processing Mode' error:"
				echo "   Run: sudo zypper install intel-opencl ocl-icd-devel"
				;;
			amd)
				echo "   - Select your AMD GPU"
				echo "   - Set GPU Processing Mode to: OpenCL"
				echo ""
				echo "3. If you get 'Unsupported GPU Processing Mode' error:"
				echo "   Run: sudo zypper install rocm-opencl Mesa-libRusticlOpenCL"
				;;
			nvidia)
				echo "   - Select your NVIDIA GPU"
				echo "   - Set GPU Processing Mode to: CUDA (preferred) or OpenCL"
				echo ""
				echo "3. If you get 'Unsupported GPU Processing Mode' error:"
				echo "   Ensure NVIDIA driver is loaded: nvidia-smi"
				echo "   If driver not loaded, reboot the system"
				;;
			unknown)
				echo "   - Select your GPU"
				echo "   - Set GPU Processing Mode based on your GPU vendor:"
				echo "     * Intel/AMD: OpenCL"
				echo "     * NVIDIA: CUDA or OpenCL"
				;;
		esac
	fi

	echo ""
}

Main()
{
	echo "========================================"
	echo " DaVinci Resolve Fix Script for openSUSE Tumbleweed"
	echo "========================================"
	echo ""

	Check_Root

	# Detect GPU and install appropriate drivers
	local GPU_Vendor
	GPU_Vendor=$(Detect_GPU)

	Install_Dependencies
	Install_GPU_Stack "$GPU_Vendor"
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

	Print_Post_Install "$GPU_Vendor"

	Print_Status "All fixes applied successfully!"
	Print_Warning "Log out and back in for group changes to take effect."
	echo ""
}

Main "$@"
