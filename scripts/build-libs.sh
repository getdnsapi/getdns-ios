#!/bin/bash

source settings.env

# build openssl
./download-lib.sh $OPENSSL_DIR $OPENSSL_URL
./build-openssl.sh

# build libidn
export LIB_CFLAGS=""
export LIB_LDFLAGS="-liconv"
./download-lib.sh $LIBIDN_DIR $LIBIDN_URL
for ARCH in ${ARCHS[@]}
do
    ./build-static-lib.sh $LIBIDN_DIR $ARCH $LIBIDN_CHECK_LIB
done

# build ldns
export LIB_CFLAGS=""
export LIB_LDFLAGS=""
./download-lib.sh $LIBLDNS_DIR $LIBLDNS_URL
for ARCH in ${ARCHS[@]}
do
    ./build-static-lib.sh $LIBLDNS_DIR $ARCH $LIBLDNS_CHECK_LIB --with-ssl="${INSTALL_PREFIX}/${ARCH}"
done

# build expat
export LIB_CFLAGS="-Wno-implicit-function-declaration"
export LIB_LDFLAGS=""
./download-lib.sh $LIBEXPAT_DIR $LIBEXPAT_URL
for ARCH in ${ARCHS[@]}
do
    ./build-static-lib.sh $LIBEXPAT_DIR $ARCH $LIBEXPAT_CHECK_LIB
done

# build unbound
export LIB_CFLAGS=""
export LIB_LDFLAGS=""
./download-lib.sh $LIBUNBOUND_DIR $LIBUNBOUND_URL
for ARCH in ${ARCHS[@]}
do
    ./build-static-lib.sh $LIBUNBOUND_DIR $ARCH $LIBUNBOUND_CHECK_LIB \
       --with-ssl="${INSTALL_PREFIX}/${ARCH}" \
       --with-ldns="${INSTALL_PREFIX}/${ARCH}" \
       --with-expat="${INSTALL_PREFIX}/${ARCH}"
done

# verify
for LIB in ${DEPS_VERIFY_LIBS[@]}
do
    for ARCH in ${ARCHS[@]}
    do
        if [ ! -e ${INSTALL_PREFIX}/${ARCH}/lib/${LIB} ]; then
            echo "Dependency not built. (${LIB} for ${ARCH})  "
            exit 1
        fi
    done
done

echo "Built dependencies successfully"

# build getdns
export LIB_CFLAGS=""
export LIB_LDFLAGS="-lcrypto -lssl -liconv"
./download-lib.sh $GETDNS_DIR $GETDNS_URL
for ARCH in ${ARCHS[@]}
do
    ./build-static-lib.sh $GETDNS_DIR $ARCH $GETDNS_CHECK_LIB \
       --with-libldns="${INSTALL_PREFIX}/${ARCH}" \
       --with-libunbound="${INSTALL_PREFIX}/${ARCH}" \
       --with-libidn="${INSTALL_PREFIX}/${ARCH}"
    if [ ! -e ${INSTALL_PREFIX}/${ARCH}/lib/${GETDNS_CHECK_LIB} ]; then
        echo "getdns not built. (${GETDNS_CHECK_LIB} for ${ARCH})  "
        exit 1
    fi
done

