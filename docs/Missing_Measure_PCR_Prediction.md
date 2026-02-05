# Fix: Missing measure-pcr-prediction File on openSUSE Tumbleweed

Fixes boot halting with "Missing measure-pcr-prediction file" on GRUB systems with disk encryption.

## Symptom

After a kernel or system update, the system halts during boot with:

```
ERROR: Missing measure-pcr-prediction file
Use 'measure-pcr-validator.ignore=yes' in cmdline to bypass the check
*** The system will be halted. Press any key ...
```

Adding `measure-pcr-validator.ignore=yes` to the kernel command line works as a temporary bypass but is not a permanent fix.

## Cause

Two things combine to cause this:

1. The `sdbootutil-dracut-measure-pcr` package installs a dracut module (`50measure-pcr`) that validates TPM2 PCR predictions during boot
2. `/etc/crypttab` contains `tpm2-measure-pcr=yes` on encrypted device entries, which triggers the validator

On GRUB systems, the prediction files in `/var/lib/sdbootutil/` are never generated (they're an sd-boot feature), so the validator fails and halts the boot.

Removing the package alone is not enough. The `tpm2-measure-pcr=yes` flag in `/etc/crypttab` must also be removed, and the initrd must be rebuilt.

## Fix

### Traditional GRUB

```bash
# 1. Remove tpm2-measure-pcr=yes from /etc/crypttab
sudo sed -i 's/tpm2-measure-pcr=yes,//g; s/,tpm2-measure-pcr=yes//g; s/tpm2-measure-pcr=yes//g' /etc/crypttab

# 2. Remove the package and lock it so updates don't reinstall it
sudo zypper rm sdbootutil-dracut-measure-pcr
sudo zypper al sdbootutil-dracut-measure-pcr

# 3. Rebuild the initrd
sudo dracut -f

# 4. Regenerate GRUB config
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

### GRUB with BLS (grub2-x86_64-efi-bls)

Newer Tumbleweed installs use GRUB with Boot Loader Specification (BLS). This changes the fix significantly:

- There is no `grub2-mkconfig` command
- Kernel parameters live in `/etc/kernel/cmdline` instead of `/etc/default/grub`
- `dracut -f` only rebuilds `/boot/initrd-*` but BLS boots from a separate initrd on the EFI partition
- `kernel-install` is required to rebuild the EFI partition initrd
- Snapper creates BLS entries that reference specific initrds by hash

**Important:** On BLS systems, `dracut -f` alone will NOT fix the issue. The EFI partition has its own copy of the initrd that must be rebuilt with `kernel-install`.

```bash
# 1. Remove tpm2-measure-pcr=yes from /etc/crypttab
sudo sed -i 's/tpm2-measure-pcr=yes,//g; s/,tpm2-measure-pcr=yes//g; s/tpm2-measure-pcr=yes//g' /etc/crypttab

# 2. Remove the package and lock it so updates don't reinstall it
sudo zypper rm sdbootutil-dracut-measure-pcr
sudo zypper al sdbootutil-dracut-measure-pcr

# 3. Rebuild /boot initrd
sudo dracut -f

# 4. Review old kernels on EFI partition
#    Each kernel takes ~150MB. A 600MB EFI partition fits ~3 total.
ls -d /boot/efi/opensuse-tumbleweed/*/
du -sh /boot/efi/opensuse-tumbleweed/*/
df -h /boot/efi

#    Remove old hashed initrds from current kernel dir
KVER=$(uname -r)
sudo sh -c "rm -f /boot/efi/opensuse-tumbleweed/${KVER}/initrd-*"

#    Optionally remove old kernel versions to free space (keep at least 1 for rollback)
#    sudo rm -rf /boot/efi/opensuse-tumbleweed/<old-version>

#    Remove stale BLS entries that reference removed kernels
sudo sh -c 'for f in /boot/efi/loader/entries/snapper-*.conf /boot/efi/loader/entries/system-*.conf; do
    [ -f "$f" ] || continue
    initrd=$(grep "^initrd" "$f" | awk "{print \$2}")
    [ -n "$initrd" ] && [ ! -f "/boot/efi${initrd}" ] && rm -f "$f" && echo "Removed: $(basename "$f")"
done'

# 5. Verify /etc/kernel/cmdline has root= parameter
#    If missing, the BLS entry will fail to boot
cat /etc/kernel/cmdline
#    It MUST contain root=/dev/mapper/<your-luks-name> and rootflags=subvol=<your-subvol>
#    Example:
#    splash=silent mitigations=auto quiet security=selinux selinux=1 root=/dev/mapper/cr_root rootflags=subvol=@/.snapshots/1/snapshot

# 6. Rebuild the EFI partition initrd and BLS entry
sudo kernel-install add ${KVER} /usr/lib/modules/${KVER}/vmlinuz

# 7. Verify
sudo lsinitrd /boot/efi/opensuse-tumbleweed/${KVER}/initrd 2>/dev/null | grep measure-pcr
# Should return nothing (clean)
```

### Verify

```bash
# Confirm crypttab no longer references measure-pcr
grep -c 'tpm2-measure-pcr' /etc/crypttab
# Should output: 0

# Confirm package is removed
rpm -q sdbootutil-dracut-measure-pcr
# Should output: package is not installed
```

Reboot to confirm the system boots without halting.

## After Kernel Updates (BLS Only)

After running `zypper dup` and a new kernel is installed, you must rebuild the EFI initrd before rebooting:

```bash
# Check installed kernels
rpm -qa | grep kernel-default | sort

# Rebuild with the NEWEST kernel version (not necessarily the running one)
sudo kernel-install add <new-version> /usr/lib/modules/<new-version>/vmlinuz
```

If you reboot into the new kernel without doing this, the EFI partition will have a stale initrd.

## Temporary Bypass

If the system is halted and you need to boot once to apply the fix, edit the GRUB entry at boot:

1. Press `e` at the GRUB menu
2. Add `measure-pcr-validator.ignore=yes` to the kernel line
3. Press `F10` to boot

This is a one-time bypass. It is not persisted across reboots.

## Who This Affects

- **GRUB users with disk encryption** (default Tumbleweed install with LUKS + TPM2) - safe to apply this fix
- **sd-boot users with TPM2 measured boot** - do NOT apply, this package and crypttab flag are required for your boot chain

## How to Check Your Bootloader

```bash
# Check which GRUB variant is installed
rpm -qa | grep grub2

# grub2-x86_64-efi-bls = BLS GRUB (no grub2-mkconfig, uses /etc/kernel/cmdline)
# grub2-x86_64-efi     = Traditional GRUB (has grub2-mkconfig, uses /etc/default/grub)

# sd-boot
bootctl list 2>/dev/null && echo "sd-boot"
```

## BLS GRUB Key Differences

| Feature | Traditional GRUB | BLS GRUB |
|---------|-----------------|----------|
| Kernel parameters | `/etc/default/grub` | `/etc/kernel/cmdline` |
| Config rebuild | `grub2-mkconfig` | `kernel-install` |
| Boot initrd location | `/boot/initrd-*` | `/boot/efi/opensuse-tumbleweed/<version>/initrd` |
| Boot entries | Generated `grub.cfg` | `/boot/efi/loader/entries/*.conf` |
| `dracut -f` sufficient | Yes | No - must also run `kernel-install` |

## Common Pitfalls

- **`dracut -f` only rebuilds `/boot/initrd-*`** on BLS systems. The bootloader loads from the EFI partition, so this alone won't fix the issue.
- **Missing `root=` in `/etc/kernel/cmdline`** causes `gpt-auto-root` failures. Always verify this file contains the full `root=/dev/mapper/<name>` and `rootflags=` parameters before running `kernel-install`.
- **EFI partition can fill up** with multiple initrds (~150MB each). A 600MB EFI partition can only hold ~3 total. Check usage with `df -h /boot/efi` and `du -sh /boot/efi/opensuse-tumbleweed/*/` before rebuilding. Keep at least 1 old kernel for rollback.
- **Deleting old kernels breaks snapper entries** that reference them by hash. Remove the corresponding BLS entries too. The script handles this automatically after you choose which kernels to remove.

## Package Reference

| Package | Purpose |
|---------|---------|
| `sdbootutil-dracut-measure-pcr` | TPM2 PCR prediction for sd-boot (not needed for GRUB) |
| `sdbootutil` | sd-boot management utility |
| `grub2-x86_64-efi-bls` | BLS variant of GRUB (newer Tumbleweed installs) |
