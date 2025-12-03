#!/bin/bash

# guhwall Installer (guhwall, Walrs, GTK)
# ---------------------------------------------------
set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${BLUE}:: Initializing guhwall System Installer...${NC}"

# ---------------------------------------------------------
# PART 1: System Dependencies
# ---------------------------------------------------------
echo -e "${BLUE}:: Installing system dependencies...${NC}"
sudo pacman -S --needed --noconfirm base-devel git rust cargo nodejs npm feh xorg-xinput xdotool

# ---------------------------------------------------------
# PART 2: Build Walrs (From Source)
# ---------------------------------------------------------
BUILD_ROOT="/tmp/guhwall_installer_$(date +%s)"
mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

if command -v walrs &> /dev/null; then
    echo -e "${GREEN}:: Walrs is already installed. Skipping.${NC}"
else
    echo -e "${BLUE}:: Cloning Walrs...${NC}"
    git clone https://github.com/pixel2175/walrs
    cd walrs
    echo -e "${BLUE}:: Compiling Walrs...${NC}"
    sudo make clean install
    cd "$BUILD_ROOT"
    echo -e "${GREEN}:: Walrs installed.${NC}"
fi

# ---------------------------------------------------------
# PART 3: Build guhwall (From Source)
# ---------------------------------------------------------
echo -e "${BLUE}:: Cloning guhwall...${NC}"
git clone https://github.com/Tapi-Mandy/guhwall
cd guhwall

echo -e "${BLUE}:: Building guhwall Binary...${NC}"
npm install
npm run dist

echo -e "${BLUE}:: Installing guhwall System-wide...${NC}"
# Remove old install
sudo rm -rf /opt/guhwall
sudo mkdir -p /opt/guhwall

# Copy files
sudo cp -r dist/linux-unpacked/* /opt/guhwall/
sudo ln -sf /opt/guhwall/guhwall /usr/bin/guhwall

# Icons & Desktop Entry
sudo mkdir -p /usr/share/icons/hicolor/scalable/apps
sudo cp icon.svg /usr/share/icons/hicolor/scalable/apps/guhwall.svg
sudo mkdir -p /usr/share/applications
sudo cp guhwall.desktop /usr/share/applications/guhwall.desktop

# ---------------------------------------------------------
# PART 4: GTK THEMING & AUTOMATIC CONFIGURATION
# ---------------------------------------------------------
echo -e "${BLUE}:: Configuring GTK Themes & Colors...${NC}"

# A. Install adw-gtk3 Theme (Locally)
if [ ! -d "$HOME/.themes/adw-gtk3-dark" ]; then
    echo "   -> Downloading adw-gtk3 theme..."
    mkdir -p "$HOME/.themes"
    curl -L https://github.com/lassekongo83/adw-gtk3/releases/download/v5.1/adw-gtk3v5-1.tar.xz -o /tmp/adw.tar.xz
    tar -xf /tmp/adw.tar.xz -C "$HOME/.themes"
else
    echo "   -> Theme already exists."
fi

# B. Create the Walrs Template
# This maps the generated colors to LibAdwaita variables
echo "   -> Creating Walrs color template..."
mkdir -p "$HOME/.config/wal/templates"
cat > "$HOME/.config/wal/templates/gtk-colors.css" << 'EOF'
@define-color accent_color {color4};
@define-color accent_bg_color {color4};
@define-color accent_fg_color {background};
@define-color window_bg_color {background};
@define-color window_fg_color {foreground};
@define-color view_bg_color {background};
@define-color view_fg_color {foreground};
@define-color headerbar_bg_color {background};
@define-color headerbar_fg_color {foreground};
@define-color headerbar_backdrop_color @window_bg_color;
@define-color card_bg_color rgba(255, 255, 255, 0.05);
@define-color card_fg_color {foreground};
@define-color popover_bg_color {background};
@define-color popover_fg_color {foreground};
@define-color dialog_bg_color {background};
@define-color dialog_fg_color {foreground};
EOF

# C. Configure GTK3 (Automatically inject $HOME)
echo "   -> Configuring GTK 3..."
mkdir -p "$HOME/.config/gtk-3.0"
# Write Settings
cat > "$HOME/.config/gtk-3.0/settings.ini" << EOF
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=Sans 11
gtk-application-prefer-dark-theme=1
EOF
# Write Import (DYNAMICALLY uses user's home dir)
echo "@import url(\"file://${HOME}/.cache/wal/gtk-colors.css\");" > "$HOME/.config/gtk-3.0/gtk.css"

# D. Configure GTK4
echo "   -> Configuring GTK 4..."
mkdir -p "$HOME/.config/gtk-4.0"
# Write Settings
cat > "$HOME/.config/gtk-4.0/settings.ini" << EOF
[Settings]
gtk-theme-name=Default
gtk-icon-theme-name=Adwaita
gtk-font-name=Sans 11
gtk-application-prefer-dark-theme=1
EOF
# Write Import (DYNAMICALLY uses user's home dir)
echo "@import url(\"file://${HOME}/.cache/wal/gtk-colors.css\");" > "$HOME/.config/gtk-4.0/gtk.css"

# ---------------------------------------------------------
# Cleanup
# ---------------------------------------------------------
cd ~
rm -rf "$BUILD_ROOT"
rm -f /tmp/adw.tar.xz

echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN} INSTALLATION & CONFIG COMPLETE!${NC}"
echo -e "${GREEN}==============================================${NC}"
echo -e " 1. Walrs & guhwall installed."
echo -e " 2. GTK Themes set to Adw-GTK3."
echo -e " 3. Configs linked to your username ($USER)."
echo -e ""
echo -e "Run the app: ${BLUE}guhwall${NC}"
