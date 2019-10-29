#!/bin/bash

SDK_PATH='./ios/sdk/Products/WeexSDK.framework'
BUNDLE_PATH='./ios/bundle/Products/WeexSDK.bundle'

OUT_PATH='./output/'

BUNDLE_PROJECT_PATH='./ios/bundle/'

xcodebuild build -project ./ios/sdk/WeexSDK.xcodeproj -target WeexSDK_MTL -UseModernBuildSystem=NO

. ./ios/bundle/build.sh

build_bundle ${BUNDLE_PROJECT_PATH}


rm -rf ${OUT_PATH}

mkdir -p $OUT_PATH

mv $SDK_PATH $OUT_PATH
mv $BUNDLE_PATH $OUT_PATH

rm ${OUT_PATH}/WeexSDK.framework/*.js
rm ${OUT_PATH}/WeexSDK.framework/*.png

