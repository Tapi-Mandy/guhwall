#!/bin/bash
set -e

echo "=== guhwall Installer ==="

# 1. Install Pacman Dependencies (Official Repos)
if command -v pacman &> /dev/null; then
    echo "[1/4] Installing system dependencies (needs sudo)..."
    # swww is in 'extra', rust is in 'extra', go is in 'extra'
    sudo pacman -S --needed go gtk3 pkgconf libnotify swww rust git base-devel
else
    echo "Warning: Not on Arch Linux. Ensure you have Go, GTK3, Rust, and SWWW installed."
fi

# 2. Install Matugen via Cargo (User space)
if ! command -v matugen &> /dev/null; then
    echo "[2/4] Installing Matugen via Cargo..."
    cargo install matugen
    
    # Ensure cargo bin is in path for this session
    export PATH="$HOME/.cargo/bin:$PATH"
    
    echo "Note: If matugen doesn't run later, ensure ~/.cargo/bin is in your PATH."
else
    echo "[2/4] Matugen already installed."
fi

# 3. Initialize Go Module
if [ ! -f go.mod ]; then
    echo "[3/4] Initializing Go module..."
    go mod init guhwall
    go get github.com/gotk3/gotk3/gtk
    go get github.com/gotk3/gotk3/gdk
    go get github.com/gotk3/gotk3/glib
    go get github.com/disintegration/imaging
fi

# 4. Build and Install guhwall
echo "[4/4] Building and Installing guhwall..."
make install

echo "---------------------------------------"
echo "Success! Launch 'guhwall' from your menu."
echo "---------------------------------------"
