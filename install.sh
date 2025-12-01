#!/bin/bash

# guhwall's installer script (Direct Install)
# ------------------------------------------
set -e # Exit immediately if a command fails

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${BLUE}:: Initializing guhwall Installer...${NC}"

# 1. Install Build Dependencies
echo -e "${BLUE}:: Installing system dependencies...${NC}"
# We need these to compile everything
sudo pacman -S --needed --noconfirm base-devel git rust cargo nodejs npm feh xorg-xinput xdotool

# 2. Setup Temp Directory
BUILD_ROOT="/tmp/guhwall_installer_$(date +%s)"
mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

# ---------------------------------------------------------
# PART A: Build Walrs
# ---------------------------------------------------------
if command -v walrs &> /dev/null; then
    echo -e "${GREEN}:: Walrs is already installed. Skipping.${NC}"
else
    echo -e "${BLUE}:: Cloning Walrs (pixel2175)...${NC}"
    git clone https://github.com/pixel2175/walrs.git
    cd walrs
    
    echo -e "${BLUE}:: Installing Walrs...${NC}"
    # As requested: make clean install
    sudo make clean install
    
    cd "$BUILD_ROOT"
    echo -e "${GREEN}:: Walrs installed successfully!${NC}"
fi

# ---------------------------------------------------------
# PART B: Build guhwall
# ---------------------------------------------------------
echo -e "${BLUE}:: Cloning guhwall (Tapi-Mandy)...${NC}"
git clone https://github.com/Tapi-Mandy/guhwall
cd guhwall

echo -e "${BLUE}:: Installing Node modules...${NC}"
npm install

echo -e "${BLUE}:: Compiling Binary (Electron Builder)...${NC}"
npm run dist

echo -e "${BLUE}:: Installing to /opt/guhwall...${NC}"

# 1. Clean old install
sudo rm -rf /opt/guhwall
sudo mkdir -p /opt/guhwall

# 2. Copy the COMPILED application (from dist/linux-unpacked)
sudo cp -r dist/linux-unpacked/* /opt/guhwall/

# 3. Link the binary
sudo ln -sf /opt/guhwall/guhwall /usr/bin/guhwall

# 4. Install Icon
sudo mkdir -p /usr/share/icons/hicolor/scalable/apps
sudo cp icon.svg /usr/share/icons/hicolor/scalable/apps/guhwall.svg

# 5. Install Desktop Entry
sudo mkdir -p /usr/share/applications
sudo cp guhwall.desktop /usr/share/applications/guhwall.desktop

# ---------------------------------------------------------
# Cleanup
# ---------------------------------------------------------
cd ~
rm -rf "$BUILD_ROOT"

echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN} INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}==============================================${NC}"
echo -e "Run the app by typing: ${BLUE}guhwall${NC}"
