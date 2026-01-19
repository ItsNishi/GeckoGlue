# Epson Printer/Scanner on openSUSE Tumbleweed

Setup guide for Epson all-in-one printers (XP series, ET series, WF series) with printing and scanning support.

## Tested Hardware

| Model | Printing | Scanning | Connection |
|-------|----------|----------|------------|
| XP-5200 | IPP Everywhere | Epson Scan 2 | WiFi |

## 1. Printer Setup (IPP Driverless)

Modern Epson printers support IPP Everywhere (driverless printing). This is the recommended method.

### Find Your Printer IP

Check your router's DHCP leases or print a network status page from the printer's control panel.

### Add Printer via Command Line

```bash
# Replace IP with your printer's address
sudo lpadmin -p "EPSON_XP5200" -E \
    -v "ipp://<PRINTER_IP>:631/ipp/print" \
    -m everywhere \
    -L "WiFi" \
    -D "Epson XP-5200"

# Set as default printer (optional)
sudo lpadmin -d EPSON_XP5200
```

### Add Printer via YaST

1. Open **YaST Control Center** > **Hardware** > **Printer**
2. In Printer Configurations, click **Add**
3. Click **Connection Wizard** (top right)
4. Select **Internet Printing Protocol (IPP)** under "Access Network Printer or Printserver Box via"
5. Enter URI: `ipp://<PRINTER_IP>/ipp/print`
6. Keep manufacturer as **Generic**, click **OK**
7. In "Find and Assign a Driver", select **Generic IPP Everywhere Printer**
8. Optionally set a name under "Set Arbitrary Name"
9. Click **OK** to finish

Printer should now appear with "Ready" status.

### Verify Printer

```bash
# Check printer status
lpstat -p -d

# Test print
echo "Test page" | lp -d EPSON_XP5200
```

## 2. Scanner Setup (Epson Scan 2)

### Download Epson Scan 2

1. Go to [Epson Linux Drivers](https://download.ebz.epson.net/dsc/search/01/search/?OSC=LX)
2. Search for your model (e.g., "XP-5200")
3. Download "Epson Scan 2" bundle (RPM, 64-bit)
4. Extract and run installer:

```bash
cd ~/Downloads/epsonscan2-bundle-*
chmod +x ./install.sh
sudo ./install.sh
```

### Fix: Application Crashes Immediately

Epson Scan 2 ships as 32-bit and requires 32-bit Qt5 libraries.

**Symptom:** Application opens then closes instantly, or shows library errors.

**Diagnosis:**
```bash
epsonscan2
# Error: libQt5Widgets.so.5: cannot open shared object file
```

**Fix:**
```bash
sudo zypper install libQt5Widgets5-32bit
```

This pulls in all required 32-bit Qt5 dependencies.

### Configure Network Scanner

1. Launch Epson Scan 2
2. Go to Scanner Settings (or it may auto-detect)
3. Add scanner by IP if not detected: `<PRINTER_IP>`

### Verify Scanner

```bash
# Check if scanner is detected
scanimage -L

# Test scan (saves to test.png)
scanimage --format=png > test.png
```

## 3. Alternative: Epson ESC/P-R Driver

If IPP driverless doesn't provide adequate print quality or paper handling options, install the native driver.

### Check Packman Repository

```bash
# Add Packman if not already enabled
sudo zypper ar -cfp 90 \
    https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ \
    packman

# Search for driver
zypper search epson-inkjet-printer-escpr2
```

### Manual Installation from Epson

1. Download from [Epson Linux Drivers](https://download.ebz.epson.net/dsc/search/01/search/?OSC=LX)
2. Search for your model, download "ESC/P-R Driver" (RPM)
3. Install:

```bash
sudo zypper install ./epson-inkjet-printer-escpr2-*.rpm
```

4. Re-add printer selecting the Epson PPD instead of "everywhere"

## Troubleshooting

### Printer Not Found on Network

```bash
# Verify printer is reachable
ping <PRINTER_IP>

# Check if IPP port is open
curl -s -m 5 "http://<PRINTER_IP>:631/" && echo "IPP available"
```

### CUPS Service Issues

```bash
# Check CUPS status
systemctl status cups

# Restart CUPS
sudo systemctl restart cups

# View CUPS logs
journalctl -u cups -f
```

### Scanner Not Detected

```bash
# Check SANE backends
scanimage -L

# Verify network scanner plugin is installed
rpm -qa | grep epsonscan2
```

### Permission Issues

```bash
# Add user to scanner group
sudo usermod -aG lp $USER

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Log out and back in for group changes
```

## Package Reference

| Package | Purpose |
|---------|---------|
| `cups` | Print server |
| `cups-filters` | Driverless printing support |
| `epsonscan2` | Scanner application |
| `epsonscan2-non-free-plugin` | Scanner network plugin |
| `libQt5Widgets5-32bit` | Fix for Epson Scan 2 crash |
| `epson-inkjet-printer-escpr2` | Native print driver (optional) |
