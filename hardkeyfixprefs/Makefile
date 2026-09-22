TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = HardKeyFixPrefs

HardKeyFixPrefs_FILES = HKFPRootListController.m
HardKeyFixPrefs_FRAMEWORKS = UIKit
HardKeyFixPrefs_PRIVATE_FRAMEWORKS = Preferences
HardKeyFixPrefs_INSTALL_PATH = /Library/PreferenceBundles
HardKeyFixPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
