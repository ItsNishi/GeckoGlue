# Update Proton VPN on openSUSE Tumbleweed

This procedure updated an existing Proton VPN installation from the Fedora 43 stable repository
on openSUSE Tumbleweed 20261103 on 2026-11-09. The installation uses Python 3.14 even though
the system default `python3` is 3.13. This is an update checkpoint, not a fresh installation guide.

The [installer](../scripts/fix-protonvpn.sh) now supports both installation and updates with
native Python 3.14 dependencies and explicit GUI/daemon launchers. See
[Proton VPN setup](ProtonVPN_Setup.md) for usage. The commands below preserve the original
manual update checkpoint.

## Verified package versions

| Package | Before | After |
|---------|--------|-------|
| `proton-vpn-gtk-app` | `4.12.0` | `4.18.7-1.fc43` |
| `proton-vpn-daemon` | `0.13.4` | `0.13.8-1.fc43` |
| `python3-proton-keyring-linux` | `0.2.1` | `0.2.3-1.fc43` |
| `python3-proton-vpn-api-core` | `4.14.1` | `5.8.7-1.fc43` |

## Check the interpreter and dependencies

The existing desktop launcher uses:

```ini
Exec=/usr/bin/python3.14 /usr/bin/protonvpn-app
```

Check the existing repository URL with `zypper lr -u`. This update used
`https://repo.protonvpn.com/fedora-43-stable`, with alias `protonvpn-fedora-stable`.

Fedora and openSUSE use different names for several dependencies:

| Fedora requirement | Installed openSUSE equivalent |
|--------------------|------------------------------|
| `python3-dbus-fast` | `python314-dbus_fast` |
| `python3-dbus` | `python314-dbus-python` |
| `python3-secretstorage` | `python314-SecretStorage` |
| `python3-pynacl` | `python314-PyNaCl` |

Verify the modules using the interpreter that runs Proton VPN:

```bash
/usr/bin/python3.14 - <<'PY'
import dbus_fast
import dbus
import secretstorage
import nacl
import gi
import psutil
import systemd
import bcc

gi.require_version("Gtk", "4.0")
gi.require_version("NM", "1.0")
print("Dependency imports passed")
PY
```

All these checks passed on the updated machine. Resolve any missing modules before proceeding.

## Update the four packages

```bash
sudo zypper refresh protonvpn-fedora-stable
sudo zypper --no-refresh install --no-recommends --from protonvpn-fedora-stable \
	proton-vpn-gtk-app proton-vpn-daemon \
	python3-proton-keyring-linux python3-proton-vpn-api-core
```

A normal `zypper update` skipped these packages because of the dependency-name mismatches.
The explicit install offered four exceptions for the Fedora names listed above. Accept an
exception only after verifying the corresponding installed openSUSE module. Review any additional
solver problems separately; the four verified exceptions do not justify ignoring other dependencies.

The API core package changed from `noarch` to `x86_64` and moved into
`/usr/lib64/python3.14/site-packages/`. Existing symlinks into Python 3.13 were insufficient for
the updated daemon. All four packages installed, but Zypper exited 107 because the daemon's
post-transaction restart failed with an import error under Python 3.13.

## Run the daemon with Python 3.14

Create `/etc/systemd/system/me.proton.vpn.split_tunneling.service.d/python314.conf` containing:

```ini
[Service]
ExecStart=
ExecStart=/usr/bin/python3.14 -m proton.vpn.daemon
```

The empty `ExecStart=` clears the packaged command before setting the replacement.
Reload the unit and restart it:

```bash
sudo systemctl daemon-reload
sudo systemctl reset-failed me.proton.vpn.split_tunneling.service
sudo systemctl restart me.proton.vpn.split_tunneling.service
systemctl is-active me.proton.vpn.split_tunneling.service
```

The service reported `active` after this override. Recheck the interpreter and override when
Tumbleweed changes its default Python version. Inspect old compatibility symlinks before removing
them; preserve RPM-owned package directories.

## Verify and reopen the app

```bash
rpm -q proton-vpn-gtk-app proton-vpn-daemon \
	python3-proton-keyring-linux python3-proton-vpn-api-core
/usr/bin/python3.14 /usr/bin/protonvpn-app --version
```

Close the old GUI and reopen it through the existing Python 3.14 desktop launcher, or run:

```bash
/usr/bin/python3.14 /usr/bin/protonvpn-app
```

Verified on 2026-11-09: version output `4.18.7`, successful GUI and daemon imports, an active
daemon, GUI startup completion, API refresh responses, and completion of the server-list update.
Nonfatal GTK slider-size warnings appeared during startup. The installed package versions and
active daemon were rechecked on 2026-11-11.

Tunnel establishment, traffic routing, kill switch, and split-tunneling behavior were not tested.
The desktop metapackage remains at `0.10.1`; version `0.11.0` additionally requires the CLI,
which was outside this GUI update.
