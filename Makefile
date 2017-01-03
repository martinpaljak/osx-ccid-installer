# Target 10.11+
CFLAGS = -mmacosx-version-min=10.11
export CFLAGS

TARGET ?= $(CURDIR)/target
BUILDPREFIX ?= $(CURDIR)/tmp
CCIDVER = $(shell cd CCID && git describe --always --tags --long)

PKG_CONFIG_PATH = $(BUILDPREFIX)/lib/pkgconfig
export PKG_CONFIG_PATH

# SIGNER ?= Martin Paljak
ifneq ($(strip $(SIGNER)),)
  PKGSIGN = --sign "Developer ID Installer: $(SIGNER)"
endif

.PHONY: default clean
.NOTPARALLEL default: clean dmg srcdist

pkg: ccid-installer.pkg
dmg: ccid-installer.dmg

clean:
	git submodule foreach git clean -dfx
	git submodule foreach git reset --hard
	rm -rf target tmp *.pkg *.dmg

LIBUSB = $(BUILDPREFIX)/lib/libusb-1.0.a
BUNDLE = $(TARGET)/usr/local/libexec/SmartCardServices/drivers/ifd-ccid.bundle

$(LIBUSB):
	(cd libusb \
	&& ./autogen.sh \
	&& ./configure --prefix=$(BUILDPREFIX) --disable-dependency-tracking --enable-static --disable-shared \
	&& $(MAKE) \
	&& $(MAKE) install \
	)

$(BUNDLE): $(LIBUSB)
	(cd CCID \
	&& ./bootstrap \
	&& ./MacOSX/configure \
	&& $(MAKE) \
	&& $(MAKE) install DESTDIR=$(TARGET) \
	)

srcdist:
	$(MAKE) -C CCID dist-gzip
	mv CCID/ccid-*.tar.gz $(CCIDVER).tar.gz

ifd-ccid.pkg: $(BUNDLE)
	test -z "$(SIGNER)" || codesign -f -s "Developer ID Application: $(SIGNER)" $(BUNDLE)
	pkgbuild --root $(TARGET) --scripts scripts --identifier org.openkms.mac.ccid --version $(CCIDVER) --install-location / --ownership recommended $@

ccid-installer.pkg: ifd-ccid.pkg
	productbuild --distribution Distribution.xml --package-path . --resources resources $(PKGSIGN) $@

uninstall.pkg: uninstaller-scripts/postinstall
	pkgbuild --nopayload --identifier org.openkms.mac.ccid.uninstall --scripts uninstaller-scripts $(PKGSIGN) $@

ccid-installer.dmg: ccid-installer.pkg uninstall.pkg
	hdiutil create -ov -srcfolder uninstall.pkg -srcfolder ccid-installer.pkg -volname "CCID installer ($(CCIDVER))" $@
	test -z "$(SIGNER)" || codesign -f -s "Developer ID Application: $(SIGNER)" $@
