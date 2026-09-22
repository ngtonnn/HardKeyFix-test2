#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

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

// --- Enum ---
typedef NS_ENUM(NSInteger, HKFDockEdge) {
    HKFDockEdgeLeft = 0,
    HKFDockEdgeRight,
    HKFDockEdgeTop
};

// --- Hardcoded Preferences ---
static const BOOL prefs_lockPosition = NO;
static const CGFloat prefs_idleOpacity = 0.3; 
static const CGFloat prefs_idleTimeout = 0.5; 
static const CGFloat prefs_buttonSize = 55.0; 
static const CGFloat prefs_dialSize = 180.0; 
static const CGFloat prefs_sensitivity = 1.0;

// --- Dial View ---
@interface HKFDialView : UIView
@property (nonatomic, strong) UIView *wheelView;
@property (nonatomic, assign) HKFDockEdge dockEdge;
- (instancetype)initWithFrame:(CGRect)frame edge:(HKFDockEdge)edge;
- (void)setVolume:(float)volume;
@end

@implementation HKFDialView
- (instancetype)initWithFrame:(CGRect)frame edge:(HKFDockEdge)edge {
    self = [super initWithFrame:frame];
    if (self) {
        _dockEdge = edge;
        
        _wheelView = [[UIView alloc] initWithFrame:self.bounds];
        _wheelView.layer.cornerRadius = frame.size.width / 2.0;
        _wheelView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
        
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = _wheelView.bounds;
        blurView.layer.cornerRadius = frame.size.width / 2.0;
        blurView.clipsToBounds = YES;
        [_wheelView addSubview:blurView];
        
        CGFloat radius = frame.size.width / 2.0;
        CGPoint center = CGPointMake(radius, radius);
        
        for (int i = 0; i <= 40; i++) {
            UIView *wrapper = [[UIView alloc] initWithFrame:self.bounds];
            UIView *tick = [[UIView alloc] init];
            
            BOOL isMajor = (i % 10 == 0);
            tick.backgroundColor = isMajor ? [UIColor whiteColor] : [UIColor colorWithWhite:0.6 alpha:1.0];
            
            CGFloat tickW = isMajor ? 16.0 : 8.0;
            CGFloat tickH = 2.0;
            
            tick.frame = CGRectMake(frame.size.width - tickW - 4, (frame.size.height - tickH) / 2.0, tickW, tickH);
            tick.layer.cornerRadius = 1.0;
            [wrapper addSubview:tick];
            
            CGFloat tickAngle;
            if (edge == HKFDockEdgeLeft) {
                tickAngle = (M_PI / 2.0) - (i / 40.0) * M_PI;
            } else if (edge == HKFDockEdgeRight) {
                tickAngle = (M_PI / 2.0) + (i / 40.0) * M_PI;
            } else { // Top
                tickAngle = M_PI - (i / 40.0) * M_PI;
            }
            
            wrapper.transform = CGAffineTransformMakeRotation(tickAngle);
            [_wheelView addSubview:wrapper];
            
            if (isMajor) {
                UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 30, 20)];
                int volNum = 100 - (i * 100 / 40);
                if (edge == HKFDockEdgeTop) {
                    volNum = (i * 100 / 40); // 0 at left (i=0), 100 at right (i=40)
                }
                lbl.text = [NSString stringWithFormat:@"%d", volNum];
                lbl.textColor = [UIColor whiteColor];
                lbl.font = [UIFont boldSystemFontOfSize:12];
                lbl.textAlignment = NSTextAlignmentCenter;
                
                lbl.center = CGPointMake(frame.size.width - 36, frame.size.height / 2.0);
                [wrapper addSubview:lbl];
                lbl.transform = CGAffineTransformMakeRotation(-tickAngle); 
            }
        }
        
        [self addSubview:_wheelView];
        
        // --- Marker ---
        UIView *marker = [[UIView alloc] init];
        marker.backgroundColor = [UIColor systemYellowColor];
        marker.layer.cornerRadius = 1.5;
        
        marker.layer.shadowColor = [UIColor blackColor].CGColor;
        marker.layer.shadowOffset = CGSizeMake(0, 1);
        marker.layer.shadowOpacity = 0.8;
        marker.layer.shadowRadius = 1.5;
        
        CGFloat markerW = 18.0;
        CGFloat markerH = 3.0;
        
        if (edge == HKFDockEdgeLeft) {
            marker.frame = CGRectMake(frame.size.width - markerW - 2, (frame.size.height - markerH) / 2.0, markerW, markerH);
        } else if (edge == HKFDockEdgeRight) {
            marker.frame = CGRectMake(2, (frame.size.height - markerH) / 2.0, markerW, markerH);
        } else {
            marker.frame = CGRectMake((frame.size.width - markerH) / 2.0, 2, markerH, markerW);
        }
        
        [self addSubview:marker];
    }
    return self;
}

- (void)setVolume:(float)volume {
    CGFloat angle;
    if (_dockEdge == HKFDockEdgeTop) {
        angle = (volume - 0.5) * M_PI; // Middle is 0, Right is M_PI/2, Left is -M_PI/2
    } else {
        angle = (volume - 0.5) * M_PI;
        if (_dockEdge == HKFDockEdgeLeft) {
            angle = -angle;
        }
    }
    _wheelView.transform = CGAffineTransformMakeRotation(angle);
}
@end


// --- System HUD Hider (Hook) ---
%hook SBVolumeControl
- (void)presentVolumeHUDWithVolume:(float)arg1 {}
- (void)_presentVolumeHUDWithVolume:(float)arg1 {}
%end


// --- Floating Widget Controller ---

@interface HKFFloatingManager : NSObject
@property (nonatomic, strong) UIWindow *floatingWindow;
+ (instancetype)sharedInstance;
- (void)setup;
@end

@implementation HKFFloatingManager {
    UIView *_buttonView;
    UIVisualEffectView *_blurView;
    UIView *_innerRing;
    UIView *_centerDot;
    
    NSTimer *_idleTimer;
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

- (void)_updateShapeForEdge:(HKFDockEdge)edge {
    _currentEdge = edge;
    CGFloat btnSize = prefs_buttonSize;
    CGSize newSize = (edge == HKFDockEdgeTop) ? CGSizeMake(120, 36) : CGSizeMake(btnSize, btnSize);
    
    self.floatingWindow.bounds = CGRectMake(0, 0, newSize.width, newSize.height);
    _buttonView.frame = self.floatingWindow.bounds;
    
    CGFloat cornerRadius = (edge == HKFDockEdgeTop) ? 18.0 : btnSize / 2.0;
    _buttonView.layer.cornerRadius = cornerRadius;
    _blurView.frame = _buttonView.bounds;
    _blurView.layer.cornerRadius = cornerRadius;
    
    _innerRing.frame = CGRectInset(_buttonView.bounds, 6, 6);
    _innerRing.layer.cornerRadius = (edge == HKFDockEdgeTop) ? 12.0 : _innerRing.bounds.size.width / 2.0;
    
    if (edge == HKFDockEdgeTop) {
        _centerDot.frame = CGRectInset(_buttonView.bounds, 26, 12);
        _centerDot.layer.cornerRadius = 6.0;
    } else {
        _centerDot.frame = CGRectInset(_buttonView.bounds, 16, 16);
        _centerDot.layer.cornerRadius = _centerDot.bounds.size.width / 2.0;
    }
}

- (void)setup {
    UIWindowScene *targetScene = nil;
    for (UIWindowScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.screen == [UIScreen mainScreen]) {
            targetScene = s;
            break;
        }
    }
    
    CGFloat btnSize = prefs_buttonSize;
    CGFloat W = [UIScreen mainScreen].bounds.size.width;
    CGFloat H = [UIScreen mainScreen].bounds.size.height;
    
    CGRect windowFrame = CGRectMake(W - btnSize - 2, H / 2.0 - btnSize / 2.0, btnSize, btnSize);
    
    if (targetScene) {
        self.floatingWindow = [[UIWindow alloc] initWithWindowScene:targetScene];
        self.floatingWindow.frame = windowFrame;
    } else {
        self.floatingWindow = [[UIWindow alloc] initWithFrame:windowFrame];
    }
    
    self.floatingWindow.backgroundColor = [UIColor clearColor];
    self.floatingWindow.windowLevel = 9999999.0;
    self.floatingWindow.userInteractionEnabled = YES;
    self.floatingWindow.clipsToBounds = NO; 
    
    UIViewController *rootVC = [UIViewController new];
    rootVC.view.backgroundColor = [UIColor clearColor];
    rootVC.view.clipsToBounds = NO;
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

    _buttonView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, btnSize, btnSize)];
    _buttonView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
    _buttonView.layer.masksToBounds = NO;
    _buttonView.layer.borderWidth = 1.0;
    _buttonView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.1].CGColor;
    _buttonView.layer.shadowColor = [UIColor whiteColor].CGColor;
    _buttonView.layer.shadowOffset = CGSizeZero;
    _buttonView.layer.shadowOpacity = 0.5;
    _buttonView.layer.shadowRadius = 8.0;
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    _blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    _blurView.clipsToBounds = YES;
    _blurView.userInteractionEnabled = NO;
    [_buttonView addSubview:_blurView];
    
    _innerRing = [[UIView alloc] init];
    _innerRing.layer.borderWidth = 1.5;
    _innerRing.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.4].CGColor;
    _innerRing.userInteractionEnabled = NO;
    [_buttonView addSubview:_innerRing];
    
    _centerDot = [[UIView alloc] init];
    _centerDot.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    _centerDot.userInteractionEnabled = NO;
    [_buttonView addSubview:_centerDot];
    
    [rootVC.view addSubview:_buttonView];
    
    [self _updateShapeForEdge:HKFDockEdgeRight]; // Default
    
    _buttonView.alpha = prefs_idleOpacity;
    _isIdle = YES;

    UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleDoubleTap:)];
    tapGR.numberOfTapsRequired = 2;
    [_buttonView addGestureRecognizer:tapGR];

    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handleVolumePan:)];
    [_buttonView addGestureRecognizer:panGR];

    UILongPressGestureRecognizer *longPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_handleLongPressMove:)];
    longPressGR.minimumPressDuration = 0.5;
    [_buttonView addGestureRecognizer:longPressGR];

    self.floatingWindow.hidden = NO;
    [self _resetIdleTimer];
}

- (void)_resetIdleTimer {
    [_idleTimer invalidate];
    _idleTimer = [NSTimer scheduledTimerWithTimeInterval:prefs_idleTimeout target:self selector:@selector(_idleTimerFired) userInfo:nil repeats:NO];
}

- (void)_idleTimerFired {
    if (_isIdle) return;
    _isIdle = YES;
    
    [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        _buttonView.alpha = prefs_idleOpacity;
        CGFloat W = [UIScreen mainScreen].bounds.size.width;
        CGPoint center = self.floatingWindow.center;
        
        if (_currentEdge == HKFDockEdgeTop) {
            center.y = 50.0;
        } else if (_currentEdge == HKFDockEdgeLeft) {
            center.x = (prefs_buttonSize / 2.0) + 2; 
        } else {
            center.x = W - (prefs_buttonSize / 2.0) - 2;
        }
        
        self.floatingWindow.center = center;
    } completion:nil];
}

- (void)_wakeUp {
    [_idleTimer invalidate];
    if (!_isIdle) return;
    _isIdle = NO;
    
    [UIView animateWithDuration:0.2 animations:^{
        _buttonView.alpha = 1.0;
    }];
}

- (void)_handleDoubleTap:(UITapGestureRecognizer *)gr {
    [self _resetIdleTimer];
    
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
            self.floatingWindow.hidden = NO;
        });
    });
}

- (void)_handleVolumePan:(UIPanGestureRecognizer *)gr {
    [self _wakeUp];
    CGPoint location = [gr locationInView:nil]; 
    
    if (!_volumeSlider) return;

    if (gr.state == UIGestureRecognizerStateBegan) {
        _lastPanCoord = (_currentEdge == HKFDockEdgeTop) ? location.x : location.y;
        _currentVolume = _volumeSlider.value;
        _lastHapticStep = (int)(_currentVolume * 16.0);
        
        _dialView = [[HKFDialView alloc] initWithFrame:CGRectMake(0, 0, prefs_dialSize, prefs_dialSize) edge:_currentEdge];
        
        if (_currentEdge == HKFDockEdgeTop) {
            _dialView.center = CGPointMake(_buttonView.bounds.size.width / 2.0, _buttonView.bounds.size.height / 2.0); 
        } else {
            _dialView.center = CGPointMake(prefs_buttonSize / 2.0, prefs_buttonSize / 2.0); 
        }
        
        [_dialView setVolume:_currentVolume];
        
        _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);
        _dialView.alpha = 0.0;
        [self.floatingWindow.rootViewController.view insertSubview:_dialView belowSubview:_buttonView];
        
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            _dialView.transform = CGAffineTransformIdentity;
            _dialView.alpha = 1.0;
            _buttonView.alpha = 0.0;
        } completion:nil];
        
        [_heavyFeedback prepare];
        [_lightFeedback prepare];
        [_heavyFeedback impactOccurred];
        
    } 
    else if (gr.state == UIGestureRecognizerStateChanged) {
        CGFloat currentCoord = (_currentEdge == HKFDockEdgeTop) ? location.x : location.y;
        CGFloat delta = currentCoord - _lastPanCoord; 
        _lastPanCoord = currentCoord;
        
        CGFloat vel = (_currentEdge == HKFDockEdgeTop) ? [gr velocityInView:nil].x : [gr velocityInView:nil].y;
        CGFloat speedMultiplier = 1.0 + MIN(fabs(vel) / 500.0, 3.0);
        
        float volumeChange;
        if (_currentEdge == HKFDockEdgeTop) {
            volumeChange = (delta / 150.0) * prefs_sensitivity * speedMultiplier;
        } else {
            volumeChange = (-delta / 150.0) * prefs_sensitivity * speedMultiplier;
        }
        
        _currentVolume += volumeChange;
        _currentVolume = MAX(0.0f, MIN(1.0f, _currentVolume));
        
        [_dialView setVolume:_currentVolume];
        
        [_volumeSlider setValue:_currentVolume animated:NO];
        [_volumeSlider sendActionsForControlEvents:UIControlEventTouchUpInside];
        
        int currentStep = (int)(_currentVolume * 16.0);
        if (currentStep != _lastHapticStep) {
            _lastHapticStep = currentStep;
            [_lightFeedback impactOccurred];
            [_lightFeedback prepare];
        }
    }
    else {
        [UIView animateWithDuration:0.3 animations:^{
            _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);
            _dialView.alpha = 0.0;
            _buttonView.alpha = 1.0;
        } completion:^(BOOL finished) {
            [_dialView removeFromSuperview];
            _dialView = nil;
        }];
        [self _resetIdleTimer];
    }
}

- (void)_handleLongPressMove:(UILongPressGestureRecognizer *)gr {
    [self _wakeUp];
    if (prefs_lockPosition) {
        [self _resetIdleTimer];
        return;
    }
    
    CGPoint location = [gr locationInView:nil];
    
    if (gr.state == UIGestureRecognizerStateBegan) {
        _dragStartCenter = self.floatingWindow.center;
        _dragStartTouch = location;
        
        CGFloat W = [UIScreen mainScreen].bounds.size.width;
        CGPoint popCenter = self.floatingWindow.center;
        
        if (_currentEdge == HKFDockEdgeTop) {
            popCenter.y = 50.0;
        } else if (popCenter.x < W / 2.0) {
            popCenter.x = (prefs_buttonSize / 2.0) + 2; 
        } else { 
            popCenter.x = W - (prefs_buttonSize / 2.0) - 2; 
        }
        
        [UIView animateWithDuration:0.2 animations:^{
            self.floatingWindow.center = popCenter;
            self.floatingWindow.transform = CGAffineTransformMakeScale(1.1, 1.1);
        }];
        _dragStartCenter = popCenter;
        
        [_mediumFeedback prepare];
        [_mediumFeedback impactOccurred];
    }
    else if (gr.state == UIGestureRecognizerStateChanged) {
        CGFloat dx = location.x - _dragStartTouch.x;
        CGFloat dy = location.y - _dragStartTouch.y;
        self.floatingWindow.center = CGPointMake(_dragStartCenter.x + dx, _dragStartCenter.y + dy);
        
        // Dynamically preview shape change
        CGFloat H = [UIScreen mainScreen].bounds.size.height;
        HKFDockEdge edgePreview = HKFDockEdgeRight;
        if (self.floatingWindow.center.y < H * 0.12) {
            edgePreview = HKFDockEdgeTop;
        } else {
            edgePreview = (self.floatingWindow.center.x < [UIScreen mainScreen].bounds.size.width / 2.0) ? HKFDockEdgeLeft : HKFDockEdgeRight;
        }
        
        if (edgePreview != _currentEdge) {
            [UIView animateWithDuration:0.2 animations:^{
                [self _updateShapeForEdge:edgePreview];
                [_lightFeedback impactOccurred];
            }];
        }
    }
    else {
        CGFloat W = [UIScreen mainScreen].bounds.size.width;
        CGFloat H = [UIScreen mainScreen].bounds.size.height;
        CGPoint finalCenter = self.floatingWindow.center;
        
        HKFDockEdge finalEdge;
        if (finalCenter.y < H * 0.12) {
            finalEdge = HKFDockEdgeTop;
            finalCenter.y = 50.0;
            // Keep X where they dropped it, clamped to bounds
            if (finalCenter.x < 60) finalCenter.x = 60;
            if (finalCenter.x > W - 60) finalCenter.x = W - 60;
        } else {
            CGFloat radius = prefs_buttonSize / 2.0;
            if (finalCenter.x < W / 2.0) {
                finalEdge = HKFDockEdgeLeft;
                finalCenter.x = radius + 2; 
            } else {
                finalEdge = HKFDockEdgeRight;
                finalCenter.x = W - radius - 2;
            }
            
            CGFloat topSafeArea = 100.0;
            CGFloat bottomSafeArea = H - 50.0 - radius;
            if (finalCenter.y < topSafeArea) finalCenter.y = topSafeArea;
            if (finalCenter.y > bottomSafeArea) finalCenter.y = bottomSafeArea;
        }
        
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            [self _updateShapeForEdge:finalEdge];
            self.floatingWindow.center = finalCenter;
            self.floatingWindow.transform = CGAffineTransformIdentity;
        } completion:nil];
        [self _resetIdleTimer];
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
%end
