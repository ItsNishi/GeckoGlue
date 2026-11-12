#!/bin/bash
# Install or update the official Fedora 43 Proton VPN GUI on openSUSE Tumbleweed.

set -euo pipefail

readonly Fedora_Release="43"
readonly Repo_Name="protonvpn-fedora-stable"
readonly Repo_Base_Url="https://repo.protonvpn.com/fedora-${Fedora_Release}-stable"
readonly Proton_Python="/usr/bin/python3.14"
readonly Daemon_Service="me.proton.vpn.split_tunneling.service"
readonly Launcher="/usr/local/bin/protonvpn-app"
readonly Desktop_File="proton.vpn.app.gtk.desktop"
readonly Proton_Packages=(
	proton-vpn-gtk-app
	proton-vpn-daemon
	python3-proton-core
	python3-proton-keyring-linux
	python3-proton-vpn-api-core
)

Check_Platform()
{
	# shellcheck source=/dev/null
	source /etc/os-release
	if [[ "$ID" != "opensuse-tumbleweed" || "$(uname -m)" != "x86_64" ]]; then
		printf '%s\n' "This script targets openSUSE Tumbleweed x86_64 with Fedora 43 packages." >&2
		return 1
	fi
}

Install_Dependencies()
{
	local Dependencies=(
		python314 python314-aiohttp python314-bcrypt python314-python-gnupg
		python314-importlib-metadata python314-pyOpenSSL python314-requests
		python314-PyNaCl python314-SecretStorage python314-dbus-python python314-dbus_fast
		python314-gobject python314-gobject-Gdk python314-gobject-cairo
		python314-packaging python314-keyring python314-distro python314-fido2
		python314-Jinja2 python314-sentry-sdk python314-psutil python314-systemd python314-bcc
		typelib-1_0-Gtk-4_0 typelib-1_0-NM-1_0 gnome-keyring libnotify-tools librsvg-2-2
		NetworkManager NetworkManager-openvpn NetworkManager-applet-openvpn
		wireguard-tools desktop-file-utils
	)
	local Missing=()
	local Package
	for Package in "${Dependencies[@]}"; do
		if ! rpm -q "$Package" &>/dev/null; then
			Missing+=("$Package")
		fi
	done

	if (( ${#Missing[@]} > 0 )); then
		zypper --non-interactive install --no-recommends "${Missing[@]}"
	fi
}

Check_Dependencies()
{
	"$Proton_Python" - <<'PY'
import aiohttp
import bcrypt
import bcc
import cairo
import dbus
import dbus_fast
import distro
import fido2
import gi
import gnupg
import importlib_metadata
import jinja2
import keyring
import nacl
import OpenSSL
import packaging
import psutil
import requests
import secretstorage
import sentry_sdk
import systemd

gi.require_version("Gtk", "4.0")
gi.require_version("NM", "1.0")
from gi.repository import Gtk, NM

print("Python 3.14 dependencies and GTK 4 / NetworkManager bindings passed")
PY
}

Add_Repo()
{
	# Parse repository configuration so an existing alias cannot silently select another source.
	/usr/bin/python3 - "$Repo_Name" "$Repo_Base_Url" <<'PY'
import configparser
from pathlib import Path
import sys

Name, Url = sys.argv[1:]
Found = False
for File in Path("/etc/zypp/repos.d").glob("*.repo"):
	Config = configparser.ConfigParser(interpolation=None)
	Config.read(File)
	if Name not in Config:
		continue
	Repo = Config[Name]
	if Found or Repo.get("baseurl", "").rstrip("/") != Url:
		raise SystemExit(f"Conflicting repository alias in {File}; review it before continuing")
	if not Repo.getboolean("enabled", fallback=True):
		raise SystemExit(f"Repository is disabled in {File}")
	if not Repo.getboolean("pkg_gpgcheck", fallback=Repo.getboolean("gpgcheck", fallback=True)):
		raise SystemExit(f"Package signature checks are disabled in {File}")
	Found = True

if not Found:
	Config = configparser.ConfigParser(interpolation=None)
	Config[Name] = {
		"name": "Proton VPN Fedora 43 Stable repository",
		"baseurl": Url,
		"enabled": "1",
		"autorefresh": "1",
		"gpgcheck": "1",
		"repo_gpgcheck": "0",
		"gpgkey": f"{Url}/public_key.asc",
		"type": "rpm-md",
	}
	with Path("/etc/zypp/repos.d/protonvpn-stable.repo").open("x") as File:
		Config.write(File)
PY
	zypper --gpg-auto-import-keys refresh "$Repo_Name"
}

Configure_Daemon()
{
	local Override_Dir="/etc/systemd/system/${Daemon_Service}.d"
	install -d -m 0755 "$Override_Dir"
	cat > "${Override_Dir}/python314.conf" <<EOF_SERVICE
[Service]
ExecStart=
ExecStart=${Proton_Python} -m proton.vpn.daemon
EOF_SERVICE
	chmod 0644 "${Override_Dir}/python314.conf"
	# Configure before installing so the package's post-transaction restart uses Python 3.14.
	systemctl daemon-reload
}

Install_ProtonVPN()
{
	printf '%s\n' \
		"Installing or updating Proton VPN; review Zypper's dependency solutions." \
		"Verified equivalents: python3-dbus -> python314-dbus-python," \
		"python3-dbus-fast -> python314-dbus_fast," \
		"python3-secretstorage -> python314-SecretStorage, python3-pynacl -> python314-PyNaCl." \
		"Other dependency errors require separate review. Cancel if an equivalent is missing."
	# Always request the packages, including when an older version is already installed.
	# Keep the solver interactive; do not force resolution or ignore all RPM dependencies.
	zypper --no-refresh install --no-recommends --from "$Repo_Name" "${Proton_Packages[@]}"
}

Configure_Launcher()
{
	install -d -m 0755 /usr/local/bin /usr/local/share/applications
	cat > "$Launcher" <<EOF_LAUNCHER
#!/bin/bash
exec ${Proton_Python} /usr/bin/protonvpn-app "\$@"
EOF_LAUNCHER
	chmod 0755 "$Launcher"
	desktop-file-install --dir=/usr/local/share/applications \
		--set-key=Exec --set-value="$Launcher" "/usr/share/applications/${Desktop_File}"
	desktop-file-validate "/usr/local/share/applications/${Desktop_File}"
}

Verify_Installation()
{
	Check_Dependencies
	rpm -q "${Proton_Packages[@]}"
	"$Proton_Python" - <<'PY'
from importlib.metadata import version
import proton.vpn.app.gtk.__main__
import proton.vpn.daemon.__main__

print(f"Proton VPN GUI {version('proton-vpn-gtk-app')}: GUI and daemon imports passed")
PY
	bash -n "$Launcher"
	desktop-file-validate "/usr/local/share/applications/${Desktop_File}"
	systemctl is-active "$Daemon_Service"
	systemctl --no-pager show --property=ExecStart "$Daemon_Service"
}

Main()
{
	if [[ "${1:-}" == "--help" && $# -eq 1 ]]; then
		printf '%s\n' "Usage: sudo $0 | $0 --check" \
			"--check verifies the installed packages, imports, launchers and daemon without changes."
		return
	fi
	if [[ $# -gt 0 && ( $# -ne 1 || "$1" != "--check" ) ]]; then
		printf '%s\n' "Unknown arguments. Use --help for usage." >&2
		return 2
	fi

	Check_Platform
	if [[ "${1:-}" == "--check" ]]; then
		Verify_Installation
		return
	fi
	if [[ $EUID -ne 0 ]]; then
		printf '%s\n' "Run with sudo $0; use --check for verification without administrator access." >&2
		return 1
	fi

	Add_Repo
	Install_Dependencies
	Check_Dependencies
	Configure_Daemon
	Install_ProtonVPN
	Configure_Launcher
	systemctl reset-failed "$Daemon_Service"
	systemctl restart "$Daemon_Service"
	Verify_Installation
	printf '%s\n' "Installation verified. Reopen Proton VPN from the app menu or run ${Launcher}." \
		"Per-user desktop overrides must also use Python 3.14." \
		"Tunnel connectivity, kill switch and split-tunneling behavior have not been tested."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	Main "$@"
fi
