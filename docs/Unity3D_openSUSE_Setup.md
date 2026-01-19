# Unity3D on openSUSE Tumbleweed

Installation and configuration guide for Unity Hub and Unity Editor on openSUSE Tumbleweed.

## Prerequisites

- openSUSE Tumbleweed
- 64-bit system with SSE2 support
- GPU with OpenGL 3.2+ or Vulkan support
- Minimum 8GB RAM (16GB+ recommended)
- SSD storage for projects and cache

## 1. Install Dependencies

```bash
# Core libraries
sudo zypper install libgtk-2_0-0 libgtk-3-0 libgdk_pixbuf-2_0-0 \
    libglib-2_0-0 libgobject-2_0-0 libgio-2_0-0

# X11 and graphics
sudo zypper install libX11-6 libXcursor1 libXrandr2 libXi6 libXinerama1 \
    libXfixes3 libXrender1 libXext6 libXcomposite1 libXdamage1

# Audio
sudo zypper install alsa alsa-plugins libasound2

# Networking and security
sudo zypper install libcurl4 mozilla-nss mozilla-nspr ca-certificates

# Build tools (for IL2CPP and native plugins)
sudo zypper install -t pattern devel_C_C++

# Additional
sudo zypper install libfuse2 libpng16-16 libjpeg8 libfreetype6
```

## 2. Fix Library Compatibility (Tumbleweed-specific)

### SSL Certificate Path

Unity expects Debian/Ubuntu certificate path (`/etc/ssl/certs/ca-certificates.crt`), but openSUSE uses `/etc/ssl/ca-bundle.pem`. Without this fix, Unity services fail with:
```
Curl error 35: Cert handshake failed. Fatal error. UnityTls error code: 7
Error reading ca cert file from /etc/ssl/certs/ca-certificates.crt (0)
```

```bash
# Create compatibility symlink
sudo ln -s /etc/ssl/ca-bundle.pem /etc/ssl/certs/ca-certificates.crt
```

### libxml2 Symlink

openSUSE Tumbleweed ships libxml2 with a different soname than Unity expects.

```bash
# Create compatibility symlink
sudo ln -s /lib64/libxml2.so.16 /lib64/libxml2.so.2
```

**Note:** These symlinks survive system updates unless the libraries change major version.

### Verify the fix

```bash
# Should show no "not found" entries
ldd ~/Unity/Hub/Editor/*/Editor/Unity 2>&1 | grep "not found"
```

## 3. Install Unity Hub

### Option A: AppImage (Recommended)

```bash
# Download from Unity website
# https://unity.com/download

# Make executable
chmod +x UnityHub.AppImage

# Run
./UnityHub.AppImage

# Or install system-wide
sudo mv UnityHub.AppImage /opt/unityhub/UnityHub.AppImage
```

### Option B: Manual Extraction

```bash
# Download the .deb or tarball from Unity
# Extract and place in /opt/unityhub

# Create launcher script
cat << 'EOF' | sudo tee /usr/local/bin/unityhub
#!/bin/bash
/opt/unityhub/unityhub-bin "$@"
EOF
sudo chmod +x /usr/local/bin/unityhub
```

### Desktop Entry

```bash
cat << 'EOF' > ~/.local/share/applications/unityhub.desktop
[Desktop Entry]
Name=Unity Hub
Exec=/opt/unityhub/unityhub %U
Terminal=false
Type=Application
Icon=unityhub
StartupWMClass=unityhub
Comment=The Official Unity Hub
Categories=Development;
MimeType=x-scheme-handler/unityhub;x-scheme-handler/com.unity3d.kharma;
EOF

# Register the kharma protocol (for Asset Store "Open in Unity" links)
update-desktop-database ~/.local/share/applications/
xdg-mime default unityhub.desktop x-scheme-handler/com.unity3d.kharma
```

## 4. Install Unity Editor

1. Launch Unity Hub
2. Sign in with Unity account
3. Go to **Installs** > **Install Editor**
4. Select desired version (LTS recommended for stability)
5. Choose modules:
   - **Linux Build Support (IL2CPP)** - for Linux builds
   - **Linux Build Support (Mono)** - for Linux builds
   - **WebGL Build Support** - for browser games
   - **Documentation** - offline docs
   - **Android/iOS** - if targeting mobile

Default install path: `~/Unity/Hub/Editor/<version>/`

## 5. GPU Configuration

### Intel Arc (Battlemage/Alchemist)

```bash
# Install Intel GPU stack
sudo zypper install intel-gpu-tools libva-utils vulkan-tools \
    intel-opencl intel-compute-runtime level-zero-loader

# Verify
vulkaninfo --summary
clinfo | head -20
```

### NVIDIA

```bash
# Add NVIDIA repo and install drivers
sudo zypper addrepo --refresh \
    'https://download.nvidia.com/opensuse/tumbleweed' NVIDIA
sudo zypper install nvidia-video-G06 nvidia-gl-G06

# Reboot required
```

### AMD

```bash
# Open source drivers (default in kernel)
# Install Vulkan support
sudo zypper install vulkan-radeon libvulkan_radeon

# Verify
vulkaninfo --summary
```

## 6. Unity Editor Settings

### Graphics API

1. **Edit** > **Project Settings** > **Player**
2. Under **Other Settings** > **Rendering**:
   - Uncheck "Auto Graphics API for Linux"
   - Set order: **Vulkan**, OpenGLCore
   - Vulkan performs better on modern GPUs

### Editor Preferences

1. **Edit** > **Preferences**
2. **General**:
   - Script Changes While Playing: Stop Playing and Recompile
3. **External Tools**:
   - External Script Editor: Configure your IDE (Rider, VS Code, etc.)
4. **GI Cache**:
   - Set cache location to SSD for faster lighting builds

## 7. Project Creation

### From Unity Hub

1. Click **New Project**
2. Select template (2D, 3D, URP, HDRP)
3. Choose location (SSD recommended)
4. Click **Create Project**

### From Command Line

```bash
# Create project
~/Unity/Hub/Editor/6000.3.4f1/Editor/Unity \
    -createProject /path/to/MyProject

# Open existing project
~/Unity/Hub/Editor/6000.3.4f1/Editor/Unity \
    -projectPath /path/to/MyProject
```

### Headless/Batch Mode

```bash
# Build project in batch mode
~/Unity/Hub/Editor/6000.3.4f1/Editor/Unity \
    -batchmode \
    -nographics \
    -projectPath /path/to/MyProject \
    -executeMethod BuildScript.Build \
    -quit \
    -logFile /tmp/unity_build.log
```

## 8. IDE Integration

### JetBrains Rider (Recommended)

1. Install Rider
2. In Unity: **Edit** > **Preferences** > **External Tools**
3. Set External Script Editor to Rider
4. Enable "Generate .csproj files for: All packages"

### VS Code

```bash
# Install extensions
code --install-extension ms-dotnettools.csharp
code --install-extension unity.unity-debug
```

In Unity Preferences, select VS Code as external editor.

## Troubleshooting

### "Unable to load library" Errors

```bash
# Check what's missing
ldd ~/Unity/Hub/Editor/*/Editor/Unity 2>&1 | grep "not found"

# Find and install missing library
zypper search <library-name>
sudo zypper install <package>
```

### Hub Won't Start

```bash
# Run from terminal to see errors
/opt/unityhub/unityhub-bin

# Clear cache if corrupted
rm -rf ~/.config/unityhub/Cache
rm -rf ~/.config/unityhub/blob_storage
```

### Editor Crashes on Project Load

```bash
# Check logs
cat ~/.config/unity3d/Editor.log | tail -200

# Try safe mode
~/Unity/Hub/Editor/*/Editor/Unity -safeMode -projectPath /path/to/project
```

### Black Screen in Game View

- Switch Graphics API: Project Settings > Player > Vulkan instead of OpenGL
- Update GPU drivers
- Check: `glxinfo | grep "OpenGL version"`

### Slow Shader Compilation

```bash
# Increase shader cache size
# Edit > Preferences > GI Cache > Maximum Cache Size

# Or pre-warm shaders in Player Settings
# Player > Other Settings > Shader Variant Loading
```

### Asset Import Failures

```bash
# Clear Library folder (forces reimport)
rm -rf /path/to/project/Library

# Open project - will reimport all assets
```

### License Issues

```bash
# Check license status
ls ~/.local/share/unity3d/Unity/

# Manual license activation
~/Unity/Hub/Editor/*/Editor/Unity -manualLicenseFile /path/to/license.ulf
```

### Token Exchange / Asset Store Errors

Errors like `UnityConnectWebRequestException: Token Exchange failed` or `Could not read file com.unity3d.kharma` indicate SSL certificate issues.

```bash
# Check if symlink exists
ls -la /etc/ssl/certs/ca-certificates.crt

# If missing, create it
sudo ln -s /etc/ssl/ca-bundle.pem /etc/ssl/certs/ca-certificates.crt

# Restart Unity Editor after fix
```

This resolves:
- Token exchange failures
- Asset Store "Open in Unity" not working
- Package Manager authentication errors

## Performance Tips

### General

- Use SSD for project location
- Set `Library/` folder exclusion in antivirus
- Close unnecessary background applications

### Large Projects

- Enable **Asset Database v2** (default in Unity 2019.3+)
- Use **Accelerator** for team cache sharing
- Set **Compress Assets on Import** based on needs

### Build Times

```bash
# Use IL2CPP incremental builds
# Player Settings > Other > IL2CPP Code Generation: Faster (smaller) builds

# Parallel asset importing
# Preferences > Asset Pipeline > Parallel Import
```

## Useful Paths

| Purpose | Path |
|---------|------|
| Unity Hub config | `~/.config/unityhub/` |
| Unity preferences | `~/.config/unity3d/` |
| Editor logs | `~/.config/unity3d/Editor.log` |
| Project logs | `<project>/Logs/Editor.log` |
| License files | `~/.local/share/unity3d/Unity/` |
| Asset Store cache | `~/.local/share/unity3d/Asset Store-5.x/` |
| Global cache | `~/.config/unity3d/cache/` |

## Command Line Arguments

| Argument | Description |
|----------|-------------|
| `-projectPath <path>` | Open specific project |
| `-createProject <path>` | Create new project |
| `-batchmode` | Run without UI |
| `-nographics` | No GPU initialization |
| `-quit` | Exit after command completes |
| `-logFile <path>` | Redirect log output |
| `-executeMethod <method>` | Run static C# method |
| `-buildTarget <target>` | Set build platform |
| `-safeMode` | Launch in safe mode |

## References

- [Unity Manual - Linux](https://docs.unity3d.com/Manual/GettingStartedInstallingUnity.html)
- [Unity Forum - Linux](https://forum.unity.com/forums/linux.93/)
- [Unity Hub CLI](https://docs.unity3d.com/hub/manual/HubCLI.html)
