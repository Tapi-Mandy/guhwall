<div align="center">
  <img width="1371" height="513" alt="guhwall" src="https://github.com/user-attachments/assets/0245a22b-15ef-4371-b629-c95ed2edbe61"/>
</div>

---

<h3 align="center">Aesthetic wallpaper manager made for <a href="https://github.com/Tapi-Mandy/guhwm/">guhwm</a>.</h3>

<h4 align="center">Built with Python & GTK, it provides a beautiful, lightweight, and compact UI to browse your collection and instantly apply themes using matugen.</h4>

---

### Git clone from source
> Useful for modifying / forking
#### Clone the repository:
```
git clone https://github.com/Tapi-Mandy/guhwall.git
```

> [!IMPORTANT]
> You need to give permissions to `guhwall`, `guhwall-apply`, & `install.sh`.
> 
> *(If you want to use/modify the installer)* *obviously*
>
> `chmod +x install.sh guhwall guhwall-apply`

**Dependencies:** (Arch)
```
sudo pacman -S --needed --noconfirm python-gobject gtk3 matugen swww swaync python-pillow python-cairo cantarell-fonts
```

> **Note:** `matugen` generates Material Design 3 compliant color palettes from wallpapers.
> If not in official repos, install from AUR: `yay -S matugen` or `paru -S matugen`

### Alternatively

#### Curl the installer:
> Method used in guhwizard
```
curl -L https://github.com/Tapi-Mandy/guhwall/tarball/main | tar -xz --strip-components=1 && ./install.sh
```

---

> [!TIP]
> The functionality of guhwall is inherently based on [guhwm](https://github.com/Tapi-Mandy/guhwm).
>
> You would need to modify it / fork it if you want to use it differently.
