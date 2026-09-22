#import <Foundation/Foundation.h>
#import <Preferences/PSListController.h>

@interface HKFPRootListController : PSListController
@end

@implementation HKFPRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

@end
