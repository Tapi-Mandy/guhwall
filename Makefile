# Makefile for guhwall

# Build directories
BUILD_DIR = dist/linux-unpacked
INSTALL_DIR = /opt/guhwall
BIN_DIR = /usr/bin
DESKTOP_DIR = /usr/share/applications
ICON_DIR = /usr/share/icons/hicolor/scalable/apps

# This "build" step ensures the binary is fresh before installing
build:
	npm run dist

install:
	@echo "Installing guhwall Binary..."
	
	# 1. Clean old install
	rm -rf $(INSTALL_DIR)
	mkdir -p $(INSTALL_DIR)
	
	# 2. Copy the COMPILED application (not the source code)
	cp -r $(BUILD_DIR)/* $(INSTALL_DIR)
	
	# 3. Link the binary
	# We link directly to the executable electron-builder created
	ln -sf $(INSTALL_DIR)/guhwall $(BIN_DIR)/guhwall
	
	# 4. Install Desktop File and Icon
	mkdir -p $(ICON_DIR)
	cp icon.svg $(ICON_DIR)/guhwall.svg
	cp guhwall.desktop $(DESKTOP_DIR)/guhwall.desktop
	
	@echo "Success! guhwall is installed."

uninstall:
	@echo "Uninstalling..."
	rm -rf $(INSTALL_DIR)
	rm -f $(BIN_DIR)/guhwall
	rm -f $(ICON_DIR)/guhwall.svg
	rm -f $(DESKTOP_DIR)/guhwall.desktop
	@echo "Done."
all: build install
