#!/bin/bash 

set -e

if [ "$#" -eq 0 ];then
  underline=`tput smul`
  nounderline=`tput rmul`
  bold=`tput bold`
  normal=`tput sgr0`
  echo -e "Use to generate a fat .a file from multiple thin .a files."
  echo -e "usage: ${bold}$0${normal} ${underline}library_file${nounderline} ${underline}output_name${nounderline}"
  echo -e "\t${underline}library_file${nounderline}: the thin library name. eg. libAnalytics.a"
  echo -e "\t${underline}output_name${nounderline}: the name of the new fat .a file. eg. 'libAnalytics' don't include '.a'"
  exit 0
fi

platform=$1
thin_library_file=$2
output_fat_library_file=$3
platform_dir="build"
cd ${platform_dir}

cur_dir=`pwd`
#generate simulator fat lib
echo "cur dir"
echo ${cur_dir}
echo "Creating $output_fat_library_file.a for $platform"
/usr/bin/lipo -create $platform/*/out/$thin_library_file \
	      -output $platform/$output_fat_library_file.a
