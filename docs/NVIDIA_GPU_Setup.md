# NVIDIA GPU on openSUSE Tumbleweed

Setup guide for NVIDIA GPUs on Tumbleweed laptops and desktops, including driver installation, hybrid graphics, and common update issues.

## Tested Hardware

| GPU | Driver | Status |
|-----|--------|--------|
| RTX 3050 (Laptop) | nvidia-driver-G06 | Working |

## 1. Driver Installation

### Add NVIDIA Repository

The official openSUSE hardware repo provides NVIDIA drivers:

```bash
sudo zypper addrepo --refresh \
    https://download.opensuse.org/repositories/hardware/openSUSE_Tumbleweed/ \
    hardware
sudo zypper ref
```

### Install Driver

**Modern GPUs (GTX 10xx, 16xx, RTX series):**
```bash
sudo zypper install nvidia-driver-G06 nvidia-gl-G06
```

**Older GPUs (GTX 600-900 series):**
```bash
sudo zypper install nvidia-driver-G05 nvidia-gl-G05
```

Reboot after installation.

### Verify

```bash
nvidia-smi
```

## 2. Hybrid Graphics (Laptop)

For laptops with Intel/AMD integrated + NVIDIA discrete:

```bash
sudo zypper install nvidia-prime
```

Run GPU-intensive applications with:

```bash
prime-run <application>
```

## 3. Fix: Black Screen After Driver Install

### Check Secure Boot

NVIDIA drivers are unsigned on openSUSE. Secure boot will block them.

```bash
mokutil --sb-state
```

If enabled, disable secure boot in BIOS/UEFI settings.

### Rebuild Kernel Modules

If the driver installed but the module didn't build:

```bash
sudo zypper install -f nvidia-driver-G06-kmp-default
```

### Blacklist Nouveau

Should be automatic, but verify:

```bash
cat /etc/modprobe.d/50-nvidia-default.conf
```

If missing, create it:

```bash
echo "blacklist nouveau" | sudo tee /etc/modprobe.d/50-nvidia-default.conf
sudo dracut -f
```

## 4. MOK Enrollment After Updates

After kernel or driver updates with Secure Boot enabled, the system may prompt to enroll a Machine Owner Key (MOK).

1. Select **Enroll MOK**
2. Select **Continue**
3. Enter your **root password**
4. Select **Reboot**

This happens because updated kernel modules need to be trusted by Secure Boot. If you disabled Secure Boot for NVIDIA, you won't see this prompt.

## 5. Booting the Installer with NVIDIA

Some NVIDIA GPUs cause the nouveau driver to crash during installation.

At the GRUB boot menu:

1. Press `e` to edit the boot entry
2. Add `nomodeset` to the kernel line (after `splash=silent`)
3. Press `F10` to boot

## Troubleshooting

### Driver Not Loading

```bash
# Check if module is loaded
lsmod | grep nvidia

# Check for errors
journalctl -b -p err | grep -iE 'nvidia|nouveau|drm'

# Check kernel module availability
modinfo nvidia
```

### Screen Tearing

```bash
# Enable ForceCompositionPipeline
nvidia-settings --assign CurrentMetaMode="nvidia-auto-select +0+0 { ForceCompositionPipeline = On }"
```

### Wayland Issues

NVIDIA on Wayland requires the DRM kernel modesetting module:

```bash
# Add to /etc/modprobe.d/nvidia.conf
echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia-drm.conf
sudo dracut -f
```

## Package Reference

| Package | Purpose |
|---------|---------|
| `nvidia-driver-G06` | Kernel driver for modern GPUs |
| `nvidia-gl-G06` | OpenGL libraries |
| `nvidia-driver-G06-kmp-default` | Kernel module package |
| `nvidia-compute-G06` | CUDA runtime |
| `nvidia-prime` | Hybrid graphics switching |
| `nvidia-driver-G05` | Driver for older GPUs |
