use gtk4::prelude::*;
use libadwaita::prelude::*;
use libadwaita::{Application, ApplicationWindow, HeaderBar, ToastOverlay, Toast};
use gtk4::{
    Align, Button, DropDown, FileDialog,
    GridView, Label, ListItem, Orientation,
    Picture, PolicyType, ScrolledWindow, SearchEntry,
    SignalListItemFactory, SingleSelection, StringList,
    gdk, glib, gio, Overflow
};
use serde::{Deserialize, Serialize};
use std::cell::RefCell;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::rc::Rc;
use std::sync::{Arc, Mutex};
use std::hash::{Hash, Hasher};
use std::collections::hash_map::DefaultHasher;
use walkdir::WalkDir;

const APP_ID: &str = "com.github.guhwall";
const THUMB_W: i32 = 240;
const THUMB_H: i32 = 150;

// ==================================================================================
// MODULE 1: CUSTOM GOBJECT
// ==================================================================================
mod wallpaper_object {
    use gtk4::glib;
    use gtk4::subclass::prelude::*;
    use std::cell::RefCell;
    use std::path::PathBuf;

    #[derive(Default)]
    pub struct WallpaperData {
        pub path: RefCell<PathBuf>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for WallpaperData {
        const NAME: &'static str = "WallpaperObject";
        type Type = super::WallpaperObject;
        type ParentType = glib::Object;
    }

    impl ObjectImpl for WallpaperData {}

    glib::wrapper! {
        pub struct WallpaperObject(ObjectSubclass<WallpaperData>);
    }

    impl WallpaperObject {
        pub fn new(path: PathBuf) -> Self {
            let obj: Self = glib::Object::builder().build();
            *obj.imp().path.borrow_mut() = path;
            obj
        }

        pub fn path(&self) -> PathBuf {
            self.imp().path.borrow().clone()
        }
    }
}
use wallpaper_object::WallpaperObject;

// ==================================================================================
// MODULE 2: CONFIG & STATE
// ==================================================================================

#[derive(Debug, Serialize, Deserialize, Clone, Copy, PartialEq)]
enum Backend { Swww, Swaybg, Hyprpaper, Feh, Wallutils }

impl Backend {
    fn all() -> Vec<Backend> { vec![Backend::Swww, Backend::Swaybg, Backend::Hyprpaper, Backend::Feh, Backend::Wallutils] }
    fn as_str(&self) -> &'static str {
        match self {
            Backend::Swww => "swww", Backend::Swaybg => "swaybg",
            Backend::Hyprpaper => "hyprpaper", Backend::Feh => "feh", Backend::Wallutils => "wallutils",
        }
    }
}

#[derive(Debug, Serialize, Deserialize, Clone, Copy, PartialEq)]
enum ThemeBackend { Pywal, Matugen, None }

impl ThemeBackend {
    fn all() -> Vec<ThemeBackend> { vec![ThemeBackend::Pywal, ThemeBackend::Matugen, ThemeBackend::None] }
    fn as_str(&self) -> &'static str {
        match self { ThemeBackend::Pywal => "pywal", ThemeBackend::Matugen => "matugen", ThemeBackend::None => "none" }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct AppConfig {
    wallpaper_dir: PathBuf,
    backend: Backend,
    theme_backend: ThemeBackend,
}

impl Default for AppConfig {
    fn default() -> Self {
        let home = directories::UserDirs::new().expect("No home").home_dir().to_path_buf();
        Self { wallpaper_dir: home.join("Pictures"), backend: Backend::Swww, theme_backend: ThemeBackend::Pywal }
    }
}

struct AppState {
    config: AppConfig,
    store: gtk4::gio::ListStore,
}

impl AppState {
    fn new(config: AppConfig) -> Self {
        let store = gtk4::gio::ListStore::new::<WallpaperObject>();
        Self { config, store }
    }
    fn save_config(&self) {
        let dirs = directories::ProjectDirs::from("com", "github", "guhwall").unwrap();
        let _ = std::fs::create_dir_all(dirs.config_dir());
        let _ = std::fs::write(dirs.config_dir().join("config.toml"), toml::to_string(&self.config).unwrap());
    }
}

// ==================================================================================
// MODULE 3: CACHING & THREAD POOL
// ==================================================================================

type TextureCache = Arc<Mutex<HashMap<PathBuf, gdk::Texture>>>;

fn get_texture_cache() -> TextureCache {
    static CACHE: once_cell::sync::OnceCell<TextureCache> = once_cell::sync::OnceCell::new();
    CACHE.get_or_init(|| Arc::new(Mutex::new(HashMap::new()))).clone()
}

struct LoadedImage {
    path: PathBuf,
    width: i32,
    height: i32,
    bytes: glib::Bytes,
}

fn get_cache_path(original_path: &Path) -> PathBuf {
    let dirs = directories::ProjectDirs::from("com", "github", "guhwall").unwrap();
    let cache_dir = dirs.cache_dir();
    if !cache_dir.exists() { let _ = std::fs::create_dir_all(cache_dir); }
    
    let mut hasher = DefaultHasher::new();
    original_path.hash(&mut hasher);
    cache_dir.join(format!("{}.jpg", hasher.finish()))
}

fn load_thumbnail_async(path: PathBuf, sender: async_channel::Sender<LoadedImage>) {
    rayon::spawn(move || {
        let cache_path = get_cache_path(&path);
        let mut final_image: Option<image::DynamicImage> = None;

        if cache_path.exists() {
            if let Ok(img) = image::open(&cache_path) {
                final_image = Some(img);
            }
        }

        if final_image.is_none() {
            if let Ok(metadata) = std::fs::metadata(&path) {
                 if metadata.len() < 100 * 1024 * 1024 { 
                     if let Ok(img) = image::open(&path) {
                        let thumb = img.resize_to_fill(
                            THUMB_W as u32, 
                            THUMB_H as u32, 
                            image::imageops::FilterType::Triangle 
                        );
                        let _ = thumb.save_with_format(&cache_path, image::ImageFormat::Jpeg);
                        final_image = Some(thumb);
                     }
                 }
            }
        }

        if let Some(img) = final_image {
            let rgba = img.to_rgba8();
            let width = rgba.width() as i32;
            let height = rgba.height() as i32;
            let _ = sender.send_blocking(LoadedImage {
                path, 
                width, 
                height, 
                bytes: glib::Bytes::from(&rgba.into_raw())
            });
        }
    });
}

// ==================================================================================
// MODULE 4: UI
// ==================================================================================

fn main() {
    libadwaita::init().expect("Failed to init LibAdwaita");
    
    rayon::ThreadPoolBuilder::new()
        .stack_size(4 * 1024 * 1024)
        .build_global()
        .unwrap_or(());

    let provider = gtk4::CssProvider::new();
    provider.load_from_string("
        .wallpaper_card {
            background-color: #252525;
            border-radius: 12px;
            margin: 4px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.3);
        }
        .wallpaper_card:hover {
            background-color: #333333;
            box-shadow: 0 3px 8px rgba(0,0,0,0.5);
        }
        window { background-color: #1e1e1e; }
    ");
    gtk4::style_context_add_provider_for_display(
        &gdk::Display::default().unwrap(), &provider, gtk4::STYLE_PROVIDER_PRIORITY_APPLICATION,
    );

    let app = Application::builder().application_id(APP_ID).build();
    app.connect_activate(build_ui);
    app.run();
}

fn build_ui(app: &Application) {
    let config = load_config();
    let app_state = Rc::new(RefCell::new(AppState::new(config)));

    let content_box = gtk4::Box::new(Orientation::Vertical, 0);
    let header = HeaderBar::builder().title_widget(&Label::new(Some("GuhWall"))).build();
    content_box.append(&header);

    let toast_overlay = ToastOverlay::new();
    let main_content = gtk4::Box::new(Orientation::Vertical, 0);
    toast_overlay.set_child(Some(&main_content));
    content_box.append(&toast_overlay);

    let toolbar = gtk4::Box::builder().orientation(Orientation::Horizontal).spacing(10)
        .margin_start(12).margin_end(12).margin_top(12).margin_bottom(12).build();
    
    let folder_btn = Button::with_label("Folder");
    let search_entry = SearchEntry::builder().hexpand(true).placeholder_text("Search...").build();
    
    let backend_list = StringList::new(&Backend::all().iter().map(|b| b.as_str()).collect::<Vec<_>>());
    let backend_dropdown = DropDown::builder().model(&backend_list).build();
    backend_dropdown.set_selected(Backend::all().iter().position(|&x| x == app_state.borrow().config.backend).unwrap_or(0) as u32);

    let theme_list = StringList::new(&ThemeBackend::all().iter().map(|t| t.as_str()).collect::<Vec<_>>());
    let theme_dropdown = DropDown::builder().model(&theme_list).build();
    theme_dropdown.set_selected(ThemeBackend::all().iter().position(|&x| x == app_state.borrow().config.theme_backend).unwrap_or(0) as u32);

    let random_btn = Button::with_label("Random");

    toolbar.append(&folder_btn);
    toolbar.append(&search_entry);
    toolbar.append(&backend_dropdown);
    toolbar.append(&theme_dropdown);
    toolbar.append(&random_btn);
    main_content.append(&toolbar);

    let selection_model = SingleSelection::new(Some(app_state.borrow().store.clone()));
    let factory = SignalListItemFactory::new();

    factory.connect_setup(|_, list_item| {
        let list_item = list_item.downcast_ref::<ListItem>().unwrap();
        let container = gtk4::Box::builder()
            .css_classes(vec!["wallpaper_card"])
            .halign(Align::Center).valign(Align::Center)
            .width_request(THUMB_W).height_request(THUMB_H)
            .overflow(Overflow::Hidden)
            .build();
        let picture = Picture::builder().can_shrink(false).content_fit(gtk4::ContentFit::Cover).build();
        container.append(&picture);
        list_item.set_child(Some(&container));
    });

    factory.connect_bind(move |_, list_item| {
        let list_item = list_item.downcast_ref::<ListItem>().unwrap();
        let item = list_item.item().and_downcast::<WallpaperObject>().unwrap();
        let container = list_item.child().and_downcast::<gtk4::Box>().unwrap();
        let picture = container.first_child().and_downcast::<Picture>().unwrap();
        let path = item.path();

        let cache = get_texture_cache();
        let cached_texture = { cache.lock().unwrap().get(&path).cloned() };

        if let Some(texture) = cached_texture {
            picture.set_paintable(Some(&texture));
        } else {
            picture.set_paintable(None::<&gdk::Texture>);
            let (sender, receiver) = async_channel::unbounded();
            load_thumbnail_async(path.clone(), sender);
            
            let picture_weak = picture.downgrade();
            glib::spawn_future_local(async move {
                if let Ok(loaded) = receiver.recv().await {
                    if let Some(pic) = picture_weak.upgrade() {
                        let texture = gdk::MemoryTexture::new(
                            loaded.width, loaded.height,
                            gdk::MemoryFormat::R8g8b8a8,
                            &loaded.bytes, loaded.width as usize * 4
                        );
                        get_texture_cache().lock().unwrap().insert(loaded.path, texture.upcast_ref::<gdk::Texture>().clone());
                        pic.set_paintable(Some(&texture));
                    }
                }
            });
        }
    });

    let grid_view = GridView::builder()
        .model(&selection_model)
        .factory(&factory)
        .max_columns(20)
        .min_columns(3)
        // -------- THE FIX IS HERE --------
        .single_click_activate(true) 
        // ---------------------------------
        .build();

    let scrolled_window = ScrolledWindow::builder().hscrollbar_policy(PolicyType::Never).child(&grid_view).vexpand(true).build();
    main_content.append(&scrolled_window);

    let window = ApplicationWindow::builder().application(app).title("GuhWall").default_width(1050).default_height(750).content(&content_box).build();
    window.present();

    let initial_dir = app_state.borrow().config.wallpaper_dir.clone();
    scan_directory(initial_dir, app_state.clone());

    let s_back = app_state.clone();
    backend_dropdown.connect_notify_local(Some("selected-item"), move |dd, _| {
        let idx = dd.selected() as usize;
        let mut s = s_back.borrow_mut();
        s.config.backend = Backend::all()[idx];
        s.save_config();
    });

    let s_theme = app_state.clone();
    theme_dropdown.connect_notify_local(Some("selected-item"), move |dd, _| {
        let idx = dd.selected() as usize;
        let mut s = s_theme.borrow_mut();
        s.config.theme_backend = ThemeBackend::all()[idx];
        s.save_config();
    });

    let s_click = app_state.clone();
    let t_click = toast_overlay.clone();
    grid_view.connect_activate(move |_, position| {
        let state = s_click.borrow();
        if let Some(obj) = state.store.item(position) {
            let item = obj.downcast::<WallpaperObject>().unwrap();
            apply_wallpaper(&state.config.backend, &state.config.theme_backend, &item.path(), false);
            t_click.add_toast(Toast::new(&format!("Set: {:?}", item.path().file_name().unwrap())));
        }
    });

    let win_weak = window.downgrade();
    let s_folder = app_state.clone();
    folder_btn.connect_clicked(move |_| {
        let win = match win_weak.upgrade() { Some(w) => w, None => return };
        let dialog = FileDialog::builder().title("Select Folder").modal(true).build();
        let s_rc = s_folder.clone();
        dialog.select_folder(Some(&win), gio::Cancellable::NONE, move |res| {
             if let Ok(f) = res { if let Some(p) = f.path() {
                 s_rc.borrow_mut().config.wallpaper_dir = p.clone();
                 s_rc.borrow().save_config();
                 scan_directory(p, s_rc.clone());
             }}}
        );
    });

    let s_rand = app_state.clone();
    let t_rand = toast_overlay.clone();
    random_btn.connect_clicked(move |_| {
        let state = s_rand.borrow();
        let count = state.store.n_items();
        if count > 0 {
            let idx = rand::random::<u32>() % count;
            if let Some(obj) = state.store.item(idx) {
                let item = obj.downcast::<WallpaperObject>().unwrap();
                apply_wallpaper(&state.config.backend, &state.config.theme_backend, &item.path(), true);
                t_rand.add_toast(Toast::new("Random Wallpaper Set"));
            }
        }
    });
}

fn scan_directory(path: PathBuf, app_state: Rc<RefCell<AppState>>) {
    let (sender, receiver) = async_channel::unbounded();
    rayon::spawn(move || {
        let mut paths = Vec::new();
        for entry in WalkDir::new(path).max_depth(1).into_iter()
            .filter_entry(|e| !e.file_name().to_str().map(|s| s.starts_with('.')).unwrap_or(false))
            .filter_map(|e| e.ok()) 
        {
            let p = entry.path().to_path_buf();
            if let Some(ext) = p.extension() {
                let s = ext.to_str().unwrap_or("").to_lowercase();
                if ["jpg", "jpeg", "png", "webp", "gif"].contains(&s.as_str()) {
                    paths.push(p);
                }
            }
        }
        let _ = sender.send_blocking(paths);
    });
    
    glib::spawn_future_local(async move {
        if let Ok(paths) = receiver.recv().await {
            let state = app_state.borrow();
            state.store.remove_all();
            let objects: Vec<WallpaperObject> = paths.into_iter().map(WallpaperObject::new).collect();
            state.store.extend_from_slice(&objects);
        }
    });
}

fn apply_wallpaper(backend: &Backend, theme: &ThemeBackend, path: &Path, random: bool) {
    let path_str = path.to_string_lossy();
    match backend {
        Backend::Swww => {
             let _ = Command::new("swww-daemon").spawn();
             let mut cmd = Command::new("swww");
             cmd.arg("img").arg(&*path_str);
             if random { cmd.arg("--transition-type").arg("random"); }
             let _ = cmd.spawn();
        },
        Backend::Swaybg => {
            let _ = Command::new("pkill").arg("swaybg").output();
            let _ = Command::new("swaybg").arg("-i").arg(&*path_str).arg("-m").arg("fill").spawn();
        },
        _ => {}
    }
    match theme {
        ThemeBackend::Pywal => { let _ = Command::new("wal").arg("-i").arg(&*path_str).arg("-n").spawn(); },
        ThemeBackend::Matugen => { let _ = Command::new("matugen").arg("image").arg(&*path_str).spawn(); },
        ThemeBackend::None => {},
    }
}

fn load_config() -> AppConfig {
    let dirs = directories::ProjectDirs::from("com", "github", "guhwall").unwrap();
    if let Ok(c) = std::fs::read_to_string(dirs.config_dir().join("config.toml")) {
        if let Ok(cfg) = toml::from_str(&c) { return cfg; }
    }
    AppConfig::default()
}
