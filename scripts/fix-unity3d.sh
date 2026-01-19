#!/bin/bash
#
# Unity3D Fix Script for openSUSE Tumbleweed
# Resolves common compatibility issues with Unity Hub and Unity Editor
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
		Print_Error "This script requires root privileges for some operations."
		Print_Warning "Run with: sudo $0"
		exit 1
	fi
}

Install_Dependencies()
{
	Print_Status "Installing Unity3D dependencies..."

	zypper install -y \
		libgtk-2_0-0 libgtk-3-0 libgdk_pixbuf-2_0-0 \
		libglib-2_0-0 libgobject-2_0-0 libgio-2_0-0 \
		libX11-6 libXcursor1 libXrandr2 libXi6 libXinerama1 \
		libXfixes3 libXrender1 libXext6 libXcomposite1 libXdamage1 \
		alsa alsa-plugins libasound2 \
		libcurl4 mozilla-nss mozilla-nspr ca-certificates \
		libfuse2 libpng16-16 libjpeg8 libfreetype6

	Print_Status "Dependencies installed."
}

Fix_SSL_Certificates()
{
	Print_Status "Fixing SSL certificate path for Unity..."

	if [[ -L /etc/ssl/certs/ca-certificates.crt ]]; then
		Print_Warning "SSL symlink already exists, skipping."
	elif [[ -f /etc/ssl/certs/ca-certificates.crt ]]; then
		Print_Warning "ca-certificates.crt already exists as a file, skipping."
	else
		ln -s /etc/ssl/ca-bundle.pem /etc/ssl/certs/ca-certificates.crt
		Print_Status "SSL certificate symlink created."
	fi
}

Fix_Libxml2()
{
	Print_Status "Fixing libxml2 compatibility..."

	if [[ -L /lib64/libxml2.so.2 ]]; then
		Print_Warning "libxml2 symlink already exists, skipping."
	elif [[ -f /lib64/libxml2.so.2 ]]; then
		Print_Warning "libxml2.so.2 already exists, skipping."
	elif [[ -f /lib64/libxml2.so.16 ]]; then
		ln -s /lib64/libxml2.so.16 /lib64/libxml2.so.2
		Print_Status "libxml2 symlink created."
	else
		Print_Warning "libxml2.so.16 not found, skipping."
	fi
}

Setup_Desktop_Entry()
{
	Print_Status "Setting up Unity Hub desktop entry with kharma protocol..."

	local Desktop_Dir="/home/${SUDO_USER}/.local/share/applications"
	mkdir -p "$Desktop_Dir"

	cat << 'EOF' > "$Desktop_Dir/unityhub.desktop"
[Desktop Entry]
Name=Unity Hub
Exec=/opt/unityhub/unityhub %U
Terminal=false
Type=Application
Icon=unityhub
StartupWMClass=unityhub
Comment=The Official Unity Hub
Categories=Development;
MimeType=x-scheme-handler/unityhub;x-scheme-handler/com.unity3d.kharma;
EOF

	chown "${SUDO_USER}:${SUDO_USER}" "$Desktop_Dir/unityhub.desktop"

	# Update database and register protocol as the actual user
	su - "$SUDO_USER" -c "update-desktop-database ~/.local/share/applications/ 2>/dev/null || true"
	su - "$SUDO_USER" -c "xdg-mime default unityhub.desktop x-scheme-handler/com.unity3d.kharma 2>/dev/null || true"

	Print_Status "Desktop entry configured."
}

Verify_Installation()
{
	Print_Status "Verifying fixes..."

	echo ""
	echo "SSL Certificate:"
	ls -la /etc/ssl/certs/ca-certificates.crt 2>/dev/null || echo "  Not found"

	echo ""
	echo "libxml2 Symlink:"
	ls -la /lib64/libxml2.so.2 2>/dev/null || echo "  Not found"

	echo ""
	echo "Kharma Protocol Handler:"
	su - "$SUDO_USER" -c "xdg-mime query default x-scheme-handler/com.unity3d.kharma 2>/dev/null" || echo "  Not configured"

	echo ""
}

Main()
{
	echo "========================================"
	echo " Unity3D Fix Script for openSUSE Tumbleweed"
	echo "========================================"
	echo ""

	Check_Root

	Install_Dependencies
	Fix_SSL_Certificates
	Fix_Libxml2
	Setup_Desktop_Entry

	echo ""
	Verify_Installation

	echo ""
	Print_Status "All fixes applied successfully!"
	Print_Warning "You may need to log out and back in for group changes to take effect."
	echo ""
}

Main "$@"
