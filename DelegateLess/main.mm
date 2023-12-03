//
//  main.mm
//  DelegateLess
//
//  Created by Jinwoo Kim on 12/3/23.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

namespace DL_UIApplication {
namespace _appAdoptsUISceneLifecycle {
BOOL custom(UIApplication *self, SEL _cmd) {
    // AppDelegate가 없을 경우 NO가 나올 것이며, 그러면 -[UIApplicationSceneSpecification initialActionHandlers]에서 _UISceneUserActivityBSActionsHandler 같은게 생성되지 않음.
    // 그러면 NSUserActivity를 포함한 Action들이 -[_UISceneConnectionOptionsContext unprocessedActions]에 들어가면서 무시되는 현상이 생기므로, YES로 방지
    return YES;
}
void swizzle() {
    Method method = class_getInstanceMethod(UIApplication.class, sel_registerName("_appAdoptsUISceneLifecycle"));
    method_setImplementation(method, reinterpret_cast<IMP>(&custom));
}
}

namespace _connectUISceneFromFBSScene_transitionContext {
void *windowAssociationKey = &windowAssociationKey;

id custom(UIApplication *self, SEL _cmd, id fbsScene, id transitionContext) {
    id specification = reinterpret_cast<id (*)(id, SEL)>(objc_msgSend)(fbsScene, NSSelectorFromString(@"specification"));
    
    NSString *uiSceneSessionRole = reinterpret_cast<id (*)(id, SEL)>(objc_msgSend)(specification, sel_registerName("uiSceneSessionRole"));
    
    NSString *identifier = reinterpret_cast<id (*)(Class, SEL, id)>(objc_msgSend)(UIScene.class, sel_registerName("_persistenceIdentifierForScene:"), fbsScene);
    
    reinterpret_cast<id (*)(id, SEL, id)>(objc_msgSend)(self, sel_registerName("_openSessionForPersistentIdentifier:"), identifier);
    UISceneSession *sceneSession = reinterpret_cast<id (*)(id, SEL, id, id, id)>(objc_msgSend)([UISceneSession alloc],
                                                                                               sel_registerName("_initWithPersistentIdentifier:sessionRole:configurationName:"),
                                                                                               identifier,
                                                                                               uiSceneSessionRole,
                                                                                               nil);
    
//    UISceneConfiguration *configuration = [UISceneConfiguration configurationWithName:nil sessionRole:uiSceneSessionRole];
//    configuration.sceneClass = UIWindowScene.class;
//    
//    reinterpret_cast<void (*)(id, SEL, id)>(objc_msgSend)(sceneSession, sel_registerName("_updateConfiguration:"), configuration);
    
    NSSet *actions = reinterpret_cast<id (*)(id, SEL)>(objc_msgSend)(transitionContext, NSSelectorFromString(@"actions"));
    
    id connectionOptionsContext = reinterpret_cast<id (*)(Class, SEL, id, id, id, id, id)>(objc_msgSend)(UIScene.class,
                                                                                                         sel_registerName("_connectionOptionsForScene:withSpecification:transitionContext:actions:sceneSession:"),
                                                                                                         fbsScene,
                                                                                                         specification,
                                                                                                         transitionContext,
                                                                                                         actions,
                                                                                                         sceneSession);
    
    NSSet *unprocessedActions = reinterpret_cast<id (*)(id, SEL)>(objc_msgSend)(connectionOptionsContext, sel_registerName("unprocessedActions"));
    assert(!unprocessedActions.count);
    
    UISceneConnectionOptions *connectionOptions = reinterpret_cast<id (*)(id, SEL, id, id, id)>(objc_msgSend)([UISceneConnectionOptions alloc],
                                                                                                              sel_registerName("_initWithConnectionOptionsContext:fbsScene:specification:"),
                                                                                                              connectionOptionsContext,
                                                                                                              fbsScene,
                                                                                                              specification);
    
    UIWindowScene *windowScene = reinterpret_cast<id (*)(Class, SEL, id, BOOL, id, id)>(objc_msgSend)(UIScene.class,
                                                                                                      sel_registerName("_sceneForFBSScene:create:withSession:connectionOptions:"),
                                                                                                      fbsScene,
                                                                                                      YES,
                                                                                                      sceneSession,
                                                                                                      connectionOptions);
    
    [sceneSession release];
    
    UIStoryboard * _Nullable storyboard = nil;
    
    for (NSUserActivity *userActivity in connectionOptions.userActivities) {
        if ([userActivity.activityType isEqualToString:@"Secondary"]) {
            storyboard = [UIStoryboard storyboardWithName:@"SecondaryStoryboard" bundle:NSBundle.mainBundle];
        }
    }
    
    [connectionOptions release];
    
    if (!storyboard) {
        storyboard = [UIStoryboard storyboardWithName:@"PrimaryStoryboard" bundle:NSBundle.mainBundle];
    }
    
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:windowScene];
    window.rootViewController = [storyboard instantiateInitialViewController];
    [window makeKeyAndVisible];
    objc_setAssociatedObject(windowScene.screenshotService, windowAssociationKey, window, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [window release];
    
    return windowScene;
}
void swizzle() {
    Method method = class_getInstanceMethod(UIApplication.class, sel_registerName("_connectUISceneFromFBSScene:transitionContext:"));
    method_setImplementation(method, reinterpret_cast<IMP>(&custom));
}
}
}

int main(int argc, char * argv[]) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    DL_UIApplication::_appAdoptsUISceneLifecycle::swizzle();
    DL_UIApplication::_connectUISceneFromFBSScene_transitionContext::swizzle();
    int result = UIApplicationMain(argc, argv, NULL, NULL);
    [pool release];
    
    return result;
}
