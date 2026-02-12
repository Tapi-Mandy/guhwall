# Maintainer: Mandy <mandytapi@gmail.com>
pkgname=guhwall
pkgver=1.0.0
pkgrel=1
pkgdesc="Guh?? Wallpapers!"
arch=('any')
url="https://github.com/Tapi-Mandy/guhwall"
license=('MIT')
depends=('gtk3' 'python-gobject' 'python-pillow' 'python-cairo' 'swww' 'cantarell-fonts' 'ttf-jetbrains-mono-nerd')

source=("guhwall"
        "guhwall-apply"
        "guhwall.png")

sha256sums=('000c6b234117932d442ed0515ce9bb9b9e8db1bd4c48b046820c03518c01a898'
            '30251647ea11aa7b01c58e743c815be765b9a1382cfa0f7e37449a8952aae27d'
            'f8139e21d5ff2cf4de2a477084ccedadc3882c9f53695531dde623341c2bc63d')

package() {
    # 1. Install Binaries
    install -Dm755 "${srcdir}/guhwall" "${pkgdir}/usr/bin/guhwall"
    install -Dm755 "${srcdir}/guhwall-apply" "${pkgdir}/usr/bin/guhwall-apply"

    # 2. Install Icon
    install -Dm644 "${srcdir}/guhwall.png" "${pkgdir}/usr/share/pixmaps/guhwall.png"

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
