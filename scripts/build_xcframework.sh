# important note: build/macosx/NewRelic.framework has symbolic links so be sure to
# zip with -y flag whenever compressing that .framework

#!/usr/bin/env bash -x

function getiOSBCFiles() {
	IPHONE_BCSYMBOLMAP_COMMANDS=""
	IPHONE_BCSYMBOLMAP_PATHS="build/iphoneos/iOS.xcarchive/BCSymbolMaps/"

	for path in "${IPHONE_BSCYMBOLMAP_PATHS[@]}"; do
		IPHONE_BCSYMBOLMAP_COMMANDS="${IPHONE_BCSYMBOLMAP_COMMANDS} -debug-symbols $path "
	done

	echo $IPHONE_BCSYMBOLMAP_COMMANDS
}

function gettvOSBCFiles() {
	TVOS_BCSYMBOLMAP_COMMANDS=""
	TVOS_BCSYMBOLMAP_PATHS="build/appletvos/tvOS.xcarchive/BCSymbolMaps/"

	for path in "${IPHONE_BCSYMBOLMAP_PATHS[@]}"; do
		TVOS_BCSYMBOLMAP_COMMANDS="${TVOS_BCSYMBOLMAP_COMMANDS} -debug-symbols $path"
	done

	echo $TVOS_BCSYMBOLMAP_COMMANDS
}

xcodebuild -create-xcframework \
	-framework build/iphoneos/NewRelic.framework \
		-debug-symbols /Users/jenkins/workspace/Agent-Generate-XCFramework/build/iphoneos/iOS.xcarchive/dSYMs/NewRelic.framework.dSYM \
		$(getiOSBCFiles) \
	-framework build/iphonesimulator/NewRelic.framework \
	-framework build/appletvsimulator/NewRelic.framework/ \
	-framework build/appletvos/NewRelic.framework \
		-debug-symbols /Users/jenkins/workspace/Agent-Generate-XCFramework/build/appletvos/tvOS.xcarchive/dSYMs/NewRelic.framework.dSYM \
		$(gettvOSBCFiles) \
	-framework build/macosx/NewRelic.framework 	\
		-debug-symbols /Users/jenkins/workspace/Agent-Generate-XCFramework/build/macosx/macosx.xcarchive/dSYMs/NewRelic.framework.dSYM \
	-output build/NewRelic.xcframework


cp -r dsym-upload-tools/ build/NewRelic.xcframework/Resources/