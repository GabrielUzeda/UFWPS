# Ultimate Fedora Workstation Post Script (UFWPS)

A powerful and user-friendly post-installation script for Fedora Workstation that helps you set up your system with optimal configurations, essential software, and performance tweaks.

Targeted at **Fedora Workstation 45** (GNOME 51).

<div align="center">
  <img src="screenshot.png" alt="UFWPS Screenshot" width="800"/>
</div>

## 🚀 Features

### Repository Management
- Automatic RPM Fusion (free and nonfree) repository setup
- Terra repository setup
- Multimedia codec repository configuration
- Optimized repository settings for better package management

### System Optimizatione
- Hardware acceleration setup for Intel and AMD processors
- Mesa driver optimization with freeworld VA-API and Vulkan drivers for better performance
- Custom TKG kernel installation with CPU-specific optimizations
- Performance mitigations management (optional)
- Battery optimization using TLP (for laptops)
- System update and firmware updates
- Faster boot time optimization
- Deep Sleep (S3) power management
- Dual boot timezone fix

### Desktop Environment
- GNOME extensions installation:
  - App Indicators Support
  - Clipboard Indicator
  - Caffeine
  - Fuzzy App Search
  - Do Not Disturb While Screen Sharing or Recording

### Theming
- Graphite GTK theme installation
- Papirus icon theme
- Custom wallpapers for light and dark modes
- Elegant GRUB theme with blur effect

### Hardware Support
- NVIDIA driver installation with CUDA support
- Advanced hardware acceleration support:
  - VA-API and VDPAU drivers
  - Intel Media Driver for 5th gen and newer
  - Mesa freeworld VA-API and Vulkan drivers for AMD
- OpenH264 codec support for Firefox
- Multimedia codecs and hardware acceleration

### System Cleanup
- Removal of unnecessary applications
- Optimization of startup services
- Configurable debloating options
- NetworkManager optimization
- Optional service debloat for GNOME (`gnome-debloat.sh`, run `sudo ./gnome-debloat.sh --list`; details in [docs/servicos-gnome.md](docs/servicos-gnome.md))

## 🛠️ Installation

1. Clone this repository:
```bash
git clone https://github.com/gsuzeda/UFWPS.git
```

2. Navigate to the directory:
```bash
cd UFWPS
```

3. Make the script executable:
```bash
chmod +x UFWPS.sh
```

4. Run the script:
```bash
./UFWPS.sh
```

## 📉 GNOME service debloat: measured gains

`gnome-debloat.sh` was measured in a stock Fedora 45 GNOME 51 VM (QEMU/KVM, 4 GB RAM, 4 vCPU). Each sample is a fresh VM booted from a throwaway snapshot: apply the group, reboot, wait 170 s, then sum the PSS of all processes. Every configuration has **5 valid samples**, none discarded (a VM that failed to boot was simply re-run). The value is the **median**; the sample spread is 1-8 MB, so gains under ~10 MB are noise.

| Group | Median idle PSS (MB) | Gain (MB) | Samples |
|---|---|---|---|
| baseline (no group) | 1221 | - | 5 |
| 1 services | 1213 | -8 | 5 |
| 2 power (ppd instead of tuned) | 1182 | -39 | 5 |
| 3 gnome-software on demand | 889 | -332 | 5 |
| 4 indexer | 1218 | -3 | 5 |
| 5 a11y | 1232 | ~0 | 5 |
| 6 vmguest | 1229 | ~0 | 5 |
| 7 calendar/contacts | 1177 | -44 | 5 |
| 8 print | 1215 | ~0 | 5 |
| 9 avahi | 1221 | ~0 | 5 |
| 10 time sync | 1228 | ~0 | 5 |
| 11 firewall (nftables) | 1199 | -22 | 5 |
| 12 ibus engines | 1159 | -62 | 5 |
| 13 smartcard | 1224 | ~0 | 5 |
| **`all` (groups 1-6)** | **833** | **-388 (-32%)** | 5 |
| **all 13 groups** | **667** | **-554 (-45%)** | 5 |

Notes: group 3 stops gnome-software and the daemons it pulls in (flatpak helper, dnf5daemon) from starting at login, which is why it dominates; the individual gains do not add up exactly because of overlap. Groups 5, 6, 8, 9, 10 and 13 show no RAM gain: the services they target either do not run at idle (orca, speech-dispatcher, guest agents) or use only 1-3 MB of PSS (cupsd 3, chronyd 1.5, pcscd 1.6, avahi 1). What they do save is disk, packages and attack surface:

| Group | Disk freed (MB) | Packages removed |
|---|---|---|
| 5 a11y | ~95 | 13 |
| 6 vmguest | ~7 | 8 |
| 8 print | ~73 | 26 |
| 9 avahi | 0 (masked only) | 0 |
| 10 time sync | ~75 | 51 |
| 13 smartcard | ~3 | 5 |

Group 6 only shows this on a VM with the agents installed; on bare metal it removes packages that are not running. A single sample can spike 100-280 MB for reasons outside gnome-software (seen once each in the baseline, g5 and g9), which is why the median is reported. The VM has no physical hardware. Per-service analysis: [docs/servicos-gnome.md](docs/servicos-gnome.md).

## 🌟 Recommendations

### Blur My Shell
Enhance your GNOME desktop with the Blur My Shell extension for a modern and sleek look. Check it out here:
[Blur My Shell](https://github.com/aunetx/blur-my-shell)

### Zsh with Oh My Zsh and/or Oh My Posh
Upgrade your terminal experience with Zsh and powerful customization tools:
- [Oh My Zsh](https://ohmyz.sh/): A delightful framework for managing your Zsh configuration.
- [Oh My Posh](https://ohmyposh.dev/): A prompt theme engine for any shell.

## 🤝 Contributing

Feel free to contribute to this project! Here's how you can help:
- Fork the repository
- Create a new branch (`git checkout -b feature/improvement`)
- Make your changes
- Commit your changes (`git commit -am 'Add new feature'`)
- Push to the branch (`git push origin feature/improvement`)
- Create a Pull Request

## 📝 License

MIT License

Copyright (c) 2025 Uzeda (@gsuzeda)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## 📬 Contact

- GitHub: [@gsuzeda](https://github.com/gsuzeda)
- Telegram: [@Uzeda](https://t.me/Uzeda)

## 🙏 Acknowledgments

This project wouldn't be possible without the amazing work of these projects and their contributors:

- [Graphite GTK Theme](https://github.com/vinceliuice/Graphite-gtk-theme) by vinceliuice
- [Elegant GRUB Theme](https://github.com/vinceliuice/Elegant-grub2-themes) by vinceliuice
- [Papirus Icon Theme](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme)
- [TLP](https://github.com/linrunner/TLP)
- [RPM Fusion](https://rpmfusion.org/)
- [Fedora 41 Post Install Guide](https://github.com/devangshekhawat/Fedora-41-Post-Install-Guide) by devangshekhawat
- [Mesa Freeworld Drivers](https://rpmfusion.org/Howto/Multimedia)
- [NVIDIA Drivers](https://rpmfusion.org/Howto/NVIDIA)
- [Terra Repository](https://terra.fyralabs.com/)
- [Do Not Disturb While Screen Sharing Or Recording](https://github.com/marcinjahn/gnome-do-not-disturb-while-screen-sharing-or-recording-extension)

Special thanks to all GNOME Extension developers and the Fedora community for their continuous contributions to making Linux better for everyone.

---
Made with ❤️ for the Fedora Community
