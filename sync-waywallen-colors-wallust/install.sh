#!/usr/bin/env bash
# install.sh for sync-waywallen-colors-wallust
#
# Supported families:
#   - Debian/Ubuntu and derivatives (apt)
#   - Fedora (dnf)
#   - Arch Linux and derivatives (pacman + AUR)
#
# What it does:
#   1. Installs required dependencies.
#   2. Installs wallust:
#        - Arch: AUR (paru/yay, or installs paru if needed)
#        - Fedora/Debian/Ubuntu: cargo, with rustup fallback if needed
#   3. Creates target directories.
#   4. Installs scripts and systemd user service.
#
# Environment variables:
#   AUR_HELPER=paru|yay   Force preferred AUR helper when both exist.
#   NO_RUSTUP=1           Disable rustup fallback.

set -u -o pipefail
export LC_ALL=C
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="waywallen-colors.service"

AUR_HELPER="${AUR_HELPER:-}"
NO_RUSTUP="${NO_RUSTUP:-0}"
APT_UPDATED=0

log() {
    echo "[install] $*"
}

warn() {
    echo "[install][WARNING] $*" >&2
}

err() {
    echo "[install][ERROR] $*" >&2
}

# ----------------------------------------------------------------------------
# Basic sanity checks
# ----------------------------------------------------------------------------

if [ "$(id -u)" -eq 0 ]; then
    err "Do not run install.sh as root."
    err "Run it as a normal user. It will use sudo only when necessary."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    err "sudo is required to install system packages."
    exit 1
fi

SUDO="sudo"

# ----------------------------------------------------------------------------
# Package manager detection
# ----------------------------------------------------------------------------

PKG=""

if command -v apt-get >/dev/null 2>&1; then
    PKG="apt"
elif command -v dnf >/dev/null 2>&1; then
    PKG="dnf"
elif command -v pacman >/dev/null 2>&1; then
    PKG="pacman"
else
    err "Unsupported distribution/package manager."
    err "Supported: apt, dnf, pacman."
    exit 1
fi

log "Detected package manager: $PKG"

# ----------------------------------------------------------------------------
# Package installation helpers
# ----------------------------------------------------------------------------

apt_install() {
    if [ "$APT_UPDATED" -eq 0 ]; then
        $SUDO apt-get update -y
        APT_UPDATED=1
    fi
    $SUDO apt-get install -y "$@"
}

install_required_packages() {
    log "Installing required system dependencies..."

    case "$PKG" in
        apt)
            if ! apt_install \
                bash \
                coreutils \
                findutils \
                grep \
                sed \
                gawk \
                util-linux \
                inotify-tools \
                imagemagick \
                cargo \
                build-essential \
                curl \
                ca-certificates \
                git
            then
                err "Failed to install required packages."
                exit 1
            fi
            ;;

        dnf)
            if ! $SUDO dnf install -y \
                bash \
                coreutils \
                findutils \
                grep \
                sed \
                gawk \
                util-linux \
                inotify-tools \
                ImageMagick \
                cargo \
                gcc \
                gcc-c++ \
                make \
                curl \
                ca-certificates \
                git
            then
                err "Failed to install required packages."
                exit 1
            fi
            ;;

        pacman)
            if ! $SUDO pacman -Sy --needed --noconfirm \
                bash \
                coreutils \
                findutils \
                grep \
                sed \
                gawk \
                util-linux \
                inotify-tools \
                imagemagick \
                rust \
                base-devel \
                git \
                curl \
                pkgconf
            then
                err "Failed to install required packages."
                exit 1
            fi
            ;;
    esac
}

install_optional_package() {
    local pkg="$1"
    log "Trying to install optional package: $pkg"

    case "$PKG" in
        apt)
            apt_install "$pkg" || warn "Optional package '$pkg' could not be installed."
            ;;
        dnf)
            $SUDO dnf install -y "$pkg" || warn "Optional package '$pkg' could not be installed."
            ;;
        pacman)
            $SUDO pacman -S --needed --noconfirm "$pkg" || warn "Optional package '$pkg' could not be installed."
            ;;
    esac
}

install_kde_helpers() {
    log "Installing optional KDE helper packages..."

    case "$PKG" in
        apt)
            install_optional_package plasma-workspace
            install_optional_package plasma-framework
            install_optional_package libkf5config-bin
            install_optional_package libkf6config-bin
            ;;
        dnf)
            install_optional_package plasma-workspace
            install_optional_package kf6-kconfig
            install_optional_package kf5-kconfig
            ;;
        pacman)
            install_optional_package plasma-workspace
            install_optional_package kconfig
            install_optional_package kconfig5
            ;;
    esac
}

install_optional_dependencies() {
    if ! command -v ffmpeg >/dev/null 2>&1; then
        install_optional_package ffmpeg
    fi

    if ! command -v plasma-apply-colorscheme >/dev/null 2>&1 || \
       ! { command -v kwriteconfig6 >/dev/null 2>&1 || command -v kwriteconfig5 >/dev/null 2>&1; }; then
        install_kde_helpers
    fi
}

# ----------------------------------------------------------------------------
# Wallust installation: cargo / rustup
# ----------------------------------------------------------------------------

refresh_cargo_path() {
    export PATH="$HOME/.cargo/bin:$PATH"
}

install_rustup() {
    if [ "$NO_RUSTUP" = "1" ]; then
        warn "NO_RUSTUP=1 set, skipping rustup fallback."
        return 1
    fi

    log "Installing rustup (user-local Rust toolchain)..."
    if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal; then
        if [ -f "$HOME/.cargo/env" ]; then
            . "$HOME/.cargo/env"
        fi
        refresh_cargo_path
        return 0
    fi

    return 1
}

cargo_install_wallust() {
    refresh_cargo_path

    if ! command -v cargo >/dev/null 2>&1; then
        log "cargo not found. Installing it..."
        case "$PKG" in
            apt)
                apt_install cargo || return 1
                ;;
            dnf)
                $SUDO dnf install -y cargo || return 1
                ;;
            pacman)
                $SUDO pacman -S --needed --noconfirm rust || return 1
                ;;
        esac
    fi

    refresh_cargo_path

    if ! command -v cargo >/dev/null 2>&1; then
        err "cargo is not available after installation attempt."
        return 1
    fi

    log "Installing wallust via cargo. This can take several minutes..."
    if cargo install wallust; then
        refresh_cargo_path
        return 0
    fi

    warn "cargo install wallust failed. Trying git source..."
    if cargo install --git https://github.com/varqox/wallust wallust; then
        refresh_cargo_path
        return 0
    fi

    warn "Could not build wallust with the current cargo toolchain."

    if install_rustup; then
        log "Retrying wallust installation using rustup cargo..."
        if cargo install wallust; then
            refresh_cargo_path
            return 0
        fi

        if cargo install --git https://github.com/varqox/wallust wallust; then
            refresh_cargo_path
            return 0
        fi
    fi

    return 1
}

# ----------------------------------------------------------------------------
# Wallust installation: Arch AUR
# ----------------------------------------------------------------------------

install_paru() {
    log "No AUR helper detected. Installing paru..."

    if ! $SUDO pacman -S --needed --noconfirm base-devel git rust curl; then
        err "Failed to install packages needed to build paru."
        exit 1
    fi

    local tmp
    tmp="$(mktemp -d)"

    if ! git clone --depth 1 https://aur.archlinux.org/paru.git "$tmp/paru"; then
        err "Failed to clone paru from AUR."
        rm -rf "$tmp"
        exit 1
    fi

    if ! (cd "$tmp/paru" && makepkg -si --noconfirm); then
        err "Failed to build/install paru."
        rm -rf "$tmp"
        exit 1
    fi

    rm -rf "$tmp"

    if ! command -v paru >/dev/null 2>&1; then
        err "paru installation failed."
        exit 1
    fi
}

install_aur_helper() {
    if [ -n "$AUR_HELPER" ] && ! command -v "$AUR_HELPER" >/dev/null 2>&1; then
        warn "AUR_HELPER='$AUR_HELPER' was specified, but it is not installed."
        AUR_HELPER=""
    fi

    if [ -n "$AUR_HELPER" ] && command -v "$AUR_HELPER" >/dev/null 2>&1; then
        log "Using AUR helper: $AUR_HELPER"
        return 0
    fi

    local has_paru=0
    local has_yay=0

    command -v paru >/dev/null 2>&1 && has_paru=1
    command -v yay  >/dev/null 2>&1 && has_yay=1

    if [ "$has_paru" -eq 1 ] && [ "$has_yay" -eq 1 ]; then
        if [ -t 0 ]; then
            echo
            echo "Both paru and yay were detected."
            echo "Select the AUR helper to use:"
            echo "  1) paru (default)"
            echo "  2) yay"
            read -r -p "Choice [1/2]: " choice
            case "${choice:-1}" in
                2|yay|YAY)
                    AUR_HELPER="yay"
                    ;;
                *)
                    AUR_HELPER="paru"
                    ;;
            esac
        else
            AUR_HELPER="paru"
        fi
    elif [ "$has_paru" -eq 1 ]; then
        AUR_HELPER="paru"
    elif [ "$has_yay" -eq 1 ]; then
        AUR_HELPER="yay"
    else
        install_paru
        AUR_HELPER="paru"
    fi

    if ! command -v "$AUR_HELPER" >/dev/null 2>&1; then
        err "Selected AUR helper '$AUR_HELPER' is not available."
        exit 1
    fi

    log "Using AUR helper: $AUR_HELPER"
}

install_wallust_arch() {
    install_aur_helper

    log "Installing wallust from AUR using $AUR_HELPER..."
    if "$AUR_HELPER" -S --needed --noconfirm wallust; then
        return 0
    fi

    warn "Failed to install wallust. Trying wallust-git..."
    if "$AUR_HELPER" -S --needed --noconfirm wallust-git; then
        return 0
    fi

    return 1
}

install_wallust() {
    if command -v wallust >/dev/null 2>&1; then
        log "wallust is already installed."
        return 0
    fi

    if [ "$PKG" = "pacman" ]; then
        if install_wallust_arch; then
            return 0
        fi

        warn "AUR installation failed. Trying cargo fallback..."
        if cargo_install_wallust; then
            return 0
        fi
    else
        if cargo_install_wallust; then
            return 0
        fi
    fi

    err "Could not install wallust."
    exit 1
}

# ----------------------------------------------------------------------------
# Install project files
# ----------------------------------------------------------------------------

find_source_file() {
    local name
    local base

    for name in "$@"; do
        for base in \
            "$SCRIPT_DIR" \
            "$SCRIPT_DIR/sync-waywallen-colors-wallust" \
            "$SCRIPT_DIR/bin" \
            "$SCRIPT_DIR/systemd"
        do
            if [ -f "$base/$name" ]; then
                printf '%s' "$base/$name"
                return 0
            fi
        done
    done

    return 1
}

install_files() {
    log "Creating installation directories..."
    mkdir -p "$BIN_DIR" "$SYSTEMD_DIR"

    local sync_src=""
    local watch_src=""
    local service_src=""

    sync_src="$(find_source_file "sync-waywallen-colors" "sync-waywallen-colors.sh" || true)"
    watch_src="$(find_source_file "watch-waywallen.sh" || true)"
    service_src="$(find_source_file "waywallen-colors.service" "waywallen-colors.service.txt" || true)"

    if [ -z "$sync_src" ]; then
        err "Could not find sync-waywallen-colors or sync-waywallen-colors.sh"
        err "Expected location: $SCRIPT_DIR"
        exit 1
    fi

    if [ -z "$watch_src" ]; then
        err "Could not find watch-waywallen.sh"
        err "Expected location: $SCRIPT_DIR"
        exit 1
    fi

    if [ -z "$service_src" ]; then
        err "Could not find waywallen-colors.service"
        err "Expected location: $SCRIPT_DIR"
        exit 1
    fi

    log "Installing sync script to $BIN_DIR/sync-waywallen-colors"
    install -Dm755 "$sync_src" "$BIN_DIR/sync-waywallen-colors"

    log "Installing watch script to $BIN_DIR/watch-waywallen.sh"
    install -Dm755 "$watch_src" "$BIN_DIR/watch-waywallen.sh"

    log "Installing systemd user service to $SYSTEMD_DIR/$SERVICE_NAME"
    install -Dm644 "$service_src" "$SYSTEMD_DIR/$SERVICE_NAME"
}

# ----------------------------------------------------------------------------
# Enable systemd user service
# ----------------------------------------------------------------------------

enable_service() {
    if ! command -v systemctl >/dev/null 2>&1; then
        warn "systemctl not found. Service was installed but cannot be enabled automatically."
        return 0
    fi

    log "Reloading systemd user daemon..."
    if ! systemctl --user daemon-reload >/dev/null 2>&1; then
        warn "Could not communicate with the systemd user instance."
        warn "After login, run manually:"
        warn "  systemctl --user daemon-reload"
        warn "  systemctl --user enable --now $SERVICE_NAME"
        return 0
    fi

    log "Enabling service: $SERVICE_NAME"
    if ! systemctl --user enable "$SERVICE_NAME" >/dev/null 2>&1; then
        warn "Could not enable service."
    fi

    if systemctl --user is-active graphical-session.target >/dev/null 2>&1; then
        log "Starting/restarting service..."
        if ! systemctl --user restart "$SERVICE_NAME" >/dev/null 2>&1; then
            warn "Could not start service."
        fi
    else
        log "Service installed. Start it after login with:"
        log "  systemctl --user start $SERVICE_NAME"
    fi
}

# ----------------------------------------------------------------------------
# Final checks
# ----------------------------------------------------------------------------

final_checks() {
    log "Running final checks..."

    local missing=0

    for cmd in inotifywait wallust; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log "Found required command: $cmd"
        else
            warn "Missing required command: $cmd"
            missing=1
        fi
    done

    if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
        log "Found ImageMagick command."
    else
        warn "Missing ImageMagick command (magick or convert)."
        missing=1
    fi

    if command -v ffmpeg >/dev/null 2>&1; then
        log "Found ffmpeg."
    else
        warn "ffmpeg not found. GIF support may be limited."
    fi

    if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
        log "Found plasma-apply-colorscheme."
    else
        warn "plasma-apply-colorscheme not found. KDE theme application may fail."
    fi

    if command -v kwriteconfig6 >/dev/null 2>&1 || command -v kwriteconfig5 >/dev/null 2>&1; then
        log "Found kwriteconfig command."
    else
        warn "kwriteconfig5/kwriteconfig6 not found. KDE accent update may fail."
    fi

    if [ "$missing" -eq 1 ]; then
        warn "Some required components are missing. Review the warnings above."
    fi
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

log "Starting installation..."
install_required_packages
install_optional_dependencies
install_wallust
install_files
enable_service
final_checks

log "Installation finished."
log "Installed files:"
log "  - $BIN_DIR/sync-waywallen-colors"
log "  - $BIN_DIR/watch-waywallen.sh"
log "  - $SYSTEMD_DIR/$SERVICE_NAME"
log ""
log "Useful commands:"
log "  systemctl --user status $SERVICE_NAME"
log "  systemctl --user restart $SERVICE_NAME"
log "  journalctl --user -u $SERVICE_NAME -f"
