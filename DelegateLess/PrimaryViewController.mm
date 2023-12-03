//
//  PrimaryViewController.mm
//  DelegateLess
//
//  Created by Jinwoo Kim on 12/3/23.
//

#import "PrimaryViewController.hpp"
#import <objc/runtime.h>
#import <objc/message.h>

// Decoded specification class name "InternalSceneSpecification" but could not resolve it via NSClassFromString()
namespace InternalSceneSpecification {
Class classRef;

BOOL isInternal(id self, SEL _cmd) {
    return YES;
}

void registerClass() {
    Class InternalSceneSpecification = objc_allocateClassPair(NSClassFromString(@"UIApplicationSceneSpecification"), "InternalSceneSpecification", 0);
    class_addMethod(InternalSceneSpecification, sel_registerName("isInternal"), reinterpret_cast<IMP>(&isInternal), nil);
    classRef = InternalSceneSpecification;
}
}

@interface PrimaryViewController ()
@end

@implementation PrimaryViewController

+ (void)load {
    InternalSceneSpecification::registerClass();
}

- (IBAction)requestSecondaryScene:(UIButton *)sender {
    if (!UIApplication.sharedApplication.supportsMultipleScenes) {
        NSLog(@"Not supported.");
        return;
    }
    
    UISceneSessionActivationRequest *request = [UISceneSessionActivationRequest requestWithRole:UIWindowSceneSessionRoleApplication];
    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:@"Secondary"];
    request.userActivity = userActivity;
    [userActivity release];
    
    id sharedFactory = reinterpret_cast<id (*)(Class, SEL)>(objc_msgSend)(NSClassFromString(@"_UIWorkspaceSceneRequestOptionsFactory"), sel_registerName("sharedFactory"));
    
    id endpoint = reinterpret_cast<id (*)(id, SEL, id)>(objc_msgSend)(sharedFactory, sel_registerName("customEndpointForRequest:"), request);
    
    if (!endpoint) {
        endpoint = reinterpret_cast<id (*)(Class, SEL, id, id, id)>(objc_msgSend)(NSClassFromString(@"BSServiceConnectionEndpoint"),
                                                                                  sel_registerName("endpointForMachName:service:instance:"),
                                                                                  @"com.apple.frontboard.systemappservices",
                                                                                  @"com.apple.frontboard.workspace-service",
                                                                                  nil);
    }
    
    reinterpret_cast<void (*)(id, SEL, id, id)>(objc_msgSend)(sharedFactory,
                                                              sel_registerName("buildWorkspaceRequestOptionsForRequest:withContinuation:"),
                                                              request,
                                                              ^(id _Nullable options, NSError * _Nullable error) {
        assert(!error);
        
        // affectsAppLifecycleIfInternal, isInternal
//        NSLog(@"%@", reinterpret_cast<id (*)(id, SEL)>(objc_msgSend)(options, sel_registerName("specification")));
//        id specification = [InternalSceneSpecification::classRef new];
//        reinterpret_cast<void (*)(id, SEL, id)>(objc_msgSend)(options, sel_registerName("setSpecification:"), specification);
//        [specification release];
        
        id specification = [NSClassFromString(@"UIApplicationSceneSpecification") new];
        reinterpret_cast<void (*)(id, SEL, id)>(objc_msgSend)(options, sel_registerName("setSpecification:"), specification);
        [specification release];
        
        id sharedWorkspace = reinterpret_cast<id (*)(Class, SEL)>(objc_msgSend)(NSClassFromString(@"FBSWorkspace"), sel_registerName("_sharedWorkspaceIfExists"));
        
        reinterpret_cast<void (*)(id, SEL, id, id, id)>(objc_msgSend)(sharedWorkspace,
                                                                      sel_registerName("requestSceneFromEndpoint:withOptions:completion:"),
                                                                      endpoint,
                                                                      options,
                                                                      ^(id _Nullable fbsScene, NSError * _Nullable error) {
            assert(!error);
        });
    });
}

@end
