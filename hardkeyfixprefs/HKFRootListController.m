#import <Foundation/Foundation.h>
#import "HKFRootListController.h"

@implementation HKFRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

@end
