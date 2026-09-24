THEOS_PACKAGE_SCHEME = roothide
TARGET := iphone:clang:14.5:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HardKeyFix

HardKeyFix_FILES = Tweak.x
HardKeyFix_CFLAGS = -fobjc-arc
HardKeyFix_FRAMEWORKS = UIKit AVFoundation MediaPlayer

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += hardkeyfixprefs

include $(THEOS_MAKE_PATH)/aggregate.mk




