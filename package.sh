#!/bin/bash
set -xe

# clean sources
git submodule foreach git clean -dfx
git submodule foreach git reset --hard

# clean previous bits and pieces
rm -rf target build *.pkg *.dmg

# set common compiler flags
export CFLAGS="-mmacosx-version-min=10.11 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk -arch x86_64"

TARGET=$(PWD)/target
BUILDPREFIX=$(PWD)/build

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

# wrap up the root
pkgbuild --root $TARGET --scripts scripts --identifier org.openkms.mac.ccid --version 1.4.18 --install-location / --ownership recommended ifd-ccid-openkms.pkg

# create the installer

# productbuild --sign "my-test-installer" --distribution macosx/Distribution.xml --package-path . --resources macosx/resources pluss-id-installer.pkg
productbuild --distribution Distribution.xml --package-path . --resources resources ccid-openkms-installer.pkg

# create uninstaller
pkgbuild --nopayload --identifier org.openkms.mac.ccid.uninstall --scripts uninstaller-scripts uninstall.pkg

# wrap into DMG
hdiutil create -srcfolder uninstall.pkg -srcfolder ccid-openkms-installer.pkg -volname "CCID free software driver installer" ccid-openkms-installer.dmg

# success
