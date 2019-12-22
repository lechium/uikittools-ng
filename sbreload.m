#import <dlfcn.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#include <TargetConditionals.h>

typedef NS_OPTIONS(NSUInteger, SBSRelaunchActionOptions) {
	SBSRelaunchActionOptionsNone,
	SBSRelaunchActionOptionsRestartRenderServer = 1 << 0,
	SBSRelaunchActionOptionsSnapshotTransition = 1 << 1,
	SBSRelaunchActionOptionsFadeToBlackTransition = 1 << 2
};

@interface SBSRelaunchAction : NSObject
+ (instancetype)actionWithReason:(NSString *)reason options:(SBSRelaunchActionOptions)options targetURL:(NSURL *)targetURL;
@end

@interface FBSSystemService : NSObject
+ (instancetype)sharedService;
- (void)sendActions:(NSSet *)actions withResult:(id)result;
@end

#if TARGET_OS_TV

@interface PBSPowerManager : NSObject

+(id)sharedInstance;
+(void)load;
+(void)setupPowerManagement;
-(void)_performUserEventWakeDevice;
-(void)wakeDeviceWithOptions:(id)arg1;
-(void)setNeedsDisplayWakeOnPowerOn:(BOOL)arg1;
- (void)sleepDeviceWithOptions:(id)arg1;
-(void)_registerForPowerNotifications;
-(void)_registerForThermalNotifications;
-(void)_enableIdleSleepAndWatchdog;
-(void)_registerForBackBoardNotifications;
-(void)_updateIdleTimer;
@end

@interface PBSSystemService : NSObject
+(id)sharedInstance;
-(void)endpointForProviderType:(id)arg1 withIdentifier:(id)arg2 responseBlock:(/*^block*/id)arg3 ;
-(void)launchKioskApp;
-(void)sleepSystemForReason:(id)arg1 ;
-(void)wakeSystemForReason:(id)arg1 ;
-(void)relaunchBackboardd;
-(void)relaunch;
-(void)reboot;
-(id)infoForProvidersWithType:(id)arg1 ;
-(void)deactivateApplication;
-(void)registerServiceProviderEndpoint:(id)arg1 forProviderType:(id)arg2 ;
-(void)deactivateScreenSaver;

@end

#endif


pid_t springboardPID;
pid_t backboarddPID;

int stopService(const char *ServiceName);
int updatePIDs(void);

/* Set platform binary flag */
#define FLAG_PLATFORMIZE (1 << 1)

void platformizeme() {
    void* handle = dlopen("/usr/lib/libjailbreak.dylib", RTLD_LAZY);
    if (!handle) return;
    
    // Reset errors
    dlerror();
    typedef void (*fix_entitle_prt_t)(pid_t pid, uint32_t what);
    fix_entitle_prt_t ptr = (fix_entitle_prt_t)dlsym(handle, "jb_oneshot_entitle_now");
    
    const char *dlsym_error = dlerror();
    if (dlsym_error) {
        return;
    }
    
    ptr(getpid(), FLAG_PLATFORMIZE);
}

int main(){
	@autoreleasepool {
		platformizeme();

		springboardPID = 0;
		backboarddPID = 0;

		updatePIDs();

		dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices", RTLD_NOW);
#if TARGET_OS_TV
        dlopen("/System/Library/PrivateFrameworks/PineBoardServices.framework/PineBoardServices", RTLD_NOW);
        id systemService = [objc_getClass("PBSSystemService") sharedInstance];
        //Class powermanager = objc_getClass("PBSPowerManager");
        //[powermanager setupPowerManagement];
        //[powermanager load];
        //id power = [objc_getClass("PBSPowerManager") sharedInstance];
        //NSLog(@"power: %@", power);
        //[power setDelegate:self];
        //[power setNeedsDisplayWakeOnPowerOn:TRUE];
        //[power sleepDeviceWithOptions:@{@"SleepReason": @"UserSettings"}];
        //[power _performUserEventWakeDevice];
        //[power wakeDeviceWithOptions:@{@"WakeReason":@"UserActivity"}];
        //sleep(10);
        [systemService relaunch];
        //return 0;
        
#else
        dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_NOW);
        SBSRelaunchAction *restartAction = [objc_getClass("SBSRelaunchAction") actionWithReason:@"respring" options:(SBSRelaunchActionOptionsRestartRenderServer | SBSRelaunchActionOptionsFadeToBlackTransition) targetURL:nil];
        [(FBSSystemService *)[objc_getClass("FBSSystemService") sharedService] sendActions:[NSSet setWithObject:restartAction] withResult:nil];
#endif
		
		sleep(2);

		int old_springboardPID = springboardPID;
		int old_backboarddPID = backboarddPID;

		updatePIDs();

		if (springboardPID == old_springboardPID){
#if TARGET_OS_TV
            stopService("com.apple.PineBoard");

#else
            stopService("com.apple.SpringBoard");

#endif
		}
		if (backboarddPID == old_backboarddPID){
			stopService("com.apple.backboardd");
		}
	}
	return 0;
}
