# DaVinci Resolve on openSUSE Tumbleweed

Setup guide for DaVinci Resolve with Intel Arc GPU (Battlemage/Alchemist).

## Prerequisites

- openSUSE Tumbleweed (rolling release)
- Intel Arc GPU (or NVIDIA with proprietary drivers)
- Minimum 16GB RAM recommended
- SSD storage for cache/scratch

## 1. GPU Driver Setup (Intel Arc)

### Install Intel Media and Compute Stack

```bash
# Install Intel GPU tools and VA-API
sudo zypper install intel-gpu-tools libva-utils

# Install Intel Compute Runtime (OpenCL/Level Zero)
sudo zypper install intel-opencl intel-compute-runtime level-zero-loader

# Install Vulkan support
sudo zypper install libvulkan_intel vulkan-tools
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
    libxkbcommon-x11-0 libapr1 libaprutil1 libglvnd \
    libgdk_pixbuf-2_0-0 libfuse2 ocl-icd-devel

# Font rendering
sudo zypper install google-noto-sans-fonts liberation-fonts

# Optional: CUDA support (NVIDIA only)
# sudo zypper install cuda
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
sudo mv /opt/resolve/libs/libglib-2.0.so* /opt/resolve/libs/disabled/
sudo mv /opt/resolve/libs/libgobject-2.0.so* /opt/resolve/libs/disabled/
sudo mv /opt/resolve/libs/libgio-2.0.so* /opt/resolve/libs/disabled/
```

Note: `libgmodule-2.0.so*` is not bundled with Resolve, so no action needed for it.

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
2. Select your Intel Arc GPU
3. Set GPU Processing Mode to "OpenCL" (not CUDA for Intel)

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

```bash
# Install Intel OpenCL stack
sudo zypper install intel-compute-runtime intel-opencl ocl-icd-devel
```

Relaunch Resolve after installation. Go to Preferences > Memory and GPU and set GPU Processing Mode to "OpenCL".

### "No OpenCL devices found"

```bash
# Verify Intel Compute Runtime
clinfo

# If empty, reinstall:
sudo zypper install --force intel-compute-runtime intel-opencl ocl-icd-devel

# Check ICD files exist
ls /etc/OpenCL/vendors/
# Should contain intel.icd or similar
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
