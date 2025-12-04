#!/bin/bash
# ---------------------------------------------------
# guhwall + Wallust + GTK Installer | Polybar support
# ---------------------------------------------------
set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${BLUE}:: Initializing guhwall System Installer...${NC}"

# ---------------------------------------------------------
# PART 1: Dependencies
# ---------------------------------------------------------
echo -e "${BLUE}:: Installing system dependencies...${NC}"
sudo pacman -S --needed --noconfirm base-devel git rust cargo nodejs npm feh xorg-xinput xdotool

# ---------------------------------------------------------
# PART 2: Build Wallust (From Source)
# ---------------------------------------------------------
BUILD_ROOT="/tmp/guhwall_installer_$(date +%s)"
mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"

if command -v wallust &> /dev/null; then
    echo -e "${GREEN}:: Wallust is already installed. Skipping.${NC}"
else
    echo -e "${BLUE}:: Cloning Wallust...${NC}"
    git clone https://codeberg.org/explosion-mental/wallust.git
    cd wallust
    echo -e "${BLUE}:: Compiling Wallust (Release)...${NC}"
    cargo build --release
    sudo cp target/release/wallust /usr/local/bin/
    cd "$BUILD_ROOT"
    echo -e "${GREEN}:: Wallust installed.${NC}"
fi

# ---------------------------------------------------------
# PART 3: Build guhwall (From Source)
# ---------------------------------------------------------
echo -e "${BLUE}:: Cloning guhwall...${NC}"
git clone https://github.com/Tapi-Mandy/guhwall.git
cd guhwall

echo -e "${BLUE}:: Building guhwall Binary...${NC}"
npm install
npm run dist

echo -e "${BLUE}:: Installing guhwall System-wide...${NC}"
sudo rm -rf /opt/guhwall
sudo mkdir -p /opt/guhwall
sudo cp -r dist/linux-unpacked/* /opt/guhwall/
sudo ln -sf /opt/guhwall/guhwall /usr/bin/guhwall

# Icons & Desktop Entry
sudo mkdir -p /usr/share/icons/hicolor/scalable/apps
sudo cp icon.svg /usr/share/icons/hicolor/scalable/apps/guhwall.svg
sudo mkdir -p /usr/share/applications
sudo cp guhwall.desktop /usr/share/applications/guhwall.desktop

# ---------------------------------------------------------
# PART 4: CONFIGURATION (Wallust, GTK, Polybar)
# ---------------------------------------------------------
echo -e "${BLUE}:: Configuring Templates...${NC}"

# A. Install adw-gtk3 Theme
if [ ! -d "$HOME/.themes/adw-gtk3-dark" ]; then
    mkdir -p "$HOME/.themes"
    curl -L https://github.com/lassekongo83/adw-gtk3/releases/download/v5.1/adw-gtk3v5-1.tar.xz -o /tmp/adw.tar.xz
    tar -xf /tmp/adw.tar.xz -C "$HOME/.themes"
fi

# B. Configure Wallust
mkdir -p "$HOME/.config/wallust/templates"
mkdir -p "$HOME/.cache/wal" 
mkdir -p "$HOME/.config/polybar" # Ensure config folder exists

# 1. GTK Template
cat > "$HOME/.config/wallust/templates/gtk-colors.css" << 'EOF'
@define-color accent_color {{color4}};
@define-color accent_bg_color {{color4}};
@define-color accent_fg_color {{background}};
@define-color window_bg_color {{background}};
@define-color window_fg_color {{foreground}};
@define-color view_bg_color {{background}};
@define-color view_fg_color {{foreground}};
@define-color headerbar_bg_color {{background}};
@define-color headerbar_fg_color {{foreground}};
@define-color headerbar_backdrop_color @window_bg_color;
@define-color card_bg_color rgba(255, 255, 255, 0.05);
@define-color card_fg_color {{foreground}};
@define-color popover_bg_color {{background}};
@define-color popover_fg_color {{foreground}};
EOF

# 2. Polybar Template
cat > "$HOME/.config/wallust/templates/colors-polybar.ini" << 'EOF'
[colors]
background = {{background}}
foreground = {{foreground}}
primary = {{color4}}
secondary = {{color2}}
alert = {{color1}}
disabled = {{color8}}
color0 = {{color0}}
color1 = {{color1}}
color2 = {{color2}}
color3 = {{color3}}
color4 = {{color4}}
color5 = {{color5}}
color6 = {{color6}}
color7 = {{color7}}
color8 = {{color8}}
EOF

# 3. Wallust Config
# We define where the templates should go
cat > "$HOME/.config/wallust/wallust.toml" << EOF
[entry]
template = "gtk-colors.css"
target = "~/.cache/wal/gtk-colors.css"

[entry]
template = "colors-polybar.ini"
target = "~/.config/polybar/colors.ini"
EOF

# C. Configure GTK 3 & 4
mkdir -p "$HOME/.config/gtk-3.0"
cat > "$HOME/.config/gtk-3.0/settings.ini" << EOF
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-font-name=Sans 11
gtk-application-prefer-dark-theme=1
EOF
echo "@import url(\"file://${HOME}/.cache/wal/gtk-colors.css\");" > "$HOME/.config/gtk-3.0/gtk.css"

mkdir -p "$HOME/.config/gtk-4.0"
cat > "$HOME/.config/gtk-4.0/settings.ini" << EOF
[Settings]
gtk-theme-name=Default
gtk-icon-theme-name=Adwaita
gtk-font-name=Sans 11
gtk-application-prefer-dark-theme=1
EOF
echo "@import url(\"file://${HOME}/.cache/wal/gtk-colors.css\");" > "$HOME/.config/gtk-4.0/gtk.css"

# D. AUTOMATIC POLYBAR INJECTION
POLY_CONF="$HOME/.config/polybar/config.ini"

if [ -f "$POLY_CONF" ]; then
    # If config exists, check if the include line is already there
    if ! grep -q "include-file = ~/.config/polybar/colors.ini" "$POLY_CONF"; then
        echo "   -> Injecting colors into Polybar config..."
        # Insert at line 1
        sed -i '1iinclude-file = ~/.config/polybar/colors.ini' "$POLY_CONF"
    else
        echo "   -> Polybar config already includes colors.ini."
    fi
else
    # If config doesn't exist, create a basic one that includes the colors
    echo "   -> Polybar config not found. Creating default..."
    cat > "$POLY_CONF" << EOF
include-file = ~/.config/polybar/colors.ini

[bar/example]
width = 100%
height = 24pt
background = \${colors.background}
foreground = \${colors.foreground}
font-0 = monospace;2
modules-left = xworkspaces
modules-right = date
EOF
fi

# Cleanup
cd ~
rm -rf "$BUILD_ROOT"
rm -f /tmp/adw.tar.xz

echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN} INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}==============================================${NC}"
echo -e " 1. Wallust Configured (GTK + Polybar)."
echo -e " 2. guhwall Installed."
echo -e ""
echo -e "IMPORTANT: Add 'include-file = ~/.config/polybar/colors.ini' to your Polybar config."
