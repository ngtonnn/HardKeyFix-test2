#import <Foundation/Foundation.h>
#import "HKFRootListController.h"
#include <spawn.h>

@implementation HKFRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)respring {
    pid_t pid;
    const char* args[] = {"killall", "-9", "SpringBoard", NULL};
    if (access("/var/jb/usr/bin/killall", F_OK) == 0) {
        posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char* const*)args, NULL);
    } else if (access("/usr/bin/killall", F_OK) == 0) {
        posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char* const*)args, NULL);
    }
}

@end
