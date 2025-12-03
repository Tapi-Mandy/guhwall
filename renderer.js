const { ipcRenderer } = require('electron');
const path = require('path');
const os = require('os');

const gallery = document.getElementById('gallery');
const btnFolder = document.getElementById('btn-folder');
const lblPath = document.getElementById('current-path');
const toast = document.getElementById('toast');

// --- INITIALIZATION ---
(async () => {
    const lastPath = await ipcRenderer.invoke('get-last-path');
    loadImages(lastPath);
})();

async function loadImages(dir) {
    const displayPath = dir.replace(os.homedir(), '~');
    lblPath.innerText = displayPath;
    
    gallery.innerHTML = ''; 

    const images = await ipcRenderer.invoke('get-images', dir);

    if (images.length === 0) {
        gallery.innerHTML = '<div style="grid-column: 1/-1; text-align: center; color: #555; margin-top: 50px;">No images found in this folder.</div>';
        return;
    }

images.forEach(imgData => {
    const card = document.createElement('div');
    card.className = 'card';
    
    const filename = path.basename(imgData);
    const fileUrl = `file://${imgData.split(path.sep).map(encodeURIComponent).join(path.sep)}`;

    card.innerHTML = `
        <img src="${fileUrl}" loading="lazy">
        <div class="card-overlay">
            <div class="filename">${filename}</div>
        </div>
    `;

    card.onclick = () => applyWallpaper(imgData);
    gallery.appendChild(card);
});
}

btnFolder.onclick = async () => {
    const newPath = await ipcRenderer.invoke('select-folder');
    if (newPath) {
        await ipcRenderer.invoke('save-last-path', newPath);
        loadImages(newPath);
    }
};

async function applyWallpaper(imagePath) {
    showToast("Applying...", "#666");
    try {
        await ipcRenderer.invoke('apply-wallpaper', imagePath);
        // Toast Success Color
        showToast("Wallpaper Applied!", "#937e73");
    } catch (err) {
        showToast("Error Failed", "#cf3636");
        console.error(err);
    }
}

function showToast(msg, color) {
    toast.innerText = msg;
    toast.style.background = color;
    toast.classList.add('show');
    setTimeout(() => {
        toast.classList.remove('show');
    }, 2000);
}
