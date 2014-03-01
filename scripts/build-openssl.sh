#!/bin/bash
#
#  Copyright (c) 2013 Claudiu-Vlad Ursache <claudiu@cvursache.com>
#  MIT License (see LICENSE.md file)
#
#  Based on work by Felix Schulze:
#
#  Automatic build script for libssl and libcrypto
#  for iPhoneOS and iPhoneSimulator
#
#  Created by Felix Schulze on 16.12.10.
#  Copyright 2010 Felix Schulze. All rights reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

# Modified version of
# https://raw.github.com/Raphaelios/raphaelios-scripts/master/openssl/build-openssl.sh

set -u

source settings.env

# Setup architectures, library name and other vars + cleanup from previous runs
LIB_NAME=${OPENSSL_DIR}

# Unarchive library, then configure and make for specified architectures

configure_make()
{
   ARCH=$1; GCC=$2; SDK_PATH=$3; LD=$4; FLAGS=$5
   # clean up any old ones
   rm -rf "${SOURCES}/${LIB_NAME}"
   tar xfz "${DOWNLOADS_DIR}/${LIB_NAME}.tar.gz" -C "${SOURCES}"
   rm -rf "${SOURCES}/${LIB_NAME}-${ARCH}.log"
   LOG_FILE="${SOURCES}/${LIB_NAME}-${ARCH}.log"
   cd ${SOURCES}/${LIB_NAME}
   echo "Building ${LIB_NAME} for ${ARCH}"
   ./Configure BSD-generic32 --openssldir="${INSTALL_PREFIX}/${ARCH}" &> "${LOG_FILE}"

   make LD="${LD}" CC="${GCC} -arch ${ARCH}" LDFLAG="${FLAGS}" CFLAG="-isysroot ${SDK_PATH} ${FLAGS}" &> "${LOG_FILE}";
   make install &> "${LOG_FILE}";
}
for ARCH in ${ARCHS[@]}
do
   if [ -e ${INSTALL_PREFIX}/${ARCH}/lib/${OPENSSL_CHECK_LIB} ]; then
        echo "Already built ${LIB_NAME} for ${ARCH}"
        continue
   fi
   if [ "${ARCH}" == "i386" ];
   then
    SDK="iphonesimulator"
    FLAGS="-miphoneos-version-min=${IOS_VERS}"
   else
    SDK="iphoneos"
    FLAGS=""
   fi
   SDK_PATH=$(xcrun -sdk ${SDK} --show-sdk-path)
   GCC=$(xcrun -sdk ${SDK} -find gcc)
   LD=$(xcrun -sdk ${SDK} -find ld)
   configure_make "${ARCH}" "${GCC}" "${SDK_PATH}" "${LD}" "${FLAGS}"
done

# # Combine libraries for different architectures into one
# # Use .a files from the temp directory by providing relative paths
# create_lib()
# {
#    LIB_SRC=$1; LIB_DST=$2;
#    LIB_PATHS=( "${ARCHS[@]/#/${TEMP_LIB_PATH}-}" )
#    LIB_PATHS=( "${LIB_PATHS[@]/%//${LIB_SRC}}" )
#    lipo ${LIB_PATHS[@]} -create -output "${LIB_DST}"
# }
# mkdir "${LIB_DEST_DIR}";
# create_lib "lib/libcrypto.a" "${LIB_DEST_DIR}/libcrypto.a"
# create_lib "lib/libssl.a" "${LIB_DEST_DIR}/libssl.a"

# # Copy header files + final cleanups
# mkdir -p "${HEADER_DEST_DIR}"
# cp -R "${TEMP_LIB_PATH}-${ARCHS[0]}/include" "${HEADER_DEST_DIR}"
# rm -rf "${TEMP_LIB_PATH}-*" "{LIB_NAME}"
