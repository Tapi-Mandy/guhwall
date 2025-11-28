const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { exec } = require('child_process');

// --- INPUT FIX SCRIPT ---
const INPUT_FIX_SCRIPT = `
MASTER_POINTER=$(xinput list | grep "master pointer" | grep -o "id=[0-9]*" | cut -d= -f2)
MASTER_KEYBOARD=$(xinput list | grep "master keyboard" | grep -o "id=[0-9]*" | cut -d= -f2)
POINTER_IDS=$(xinput list | grep "slave.*pointer" | grep -v "XTEST" | grep -o "id=[0-9]*" | cut -d= -f2)
KEYBOARD_IDS=$(xinput list | grep "slave.*keyboard" | grep -v "XTEST" | grep -o "id=[0-9]*" | cut -d= -f2)

for id in $POINTER_IDS $KEYBOARD_IDS; do xinput float "$id" 2>/dev/null; done
xdotool key super+n
sleep 0.1
for id in $POINTER_IDS; do xinput reattach "$id" "$MASTER_POINTER" 2>/dev/null; done
for id in $KEYBOARD_IDS; do xinput reattach "$id" "$MASTER_KEYBOARD" 2>/dev/null; done
`;

const CONFIG_FILE = path.join(app.getPath('userData'), 'config.json');

function getLastPath() {
    // 1. DEFAULT PATH (System)
    const defaultPath = '/usr/share/backgrounds/guhwm_wallpapers';
    
    try {
        if (fs.existsSync(CONFIG_FILE)) {
            const data = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf-8'));
            if (data.lastPath && fs.existsSync(data.lastPath)) {
                return data.lastPath;
            }
        }
    } catch (e) {
        console.error("Config read error:", e);
    }
    return defaultPath;
}

function saveLastPath(newPath) {
    try {
        if (!fs.existsSync(app.getPath('userData'))) {
            fs.mkdirSync(app.getPath('userData'), { recursive: true });
        }
        fs.writeFileSync(CONFIG_FILE, JSON.stringify({ lastPath: newPath }));
    } catch (e) { console.error(e); }
}

let mainWindow;

function createWindow() {
    mainWindow = new BrowserWindow({
        // 2. WINDOW SIZE (Fixed here)
        width: 1200,
        height: 800,
        title: "GuhWall",
        transparent: true,
        backgroundColor: '#00000000',
        webPreferences: {
            nodeIntegration: true,
            contextIsolation: false,
            webSecurity: false
        },
        autoHideMenuBar: true
    });

    mainWindow.loadFile('index.html');
}

app.whenReady().then(createWindow);

// --- IPC HANDLERS ---
ipcMain.handle('get-images', async (event, dirPath) => {
    try {
        if (!fs.existsSync(dirPath)) return [];
        const files = fs.readdirSync(dirPath);
        return files.filter(file => 
            ['.jpg', '.jpeg', '.png', '.webp', '.bmp'].includes(path.extname(file).toLowerCase())
        ).map(file => path.join(dirPath, file));
    } catch (err) { return []; }
});

ipcMain.handle('select-folder', async () => {
    const result = await dialog.showOpenDialog(mainWindow, { properties: ['openDirectory'] });
    if (result.canceled) return null;
    return result.filePaths[0];
});

ipcMain.handle('apply-wallpaper', async (event, imagePath) => {
    return new Promise((resolve, reject) => {
        // 3. RUN WALRS
        exec(`walrs -i "${imagePath}"`, (error, stdout, stderr) => {
            if (error) console.error("Walrs error:", stderr);

            // 4. FORCE SCALE (FEH)
            exec(`feh --bg-scale "${imagePath}"`, (fehErr) => {
                
                // 5. INPUT FIX SCRIPT
                exec(INPUT_FIX_SCRIPT, { shell: '/bin/bash' }, (scriptErr) => {
                    resolve("Success");
                });
            });
        });
    });
});

ipcMain.handle('get-last-path', () => getLastPath());
ipcMain.handle('save-last-path', (event, newPath) => saveLastPath(newPath));
