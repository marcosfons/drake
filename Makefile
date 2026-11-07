# drake - drag-and-drop source/target with history
#
#   make              build Drake.app (Release)
#   make install      install to ~/.local (override with PREFIX=)
#   make NAME=dd install
#   make test         unit tests
#   make log          drake's log entries from the last hour
#   make uninstall
#   make check-shortcut KEY=ctrl+opt+cmd+D
#
# The app bundle goes to $(PREFIX)/lib and a small launcher script to
# $(PREFIX)/bin, so `drake file.txt` runs the GUI in the current directory.

NAME     ?= drake
PREFIX   ?= $(HOME)/.local
CONFIG   ?= Release
BUILDDIR ?= build

APP      = $(BUILDDIR)/Build/Products/$(CONFIG)/Drake.app
BINARY   = $(APP)/Contents/MacOS/Drake
BINDIR   = $(PREFIX)/bin
LIBDIR   = $(PREFIX)/lib
MANDIR   = $(PREFIX)/share/man/man1
LAUNCHER = $(BINDIR)/$(NAME)

# -quiet keeps the output to warnings and errors.
XCODEBUILD = xcodebuild -project Drake.xcodeproj -scheme Drake -derivedDataPath $(BUILDDIR) -quiet

.PHONY: all build install uninstall test log clean check-shortcut

all: build

build:
	$(XCODEBUILD) -configuration $(CONFIG) build

# Coverage stays off so no default.profraw is written next to the tests.
test:
	$(XCODEBUILD) -destination 'platform=macOS' -enableCodeCoverage NO test

# Refuses to install a binary built with coverage instrumentation: it would
# write default.profraw into whatever directory drake is run from.
install: build
	@if otool -l "$(BINARY)" | grep -q __llvm_prf; then \
		echo "error: $(BINARY) is instrumented for coverage; not installing" >&2; exit 1; \
	fi
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

log:
	@log show --last 1h --style compact --info --debug --predicate 'subsystem == "com.marcos.Drake"'

check-shortcut:
	@tools/check-shortcut.py $(KEY)

clean:
	rm -rf $(BUILDDIR)
