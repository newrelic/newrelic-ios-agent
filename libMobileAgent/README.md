libMobileAgent
=======================

A C++ framework used by the iOS agent.

---

**NOTICE**: this project uses HubFlow, a GitHub tool that implements [GitFlow](https://datasift.github.io/gitflow/IntroducingGitFlow.html)  Please make sure you have it set up
before committing to this project. More details can be found
[here](https://github.com/datasift/gitflow).

---

Dependencies
------------

We have one required dependency and 3 optional dependency. The optional dependencies are required to do a complete build of the specified module.
This project has the following dependencies:
- Bison v3.0.4 (optional, JSON++)
- Flex v2.6.x (optional, JSON++)
- Flatbuffers 1.7.1 (optional, HEX)
- [GMock](https://github.com/google/googletest/tree/master/googlemock)

* OSX has Bison v2.3, but JSON++ requires v3.0.4. This can be
downloaded with brew, & update your $PATH env var.
* OSX has Flex v2.5, but JSON++ requires the v2.6.x (c++14 will fail on the code the old flex generates). run `brew install flex` to install. Update your $PATH env var.
* Define a environment variable `GMOCK_DIR` that points to the googlemock 
directory in the cloned googletest repo

#### JSON++ full build
To do a full build of JSON++ (it will generate files: `json.tab.cc`, `json.tab.hh`, and `lex.yy.cc`)
- remove the above files in `ext/JSON`.
- execute cmake with flag -DBUILD_JSON=TRUE
- requires bison v3.0.4 & flex v2.6.x

#### Flatbuffers schema full build

A flatbuffers full build will regenerate all flatebuffer files defined by the schema in `ext/mobile_flatbuffer_schemas`.

Files are (in `src/Hex/include/Hex/generated`):
 - `agent-data-bundle_generated.h`
 - `agent-data_generated.h`
 - `hex_generated.h`
 - `ios_generated.h`
 - `session-attributes_generated.h`


To rebuild files:
- remove existing files
- execute cmake with flag -DBUILD_FLATBUFFER_SCHEMA=TRUE
- requires flatc v1.7.1 (recommend install from flatbuffers source)



Clion setup
-----------

* Clion requires additional cmake flags to build due to environmental
constraints. These flags can be adding using Clion > Preferences > Build, Execution, Deployment > Cmake

  * `-DENVIRONEMENT=CLION`  - this flag may not be necessary anymore, but in past versions of Clion it was necessary to distinguish how the `json` project was loaded into clion.
  * `-DBUILD_TYPE=Test` - this flag enables the build of the test binary & debug compiler flags, distinguished from `debug` which only enables the debug flag.


* Additionally, install the terminal plugin so CLion can access your env-vars such as $PATH.

Building
--------

This project uses [cmake](https://cmake.org/). A shell-script `build.sh` has 
been created for convenience. It is always recommended to run cmake in a build
directory to prevent cmake files from being created across the project folders.

~~~~
$ mkdir build && cd build
$ cmake .. -DBUILD_TYPE=Test
$ make 
~~~~

Running Tests
-------------

Once built, run tests from the `build` directory with 

`ctest`

For a more verbose test run execute `./libMobileAgentTest`

Adding additional tests and src files will need to be manually added to the
cmake system.  For additional src files, see src/Analytics/CMakeLists.txt
for examples. For additional tests see the root CMakeLists.txt file.

Building a release for iOS
------------------------------

Run ./release\_build.sh
This will produce a framework file for each c++ module into the build/
folder and includes x86\_64, i386, armv7, and arm64 architectures.

Below is legacy for manual building
-----------------------------------

These steps are a place holder at this point. By the time of release
these steps will be integrated into cmake.

Create OBJECT files for an iOS target:
`llvm-g++ -c -stdlib=libc++  -arch #ARCH#  -mios-version-min=#VERS# -isysroot #IOS_PLATFORM_PATH# *.cpp *.hpp`

Platform paths such as : /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS8.1.sdk
                         /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator8.1.sdk/


How to link
-----------

`ld -r  -ios_version_min #VERS# *.o -arch #ARCH# -o #FRAMEWORK#.a`

How to lipo
----------

Link all the architecture dependent .a files into one:

`lipo -create #framework#-arch1.a #framework#-arch2.a [...] #framework#-archn.a -output #framework#-universal.a`

