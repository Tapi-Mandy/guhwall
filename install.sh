#!/bin/bash

# Dark Vanilla Colors
CREAM='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

# Check dependencies
echo "Checking pacman dependencies..."
sudo pacman -S --needed --noconfirm python-gobject gtk3 python-pywal swww swaync python-pillow python-cairo cantarell-fonts

# Paths
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"

mkdir -p "$BIN_DIR" "$APP_DIR" "$ICON_DIR"

# Install files
echo "Copying binaries..."
cp guhwall.py "$BIN_DIR/guhwall"
cp guhwall-apply "$BIN_DIR/guhwall-apply"
chmod +x "$BIN_DIR/guhwall" "$BIN_DIR/guhwall-apply"

# Install Icon
if [ -f "assets/guhwall.svg" ]; then
    echo "Installing guhwall icon..."
    cp assets/guhwall.svg "$ICON_DIR/guhwall.svg"
else
    echo "Icon not found in assets/guhwall.svg"
fi

# Create Desktop Entry for Rofi
echo "Creating desktop entry..."
cat <<EOF > "$APP_DIR/guhwall.desktop"
[Desktop Entry]
Name=guhwall
Exec=$BIN_DIR/guhwall
Icon=guhwall
Type=Application
Categories=Settings;
Comment=Guh?? Wallpapers??
Terminal=false
EOF

# Refresh icon cache so Rofi sees it immediately
echo "Refreshing system icon cache..."
gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor 2>/dev/null || true

echo -e "${CREAM}${BOLD}✅ Done! Launch 'guhwall' via Rofi.${NC}"
