# NVIDIA GPU on openSUSE Tumbleweed

Setup guide for NVIDIA GPUs on Tumbleweed laptops and desktops, including driver installation, hybrid graphics, and Secure Boot compatibility.

## Tested Hardware

| GPU | Driver | Status |
|-----|--------|--------|
| RTX 3050 (Laptop) | nvidia-open-driver-G06-signed-kmp-default | Working |

## Driver Series

| Series | GPUs | Package |
|--------|------|---------|
| G07 | RTX 50xx (Blackwell+) | `nvidia-open-driver-G07-signed-kmp-default` |
| G06 | GTX 10xx, 16xx, RTX 20xx/30xx/40xx | `nvidia-open-driver-G06-signed-kmp-default` |
| G05 | GTX 600-900 series (Kepler/Maxwell) | `nvidia-open-driver-G05-signed-kmp-default` |

## 1. Driver Installation

The kernel module is in the openSUSE Oss repository. Userspace packages (`nvidia-smi`, OpenGL/Vulkan libs) require the NVIDIA repo.

### Add NVIDIA Repository

```bash
sudo zypper addrepo --refresh https://download.nvidia.com/opensuse/tumbleweed NVIDIA
sudo zypper ref
```

### Install Packages

```bash
# Modern GPUs (GTX 10xx, 16xx, RTX 20xx/30xx/40xx)
sudo zypper install nvidia-open-driver-G06-signed-kmp-default nvidia-video-G06 nvidia-compute-utils-G06 nvidia-settings

# Newest GPUs (RTX 50xx)
sudo zypper install nvidia-open-driver-G07-signed-kmp-default nvidia-video-G07 nvidia-compute-utils-G07 nvidia-settings
```

Reboot after installation.

### Verify

```bash
nvidia-smi
```

## 2. Secure Boot

The open-source signed drivers (`nvidia-open-driver-*-signed-kmp-default`) are compatible with Secure Boot. No need to disable it or enroll custom MOKs for the NVIDIA driver itself.

After kernel updates, the system may prompt for MOK enrollment for other modules. The password is your **root password**.

## 3. Hybrid Graphics (Laptop)

For laptops with Intel/AMD integrated + NVIDIA discrete:

```bash
sudo zypper install suse-prime
```

Switch GPUs:

```bash
sudo prime-select nvidia
sudo prime-select intel
```

Run individual applications on the NVIDIA GPU:

```bash
prime-run <application>
```

## 4. Fix: Black Screen After Driver Install

### Rebuild Kernel Modules

If the driver installed but the module didn't build:

```bash
sudo zypper install -f nvidia-open-driver-G06-signed-kmp-default
```

### Blacklist Nouveau

Should be automatic, but verify:

```bash
cat /etc/modprobe.d/50-nvidia-default.conf
cat /etc/dracut.conf.d/50-nvidia.conf
```

If missing, create both (modprobe blacklist alone is not enough - nouveau must also be omitted from the initrd):

```bash
echo "blacklist nouveau" | sudo tee /etc/modprobe.d/50-nvidia-default.conf
echo 'omit_drivers+=" nouveau "' | sudo tee /etc/dracut.conf.d/50-nvidia.conf
sudo dracut -f
```

On BLS systems, also rebuild the EFI initrd:

```bash
sudo kernel-install add $(uname -r) /usr/lib/modules/$(uname -r)/vmlinuz
```

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
echo "options nvidia-drm modeset=1" | sudo tee /etc/modprobe.d/nvidia-drm.conf
sudo dracut -f
```

## Package Reference

| Package | Repo | Purpose |
|---------|------|---------|
| `nvidia-open-driver-G06-signed-kmp-default` | Oss | Open-source signed kernel driver (GTX 10xx+, RTX) |
| `nvidia-open-driver-G07-signed-kmp-default` | Oss | Open-source signed kernel driver (RTX 50xx) |
| `nvidia-open-driver-G05-signed-kmp-default` | Oss | Open-source signed kernel driver (GTX 600-900) |
| `nvidia-video-G06` | NVIDIA | Userspace libs, `nvidia-smi`, OpenGL/Vulkan |
| `nvidia-compute-utils-G06` | NVIDIA | CUDA runtime and compute utilities |
| `nvidia-settings` | Oss | NVIDIA settings GUI |
| `suse-prime` | Oss | Hybrid graphics switching |
