TARGET := iphone:clang:14.5:14.0
ARCHS = arm64
include $(THEOS)/makefiles/common.mk
BUNDLE_NAME = HardKeyFixPrefs
HardKeyFixPrefs_FILES = HKFRootListController.m
HardKeyFixPrefs_FRAMEWORKS = UIKit
HardKeyFixPrefs_PRIVATE_FRAMEWORKS = Preferences
HardKeyFixPrefs_INSTALL_PATH = /Library/PreferenceBundles
HardKeyFixPrefs_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/bundle.mk

