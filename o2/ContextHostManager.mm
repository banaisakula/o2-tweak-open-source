#import "ContextHostManager.h"

@implementation ContextHostManager

static id parentScene;
static id primarySceneLayer;
#pragma mark - public methods

+ (id)sharedInstance{
    static dispatch_once_t onceToken;
    static ContextHostManager *sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [ContextHostManager new];
    });
    return sharedInstance;
}

#pragma mark - iOS 13

-(void *)iOS13HostViewForBundleId:(NSString *)bundleId{
    [self forceApplicationForegroundForBundleId:bundleId];
    
    FBSceneLayer *layer = [self sceneLayerForBundleId:bundleId];
    if (layer) {
        primarySceneLayer = layer;
        [self updateScenes];
    }
    
    return nil;
}

-(UIView *)hostViewForSceneLayer:(FBSceneLayer *)layer{
    _UIContextLayerHostView *hostView = [[NSClassFromString(@"_UIContextLayerHostView") alloc] initWithSceneLayer:layer];
    [hostView setFrame:[UIScreen mainScreen].bounds];
    
    return hostView;

}

-(void)forceApplicationForegroundForBundleId:(NSString *)bundleId{
    FBScene *scene = [self sceneForBundleId:bundleId];
    if (scene) {
        FBSMutableSceneSettings *sceneSettings = [scene valueForKey:@"_mutableSettings"];
        [sceneSettings setForeground:YES];
        [scene updateSettings:sceneSettings withTransitionContext:nil completion:nil];
    }
}

-(FBScene *)sceneForBundleId:(NSString *)bundleId{
    parentScene = nil;
    NSDictionary *scenes = [[NSClassFromString(@"FBSceneManager") sharedInstance] valueForKey:@"_scenesByID"];
    
    NSMutableArray *closeMatches = [[NSMutableArray alloc] init];
    
    for(NSString *identifier in [scenes allKeys]){
        if([identifier containsString:bundleId]){
            if ([scenes[identifier] isKindOfClass:NSClassFromString(@"FBScene")]) {
                [closeMatches addObject:identifier];
            }
        }
    }
        
    if (closeMatches.count == 1) {
        parentScene = scenes[closeMatches.firstObject];
    }else if (closeMatches.count > 1){
        NSArray *sorted = [closeMatches sortedArrayWithOptions:0 usingComparator:^NSComparisonResult(NSString *id1, NSString *id2){

            NSRange r1 = [id1 rangeOfString:bundleId];
            NSRange r2 = [id1 rangeOfString:bundleId];
            
            if (r1.length > r2.length) {
                return NSOrderedDescending;
            }else{
                return NSOrderedAscending;
            }
        }];
        parentScene = scenes[sorted.firstObject];
    }
    
    return parentScene;
}

-(FBSceneLayer *)sceneLayerForBundleId:(NSString *)bundleId{
    FBSceneLayerManager *manager = [[self sceneForBundleId:bundleId] valueForKey:@"layerManager"];
    NSOrderedSet *set = [manager valueForKey:@"layers"];
    
    if (set.count > 0) {
        if (!manager.observationInfo) {
            [manager addObserver:self forKeyPath:@"layers" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:nil];
        }

        for (FBSceneLayer *layer in set) {
            if (!layer.externalSceneID) {
                return layer;
            }
        }
    }
    return nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(FBSceneLayerManager *)object change:(NSDictionary *)change context:(void *)context{
    if ([keyPath isEqualToString:@"layers"]) {
        [self updateScenes];
    }
}

-(void)updateScenes{
    UIView *sceneStack = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIView *externalSceneStack = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    for (FBSceneLayer *layer in [[parentScene valueForKey:@"layerManager"] layers]) {
        if (layer.externalSceneID) {
            _UIExternalSceneLayerHostView *hostView = [[NSClassFromString(@"_UIExternalSceneLayerHostView") alloc] initWithSceneLayer:layer parentScene:parentScene];
            [hostView setFrame:[UIScreen mainScreen].bounds];
            [externalSceneStack addSubview:hostView];
        }else{
            _UIContextLayerHostView *hostView = [[NSClassFromString(@"_UIContextLayerHostView") alloc] initWithSceneLayer:layer];
            [hostView setFrame:[UIScreen mainScreen].bounds];
            [sceneStack addSubview:hostView];
        }
    }
    
    
    [self.sceneDelegate contextManager:self scene:parentScene sceneStackDidChange:sceneStack];
    [self.sceneDelegate contextManager:self scene:parentScene externalSceneStackDidChange:externalSceneStack];
}
//停止托管
-(void)iOS13StopHostingForBundleId:(NSString *)bundleId{
    FBScene *scene = [self sceneForBundleId:bundleId];
    if (scene) {
        FBSceneLayerManager *manager = [scene valueForKey:@"layerManager"];
        if (manager.observationInfo) {
            [manager removeObserver:self forKeyPath:@"layers"];
        }
        
        FBSMutableSceneSettings *sceneSettings = [scene valueForKey:@"_mutableSettings"];
        [sceneSettings setForeground:false];
        [scene updateSettings:sceneSettings withTransitionContext:nil completion:nil];
    }
}


#pragma mark - Pre 13 implementation

- (UIView *)hostViewForApplication:(id)sbapplication {
    [self launchSuspendedApplicationWithBundleID:[(SBApplication *)sbapplication bundleIdentifier]];
    
    [self enableBackgroundingForApplication:sbapplication];
    
    [[self contextManagerForApplication:sbapplication] enableHostingForRequester:[(SBApplication *)sbapplication bundleIdentifier] orderFront:YES];
    
    id hostView = [[self contextManagerForApplication:sbapplication] hostViewForRequester:[(SBApplication *)sbapplication bundleIdentifier] enableAndOrderFront:YES];
    
    return hostView;
}

- (UIView *)hostViewForApplicationWithBundleID:(NSString *)bundleID {
    SBApplication *appToHost = applicationForID(bundleID);
    return [self hostViewForApplication:appToHost];
}

- (void)disableBackgroundingForApplication:(id)sbapplication {
    
    FBSMutableSceneSettings *sceneSettings = [self sceneSettingsForApplication:sbapplication];
    
    [sceneSettings setBackgrounded:YES];
    
    if (IS_IOS11orHIGHER) {
        [[self FBSceneForApplication:sbapplication] updateSettings:sceneSettings withTransitionContext:nil];
    }else{
        [[self FBSceneForApplication:sbapplication] _applyMutableSettings:sceneSettings withTransitionContext:nil completion:nil];
    }
}

- (void)enableBackgroundingForApplication:(id)sbapplication {
    
    FBSMutableSceneSettings *sceneSettings = [self sceneSettingsForApplication:sbapplication];
    
    [sceneSettings setBackgrounded:NO];
    
    if (IS_IOS11orHIGHER) {
        [[self FBSceneForApplication:sbapplication] updateSettings:sceneSettings withTransitionContext:nil];
    }else{
        [[self FBSceneForApplication:sbapplication] _applyMutableSettings:sceneSettings withTransitionContext:nil completion:nil];
    }
}

- (FBScene *)FBSceneForApplication:(id)sbapplication {
    
    FBScene* mainScene =  [(SBApplication *)sbapplication mainScene];
    return mainScene;
}

- (FBWindowContextHostManager *)contextManagerForApplication:(id)sbapplication {
    id contextHostManager = [[self FBSceneForApplication:sbapplication] hostManager];
    return contextHostManager;
}

- (FBSMutableSceneSettings *)sceneSettingsForApplication:(id)sbapplication {
    return [[[self FBSceneForApplication:sbapplication] mutableSettings] mutableCopy];
}
- (void)stopHostingForBundleID:(NSString *)bundleID {
    SBApplication *appToHost = [[NSClassFromString(@"SBApplicationController") sharedInstance] applicationWithBundleIdentifier:bundleID];
    [self disableBackgroundingForApplication:appToHost];
    FBWindowContextHostManager *contextManager = [self contextManagerForApplication:appToHost];
    [contextManager disableHostingForRequester:bundleID];
}




- (void)launchSuspendedApplicationWithBundleID:(NSString *)bundleID {
    [[UIApplication sharedApplication] launchApplicationWithIdentifier:bundleID suspended:YES];
}

static SBApplication *applicationForID(NSString *applicationID){
    id controller = [objc_getClass("SBApplicationController") sharedInstance];
    
    if ([controller respondsToSelector:@selector(applicationWithDisplayIdentifier:)]) {
        return [controller applicationWithDisplayIdentifier:applicationID];
    } else {
        return [controller applicationWithBundleIdentifier:applicationID];
    }
}


@end





