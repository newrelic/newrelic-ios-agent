# important note: build/macosx/NewRelic.framework has symbolic links so be sure to
# zip with -y flag whenever compressing that .framework

#!/usr/bin/env bash -x

function getiOSBCFiles() {
	local IPHONE_BCSYMBOLMAP_COMMANDS=""
	local IPHONE_BCSYMBOLMAP_PATHS="build/iphoneos/iOS.xcarchive/BCSymbolMaps/*"

	for path in $IPHONE_BCSYMBOLMAP_PATHS; do
		fullPath=$(pwd)/$path
		IPHONE_BCSYMBOLMAP_COMMANDS="${IPHONE_BCSYMBOLMAP_COMMANDS} -debug-symbols $fullPath "
	done

	echo $IPHONE_BCSYMBOLMAP_COMMANDS
}

function gettvOSBCFiles() {
	local TVOS_BCSYMBOLMAP_COMMANDS=""
	local TVOS_BCSYMBOLMAP_PATHS="build/appletvos/tvOS.xcarchive/BCSymbolMaps/*"

	for path in $TVOS_BCSYMBOLMAP_PATHS; do
		fullPath=$(pwd)/$path
		TVOS_BCSYMBOLMAP_COMMANDS="${TVOS_BCSYMBOLMAP_COMMANDS} -debug-symbols $fullPath"
	done

	echo $TVOS_BCSYMBOLMAP_COMMANDS
}

IPHONE_BCSYMBOLMAP_COMMANDS=$(getiOSBCFiles)
TVOS_BCSYMBOLMAP_COMMANDS=$(gettvOSBCFiles)
xcodebuild -create-xcframework \
	-framework build/iphoneos/NewRelic.framework \
		-debug-symbols $(pwd)/build/iphoneos/iOS.xcarchive/dSYMs/NewRelic.framework.dSYM \
		$IPHONE_BCSYMBOLMAP_COMMANDS \
	-framework build/iphonesimulator/NewRelic.framework \
	-framework build/appletvsimulator/NewRelic.framework \
	-framework build/appletvos/NewRelic.framework \
		-debug-symbols $(pwd)/build/appletvos/tvOS.xcarchive/dSYMs/NewRelic.framework.dSYM \
	-framework build/macosx/NewRelic.framework 	\
		-debug-symbols $(pwd)/build/macosx/macosx.xcarchive/dSYMs/NewRelic.framework.dSYM \
	-output build/NewRelic.xcframework


cp -r dsym-upload-tools/ build/NewRelic.xcframework/Resources/