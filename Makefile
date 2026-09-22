include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HardKeyFix

HardKeyFix_FILES = Tweak.x
HardKeyFix_CFLAGS = -fobjc-arc
HardKeyFix_FRAMEWORKS = UIKit AVFoundation MediaPlayer

TARGET = iphone:clang:latest:14.0
ARCHS = arm64

include $(THEOS_MAKE_PATH)/tweak.mk
