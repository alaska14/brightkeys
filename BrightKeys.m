#import <Cocoa/Cocoa.h>
#import <IOKit/IOKitLib.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (assign, nonatomic) BOOL isEnabled;
@property (assign, nonatomic) BOOL launchAtLogin;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    if ([defs objectForKey:@"isEnabled"] == nil) {
        [defs setBool:YES forKey:@"isEnabled"];
    }
    if ([defs objectForKey:@"launchAtLogin"] == nil) {
        [defs setBool:YES forKey:@"launchAtLogin"];
    }
    self.isEnabled = [defs boolForKey:@"isEnabled"];
    self.launchAtLogin = [defs boolForKey:@"launchAtLogin"];

    [self setupStatusItem];
    if (self.isEnabled) {
        [self applyKeyRemapping];
    }
    [self updateLaunchAgent];

    // Reapply on wake from sleep or display changes
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(systemDidWake:)
                                                               name:NSWorkspaceDidWakeNotification
                                                             object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                           selector:@selector(systemDidWake:)
                                                               name:NSWorkspaceScreensDidWakeNotification
                                                             object:nil];
}

- (void)systemDidWake:(NSNotification *)note {
    if (self.isEnabled) {
        [self applyKeyRemapping];
    }
}

#pragma mark - Menu Bar Status Item

- (void)setupStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSImage *icon = [self renderMenuBarIconActive:self.isEnabled];
    self.statusItem.button.image = icon;
    self.statusItem.button.toolTip = @"BrightKeys · F5/F6 Keyboard Brightness";
    self.statusItem.button.target = self;
    self.statusItem.button.action = @selector(showMenu);
}

- (NSImage *)renderMenuBarIconActive:(BOOL)active {
    NSSize size = NSMakeSize(18, 14);
    NSImage *img = [[NSImage alloc] initWithSize:size];
    [img lockFocus];

    [[NSColor clearColor] set];
    NSRectFill(NSMakeRect(0, 0, size.width, size.height));

    NSColor *strokeCol = active ? [NSColor blackColor] : [NSColor grayColor];
    [strokeCol set];

    CGFloat strokeW = 1.35;
    CGFloat yBase = 2.2;
    CGFloat cx = size.width / 2.0;

    // Baseline: 3 rounded dashes
    CGFloat midW = 5.6;
    CGFloat sideW = 2.4;
    CGFloat gap = 1.8;

    // Left
    NSBezierPath *l = [NSBezierPath bezierPath];
    [l moveToPoint:NSMakePoint(cx - midW/2.0 - gap - sideW, yBase)];
    [l lineToPoint:NSMakePoint(cx - midW/2.0 - gap, yBase)];
    l.lineWidth = strokeW;
    l.lineCapStyle = NSLineCapStyleRound;
    [l stroke];

    // Mid
    NSBezierPath *m = [NSBezierPath bezierPath];
    [m moveToPoint:NSMakePoint(cx - midW/2.0, yBase)];
    [m lineToPoint:NSMakePoint(cx + midW/2.0, yBase)];
    m.lineWidth = strokeW;
    m.lineCapStyle = NSLineCapStyleRound;
    [m stroke];

    // Right
    NSBezierPath *r = [NSBezierPath bezierPath];
    [r moveToPoint:NSMakePoint(cx + midW/2.0 + gap, yBase)];
    [r lineToPoint:NSMakePoint(cx + midW/2.0 + gap + sideW, yBase)];
    r.lineWidth = strokeW;
    r.lineCapStyle = NSLineCapStyleRound;
    [r stroke];

    // 3 Rays
    CGFloat rIn = 3.6;
    CGFloat rOut = 8.2;
    CGFloat angles[3] = { 135.0, 90.0, 45.0 };

    for (int i = 0; i < 3; i++) {
        CGFloat rad = angles[i] * M_PI / 180.0;
        CGFloat x1 = cx + rIn * cos(rad);
        CGFloat y1 = yBase + rIn * sin(rad);
        CGFloat x2 = cx + rOut * cos(rad);
        CGFloat y2 = yBase + rOut * sin(rad);

        NSBezierPath *ray = [NSBezierPath bezierPath];
        [ray moveToPoint:NSMakePoint(x1, y1)];
        [ray lineToPoint:NSMakePoint(x2, y2)];
        ray.lineWidth = strokeW;
        ray.lineCapStyle = NSLineCapStyleRound;
        [ray stroke];
    }

    [img unlockFocus];
    [img setTemplate:YES];
    return img;
}

#pragma mark - Menu Building

- (void)showMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    menu.autoenablesItems = NO;

    // Header
    NSMenuItem *header = [[NSMenuItem alloc] initWithTitle:@"bright keys.  v1.0" action:nil keyEquivalent:@""];
    header.enabled = NO;
    NSFont *hFont = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    if (hFont) {
        header.attributedTitle = [[NSAttributedString alloc] initWithString:@"bright keys.  v1.0"
                                                                attributes:@{NSFontAttributeName: hFont}];
    }
    [menu addItem:header];

    // Subtitle
    NSMenuItem *sub = [[NSMenuItem alloc] initWithTitle:@"F5: Brightness Down · F6: Brightness Up" action:nil keyEquivalent:@""];
    sub.enabled = NO;
    [menu addItem:sub];
    [menu addItem:[NSMenuItem separatorItem]];

    // Active Toggle
    NSString *statusTitle = self.isEnabled ? @"✓  F5 / F6 Brightness Remap: Active" : @"    F5 / F6 Brightness Remap: Paused";
    NSMenuItem *toggleItem = [[NSMenuItem alloc] initWithTitle:statusTitle action:@selector(toggleEnabled:) keyEquivalent:@""];
    toggleItem.target = self;
    [menu addItem:toggleItem];

    // Launch at login
    NSString *loginTitle = self.launchAtLogin ? @"✓  Launch at Login" : @"    Launch at Login";
    NSMenuItem *loginItem = [[NSMenuItem alloc] initWithTitle:loginTitle action:@selector(toggleLaunchAtLogin:) keyEquivalent:@""];
    loginItem.target = self;
    [menu addItem:loginItem];

    [menu addItem:[NSMenuItem separatorItem]];

    // About
    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:@"About BrightKeys" action:@selector(showAbout) keyEquivalent:@""];
    aboutItem.target = self;
    [menu addItem:aboutItem];

    // Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit BrightKeys" action:@selector(quitApp) keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];

    self.statusItem.menu = menu;
    [self.statusItem.button performClick:nil];
    self.statusItem.menu = nil;
}

- (void)toggleEnabled:(id)sender {
    self.isEnabled = !self.isEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:self.isEnabled forKey:@"isEnabled"];
    if (self.isEnabled) {
        [self applyKeyRemapping];
    } else {
        [self removeKeyRemapping];
    }
    self.statusItem.button.image = [self renderMenuBarIconActive:self.isEnabled];
}

- (void)toggleLaunchAtLogin:(id)sender {
    self.launchAtLogin = !self.launchAtLogin;
    [[NSUserDefaults standardUserDefaults] setBool:self.launchAtLogin forKey:@"launchAtLogin"];
    [self updateLaunchAgent];
}

- (void)showAbout {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"bright keys. 1.0 by MonoLab";
    alert.informativeText = @"Restores native keyboard backlight control to F5 and F6 keys on Apple Silicon MacBooks.\n\n"
                            "• 0% CPU overhead\n"
                            "• 0 MB RAM footprint\n"
                            "• Pure macOS kernel HID remapping\n\n"
                            "Crafted by MonoLab.";
    [alert runModal];
}

- (void)quitApp {
    [NSApp terminate:nil];
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

- (void)updateLaunchAgent {
    NSString *plistDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents"];
    NSString *plistPath = [plistDir stringByAppendingPathComponent:@"com.monolab.brightkeys.plist"];

    if (self.launchAtLogin) {
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
    } else {
        [[NSFileManager defaultManager] removeItemAtPath:plistPath error:nil];
    }
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
