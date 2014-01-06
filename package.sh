#!/bin/bash
set -xe

# clean sources
test x"$1" == x"clean" && rm -rf trunk libusbx

# clean previous bits and pieces
rm -rf target build *.pkg *.dmg

# fetch sources and/or clean existing ones
CCID_REV=6811
LIBUSBX_REV=8b46e1c

test -e trunk || svn checkout -r $CCID_REV svn://anonscm.debian.org/pcsclite/trunk
svn revert -R trunk
svn up -r $CCID_REV trunk
test -e libusbx || git clone https://github.com/libusbx/libusbx.git
(cd libusbx && git reset --hard $LIBUSBX_REV && git clean -dfx)

# set common compiler flags
export CFLAGS="-mmacosx-version-min=10.8 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk -arch i386 -arch x86_64"

TARGET=$(PWD)/target
BUILDPREFIX=$(PWD)/build

# build libusbx
(cd libusbx
./autogen.sh
./configure --prefix=$BUILDPREFIX --disable-dependency-tracking --enable-static --disable-shared \
&& make \
&& make install
)

# build ccid
export PKG_CONFIG_PATH=$BUILDPREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
export BUNDLE_ID=openkms

(cd trunk
# apply patches
for f in ../ccid-patches/*.patch; do echo $(basename $f); patch -p0 < $f; done
cd Drivers/ccid
./bootstrap
./MacOSX/configure
make
make install DESTDIR=$TARGET
)
# wrap up the root
pkgbuild --root $TARGET --scripts scripts --identifier org.openkms.mac.ccid --version 1.4.14 --install-location / --ownership recommended ifd-ccid-openkms.pkg

# create the installer

# productbuild --sign "my-test-installer" --distribution macosx/Distribution.xml --package-path . --resources macosx/resources pluss-id-installer.pkg
productbuild --distribution Distribution.xml --package-path . --resources resources ccid-openkms-installer.pkg

# create uninstaller
pkgbuild --nopayload --identifier org.openkms.mac.ccid.uninstall --scripts uninstaller-scripts uninstall.pkg

# wrap into DMG
hdiutil create -srcfolder uninstall.pkg -srcfolder ccid-openkms-installer.pkg -volname "CCID free software driver installer" ccid-openkms-installer.dmg

# success