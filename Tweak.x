#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>
#import <math.h>

@interface SBLockScreenManager : NSObject
+ (id)sharedInstance;
- (void)lockUIFromSource:(int)arg1 withOptions:(id)arg2;
@end

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-variable"

@interface SpringBoard : UIApplication
- (id)screenshotManager;
- (UIWindow *)statusBarWindow;
- (void)_simulateLockButtonPress;
@end

@interface SBScreenshotManager : NSObject
- (void)saveScreenshotsWithCompletion:(id)completion;
@end

@interface SBScreenShotter : NSObject
+ (instancetype)sharedInstance;
- (void)saveScreenshot:(BOOL)saveToPhotos;
@end

typedef NS_ENUM(NSInteger, HKFDockEdge) {
    HKFDockEdgeLeft = 0,
    HKFDockEdgeRight,
    HKFDockEdgeTop
};

static BOOL prefs_enableSecondButton = NO;
static NSInteger prefs_topNumberRotation = 1; // 0 = 0deg, 1 = +90deg (Landscape Left), 2 = -90deg (Landscape Right)
static CGFloat prefs_idleTimeout = 0.5;

// Main button (Button 1)
static CGFloat prefs_idleOpacity = 0.3;
static CGFloat prefs_width = 32.0;
static CGFloat prefs_length = 100.0;
static CGFloat prefs_edgePadding = 0.0;

// Second button (Button 2)
static CGFloat prefs_idleOpacity2 = 0.3;
static CGFloat prefs_width2 = 32.0;
static CGFloat prefs_length2 = 100.0;
static CGFloat prefs_edgePadding2 = 0.0;

static void loadPrefs() {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.yourname.hardkeyfix"];
    if (prefs) {
        if ([prefs objectForKey:@"enableSecondButton"]) prefs_enableSecondButton = [prefs boolForKey:@"enableSecondButton"];
        if ([prefs objectForKey:@"topNumberRotation"]) prefs_topNumberRotation = [prefs integerForKey:@"topNumberRotation"];
        
        if ([prefs objectForKey:@"idleOpacity"]) prefs_idleOpacity = [prefs doubleForKey:@"idleOpacity"];
        if ([prefs objectForKey:@"width"]) prefs_width = [prefs doubleForKey:@"width"];
        if ([prefs objectForKey:@"length"]) prefs_length = [prefs doubleForKey:@"length"];
        if ([prefs objectForKey:@"edgePadding"]) prefs_edgePadding = [prefs doubleForKey:@"edgePadding"];
        
        if ([prefs objectForKey:@"idleOpacity2"]) prefs_idleOpacity2 = [prefs doubleForKey:@"idleOpacity2"];
        if ([prefs objectForKey:@"width2"]) prefs_width2 = [prefs doubleForKey:@"width2"];
        if ([prefs objectForKey:@"length2"]) prefs_length2 = [prefs doubleForKey:@"length2"];
        if ([prefs objectForKey:@"edgePadding2"]) prefs_edgePadding2 = [prefs doubleForKey:@"edgePadding2"];
    }
}

@interface HKFDialView : UIView
@property (nonatomic, strong) UIView *rulerView;
@property (nonatomic, assign) HKFDockEdge dockEdge;
@property (nonatomic, assign) NSInteger numberRotation;
- (instancetype)initWithFrame:(CGRect)frame edge:(HKFDockEdge)edge numberRotation:(NSInteger)rotation;
- (void)setVolume:(float)volume;
@end

@implementation HKFDialView
@synthesize rulerView = _rulerView;
@synthesize dockEdge = _dockEdge;
@synthesize numberRotation = _numberRotation;

- (instancetype)initWithFrame:(CGRect)frame edge:(HKFDockEdge)edge numberRotation:(NSInteger)rotation {
    self = [super initWithFrame:frame];
    if (self) {
        _dockEdge = edge;
        _numberRotation = rotation;
        
        self.layer.cornerRadius = 16.0;
        self.clipsToBounds = YES;
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
        
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = self.bounds;
        [self addSubview:blurView];
        
        BOOL isTop = (edge == HKFDockEdgeTop);
        BOOL isLeft = (edge == HKFDockEdgeLeft);
        
        if (isTop) {
            _rulerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 600, frame.size.height)];
        } else {
            _rulerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 600)];
        }
        [self addSubview:_rulerView];
        
        for (int i = 0; i <= 40; i++) {
            BOOL isMajor = (i % 10 == 0);
            UIView *tick = [[UIView alloc] init];
            tick.backgroundColor = isMajor ? [UIColor whiteColor] : [UIColor colorWithWhite:0.6 alpha:1.0];
            tick.layer.cornerRadius = 1.0;
            
            UILabel *lbl = nil;
            if (isMajor) {
                lbl = [[UILabel alloc] init];
                int volNum = isTop ? (i * 100 / 40) : (100 - (i * 100 / 40));
                lbl.text = [NSString stringWithFormat:@"%d", volNum];
                lbl.textColor = [UIColor whiteColor];
                lbl.textAlignment = NSTextAlignmentCenter;
            }
            
            if (isTop) {
                // ĐỈNH: Vạch chia ở mép trên (rìa điện thoại: y = 6..24), Số ở phía dưới (phía trong màn hình)
                tick.frame = CGRectMake(i * 15, 6, 2, isMajor ? 18 : 12);
                if (isMajor) {
                    lbl.bounds = CGRectMake(0, 0, 32, 16);
                    lbl.center = CGPointMake(i * 15, 39);
                    lbl.font = [UIFont boldSystemFontOfSize:11];
                    if (rotation == 1) {
                        lbl.transform = CGAffineTransformMakeRotation(M_PI_2);
                    } else if (rotation == 2) {
                        lbl.transform = CGAffineTransformMakeRotation(-M_PI_2);
                    }
                }
            } else if (isLeft) {
                // MÉP TRÁI: Vạch chia ở mép trái (rìa điện thoại: x = 6..24), Số ở phía trong bên phải (x = 24..46)
                tick.frame = CGRectMake(6, i * 15, isMajor ? 18 : 12, 2);
                if (isMajor) {
                    lbl.frame = CGRectMake(24, i * 15 - 9, 22, 18);
                    lbl.font = [UIFont boldSystemFontOfSize:10];
                }
            } else {
                // MÉP PHẢI: Vạch chia ở mép phải (rìa điện thoại: x = 24..42), Số ở phía trong bên trái (x = 2..24)
                tick.frame = CGRectMake(isMajor ? (48 - 6 - 18) : (48 - 6 - 12), i * 15, isMajor ? 18 : 12, 2);
                if (isMajor) {
                    lbl.frame = CGRectMake(2, i * 15 - 9, 22, 18);
                    lbl.font = [UIFont boldSystemFontOfSize:10];
                }
            }
            
            [_rulerView addSubview:tick];
            if (isMajor) {
                [_rulerView addSubview:lbl];
            }
        }
        
        UIView *marker = [[UIView alloc] init];
        marker.backgroundColor = [UIColor systemYellowColor];
        marker.layer.cornerRadius = 1.0;
        marker.layer.shadowColor = [UIColor blackColor].CGColor;
        marker.layer.shadowOffset = CGSizeZero;
        marker.layer.shadowOpacity = 1.0;
        marker.layer.shadowRadius = 2.0;
        
        if (isTop) {
            marker.frame = CGRectMake((frame.size.width - 2) / 2.0, 4, 2, 22);
        } else if (isLeft) {
            marker.frame = CGRectMake(4, (frame.size.height - 2) / 2.0, 22, 2);
        } else {
            marker.frame = CGRectMake(22, (frame.size.height - 2) / 2.0, 22, 2);
        }
        [self addSubview:marker];
    }
    return self;
}

- (void)setVolume:(float)volume {
    if (_dockEdge == HKFDockEdgeTop) {
        CGFloat centerOffset = self.bounds.size.width / 2.0;
        CGFloat tx = centerOffset - (volume * 600.0);
        _rulerView.transform = CGAffineTransformMakeTranslation(tx, 0);
    } else {
        CGFloat centerOffset = self.bounds.size.height / 2.0;
        CGFloat ty = centerOffset - ((1.0 - volume) * 600.0);
        _rulerView.transform = CGAffineTransformMakeTranslation(0, ty);
    }
}
@end

%hook SBVolumeControl
- (void)presentVolumeHUDWithVolume:(float)arg1 {}
- (void)_presentVolumeHUDWithVolume:(float)arg1 {}
%end

@interface HKFButtonView : UIView
@end

@implementation HKFButtonView
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGRect hitRect = CGRectInset(self.bounds, -12, -8);
    return CGRectContainsPoint(hitRect, point);
}
@end

@interface HKFFloatingWindow : UIWindow
@end

@implementation HKFFloatingWindow
- (BOOL)_canBecomeKeyWindow { return NO; }
- (BOOL)_canAffectStatusBarAppearance { return NO; }

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || !self.userInteractionEnabled) return NO;
    if (CGRectContainsPoint(self.bounds, point)) return YES;
    
    UIView *rootView = self.rootViewController.view;
    for (UIView *sub in rootView.subviews) {
        if ([sub isKindOfClass:[HKFDialView class]] && !sub.hidden && sub.alpha > 0.01) {
            CGPoint p = [self convertPoint:point toView:sub];
            if ([sub pointInside:p withEvent:event]) return YES;
        }
    }
    return NO;
}
@end

@interface HKFButtonItem : NSObject
@property (nonatomic, assign) NSInteger buttonIndex;
@property (nonatomic, strong) HKFFloatingWindow *floatingWindow;
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) HKFDockEdge currentEdge;

- (instancetype)initWithIndex:(NSInteger)index scene:(UIWindowScene *)scene;
- (void)updateConfig;
- (void)updateShapeForEdge:(HKFDockEdge)edge;
- (void)savePosition;
- (void)wakeUp;
- (void)idleTimerFired;
- (void)resetIdleTimer;
- (void)dismissDialView;
@end

@interface HKFFloatingManager : NSObject
@property (nonatomic, strong) UISlider *volumeSlider;
@property (nonatomic, strong) HKFButtonItem *button1;
@property (nonatomic, strong) HKFButtonItem *button2;
+ (instancetype)sharedInstance;
- (void)setup;
- (void)reloadConfig;
- (void)updateScene:(UIWindowScene *)scene;
@end

@implementation HKFButtonItem {
    HKFButtonView *_buttonView;
    UIView *_visualContainer;
    UIVisualEffectView *_blurView;
    UIView *_innerRing;
    UIView *_centerDot;
    
    NSTimer *_idleTimer;
    NSTimer *_dialDismissTimer;
    BOOL _isIdle;
    BOOL _isPositionUnlocked;
    
    float _currentVolume;
    CGFloat _lastPanCoord;
    int _lastHapticStep;
    HKFDialView *_dialView;
    
    UIImpactFeedbackGenerator *_lightFeedback;
    UIImpactFeedbackGenerator *_heavyFeedback;
    UIImpactFeedbackGenerator *_mediumFeedback;
    
    CGPoint _dragStartCenter;
}

- (CGFloat)_prefIdleOpacity {
    return (_buttonIndex == 1) ? prefs_idleOpacity : prefs_idleOpacity2;
}

- (CGFloat)_prefWidth {
    return (_buttonIndex == 1) ? prefs_width : prefs_width2;
}

- (CGFloat)_prefLength {
    return (_buttonIndex == 1) ? prefs_length : prefs_length2;
}

- (CGFloat)_prefEdgePadding {
    return (_buttonIndex == 1) ? prefs_edgePadding : prefs_edgePadding2;
}

- (void)_applyDockedCenter {
    CGFloat W = [UIScreen mainScreen].bounds.size.width;
    CGFloat H = [UIScreen mainScreen].bounds.size.height;
    CGFloat w = [self _prefWidth];
    CGFloat len = [self _prefLength];
    CGFloat pad = [self _prefEdgePadding];
    CGPoint center = self.floatingWindow.center;
    
    if (_currentEdge == HKFDockEdgeTop) {
        center.y = (w / 2.0) + pad;
        CGFloat halfLen = len / 2.0;
        if (center.x < halfLen) center.x = halfLen;
        if (center.x > W - halfLen) center.x = W - halfLen;
    } else if (_currentEdge == HKFDockEdgeLeft) {
        center.x = (w / 2.0) + pad;
        if (center.y < 60.0) center.y = 60.0;
        if (center.y > H - 50.0) center.y = H - 50.0;
    } else {
        center.x = W - ((w / 2.0) + pad);
        if (center.y < 60.0) center.y = 60.0;
        if (center.y > H - 50.0) center.y = H - 50.0;
    }
    self.floatingWindow.center = center;
}

- (instancetype)initWithIndex:(NSInteger)index scene:(UIWindowScene *)scene {
    self = [super init];
    if (self) {
        _buttonIndex = index;
        _isEnabled = (index == 1) ? YES : prefs_enableSecondButton;
        _currentEdge = (index == 1) ? HKFDockEdgeRight : HKFDockEdgeTop;
        
        if (scene) {
            self.floatingWindow = [[HKFFloatingWindow alloc] initWithWindowScene:scene];
        } else {
            self.floatingWindow = [[HKFFloatingWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
        self.floatingWindow.windowLevel = 10000005.0 + index;
        self.floatingWindow.backgroundColor = [UIColor clearColor];
        self.floatingWindow.userInteractionEnabled = YES;
        self.floatingWindow.hidden = !_isEnabled;
        self.floatingWindow.clipsToBounds = NO;
        
        UIViewController *rootVC = [UIViewController new];
        rootVC.view.backgroundColor = [UIColor clearColor];
        rootVC.view.clipsToBounds = NO;
        self.floatingWindow.rootViewController = rootVC;
        
        _lightFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        _heavyFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        _mediumFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        
        _buttonView = [[HKFButtonView alloc] initWithFrame:CGRectZero];
        _buttonView.backgroundColor = [UIColor clearColor];
        _buttonView.userInteractionEnabled = YES;
        _buttonView.alpha = 1.0;
        
        _visualContainer = [[UIView alloc] initWithFrame:CGRectZero];
        _visualContainer.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
        _visualContainer.layer.masksToBounds = NO;
        _visualContainer.layer.borderWidth = 1.0;
        _visualContainer.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.1].CGColor;
        _visualContainer.userInteractionEnabled = NO;
        
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        _blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        _blurView.clipsToBounds = YES;
        _blurView.userInteractionEnabled = NO;
        [_visualContainer addSubview:_blurView];
        
        _innerRing = [[UIView alloc] init];
        _innerRing.layer.borderWidth = 1.5;
        _innerRing.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.4].CGColor;
        _innerRing.userInteractionEnabled = NO;
        [_visualContainer addSubview:_innerRing];
        
        _centerDot = [[UIView alloc] init];
        _centerDot.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.7];
        _centerDot.userInteractionEnabled = NO;
        [_visualContainer addSubview:_centerDot];
        
        [_buttonView addSubview:_visualContainer];
        [rootVC.view addSubview:_buttonView];
        
        CGFloat W = [UIScreen mainScreen].bounds.size.width;
        CGFloat H = [UIScreen mainScreen].bounds.size.height;
        CGFloat w = [self _prefWidth];
        CGFloat len = [self _prefLength];
        CGFloat pad = [self _prefEdgePadding];
        
        NSMutableDictionary *posDict = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/SpringBoard/HardKeyFixPosition.plist"];
        
        NSString *edgeKey = (_buttonIndex == 1) ? @"savedEdge" : @"savedEdge2";
        NSString *yKey = (_buttonIndex == 1) ? @"savedY" : @"savedY2";
        NSString *xKey = (_buttonIndex == 1) ? @"savedX" : @"savedX2";
        
        NSInteger savedEdge = (_buttonIndex == 1) ? HKFDockEdgeRight : HKFDockEdgeTop;
        CGFloat savedY = (_buttonIndex == 1) ? (H / 2.0) : ((w / 2.0) + pad);
        CGFloat savedX = (_buttonIndex == 1) ? (W - ((w / 2.0) + pad)) : (W / 2.0);
        
        if (posDict) {
            if (posDict[edgeKey]) savedEdge = [posDict[edgeKey] integerValue];
            if (posDict[yKey]) savedY = [posDict[yKey] floatValue];
            if (posDict[xKey]) savedX = [posDict[xKey] floatValue];
        }
        
        _currentEdge = (HKFDockEdge)savedEdge;
        [self updateShapeForEdge:_currentEdge];
        
        if (_currentEdge == HKFDockEdgeTop) {
            CGFloat halfLen = len / 2.0;
            if (savedX < halfLen) savedX = halfLen;
            if (savedX > W - halfLen) savedX = W - halfLen;
            self.floatingWindow.center = CGPointMake(savedX, (w / 2.0) + pad);
        } else if (_currentEdge == HKFDockEdgeLeft) {
            CGFloat edgeOffset = (w / 2.0) + pad;
            self.floatingWindow.center = CGPointMake(edgeOffset, savedY);
        } else {
            CGFloat edgeOffset = (w / 2.0) + pad;
            self.floatingWindow.center = CGPointMake(W - edgeOffset, savedY);
        }
        
        _visualContainer.alpha = [self _prefIdleOpacity];
        _buttonView.alpha = 1.0;
        _isIdle = YES;
        
        UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleDoubleTap:)];
        tapGR.numberOfTapsRequired = 2;
        tapGR.delaysTouchesBegan = NO;
        tapGR.delaysTouchesEnded = NO;
        [_buttonView addGestureRecognizer:tapGR];

        UITapGestureRecognizer *tripleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleTripleTap:)];
        tripleTapGR.numberOfTapsRequired = 3;
        tripleTapGR.delaysTouchesBegan = NO;
        tripleTapGR.delaysTouchesEnded = NO;
        [_buttonView addGestureRecognizer:tripleTapGR];
        [tapGR requireGestureRecognizerToFail:tripleTapGR];

        UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handleVolumePan:)];
        panGR.delaysTouchesBegan = NO;
        panGR.delaysTouchesEnded = NO;
        [_buttonView addGestureRecognizer:panGR];

        UILongPressGestureRecognizer *holdToLockGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_handleHoldToLock:)];
        holdToLockGR.minimumPressDuration = 0.4;
        holdToLockGR.delaysTouchesBegan = NO;
        holdToLockGR.delaysTouchesEnded = NO;
        [_buttonView addGestureRecognizer:holdToLockGR];
        
        if (_isEnabled) {
            self.floatingWindow.hidden = NO;
            [self resetIdleTimer];
        }
    }
    return self;
}

- (void)updateShapeForEdge:(HKFDockEdge)edge {
    _currentEdge = edge;
    
    CGFloat w = [self _prefWidth];
    CGFloat len = [self _prefLength];
    CGSize newSize;
    if (edge == HKFDockEdgeTop) {
        newSize = CGSizeMake(len, w);
    } else {
        newSize = CGSizeMake(w, len);
    }
    
    self.floatingWindow.bounds = CGRectMake(0, 0, newSize.width, newSize.height);
    _buttonView.frame = self.floatingWindow.bounds;
    
    CGFloat cornerRadius = MIN(newSize.width, newSize.height) / 2.0;
    _visualContainer.frame = _buttonView.bounds;
    _visualContainer.layer.cornerRadius = cornerRadius;
    _blurView.frame = _visualContainer.bounds;
    _blurView.layer.cornerRadius = cornerRadius;
    
    _innerRing.frame = CGRectInset(_visualContainer.bounds, 4, 4);
    _innerRing.layer.cornerRadius = MAX((cornerRadius - 4.0), 0.0);
    
    CGFloat dotLength = len * 0.4;
    if (edge == HKFDockEdgeTop) {
        _centerDot.frame = CGRectMake(newSize.width/2.0 - (dotLength/2.0), newSize.height/2.0 - 2, dotLength, 4);
    } else {
        _centerDot.frame = CGRectMake(newSize.width/2.0 - 2, newSize.height/2.0 - (dotLength/2.0), 4, dotLength);
    }
    _centerDot.layer.cornerRadius = 2.0;
}

- (void)updateConfig {
    if (_buttonIndex == 2) {
        _isEnabled = prefs_enableSecondButton;
        self.floatingWindow.hidden = !_isEnabled;
        if (!_isEnabled) {
            [_idleTimer invalidate];
            _idleTimer = nil;
            [_dialDismissTimer invalidate];
            _dialDismissTimer = nil;
            if (_dialView) {
                [_dialView removeFromSuperview];
                _dialView = nil;
            }
            return;
        }
    }
    if (_dialView && _dialView.numberRotation != prefs_topNumberRotation) {
        [_dialView removeFromSuperview];
        _dialView = nil;
    }
    [self updateShapeForEdge:_currentEdge];
    [self _applyDockedCenter];
    if (_isIdle) {
        _visualContainer.alpha = [self _prefIdleOpacity];
    }
}

- (void)savePosition {
    NSString *path = @"/var/mobile/Library/SpringBoard/HardKeyFixPosition.plist";
    NSMutableDictionary *stateDict = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
    
    NSString *edgeKey = (_buttonIndex == 1) ? @"savedEdge" : @"savedEdge2";
    NSString *yKey = (_buttonIndex == 1) ? @"savedY" : @"savedY2";
    NSString *xKey = (_buttonIndex == 1) ? @"savedX" : @"savedX2";
    
    [stateDict setObject:@(_currentEdge) forKey:edgeKey];
    [stateDict setObject:@(self.floatingWindow.center.y) forKey:yKey];
    [stateDict setObject:@(self.floatingWindow.center.x) forKey:xKey];
    [stateDict writeToFile:path atomically:YES];
}

- (void)resetIdleTimer {
    [_idleTimer invalidate];
    _idleTimer = [NSTimer scheduledTimerWithTimeInterval:prefs_idleTimeout target:self selector:@selector(idleTimerFired) userInfo:nil repeats:NO];
}

- (void)idleTimerFired {
    [_idleTimer invalidate];
    _idleTimer = nil;
    if (_isIdle) return;
    _isIdle = YES;
    
    [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        _visualContainer.alpha = [self _prefIdleOpacity];
        [self _applyDockedCenter];
    } completion:nil];
}

- (void)wakeUp {
    [_idleTimer invalidate];
    _idleTimer = nil;
    if (!_isIdle) return;
    _isIdle = NO;
    
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        _visualContainer.alpha = 1.0;
    } completion:nil];
}

- (void)dismissDialView {
    [_dialDismissTimer invalidate];
    _dialDismissTimer = nil;
    
    [_dialView.layer removeAllAnimations];
    [_visualContainer.layer removeAllAnimations];
    
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);
        _dialView.alpha = 0.0;
        _visualContainer.alpha = 1.0;
    } completion:^(BOOL finished){
        _dialView.alpha = 0.0;
        _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    }];
    
    [self resetIdleTimer];
}

- (void)_handleTripleTap:(UITapGestureRecognizer *)gr {
    _isPositionUnlocked = !_isPositionUnlocked;
    [_mediumFeedback impactOccurred];
    
    if (_isPositionUnlocked) {
        _innerRing.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        self.floatingWindow.transform = CGAffineTransformMakeScale(1.1, 1.1);
    } else {
        _innerRing.backgroundColor = [UIColor clearColor];
        self.floatingWindow.transform = CGAffineTransformIdentity;
        [self savePosition];
    }
}

- (void)_handleHoldToLock:(UILongPressGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan) {
        [_heavyFeedback impactOccurred];
        
        if ([(SpringBoard *)[UIApplication sharedApplication] respondsToSelector:@selector(_simulateLockButtonPress)]) {
            [(SpringBoard *)[UIApplication sharedApplication] _simulateLockButtonPress];
        } else {
            Class lockManagerClass = objc_getClass("SBLockScreenManager");
            if (lockManagerClass && [lockManagerClass respondsToSelector:@selector(sharedInstance)]) {
                id manager = [lockManagerClass sharedInstance];
                if ([manager respondsToSelector:@selector(lockUIFromSource:withOptions:)]) {
                    [manager lockUIFromSource:1 withOptions:nil];
                }
            }
        }
    }
}

- (void)_handleDoubleTap:(UITapGestureRecognizer *)gr {
    (void)gr;
    [self resetIdleTimer];
    self.floatingWindow.hidden = YES;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
        if ([sb respondsToSelector:@selector(screenshotManager)]) {
            id manager = [sb screenshotManager];
            if (manager && [manager respondsToSelector:@selector(saveScreenshotsWithCompletion:)]) {
                [manager saveScreenshotsWithCompletion:nil];
            }
        } else {
            Class shotterClass = objc_getClass("SBScreenShotter");
            if (shotterClass && [shotterClass respondsToSelector:@selector(sharedInstance)]) {
                [[shotterClass sharedInstance] saveScreenshot:YES];
            }
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.isEnabled) {
                self.floatingWindow.hidden = NO;
            }
        });
    });
}

- (void)_handleVolumePan:(UIPanGestureRecognizer *)gr {
    if (_isPositionUnlocked) {
        [self _handlePositionPan:gr];
        return;
    }
    
    UISlider *slider = [HKFFloatingManager sharedInstance].volumeSlider;
    if (!slider) return;
    CGPoint location = [gr locationInView:nil]; 

    if (gr.state == UIGestureRecognizerStateBegan) {
        [self wakeUp];
        [_dialDismissTimer invalidate];
        _dialDismissTimer = nil;
        
        _lastPanCoord = (_currentEdge == HKFDockEdgeTop) ? location.x : location.y;
        _currentVolume = slider.value;
        _lastHapticStep = (int)(_currentVolume * 16.0);
        
        CGRect dialFrame;
        if (_currentEdge == HKFDockEdgeTop) {
            dialFrame = CGRectMake(0, 0, 260, 56);
        } else {
            dialFrame = CGRectMake(0, 0, 48, 260);
        }
        
        if (!_dialView || _dialView.dockEdge != _currentEdge || _dialView.numberRotation != prefs_topNumberRotation) {
            [_dialView removeFromSuperview];
            _dialView = [[HKFDialView alloc] initWithFrame:dialFrame edge:_currentEdge numberRotation:prefs_topNumberRotation];
            _dialView.userInteractionEnabled = NO;
            [self.floatingWindow.rootViewController.view addSubview:_dialView];
        } else {
            [self.floatingWindow.rootViewController.view bringSubviewToFront:_dialView];
        }
        
        _dialView.transform = CGAffineTransformIdentity;
        if (_currentEdge == HKFDockEdgeTop) {
            _dialView.layer.anchorPoint = CGPointMake(0.5, 0.0);
            _dialView.frame = CGRectMake((_buttonView.bounds.size.width - 260) / 2.0, _buttonView.bounds.size.height + 4, 260, 56);
        } else if (_currentEdge == HKFDockEdgeLeft) {
            _dialView.layer.anchorPoint = CGPointMake(0.0, 0.5);
            _dialView.frame = CGRectMake(0, (_buttonView.bounds.size.height - 260) / 2.0, 48, 260);
        } else {
            _dialView.layer.anchorPoint = CGPointMake(1.0, 0.5);
            _dialView.frame = CGRectMake(_buttonView.bounds.size.width - 48, (_buttonView.bounds.size.height - 260) / 2.0, 48, 260);
        }

        [_dialView setVolume:_currentVolume];
        
        _dialView.alpha = 0.0;
        _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);
        
        [_dialView.layer removeAllAnimations];
        [_visualContainer.layer removeAllAnimations];
        
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
            _dialView.transform = CGAffineTransformIdentity;
            _dialView.alpha = 1.0;
        } completion:nil];
        
        [_heavyFeedback prepare];
        [_lightFeedback prepare];
        [_heavyFeedback impactOccurred];
        
        _dialDismissTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(dismissDialView) userInfo:nil repeats:NO];
    } 
    else if (gr.state == UIGestureRecognizerStateChanged) {
        [_dialDismissTimer invalidate];
        _dialDismissTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(dismissDialView) userInfo:nil repeats:NO];
        
        CGFloat currentCoord = (_currentEdge == HKFDockEdgeTop) ? location.x : location.y;
        CGFloat delta = currentCoord - _lastPanCoord; 
        _lastPanCoord = currentCoord;
        
        CGFloat vel = (_currentEdge == HKFDockEdgeTop) ? [gr velocityInView:nil].x : [gr velocityInView:nil].y;
        CGFloat speedMultiplier = 1.0 + MIN(fabs(vel) / 500.0, 3.0);
        
        float volumeChange;
        if (_currentEdge == HKFDockEdgeTop) {
            volumeChange = (delta / 150.0) * speedMultiplier;
        } else {
            volumeChange = (-delta / 150.0) * speedMultiplier;
        }
        
        _currentVolume += volumeChange;
        _currentVolume = MAX(0.0f, MIN(1.0f, _currentVolume));
        
        [_dialView setVolume:_currentVolume];
        
        [slider setValue:_currentVolume animated:NO];
        [slider sendActionsForControlEvents:UIControlEventValueChanged];
        
        int currentStep = (int)(_currentVolume * 16.0);
        if (currentStep != _lastHapticStep) {
            _lastHapticStep = currentStep;
            [_lightFeedback impactOccurred];
            [_lightFeedback prepare];
        }
    }
    else {
        [slider sendActionsForControlEvents:UIControlEventTouchUpInside];
        [self dismissDialView];
    }
}

- (void)_handlePositionPan:(UIPanGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan) {
        [self dismissDialView];
        [self wakeUp];
        _dragStartCenter = self.floatingWindow.center;
        
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
            self.floatingWindow.transform = CGAffineTransformMakeScale(1.1, 1.1);
            _visualContainer.alpha = 1.0;
        } completion:nil];
        
        [_mediumFeedback impactOccurred];
    }
    else if (gr.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [gr translationInView:nil];
        self.floatingWindow.center = CGPointMake(_dragStartCenter.x + translation.x, _dragStartCenter.y + translation.y);
        
        CGFloat W = [UIScreen mainScreen].bounds.size.width;
        CGPoint currentCenter = self.floatingWindow.center;
        
        HKFDockEdge edgePreview;
        if (currentCenter.y < 80.0) {
            edgePreview = HKFDockEdgeTop;
        } else {
            edgePreview = (currentCenter.x < W / 2.0) ? HKFDockEdgeLeft : HKFDockEdgeRight;
        }
        
        if (edgePreview != _currentEdge) {
            [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
                [self updateShapeForEdge:edgePreview];
                [_lightFeedback impactOccurred];
            } completion:nil];
        }
    }
    else {
        CGFloat W = [UIScreen mainScreen].bounds.size.width;
        CGFloat H = [UIScreen mainScreen].bounds.size.height;
        CGFloat w = [self _prefWidth];
        CGFloat len = [self _prefLength];
        CGFloat pad = [self _prefEdgePadding];
        CGPoint finalCenter = self.floatingWindow.center;
        
        HKFDockEdge finalEdge;
        if (finalCenter.y < 80.0) {
            finalEdge = HKFDockEdgeTop;
            finalCenter.y = (w / 2.0) + pad;
            CGFloat halfLen = len / 2.0;
            if (finalCenter.x < halfLen) finalCenter.x = halfLen;
            if (finalCenter.x > W - halfLen) finalCenter.x = W - halfLen;
        } else {
            if (finalCenter.x < W / 2.0) {
                finalEdge = HKFDockEdgeLeft;
                finalCenter.x = (w / 2.0) + pad;
            } else {
                finalEdge = HKFDockEdgeRight;
                finalCenter.x = W - ((w / 2.0) + pad);
            }
            CGFloat topSafeArea = 60.0;
            CGFloat bottomSafeArea = H - 50.0;
            if (finalCenter.y < topSafeArea) finalCenter.y = topSafeArea;
            if (finalCenter.y > bottomSafeArea) finalCenter.y = bottomSafeArea;
        }
        
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
            [self updateShapeForEdge:finalEdge];
            self.floatingWindow.center = finalCenter;
            self.floatingWindow.transform = CGAffineTransformIdentity;
            _visualContainer.alpha = 1.0;
        } completion:^(BOOL finished){
            _isIdle = NO;
            [self resetIdleTimer];
            [self savePosition];
        }];
    }
}
@end

@implementation HKFFloatingManager {
    MPVolumeView *_hiddenVolumeView;
}

+ (instancetype)sharedInstance {
    static HKFFloatingManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)setup {
    if (_button1) return;
    loadPrefs();
    
    UIWindowScene *targetScene = nil;
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(statusBarWindow)]) {
        UIWindow *sbWin = [(SpringBoard *)[UIApplication sharedApplication] statusBarWindow];
        if (sbWin && [sbWin respondsToSelector:@selector(windowScene)] && sbWin.windowScene) {
            targetScene = sbWin.windowScene;
        }
    }
    if (!targetScene) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                targetScene = (UIWindowScene *)scene;
                break;
            }
        }
    }
    if (!targetScene) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                if (ws.screen == [UIScreen mainScreen]) {
                    targetScene = ws;
                    break;
                }
            }
        }
    }
    if (!targetScene) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setup];
        });
        return;
    }
    
    _hiddenVolumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    _hiddenVolumeView.alpha = 0.01;
    _hiddenVolumeView.hidden = NO;
    _hiddenVolumeView.userInteractionEnabled = NO;
    
    for (UIView *view in _hiddenVolumeView.subviews) {
        if ([view isKindOfClass:[UISlider class]]) {
            self.volumeSlider = (UISlider *)view;
            break;
        }
    }
    
    _button1 = [[HKFButtonItem alloc] initWithIndex:1 scene:targetScene];
    [_button1.floatingWindow.rootViewController.view addSubview:_hiddenVolumeView];
    
    _button2 = [[HKFButtonItem alloc] initWithIndex:2 scene:targetScene];
}

- (void)reloadConfig {
    if (_button1) [_button1 updateConfig];
    if (_button2) [_button2 updateConfig];
}

- (void)updateScene:(UIWindowScene *)scene {
    if (_button1 && _button1.floatingWindow && _button1.floatingWindow.windowScene != scene) {
        _button1.floatingWindow.windowScene = scene;
    }
    if (_button2 && _button2.floatingWindow && _button2.floatingWindow.windowScene != scene) {
        _button2.floatingWindow.windowScene = scene;
    }
}
@end

static void reloadPrefsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    loadPrefs();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[HKFFloatingManager sharedInstance] reloadConfig];
    });
}

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reloadPrefsNotification, CFSTR("com.yourname.hardkeyfix/ReloadPrefs"), NULL, CFNotificationSuspensionBehaviorCoalesce);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[HKFFloatingManager sharedInstance] setup];
    });
}

- (void)frontDisplayDidChange:(id)newDisplay {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(statusBarWindow)]) {
            UIWindow *sbWin = [(SpringBoard *)[UIApplication sharedApplication] statusBarWindow];
            if (sbWin && [sbWin respondsToSelector:@selector(windowScene)] && sbWin.windowScene) {
                [[HKFFloatingManager sharedInstance] updateScene:sbWin.windowScene];
            }
        }
    });
}
%end
