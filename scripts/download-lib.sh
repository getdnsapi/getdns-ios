#!/bin/bash

LIB_DIR=$1
LIB_URL=$2

source settings.env

if [ ! -e ${DOWNLOADS_DIR}/${LIB_DIR}.tar.gz ]; then
    echo "Downloading ${LIB_DIR}"
    curl -L -o ${DOWNLOADS_DIR}/${LIB_DIR}.tar.gz ${LIB_URL}
fi
