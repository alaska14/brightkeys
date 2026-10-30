#import <Cocoa/Cocoa.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hid/IOHIDProperties.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // 1. Single Instance Check: If already running, offer a frictionless modal to Keep Running or Quit
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleId) bundleId = @"com.monolab.brightkeys";

    NSArray<NSRunningApplication *> *instances = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleId];
    pid_t myPid = [[NSProcessInfo processInfo] processIdentifier];

    NSRunningApplication *existingInstance = nil;
    for (NSRunningApplication *app in instances) {
        if (app.processIdentifier != myPid) {
            existingInstance = app;
            break;
        }
    }

    if (existingInstance) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"bright keys. is Active";
        alert.informativeText = @"bright keys. is running silently in the background with zero menu bar clutter, keeping your F5 and F6 keyboard brightness keys restored.\n\nWould you like to keep it running or quit?";
        [alert addButtonWithTitle:@"Keep Running"];
        [alert addButtonWithTitle:@"Quit BrightKeys"];
        alert.alertStyle = NSAlertStyleInformational;

        [NSApp activateIgnoringOtherApps:YES];
        if ([alert runModal] == NSAlertSecondButtonReturn) {
            [existingInstance terminate];
            [self removeKeyRemapping];
            [self sendNotificationWithTitle:@"bright keys. Stopped" message:@"F5 and F6 restored to default Apple dictation and focus."];
        }
        [NSApp terminate:nil];
        return;
    }

    // 2. Apply Kernel Key Remapping
    [self applyKeyRemapping];

    // 3. Login item for silent boot persistence (legacy LaunchAgent removed to avoid double launch)
    [self removeLegacyLaunchAgent];
    [self ensureAutoStart];

    // 4. Watch for Sleep / Wake / Display changes to re-arm kernel mapping
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(systemDidWake:)
                                                               name:NSWorkspaceDidWakeNotification
                                                             object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(systemDidWake:)
                                                               name:NSWorkspaceScreensDidWakeNotification
                                                             object:nil];

    // 5. Friendly subtle notification on initial launch
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if (![defs boolForKey:@"hasShownWelcome"]) {
        [defs setBool:YES forKey:@"hasShownWelcome"];
        [self sendNotificationWithTitle:@"bright keys. Active"
                                message:@"F5 (Dim) & F6 (Brighten) active with 0% menu bar clutter."];
    }
}

- (void)systemDidWake:(NSNotification *)note {
    [self applyKeyRemapping];
}

#pragma mark - Kernel Key Remapping

// Our four mappings: F5 (Dictation/mic) & raw F5 -> keyboard illumination down,
// F6 (Do Not Disturb/moon) & raw F6 -> keyboard illumination up.
static NSArray<NSDictionary *> *BrightKeysMappings(void) {
    return @[
        @{@"HIDKeyboardModifierMappingSrc": @(0xC000000CFULL),  @"HIDKeyboardModifierMappingDst": @(0xFF00000009ULL)}, // F5 Mic  -> illumination_down
        @{@"HIDKeyboardModifierMappingSrc": @(0x10000009BULL),  @"HIDKeyboardModifierMappingDst": @(0xFF00000008ULL)}, // F6 Moon -> illumination_up
        @{@"HIDKeyboardModifierMappingSrc": @(0x70000003EULL),  @"HIDKeyboardModifierMappingDst": @(0xFF00000009ULL)}, // F5 Raw  -> illumination_down
        @{@"HIDKeyboardModifierMappingSrc": @(0x70000003FULL),  @"HIDKeyboardModifierMappingDst": @(0xFF00000008ULL)}, // F6 Raw  -> illumination_up
    ];
}

// Returns the user's existing UserKeyMapping entries minus any that use one of our source keys,
// so we never clobber remaps the user (or another tool) has set up.
static NSMutableArray *BrightKeysForeignMappings(IOHIDEventSystemClientRef client) {
    NSMutableArray *result = [NSMutableArray array];
    CFTypeRef current = IOHIDEventSystemClientCopyProperty(client, CFSTR(kIOHIDUserKeyUsageMapKey));
    if (current) {
        NSArray *arr = (__bridge_transfer NSArray *)current;
        if ([arr isKindOfClass:[NSArray class]]) {
            NSSet *ourSrcs = [NSSet setWithArray:[BrightKeysMappings() valueForKey:@"HIDKeyboardModifierMappingSrc"]];
            for (NSDictionary *entry in arr) {
                if (![entry isKindOfClass:[NSDictionary class]]) continue;
                if ([ourSrcs containsObject:entry[@"HIDKeyboardModifierMappingSrc"]]) continue;
                [result addObject:entry];
            }
        }
    }
    return result;
}

static void BrightKeysSetMapping(BOOL enabled) {
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault);
    if (!client) return;
    NSMutableArray *mapping = BrightKeysForeignMappings(client);
    if (enabled) [mapping addObjectsFromArray:BrightKeysMappings()];
    IOHIDEventSystemClientSetProperty(client, CFSTR(kIOHIDUserKeyUsageMapKey), (__bridge CFArrayRef)mapping);
    CFRelease(client);
}

- (void)applyKeyRemapping {
    BrightKeysSetMapping(YES);
}

- (void)removeKeyRemapping {
    BrightKeysSetMapping(NO);
}

- (void)removeLegacyLaunchAgent {
    // Older builds installed a LaunchAgent *and* a login item, which started BrightKeys twice
    // at login (the second copy showed the "Keep Running / Quit" dialog). The login item alone is enough.
    NSString *plistPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents/com.monolab.brightkeys.plist"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:plistPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:plistPath error:nil];
    }
}

- (void)ensureAutoStart {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if (![defs boolForKey:@"hasConfiguredAutoStart"]) {
        [defs setBool:YES forKey:@"hasConfiguredAutoStart"];
        NSString *appPath = [[NSBundle mainBundle] bundlePath];
        if (appPath && [appPath hasPrefix:@"/Applications"]) {
            NSString *script = [NSString stringWithFormat:
                @"tell application \"System Events\"\n"
                @"  if not (exists (login item \"BrightKeys\")) then\n"
                @"    make login item at end with properties {path:\"%@\", hidden:false}\n"
                @"  end if\n"
                @"end tell", appPath];
            NSAppleScript *as = [[NSAppleScript alloc] initWithSource:script];
            [as executeAndReturnError:nil];
        }
    }
}

- (void)sendNotificationWithTitle:(NSString *)title message:(NSString *)msg {
    NSString *script = [NSString stringWithFormat:@"display notification \"%@\" with title \"%@\"", msg, title];
    NSAppleScript *as = [[NSAppleScript alloc] initWithSource:script];
    [as executeAndReturnError:nil];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // `BrightKeys --remove-mapping` removes only BrightKeys' F5/F6 mappings and exits
        // (used by the Homebrew uninstall hook).
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "--remove-mapping") == 0) {
                BrightKeysSetMapping(NO);
                return 0;
            }
        }
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
