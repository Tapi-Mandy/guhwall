<div align="center">
  <img width="80%" alt="guhwall" src="https://github.com/user-attachments/assets/0245a22b-15ef-4371-b629-c95ed2edbe61"/>
</div>

---

<div align="center">
  <h3>Aesthetic Wallpaper Manager Made For <a href="https://github.com/Tapi-Mandy/guhwm/">guhwm</a></h3>
  <h4>Built with Python & GTK, it provides a beautiful, lightweight, and compact UI to browse your collection</h4>
</div>

---
## Installation
### <sub><img src="https://cdn.simpleicons.org/archlinux/1793D1" height="25" width="25"></sub> Arch Linux

```bash
git clone --depth 1 https://github.com/Tapi-Mandy/guhwall.git
cd guhwall
makepkg -si
```

---

> [!TIP]
> The functionality of guhwall is inherently based on [guhwm](https://github.com/Tapi-Mandy/guhwm).
>
> You would need to modify it / fork it if you want to use it differently.

### Setup:
* [**pipx**](https://pipx.pypa.io/stable/):
```
sudo pacman -S python-pipx
```
> After installation, run the command to add the pipx binary directory to your system PATH:
```
pipx ensurepath
```
>
> Note: You may need to restart your terminal or run `source ~/.bashrc` (or similar for your shell) for the changes to take effect.
* [**pywal16**](https://pypi.org/project/pywal16/):

```
pipx install pywal16
```

* [**adw-gtk3**](https://github.com/lassekongo83/adw-gtk3):

```
pacman -S adw-gtk-theme
```

> And then, you would need to run this for proper theming:
```
gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' && gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
```

Or, you could literally just use [guhwm](https://github.com/Tapi-Mandy/guhwm)..
