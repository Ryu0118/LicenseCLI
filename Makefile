COMMAND_NAME = licensecli
BINARY_PATH = ./.build/release/$(COMMAND_NAME)
VERSION = 0.0.1

.PHONY: release
release:
	mkdir -p releases
	swift build -c release
	cp $(BINARY_PATH) $(COMMAND_NAME) 
	tar acvf releases/$(COMMAND_NAME)_$(VERSION).tar.gz $(COMMAND_NAME) 
	cp $(COMMAND_NAME) releases/$(COMMAND_NAME)
	rm $(COMMAND_NAME) 
