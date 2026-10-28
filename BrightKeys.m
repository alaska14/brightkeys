#import <Cocoa/Cocoa.h>
#import <IOKit/IOKitLib.h>

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

    // 3. Ensure LaunchAgent & Login Item are configured for silent boot persistence
    [self ensureLaunchAgent];
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

- (void)applyKeyRemapping {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/hidutil";
    task.arguments = @[
        @"property",
        @"--set",
        @"{\"UserKeyMapping\":["
          "{\"HIDKeyboardModifierMappingSrc\":51539607759,\"HIDKeyboardModifierMappingDst\":1095216660489}," // F5 Mic -> illumination_down
          "{\"HIDKeyboardModifierMappingSrc\":4294967451,\"HIDKeyboardModifierMappingDst\":1095216660488},"  // F6 Moon -> illumination_up
          "{\"HIDKeyboardModifierMappingSrc\":30064771134,\"HIDKeyboardModifierMappingDst\":1095216660489}," // F5 Raw -> illumination_down
          "{\"HIDKeyboardModifierMappingSrc\":30064771135,\"HIDKeyboardModifierMappingDst\":1095216660488}"  // F6 Raw -> illumination_up
        @"]}"
    ];
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) {}
}

- (void)removeKeyRemapping {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/hidutil";
    task.arguments = @[@"property", @"--set", @"{\"UserKeyMapping\":[]}"];
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) {}
}

- (void)ensureLaunchAgent {
    NSString *plistDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents"];
    NSString *plistPath = [plistDir stringByAppendingPathComponent:@"com.monolab.brightkeys.plist"];

    [[NSFileManager defaultManager] createDirectoryAtPath:plistDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *plistContent = [NSString stringWithFormat:
        @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        @"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
        @"<plist version=\"1.0\">\n"
        @"<dict>\n"
        @"    <key>Label</key>\n"
        @"    <string>com.monolab.brightkeys</string>\n"
        @"    <key>ProgramArguments</key>\n"
        @"    <array>\n"
        @"        <string>/Applications/BrightKeys.app/Contents/MacOS/BrightKeys</string>\n"
        @"    </array>\n"
        @"    <key>RunAtLoad</key>\n"
        @"    <true/>\n"
        @"    <key>KeepAlive</key>\n"
        @"    <false/>\n"
        @"</dict>\n"
        @"</plist>\n"];
    [plistContent writeToFile:plistPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
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
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
