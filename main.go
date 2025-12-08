package main

import (
	"crypto/md5"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/disintegration/imaging"
	"github.com/gotk3/gotk3/gdk"
	"github.com/gotk3/gotk3/glib"
	"github.com/gotk3/gotk3/gtk"
)

// STYLING: Translucent Background
// We use rgba(r,g,b,alpha) to allow the wallpaper behind to bleed through.
const STYLING = `
    window { 
        background-color: rgba(17, 17, 27, 0.85); 
        color: #cdd6f4; 
    }
    
    headerbar { 
        background: transparent; 
        border: none; 
        box-shadow: none; 
        min-height: 46px; 
    }
    headerbar title { color: #cba6f7; font-weight: bold; font-size: 16px; }
    
    scrolledwindow { background: transparent; }
    flowbox { background: transparent; }
    
    button {
        background-color: rgba(30, 30, 46, 0.8); /* Slightly transparent cards */
        border-radius: 8px;
        border: 1px solid #313244;
        padding: 0;
        margin: 6px;
        box-shadow: 0 4px 6px rgba(0,0,0,0.3);
        transition: all 0.2s ease;
    }
    button:hover {
        background-color: #45475a;
        border-color: #cba6f7;
        box-shadow: 0 4px 12px rgba(203, 166, 247, 0.3);
        transform: scale(1.02);
    }
`

func main() {
	gtk.Init(nil)

	win, _ := gtk.WindowNew(gtk.WINDOW_TOPLEVEL)
	win.SetTitle("guhwall")
	win.SetDefaultSize(960, 640)
	win.SetIconName("guhwall")
	win.Connect("destroy", func() { gtk.MainQuit() })

	// --- TRANSPARENCY MAGIC STARTS HERE ---
	// 1. Get the screen associated with the window
	screen, _ := win.GetScreen()
	
	// 2. Ask for a visual that supports Alpha (transparency)
	visual, _ := screen.GetRgbaVisual()
	
	// 3. Apply it if available (Compositors like Hyprland/Sway support this)
	if visual != nil {
		win.SetVisual(visual)
	}
	
	// 4. Allow the app to paint its own background (crucial for CSS rgba to work)
	win.SetAppPaintable(true)
	// --- TRANSPARENCY MAGIC ENDS HERE ---

	provider, _ := gtk.CssProviderNew()
	provider.LoadFromData(STYLING)
	gtk.AddProviderForScreen(screen, provider, gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

	vbox, _ := gtk.BoxNew(gtk.ORIENTATION_VERTICAL, 0)
	win.Add(vbox)

	header, _ := gtk.HeaderBarNew()
	header.SetShowCloseButton(true)
	header.SetTitle("guhwall")
	header.SetSubtitle("Wallpaper Manager")
	win.SetTitlebar(header)

	scroll, _ := gtk.ScrolledWindowNew(nil, nil)
	scroll.SetPolicy(gtk.POLICY_AUTOMATIC, gtk.POLICY_AUTOMATIC)
	vbox.PackStart(scroll, true, true, 0)

	grid, _ := gtk.FlowBoxNew()
	grid.SetValign(gtk.ALIGN_START)
	grid.SetSelectionMode(gtk.SELECTION_NONE)
	grid.SetMaxChildrenPerLine(10)
	grid.SetMinChildrenPerLine(1)
	scroll.Add(grid)

	go loadWallpapers(grid)

	win.ShowAll()
	gtk.Main()
}

func loadWallpapers(grid *gtk.FlowBox) {
	home, _ := os.UserHomeDir()
	wallDir := filepath.Join(home, "Pictures", "Wallpapers")
	os.MkdirAll(wallDir, 0755)

	cacheDir := filepath.Join(home, ".cache", "guhwall", "thumbs")
	os.MkdirAll(cacheDir, 0755)

	files, _ := os.ReadDir(wallDir)

	for _, f := range files {
		if f.IsDir() { continue }
		name := f.Name()
		lower := strings.ToLower(name)
		if !strings.HasSuffix(lower, ".jpg") && !strings.HasSuffix(lower, ".png") && !strings.HasSuffix(lower, ".jpeg") && !strings.HasSuffix(lower, ".webp") {
			continue
		}

		fullPath := filepath.Join(wallDir, name)
		thumbPath := getThumbnail(fullPath, cacheDir)

		glib.IdleAdd(func() {
			btn := createButton(fullPath, thumbPath)
			grid.Add(btn)
			grid.ShowAll()
		})
	}
}

func createButton(fullPath, thumbPath string) *gtk.Button {
	btn, _ := gtk.ButtonNew()
	btn.SetSizeRequest(240, 135)
	
	pixbuf, _ := gdk.PixbufNewFromFileAtScale(thumbPath, 240, 135, true)
	img, _ := gtk.ImageNewFromPixbuf(pixbuf)
	btn.Add(img)

	btn.Connect("clicked", func() {
		applyWallpaper(fullPath)
	})
	return btn
}

func applyWallpaper(path string) {
	exec.Command("swww", "img", path, "--transition-type", "grow", "--transition-pos", "center", "--transition-step", "90", "--transition-fps", "120").Run()
	exec.Command("matugen", "image", path).Run()
	exec.Command("notify-send", "-a", "guhwall", "-i", path, "Wallpaper Set", "Global theme updated.").Run()
}

func getThumbnail(originalPath, cacheDir string) string {
	h := md5.New()
	io.WriteString(h, originalPath)
	hash := fmt.Sprintf("%x.jpg", h.Sum(nil))
	thumbPath := filepath.Join(cacheDir, hash)

	if _, err := os.Stat(thumbPath); err == nil {
		return thumbPath
	}
	src, err := imaging.Open(originalPath)
	if err != nil { return originalPath }
	dst := imaging.Resize(src, 300, 0, imaging.Lanczos)
	imaging.Save(dst, thumbPath)
	return thumbPath
}
