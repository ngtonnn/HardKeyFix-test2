THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HardKeyFix

HardKeyFix_FILES = Tweak.x
HardKeyFix_CFLAGS = -fobjc-arc
HardKeyFix_FRAMEWORKS = UIKit AVFoundation MediaPlayer

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += hardkeyfixprefs

include $(THEOS_MAKE_PATH)/aggregate.mk

