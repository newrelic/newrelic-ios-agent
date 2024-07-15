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
rm -rf ${BUILD_PATH}/watchos

# build device version
/usr/bin/xcodebuild -configuration Release -scheme Agent-watchOS -sdk watchos archive BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -archivePath watchOS.xcarchive > build.out 2>&1

if [ $? -ne 0 ]; then
  echo "Xcode build failed."
  cat build.out
  exit 1
fi

# insert xcode build environmental vars
source ${BUILD_PATH}/archive_paths.sh


# Copying EXECUTABLE_NAME to build_path/platform folder
  mkdir -p ${BUILD_PATH}/watchos
  echo "copying built ${CODESIGNING_FOLDER_PATH} to build/watchos"
  cp -p -R ${CODESIGNING_FOLDER_PATH} ${BUILD_PATH}/watchos/${EXECUTABLE_NAME}.framework

  echo "copying build watchOS.xcarchive to build/watchos"
  cp -p -R "watchOS.xcarchive" "${BUILD_PATH}/watchos/watchOS.xcarchive"


#build simulator version
/usr/bin/xcodebuild -configuration Release -scheme Agent-watchOS -sdk watchsimulator build > build.out 2>&1

if [ $? -ne 0 ]; then
  echo "Xcode build failed."
  cat build.out
  exit 1
fi

# insert xcode build environmental vars
source ${BUILD_PATH}/archive_paths.sh

# copy simulator build to local build folder
mkdir -p ${BUILD_PATH}/watchsimulator
echo "Copying ${EXECUTABLE_NAME} to build/watchsimulator"
cp -p -R ${CODESIGNING_FOLDER_PATH}/ ${BUILD_PATH}/watchsimulator/${EXECUTABLE_NAME}.framework/




