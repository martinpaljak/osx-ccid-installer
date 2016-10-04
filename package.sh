#!/bin/bash
set -xe

# clean sources
git submodule foreach git clean -dfx
git submodule foreach git reset --hard

# clean previous bits and pieces
rm -rf target build *.pkg *.dmg

# Locate the latest OSX SDK
SDKS_PATH="$(xcode-select -p)/Platforms/MacOSX.platform/Developer/SDKs"
SDK_PATH="${SDK_PATH:-$SDKS_PATH/$(ls -1 ${SDKS_PATH} | sort -n -k2 -t. -r | head -1)}"
export CFLAGS="-mmacosx-version-min=10.11 -isysroot ${SDK_PATH} -arch x86_64"

TARGET="${PWD}/target"
BUILDPREFIX="${PWD}/build"
CCIDVER="$(cd CCID && git describe --always --tags --long)"

# build libusb
(cd libusb
./autogen.sh
./configure --prefix=$BUILDPREFIX --disable-dependency-tracking --enable-static --disable-shared \
&& make \
&& make install
)

# build ccid
export PKG_CONFIG_PATH=$BUILDPREFIX/lib/pkgconfig:$PKG_CONFIG_PATH

(cd CCID
# apply patches
for f in ../ccid-patches/*.patch; do echo $(basename $f); patch --forward -p1 < $f; done
./bootstrap
./MacOSX/configure
make
make install DESTDIR=$TARGET
)

# wrap up (possibly patched) CCID sources
make -C CCID dist-gzip
mv CCID/ccid-*.tar.gz ${CCIDVER}.tar.gz
# wrap up the root
pkgbuild --root $TARGET --scripts scripts --identifier org.openkms.mac.ccid --version ${CCIDVER} --install-location / --ownership recommended ifd-ccid.pkg

# create the installer

# productbuild --sign "my-test-installer" --distribution macosx/Distribution.xml --package-path . --resources macosx/resources pluss-id-installer.pkg
productbuild --distribution Distribution.xml --package-path . --resources resources ccid-installer.pkg

# create uninstaller
pkgbuild --nopayload --identifier org.openkms.mac.ccid.uninstall --scripts uninstaller-scripts uninstall.pkg

# wrap into DMG
hdiutil create -srcfolder uninstall.pkg -srcfolder ccid-installer.pkg -volname "CCID installer (${CCIDVER})" ccid-installer.dmg

# success
