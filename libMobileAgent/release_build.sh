#!/bin/bash

if [ -a build ]; then
  rm -rf build
fi


./build.sh $1 $2
