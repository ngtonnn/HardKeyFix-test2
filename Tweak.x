#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>
#import <math.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wunused-variable"

/* ── Forward declarations (SpringBoard-only classes) ── */

@interface SpringBoard : UIApplication
- (id)screenshotManager;
@end

@interface SBScreenshotManager : NSObject
- (void)saveScreenshotsWithCompletion:(id)completion;
@end

@interface SBScreenShotter : NSObject
+ (instancetype)sharedInstance;
- (void)saveScreenshot:(BOOL)saveToPhotos;
@end

/* ── Types & statics ── */

typedef NS_ENUM(NSInteger, HKFDockEdge) {
    HKFDockEdgeLeft = 0,
    HKFDockEdgeRight,
    HKFDockEdgeTop
};

static BOOL hkf_isSpringBoard = NO;
static const CGFloat kIdleOpacity  = 0.3;
static const CGFloat kIdleTimeout  = 0.5;
static NSString *const kPrefsPath =
    @"/var/mobile/Library/Preferences/com.yourname.hardkeyfix.plist";
static NSString *const kScreenshotNotify =
    @"com.yourname.hardkeyfix/screenshot";

/* ── Position persistence helpers ── */

static void HKFSavePosition(CGFloat x, CGFloat y, int edge) {
    [@{@"x": @(x), @"y": @(y), @"edge": @(edge)}
        writeToFile:kPrefsPath atomically:YES];
}
static NSDictionary *HKFLoadPosition(void) {
    return [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
}

/* ── Screenshot callback (runs in SpringBoard) ── */

static void HKFScreenshotCB(CFNotificationCenterRef c, void *obs,
    CFNotificationName n, const void *obj, CFDictionaryRef info) {
    dispatch_async(dispatch_get_main_queue(), ^{
        SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
        if ([sb respondsToSelector:@selector(screenshotManager)]) {
            id mgr = [sb screenshotManager];
            if (mgr && [mgr respondsToSelector:
                    @selector(saveScreenshotsWithCompletion:)])
                [mgr saveScreenshotsWithCompletion:nil];
        } else {
            Class c2 = objc_getClass("SBScreenShotter");
            if (c2 && [c2 respondsToSelector:@selector(sharedInstance)])
                [[c2 sharedInstance] saveScreenshot:YES];
        }
    });
}

/* ════════════════════════════════════════════════════════════
   HKFDialView  –  volume ruler (unchanged)
   ════════════════════════════════════════════════════════════ */

@interface HKFDialView : UIView
@property (nonatomic, strong) UIView *rulerView;
@property (nonatomic, assign) HKFDockEdge dockEdge;
- (instancetype)initWithFrame:(CGRect)frame edge:(HKFDockEdge)edge;
- (void)setVolume:(float)volume;
@end

@implementation HKFDialView
@synthesize rulerView = _rulerView;
@synthesize dockEdge  = _dockEdge;

- (instancetype)initWithFrame:(CGRect)frame edge:(HKFDockEdge)edge {
    self = [super initWithFrame:frame];
    if (self) {
        _dockEdge = edge;
        self.layer.cornerRadius = 16.0;
        self.clipsToBounds = YES;
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *bv = [[UIVisualEffectView alloc] initWithEffect:blur];
        bv.frame = self.bounds;
        [self addSubview:bv];

        BOOL isTop = (edge == HKFDockEdgeTop);
        _rulerView = isTop
            ? [[UIView alloc] initWithFrame:CGRectMake(0,0,600,frame.size.height)]
            : [[UIView alloc] initWithFrame:CGRectMake(0,0,frame.size.width,600)];
        [self addSubview:_rulerView];

        for (int i = 0; i <= 40; i++) {
            BOOL maj = (i % 10 == 0);
            UIView *tick = [[UIView alloc] init];
            tick.backgroundColor = maj ? [UIColor whiteColor]
                : [UIColor colorWithWhite:0.6 alpha:1.0];
            tick.layer.cornerRadius = 1.0;

            UILabel *lbl = nil;
            if (maj) {
                lbl = [[UILabel alloc] init];
                int v = isTop ? (i*100/40) : (100 - i*100/40);
                lbl.text = [NSString stringWithFormat:@"%d", v];
                lbl.textColor = [UIColor whiteColor];
                lbl.textAlignment = NSTextAlignmentCenter;
            }

            if (isTop) {
                tick.frame = CGRectMake(i*15, maj?20:26, 2, maj?20:14);
                if (maj) { lbl.frame = CGRectMake(i*15-15,4,32,14);
                           lbl.font = [UIFont boldSystemFontOfSize:11]; }
            } else {
                tick.frame = CGRectMake(maj?18:24, i*15, maj?20:14, 2);
                if (maj) { lbl.frame = CGRectMake(0,i*15-10,18,20);
                           lbl.font = [UIFont boldSystemFontOfSize:9]; }
            }
            [_rulerView addSubview:tick];
            if (maj) [_rulerView addSubview:lbl];
        }

        UIView *marker = [[UIView alloc] init];
        marker.backgroundColor = [UIColor systemYellowColor];
        marker.layer.cornerRadius = 1.0;
        marker.layer.shadowColor  = [UIColor blackColor].CGColor;
        marker.layer.shadowOffset = CGSizeZero;
        marker.layer.shadowOpacity = 1.0;
        marker.layer.shadowRadius  = 2.0;
        marker.frame = isTop
            ? CGRectMake((frame.size.width-2)/2.0, 16, 2, 28)
            : CGRectMake(16, (frame.size.height-2)/2.0, 28, 2);
        [self addSubview:marker];
    }
    return self;
}

- (void)setVolume:(float)volume {
    if (_dockEdge == HKFDockEdgeTop) {
        CGFloat cx = self.bounds.size.width / 2.0;
        _rulerView.transform = CGAffineTransformMakeTranslation(cx - volume*600.0, 0);
    } else {
        CGFloat cy = self.bounds.size.height / 2.0;
        _rulerView.transform = CGAffineTransformMakeTranslation(0, cy - (1.0-volume)*600.0);
    }
}
@end

/* ════════════════════════════════════════════════════════════
   SpringBoard-only: suppress system volume HUD
   ════════════════════════════════════════════════════════════ */

%group SBHooks
%hook SBVolumeControl
- (void)presentVolumeHUDWithVolume:(float)v  {}
- (void)_presentVolumeHUDWithVolume:(float)v {}
%end
%end

/* ════════════════════════════════════════════════════════════
   HKFButtonView  –  invisible touch target
   ════════════════════════════════════════════════════════════ */

@interface HKFButtonView : UIView
@end

@implementation HKFButtonView
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e {
    return CGRectContainsPoint(CGRectInset(self.bounds, -15, -12), p);
}
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    if (!self.userInteractionEnabled || self.hidden) return nil;
    return [self pointInside:p withEvent:e] ? self : nil;
}
/* swallow unhandled touches so they never reach the app */
- (void)touchesBegan:(NSSet<UITouch*>*)t withEvent:(UIEvent*)e {}
- (void)touchesMoved:(NSSet<UITouch*>*)t withEvent:(UIEvent*)e {}
- (void)touchesEnded:(NSSet<UITouch*>*)t withEvent:(UIEvent*)e {}
- (void)touchesCancelled:(NSSet<UITouch*>*)t withEvent:(UIEvent*)e {}
@end

/* ════════════════════════════════════════════════════════════
   HKFFloatingWindow  –  full-screen pass-through overlay
   ════════════════════════════════════════════════════════════ */

@class HKFFloatingManager;

@interface HKFFloatingWindow : UIWindow
@end

@interface HKFFloatingManager : NSObject
@property (nonatomic, strong) UIWindow *floatingWindow;
+ (instancetype)sharedInstance;
- (void)setup;
- (BOOL)isPointInInteractiveArea:(CGPoint)pt;
- (UIView *)buttonViewForHit;
@end

@implementation HKFFloatingWindow
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)e {
    if (self.hidden || !self.userInteractionEnabled) return NO;
    UIView *hit = [self.rootViewController.view hitTest:p withEvent:e];
    if (!hit || hit == self.rootViewController.view) return NO;
    return YES;
}
@end

/* ════════════════════════════════════════════════════════════
   HKFRootViewController
   ════════════════════════════════════════════════════════════ */

@interface HKFRootViewController : UIViewController
@end
@implementation HKFRootViewController
- (BOOL)shouldAutorotate { return NO; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}
- (BOOL)_canShowWhileLocked { return YES; }
@end

/* ════════════════════════════════════════════════════════════
   HKFFloatingManager – main controller (runs in every process)
   ════════════════════════════════════════════════════════════ */

@interface HKFFloatingManager ()
- (void)_updateShapeForEdge:(HKFDockEdge)edge;
- (void)_resetIdleTimer;
- (void)_idleTimerFired;
- (void)_wakeUp;
- (void)_dismissDialView;
- (void)_showDialForCurrentVolume;
- (void)_handleDoubleTap:(UITapGestureRecognizer *)gr;
- (void)_handleVolumePan:(UIPanGestureRecognizer *)gr;
- (void)_handleLongPressMove:(UILongPressGestureRecognizer *)gr;
@end

@implementation HKFFloatingManager {
    HKFButtonView *_buttonView;
    UIView *_visualContainer;
    UIVisualEffectView *_blurView;
    UIView *_innerRing;
    UIView *_centerDot;

    NSTimer *_idleTimer;
    NSTimer *_dialDismissTimer;
    BOOL _isIdle;
    HKFDockEdge _currentEdge;

    float _currentVolume;
    CGFloat _lastPanCoord;
    int _lastHapticStep;
    MPVolumeView *_hiddenVolumeView;
    UISlider *_volumeSlider;
    HKFDialView *_dialView;

    UIImpactFeedbackGenerator *_lightFB;
    UIImpactFeedbackGenerator *_heavyFB;
    UIImpactFeedbackGenerator *_mediumFB;

    CGPoint _dragStartCenter;
    CGPoint _dragStartTouch;
}

+ (instancetype)sharedInstance {
    static HKFFloatingManager *inst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[self alloc] init]; });
    return inst;
}

/* ── Hit-testing helpers called by the window ── */

- (BOOL)isPointInInteractiveArea:(CGPoint)pt {
    if (!_buttonView || _buttonView.hidden) return NO;
    CGRect r = CGRectInset(_buttonView.frame, -15, -12);
    return CGRectContainsPoint(r, pt);
}
- (UIView *)buttonViewForHit { return _buttonView; }

/* ── Shape ── */

- (void)_updateShapeForEdge:(HKFDockEdge)edge {
    _currentEdge = edge;
    CGSize sz = (edge == HKFDockEdgeTop)
        ? CGSizeMake(200, 32) : CGSizeMake(32, 100);

    _buttonView.bounds = CGRectMake(0, 0, sz.width, sz.height);

    CGFloat cr = 16.0;
    _visualContainer.frame = _buttonView.bounds;
    _visualContainer.layer.cornerRadius = cr;
    _blurView.frame = _visualContainer.bounds;
    _blurView.layer.cornerRadius = cr;

    _innerRing.frame = CGRectInset(_visualContainer.bounds, 4, 4);
    _innerRing.layer.cornerRadius = 12.0;

    if (edge == HKFDockEdgeTop) {
        _centerDot.frame = CGRectMake(sz.width/2.0-24, sz.height/2.0-2, 48, 4);
    } else {
        _centerDot.frame = CGRectMake(sz.width/2.0-2, sz.height/2.0-12, 4, 24);
    }
    _centerDot.layer.cornerRadius = 2.0;
}

/* ── Setup (called once per process) ── */

- (void)setup {
    if (self.floatingWindow) return;  /* already set up */

    /* pick a window scene */
    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) {
            UIWindowScene *ws = (UIWindowScene *)s;
            if (ws.activationState == UISceneActivationStateForegroundActive) {
                scene = ws; break;
            }
        }
    }
    if (!scene) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s; break;
            }
        }
    }

    CGRect scr = [UIScreen mainScreen].bounds;
    CGFloat W = scr.size.width;

    if (scene) {
        self.floatingWindow = [[HKFFloatingWindow alloc] initWithWindowScene:scene];
        self.floatingWindow.frame = scr;
    } else {
        self.floatingWindow = [[HKFFloatingWindow alloc] initWithFrame:scr];
    }

    self.floatingWindow.windowLevel = CGFLOAT_MAX / 2.0;
    self.floatingWindow.backgroundColor = [UIColor clearColor];
    self.floatingWindow.userInteractionEnabled = YES;
    self.floatingWindow.clipsToBounds = NO;

    HKFRootViewController *rootVC = [[HKFRootViewController alloc] init];
    rootVC.view.frame = scr;
    rootVC.view.backgroundColor = [UIColor clearColor];
    rootVC.view.clipsToBounds = NO;
    rootVC.view.userInteractionEnabled = YES;
    self.floatingWindow.rootViewController = rootVC;

    /* feedback generators */
    _lightFB  = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    _heavyFB  = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    _mediumFB = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];

    /* hidden MPVolumeView for controlling system volume */
    _hiddenVolumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-100,-100,10,10)];
    _hiddenVolumeView.alpha = 0.01;
    _hiddenVolumeView.hidden = NO;
    _hiddenVolumeView.userInteractionEnabled = NO;
    [rootVC.view addSubview:_hiddenVolumeView];

    for (UIView *v in _hiddenVolumeView.subviews) {
        if ([v isKindOfClass:[UISlider class]]) { _volumeSlider = (UISlider *)v; break; }
    }
    /* retry if slider not found yet */
    if (!_volumeSlider) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2*NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
            for (UIView *v in _hiddenVolumeView.subviews) {
                if ([v isKindOfClass:[UISlider class]]) { _volumeSlider = (UISlider *)v; break; }
            }
        });
    }

    /* ── build button view & visuals ── */
    _buttonView = [[HKFButtonView alloc] initWithFrame:CGRectMake(0,0,200,32)];
    _buttonView.backgroundColor = [UIColor clearColor];
    _buttonView.userInteractionEnabled = YES;
    _buttonView.alpha = 1.0;

    _visualContainer = [[UIView alloc] initWithFrame:_buttonView.bounds];
    _visualContainer.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
    _visualContainer.layer.masksToBounds = NO;
    _visualContainer.layer.borderWidth  = 1.0;
    _visualContainer.layer.borderColor  = [UIColor colorWithWhite:1.0 alpha:0.1].CGColor;
    _visualContainer.layer.shadowColor  = [UIColor whiteColor].CGColor;
    _visualContainer.layer.shadowOffset = CGSizeZero;
    _visualContainer.layer.shadowOpacity = 0.5;
    _visualContainer.layer.shadowRadius  = 8.0;
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

    /* ── restore saved position ── */
    NSDictionary *saved = HKFLoadPosition();
    CGFloat posX = W / 2.0, posY = 40.0; // Moved down from 16.0 to avoid status bar
    HKFDockEdge posEdge = HKFDockEdgeTop;
    if (saved) {
        if (saved[@"x"])    posX    = [saved[@"x"] doubleValue];
        if (saved[@"y"])    posY    = [saved[@"y"] doubleValue];
        if (saved[@"edge"]) posEdge = (HKFDockEdge)[saved[@"edge"] intValue];
    }
    /* clamp to screen */
    CGFloat H = scr.size.height;
    if (posX < 0 || posX > W) posX = W/2.0;
    if (posY < 0 || posY > H) posY = 40.0; // Moved down from 16.0

    [self _updateShapeForEdge:posEdge];
    _buttonView.center = CGPointMake(posX, posY);

    _visualContainer.alpha = (posEdge == HKFDockEdgeTop) ? 0.0 : kIdleOpacity;
    _buttonView.alpha = 1.0;
    _isIdle = YES;

    /* ── gesture recognisers ── */
    UITapGestureRecognizer *dblTap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(_handleDoubleTap:)];
    dblTap.numberOfTapsRequired = 2;
    dblTap.delaysTouchesBegan = NO;
    [_buttonView addGestureRecognizer:dblTap];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(_handleVolumePan:)];
    pan.delaysTouchesBegan = NO;
    [_buttonView addGestureRecognizer:pan];

    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc]
        initWithTarget:self action:@selector(_handleLongPressMove:)];
    lp.minimumPressDuration = 0.5;
    [_buttonView addGestureRecognizer:lp];

    self.floatingWindow.hidden = NO;
    [self _resetIdleTimer];
}

/* ── Idle timer ── */

- (void)_resetIdleTimer {
    [_idleTimer invalidate];
    _idleTimer = [NSTimer scheduledTimerWithTimeInterval:kIdleTimeout
        target:self selector:@selector(_idleTimerFired) userInfo:nil repeats:NO];
}

- (void)_idleTimerFired {
    if (_isIdle) return;
    _isIdle = YES;
    [UIView animateWithDuration:0.4 delay:0
        options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionAllowUserInteraction
        animations:^{
            _visualContainer.alpha =
                (_currentEdge == HKFDockEdgeTop) ? 0.0 : kIdleOpacity;
            CGFloat W = [UIScreen mainScreen].bounds.size.width;
            CGPoint c = _buttonView.center;
            if (_currentEdge == HKFDockEdgeTop)       c.y = 40.0;
            else if (_currentEdge == HKFDockEdgeLeft)  c.x = 16.0;
            else                                       c.x = W - 16.0;
            _buttonView.center = c;
        } completion:nil];
}

- (void)_wakeUp {
    [_idleTimer invalidate];
    if (!_isIdle) return;
    _isIdle = NO;
    if (_currentEdge != HKFDockEdgeTop) {
        [UIView animateWithDuration:0.2 delay:0
            options:UIViewAnimationOptionAllowUserInteraction
            animations:^{ _visualContainer.alpha = 1.0; } completion:nil];
    } else {
        _visualContainer.alpha = 0.0;
    }
}

/* ── Dial management ── */

- (void)_showDialForCurrentVolume {
    if (!_volumeSlider) return;
    [_dialDismissTimer invalidate]; _dialDismissTimer = nil;
    _currentVolume = _volumeSlider.value;

    CGFloat W = [UIScreen mainScreen].bounds.size.width;
    CGRect df = (_currentEdge == HKFDockEdgeTop)
        ? CGRectMake(0,0,260,48) : CGRectMake(0,0,48,260);

    if (!_dialView || _dialView.dockEdge != _currentEdge) {
        [_dialView removeFromSuperview];
        _dialView = [[HKFDialView alloc] initWithFrame:df edge:_currentEdge];
        _dialView.userInteractionEnabled = NO;
        [self.floatingWindow.rootViewController.view addSubview:_dialView];
    } else {
        [self.floatingWindow.rootViewController.view bringSubviewToFront:_dialView];
    }

    _dialView.transform = CGAffineTransformIdentity;
    if (_currentEdge == HKFDockEdgeTop) {
        _dialView.layer.anchorPoint = CGPointMake(0.5, 0.0);
        _dialView.frame = CGRectMake((W-260)/2.0, 0, 260, 48);
    } else if (_currentEdge == HKFDockEdgeLeft) {
        _dialView.layer.anchorPoint = CGPointMake(0.0, 0.5);
        _dialView.frame = CGRectMake(0, _buttonView.center.y-130, 48, 260);
    } else {
        _dialView.layer.anchorPoint = CGPointMake(1.0, 0.5);
        _dialView.frame = CGRectMake(W-48, _buttonView.center.y-130, 48, 260);
    }
    [_dialView setVolume:_currentVolume];

    if (_dialView.alpha < 0.01)
        _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);

    [_dialView.layer removeAllAnimations];
    [_visualContainer.layer removeAllAnimations];
    if (_currentEdge == HKFDockEdgeTop) _visualContainer.alpha = 0.0;

    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7
        initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut|
                UIViewAnimationOptionAllowUserInteraction|
                UIViewAnimationOptionBeginFromCurrentState
        animations:^{
            _dialView.transform = CGAffineTransformIdentity;
            _dialView.alpha = 1.0;
            if (_currentEdge == HKFDockEdgeTop) _visualContainer.alpha = 0.0;
        } completion:nil];

    [_lightFB prepare]; [_lightFB impactOccurred];

    _dialDismissTimer = [NSTimer scheduledTimerWithTimeInterval:1.5
        target:self selector:@selector(_dismissDialView) userInfo:nil repeats:NO];
}

- (void)_dismissDialView {
    [_dialDismissTimer invalidate]; _dialDismissTimer = nil;
    [_dialView.layer removeAllAnimations];
    [_visualContainer.layer removeAllAnimations];

    [UIView animateWithDuration:0.2 delay:0
        options:UIViewAnimationOptionCurveEaseInOut|UIViewAnimationOptionAllowUserInteraction
        animations:^{
            _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);
            _dialView.alpha = 0.0;
            if (_currentEdge == HKFDockEdgeTop)  _visualContainer.alpha = 0.0;
            else                                  _visualContainer.alpha = 1.0;
        } completion:^(BOOL ok){
            _dialView.alpha = 0.0;
            _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);
            if (_currentEdge == HKFDockEdgeTop) {
                _visualContainer.alpha = 0.0;
                _isIdle = YES;
            }
        }];
    if (_currentEdge != HKFDockEdgeTop) [self _resetIdleTimer];
}

/* ── Gesture handlers ── */

- (void)_handleDoubleTap:(UITapGestureRecognizer *)gr {
    if (gr.state != UIGestureRecognizerStateEnded) return;

    _buttonView.hidden = YES;
    if (_dialView) _dialView.hidden = YES;

    if (hkf_isSpringBoard) {
        /* take screenshot directly */
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1*NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
            SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
            if ([sb respondsToSelector:@selector(screenshotManager)]) {
                id m = [sb screenshotManager];
                if (m && [m respondsToSelector:@selector(saveScreenshotsWithCompletion:)])
                    [m saveScreenshotsWithCompletion:nil];
            } else {
                Class c2 = objc_getClass("SBScreenShotter");
                if (c2 && [c2 respondsToSelector:@selector(sharedInstance)])
                    [[c2 sharedInstance] saveScreenshot:YES];
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4*NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                _buttonView.hidden = NO;
                if (_dialView) _dialView.hidden = NO;
            });
        });
    } else {
        /* ask SpringBoard via Darwin notification */
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge CFNotificationName)kScreenshotNotify,
            NULL, NULL, true);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5*NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
            _buttonView.hidden = NO;
            if (_dialView) _dialView.hidden = NO;
        });
    }
}

- (void)_handleVolumePan:(UIPanGestureRecognizer *)gr {
    if (!_volumeSlider) return;
    CGPoint loc = [gr locationInView:self.floatingWindow];

    if (gr.state == UIGestureRecognizerStateBegan) {
        [self _wakeUp];
        [_dialDismissTimer invalidate]; _dialDismissTimer = nil;

        _lastPanCoord = (_currentEdge == HKFDockEdgeTop) ? loc.x : loc.y;
        _currentVolume = _volumeSlider.value;
        _lastHapticStep = (int)(_currentVolume * 16.0);

        CGFloat W = [UIScreen mainScreen].bounds.size.width;
        CGRect df = (_currentEdge == HKFDockEdgeTop)
            ? CGRectMake(0,0,260,48) : CGRectMake(0,0,48,260);

        if (!_dialView || _dialView.dockEdge != _currentEdge) {
            [_dialView removeFromSuperview];
            _dialView = [[HKFDialView alloc] initWithFrame:df edge:_currentEdge];
            _dialView.userInteractionEnabled = NO;
            [self.floatingWindow.rootViewController.view addSubview:_dialView];
        } else {
            [self.floatingWindow.rootViewController.view bringSubviewToFront:_dialView];
        }

        _dialView.transform = CGAffineTransformIdentity;
        if (_currentEdge == HKFDockEdgeTop) {
            _dialView.layer.anchorPoint = CGPointMake(0.5, 0.0);
            _dialView.frame = CGRectMake((W-260)/2.0, 0, 260, 48);
        } else if (_currentEdge == HKFDockEdgeLeft) {
            _dialView.layer.anchorPoint = CGPointMake(0.0, 0.5);
            _dialView.frame = CGRectMake(0, _buttonView.center.y-130, 48, 260);
        } else {
            _dialView.layer.anchorPoint = CGPointMake(1.0, 0.5);
            _dialView.frame = CGRectMake(W-48, _buttonView.center.y-130, 48, 260);
        }
        [_dialView setVolume:_currentVolume];

        if (_dialView.alpha < 0.01)
            _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);

        [_dialView.layer removeAllAnimations];
        [_visualContainer.layer removeAllAnimations];
        if (_currentEdge == HKFDockEdgeTop) _visualContainer.alpha = 0.0;

        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7
            initialSpringVelocity:0
            options:UIViewAnimationOptionCurveEaseOut|
                    UIViewAnimationOptionAllowUserInteraction|
                    UIViewAnimationOptionBeginFromCurrentState
            animations:^{
                _dialView.transform = CGAffineTransformIdentity;
                _dialView.alpha = 1.0;
                if (_currentEdge == HKFDockEdgeTop) _visualContainer.alpha = 0.0;
            } completion:nil];

        [_heavyFB prepare]; [_lightFB prepare]; [_heavyFB impactOccurred];

        _dialDismissTimer = [NSTimer scheduledTimerWithTimeInterval:1.5
            target:self selector:@selector(_dismissDialView) userInfo:nil repeats:NO];
    }
    else if (gr.state == UIGestureRecognizerStateChanged) {
        [_dialDismissTimer invalidate];
        _dialDismissTimer = [NSTimer scheduledTimerWithTimeInterval:1.5
            target:self selector:@selector(_dismissDialView) userInfo:nil repeats:NO];

        CGFloat cur = (_currentEdge == HKFDockEdgeTop) ? loc.x : loc.y;
        CGFloat delta = cur - _lastPanCoord;
        _lastPanCoord = cur;

        CGFloat vel = (_currentEdge == HKFDockEdgeTop)
            ? [gr velocityInView:self.floatingWindow].x
            : [gr velocityInView:self.floatingWindow].y;
        CGFloat mult = 1.0 + MIN(fabs(vel)/500.0, 3.0);
        _currentVolume += (float)((-delta / 150.0) * mult);
        _currentVolume = MAX(0.0f, MIN(1.0f, _currentVolume));

        [_dialView setVolume:_currentVolume];
        [_volumeSlider setValue:_currentVolume animated:NO];
        [_volumeSlider sendActionsForControlEvents:UIControlEventValueChanged];

        int step = (int)(_currentVolume * 16.0);
        if (step != _lastHapticStep) {
            _lastHapticStep = step;
            [_lightFB impactOccurred]; [_lightFB prepare];
        }
    }
    else { /* ended / cancelled */
        [_volumeSlider sendActionsForControlEvents:UIControlEventTouchUpInside];
        [self _dismissDialView];
    }
}

- (void)_handleLongPressMove:(UILongPressGestureRecognizer *)gr {
    CGPoint loc = [gr locationInView:self.floatingWindow];

    if (gr.state == UIGestureRecognizerStateBegan) {
        [self _dismissDialView]; [self _wakeUp];
        _dragStartCenter = _buttonView.center;
        _dragStartTouch  = loc;

        CGFloat W = [UIScreen mainScreen].bounds.size.width;
        CGPoint pop = _buttonView.center;
        if      (_currentEdge == HKFDockEdgeTop)  pop.y = 40.0;
        else if (pop.x < W/2.0)                   pop.x = 16.0;
        else                                       pop.x = W - 16.0;

        [UIView animateWithDuration:0.2 delay:0
            options:UIViewAnimationOptionAllowUserInteraction animations:^{
            _buttonView.center = pop;
            _buttonView.transform = CGAffineTransformMakeScale(1.1, 1.1);
            _visualContainer.alpha = 1.0;
        } completion:nil];
        _dragStartCenter = pop;
        [_mediumFB prepare]; [_mediumFB impactOccurred];
    }
    else if (gr.state == UIGestureRecognizerStateChanged) {
        CGFloat dx = loc.x - _dragStartTouch.x;
        CGFloat dy = loc.y - _dragStartTouch.y;
        _buttonView.center = CGPointMake(_dragStartCenter.x+dx, _dragStartCenter.y+dy);

        CGFloat H = [UIScreen mainScreen].bounds.size.height;
        HKFDockEdge preview = HKFDockEdgeRight;
        if (_buttonView.center.y < H * 0.12)
            preview = HKFDockEdgeTop;
        else
            preview = (_buttonView.center.x < [UIScreen mainScreen].bounds.size.width/2.0)
                ? HKFDockEdgeLeft : HKFDockEdgeRight;

        if (preview != _currentEdge) {
            [UIView animateWithDuration:0.2 delay:0
                options:UIViewAnimationOptionAllowUserInteraction animations:^{
                [self _updateShapeForEdge:preview];
                [_lightFB impactOccurred];
            } completion:nil];
        }
    }
    else { /* ended / cancelled */
        CGFloat W = [UIScreen mainScreen].bounds.size.width;
        CGFloat H = [UIScreen mainScreen].bounds.size.height;
        CGPoint fc = _buttonView.center;
        HKFDockEdge fe;

        if (fc.y < H * 0.12) {
            fe = HKFDockEdgeTop;
            fc.y = 40.0;
            CGFloat mx = 110.0;
            if (fc.x < mx)   fc.x = mx;
            if (fc.x > W-mx) fc.x = W-mx;
        } else {
            if (fc.x < W/2.0) { fe = HKFDockEdgeLeft;  fc.x = 16.0; }
            else               { fe = HKFDockEdgeRight; fc.x = W-16.0; }
            if (fc.y < 100.0)  fc.y = 100.0;
            if (fc.y > H-50.0) fc.y = H-50.0;
        }

        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8
            initialSpringVelocity:0
            options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionAllowUserInteraction
            animations:^{
                [self _updateShapeForEdge:fe];
                _buttonView.center = fc;
                _buttonView.transform = CGAffineTransformIdentity;
                _visualContainer.alpha = (fe == HKFDockEdgeTop) ? 0.0 : 1.0;
            } completion:^(BOOL ok){
                if (fe == HKFDockEdgeTop) _isIdle = YES;
            }];
        if (fe != HKFDockEdgeTop) [self _resetIdleTimer];

        /* persist position */
        HKFSavePosition(fc.x, fc.y, (int)fe);
    }
}
@end

/* ════════════════════════════════════════════════════════════
   Constructor – runs in every UIKit process
   ════════════════════════════════════════════════════════════ */

%ctor {
    @autoreleasepool {
        NSString *bid = [NSBundle mainBundle].bundleIdentifier;
        if (!bid) return;

        /* skip extensions */
        if ([[NSBundle mainBundle].bundlePath hasSuffix:@".appex"]) return;

        hkf_isSpringBoard = [bid isEqualToString:@"com.apple.springboard"];

        /* SpringBoard-only hooks (suppress volume HUD) */
        if (hkf_isSpringBoard) {
            %init(SBHooks);

            /* listen for screenshot requests from app processes */
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                HKFScreenshotCB,
                (__bridge CFStringRef)kScreenshotNotify,
                NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        }

        /* create widget ONLY in SpringBoard */
        if (hkf_isSpringBoard) {
            [[NSNotificationCenter defaultCenter]
                addObserverForName:UIApplicationDidFinishLaunchingNotification
                object:nil queue:nil
                usingBlock:^(NSNotification *note) {
                    dispatch_after(
                        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5*NSEC_PER_SEC)),
                        dispatch_get_main_queue(), ^{
                            [[HKFFloatingManager sharedInstance] setup];
                        });
                }];
        }
    }
}
