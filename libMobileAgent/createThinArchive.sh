#!/bin/bash 


set -x
if [ "$#" -eq 0 ];then
  underline=`tput smul`
  nounderline=`tput rmul`
  bold=`tput bold`
  normal=`tput sgr0`
  echo -e "Use to build the libMobileAgent."
  echo -e "usage: ${bold}$0${normal} ${underline}PLATFORM${nounderline} [${underline}ARCHS${nounderline}]"
  echo -e "\t${underline}PLATFORM${nounderline}: which platform to build. e.g.: 'iphoneos', 'appletvos'"
  echo -e "\t${underline}ARCHS${nounderline}:[optional] which cpu architectures to use. e.g.: 'armv7', 'x86_64', etc."
  echo -e "\t${underline}BUILDTYPE${nounderline}:[optional] controls compiler flags for debugging/release builds. e.g.: 'Debug', 'Test', or 'Release' (default)"
  exit 0
fi


root_dir=`pwd`

PLATFORM=${1}
BUILD_TYPE=${2}
ARCHS=""

CLANG_PATH=`xcrun -find clang`
CLANGXX_PATH=`xcrun -find clang++`

build_dir=${root_dir}/build
CMAKE_SYSTEM_NAME=iOS
if [ -z ${PLATFORM} ]; then
  echo "$PLATFORM not set. using platform 'iphoneos'"
  PLATFORM='iphoneos'
fi

if [ "${PLATFORM}" = "appletvos" ]; then
    CMAKE_SYSTEM_NAME=tvos
    ARCHS="arm64"
fi

if [ "${PLATFORM}" = "appletvsimulator" ]; then
    CMAKE_SYSTEM_NAME=tvos
    ARCHS="arm64 x86_64"
fi

if [ "${PLATFORM}" = "macosx" ]; then
	CMAKE_SYSTEM_NAME="Darwin"
	PLATFORM=macosx
	ARCHS="arm64 x86_64"
fi

  platform_dir=${build_dir}/${PLATFORM}

  mkdir -p ${platform_dir}

if [ $PLATFORM = 'iphoneos' ] && [ -z "$ARCHS" ]; then
  ARCHS="arm64 arm64e armv7 armv7s"
  echo "ARCHS not defined using: '${ARCHS}'"
elif [ -z "$ARCHS" ]; then
  ARCHS="arm64 x86_64"
  echo "ARCHS not defined using: '${ARCHS}'"
fi

if [ "${PLATFORM}" = "iphonesimulator" ]; then
	ARCHS="arm64 x86_64 i386"
fi

if [ -z "$BUILD_TYPE" ]; then
    BUILD_TYPE="Release"
fi

echo for arch_type in $ARCHS
for arch_type in $ARCHS; do
  arch_dir=${platform_dir}/${arch_type}
  cd ${platform_dir}
  mkdir -p ${arch_dir}
  cmake ${root_dir} -G Xcode -DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME} -DARCH_TYPE=${arch_type} -DBUILD_TYPE=${BUILD_TYPE} -DPLATFORM=${PLATFORM} -DCMAKE_CXX_COMPILER="${CLANGXX_PATH}" -DCMAKE_C_COMPILER="${CLANG_PATH}" -B${arch_dir}  > build.out 2>&1

  # if [ $? != 0 ]; then
  #   cat build.out
  #   exit 1
  # fi
  # rm build.out

  # cd ${arch_dir}
  # make VERBOSE=1 > build.out 2>&1
  # if [ $? != 0 ]; then
  #   cat build.out
  #   exit 1
  # fi
  # rm build.out

done

