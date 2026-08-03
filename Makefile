# drake - drag-and-drop source/target with history
#
#   make              build Drake.app
#   make install      install to ~/.local (override with PREFIX=)
#   make NAME=dd install
#   make test
#   make uninstall
#   make check-shortcut KEY=ctrl+opt+cmd+D
#
# The app bundle goes to $(PREFIX)/lib and a small launcher script to
# $(PREFIX)/bin, so `drake file.txt` runs the GUI in the current directory.

NAME     ?= drake
PREFIX   ?= $(HOME)/.local
CONFIG   ?= Release
BUILDDIR ?= build

APP     = $(BUILDDIR)/Build/Products/$(CONFIG)/Drake.app
BINDIR  = $(PREFIX)/bin
LIBDIR  = $(PREFIX)/lib
MANDIR  = $(PREFIX)/share/man/man1
LAUNCHER = $(BINDIR)/$(NAME)

XCODEBUILD = xcodebuild -project Drake.xcodeproj -scheme Drake -derivedDataPath $(BUILDDIR)

.PHONY: all build install uninstall test clean check-shortcut

all: build

build:
	$(XCODEBUILD) -configuration $(CONFIG) build

test:
	$(XCODEBUILD) -destination 'platform=macOS' -only-testing:DrakeTests test

install: build
	mkdir -p "$(BINDIR)" "$(LIBDIR)" "$(MANDIR)"
	rm -rf "$(LIBDIR)/Drake.app"
	cp -R "$(APP)" "$(LIBDIR)/Drake.app"
	printf '#!/bin/sh\n# Launcher for Drake. Runs the app binary directly so it\n# inherits the working directory, stdout and arguments.\nexec "%s/Drake.app/Contents/MacOS/Drake" "$$@"\n' "$(LIBDIR)" > "$(LAUNCHER)"
	chmod +x "$(LAUNCHER)"
	sed 's/@NAME@/$(NAME)/g' drake.1 > "$(MANDIR)/$(NAME).1"
	@echo
	@echo "Installed $(LAUNCHER)"
	@case ":$$PATH:" in \
		*":$(BINDIR):"*) echo "$(BINDIR) is on your PATH - run: $(NAME) file.txt" ;; \
		*) echo "NOTE: $(BINDIR) is not on your PATH. Add to ~/.zshrc:"; \
		   echo "      export PATH=\"$(BINDIR):\$$PATH\"" ;; \
	esac

uninstall:
	rm -rf "$(LIBDIR)/Drake.app"
	rm -f "$(LAUNCHER)" "$(MANDIR)/$(NAME).1"

check-shortcut:
	@tools/check-shortcut.py $(KEY)

clean:
	rm -rf $(BUILDDIR)
