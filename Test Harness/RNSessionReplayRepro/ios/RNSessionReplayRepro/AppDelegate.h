#import <UIKit/UIKit.h>
#import <ReactNativeNavigation/RNNAppDelegate.h>

// react-native-navigation owns the window and root view controllers (native stacks
// inside native bottom tabs), the way the Levi's app is set up.
@interface AppDelegate : RNNAppDelegate

@end

// Apps built with the iOS 27 SDK must use the scene life cycle or they fail to launch.
// react-native-navigation predates scenes: it creates its window on the app delegate during
// launch and finds it there afterwards, so this only moves that window onto the scene.
@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>

@property (nonatomic, strong) UIWindow *window;

@end
