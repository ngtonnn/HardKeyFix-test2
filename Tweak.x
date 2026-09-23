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

@interface SpringBoard : UIApplication
- (id)screenshotManager;
- (NSSet<UIWindowScene *> *)connectedScenes;
@end

@interface SBScreenshotManager : NSObject
- (void)saveScreenshotsWithCompletion:(id)completion;
@end

@interface SBScreenShotter : NSObject
+ (instancetype)sharedInstance;
- (void)saveScreenshot:(BOOL)saveToPhotos;
@end

@interface SBMainDisplaySceneLayoutStatusBarView : UIView
- (void)_statusBarTapped:(id)arg1 type:(NSInteger)arg2;
@end

typedef NS_ENUM(NSInteger, HKFDockEdge) {
    HKFDockEdgeLeft = 0,
    HKFDockEdgeRight,
    HKFDockEdgeTop
};

static const BOOL prefs_lockPosition = NO;
static const CGFloat prefs_idleOpacity = 0.3; 
static const CGFloat prefs_idleTimeout = 0.5; 

@interface HKFDialView : UIView
@property (nonatomic, strong) UIView *rulerView;
@property (nonatomic, assign) HKFDockEdge dockEdge;
- (instancetype)initWithFrame:(CGRect)frame edge:(HKFDockEdge)edge;
- (void)setVolume:(float)volume;
@end

@implementation HKFDialView
@synthesize rulerView = _rulerView;
@synthesize dockEdge = _dockEdge;

- (instancetype)initWithFrame:(CGRect)frame edge:(HKFDockEdge)edge {
    self = [super initWithFrame:frame];
    if (self) {
        _dockEdge = edge;
        
        self.layer.cornerRadius = 16.0;
        self.clipsToBounds = YES;
        self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
        
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = self.bounds;
        [self addSubview:blurView];
        
        BOOL isTop = (edge == HKFDockEdgeTop);
        
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
                tick.frame = CGRectMake(i * 15, isMajor ? 20 : 26, 2, isMajor ? 20 : 14);
                if (isMajor) {
                    lbl.frame = CGRectMake(i * 15 - 15, 4, 32, 14);
                    lbl.font = [UIFont boldSystemFontOfSize:11];
                }
            } else {
                tick.frame = CGRectMake(isMajor ? 18 : 24, i * 15, isMajor ? 20 : 14, 2);
                if (isMajor) {
                    lbl.frame = CGRectMake(0, i * 15 - 10, 18, 20); 
                    lbl.font = [UIFont boldSystemFontOfSize:9]; 
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
            marker.frame = CGRectMake((frame.size.width - 2) / 2.0, 16, 2, 28);
        } else {
            marker.frame = CGRectMake(16, (frame.size.height - 2) / 2.0, 28, 2);
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
    CGRect hitRect = CGRectInset(self.bounds, -15, -12);
    return CGRectContainsPoint(hitRect, point);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!self.userInteractionEnabled || self.hidden) return nil;
    if ([self pointInside:point withEvent:event]) {
        return self;
    }
    return nil;
}
@end

@class HKFFloatingManager;

@interface HKFFloatingWindow : UIWindow
@end

@interface HKFRootViewController : UIViewController
@end

@implementation HKFRootViewController
- (BOOL)_canShowWhileLocked { return YES; }
- (BOOL)shouldAutorotate { return NO; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }
@end

@interface HKFFloatingManager : NSObject
@property (nonatomic, strong) UIWindow *floatingWindow;
+ (instancetype)sharedInstance;
- (void)setup;
- (BOOL)isPointInInteractiveArea:(CGPoint)point fromWindow:(UIWindow *)window withEvent:(UIEvent *)event;
- (UIView *)targetViewForHitAtPoint:(CGPoint)point fromWindow:(UIWindow *)window withEvent:(UIEvent *)event;
- (BOOL)isPointInTweakArea:(CGPoint)pt;
- (void)handleExternalStatusBarTap;
@end

@implementation HKFFloatingWindow
- (BOOL)_canShowWhileLocked { return YES; }
- (BOOL)_isSecure { return YES; }
+ (BOOL)_isSecure { return YES; }

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || !self.userInteractionEnabled) return NO;
    return [[HKFFloatingManager sharedInstance] isPointInInteractiveArea:point fromWindow:self withEvent:event];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (![self pointInside:point withEvent:event]) return nil;
    return [[HKFFloatingManager sharedInstance] targetViewForHitAtPoint:point fromWindow:self withEvent:event];
}
@end

@interface HKFFloatingManager ()
- (void)_updateShapeForEdge:(HKFDockEdge)edge;
- (void)_resetIdleTimer;
- (void)_idleTimerFired;
- (void)_wakeUp;
- (void)_dismissDialView;
- (void)_showDialForCurrentVolume;
- (void)_handleSingleTap:(UITapGestureRecognizer *)gr;
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
    
    UIImpactFeedbackGenerator *_lightFeedback;
    UIImpactFeedbackGenerator *_heavyFeedback;
    UIImpactFeedbackGenerator *_mediumFeedback;
    
    CGPoint _dragStartCenter;
    CGPoint _dragStartTouch;
}

+ (instancetype)sharedInstance {
    static HKFFloatingManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (BOOL)isPointInInteractiveArea:(CGPoint)point fromWindow:(UIWindow *)window withEvent:(UIEvent *)event {
    if (_dialView && !_dialView.hidden && _dialView.alpha > 0.01) {
        CGPoint p = [window convertPoint:point toView:_dialView];
        if ([_dialView pointInside:p withEvent:event]) {
            return YES;
        }
    }
    if (_buttonView && !_buttonView.hidden && _buttonView.userInteractionEnabled) {
        CGPoint p = [window convertPoint:point toView:_buttonView];
        if ([_buttonView pointInside:p withEvent:event]) {
            return YES;
        }
    }
    return NO;
}

- (UIView *)targetViewForHitAtPoint:(CGPoint)point fromWindow:(UIWindow *)window withEvent:(UIEvent *)event {
    return _buttonView;
}

- (BOOL)isPointInTweakArea:(CGPoint)pt {
    if (_dialView && !_dialView.hidden && _dialView.alpha > 0.01) {
        return YES;
    }
    if (!_buttonView) return NO;
    CGRect r = CGRectInset(_buttonView.frame, -15, -12);
    return CGRectContainsPoint(r, pt);
}

- (void)handleExternalStatusBarTap {
    [self _wakeUp];
    [self _showDialForCurrentVolume];
}

- (void)_updateShapeForEdge:(HKFDockEdge)edge {
    _currentEdge = edge;
    
    CGSize newSize;
    if (edge == HKFDockEdgeTop) {
        newSize = CGSizeMake(200, 32);
    } else {
        newSize = CGSizeMake(32, 100);
    }
    
    _buttonView.bounds = CGRectMake(0, 0, newSize.width, newSize.height);
    
    CGFloat cornerRadius = 16.0;
    _visualContainer.frame = _buttonView.bounds;
    _visualContainer.layer.cornerRadius = cornerRadius;
    _blurView.frame = _visualContainer.bounds;
    _blurView.layer.cornerRadius = cornerRadius;
    
    _innerRing.frame = CGRectInset(_visualContainer.bounds, 4, 4);
    _innerRing.layer.cornerRadius = 12.0;
    
    if (edge == HKFDockEdgeTop) {
        _centerDot.frame = CGRectMake(newSize.width/2.0 - 24, newSize.height/2.0 - 2, 48, 4);
    } else {
        _centerDot.frame = CGRectMake(newSize.width/2.0 - 2, newSize.height/2.0 - 12, 4, 24);
    }
    _centerDot.layer.cornerRadius = 2.0;
}

- (void)setup {
    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) {
            scene = (UIWindowScene *)s;
            break;
        }
    }
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGFloat W = screenBounds.size.width;
    
    if (scene) {
        self.floatingWindow = [[HKFFloatingWindow alloc] initWithWindowScene:scene];
        self.floatingWindow.frame = screenBounds;
    } else {
        self.floatingWindow = [[HKFFloatingWindow alloc] initWithFrame:screenBounds];
    }
    
    self.floatingWindow.windowLevel = CGFLOAT_MAX / 2.0;
    self.floatingWindow.backgroundColor = [UIColor clearColor];
    self.floatingWindow.userInteractionEnabled = YES;
    self.floatingWindow.clipsToBounds = NO;
    
    HKFRootViewController *rootVC = [[HKFRootViewController alloc] init];
    rootVC.view.frame = screenBounds;
    rootVC.view.backgroundColor = [UIColor clearColor];
    rootVC.view.clipsToBounds = NO;
    rootVC.view.userInteractionEnabled = YES;
    self.floatingWindow.rootViewController = rootVC;
    
    _lightFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    _heavyFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    _mediumFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];

    _hiddenVolumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    _hiddenVolumeView.alpha = 0.01;
    _hiddenVolumeView.hidden = NO;
    _hiddenVolumeView.userInteractionEnabled = NO;
    [rootVC.view addSubview:_hiddenVolumeView];
    
    for (UIView *view in _hiddenVolumeView.subviews) {
        if ([view isKindOfClass:[UISlider class]]) {
            _volumeSlider = (UISlider *)view;
            break;
        }
    }

    _buttonView = [[HKFButtonView alloc] initWithFrame:CGRectMake(0, 0, 200, 32)];
    _buttonView.backgroundColor = [UIColor clearColor];
    _buttonView.userInteractionEnabled = YES;
    _buttonView.alpha = 1.0;
    
    _visualContainer = [[UIView alloc] initWithFrame:_buttonView.bounds];
    _visualContainer.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
    _visualContainer.layer.masksToBounds = NO;
    _visualContainer.layer.borderWidth = 1.0;
    _visualContainer.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.1].CGColor;
    _visualContainer.layer.shadowColor = [UIColor whiteColor].CGColor;
    _visualContainer.layer.shadowOffset = CGSizeZero;
    _visualContainer.layer.shadowOpacity = 0.5;
    _visualContainer.layer.shadowRadius = 8.0;
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
    
    [self _updateShapeForEdge:HKFDockEdgeTop]; 
    _buttonView.center = CGPointMake(W / 2.0, 16.0);
    
    _visualContainer.alpha = 0.0;
    _buttonView.alpha = 1.0;
    _isIdle = YES;

    UITapGestureRecognizer *doubleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleDoubleTap:)];
    doubleTapGR.numberOfTapsRequired = 2;
    doubleTapGR.delaysTouchesBegan = NO;
    [_buttonView addGestureRecognizer:doubleTapGR];

    UITapGestureRecognizer *singleTapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleSingleTap:)];
    singleTapGR.numberOfTapsRequired = 1;
    singleTapGR.delaysTouchesBegan = NO;
    [singleTapGR requireGestureRecognizerToFail:doubleTapGR];
    [_buttonView addGestureRecognizer:singleTapGR];

    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handleVolumePan:)];
    panGR.delaysTouchesBegan = NO;
    [_buttonView addGestureRecognizer:panGR];

    UILongPressGestureRecognizer *longPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_handleLongPressMove:)];
    longPressGR.minimumPressDuration = 0.5;
    [_buttonView addGestureRecognizer:longPressGR];

    [self.floatingWindow makeKeyAndVisible];
    [self _resetIdleTimer];
}

- (void)_resetIdleTimer {
    [_idleTimer invalidate];
    _idleTimer = [NSTimer scheduledTimerWithTimeInterval:prefs_idleTimeout target:self selector:@selector(_idleTimerFired) userInfo:nil repeats:NO];
}

- (void)_idleTimerFired {
    if (_isIdle) return;
    _isIdle = YES;
    
    [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        _visualContainer.alpha = (_currentEdge == HKFDockEdgeTop) ? 0.0 : prefs_idleOpacity;
        CGFloat W = [UIScreen mainScreen].bounds.size.width;
        CGPoint center = _buttonView.center;
        
        if (_currentEdge == HKFDockEdgeTop) {
            center.y = 16.0;
        } else if (_currentEdge == HKFDockEdgeLeft) {
            center.x = 16.0; 
        } else {
            center.x = W - 16.0;
        }
        
        _buttonView.center = center;
    } completion:nil];
}

- (void)_wakeUp {
    [_idleTimer invalidate];
    if (!_isIdle) return;
    _isIdle = NO;
    
    if (_currentEdge != HKFDockEdgeTop) {
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
            _visualContainer.alpha = 1.0;
        } completion:nil];
    } else {
        _visualContainer.alpha = 0.0;
    }
}

- (void)_showDialForCurrentVolume {
    if (!_volumeSlider) return;
    
    [_dialDismissTimer invalidate];
    _dialDismissTimer = nil;
    
    _currentVolume = _volumeSlider.value;
    
    CGFloat W = [UIScreen mainScreen].bounds.size.width;
    CGRect dialFrame;
    if (_currentEdge == HKFDockEdgeTop) {
        dialFrame = CGRectMake(0, 0, 260, 48);
    } else {
        dialFrame = CGRectMake(0, 0, 48, 260);
    }
    
    if (!_dialView || _dialView.dockEdge != _currentEdge) {
        [_dialView removeFromSuperview];
        _dialView = [[HKFDialView alloc] initWithFrame:dialFrame edge:_currentEdge];
        _dialView.userInteractionEnabled = NO;
        [self.floatingWindow.rootViewController.view addSubview:_dialView];
    } else {
        [self.floatingWindow.rootViewController.view bringSubviewToFront:_dialView];
    }
    
    _dialView.transform = CGAffineTransformIdentity;
    if (_currentEdge == HKFDockEdgeTop) {
        _dialView.layer.anchorPoint = CGPointMake(0.5, 0.0);
        _dialView.frame = CGRectMake((W - 260.0) / 2.0, 0, 260, 48);
    } else if (_currentEdge == HKFDockEdgeLeft) {
        _dialView.layer.anchorPoint = CGPointMake(0.0, 0.5);
        _dialView.frame = CGRectMake(0, _buttonView.center.y - 130.0, 48, 260);
    } else {
        _dialView.layer.anchorPoint = CGPointMake(1.0, 0.5);
        _dialView.frame = CGRectMake(W - 48.0, _buttonView.center.y - 130.0, 48, 260);
    }

    [_dialView setVolume:_currentVolume];
    
    if (_dialView.alpha == 0.0) {
        _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    }
    
    [_dialView.layer removeAllAnimations];
    [_visualContainer.layer removeAllAnimations];
    
    if (_currentEdge == HKFDockEdgeTop) {
        _visualContainer.alpha = 0.0;
    }
    
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
        _dialView.transform = CGAffineTransformIdentity;
        _dialView.alpha = 1.0;
        if (_currentEdge == HKFDockEdgeTop) {
            _visualContainer.alpha = 0.0;
        }
    } completion:nil];
    
    [_lightFeedback prepare];
    [_lightFeedback impactOccurred];
    
    _dialDismissTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(_dismissDialView) userInfo:nil repeats:NO];
}

- (void)_dismissDialView {
    [_dialDismissTimer invalidate];
    _dialDismissTimer = nil;
    
    [_dialView.layer removeAllAnimations];
    [_visualContainer.layer removeAllAnimations];
    
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction animations:^{
        _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);
        _dialView.alpha = 0.0;
        if (_currentEdge == HKFDockEdgeTop) {
            _visualContainer.alpha = 0.0;
        } else {
            _visualContainer.alpha = 1.0;
        }
    } completion:^(BOOL finished){
        _dialView.alpha = 0.0;
        _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);
        if (_currentEdge == HKFDockEdgeTop) {
            _visualContainer.alpha = 0.0;
            _isIdle = YES;
        }
    }];
    
    if (_currentEdge != HKFDockEdgeTop) {
        [self _resetIdleTimer];
    }
}

- (void)_handleSingleTap:(UITapGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateEnded) {
        [self _wakeUp];
        [self _showDialForCurrentVolume];
    }
}

- (void)_handleDoubleTap:(UITapGestureRecognizer *)gr {
    (void)gr;
    [self _resetIdleTimer];
    _buttonView.hidden = YES;
    if (_dialView) _dialView.hidden = YES;
    
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
            _buttonView.hidden = NO;
            if (_dialView) _dialView.hidden = NO;
        });
    });
}

- (void)_handleVolumePan:(UIPanGestureRecognizer *)gr {
    if (!_volumeSlider) return;
    CGPoint location = [gr locationInView:self.floatingWindow]; 

    if (gr.state == UIGestureRecognizerStateBegan) {
        [self _wakeUp];
        [_dialDismissTimer invalidate];
        _dialDismissTimer = nil;
        
        _lastPanCoord = (_currentEdge == HKFDockEdgeTop) ? location.x : location.y;
        _currentVolume = _volumeSlider.value;
        _lastHapticStep = (int)(_currentVolume * 16.0);
        
        CGFloat W = [UIScreen mainScreen].bounds.size.width;
        CGRect dialFrame;
        if (_currentEdge == HKFDockEdgeTop) {
            dialFrame = CGRectMake(0, 0, 260, 48);
        } else {
            dialFrame = CGRectMake(0, 0, 48, 260);
        }
        
        if (!_dialView || _dialView.dockEdge != _currentEdge) {
            [_dialView removeFromSuperview];
            _dialView = [[HKFDialView alloc] initWithFrame:dialFrame edge:_currentEdge];
            _dialView.userInteractionEnabled = NO;
            [self.floatingWindow.rootViewController.view addSubview:_dialView];
        } else {
            [self.floatingWindow.rootViewController.view bringSubviewToFront:_dialView];
        }
        
        _dialView.transform = CGAffineTransformIdentity;
        if (_currentEdge == HKFDockEdgeTop) {
            _dialView.layer.anchorPoint = CGPointMake(0.5, 0.0);
            _dialView.frame = CGRectMake((W - 260.0) / 2.0, 0, 260, 48);
        } else if (_currentEdge == HKFDockEdgeLeft) {
            _dialView.layer.anchorPoint = CGPointMake(0.0, 0.5);
            _dialView.frame = CGRectMake(0, _buttonView.center.y - 130.0, 48, 260);
        } else {
            _dialView.layer.anchorPoint = CGPointMake(1.0, 0.5);
            _dialView.frame = CGRectMake(W - 48.0, _buttonView.center.y - 130.0, 48, 260);
        }

        [_dialView setVolume:_currentVolume];
        
        if (_dialView.alpha == 0.0) {
            _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);
        }
        
        [_dialView.layer removeAllAnimations];
        [_visualContainer.layer removeAllAnimations];
        
        if (_currentEdge == HKFDockEdgeTop) {
            _visualContainer.alpha = 0.0;
        }
        
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState animations:^{
            _dialView.transform = CGAffineTransformIdentity;
            _dialView.alpha = 1.0;
            if (_currentEdge == HKFDockEdgeTop) {
                _visualContainer.alpha = 0.0;
            }
        } completion:nil];
        
        [_heavyFeedback prepare];
        [_lightFeedback prepare];
        [_heavyFeedback impactOccurred];
        
        _dialDismissTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(_dismissDialView) userInfo:nil repeats:NO];
    } 
    else if (gr.state == UIGestureRecognizerStateChanged) {
        [_dialDismissTimer invalidate];
        _dialDismissTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(_dismissDialView) userInfo:nil repeats:NO];
        
        CGFloat currentCoord = (_currentEdge == HKFDockEdgeTop) ? location.x : location.y;
        CGFloat delta = currentCoord - _lastPanCoord; 
        _lastPanCoord = currentCoord;
        
        CGFloat vel = (_currentEdge == HKFDockEdgeTop) ? [gr velocityInView:self.floatingWindow].x : [gr velocityInView:self.floatingWindow].y;
        CGFloat speedMultiplier = 1.0 + MIN(fabs(vel) / 500.0, 3.0);
        
        float volumeChange = (-delta / 150.0) * speedMultiplier;
        
        _currentVolume += volumeChange;
        _currentVolume = MAX(0.0f, MIN(1.0f, _currentVolume));
        
        [_dialView setVolume:_currentVolume];
        
        [_volumeSlider setValue:_currentVolume animated:NO];
        [_volumeSlider sendActionsForControlEvents:UIControlEventValueChanged];
        
        int currentStep = (int)(_currentVolume * 16.0);
        if (currentStep != _lastHapticStep) {
            _lastHapticStep = currentStep;
            [_lightFeedback impactOccurred];
            [_lightFeedback prepare];
        }
    }
    else {
        [_volumeSlider sendActionsForControlEvents:UIControlEventTouchUpInside];
        [self _dismissDialView];
    }
}

- (void)_handleLongPressMove:(UILongPressGestureRecognizer *)gr {
    if (prefs_lockPosition) {
        [self _resetIdleTimer];
        return;
    }
    
    CGPoint location = [gr locationInView:self.floatingWindow];
    
    if (gr.state == UIGestureRecognizerStateBegan) {
        [self _dismissDialView];
        [self _wakeUp];
        _dragStartCenter = _buttonView.center;
        _dragStartTouch = location;
        
        CGFloat W = [UIScreen mainScreen].bounds.size.width;
        CGPoint popCenter = _buttonView.center;
        
        if (_currentEdge == HKFDockEdgeTop) {
            popCenter.y = 16.0;
        } else if (popCenter.x < W / 2.0) {
            popCenter.x = 16.0; 
        } else { 
            popCenter.x = W - 16.0; 
        }
        
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
            _buttonView.center = popCenter;
            _buttonView.transform = CGAffineTransformMakeScale(1.1, 1.1);
            _visualContainer.alpha = 1.0;
        } completion:nil];
        _dragStartCenter = popCenter;
        
        [_mediumFeedback prepare];
        [_mediumFeedback impactOccurred];
    }
    else if (gr.state == UIGestureRecognizerStateChanged) {
        CGFloat dx = location.x - _dragStartTouch.x;
        CGFloat dy = location.y - _dragStartTouch.y;
        _buttonView.center = CGPointMake(_dragStartCenter.x + dx, _dragStartCenter.y + dy);
        
        CGFloat H = [UIScreen mainScreen].bounds.size.height;
        HKFDockEdge edgePreview = HKFDockEdgeRight;
        if (_buttonView.center.y < H * 0.12) {
            edgePreview = HKFDockEdgeTop;
        } else {
            edgePreview = (_buttonView.center.x < [UIScreen mainScreen].bounds.size.width / 2.0) ? HKFDockEdgeLeft : HKFDockEdgeRight;
        }
        
        if (edgePreview != _currentEdge) {
            [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
                [self _updateShapeForEdge:edgePreview];
                [_lightFeedback impactOccurred];
            } completion:nil];
        }
    }
    else {
        CGFloat W = [UIScreen mainScreen].bounds.size.width;
        CGFloat H = [UIScreen mainScreen].bounds.size.height;
        CGPoint finalCenter = _buttonView.center;
        
        HKFDockEdge finalEdge;
        if (finalCenter.y < H * 0.12) {
            finalEdge = HKFDockEdgeTop;
            finalCenter.y = 16.0;
            CGFloat minX = 110.0;
            if (finalCenter.x < minX) finalCenter.x = minX;
            if (finalCenter.x > W - minX) finalCenter.x = W - minX;
        } else {
            if (finalCenter.x < W / 2.0) {
                finalEdge = HKFDockEdgeLeft;
                finalCenter.x = 16.0; 
            } else {
                finalEdge = HKFDockEdgeRight;
                finalCenter.x = W - 16.0;
            }
            
            CGFloat topSafeArea = 100.0;
            CGFloat bottomSafeArea = H - 50.0;
            if (finalCenter.y < topSafeArea) finalCenter.y = topSafeArea;
            if (finalCenter.y > bottomSafeArea) finalCenter.y = bottomSafeArea;
        }
        
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
            [self _updateShapeForEdge:finalEdge];
            _buttonView.center = finalCenter;
            _buttonView.transform = CGAffineTransformIdentity;
            if (finalEdge == HKFDockEdgeTop) {
                _visualContainer.alpha = 0.0;
            } else {
                _visualContainer.alpha = 1.0;
            }
        } completion:^(BOOL finished){
            if (finalEdge == HKFDockEdgeTop) {
                _isIdle = YES;
            }
        }];
        if (finalEdge != HKFDockEdgeTop) {
            [self _resetIdleTimer];
        }
    }
}
@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[HKFFloatingManager sharedInstance] setup];
    });
}

- (void)frontDisplayDidChange:(id)newDisplay {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = [HKFFloatingManager sharedInstance].floatingWindow;
        if (win) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *ws = (UIWindowScene *)s;
                    if (ws.activationState == UISceneActivationStateForegroundActive) {
                        if (win.windowScene != ws) {
                            win.windowScene = ws;
                        }
                        break;
                    }
                }
            }
        }
    });
}
%end

%group StatusBarHook
%hook SBMainDisplaySceneLayoutStatusBarView
- (void)_statusBarTapped:(id)arg1 type:(NSInteger)arg2 {
    CGPoint pt = CGPointZero;
    if ([arg1 respondsToSelector:@selector(locationInView:)]) {
        pt = [arg1 locationInView:nil];
    }
    if ([[HKFFloatingManager sharedInstance] isPointInTweakArea:pt]) {
        [[HKFFloatingManager sharedInstance] handleExternalStatusBarTap];
        return;
    }
    %orig;
}
%end
%end

%ctor {
    %init;
    if (objc_getClass("SBMainDisplaySceneLayoutStatusBarView")) {
        %init(StatusBarHook);
    }
}
