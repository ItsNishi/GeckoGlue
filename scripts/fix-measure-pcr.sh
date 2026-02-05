#!/bin/bash
#
# Fix: Missing measure-pcr-prediction for openSUSE Tumbleweed
# Removes sdbootutil-dracut-measure-pcr and cleans crypttab for GRUB users
# Handles both traditional GRUB and BLS GRUB (grub2-x86_64-efi-bls)
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

Is_BLS=false
KVER=$(uname -r)

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

Check_Bootloader()
{
	Print_Status "Detecting bootloader..."

	if bootctl is-installed &>/dev/null; then
		Print_Error "sd-boot detected. This fix is NOT for sd-boot systems."
		Print_Error "The measure-pcr package and crypttab flags are required for your boot chain."
		exit 1
	fi

	if rpm -q grub2-x86_64-efi-bls &>/dev/null; then
		Is_BLS=true
		Print_Status "GRUB with BLS detected."
	elif [[ -f /etc/default/grub ]]; then
		Print_Status "Traditional GRUB detected."
	else
		Print_Warning "Could not determine bootloader."
		read -p "Are you using GRUB? (y/N): " Is_Grub
		if [[ ! "$Is_Grub" =~ ^[Yy]$ ]]; then
			Print_Error "Aborting. Only apply this fix on GRUB systems."
			exit 1
		fi
	fi
}

Clean_Crypttab()
{
	Print_Status "Checking /etc/crypttab for tpm2-measure-pcr..."

	if [[ ! -f /etc/crypttab ]]; then
		Print_Warning "No /etc/crypttab found, skipping."
		return
	fi

	if grep -q 'tpm2-measure-pcr=yes' /etc/crypttab; then
		Print_Status "Removing tpm2-measure-pcr=yes from /etc/crypttab..."
		sed -i 's/tpm2-measure-pcr=yes,//g; s/,tpm2-measure-pcr=yes//g; s/tpm2-measure-pcr=yes//g' /etc/crypttab
		Print_Status "crypttab cleaned."
	else
		Print_Warning "tpm2-measure-pcr=yes not found in crypttab, skipping."
	fi
}

Remove_Package()
{
	Print_Status "Checking for sdbootutil-dracut-measure-pcr..."

	if ! rpm -q sdbootutil-dracut-measure-pcr &>/dev/null; then
		Print_Warning "Package not installed, skipping."
		return
	fi

	Print_Status "Removing sdbootutil-dracut-measure-pcr..."
	zypper remove -y sdbootutil-dracut-measure-pcr
	Print_Status "Package removed."

	Print_Status "Locking package to prevent reinstall on updates..."
	zypper al sdbootutil-dracut-measure-pcr
	Print_Status "Package locked."
}

Rebuild_Initrd()
{
	Print_Status "Rebuilding /boot initrd..."
	dracut -f
	Print_Status "/boot initrd rebuilt."
}

Rebuild_Traditional_Grub()
{
	Print_Status "Regenerating GRUB config..."
	grub2-mkconfig -o /boot/grub2/grub.cfg
	Print_Status "GRUB config regenerated."
}

Check_Kernel_Cmdline()
{
	Print_Status "Checking /etc/kernel/cmdline..."

	if [[ ! -f /etc/kernel/cmdline ]]; then
		Print_Warning "/etc/kernel/cmdline does not exist. Creating from running kernel..."
		mkdir -p /etc/kernel
		# Strip BOOT_IMAGE= parameter and copy the rest
		sed 's/BOOT_IMAGE=[^ ]* //' /proc/cmdline > /etc/kernel/cmdline
		Print_Status "Created /etc/kernel/cmdline from /proc/cmdline."
	fi

	if ! grep -q 'root=' /etc/kernel/cmdline; then
		Print_Warning "/etc/kernel/cmdline is missing root= parameter. Populating from /proc/cmdline..."
		sed 's/BOOT_IMAGE=[^ ]* //' /proc/cmdline > /etc/kernel/cmdline
		Print_Status "Updated /etc/kernel/cmdline from /proc/cmdline."
	fi

	if ! grep -q 'root=' /etc/kernel/cmdline; then
		Print_Error "/etc/kernel/cmdline still missing root= after auto-fix."
		Print_Error "Current contents:"
		cat /etc/kernel/cmdline
		echo ""
		Print_Error "Manually add root=/dev/mapper/<your-luks-name> and rootflags=subvol=<your-subvol>"
		exit 1
	fi

	Print_Status "Kernel cmdline OK:"
	echo "  $(cat /etc/kernel/cmdline)"
}

Clean_EFI_Stale_Entries()
{
	Print_Status "Cleaning stale BLS entries from EFI partition..."

	# Remove snapper entries that reference old initrds by hash
	local Stale_Count=0
	for Entry in /boot/efi/loader/entries/snapper-*.conf /boot/efi/loader/entries/system-*.conf; do
		if [[ -f "$Entry" ]]; then
			# Check if the initrd this entry references still exists
			local Initrd_Path
			Initrd_Path=$(grep '^initrd' "$Entry" | awk '{print $2}')
			if [[ -n "$Initrd_Path" ]] && [[ ! -f "/boot/efi${Initrd_Path}" ]]; then
				Print_Warning "Removing stale entry: $(basename "$Entry")"
				rm -f "$Entry"
				Stale_Count=$((Stale_Count + 1))
			fi
		fi
	done

	if [[ $Stale_Count -eq 0 ]]; then
		Print_Warning "No stale entries found."
	else
		Print_Status "Removed $Stale_Count stale entries."
	fi

	# Remove old hashed initrds from EFI to free space
	local EFI_Dir="/boot/efi/opensuse-tumbleweed/${KVER}"
	if [[ -d "$EFI_Dir" ]]; then
		local Old_Initrds
		Old_Initrds=$(find "$EFI_Dir" -name "initrd-*" 2>/dev/null)
		if [[ -n "$Old_Initrds" ]]; then
			Print_Status "Removing old hashed initrds from EFI..."
			rm -f "$EFI_Dir"/initrd-*
			Print_Status "Old initrds removed."
		fi
	fi

	# Remove old kernel versions from EFI
	for Dir in /boot/efi/opensuse-tumbleweed/*/; do
		local Dir_Ver
		Dir_Ver=$(basename "$Dir")
		if [[ "$Dir_Ver" != "$KVER" ]] && [[ -d "$Dir" ]]; then
			Print_Warning "Removing old kernel $Dir_Ver from EFI..."
			rm -rf "$Dir"
		fi
	done

	Print_Status "EFI space after cleanup:"
	df -h /boot/efi | tail -1
}

Get_Newest_Kernel()
{
	# Find the newest installed kernel-default package version
	local Newest
	Newest=$(rpm -qa --queryformat '%{VERSION}-%{RELEASE}\n' kernel-default | sort -V | tail -1)

	if [[ -z "$Newest" ]]; then
		echo "$KVER"
		return
	fi

	# Convert RPM version to directory name format (e.g., 6.18.8-1-default)
	# RPM gives us something like 6.18.8-1.1 but dir is 6.18.8-1-default
	local Dir_Match
	for Dir in /usr/lib/modules/*/vmlinuz; do
		Dir_Match=$(dirname "$Dir")
		Dir_Match=$(basename "$Dir_Match")
		echo "$Dir_Match"
	done | sort -V | tail -1
}

Rebuild_BLS_Entry()
{
	local Target_Kver
	Target_Kver=$(Get_Newest_Kernel)

	local Vmlinuz="/usr/lib/modules/${Target_Kver}/vmlinuz"

	if [[ ! -f "$Vmlinuz" ]]; then
		Print_Error "Kernel image not found at $Vmlinuz"
		Print_Error "Available kernels:"
		ls /usr/lib/modules/*/vmlinuz 2>/dev/null
		exit 1
	fi

	if [[ "$Target_Kver" != "$KVER" ]]; then
		Print_Warning "Running kernel: $KVER"
		Print_Warning "Newest kernel:  $Target_Kver"
		Print_Status "Building for newest kernel..."
	fi

	Print_Status "Rebuilding EFI initrd and BLS entry for ${Target_Kver}..."
	kernel-install add "${Target_Kver}" "$Vmlinuz"
	Print_Status "BLS entry rebuilt."
}

Verify_Fix()
{
	Print_Status "Verifying fix..."

	echo ""
	echo "crypttab measure-pcr references:"
	if [[ -f /etc/crypttab ]] && grep -c 'tpm2-measure-pcr' /etc/crypttab 2>/dev/null; then
		Print_Error "tpm2-measure-pcr still present in /etc/crypttab."
	else
		echo "  None (clean)"
	fi

	echo ""
	echo "Package status:"
	if rpm -q sdbootutil-dracut-measure-pcr &>/dev/null; then
		Print_Error "Package still installed."
	else
		echo "  sdbootutil-dracut-measure-pcr not installed (clean)"
	fi

	echo ""
	echo "/boot initrd:"
	if lsinitrd "/boot/initrd-${KVER}" 2>/dev/null | grep -q measure-pcr; then
		Print_Error "measure-pcr found in /boot initrd!"
	else
		echo "  Clean (no measure-pcr)"
	fi

	if [[ "$Is_BLS" == true ]]; then
		echo ""
		echo "EFI initrd:"
		local EFI_Initrd="/boot/efi/opensuse-tumbleweed/${KVER}/initrd"
		if [[ -f "$EFI_Initrd" ]]; then
			if lsinitrd "$EFI_Initrd" 2>/dev/null | grep -q measure-pcr; then
				Print_Error "measure-pcr found in EFI initrd!"
			else
				echo "  Clean (no measure-pcr)"
			fi
		else
			Print_Error "EFI initrd not found at $EFI_Initrd"
		fi

		echo ""
		echo "BLS entries:"
		ls -1 /boot/efi/loader/entries/*.conf 2>/dev/null || echo "  None found"

		echo ""
		echo "EFI partition:"
		df -h /boot/efi | tail -1
	fi

	echo ""
}

Main()
{
	echo "========================================"
	echo " Fix: Missing measure-pcr-prediction"
	echo " for openSUSE Tumbleweed (GRUB)"
	echo "========================================"
	echo ""

	Check_Root
	Check_Bootloader
	Clean_Crypttab
	Remove_Package
	Rebuild_Initrd

	if [[ "$Is_BLS" == true ]]; then
		Check_Kernel_Cmdline
		Clean_EFI_Stale_Entries
		Rebuild_BLS_Entry
	else
		Rebuild_Traditional_Grub
	fi

	echo ""
	Verify_Fix

	Print_Status "Fix applied. Reboot to confirm the system boots without halting."
	echo ""
}

Main "$@"
