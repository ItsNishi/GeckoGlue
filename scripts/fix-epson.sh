#!/bin/bash
#
# Epson Printer/Scanner Fix Script for openSUSE Tumbleweed
# Resolves Epson Scan 2 crash and sets up IPP printing
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Global variable for printer name
Printer_Name=""

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

Fix_Epson_Scan2()
{
	Print_Status "Fixing Epson Scan 2 dependencies..."

	# Epson Scan 2 is 32-bit and needs 32-bit Qt5 libraries
	if rpm -q libQt5Widgets5-32bit &>/dev/null; then
		Print_Warning "libQt5Widgets5-32bit already installed, skipping."
	else
		zypper install -y libQt5Widgets5-32bit
		Print_Status "32-bit Qt5 libraries installed."
	fi
}

Setup_IPP_Printer()
{
	Print_Status "Setting up IPP printer..."

	echo ""
	read -p "Enter printer IP address (or 'skip' to skip): " Printer_IP

	if [[ "$Printer_IP" == "skip" || -z "$Printer_IP" ]]; then
		Print_Warning "Skipping printer setup."
		return
	fi

	# Validate IP format (basic check)
	if ! [[ "$Printer_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		Print_Error "Invalid IP address format."
		return
	fi

	# Test connectivity
	Print_Status "Testing connection to $Printer_IP..."
	if ! ping -c 1 -W 3 "$Printer_IP" &>/dev/null; then
		Print_Error "Cannot reach $Printer_IP. Check printer is on and connected."
		return
	fi

	# Check if IPP port responds
	if ! curl -s -m 5 "http://$Printer_IP:631/" &>/dev/null; then
		Print_Warning "IPP port 631 not responding. Printer may not support IPP."
	fi

	read -p "Enter printer name (default: EPSON_Printer): " Printer_Name
	Printer_Name="${Printer_Name:-EPSON_Printer}"

	# Remove spaces and special characters from name
	Printer_Name=$(echo "$Printer_Name" | tr ' ' '_' | tr -cd '[:alnum:]_-')

	# Check if printer already exists
	if lpstat -p "$Printer_Name" &>/dev/null; then
		Print_Warning "Printer '$Printer_Name' already exists."
		read -p "Replace it? (y/N): " Replace
		if [[ "$Replace" =~ ^[Yy]$ ]]; then
			lpadmin -x "$Printer_Name"
		else
			Print_Warning "Skipping printer setup."
			Printer_Name=""
			return
		fi
	fi

	# Add printer using IPP Everywhere
	lpadmin -p "$Printer_Name" -E \
		-v "ipp://$Printer_IP:631/ipp/print" \
		-m everywhere \
		-L "Network" \
		-D "Epson Printer"

	Print_Status "Printer '$Printer_Name' added."

	read -p "Set as default printer? (y/N): " Set_Default
	if [[ "$Set_Default" =~ ^[Yy]$ ]]; then
		lpadmin -d "$Printer_Name"
		Print_Status "Set as default printer."
	fi
}

Add_User_To_Groups()
{
	Print_Status "Adding user to printer/scanner groups..."

	if [[ -n "$SUDO_USER" ]]; then
		usermod -aG lp "$SUDO_USER" 2>/dev/null || true
		Print_Status "Added $SUDO_USER to lp group."
	fi
}

Verify_Installation()
{
	Print_Status "Verifying fixes..."

	echo ""
	echo "Qt5 32-bit Libraries:"
	rpm -q libQt5Widgets5-32bit 2>/dev/null || echo "  Not installed"

	echo ""
	echo "Epson Scan 2:"
	if command -v epsonscan2 &>/dev/null; then
		echo "  Installed at: $(which epsonscan2)"
	else
		echo "  Not installed (download from Epson website)"
	fi

	echo ""
	echo "Configured Printers:"
	lpstat -p 2>/dev/null || echo "  No printers configured"

	echo ""
}

Print_Test_Instructions()
{
	echo ""
	Print_Status "Setup complete!"
	echo ""

	if [[ -n "$Printer_Name" ]]; then
		read -p "Print a test page? (y/N): " Test_Print
		if [[ "$Test_Print" =~ ^[Yy]$ ]]; then
			Print_Status "Sending test page to $Printer_Name..."
			if lp -d "$Printer_Name" /usr/share/cups/data/testprint; then
				Print_Status "Test page sent."
			else
				Print_Error "Failed to send test page."
			fi
		fi
		echo ""
	fi

	echo "To test scanning:"
	echo "  epsonscan2"
	echo ""
	Print_Warning "Log out and back in for group changes to take effect."
	echo ""
}

Main()
{
	echo "========================================"
	echo " Epson Fix Script for openSUSE Tumbleweed"
	echo "========================================"
	echo ""

	Check_Root

	Fix_Epson_Scan2
	Setup_IPP_Printer
	Add_User_To_Groups

	echo ""
	Verify_Installation
	Print_Test_Instructions
}

Main "$@"
