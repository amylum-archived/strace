PACKAGE = strace
ORG = amylum

DEP_DIR = /tmp/dep-dir

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/v//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

PATH_FLAGS = --prefix=/usr
CONF_FLAGS = --with-libunwind
CFLAGS = -I$(DEP_DIR)/usr/include

LIBUNWIND_VERSION = 1.1-4
LIBUNWIND_URL = https://github.com/amylum/libunwind/releases/download/$(LIBUNWIND_VERSION)/libunwind.tar.gz
LIBUNWIND_TAR = /tmp/libunwind.tar.gz
LIBUNWIND_DIR = /tmp/libunwind
LIBUNWIND_PATH = -I$(LIBUNWIND_DIR)/usr/include -L$(LIBUNWIND_DIR)/usr/lib

.PHONY : default submodule deps manual container deps build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	mkdir -p $(DEP_DIR)/usr/include/
	cp -R /usr/include/{linux,asm,asm-generic,mtd} $(DEP_DIR)/usr/include/
	rm -rf $(LIBUNWIND_DIR) $(LIBUNWIND_TAR)
	mkdir $(LIBUNWIND_DIR)
	curl -sLo $(LIBUNWIND_TAR) $(LIBUNWIND_URL)
	tar -x -C $(LIBUNWIND_DIR) -f $(LIBUNWIND_TAR)

build: deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS) $(LIBUNWIND_PATH)' CPPFLAGS='$(CFLAGS) $(LIBUNWIND_PATH)' ./configure $(PATH_FLAGS) $(CONF_FLAGS)
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) install
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/COPYING $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

