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

xcodebuild -create-xcframework \
	-framework build/iphoneos/NewRelic.framework \
		-debug-symbols build/iphoneos/iOS.xcarchive/dSYMs/NewRelic.framework.dSYM \
		$(getiOSBCFiles) \
	-framework build/iphonesimulator/NewRelic.framework \
	-framework build/appletvsimulator/NewRelic.framework/ \
	-framework build/appletvos/NewRelic.framework \
	-framework build/macosx/NewRelic.framework 	\
	-output build/NewRelic.xcframework


cp -r dsym-upload-tools/ build/NewRelic.xcframework/Resources/