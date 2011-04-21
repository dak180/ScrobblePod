//
//  MobileDeviceSupport.m
//  iScrobbler
//
//  Created by Brian Bergstrand on 7/12/2007.
//  Copyright 2008 Brian Bergstrand.
//
//  Released under the GPL, license details available in res/gpl.txt
//

#import <sys/errno.h>
#import <dlfcn.h>
#import <mach/error.h>

#import <IOKit/IOMessage.h>
#import <IOKit/usb/IOUSBLib.h>

#import <Foundation/Foundation.h>

// Private MobileDevice framework support

// Device notification types
enum {
    kDeviceNotificationConnected = 1,
    kDeviceNotificationDisconnected = 2,
};

enum {
    kProduct_iPodTouch = 4753,
	kProduct_iPodTouch2G = 4755,
	kProduct_iPodTouch3G = 4761,
	kProduct_iPodTouch4G = 4766,
	kProduct_iPhone = 4752,
    kProduct_iPhone3G = 4754,
	kProduct_iPhone3GS = 4756,
	kProduct_iPad = 4762,
	kProduct_iPhone4 = 4759,
	kProduct_iPhone4CDMA = 4764,
};

struct AMDevice
{
	// Thanks to iFunbox.dev
	unsigned int unknown_header[2];
	unsigned int unknown0[4];
	unsigned int deviceID;
	unsigned int unknown5;
	unsigned int productID;
	char *serial;
	unsigned int lockdown_conn;
	unsigned char unknown3[8];
	unsigned char unknown4[6*16+1];
	unsigned char padding[8];
	unsigned char safe_extending[256];
} __attribute__ ((packed));

struct AMDeviceCallbackInfo {
    struct AMDevice *device; // device description
    unsigned int type; // notification type
} __attribute__ ((packed));

struct AMDeviceNotification {
    unsigned int unknown0;
    unsigned int unknown1;
    unsigned int unknown2;
    void *callback;
    unsigned int unknown3;
} __attribute__ ((packed));

struct AMDeviceConnection {
    unsigned char private[44];
} __attribute__ ((packed));

typedef void(*AMDeviceNotificationCallback)(struct AMDeviceCallbackInfo *);

typedef mach_error_t (*AMDeviceNotificationSubscribe)(AMDeviceNotificationCallback callback,
    unsigned int unknown, unsigned int unknown1, unsigned int unkonwn3,
    struct AMDeviceNotification **notification);

typedef CFStringRef (*AMDeviceCopyDeviceIdentifier)(struct AMDevice *);

typedef void* (*AMDeviceCopyValue)(struct AMDevice *, int unknown, CFStringRef str);

// Private MobileDevice framework support

#if !defined(__LP64__)
static void DeviceNotificationCallback_(struct AMDeviceCallbackInfo *info);

static void *libHandle = nil;

static void CFHandleCallback(CFNotificationCenterRef center, void *observer, CFStringRef name,
    const void *object, CFDictionaryRef userInfo);

NSMutableDictionary *devicesAttachedBeforeLaunch = nil;
static NSMutableDictionary* FindAttachedDevices(void);

#endif

__private_extern__
int IntializeMobileDeviceSupport(const char *path, void **handle)
{
    int err;
    #if !defined(__LP64__)
    if (libHandle) {
        if (handle)
            *handle = NULL;
        return (0);
    }
    
    devicesAttachedBeforeLaunch = [FindAttachedDevices() retain];
    
    if ((libHandle = dlopen(path, RTLD_LAZY|RTLD_LOCAL))) {
        AMDeviceNotificationSubscribe subscribe;
        if ((subscribe = dlsym(libHandle, "AMDeviceNotificationSubscribe"))) {
            struct AMDeviceNotification *note;
            err = subscribe(DeviceNotificationCallback_, 0, 0, 0, &note);
            
            // Don't know how to get a sync start/finished notification from the MB framework
            // so rely on sync services notifications.
            // XXX: do these occur if the user turned off all shared data syncing (mail/contacts/etc)?
            CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(), NULL,
                CFHandleCallback, CFSTR("com.apple.syncservices.iPodSync.SyncStatusChangedNotification"), NULL, 0);
        } else {
            dlclose(libHandle);
            libHandle = NULL;
            err = cfragNoSymbolErr;
        }
    } else
        err = cfragNoLibraryErr;
    
    if (handle)
        *handle = NULL; // XXX: for now don't publish the handle
    #else
    err = cfragFragmentFormatErr; // MobileDevice framework is 32bit only (as of iTunes 7.7)
    #endif
    
    if (err) {
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"org.bergstrand.amds.intializeDidFail"
            object:[NSNumber numberWithInt:err]];
    }
    return (err);
}

#if !defined(__LP64__)
static NSMutableDictionary *connectedDevices = nil;

static void CFHandleCallback(CFNotificationCenterRef center, void *observer, CFStringRef name,
    const void *object, CFDictionaryRef userInfo)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    @try {

    if ([@"com.apple.syncservices.iPodSync.SyncStatusChangedNotification" isEqualToString:(id)name]) {
        NSString *serial = [(id)object lowercaseString];
        NSDictionary *d;
        if (nil == (d = [connectedDevices objectForKey:serial]))
            return;
        
        NSString *state = [(id)userInfo objectForKey:@"State"];
        
        if ([state isEqualToString:@"Finished"]) {
            [[NSDistributedNotificationCenter defaultCenter]
                postNotificationName:@"org.bergstrand.amds.syncDidFinish"
                object:serial userInfo:d];
        } else if ([state isEqualToString:@"Starting"]) {
            [[NSDistributedNotificationCenter defaultCenter]
                postNotificationName:@"org.bergstrand.amds.syncDidStart"
                object:serial userInfo:d];
        }
    }
    
    } @catch(NSException *e) {}
    [pool drain];
}

static void DeviceNotificationCallback_(struct AMDeviceCallbackInfo *info)
{
    if (!info)
        return;

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    @try {
    
    if (!connectedDevices)
        connectedDevices = [[NSMutableDictionary alloc] init];
    
    NSDictionary *productNameMap = [NSDictionary dictionaryWithObjectsAndKeys:
		@"iPod Touch", [NSNumber numberWithUnsignedInt:kProduct_iPodTouch],
		@"iPod Touch 2G", [NSNumber numberWithUnsignedInt:kProduct_iPodTouch2G],
		@"iPod Touch 3G", [NSNumber numberWithUnsignedInt:kProduct_iPodTouch3G],
		@"iPod Touch 4G", [NSNumber numberWithUnsignedInt:kProduct_iPodTouch4G],
		@"iPhone", [NSNumber numberWithUnsignedInt:kProduct_iPhone],							
        @"iPhone 3G", [NSNumber numberWithUnsignedInt:kProduct_iPhone3G],
		@"iPhone 3GS", [NSNumber numberWithUnsignedInt:kProduct_iPhone3GS],
		@"iPhone 4", [NSNumber numberWithUnsignedInt:kProduct_iPhone4],
		@"iPhone 4", [NSNumber numberWithUnsignedInt:kProduct_iPhone4CDMA],
		@"iPad", [NSNumber numberWithUnsignedInt:kProduct_iPad],
        nil];
    
    NSString *deviceName;
    
    AMDeviceCopyDeviceIdentifier copyID = dlsym(libHandle, "AMDeviceCopyDeviceIdentifier");
    #ifdef notyet
    // CopyValue requires a connection to the device
    AMDeviceCopyValue copyVal = dlsym(libHandle, "AMDeviceCopyValue");
    CFStringRef kAMDDeviceName = dlsym(libHandle, "kAMDDeviceName");
    if (copyVal && kAMDDeviceName && info->device)
        deviceName = [(id)copyVal(info->device, 0, kAMDDeviceName) autorelease];
    else
    #endif
        deviceName = @"";
    
    NSString *serial;
    if (copyID && info->device && (serial = (id)copyID(info->device))) {
        serial = [[serial autorelease] lowercaseString];
    } else {
        serial = info->device ? [[NSString stringWithUTF8String:info->device->serial] lowercaseString] : @"";
    }
    
    NSNumber *productID = info->device ? [NSNumber numberWithUnsignedInt:info->device->productID] : (id)@"";
    NSString *productName = [productNameMap objectForKey:productID];
    if (!productName)
        productName = @"Unknown Mobile Device";
    
    BOOL connectedBeforeLaunch = nil != [devicesAttachedBeforeLaunch objectForKey:serial];
    if (connectedBeforeLaunch)
        [devicesAttachedBeforeLaunch removeObjectForKey:serial];
    
    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
        serial, @"serial",
        [NSNumber numberWithBool:connectedBeforeLaunch], @"connectedBeforeLaunch",
        deviceName, @"name",
        productName, @"product",
        productID, @"productID",
        #if defined(ISDEBUG) || defined(DEBUG)
        [NSNumber numberWithUnsignedInt:info->type], @"eventID",
        #endif
        nil];
    
    #if defined(ISDEBUG) || defined(DEBUG)
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"org.bergstrand.amds.debug"
        object:serial userInfo:d];
    #endif
    
    switch (info->type) {
        case kDeviceNotificationConnected:
            [connectedDevices setObject:d forKey:serial];
            [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"org.bergstrand.amds.connect"
                object:serial userInfo:d];
        break;
        
        case kDeviceNotificationDisconnected:
            [connectedDevices removeObjectForKey:serial];
            [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"org.bergstrand.amds.disconnect"
                object:serial userInfo:d];
        break;
        
        default:
        break;
    }
    
    } @catch(NSException *e) {}
    [pool drain];
}

static BOOL IsMassStorageDevice(io_object_t entry)
{
    io_iterator_t i;
    BOOL canMount = NO;
    kern_return_t kr = IORegistryEntryGetChildIterator(entry, kIOServicePlane, &i);
    if (0 == kr && 0 != i) {
        io_object_t iobj;
        while ((iobj = IOIteratorNext(i))) {
            // the iterator is for 1st generation children only, to get all descendants we have to go recursive
            if (IOObjectConformsTo(iobj, "IOUSBMassStorageClass") || IsMassStorageDevice(iobj)) {
                canMount = YES;
                IOObjectRelease(iobj);
                break;
            }
            
            IOObjectRelease(iobj);
        }
        
        IOObjectRelease(i);
     }
     return (canMount);
}

static NSMutableDictionary* FindAttachedDevices(void)
{
    NSMutableDictionary *devices = [NSMutableDictionary dictionary];
    io_iterator_t i;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(kIOUSBDeviceClassName), &i);
    if (0 == kr && 0 != i) {
        io_object_t iobj;
        while ((iobj = IOIteratorNext(i))) {
            
            NSDictionary *properties;
            IORegistryEntryCreateCFProperties(iobj, (CFMutableDictionaryRef*)&properties, kCFAllocatorDefault, 0);
            if (properties) {
                // XXX: hack!
                NSString *productName = [properties objectForKey:@"USB Product Name"];
                NSString *productID = [properties objectForKey:@"idProduct"];
                NSString *serial = [[properties objectForKey:@"USB Serial Number"] lowercaseString];
                
                if (productID && productName && (NSOrderedSame == [productName caseInsensitiveCompare:@"iPhone"]
                    || (NSOrderedSame == [productName caseInsensitiveCompare:@"iPod"]
                        && NO == IsMassStorageDevice(iobj)))) {
                            
                    NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:
                        productName, @"product",
                        serial, @"serial",
                        productID, @"productID",
                        nil];
                    
                    [devices setObject:d forKey:serial];
                }
                
                [properties release];
            }
            
            IOObjectRelease(iobj);
        }
        
        IOObjectRelease(i);
    }
    
    return (devices);
}

#endif // LP64
