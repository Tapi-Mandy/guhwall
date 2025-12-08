#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

# 0. Error Trap (So it doesn't just exit silently on fail)
trap 'echo "Error occurred at line $LINENO. Installation failed."' ERR

# CONFIGURATION
REPO_URL="https://github.com/Tapi-Mandy/guhwall.git"
CLONE_DIR="$HOME/guhwall-source"

echo "-----------------------------------------------------"
echo "        GUHWALL INSTALLER (Native Mode)              "
echo "-----------------------------------------------------"

# 1. Check & Install Dependencies
echo "[1/4] Checking System Dependencies..."

if command -v pacman &> /dev/null; then
    # Arch Linux Packages
    sudo pacman -S --needed --noconfirm \
        base-devel \
        go \
        rust \
        git \
        gtk3 \
        pkgconf \
        libnotify \
        lz4 \
        libxkbcommon
    
    # Add Cargo to PATH immediately for this script execution
    export PATH="$HOME/.cargo/bin:$PATH"
    
    # Install Matugen via Cargo (More reliable than AUR helpers for this)
    if ! command -v swww &> /dev/null; then
        echo "   -> Installing swww (via pacman)..."
        sudo pacman -S --needed --noconfirm swww
    fi

    if ! command -v matugen &> /dev/null; then
        echo "   -> Installing matugen (via cargo)..."
        cargo install matugen
    fi
else
    echo "Not on Arch Linux? Make sure you have Go, Rust, GTK3, and git installed manually."
fi

# 2. Clone the Repository
echo "[2/4] Setting up Source Code..."

# Check if we are running INSIDE the repo already (Local install)
if [ -f "main.go" ] && [ -f "Makefile" ]; then
    echo "   -> We are inside the source directory. Using current files."
else
    # We are outside, so we clean clone
    echo "   -> Cloning guhwall from GitHub to $CLONE_DIR..."
    
    # Remove old version if exists to avoid conflicts
    rm -rf "$CLONE_DIR"
    
    git clone "$REPO_URL" "$CLONE_DIR"
    
    # Enter the directory
    cd "$CLONE_DIR"
fi

# 3. Initialize Go Module

# Remove old dependency files to force a clean update
rm -f go.mod go.sum

# Initialize module
go mod init guhwall

# Force the 'master' branch of the GTK library.
# The default version crashes on Arch Linux. This fixes it.
echo "   -> Fetching latest library versions..."
go get github.com/gotk3/gotk3@master
go get github.com/disintegration/imaging

# Tidy up
go mod tidy

# 4. Build and Install
echo "[4/4] Running Make Install..."
make install

echo "-----------------------------------------------------"
echo "  SUCCESS! guhwall installed."
echo "   Run 'guhwall' to start."
echo "-----------------------------------------------------"
