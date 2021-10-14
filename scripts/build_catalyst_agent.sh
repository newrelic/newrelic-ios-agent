#!/usr/bin/env bash -x

###########################
#create the script_path var
###########################
pushd `dirname $0` > /dev/null
SCRIPT_PATH=`pwd`
BUILD_PATH="${SCRIPT_PATH}/../build"
popd > /dev/null

echo "SCRIPT_PATH: ${SCRIPT_PATH}"
echo "BUILD_PATH: ${BUILD_PATH}"


# set version from agvtool

VERSION=`agvtool vers -terse`

# move to root dir
pushd ${SCRIPT_PATH}/..

# cleaning up build directory
rm -rf ${BUILD_PATH}/macosx

# build device version
/usr/bin/xcodebuild -configuration Release -scheme Agent-iOS -sdk macosx archive BUILD_LIBRARIES_FOR_DISTRIBUTION=YES SUPPORTS_MACCATALYST=YES -archivePath Catalyst.xcarchive > build.out 2>&1

if [[ $? != 0 ]]; then
  echo "Xcode build failed."
  cat build.out
  exit 1
fi

# insert xcode build environmental vars
source ${BUILD_PATH}/archive_paths.sh


#pushd "${BUILT_PRODUCTS_DIR}"
#${PROJECT_DIR}/scripts/fixFrameworkSymlinks.sh ${PRODUCT_NAME}
#popd

# Copying EXECUTABLE_NAME to build_path/platform folder
  mkdir -p ${BUILD_PATH}/macosx
  echo "copying built ${CODESIGNING_FOLDER_PATH} to build/macosx"
  cp -p -R ${CODESIGNING_FOLDER_PATH} ${BUILD_PATH}/macosx/${EXECUTABLE_NAME}.framework

# change the anatomy of the framework to match Apple specs for OSX. Do not use for iOS/tvOS frameworks. 
# https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPFrameworks/Concepts/FrameworkAnatomy.html
echo "changing framework anatomy for Mac Catalyst ${EXECUTABLE_NAME}.framework at ${BUILD_PATH}/macosx/"
pushd "${BUILD_PATH}/macosx/"
${PROJECT_DIR}/scripts/fixFrameworkSymlinks.sh ${EXECUTABLE_NAME}
popd


  echo "copying build Catalyst.xcarchive to build/macosx"
  cp -p -R "Catalyst.xcarchive" "${BUILD_PATH}/macosx/Catalyst.xcarchive"


