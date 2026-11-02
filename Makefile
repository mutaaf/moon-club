# Moon Club — one idempotent entry point: `make up` (generate, sync-free build, test, launch in the simulators).
SIM_PHONE ?= iPhone 17
SIM_PAD ?= iPad Pro 11-inch (M5)
DD := build/dd

.PHONY: up gen build test core rules sim shots widgets device testflight content clean
up: gen test sim
gen:
	@command -v xcodegen >/dev/null || brew install xcodegen
	@xcodebuild -showComponent MetalToolchain 2>/dev/null | grep -q 'Status: installed' || xcodebuild -downloadComponent MetalToolchain
	xcodegen generate
build: gen
	xcodebuild -project MoonClub.xcodeproj -scheme MoonClub -destination 'platform=iOS Simulator,name=$(SIM_PHONE)' -derivedDataPath $(DD) -quiet build
core:
	cd Packages/MoonClubCore && swift test
rules:
	scripts/check-rules.sh
test: gen rules core
	xcodebuild -project MoonClub.xcodeproj -scheme MoonClub -destination 'platform=iOS Simulator,name=$(SIM_PHONE)' -derivedDataPath $(DD) -quiet test
sim: build
	@for n in "$(SIM_PHONE)" "$(SIM_PAD)"; do \
	  id=$$(xcrun simctl list devices available | grep -F "    $$n (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'); \
	  xcrun simctl boot $$id 2>/dev/null || true; xcrun simctl install $$id $(DD)/Build/Products/Debug-iphonesimulator/MoonClub.app; \
	  xcrun simctl launch $$id com.mutaafaziz.moonclub >/dev/null; done; open -a Simulator
widgets: gen
	scripts/widget-shots.sh
shots: build
	scripts/shots.sh
device:
	scripts/device.sh
testflight:
	scripts/testflight.sh
content:
	scripts/sync-content.sh
clean:
	rm -rf build MoonClub.xcodeproj
