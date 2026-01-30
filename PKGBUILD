# Maintainer: Mandy <mandytapi@gmail.com>
pkgname=guhwall
pkgver=1.0.0
pkgrel=1
pkgdesc="Guh?? Wallpapers!"
arch=('any')
url="https://github.com/Tapi-Mandy/guhwall"
license=('MIT')
depends=('gtk3' 'python-gobject' 'python-pillow' 'python-cairo' 'matugen' 'swww' 'cantarell-fonts' 'ttf-jetbrains-mono-nerd')
source=("guhwall"
        "guhwall-apply"
        "assets/guhwall.png")
sha256sums=('SKIP'
            'SKIP'
            'SKIP')

package() {
    # 1. Install Binaries
    install -Dm755 "${srcdir}/guhwall" "${pkgdir}/usr/bin/guhwall"
    install -Dm755 "${srcdir}/guhwall-apply" "${pkgdir}/usr/bin/guhwall-apply"

    # 2. Install Icon
    install -Dm644 "${srcdir}/guhwall.png" "${pkgdir}/usr/share/icons/hicolor/scalable/apps/guhwall.png"

    # 3. Create and Install Desktop Entry
    mkdir -p "${pkgdir}/usr/share/applications"
    cat <<EOF > "${pkgdir}/usr/share/applications/guhwall.desktop"
[Desktop Entry]
Name=guhwall
Exec=/usr/bin/guhwall
Icon=guhwall
Type=Application
Categories=Settings;Graphics;
Comment=Guh?? Wallpapers!
Terminal=false
EOF
}