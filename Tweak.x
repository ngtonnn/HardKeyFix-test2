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
@property (nonatomic, assign) BOOL isLeftEdge;
- (instancetype)initWithFrame:(CGRect)frame isLeft:(BOOL)isLeft;
- (void)setVolume:(float)volume;
@end

@implementation HKFDialView
- (instancetype)initWithFrame:(CGRect)frame isLeft:(BOOL)isLeft {
    self = [super initWithFrame:frame];
    if (self) {
        _isLeftEdge = isLeft;
        
        _wheelView = [[UIView alloc] initWithFrame:self.bounds];
        _wheelView.layer.cornerRadius = frame.size.width / 2.0;
        _wheelView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
        
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = _wheelView.bounds;
        blurView.layer.cornerRadius = frame.size.width / 2.0;
        blurView.clipsToBounds = YES;
        [_wheelView addSubview:blurView];
        
        // 40 steps from 100% to 0% (180 degrees)
        for (int i = 0; i <= 40; i++) {
            UIView *wrapper = [[UIView alloc] initWithFrame:self.bounds];
            UIView *tick = [[UIView alloc] init];
            
            BOOL isMajor = (i % 10 == 0);
            tick.backgroundColor = isMajor ? [UIColor whiteColor] : [UIColor colorWithWhite:0.6 alpha:1.0];
            
            CGFloat tickW = isMajor ? 16.0 : 8.0;
            CGFloat tickH = 2.0;
            
            // LUÔN VẼ Ở MÉP PHẢI CỦA WRAPPER
            tick.frame = CGRectMake(frame.size.width - tickW - 4, (frame.size.height - tickH) / 2.0, tickW, tickH);
            tick.layer.cornerRadius = 1.0;
            [wrapper addSubview:tick];
            
            CGFloat tickAngle;
            if (isLeft) {
                tickAngle = (M_PI / 2.0) - (i / 40.0) * M_PI;
            } else {
                tickAngle = (M_PI / 2.0) + (i / 40.0) * M_PI;
            }
            
            wrapper.transform = CGAffineTransformMakeRotation(tickAngle);
            [_wheelView addSubview:wrapper];
            
            if (isMajor) {
                UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 30, 20)];
                int volNum = 100 - (i * 100 / 40);
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
        
        if (isLeft) {
            marker.frame = CGRectMake(frame.size.width - markerW - 2, (frame.size.height - markerH) / 2.0, markerW, markerH);
        } else {
            marker.frame = CGRectMake(2, (frame.size.height - markerH) / 2.0, markerW, markerH);
        }
        
        [self addSubview:marker];
    }
    return self;
}

- (void)setVolume:(float)volume {
    CGFloat angle = (volume - 0.5) * M_PI;
    if (_isLeftEdge) {
        angle = -angle;
    }
    _wheelView.transform = CGAffineTransformMakeRotation(angle);
}
@end


// --- System HUD Hider (Hook) ---
// Hook thẳng vào SBVolumeControl để triệt tiêu vĩnh viễn thanh Volume HUD của Apple
%hook SBVolumeControl
- (void)presentVolumeHUDWithVolume:(float)arg1 {
    // Không làm gì cả -> Ẩn HUD
}
- (void)_presentVolumeHUDWithVolume:(float)arg1 {
    // Không làm gì cả -> Ẩn HUD
}
%end


// --- Floating Widget Controller ---

@interface HKFWindow : UIWindow
@property (nonatomic, weak) UIView *buttonView;
@property (nonatomic, weak) UIView *dialView;
@end

@implementation HKFWindow
- (BOOL)_canShowWhileLocked {
    return YES;
}
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.buttonView && CGRectContainsPoint(self.buttonView.frame, point)) return YES;
    if (self.dialView && CGRectContainsPoint(self.dialView.frame, point)) return YES;
    return NO; // Xuyên thấu cảm ứng xuống dưới
}
@end

// Root Controller vượt màn hình khóa
@interface HKFRootViewController : UIViewController
@end
@implementation HKFRootViewController
- (BOOL)_canShowWhileLocked {
    return YES;
}
@end


@interface HKFFloatingManager : NSObject
@property (nonatomic, strong) UIWindow *floatingWindow;
+ (instancetype)sharedInstance;
- (void)setup;
@end

@implementation HKFFloatingManager {
    UIView *_buttonView;
    NSTimer *_idleTimer;
    BOOL _isIdle;
    
    float _currentVolume;
    CGFloat _lastPanY;
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

- (void)setup {
    UIWindowScene *targetScene = nil;
    for (UIWindowScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.screen == [UIScreen mainScreen]) {
            targetScene = s;
            break;
        }
    }
    
    Class SecureWindowClass = NSClassFromString(@"SBSecureWindow");
    Class TargetWindowClass = SecureWindowClass ? SecureWindowClass : [UIWindow class];
    
    // Ghi đè class tại runtime để kế thừa SBSecureWindow nếu có, nếu không thì dùng HKFWindow
    // Tuy nhiên, cách an toàn nhất trên iOS 16 là dùng thẳng HKFWindow và gán _canShowWhileLocked.
    
    if (targetScene) {
        self.floatingWindow = [[HKFWindow alloc] initWithWindowScene:targetScene];
    } else {
        self.floatingWindow = [[HKFWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    
    self.floatingWindow.backgroundColor = [UIColor clearColor];
    self.floatingWindow.windowLevel = 9999999.0;
    self.floatingWindow.userInteractionEnabled = YES;
    
    HKFRootViewController *rootVC = [HKFRootViewController new];
    rootVC.view.backgroundColor = [UIColor clearColor];
    self.floatingWindow.rootViewController = rootVC;
    
    _lightFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    _heavyFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    _mediumFeedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];

    // MPVolumeView để lấy slider chỉnh âm lượng ngầm
    _hiddenVolumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(50, 50, 10, 10)];
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

    CGFloat btnSize = prefs_buttonSize;
    _buttonView = [[UIView alloc] initWithFrame:CGRectMake(self.floatingWindow.bounds.size.width - btnSize - 2, self.floatingWindow.bounds.size.height / 2, btnSize, btnSize)];
    _buttonView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
    _buttonView.layer.cornerRadius = btnSize / 2.0;
    _buttonView.layer.masksToBounds = NO;
    _buttonView.layer.borderWidth = 1.0;
    _buttonView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.1].CGColor;
    
    _buttonView.layer.shadowColor = [UIColor whiteColor].CGColor;
    _buttonView.layer.shadowOffset = CGSizeZero;
    _buttonView.layer.shadowOpacity = 0.5;
    _buttonView.layer.shadowRadius = 8.0;
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = _buttonView.bounds;
    blurView.layer.cornerRadius = btnSize / 2.0;
    blurView.clipsToBounds = YES;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.userInteractionEnabled = NO;
    [_buttonView addSubview:blurView];
    
    UIView *innerRing = [[UIView alloc] initWithFrame:CGRectInset(_buttonView.bounds, 6, 6)];
    innerRing.layer.cornerRadius = innerRing.bounds.size.width / 2.0;
    innerRing.layer.borderWidth = 1.5;
    innerRing.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.4].CGColor;
    innerRing.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    innerRing.userInteractionEnabled = NO;
    [_buttonView addSubview:innerRing];
    
    UIView *centerDot = [[UIView alloc] initWithFrame:CGRectInset(_buttonView.bounds, 16, 16)];
    centerDot.layer.cornerRadius = centerDot.bounds.size.width / 2.0;
    centerDot.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    centerDot.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    centerDot.userInteractionEnabled = NO;
    [_buttonView addSubview:centerDot];
    
    HKFWindow *passWin = (HKFWindow *)self.floatingWindow;
    passWin.buttonView = _buttonView; 
    [rootVC.view addSubview:_buttonView];
    
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
        CGFloat W = self.floatingWindow.bounds.size.width;
        CGFloat radius = _buttonView.bounds.size.width / 2.0;
        CGPoint center = _buttonView.center;
        
        if (center.x < W / 2.0) {
            center.x = radius + 2; 
        } else {
            center.x = W - radius - 2;
        }
        
        _buttonView.center = center;
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
    
    self.floatingWindow.hidden = YES; // Tạm ẩn cả Window
    
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
    CGPoint location = [gr locationInView:self.floatingWindow.rootViewController.view];
    
    if (!_volumeSlider) return;

    if (gr.state == UIGestureRecognizerStateBegan) {
        _lastPanY = location.y;
        _currentVolume = _volumeSlider.value;
        _lastHapticStep = (int)(_currentVolume * 16.0);
        
        CGFloat W = self.floatingWindow.bounds.size.width;
        BOOL isLeft = (_buttonView.center.x < W / 2.0);
        
        _dialView = [[HKFDialView alloc] initWithFrame:CGRectMake(0, 0, prefs_dialSize, prefs_dialSize) isLeft:isLeft];
        _dialView.center = _buttonView.center;
        [_dialView setVolume:_currentVolume];
        
        _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);
        _dialView.alpha = 0.0;
        [self.floatingWindow.rootViewController.view insertSubview:_dialView belowSubview:_buttonView];
        
        HKFWindow *passWin = (HKFWindow *)self.floatingWindow;
        passWin.dialView = _dialView; // Gắn reference
        
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
        CGFloat deltaY = location.y - _lastPanY; 
        _lastPanY = location.y;
        
        CGFloat velY = [gr velocityInView:self.floatingWindow.rootViewController.view].y;
        CGFloat speedMultiplier = 1.0 + MIN(fabs(velY) / 500.0, 3.0);
        
        float volumeChange = (-deltaY / 150.0) * prefs_sensitivity * speedMultiplier;
        
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
            HKFWindow *passWin = (HKFWindow *)self.floatingWindow;
            passWin.dialView = nil;
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
    
    CGPoint location = [gr locationInView:self.floatingWindow.rootViewController.view];
    
    if (gr.state == UIGestureRecognizerStateBegan) {
        _dragStartCenter = _buttonView.center;
        _dragStartTouch = location;
        
        CGFloat W = self.floatingWindow.bounds.size.width;
        CGFloat radius = _buttonView.bounds.size.width / 2.0;
        CGPoint popCenter = _buttonView.center;
        if (popCenter.x < W / 2.0) { popCenter.x = radius + 2; } 
        else { popCenter.x = W - radius - 2; }
        
        [UIView animateWithDuration:0.2 animations:^{
            _buttonView.center = popCenter;
            _buttonView.transform = CGAffineTransformMakeScale(1.2, 1.2);
        }];
        _dragStartCenter = popCenter;
        
        [_mediumFeedback prepare];
        [_mediumFeedback impactOccurred];
    }
    else if (gr.state == UIGestureRecognizerStateChanged) {
        CGFloat dx = location.x - _dragStartTouch.x;
        CGFloat dy = location.y - _dragStartTouch.y;
        _buttonView.center = CGPointMake(_dragStartCenter.x + dx, _dragStartCenter.y + dy);
    }
    else {
        CGFloat W = self.floatingWindow.bounds.size.width;
        CGFloat H = self.floatingWindow.bounds.size.height;
        CGFloat radius = _buttonView.bounds.size.width / 2.0;
        CGPoint finalCenter = _buttonView.center;
        
        if (finalCenter.x < W / 2.0) {
            finalCenter.x = radius + 2; 
        } else {
            finalCenter.x = W - radius - 2;
        }
        
        CGFloat topSafeArea = 50.0;
        CGFloat bottomSafeArea = H - 50.0;
        if (finalCenter.y < topSafeArea) finalCenter.y = topSafeArea;
        if (finalCenter.y > bottomSafeArea) finalCenter.y = bottomSafeArea;
        
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            _buttonView.center = finalCenter;
            _buttonView.transform = CGAffineTransformIdentity;
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
