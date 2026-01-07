#!/bin/bash

# Colors
CREAM='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

# ASCII Art
echo -e "${CREAM}"
echo " /\_/\\"
echo "( o.o )"
echo " > ^ <"
echo -e "${NC}"

echo -e "${CREAM}${BOLD}--- Installing guhwall ---${NC}"

# 1. Dependencies
echo -e "${CREAM}Installing dependencies...${NC}"
sudo pacman -S --needed --noconfirm python-gobject gtk3 python-pywal swww swaync python-pillow python-cairo cantarell-fonts

# 2. Binary Installation
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

echo -e "${CREAM}Copying binaries...${NC}"

# Install main app
if [ -f "guhwall" ]; then
    cp guhwall "$BIN_DIR/guhwall"
else
    echo -e "\033[0;31m[!] Error: Could not find guhwall in the current directory.\033[0m"
    exit 1
fi

# Install logic script
if [ -f "guhwall-apply" ]; then
    cp guhwall-apply "$BIN_DIR/guhwall-apply"
else
    echo -e "\033[0;31m[!] Error: Could not find guhwall-apply in the current directory.\033[0m"
    exit 1
fi

# Set permissions
chmod +x "$BIN_DIR/guhwall" "$BIN_DIR/guhwall-apply"

# 3. Icon Installation
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
mkdir -p "$ICON_DIR"
if [ -f "assets/guhwall.svg" ]; then
    echo -e "${CREAM}Installing icon...${NC}"
    cp assets/guhwall.svg "$ICON_DIR/guhwall.svg"
fi

# 4. Desktop Entry
APP_DIR="$HOME/.local/share/applications"
mkdir -p "$APP_DIR"
cat <<EOF > "$APP_DIR/guhwall.desktop"
[Desktop Entry]
Name=guhwall
Exec=$BIN_DIR/guhwall
Icon=guhwall
Type=Application
Categories=Settings;Graphics;
Comment=Guh?? Wallpapers!
Terminal=false
EOF

# 5. Cache Refresh
gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor 2>/dev/null || true

echo -e "${CREAM}${BOLD}Done! Launch 'guhwall' via Rofi after the installation is complete.${NC}"