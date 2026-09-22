THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = HardKeyFixPrefs

HardKeyFixPrefs_FILES = HKFPRootListController.m
HardKeyFixPrefs_FRAMEWORKS = UIKit
HardKeyFixPrefs_INSTALL_PATH = /Library/PreferenceBundles
HardKeyFixPrefs_CFLAGS = -fobjc-arc
HardKeyFixPrefs_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
