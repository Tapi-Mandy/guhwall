#!/bin/bash

# --- Colors ---
YLW=$'\033[1;33m' # Yellow: Primary
WHT=$'\033[0;37m' # Light Gray
GRA=$'\033[1;30m' # Dark Gray
RED=$'\033[0;31m' # Red
BOLD=$'\033[1m'   # Bold
NC=$'\033[0m'     # No Color

# --- ASCII Art ---
echo -e "${YLW}"
echo " /\_/\\"
echo "( o.o )"
echo " > ^ <"
echo -e "${NC}"

# 1. Dependencies
echo -e "${YLW}--> Installing dependencies...${NC}"
sudo pacman -S --needed --noconfirm python-gobject gtk3 python-pywal swww python-pillow python-cairo cantarell-fonts

# 2. Binary Installation
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

echo -e "${YLW}--> Copying binaries...${NC}"

# Install main app
if [ -f "guhwall" ]; then
    cp guhwall "$BIN_DIR/guhwall"
else
    echo -e "${RED}[!] Error: Could not find guhwall in the current directory.${NC}"
    exit 1
fi

# Install logic script
if [ -f "guhwall-apply" ]; then
    cp guhwall-apply "$BIN_DIR/guhwall-apply"
else
    echo -e "${RED}[!] Error: Could not find guhwall-apply in the current directory.${NC}"
    exit 1
fi

# Set permissions
chmod +x "$BIN_DIR/guhwall" "$BIN_DIR/guhwall-apply"

# 3. Icon Installation
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
mkdir -p "$ICON_DIR"
if [ -f "assets/guhwall.svg" ]; then
    echo -e "${YLW}--> Installing icon...${NC}"
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

echo -e "${YLW}${BOLD}==> Done! Launch 'guhwall' via Rofi after the installation is complete.${NC}"