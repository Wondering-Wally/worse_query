//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#include "worse_query.h"
#include "pathleak.h"

#include <CoreFoundation/CoreFoundation.h>

// Exists in libSecurity on iOS but is not in the public SDK headers.
typedef const struct __SecTask *SecTaskRef;
extern SecTaskRef SecTaskCreateFromSelf(CFAllocatorRef allocator);
extern CFTypeRef SecTaskCopyValueForEntitlement(SecTaskRef task, CFStringRef entitlement);
