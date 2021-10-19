# important note: build/macosx/NewRelic.framework has symbolic links so be sure to
# zip with -y flag whenever compressing that .framework

#!/usr/bin/env bash -x

function getiOSBCFiles() {
	IPHONE_BCSYMBOLMAP_COMMANDS=""
	IPHONE_BCSYMBOLMAP_PATHS="build/iphoneos/iOS.xcarchive/BCSymbolMaps/*"

	for path in $IPHONE_BSCYMBOLMAP_PATHS; do
		fullPath=$(pwd)/$path
		IPHONE_BCSYMBOLMAP_COMMANDS="${IPHONE_BCSYMBOLMAP_COMMANDS} -debug-symbols $fullPath "
	done

	echo $IPHONE_BCSYMBOLMAP_COMMANDS
}

function gettvOSBCFiles() {
	TVOS_BCSYMBOLMAP_COMMANDS=""
	TVOS_BCSYMBOLMAP_PATHS="build/appletvos/tvOS.xcarchive/BCSymbolMaps/*"

	for path in $TVOS_BCSYMBOLMAP_PATHS; do
		fullPath=$(pwd)/$path
		TVOS_BCSYMBOLMAP_COMMANDS="${TVOS_BCSYMBOLMAP_COMMANDS} -debug-symbols $fullPath"
	done

	echo $TVOS_BCSYMBOLMAP_COMMANDS
}

getiOSBCFiles
gettvOSBCFiles
xcodebuild -create-xcframework \
	-framework build/iphoneos/NewRelic.framework \
		-debug-symbols /Users/jenkins/workspace/Agent-Generate-XCFramework/build/iphoneos/iOS.xcarchive/dSYMs/NewRelic.framework.dSYM \
		$IPHONE_BCSYMBOLMAP_COMMANDS \
	-framework build/iphonesimulator/NewRelic.framework \
	-framework build/appletvsimulator/NewRelic.framework/ \
	-framework build/appletvos/NewRelic.framework \
		-debug-symbols /Users/jenkins/workspace/Agent-Generate-XCFramework/build/appletvos/tvOS.xcarchive/dSYMs/NewRelic.framework.dSYM \
		$TVOS_BCSYMBOLMAP_COMMANDS \
	-framework build/macosx/NewRelic.framework 	\
		-debug-symbols /Users/jenkins/workspace/Agent-Generate-XCFramework/build/macosx/macosx.xcarchive/dSYMs/NewRelic.framework.dSYM \
	-output build/NewRelic.xcframework


cp -r dsym-upload-tools/ build/NewRelic.xcframework/Resources/