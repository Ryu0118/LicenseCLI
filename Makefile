SWIFTFORMAT := .nest/bin/swiftformat
SWIFTLINT := .nest/bin/swiftlint
COMMAND_NAME := licensecli
BINARY_PATH := ./.build/apple/Products/Release/$(COMMAND_NAME)
VERSION ?= 0.3.0

.PHONY: install-commands format lint format-lint hooks test check release

install-commands:
	./scripts/nest.sh bootstrap nestfile.yaml

format:
	@test -f "$(SWIFTFORMAT)" || (echo "Run: make install-commands" && exit 1)
	"$(SWIFTFORMAT)" --config .swiftformat .

lint:
	@test -f "$(SWIFTLINT)" || (echo "Run: make install-commands" && exit 1)
	"$(SWIFTLINT)" lint --config .swiftlint.yml --strict

format-lint: format lint

hooks:
	./scripts/setup-hooks.sh

test:
	swift test

check: format lint test

release:
	rm -rf releases
	mkdir -p releases
	swift build -c release --arch x86_64 --arch arm64
	cp "$(BINARY_PATH)" "$(COMMAND_NAME)"
	tar acvf "releases/licensecli_$(VERSION).tar.gz" "$(COMMAND_NAME)"
	cp "$(COMMAND_NAME)" "releases/$(COMMAND_NAME)"
	rm "$(COMMAND_NAME)"
