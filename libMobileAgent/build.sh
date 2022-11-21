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

echo "** creating thin archives: a single platform/arch per .a file (e.g. iphoneos/arm64)"
${root_dir}/createThinArchive.sh ${PLATFORM} ${BUILD_TYPE}

echo "** creating fat archives: a single .a file for each platform (e.g. iphoneos)"
${root_dir}/createFatPlatform.sh ${PLATFORM} libAnalytics.a libAnalyticsFat
${root_dir}/createFatPlatform.sh ${PLATFORM} libConnectivity.a libConnectivityFat
${root_dir}/createFatPlatform.sh ${PLATFORM} libjson.a libjsonFat
${root_dir}/createFatPlatform.sh ${PLATFORM} libUtilities.a libUtilitiesFat
${root_dir}/createFatPlatform.sh ${PLATFORM} libHex.a libHexFat

echo "** creating platform frameworks: a single framework for each platform (e.g. iphoneos)"
${root_dir}/createFatFramework.sh ${PLATFORM}
