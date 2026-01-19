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

## 🚀 Quick Start

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/GeckoGlue.git
cd GeckoGlue

# Make scripts executable
chmod +x scripts/*.sh

# Run the fix you need
sudo ./scripts/fix-unity3d.sh
sudo ./scripts/fix-davinci-resolve.sh
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
| 👤 Permissions | Adds user to video/render groups |

### 🎬 fix-davinci-resolve.sh

Fixes for DaVinci Resolve (especially Intel Arc GPUs):

| Fix | Description |
|-----|-------------|
| 🔧 GLib Mismatch | Moves bundled GLib to use system versions |
| 🖥️ Intel OpenCL | Installs `intel-compute-runtime`, `intel-opencl`, `ocl-icd-devel` |
| 🎥 VA-API | Hardware video decode/encode support |
| 📦 Dependencies | Installs required Resolve libraries |
| 👤 Permissions | Adds user to video group, installs udev rules |

## 📖 Documentation

Detailed setup guides available in `docs/`:

- 📄 [Unity3D Setup Guide](docs/Unity3D_openSUSE_Setup.md)
- 📄 [DaVinci Resolve Setup Guide](docs/DaVinci_Resolve_openSUSE_Setup.md)

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

```bash
sudo zypper install intel-compute-runtime intel-opencl ocl-icd-devel
```
</details>

<details>
<summary>🎬 Resolve: Symbol lookup errors (g_once_init_leave_pointer)</summary>

```bash
sudo mkdir -p /opt/resolve/libs/disabled
sudo mv /opt/resolve/libs/libglib-2.0.so* /opt/resolve/libs/disabled/
sudo mv /opt/resolve/libs/libgobject-2.0.so* /opt/resolve/libs/disabled/
sudo mv /opt/resolve/libs/libgio-2.0.so* /opt/resolve/libs/disabled/
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
