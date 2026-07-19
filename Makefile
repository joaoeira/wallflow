.PHONY: build test app open clean

build:
	swift build

test:
	swift test

app:
	./Scripts/package_app.sh

open: app
	open ./dist/Wallflow.app

clean:
	swift package clean
