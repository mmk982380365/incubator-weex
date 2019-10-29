#!/bin/bash
set -e

CONFIGURATION="Release"
BDL_NAME="WeexSDK"

build_bundle() {
    if [ ! -n "$1" ] ;then
    echo "you have not input a word!"
    else
        BASE_PATH=$1
        xcodebuild build -project ${BASE_PATH}/${BDL_NAME}.xcodeproj -configuration ${CONFIGURATION} -sdk iphoneos
        WORK_DIR=${BASE_PATH}/"build"
        INSTALL_DIR=${BASE_PATH}/"Products/"
        BDL_BUILD_PATH=${WORK_DIR}/${CONFIGURATION}-iphoneos/${BDL_NAME}.bundle
        rm -rf ${INSTALL_DIR}
        mkdir -p ${INSTALL_DIR}
        mv ${BDL_BUILD_PATH} ${INSTALL_DIR}/${BDL_NAME}.bundle
        rm -rf ${WORK_DIR}
    fi
}







# 

# BDL_BUILD_PATH=${WRK_DIR}/${CONFIGURATION}-iphoneos/${BDL_NAME}.bundle

# xcodebuild build -configuration ${CONFIGURATION} -sdk iphoneos

# rm -rf ${INSTALL_DIR}

# mkdir -p ${INSTALL_DIR}

# mv ${BDL_BUILD_PATH} ${INSTALL_DIR}/${BDL_NAME}.bundle

# echo Build Bundle Success!
