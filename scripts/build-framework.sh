#!/bin/bash

source settings.env

./build-libs.sh

LINK_LIBS="-lgetdns -lldns -lidn -lunbound"

# build the framework
for ARCH in ${ARCHS[@]}
do
    if [ "${ARCH}" == "i386" ];
    then
        PLATFORM="iPhoneSimulator"
        SDK="iphonesimulator"
        EXTRA_FLAGS="-miphoneos-version-min=${IOS_VERS}"
        LIB_LDFLAGS="${LIB_LDFLAGS} -miphoneos-version-min=${IOS_VERS}"
    else
        PLATFORM="iPhoneOS"
        SDK="iphoneos"
        EXTRA_FLAGS="-mthumb-interwork"
    fi

    if [ "${ARCH}" == "arm64" ];
    then
        HOST_PREFIX="arm"
    fi

    LIB_CFLAGS="${LIB_CFLAGS} -I${INSTALL_PREFIX}/${ARCH}/include"
    LIB_LDFLAGS="${LIB_LDFLAGS} -L${INSTALL_PREFIX}/${ARCH}/lib ${LINK_LIBS}"

    DEVROOT="${XCODE_DEV}/Platforms/${PLATFORM}.platform/Developer"
    SDKROOT="${DEVROOT}/SDKs/${PLATFORM}${IOS_VERS}.sdk"

    export EXTRA_CFLAGS="-fobjc-arc -arch ${ARCH} -pipe -Os -gdwarf-2 -isysroot ${SDKROOT} ${EXTRA_FLAGS} ${LIB_CFLAGS}"
    export EXTRA_LDFLAGS="-arch ${ARCH} -isysroot ${SDKROOT} ${LIB_LDFLAGS}"
    export CXXFLAGS="${CFLAGS}"
    export CC=$(xcrun -sdk ${SDK} -find gcc)
    export LD=$(xcrun -sdk ${SDK} -find ld)
    export CXX=$(xcrun -sdk ${SDK} -find g++)
    unset AR
    unset AS
    export NM=$(xcrun -sdk ${SDK} -find nm)
    export RANLIB=$(xcrun -sdk ${SDK} -find ranlib)

    cd ${WRAPPER_SRC}
    make

done
