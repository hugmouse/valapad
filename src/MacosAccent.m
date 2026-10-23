/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 Iaroslav Angliuster
 */

#import <AppKit/AppKit.h>

typedef void (*ValaPadAccentChangedCallback) (void);

static NSMutableArray *accent_observers = nil;

// dumped from NSColor.controlAccentColor
// also apparently macOS didn't change those since 2011?
static const int ACCENT_COLORS[8][2] = {
    { 0x989898, 0x8c8c8c },
    { 0xe0383e, 0xff5257 },
    { 0xf7821b, 0xf7821b },
    { 0xffc726, 0xffc600 },
    { 0x62ba46, 0x62ba46 },
    { 0x007aff, 0x007aff },
    { 0x953d96, 0xa550a7 },
    { 0xf74f9e, 0xf74f9e },
};

static int raw_accent_index (void) {
    NSNumber *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleAccentColor"];
    return value != nil ? value.intValue : 4;
}

static bool raw_prefers_dark (void) {
    NSString *style = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    return [style isEqualToString:@"Dark"];
}

int valapad_macos_accent_index (void) {
    @autoreleasepool {
        return raw_accent_index ();
    }
}

int valapad_macos_accent_rgb (void) {
    @autoreleasepool {
        int index = raw_accent_index ();
        if (index < -1 || index > 6) {
            index = 4;
        }
        return ACCENT_COLORS[index + 1][raw_prefers_dark () ? 1 : 0];
    }
}

int valapad_macos_prefers_dark (void) {
    @autoreleasepool {
        return raw_prefers_dark () ? 1 : 0;
    }
}

void valapad_macos_accent_observe (ValaPadAccentChangedCallback callback) {
    if (accent_observers != nil) {
        return;
    }

    accent_observers = [[NSMutableArray alloc] init];
    NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
    for (NSString *name in @[ @"AppleColorPreferencesChangedNotification",
                              @"AppleInterfaceThemeChangedNotification" ]) {
        [accent_observers addObject:
            [center addObserverForName:name
                                object:nil
                                 queue:nil
                            usingBlock:^(NSNotification *notification) {
                                callback ();
                            }]];
    }
}
