#include "AmbientHardware.h"
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <dlfcn.h>
#include <math.h>
#include <stdint.h>

// ABI references: DarkModeBuddy / Apple IOHIDFamily. Loaded dynamically so an
// OS update removing these private symbols produces an unavailable state.
typedef CFTypeRef (*CopyService)(void);
typedef CFTypeRef (*CopyEvent)(CFTypeRef, int64_t, int32_t, int64_t);
typedef double (*GetValue)(CFTypeRef, int32_t);
static CopyService copyService;
static CopyEvent copyEvent;
static GetValue getValue;
static CFTypeRef sensor;
static int loaded;

void ambient_reset(void) {
    if (sensor) CFRelease(sensor);
    sensor = NULL;
}

double ambient_read_lux(void) {
    if (!loaded) {
        loaded = 1;
        void *bezel = dlopen("/System/Library/PrivateFrameworks/BezelServices.framework/BezelServices", RTLD_LAZY | RTLD_LOCAL);
        void *hid = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY | RTLD_LOCAL);
        if (bezel) copyService = (CopyService)dlsym(bezel, "ALCALSCopyALSServiceClient");
        if (hid) {
            copyEvent = (CopyEvent)dlsym(hid, "IOHIDServiceClientCopyEvent");
            getValue = (GetValue)dlsym(hid, "IOHIDEventGetFloatValue");
        }
    }
    if (!copyService || !copyEvent || !getValue) return -1;
    if (!sensor) sensor = copyService();
    if (!sensor) return -1;
    CFTypeRef event = copyEvent(sensor, 12, 0, 0);
    if (!event) { ambient_reset(); return -1; }
    double lux = getValue(event, 12 << 16);
    CFRelease(event);
    return isfinite(lux) && lux >= 0 ? lux : -1;
}

int ambient_lid_closed(void) {
    io_service_t root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"));
    if (!root) return 0;
    CFTypeRef value = IORegistryEntryCreateCFProperty(root, CFSTR("AppleClamshellState"), kCFAllocatorDefault, 0);
    IOObjectRelease(root);
    int closed = value && CFGetTypeID(value) == CFBooleanGetTypeID() && CFBooleanGetValue(value);
    if (value) CFRelease(value);
    return closed;
}
