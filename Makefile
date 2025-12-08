BINARY_NAME=guhwall
INSTALL_DIR=/usr/local/bin
DESKTOP_DIR=/usr/share/applications
ICON_DIR=/usr/share/icons/hicolor/scalable/apps

all: build

build:
	@echo "Building guhwall..."
	go build -ldflags "-s -w" -o $(BINARY_NAME) main.go

install: build
	@echo "Installing Binary..."
	@sudo mkdir -p $(INSTALL_DIR)
	@sudo cp $(BINARY_NAME) $(INSTALL_DIR)/
	
	@echo "Installing Icon..."
	@sudo mkdir -p $(ICON_DIR)
	@sudo cp icon.svg $(ICON_DIR)/$(BINARY_NAME).svg
	
	@echo "Generating Desktop Entry..."
	@echo "[Desktop Entry]" | sudo tee $(DESKTOP_DIR)/$(BINARY_NAME).desktop > /dev/null
	@echo "Type=Application" | sudo tee -a $(DESKTOP_DIR)/$(BINARY_NAME).desktop > /dev/null
	@echo "Name=guhwall" | sudo tee -a $(DESKTOP_DIR)/$(BINARY_NAME).desktop > /dev/null
	@echo "Comment=Guh Wallpaper Manager" | sudo tee -a $(DESKTOP_DIR)/$(BINARY_NAME).desktop > /dev/null
	@echo "Exec=$(BINARY_NAME)" | sudo tee -a $(DESKTOP_DIR)/$(BINARY_NAME).desktop > /dev/null
	@echo "Icon=$(BINARY_NAME)" | sudo tee -a $(DESKTOP_DIR)/$(BINARY_NAME).desktop > /dev/null
	@echo "Categories=Utility;DesktopSettings;" | sudo tee -a $(DESKTOP_DIR)/$(BINARY_NAME).desktop > /dev/null
	@echo "Terminal=false" | sudo tee -a $(DESKTOP_DIR)/$(BINARY_NAME).desktop > /dev/null
	@sudo chmod 644 $(DESKTOP_DIR)/$(BINARY_NAME).desktop
	
	@echo "Updating system caches..."
	@sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor/
	@sudo update-desktop-database
	@echo "Done."

uninstall:
	@sudo rm -f $(INSTALL_DIR)/$(BINARY_NAME)
	@sudo rm -f $(DESKTOP_DIR)/$(BINARY_NAME).desktop
	@sudo rm -f $(ICON_DIR)/$(BINARY_NAME).svg
	@echo "Uninstalled."

clean:
	rm -f $(BINARY_NAME)
