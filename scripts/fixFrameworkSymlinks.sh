#!/bin/bash

if [ "$#" -eq 0 ];then
  underline=`tput smul`
  nounderline=`tput rmul`
  bold=`tput bold`
  normal=`tput sgr0`
  echo -e "Use to fix symbolic links in a .framework file."
  echo -e "usage: ${bold}$0${normal} ${underline}framework.framework${nounderline}"
  echo -e "\t${underline}framework${nounderline}: the framework name. eg. NewRelicAgent"
  exit 0
fi
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

echo mkdir -p "$1.framework/Versions/A/Headers"
mkdir -p "$1.framework/Versions/A/Headers"

echo mkdir -p "$1.framework/Versions/A/Resources"
mkdir -p "$1.framework/Versions/A/Resources"

echo mkdir -p "$1.framework/Versions/A/Modules"
mkdir -p "$1.framework/Versions/A/Modules"

if [ ! -h "${1}.framework/${1}" ]; then
  echo mv "${1}.framework/${1}" "${1}.framework/Versions/A/${1}"
  mv "${1}.framework/${1}" "${1}.framework/Versions/A/${1}"
fi

if [ ! -h "${1}.framework/Headers" ]; then
  echo mv "${1}.framework/Headers" "${1}.framework/Versions/A"
  mv "${1}.framework/Headers" "${1}.framework/Versions/A"
fi

if [ ! -h "${1}.framework/Resources" ]; then
  echo mv "${1}.framework/Resources" "${1}.framework/Versions/A"
  mv "${1}.framework/Resources" "${1}.framework/Versions/A"
fi

if [ ! -h "${1}.framework/Modules" ]; then
  echo mv "${1}.framework/Modules" "${1}.framework/Versions/A"
  mv "${1}.framework/Modules" "${1}.framework/Versions/A"
fi

if [ ! -h "${1}.framework/Info.plist" ]; then
  echo mv "${1}.framework/Info.plist" "${1}.framework/Versions/A/Resources"
  mv "${1}.framework/Info.plist" "${1}.framework/Versions/A/Resources"
fi

echo cd "${1}.framework/Versions"
cd "${1}.framework/Versions"

echo ln -fsh A Current
 ln -fsh A Current

cd ..

echo ln -fsh "Versions/Current/${1}" "${1}"
ln -fsh "Versions/Current/${1}" "${1}"

echo ln -fsh Versions/Current/Headers/ Headers
ln -fsh Versions/Current/Headers/ Headers

echo ln -fsh Versions/Current/Resources/ Resources
ln -fsh Versions/Current/Resources/ Resources

echo ln -fsh Versions/Current/Modules/ Modules
ln -fsh Versions/Current/Modules/ Modules
