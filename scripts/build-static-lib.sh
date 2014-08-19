#!/bin/bash

# Thanks to https://github.com/x2on/expat-ios/blob/master/build-expat.sh as a guide
# and https://github.com/hasseily/Makefile-to-iOS-Framework

# Generic build of static libs - does not apply to openssl
# Only for standard ./configure

# first two args are library-version, and url
# other args are appended to configure
# useful vars:
#  - LIB_CFLAGS
#  - LIB_LDFLAGS

set -u

source settings.env

LIB_DIR=$1
ARCH=$2
CHECK_LIB=$3

shift 3

if [ -e ${INSTALL_PREFIX}/${ARCH}/lib/${CHECK_LIB} ]; then
    echo "Already built ${LIB_DIR} for ${ARCH}"
    exit 0
fi

# Clean build for ARCH
rm -rf "${SOURCES}/${LIB_DIR}"
tar -xf ${DOWNLOADS_DIR}/${LIB_DIR}.tar.gz -C ${SOURCES}
cd "${SOURCES}/${LIB_DIR}"

HOST_PREFIX=$ARCH

if [ "${ARCH}" == "i386" ];
then
    PLATFORM="iPhoneSimulator"
    SDK="iphonesimulator"
    EXTRA_FLAGS="-miphoneos-version-min=${IOS_VERS}"
    LIB_LDFLAGS="${LIB_LDFLAGS} -miphoneos-version-min=${IOS_VERS}"
else
    PLATFORM="iPhoneOS"
    SDK="iphoneos"
    #EXTRA_FLAGS="-mthumb-interwork"
    EXTRA_FLAGS=""
fi

if [ "${ARCH}" == "arm64" ];
then
    HOST_PREFIX="arm"
fi

LIB_CFLAGS="${LIB_CFLAGS} -I${INSTALL_PREFIX}/${ARCH}/include"
LIB_LDFLAGS="${LIB_LDFLAGS} -L${INSTALL_PREFIX}/${ARCH}/lib"

DEVROOT="${XCODE_DEV}/Platforms/${PLATFORM}.platform/Developer"
SDKROOT="${DEVROOT}/SDKs/${PLATFORM}${IOS_VERS}.sdk"

echo "Building ${LIB_DIR} for ${PLATFORM} ${ARCH}"

export CFLAGS="-arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${SDKROOT} ${EXTRA_FLAGS} ${LIB_CFLAGS}"
export LDFLAGS="-arch ${ARCH} -isysroot ${SDKROOT} ${LIB_LDFLAGS}"
export CXXFLAGS="${CFLAGS}"
export CC=$(xcrun -sdk ${SDK} -find gcc)
export LD=$(xcrun -sdk ${SDK} -find ld)
export CXX=$(xcrun -sdk ${SDK} -find g++)
unset AR
unset AS
export NM=$(xcrun -sdk ${SDK} -find nm)
export RANLIB=$(xcrun -sdk ${SDK} -find ranlib)

LOG="${SOURCES}/${LIB_DIR}-${ARCH}.log"
./configure \
    --prefix="${INSTALL_PREFIX}/${ARCH}" \
    --host="${HOST_PREFIX}-apple-darwin" \
    "$@" \
    --enable-static \
    --disable-shared > "${LOG}" 2>&1

make install >> "${LOG}" 2>&1
