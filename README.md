# Sync Waywallen Colors Wallust

Automatically sync your KDE Plasma colors with your Wallpaper Engine wallpapers using **Wallust**.

## ✨ Features

* 🎨 Automatically extracts colors from your current Wallpaper Engine wallpaper
* 🌈 Updates your KDE Plasma color scheme automatically
* ⚡ Runs in the background using a systemd user service
* 🐧 Supports Debian/Ubuntu, Fedora, and Arch Linux
* 🔧 Fully configurable through environment variables
* 🖼️ Supports Wallpaper Engine Workshop content

## 📦 Installation

Clone the repository:

```bash
git clone https://github.com/KzyMX/sync-waywallen-colors-wallust.git
cd sync-waywallen-colors-wallust
```

Run the installer:

```bash
chmod +x install.sh
./install.sh
```

The installer will:

* Detect your package manager (`apt`, `dnf`, or `pacman`)
* Install all required system dependencies
* Install Wallust (via AUR on Arch, Cargo on Fedora/Debian)
* Copy scripts to `~/.local/bin/`
* Install and enable the systemd user service

## 🛠️ Manual Installation

If you prefer to install everything manually:

```bash
mkdir -p ~/.local/bin
mkdir -p ~/.config/systemd/user/ 

chmod +x sync-waywallen-colors watch-waywallen.sh 
cp sync-waywallen-colors watch-waywallen.sh ~/.local/bin/
cp waywallen-colors.service ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now waywallen-colors.service
```

> Make sure all required dependencies and Wallust are installed before starting the service.

## 📖 Usage

### Automatic (Recommended)

Once installed, the service runs automatically in the background.

Simply change your wallpaper in **Wallpaper Engine** and KDE Plasma will automatically update its colors.

### Manual Sync

You can force a color extraction for a specific image or folder at any time:

```bash
sync-waywallen-colors /path/to/image.jpg
```

Or:

```bash
sync-waywallen-colors /path/to/folder
```

### Service Management

Check the service status:

```bash
systemctl --user status waywallen-colors.service
```

Start the service:

```bash
systemctl --user start waywallen-colors.service
```

Stop the service:

```bash
systemctl --user stop waywallen-colors.service
```

Restart the service:

```bash
systemctl --user restart waywallen-colors.service
```

View the service logs:

```bash
journalctl --user -u waywallen-colors.service -n 50
```

Follow the logs in real time:

```bash
journalctl --user -u waywallen-colors.service -f
```

## 🔧 Configuration

You can override the default behavior using environment variables. This is useful for systemd overrides or manual runs.

| Variable         | Default       | Description                                        |
| ---------------- | ------------- | -------------------------------------------------- |
| `STEAM_WE_DIR`   | Auto-detected | Custom Wallpaper Engine Workshop content path      |
| `SCHEME_NAME`    | `Wallust`     | KDE color scheme name                              |
| `RECENT_MINUTES` | `2`           | Minutes to look back for recent wallpaper previews |
| `MAXPX`          | `500`         | Maximum thumbnail size used for color analysis     |

### Example

```bash
export STEAM_WE_DIR="$HOME/.steam/steam/steamapps/workshop/content/431960"
export SCHEME_NAME="Wallust"
export RECENT_MINUTES=2
export MAXPX=500
```

## 🤝 Contributing

Contributions are highly encouraged! This project aims to be community-driven.

### How to Contribute

1. Fork this repository.
2. Create a feature branch:

```bash
git checkout -b feature/my-improvement
```

3. Commit your changes:

```bash
git commit -m "Add awesome feature"
```

4. Push your branch to your fork:

```bash
git push origin feature/my-improvement
```

5. Open a Pull Request describing your changes.

### Areas Where Help Is Needed

* 🚧 **Flatpak Steam support** – Detect and handle Flatpak Steam Workshop paths
* 🎨 **Additional color scheme backends** – GNOME, Hyprland, Sway, etc.
* 🐛 **Bug fixes and edge-case handling**
* 📝 **Documentation improvements**
* 🧪 **Testing across different distributions and KDE Plasma versions**

## 🐛 Reporting Bugs

Found a bug? Please open an **Issue** with:

* Your Linux distribution and version
* Your KDE Plasma version
* Steps to reproduce the issue
* Output of:

```bash
journalctl --user -u waywallen-colors.service -n 50
```

* Any relevant error messages

If you fix a bug yourself, please submit a Pull Request instead of just reporting it. We would love to review and merge your fix!

## 🙏 Acknowledgments

* **Waywallen** – The essential bridge between Wallpaper Engine and Linux
* **Wallust** – Fast, intelligent color scheme generation
* **KDE Plasma Team** – For its excellent theming APIs

---

Made with ❤️ for the Linux desktop customization community.
