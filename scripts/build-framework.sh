#!/bin/bash

source settings.env

./build-libs.sh

# build the ios wrapper
for ARCH in ${ARCHS[@]}
do
    if [ "${ARCH}" == "i386" ];
    then
        SDK="iphonesimulator"
    else
        SDK="iphoneos"
    fi
    export OTHER_CFLAGS="-I${INSTALL_PREFIX}/${ARCH}/include"
    OUT_DIR="${INSTALL_PREFIX}/${ARCH}/lib"
    cd ${WRAPPER_SRC}/getdns-wrap
    xcodebuild -arch ${ARCH} -sdk ${SDK}${IOS_VERS} CONFIGURATION_BUILD_DIR=${OUT_DIR}
    if [ ! -e ${INSTALL_PREFIX}/${ARCH}/lib/libgetdns-wrap.a ]; then
        echo "Failed to build wrapper for ${ARCH}"
        exit 1
    fi
done

# build a giant static lib for each arch
LIPO_ARGS=""
for ARCH in ${ARCHS[@]}
do
    libtool -static -o ${INSTALL_PREFIX}/libgetdns-ios.${ARCH}.a ${INSTALL_PREFIX}/${ARCH}/lib/*.a
    LIPO_ARGS="${LIPO_ARGS} ${INSTALL_PREFIX}/libgetdns-ios.${ARCH}.a"
done

# now lipo them all together!
lipo ${LIPO_ARGS} -output ${INSTALL_PREFIX}/libgetdns-ios.a -create

echo "Building the framework... finally"
tar -xf ${DIR}/Canonical.framework.tar -C ${INSTALL_PREFIX}
mv "${INSTALL_PREFIX}/Canonical.framework" "${INSTALL_PREFIX}/${FRAMEWORK_NAME}.framework"

mv "${INSTALL_PREFIX}/libgetdns-ios.a"  "${INSTALL_PREFIX}/${FRAMEWORK_NAME}.framework/Versions/A/getdns"
# why does this work?
ln -s "Versions/A/getdns" "${INSTALL_PREFIX}/${FRAMEWORK_NAME}.framework/"
cp -r "${INSTALL_PREFIX}/i386/include/getdns/*.h" "${INSTALL_PREFIX}/${FRAMEWORK_NAME}.framework/Versions/A/Headers/"

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${FRAMEWORK_VERSION}" "${INSTALL_PREFIX}/${FRAMEWORK_NAME}.framework/Versions/A/Resources/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${FRAMEWORK_IDENTIFIER}" "${INSTALL_PREFIX}/${FRAMEWORK_NAME}.framework/Versions/A/Resources/Info.plist"

