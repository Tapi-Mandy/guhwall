#!/bin/bash
set -e

# Error Trap
trap 'echo "Error occurred at line $LINENO. Installation failed."' ERR

# CONFIGURATION
REPO_URL="https://github.com/Tapi-Mandy/guhwall.git"
CLONE_DIR="$HOME/guhwall-source"

echo "-----------------------------------------------------"
echo "        GUHWALL INSTALLER (Native Mode)              "
echo "-----------------------------------------------------"

echo "[1/3] Checking Dependencies..."

if command -v pacman &> /dev/null; then
    sudo pacman -S --needed --noconfirm \
        base-devel go rust git gtk3 pkgconf libnotify lz4 libxkbcommon
    
    export PATH="$HOME/.cargo/bin:$PATH"
    
    if ! command -v swww &> /dev/null; then
        echo "   -> Installing swww..."
        sudo pacman -S --needed --noconfirm swww
    fi
    if ! command -v matugen &> /dev/null; then
        echo "   -> Installing matugen..."
        cargo install matugen
    fi
else
    echo "Not on Arch? Ensure Go, Rust, GTK3, swww, and matugen are installed."
fi

echo "[2/3] Getting Source Code..."

# Local vs Remote check
if [ -f "main.go" ] && [ -f "Makefile" ]; then
    echo "   -> Using current directory."
else
    echo "   -> Cloning from GitHub..."
    rm -rf "$CLONE_DIR"
    git clone "$REPO_URL" "$CLONE_DIR"
    cd "$CLONE_DIR"
fi

echo "[3/3] Installing..."

# Hide the warnings during build
export CGO_CFLAGS="-w"

# Run the makefile (which builds the go app using the repo's go.mod)
make install

echo "-----------------------------------------------------"
echo "  SUCCESS! Run 'guhwall' to start."
echo "-----------------------------------------------------"
