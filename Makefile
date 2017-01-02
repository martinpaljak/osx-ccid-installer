# Target 10.11+
CFLAGS = -mmacosx-version-min=10.11
export CFLAGS

TARGET = $(PWD)/target
BUILDPREFIX = $(PWD)/tmp
CCIDVER = $(shell cd CCID && git describe --always --tags --long)
SIGNER ?= 9ME8T34MPV

PKG_CONFIG_PATH = $(BUILDPREFIX)/lib/pkgconfig
export PKG_CONFIG_PATH

default:
	$(MAKE) clean
	$(MAKE) dmg

clean:
	git submodule foreach git clean -dfx
	git submodule foreach git reset --hard
	rm -rf target build *.pkg *.dmg

target:
	# Build libusb
	(cd libusb \
	&& ./autogen.sh \
	&& ./configure --prefix=$(BUILDPREFIX) --disable-dependency-tracking --enable-static --disable-shared \
	&& make \
	&& make install \
	)
	# Build CCID
	(cd CCID \
	&& ./bootstrap \
	&& ./MacOSX/configure \
	&& make \
	&& make install DESTDIR=$(TARGET) \
	)

srcdist:
	make -C CCID dist-gzip
	mv CCID/ccid-*.tar.gz $(CCIDVER).tar.gz

ifd-ccid.pkg: target
	pkgbuild --root $(TARGET) --scripts scripts --identifier org.openkms.mac.ccid --version $(CCIDVER) --install-location / --ownership recommended $@

signed: ifd-ccid.pkg
	productbuild --distribution Distribution.xml --package-path . --resources resources --sign "$(SIGNER)" ccid-installer.pkg

ccid-installer.pkg: ifd-ccid.pkg
	productbuild --distribution Distribution.xml --package-path . --resources resources $@

pkg: ccid-installer.pkg

uninstall.pkg:
	pkgbuild --nopayload --identifier org.openkms.mac.ccid.uninstall --scripts uninstaller-scripts $@

ccid-installer.dmg: ccid-installer.pkg uninstall.pkg
	hdiutil create -ov -srcfolder uninstall.pkg -srcfolder ccid-installer.pkg -volname "CCID installer ($(CCIDVER))" $@

dmg: ccid-installer.dmg

dmgsign: ccid-installer.dmg
	codesign -s "$(SIGNER)" ccid-installer.dmg

dist:
	$(MAKE) clean
	$(MAKE) signed
	$(MAKE) dmg
	$(MAKE) dmgsign
	cp ccid-installer.dmg ccid-installer-signed.dmg
