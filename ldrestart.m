//Huge thanks to Morpheus for this

#include <xpc/xpc.h>
#import <dlfcn.h>
#include <sys/stat.h>
#include <sys/fcntl.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#include <TargetConditionals.h>
#include <IOKit/pwr_mgt/IOPMLib.h>

#define DLog(format, ...) CFShow((__bridge CFStringRef)[NSString stringWithFormat:format, ## __VA_ARGS__]);

/*
 
 13.2.2 service list

 "com.apple.homed", "com.apple.corercd", "com.apple.nsurlsessiond", "com.apple.mobileactivationd", "com.apple.wifid", "com.apple.diagnosticextensionsd", "com.apple.syslogd", "com.apple.securityd", "com.apple.symptomsd", "com.apple.UserEventAgent-System", "com.apple.assistant_service", "com.apple.itunesstored", "com.saurik.substrated", "com.apple.mediaremoted", "com.apple.logd", "com.apple.nehelper", "com.apple.accessibility.AccessibilityUIServer", "com.apple.PineBoard", "com.apple.ctkd", "com.apple.contextstored", "com.apple.awdd", "com.apple.mDNSResponderHelper.reloaded", "com.apple.mobile.heartbeat", "com.apple.online-auth-agent.xpc", "com.apple.cloudd", "com.apple.OTACrashCopier", "com.apple.aslmanager", "com.apple.ap.adprivacyd", "com.apple.networkserviceproxy", "com.apple.runningboardd", "com.apple.siri.ClientFlow.ClientScripter", "com.apple.diagnosticd", "com.apple.mobilegestalt.xpc", "com.nito.safetynet", "com.apple.powerd", "com.apple.fairplayd.T2", "com.apple.tccd", "com.apple.atvcached", "com.apple.mobile.installd", "com.apple.akd", "com.apple.watchdogd", "com.apple.askpermissiond", "com.apple.nsurlstoraged", "com.apple.backboardd", "com.apple.timed", "com.apple.lsd", "com.apple.checkra1n.loaderd", "com.apple.MobileSoftwareUpdate.CleanupPreparePathService", "com.apple.pluginkit.pkd", "com.openssh.sshd", "com.apple.bluetoothd", "com.apple.mediaserverd", "com.apple.cache_delete", "com.apple.configd", "com.apple.tvperipheralagent", "com.apple.dmd", "UIKitApplication:com.apple.HeadBoard[2ea6][rb-legacy]", "com.apple.audio.toolbox.reporting.service", "com.apple.security.cloudkeychainproxy3", "com.apple.followupd", "com.apple.BlueTool", "com.apple.identityservicesd", "com.apple.MobileInstallationHelperService", "com.apple.coreduetd", "com.apple.mobilestoredemod", "com.apple.locationd", "com.apple.containermanagerd", "com.apple.crash_mover", "UIKitApplication:com.apple.TVAirPlay[d360][rb-legacy]", "com.apple.notifyd", "com.apple.rapportd", "com.apple.fseventsd", "com.apple.accountsd", "com.apple.wifianalyticsd", "com.apple.mobilestoredemodhelper", "com.apple.atc", "com.apple.familynotification", "com.apple.videosubscriptionsd", "com.apple.MobileAccessoryUpdater", "com.apple.sharingd", "com.apple.trustd", "com.apple.crashreportcopymobile", "com.apple.mDNSResponder.reloaded", "com.apple.aggregated", "com.apple.distnoted.xpc.daemon", "com.apple.cfprefsd.xpc.daemon", "com.apple.amsaccountsd", "com.apple.mobile.notification_proxy", "com.apple.assistantd", "com.nito.breezyd", "com.apple.mobile.keybagd", "com.apple.mobile.softwareupdated", "com.nito.restartd", "com.apple.misagent", "com.apple.thermalmonitord", "com.apple.medialibraryd", "com.apple.mobile.lockdown", "com.apple.OTATaskingAgent", "com.apple.mobile.storage_mounter", "com.apple.corespeechd", "com.apple.itunescloudd", "com.apple.adid", "com.apple.BTServer.le", "com.apple.mobileassetd", "com.apple.mobile.storage_mounter_proxy", "com.apple.managedconfiguration.profiled", "com.apple.installcoordinationd", "com.apple.appstored", "com.apple.apsd", "com.apple.contactsd", "com.apple.swcd", "com.apple.absd", "com.apple.mobile.installation_proxy", "com.apple.tvphotosourcesd", "com.apple.dasd", "com.apple.watchlistd", "UIKitApplication:com.apple.TVSystemBulletinService[2b83][rb-legacy]", "com.apple.geod", "com.apple.analyticsd",
 
 
 */


#if TARGET_OS_TV
@interface NSDistributedNotificationCenter : NSNotificationCenter

+ (id)defaultCenter;

- (void)addObserver:(id)arg1 selector:(SEL)arg2 name:(id)arg3 object:(id)arg4;
- (void)postNotificationName:(id)arg1 object:(id)arg2 userInfo:(id)arg3;

@end

#endif

extern int xpc_pipe_routine (xpc_object_t *xpc_pipe, xpc_object_t *inDict, xpc_object_t **out);
extern char *xpc_strerror (int);

#define HANDLE_SYSTEM 0

// Some of the routine #s launchd recognizes. There are quite a few subsystems

#define ROUTINE_START		0x32d	// 813
#define ROUTINE_STOP		0x32e	// 814
#define ROUTINE_LIST		0x32f	// 815

// XPC sets up global variables using os_alloc_once. By reverse engineering
// you can determine the values. The only one we actually need is the fourth
// one, which is used as an argument to xpc_pipe_routine

struct xpc_global_data {
	uint64_t	a;
	uint64_t	xpc_flags;
	mach_port_t	task_bootstrap_port;  /* 0x10 */
#ifndef _64
	uint32_t	padding;
#endif
	xpc_object_t	xpc_bootstrap_pipe;   /* 0x18 */
	// and there's more, but you'll have to wait for MOXiI 2 for those...
	// ...
};

// os_alloc_once_table:
//
// Ripped this from XNU's libsystem
#define OS_ALLOC_ONCE_KEY_MAX	100

struct _os_alloc_once_s {
	long once;
	void *ptr;
};

extern struct _os_alloc_once_s _os_alloc_once_table[];

static int stopService(const char *ServiceName)
{
	xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_uint64 (dict, "subsystem", 3); // subsystem (3)
	xpc_dictionary_set_uint64 (dict, "handle", HANDLE_SYSTEM);
	xpc_dictionary_set_uint64(dict, "routine", ROUTINE_STOP);
	xpc_dictionary_set_uint64 (dict, "type", 1);
	xpc_dictionary_set_string (dict, "name", ServiceName);

	xpc_object_t	*outDict = NULL;

	struct xpc_global_data  *xpc_gd  = (struct xpc_global_data *)  _os_alloc_once_table[1].ptr;

	int rc = xpc_pipe_routine (xpc_gd->xpc_bootstrap_pipe, dict, &outDict);
	if (rc == 0) {
		rc = xpc_dictionary_get_int64 (outDict, "error");
		if (rc) {
			fprintf(stderr, "Error stopping service:  %d - %s\n", rc, xpc_strerror(rc));
			return (rc);
		}
	}
	return rc;
}

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

void performUserAction() {
    
    //NSLog(@"[AirMagic] performUserAction");
    IOPMAssertionID assertionID;
    IOPMAssertionDeclareUserActivity(CFSTR(""), kIOPMUserActiveLocal, &assertionID);
    
}


int file_exists(const char *filename) {
    struct stat buffer;
    int r = stat(filename, &buffer);
    return (r == 0);
}


void killPineBoardIfNecessary() {
    
   // if (file_exists("/Library/dpkg/info/com.nito.airmagic.list")){
        //DLog(@"killing pineboard to fix AirMagic");
        char line[200];
        FILE* fp = popen("/usr/bin/killall -9 backboardd", "r");
        if (fp)
        {
            while (fgets(line, sizeof line, fp))
            {
                //no-op
            }
        }
        pclose(fp);
   // }
    
}

@interface LDRestart: NSObject

+(void)killPineBoard;

@end

@implementation LDRestart

+ (void)killPineBoard {
    
}
@end

int main(){
	platformizeme();
#if TARGET_OS_TV
    
    const char *bc = "/var/mobile/Library/Caches/com.apple.PreBoard/BootCount";
    int test = open(bc, O_RDONLY);
    if (test != -1) {
        FILE *bootCount = fopen(bc,"w");
        fprintf(bootCount,"%s","0"); //writes
        fclose(bootCount); //done
    }
    performUserAction();
/*
    Class notecenter = objc_getClass("NSDistributedNotificationCenter");
    id note = [notecenter defaultCenter];
    [note postNotificationName:@"com.nitoTV.wakeup" object:nil ];
    
     [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.nitoTV.wakeup" object:nil ];
 */
    /*
    NSString *pineBoardServices = @"/System/Library/PrivateFrameworks/PineBoardServices.framework/";
    NSBundle *pbs = [NSBundle bundleWithPath:pineBoardServices];
    [pbs load];
    Class powermanager = objc_getClass("PBSPowerManager");
    [powermanager setupPowerManagement];
    [powermanager load];
    id power = [powermanager sharedInstance];
    if ([power isDeviceAsleep]){
        DLog(@"sleepy time!");
    } else {
        DLog(@"fucking woke");
    }
    [power _performUserEventWakeDevice];
    [power wakeDeviceWithOptions:@{@"WakeReason":@"UserActivity"}];
  */
    sleep(4);
    //exit(0);
#endif
	xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
	xpc_dictionary_set_uint64(dict, "subsystem", 3); // subsystem (3)
	xpc_dictionary_set_uint64(dict, "handle", HANDLE_SYSTEM);
	xpc_dictionary_set_uint64(dict, "routine", ROUTINE_LIST);
	xpc_dictionary_set_uint64(dict, "type", 1); // set to 1
	xpc_dictionary_set_bool(dict, "legacy", 1); // mandatory

	xpc_object_t	*outDict = NULL;

	struct xpc_global_data  *xpc_gd  = (struct xpc_global_data *)  _os_alloc_once_table[1].ptr;

	int rc = xpc_pipe_routine (xpc_gd->xpc_bootstrap_pipe, dict, &outDict);
	if (rc == 0) {
		int err = xpc_dictionary_get_int64 (outDict, "error");
		if (!err){
			// We actually got a reply!
			xpc_object_t svcs = xpc_dictionary_get_value(outDict, "services");
			if (!svcs)
			{
				fprintf(stderr,"Error: no services returned for list\n");
				return 1;
			}

			xpc_type_t	svcsType = xpc_get_type(svcs);
			if (svcsType != XPC_TYPE_DICTIONARY)
			{
				fprintf(stderr,"Error: services returned for list aren't a dictionary!\n");
				return 2;
			}

			xpc_dictionary_apply(svcs, ^bool (const char *label, xpc_object_t svc) 
			{
                if (strcmp(label, "jailbreakd") == 0 || strcmp(label, "com.apple.MobileFileIntegrity") == 0 || strcmp(label, "com.apple.syslogd") == 0  || (strstr(label, "sshd") != NULL) || strcmp(label, "com.apple.dt.power") == 0|| strcmp(label, "com.apple.dt.devicearbitration") == 0|| strcmp(label, "com.apple.DuetHeuristic-BM") == 0|| strcmp(label, "com.apple.fdrserviced") == 0|| strcmp(label, "com.apple.tsloader") == 0|| strcmp(label, "com.apple.accessibility.axAuditDaemon.deviceservice") == 0|| strcmp(label, "com.apple.syslog_relay") == 0|| strcmp(label, "com.saurik.substrated") == 0 || strcmp(label, "com.apple.deleted_helper") == 0 || strcmp(label, "com.apple.ind") == 0 || strcmp(label, "com.apple.mobile.cache_delete_app_container_caches") == 0 || strcmp(label, "com.apple.coresymbolicationd") == 0 || strcmp(label, "com.apple.assistant_service") == 0
                    || strcmp(label, "com.apple.watchdogd") == 0 || strcmp(label, "com.nito.restartd") == 0 ||  strcmp(label, "com.apple.backboardd") == 0 || (strstr(label, "dropbear") != NULL))
					{
                        return 1;
                        
                    }
#if TARGET_OS_TV
                //since backboardd being killed handles these two
                if(strstr(label, "PineBoard") != NULL || strstr(label, "HeadBoard") != NULL  ) {
                    return 1;
                }
#endif
				int64_t pid = xpc_dictionary_get_int64(svc, "pid");
				if (pid != 0){
                    //fprintf(stderr,"stopping service labeled: %s\n", label);
                    fprintf(stderr,"\"%s\"\n", label);
					stopService(label);
                    //sleep(2);
                }

                return 1;
			});
            #if TARGET_OS_TV
                //sleep(5);
                //stopService("com.apple.backboardd");
                sleep(3);
                stopService("com.apple.PineBoard");
            //killPineBoardIfNecessary();
            #endif
		} else {
			fprintf(stderr, "Error:  %d - %s\n", err, xpc_strerror(err));
		}
	} else {
		fprintf(stderr, "Unable to get launchd: %d\n", rc);
	}
}
