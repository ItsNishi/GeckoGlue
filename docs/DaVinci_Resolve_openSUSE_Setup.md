# DaVinci Resolve on openSUSE Tumbleweed

Setup guide for DaVinci Resolve with automatic GPU detection and driver installation.

## Prerequisites

- openSUSE Tumbleweed (rolling release)
- Intel Arc, AMD Radeon, or NVIDIA GPU
- Minimum 16GB RAM recommended
- SSD storage for cache/scratch

## 1. GPU Driver Setup

The fix script automatically detects your GPU and installs the appropriate drivers. Manual installation instructions below:

### Intel Arc / UHD Graphics

```bash
# Install Intel GPU tools and VA-API
sudo zypper install intel-gpu-tools libva-utils

# Install Intel OpenCL Runtime
sudo zypper install intel-opencl ocl-icd-devel

# Install Vulkan support
sudo zypper install libvulkan_intel vulkan-tools
```

### AMD Radeon

```bash
# Install AMD GPU tools and VA-API
sudo zypper install libva-utils

# Install AMD OpenCL Runtime (ROCm + Mesa)
sudo zypper install rocm-opencl rocm-opencl-devel Mesa-libRusticlOpenCL

# Install Vulkan support
sudo zypper install libvulkan_radeon vulkan-tools libdrm_amdgpu1
```

### NVIDIA GeForce / Quadro

```bash
# Install NVIDIA proprietary driver
sudo zypper install nvidia-driver-G06-kmp-default nvidia-compute-G06 nvidia-gl-G06

# Install OpenCL support
sudo zypper install ocl-icd-devel
```

### Verify GPU Detection

```bash
# Check OpenCL platforms (should show Intel)
clinfo | head -20

# Check VA-API (hardware video decode/encode)
vainfo

# Check Vulkan
vulkaninfo --summary
```

**Expected output:** At least 1 OpenCL platform with Intel device.

### Kernel Parameters (Optional)

For newer Battlemage GPUs, ensure you're on kernel 6.12+ and add boot parameter if needed:

```bash
# Edit GRUB config
sudo vim /etc/default/grub

# Add to GRUB_CMDLINE_LINUX_DEFAULT:
i915.force_probe=*
```

Then regenerate GRUB:
```bash
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
```

## 2. Install Dependencies

```bash
# Required libraries
sudo zypper install libxcb-cursor0 libxcb-damage0 libxcb-util1 \
    libxkbcommon-x11-0 libapr1-0 libapr-util1-0 libglvnd \
    libgdk_pixbuf-2_0-0 libfuse2 ocl-icd-devel

# Font rendering (required for UI)
sudo zypper install google-noto-sans-fonts liberation-fonts
```

## 3. Download DaVinci Resolve

1. Go to [Blackmagic Design Downloads](https://www.blackmagicdesign.com/support/family/davinci-resolve-and-fusion)
2. Download "DaVinci Resolve for Linux" (ZIP file)
3. Extract and run installer:

```bash
cd ~/Downloads
unzip DaVinci_Resolve_*_Linux.zip
chmod +x DaVinci_Resolve_*_Linux.run
sudo ./DaVinci_Resolve_*_Linux.run
```

Default install location: `/opt/resolve`

## 4. Post-Installation Fixes

### Fix GLib Version Mismatch (Tumbleweed-specific)

openSUSE Tumbleweed ships newer GLib (2.80+) than Resolve bundles. This causes symbol lookup errors like:
```
symbol lookup error: /lib64/libpango-1.0.so.0: undefined symbol: g_once_init_leave_pointer
symbol lookup error: /lib64/libgobject-2.0.so.0: undefined symbol: g_dir_unref
```

**Fix:** Remove bundled GLib libraries to use system versions:

```bash
sudo mkdir -p /opt/resolve/libs/disabled
sudo mv /opt/resolve/libs/libgmodule-2.0.so* /opt/resolve/libs/disabled/
sudo mv /opt/resolve/libs/libgobject-2.0.so* /opt/resolve/libs/disabled/
sudo mv /opt/resolve/libs/libgio-2.0.so* /opt/resolve/libs/disabled/
sudo mv /opt/resolve/libs/libglib-2.0.so* /opt/resolve/libs/disabled/
```

All four GLib libraries must be moved in the correct order to avoid dependency issues.

**Revert if needed:**
```bash
sudo mv /opt/resolve/libs/disabled/libg*.so* /opt/resolve/libs/
```

### Permissions

```bash
# Add user to video group
sudo usermod -aG video $USER

# Set proper permissions for DaVinci panels (if using hardware)
sudo cp /opt/resolve/share/etc/udev/rules.d/*.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

## 5. Launch DaVinci Resolve

```bash
# From terminal (see errors if any)
/opt/resolve/bin/resolve

# Or use desktop shortcut
# Applications > Multimedia > DaVinci Resolve
```

## 6. Configuration

### GPU Selection

1. DaVinci Resolve > Preferences > Memory and GPU
2. Select your GPU from the list
3. Set GPU Processing Mode:
   - **Intel/AMD**: OpenCL
   - **NVIDIA**: CUDA (preferred) or OpenCL

### Optimize for Intel Arc

- **Decode Options:** Enable "Use hardware acceleration for decode"
- **Encode Options:** Intel QSV should be available for H.264/H.265 export
- **Timeline Resolution:** Start with 1080p for testing
- **Optimized Media:** Use DNxHR or ProRes proxies for 4K+ projects

### Project Settings

- Frame rate: Match your source footage
- Timeline format: Use "Automatic" for best results
- Color science: DaVinci YRGB (standard) or DaVinci YRGB Color Managed (advanced)

## Troubleshooting

### "Unsupported GPU Processing Mode"

Resolve fails to initialize GPU with this error when OpenCL packages are missing or incomplete.

**Intel GPU:**
```bash
sudo zypper install intel-opencl ocl-icd-devel

# CRITICAL: Symlink Intel ICD (Tumbleweed installs to wrong location)
sudo ln -s /usr/share/OpenCL/vendors/intel.icd /etc/OpenCL/vendors/intel.icd

# Verify Intel appears
clinfo | grep -E "Platform Name|Device Name"
```

**AMD GPU:**
```bash
sudo zypper install rocm-opencl Mesa-libRusticlOpenCL ocl-icd-devel
```

**NVIDIA GPU:**
```bash
sudo zypper install nvidia-driver-G06-kmp-default nvidia-compute-G06
# Reboot required for driver to load
```

Relaunch Resolve after installation. Go to Preferences > Memory and GPU and set GPU Processing Mode accordingly.

### "No OpenCL devices found"

```bash
# Verify OpenCL platforms
clinfo

# If empty, reinstall based on your GPU:
# Intel:
sudo zypper install --force intel-opencl ocl-icd-devel
# AMD:
sudo zypper install --force rocm-opencl Mesa-libRusticlOpenCL
# NVIDIA:
sudo zypper install --force nvidia-compute-G06

# Check ICD files exist
ls /etc/OpenCL/vendors/
# Should contain intel.icd, amdocl64.icd, or nvidia.icd
```

### Crash on Startup

```bash
# Run from terminal to see errors
/opt/resolve/bin/resolve

# Check missing libraries
ldd /opt/resolve/bin/resolve | grep "not found"

# Install missing deps
sudo zypper install <missing-lib>
```

### Poor Performance / Stuttering

- Ensure GPU is detected in Preferences > Memory and GPU
- Check thermal throttling: `intel_gpu_top`
- Reduce timeline proxy mode
- Disable "Show all video frames" in playback settings

### Audio Issues

```bash
# Install PipeWire/ALSA bridges
sudo zypper install pipewire-alsa pipewire-pulseaudio
```

### Database Errors

```bash
# Reset database (destroys projects!)
rm -rf ~/.local/share/DaVinciResolve/

# Or fix permissions
chmod -R u+rw ~/.local/share/DaVinciResolve/
```

## Intel Arc Specific Notes

### Battlemage (B580/B570)

- Requires kernel 6.12+ for full support
- Mesa 24.2+ recommended
- OpenCL via NEO runtime works but still maturing

### Known Limitations (Intel Arc on Linux)

- No hardware AV1 encode in Resolve yet (driver limitation)
- Some effects may fall back to CPU
- Fusion GPU acceleration limited compared to NVIDIA

## Alternative: Flatpak/Container

If library conflicts persist, consider Flatpak version (when available) or container:

```bash
# Using distrobox with compatible base
distrobox create --name resolve-box --image fedora:38
distrobox enter resolve-box
# Install Resolve inside container
```

## Useful Commands

```bash
# Monitor GPU usage
intel_gpu_top

# Check encode/decode caps
vainfo

# Verify OpenCL
clinfo

# Check Resolve logs
cat ~/.local/share/DaVinciResolve/logs/*.log | tail -100
```

## References

- [Blackmagic Forum - Linux](https://forum.blackmagicdesign.com/viewforum.php?f=21)
- [Intel Compute Runtime](https://github.com/intel/compute-runtime)
- [openSUSE Wiki - DaVinci Resolve](https://en.opensuse.org/SDB:DaVinci_Resolve)
