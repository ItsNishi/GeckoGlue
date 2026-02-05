# 🌵 Gecko Glue

### *Making stubborn apps stick on openSUSE Tumbleweed*

---

> ⚠️ **Work in Progress**
>
> This project is actively being developed. If you have fixes you'd like to see, encounter issues, or want to contribute - please open an issue, submit a PR, or fork the repo and make it your own!
>
> 🖥️ **Note:** These scripts are based on my personal workstation setup. Your mileage may vary - some paths or package names may need adjustment for your system.

---

## 🤔 What Is This?

Tumbleweed's bleeding-edge rolling release ships newer libraries than many applications expect. This causes crashes, missing features, and general headaches.

**Gecko Glue** provides automated scripts and documentation to bridge the gap between Tumbleweed and stubborn software.

## 🎯 Supported Applications

| Application | Status | Issues Fixed |
|-------------|--------|--------------|
| 🎮 Unity3D | ✅ Working | SSL certs, libxml2, Asset Store links |
| 🎬 DaVinci Resolve | ✅ Working | GLib mismatch, Intel Arc OpenCL, VA-API |
| 🖨️ Epson Printers | ✅ Working | Epson Scan 2 crash, IPP setup |
| 🖥️ NVIDIA GPU | ✅ Working | Driver install, hybrid graphics, secure boot |
| 🔧 System Updates | ✅ Fixed | Missing measure-pcr-prediction with SELinux + GRUB |

## 🚀 Quick Start

```bash
# Clone the repo
git clone https://github.com/ItsNishi/GeckoGlue.git
cd GeckoGlue

# Make scripts executable
chmod +x scripts/*.sh

# Run the fix you need
sudo ./scripts/fix-unity3d.sh
sudo ./scripts/fix-davinci-resolve.sh
sudo ./scripts/fix-epson.sh
sudo ./scripts/fix-nvidia.sh
sudo ./scripts/fix-measure-pcr.sh
```

## 📜 Scripts

### 🎮 fix-unity3d.sh

Fixes for Unity Hub and Unity Editor:

| Fix | Description |
|-----|-------------|
| 🔐 SSL Certificate Path | Symlinks `/etc/ssl/ca-bundle.pem` → `/etc/ssl/certs/ca-certificates.crt` |
| 📚 libxml2 Compatibility | Symlinks `libxml2.so.16` → `libxml2.so.2` |
| 🛒 Asset Store Protocol | Registers `com.unity3d.kharma://` URI handler |
| 📦 Dependencies | Installs GTK, X11, and audio libraries |

### 🎬 fix-davinci-resolve.sh

Fixes for DaVinci Resolve with automatic GPU detection:

| Fix | Description |
|-----|-------------|
| 🎮 GPU Detection | Automatically detects Intel, AMD, or NVIDIA GPU |
| 🔧 GLib Mismatch | Moves bundled GLib to use system versions |
| 🖥️ GPU Drivers | Installs appropriate OpenCL/CUDA runtime for your GPU |
| 🎥 VA-API | Hardware video decode/encode support |
| 📦 Dependencies | Installs required Resolve libraries |
| 👤 Permissions | Installs udev rules for GPU access |

**Supported GPUs:**
- **Intel**: Arc, Iris Xe, UHD Graphics (OpenCL via intel-compute-runtime)
- **AMD**: Radeon RX, Vega, Polaris (OpenCL via ROCm/Mesa)
- **NVIDIA**: GeForce, Quadro, RTX (CUDA via proprietary driver)

### 🖨️ fix-epson.sh

Fixes for Epson all-in-one printers and scanners:

| Fix | Description |
|-----|-------------|
| 🔧 Epson Scan 2 | Installs 32-bit Qt5 libraries to fix crash on launch |
| 🖨️ IPP Printer Setup | Interactive setup for network printing via IPP Everywhere |
| 🧪 Test Print | Optional test page to verify setup |

**Tested Models:**
- Epson XP-5200 (WiFi)

### 🖥️ fix-nvidia.sh

NVIDIA GPU driver installation with hybrid graphics support:

| Fix | Description |
|-----|-------------|
| 🔍 GPU Detection | Auto-detects NVIDIA GPU and selects driver series (G05/G06) |
| 🔒 Secure Boot Check | Warns if Secure Boot is enabled |
| 📦 Hardware Repo | Adds openSUSE hardware repository |
| 🖥️ Driver Install | Installs NVIDIA driver and OpenGL libraries |
| 🚫 Nouveau Blacklist | Blacklists nouveau to prevent conflicts |
| 💻 Hybrid Graphics | Optional PRIME setup for laptops |

**Supported GPUs:**
- **G06**: GTX 10xx, 16xx, RTX 20xx/30xx/40xx/50xx
- **G05**: GTX 600-900 series

### 🔧 fix-measure-pcr.sh

Fixes missing measure-pcr-prediction error during updates:

| Fix | Description |
|-----|-------------|
| 🔍 Bootloader Detection | Verifies GRUB is in use (aborts on sd-boot) |
| 🗑️ Package Removal | Removes `sdbootutil-dracut-measure-pcr` |

**Applies to:** GRUB users with SELinux encountering update failures.

## 📖 Documentation

Detailed setup guides available in `docs/`:

- 📄 [Unity3D Setup Guide](docs/Unity3D_openSUSE_Setup.md)
- 📄 [DaVinci Resolve Setup Guide](docs/DaVinci_Resolve_openSUSE_Setup.md)
- 📄 [Epson Printer/Scanner Setup](docs/Epson_Printer_Scanner_Setup.md)
- 📄 [NVIDIA GPU Setup](docs/NVIDIA_GPU_Setup.md)
- 📄 [Fix: Missing measure-pcr-prediction](docs/Missing_Measure_PCR_Prediction.md)

## 🔥 Common Issues & Quick Fixes

<details>
<summary>🎮 Unity: "Token Exchange failed" / Asset Store not working</summary>

```bash
sudo ln -s /etc/ssl/ca-bundle.pem /etc/ssl/certs/ca-certificates.crt
```
</details>

<details>
<summary>🎮 Unity: "Open in Unity" does nothing in browser</summary>

```bash
xdg-mime default unityhub.desktop x-scheme-handler/com.unity3d.kharma
```
</details>

<details>
<summary>🎬 Resolve: "Unsupported GPU Processing Mode"</summary>

**Intel GPU:**
```bash
sudo zypper install intel-opencl ocl-icd-devel
```

**AMD GPU:**
```bash
sudo zypper install rocm-opencl Mesa-libRusticlOpenCL ocl-icd-devel
```

**NVIDIA GPU:**
```bash
sudo zypper install nvidia-driver-G06-kmp-default nvidia-compute-G06
```
</details>

<details>
<summary>🎬 Resolve: Symbol lookup errors (g_once_init_leave_pointer)</summary>

```bash
sudo mkdir -p /opt/resolve/libs/disabled
sudo mv /opt/resolve/libs/libgmodule-2.0.so* /opt/resolve/libs/disabled/
sudo mv /opt/resolve/libs/libgobject-2.0.so* /opt/resolve/libs/disabled/
sudo mv /opt/resolve/libs/libgio-2.0.so* /opt/resolve/libs/disabled/
sudo mv /opt/resolve/libs/libglib-2.0.so* /opt/resolve/libs/disabled/
```
</details>

<details>
<summary>🖨️ Epson Scan 2: Crashes immediately after opening</summary>

```bash
sudo zypper install libQt5Widgets5-32bit
```
</details>

<details>
<summary>🖨️ Epson: Add network printer via IPP</summary>

```bash
sudo lpadmin -p "EPSON_XP5200" -E \
    -v "ipp://<PRINTER_IP>:631/ipp/print" \
    -m everywhere -D "Epson XP-5200"
```
</details>

## 🤝 Contributing

This is a community effort! Here's how you can help:

- 🐛 **Found a bug?** Open an issue
- 💡 **Have a fix for another app?** Submit a PR
- 🔀 **Want to take it your own direction?** Fork it!
- 💬 **Questions or suggestions?** Start a discussion

Every contribution helps make Tumbleweed more accessible for creative work.

## 📝 License

MIT - Do whatever you want with it.

---

<p align="center">
  <i>Made with 🩹 and ☕ by frustrated Tumbleweed users</i>
</p>
