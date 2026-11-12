# Proton VPN on openSUSE Tumbleweed

The official Proton VPN Fedora 43 packages can run on openSUSE Tumbleweed x86_64 with
Python 3.14 and native openSUSE dependencies. The installer uses an explicit interpreter
for both the GUI and daemon, including when the system default `python3` is Python 3.13.

## Install or update

From the repository root:

```bash
sudo ./scripts/fix-protonvpn.sh
```

The same command requests the latest available Proton GUI, daemon, core, keyring and API
packages even if Proton VPN is already installed. It installs missing native dependencies,
refreshes the Proton repository and keeps Zypper's solver interactive.

Zypper may offer dependency exceptions because Fedora and openSUSE use different package names:

| Fedora requirement | Verified openSUSE equivalent |
|--------------------|-----------------------------|
| `python3-dbus` | `python314-dbus-python` |
| `python3-dbus-fast` | `python314-dbus_fast` |
| `python3-secretstorage` | `python314-SecretStorage` |
| `python3-pynacl` | `python314-PyNaCl` |

The installer checks Python 3.14 imports before requesting Proton packages. Accept an exception
only when its corresponding native module is installed and verified. Additional solver problems
require separate review. Cancel on an unresolved dependency; the script propagates package-manager
failures and does not print a successful installation result after them.

## Configuration installed

- `/etc/zypp/repos.d/protonvpn-stable.repo`: created only if the Proton repository alias is absent.
  Existing matching repository settings are preserved. A conflicting alias, disabled repository
  or disabled package signature check stops the script.
- `/etc/systemd/system/me.proton.vpn.split_tunneling.service.d/python314.conf`: overrides the
  daemon command with `/usr/bin/python3.14 -m proton.vpn.daemon` before package installation.
- `/usr/local/bin/protonvpn-app`: runs `/usr/bin/python3.14 /usr/bin/protonvpn-app` and forwards
  command-line arguments.
- `/usr/local/share/applications/proton.vpn.app.gtk.desktop`: copies the packaged desktop entry
  with its command set to the local launcher. The RPM-owned desktop file is preserved.

Existing Python 3.13 compatibility symlinks are left in place but are no longer used by these
launchers. The installer does not remove legacy Proton clients automatically. Review and remove
any conflicting legacy package separately if Zypper reports a conflict.

Per-user desktop entries under `~/.local/share/applications/` take precedence over system entries.
If a custom Proton entry exists, its `Exec` command must also use Python 3.14 or the local launcher.
The installer does not modify user-owned desktop overrides or start the GUI as root.

## Verify and launch

Verification can run without administrator access:

```bash
./scripts/fix-protonvpn.sh --check
protonvpn-app
```

`--check` checks dependency and Proton imports, installed RPMs, launcher syntax, desktop-file
validity and daemon status. Close an older GUI process before reopening the app. If your shell
resolves the packaged command first, use `/usr/local/bin/protonvpn-app` explicitly.

For service failures:

```bash
systemctl status me.proton.vpn.split_tunneling.service
sudo journalctl -u me.proton.vpn.split_tunneling.service -n 40 --no-pager
```

The repository and Python version are pinned to Fedora 43 / Python 3.14. Recheck compatibility
before changing either. The desktop metapackage is not requested because newer versions also
require a CLI; the script manages the GUI packages directly.

## Validation

On 2026-11-11 the installer completed against an existing installation of GUI 4.18.7 on
Tumbleweed 20261103. It installed the missing Python 3.14 metadata dependency and its `zipp`
dependency, configured both launchers, and restarted the daemon successfully. The unprivileged
`--check` and local launcher's `--version` passed. Fresh installation was not tested.

An initial run stopped with Zypper status 106 after a repository-refresh warning, even though
the missing dependencies had installed. After reviewing that result, rerunning completed.
Package-manager errors remain fatal; inspect the reported error before retrying.

Run the isolated regression checks with `bash tests/test-protonvpn-installer.sh`. They cover
updates on an existing installation, native dependency selection, package-manager failure
propagation, argument validation, and the read-only verification path.

See [the verified update checkpoint](ProtonVPN_Update.md) for package versions and evidence.
Tunnel establishment, routing, kill switch and split-tunneling behavior require separate testing.
