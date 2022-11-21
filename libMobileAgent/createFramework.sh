#!/bin/bash

set -e

if [ "$#" -eq 0 ];then
  underline=`tput smul`
  nounderline=`tput rmul`
  bold=`tput bold`
  normal=`tput sgr0`
  echo -e "Use to generate a .framework file from a .a file."
  echo -e "usage: ${bold}$0${normal} ${underline}library_file${nounderline} ${underline}output_name${nounderline} ${underline}headers_folder"
  echo -e "\t${underline}library_file${nounderline}: the library path. eg. libMobileAgent.a"
  echo -e "\t${underline}output_name${nounderline}: the name of the new .framework file. eg. 'NewRelicAgent' don't include '.framework'"
  echo -e "\t${underline}headers_folder${nounderline}: the path to the public header files. It will copy all header files in this path."
  exit 0
fi


library_file=$1
output_name=$2
platform=$3
headers_dir=$4
root_dir="build/$platform/$output_name"

mkdir -p "$root_dir.framework/Versions/A/Headers"
mkdir -p "$root_dir.framework/Versions/A/Resources"
cp $library_file "${root_dir}.framework/Versions/A/${output_name}"
cp -R "$headers_dir/" "${root_dir}.framework/Versions/A/Headers"
cd "${root_dir}.framework/Versions"
ln -fsh A Current
cd ..

ln -fsh "Versions/Current/${output_name}" "${output_name}"
ln -fsh Versions/Current/Headers/ Headers
ln -fsh Versions/Current/Resources/ Resources

#mv "$root_dir.framework" "build/$platform"
