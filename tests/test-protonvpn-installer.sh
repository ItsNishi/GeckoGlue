#!/bin/bash
# Regression checks use command substitutes; they do not install packages or modify the host.

set -euo pipefail

readonly Project_Dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly Script="${Project_Dir}/scripts/fix-protonvpn.sh"
readonly Work_Dir="$(mktemp -d)"
trap 'rm -rf -- "$Work_Dir"' EXIT

# An existing installation must still reach the explicit package install/update request.
bash -s -- "$Script" > "${Work_Dir}/Install.log" <<'BASH'
source "$1"
rpm()
{
	return 0
}
zypper()
{
	printf '<%s>\n' "$@"
}
Install_ProtonVPN
BASH
rg -q '^<install>$' "${Work_Dir}/Install.log"
rg -q '^<--from>$' "${Work_Dir}/Install.log"
rg -q '^<proton-vpn-gtk-app>$' "${Work_Dir}/Install.log"
if rg -q '<(--force-resolution|--nodeps|--non-interactive|proton-vpn-gnome-desktop)>' \
	"${Work_Dir}/Install.log"; then
	printf '%s\n' "Unexpected forced solver behavior or desktop metapackage" >&2
	exit 1
fi

# Missing native dependencies must be installed instead of reusing a different Python ABI.
bash -s -- "$Script" > "${Work_Dir}/Dependencies.log" <<'BASH'
source "$1"
rpm()
{
	[[ "$2" != "python314-dbus_fast" ]]
}
zypper()
{
	printf '<%s>\n' "$@"
}
Install_Dependencies
BASH
rg -q '^<python314-dbus_fast>$' "${Work_Dir}/Dependencies.log"
if rg -q '^<python313-' "${Work_Dir}/Dependencies.log"; then
	printf '%s\n' "Dependency install selected Python 3.13" >&2
	exit 1
fi

# Package-manager failures, including post-transaction failure 107, must not report success.
for Expected in 4 107; do
	Actual=0
	bash -s -- "$Script" "$Expected" > "${Work_Dir}/Failure.log" 2>&1 <<'BASH' || Actual=$?
source "$1"
readonly Expected="$2"
zypper()
{
	return "$Expected"
}
Install_ProtonVPN
printf '%s\n' "UNEXPECTED_SUCCESS"
BASH
	[[ "$Actual" -eq "$Expected" ]]
	if rg -q 'UNEXPECTED_SUCCESS' "${Work_Dir}/Failure.log"; then
		exit 1
	fi
done

# Verification must not invoke configuration, installation or restart operations.
bash -s -- "$Script" > "${Work_Dir}/Check.log" <<'BASH'
source "$1"
Check_Platform()
{
	return 0
}
Verify_Installation()
{
	printf '%s\n' "VERIFIED"
}
Add_Repo()
{
	exit 99
}
Install_Dependencies()
{
	exit 99
}
Configure_Daemon()
{
	exit 99
}
Install_ProtonVPN()
{
	exit 99
}
Configure_Launcher()
{
	exit 99
}
Main --check
BASH
rg -q '^VERIFIED$' "${Work_Dir}/Check.log"

# Unknown arguments stop before attempting administrator operations.
Actual=0
bash "$Script" --unknown > "${Work_Dir}/Arguments.log" 2>&1 || Actual=$?
[[ "$Actual" -eq 2 ]]
printf '%s\n' "Proton VPN installer regression checks passed"
