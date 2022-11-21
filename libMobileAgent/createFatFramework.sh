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

platform=${1}
root_dir=`pwd`
build_dir=${root_dir}/build
  platform_dir=${build_dir}/${platform}

  mkdir -p ${platform_dir}

#platform_dir=${build_dir}/${platform}
#platform_dir=${root_dir}

${root_dir}/createFramework.sh ${platform_dir}/libAnalyticsFat.a Analytics ${platform} ${root_dir}/src/Analytics/include/Analytics

mkdir -p json_headers
cp ${root_dir}/ext/JSON/json.hh json_headers/
cp ${root_dir}/ext/JSON/json.tab.hh json_headers/
cp ${root_dir}/ext/JSON/json_st.hh json_headers/
cp ${root_dir}/ext/JSON/IJsonable.hpp json_headers/
${root_dir}/createFramework.sh ${platform_dir}/libjsonFat.a json ${platform} json_headers

${root_dir}/createFramework.sh ${platform_dir}/libUtilitiesFat.a Utilities ${platform} ${root_dir}/src/Utilities/include/Utilities

${root_dir}/createFramework.sh ${platform_dir}/libHexFat.a Hex ${platform} ${root_dir}/src/Hex/include/Hex

${root_dir}/createFramework.sh ${platform_dir}/libConnectivityFat.a Connectivity ${platform} ${root_dir}/src/Connectivity/include/Connectivity
