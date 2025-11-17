COMMAND_NAME = licensecli 
BINARY_PATH = ./.build/apple/Products/Release/$(COMMAND_NAME)
VERSION = 0.3.0

.PHONY: release
release:
	rm -rf releases
	mkdir -p releases
	swift build -c release --arch x86_64 --arch arm64
	cp $(BINARY_PATH) $(COMMAND_NAME) 
	tar acvf releases/licensecli_$(VERSION).tar.gz $(COMMAND_NAME) 
	cp $(COMMAND_NAME) releases/$(COMMAND_NAME)
	rm $(COMMAND_NAME) 
