# important note: build/macosx/NewRelic.framework has symbolic links so be sure to
# zip with -y flag whenever compressing that .framework

#!/usr/bin/env bash -x

xcodebuild -create-xcframework \
	-framework build/iphoneos/NewRelic.framework \
		-debug-symbols $(pwd)/build/iphoneos/iOS.xcarchive/dSYMs/NewRelic.framework.dSYM \
	-framework build/iphonesimulator/NewRelic.framework \
	-framework build/appletvsimulator/NewRelic.framework \
    -framework build/watchsimulator/NewRelic.framework \
	-framework build/appletvos/NewRelic.framework \
		-debug-symbols $(pwd)/build/appletvos/tvOS.xcarchive/dSYMs/NewRelic.framework.dSYM \
    -framework build/watchos/NewRelic.framework \
        -debug-symbols $(pwd)/build/watchos/watchOS.xcarchive/dSYMs/NewRelic.framework.dSYM \
	-framework build/macosx/NewRelic.framework 	\
		-debug-symbols $(pwd)/build/macosx/macosx.xcarchive/dSYMs/NewRelic.framework.dSYM \
	-output build/NewRelic.xcframework


cp -r dsym-upload-tools/ build/NewRelic.xcframework/Resources/
