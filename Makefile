APP_NAME = ColimaBar
SCHEME = ColimaBar
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME).xcarchive
APP_PATH = $(BUILD_DIR)/$(APP_NAME).app
ZIP_PATH = $(BUILD_DIR)/$(APP_NAME).zip
VERSION = $(shell grep 'MARKETING_VERSION' project.yml | head -1 | sed 's/.*"\(.*\)"/\1/')

.PHONY: all clean build archive zip icon xcodegen

all: zip

clean:
	rm -rf $(BUILD_DIR) $(APP_NAME).xcodeproj

xcodegen:
	xcodegen

icon:
	swift Scripts/generate-app-icon.swift

build: xcodegen
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination 'platform=macOS' \
		-derivedDataPath $(BUILD_DIR)/derived \
		build

archive: xcodegen
	xcodebuild -project $(APP_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination 'generic/platform=macOS' \
		-archivePath $(ARCHIVE_PATH) \
		archive
	mkdir -p $(BUILD_DIR)
	cp -R $(ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app $(APP_PATH)

zip: archive
	cd $(BUILD_DIR) && ditto -c -k --keepParent $(APP_NAME).app $(APP_NAME).zip
	@echo ""
	@echo "Built $(ZIP_PATH) (v$(VERSION))"
	@echo "SHA-256: $$(shasum -a 256 $(ZIP_PATH) | cut -d' ' -f1)"

install: archive
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP_PATH) /Applications/$(APP_NAME).app
	@echo "Installed to /Applications/$(APP_NAME).app"

uninstall:
	rm -rf /Applications/$(APP_NAME).app
