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
static const CGFloat prefs_idleTimeout = 0.5; // Đã đổi thành 0.5s theo yêu cầu
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
        
        // 40 steps from +M_PI/2 to -M_PI/2 (180 degrees)
        for (int i = 0; i <= 40; i++) {
            UIView *wrapper = [[UIView alloc] initWithFrame:self.bounds];
            UIView *tick = [[UIView alloc] init];
            
            BOOL isMajor = (i % 10 == 0);
            tick.backgroundColor = isMajor ? [UIColor whiteColor] : [UIColor colorWithWhite:0.6 alpha:1.0];
            
            CGFloat tickW = isMajor ? 16.0 : 8.0;
            CGFloat tickH = 2.0;
            
            if (isLeft) {
                tick.frame = CGRectMake(frame.size.width - tickW - 4, (frame.size.height - tickH) / 2.0, tickW, tickH);
            } else {
                tick.frame = CGRectMake(4, (frame.size.height - tickH) / 2.0, tickW, tickH);
            }
            
            tick.layer.cornerRadius = 1.0;
            [wrapper addSubview:tick];
            
            // i=0 -> 100%, i=40 -> 0%
            // 100% vẽ ở +90 độ (dưới cùng). 0% vẽ ở -90 độ (trên cùng)
            CGFloat tickAngle = (M_PI / 2.0) - (i / 40.0) * M_PI;
            wrapper.transform = CGAffineTransformMakeRotation(tickAngle);
            [_wheelView addSubview:wrapper];
            
            // Vẽ số
            if (isMajor) {
                UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 30, 20)];
                int volNum = 100 - (i * 100 / 40);
                lbl.text = [NSString stringWithFormat:@"%d", volNum];
                lbl.textColor = [UIColor whiteColor];
                lbl.font = [UIFont boldSystemFontOfSize:12];
                lbl.textAlignment = NSTextAlignmentCenter;
                
                if (isLeft) {
                    lbl.center = CGPointMake(frame.size.width - 34, frame.size.height / 2.0);
                } else {
                    lbl.center = CGPointMake(34, frame.size.height / 2.0);
                }
                [wrapper addSubview:lbl];
                lbl.transform = CGAffineTransformMakeRotation(-tickAngle); // Giữ số luôn thẳng đứng so với tâm
            }
        }
        
        [self addSubview:_wheelView];
    }
    return self;
}

- (void)setVolume:(float)volume {
    // volume 0.0 -> quay +90 độ. volume 1.0 -> quay -90 độ.
    // Xoay ngược chiều kim đồng hồ khi tăng âm lượng (Vuốt lên -> Bánh xe xoay lên)
    CGFloat angle = -(volume - 0.5) * M_PI;
    _wheelView.transform = CGAffineTransformMakeRotation(angle);
}
@end


// --- Floating Widget ---
@interface HKFFloatingWindow : UIWindow <UIGestureRecognizerDelegate>
@end

@implementation HKFFloatingWindow {
    UIView *_buttonView;
    NSTimer *_idleTimer;
    BOOL _isIdle;
    
    // Volume & Dial
    float _currentVolume;
    CGFloat _lastPanY;
    int _lastHapticStep;
    MPVolumeView *_hiddenVolumeView;
    UISlider *_volumeSlider;
    HKFDialView *_dialView;
    
    // Dragging
    CGPoint _dragStartCenter;
    CGPoint _dragStartTouch;
}

- (instancetype)init {
    UIWindowScene *scene = nil;
    for (UIWindowScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) {
            scene = s;
            break;
        }
    }
    if (scene) {
        self = [super initWithWindowScene:scene];
    } else {
        self = [super initWithFrame:[UIScreen mainScreen].bounds];
    }
    if (self) {
        [self _setup];
    }
    return self;
}

- (void)_setup {
    self.frame = [UIScreen mainScreen].bounds;
    self.backgroundColor = [UIColor clearColor];
    self.windowLevel = UIWindowLevelStatusBar + 1000;
    self.userInteractionEnabled = YES;
    self.hidden = NO;

    UIViewController *rootVC = [UIViewController new];
    rootVC.view.backgroundColor = [UIColor clearColor];
    self.rootViewController = rootVC;

    // --- Volume Controller ---
    // Đã hủy chức năng ẩn Volume HUD, trả lại trạng thái gốc của máy
    _hiddenVolumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    _hiddenVolumeView.alpha = 0.0; // Chỉ ẩn thanh UI ảo này, không ẩn HUD hệ thống
    _hiddenVolumeView.hidden = NO;
    _hiddenVolumeView.userInteractionEnabled = NO;
    [rootVC.view addSubview:_hiddenVolumeView];
    
    for (UIView *view in _hiddenVolumeView.subviews) {
        if ([view isKindOfClass:[UISlider class]]) {
            _volumeSlider = (UISlider *)view;
            break;
        }
    }

    // --- Floating Button ---
    CGFloat btnSize = prefs_buttonSize;
    _buttonView = [[UIView alloc] initWithFrame:CGRectMake(self.bounds.size.width, self.bounds.size.height / 2, btnSize, btnSize)];
    _buttonView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.9];
    _buttonView.layer.cornerRadius = btnSize / 2.0;
    _buttonView.layer.masksToBounds = YES;
    _buttonView.layer.borderWidth = 1.5;
    _buttonView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = _buttonView.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.userInteractionEnabled = NO;
    [_buttonView addSubview:blurView];
    
    [rootVC.view addSubview:_buttonView];
    
    _buttonView.center = CGPointMake(self.bounds.size.width, self.bounds.size.height / 2.0);
    _buttonView.alpha = prefs_idleOpacity;
    _isIdle = YES;

    // Gestures
    UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleDoubleTap:)];
    tapGR.numberOfTapsRequired = 2;
    [_buttonView addGestureRecognizer:tapGR];

    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handleVolumePan:)];
    [_buttonView addGestureRecognizer:panGR];

    UILongPressGestureRecognizer *longPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_handleLongPressMove:)];
    longPressGR.minimumPressDuration = 0.5;
    [_buttonView addGestureRecognizer:longPressGR];

    [self _resetIdleTimer];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return CGRectContainsPoint(_buttonView.frame, point) || (_dialView && CGRectContainsPoint(_dialView.frame, point));
}

// --- Idle ---
- (void)_resetIdleTimer {
    [_idleTimer invalidate];
    _idleTimer = [NSTimer scheduledTimerWithTimeInterval:prefs_idleTimeout target:self selector:@selector(_idleTimerFired) userInfo:nil repeats:NO];
}

- (void)_idleTimerFired {
    if (_isIdle) return;
    _isIdle = YES;
    
    [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        _buttonView.alpha = prefs_idleOpacity;
        CGFloat W = self.bounds.size.width;
        CGPoint center = _buttonView.center;
        center.x = (center.x < W / 2.0) ? 0 : W;
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

// --- Gestures ---
- (void)_handleDoubleTap:(UITapGestureRecognizer *)gr {
    [self _wakeUp];
    [self _resetIdleTimer];
    
    SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
    if ([sb respondsToSelector:@selector(screenshotManager)]) {
        id manager = [sb screenshotManager];
        if (manager && [manager respondsToSelector:@selector(saveScreenshotsWithCompletion:)]) {
            [manager saveScreenshotsWithCompletion:nil];
            return;
        }
    }
    Class shotterClass = objc_getClass("SBScreenShotter");
    if (shotterClass && [shotterClass respondsToSelector:@selector(sharedInstance)]) {
        [[shotterClass sharedInstance] saveScreenshot:YES];
    }
}

- (void)_handleVolumePan:(UIPanGestureRecognizer *)gr {
    [self _wakeUp];
    CGPoint location = [gr locationInView:self];
    
    if (!_volumeSlider) return;

    if (gr.state == UIGestureRecognizerStateBegan) {
        _lastPanY = location.y;
        _currentVolume = _volumeSlider.value;
        _lastHapticStep = (int)(_currentVolume * 16.0);
        
        CGFloat W = self.bounds.size.width;
        BOOL isLeft = (_buttonView.center.x < W / 2.0);
        
        _dialView = [[HKFDialView alloc] initWithFrame:CGRectMake(0, 0, prefs_dialSize, prefs_dialSize) isLeft:isLeft];
        _dialView.center = _buttonView.center;
        [_dialView setVolume:_currentVolume];
        
        _dialView.transform = CGAffineTransformMakeScale(0.1, 0.1);
        _dialView.alpha = 0.0;
        [self.rootViewController.view insertSubview:_dialView belowSubview:_buttonView];
        
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            _dialView.transform = CGAffineTransformIdentity;
            _dialView.alpha = 1.0;
            _buttonView.alpha = 0.0;
        } completion:nil];
        
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [feedback impactOccurred];
        
    } 
    else if (gr.state == UIGestureRecognizerStateChanged) {
        CGFloat deltaY = location.y - _lastPanY; 
        _lastPanY = location.y;
        
        CGFloat velY = [gr velocityInView:self].y;
        
        // Tốc độ vuốt càng nhanh, hệ số nhân càng lớn (Max x3)
        CGFloat speedMultiplier = 1.0 + MIN(fabs(velY) / 500.0, 3.0);
        
        // 150 pixel vuốt chậm = 100% âm lượng (180 độ bánh xe)
        float volumeChange = (-deltaY / 150.0) * prefs_sensitivity * speedMultiplier;
        
        _currentVolume += volumeChange;
        _currentVolume = MAX(0.0f, MIN(1.0f, _currentVolume));
        
        [_dialView setVolume:_currentVolume];
        
        // Cập nhật âm lượng liên tục để không bị kẹt khi vuốt chậm
        [_volumeSlider setValue:_currentVolume animated:NO];
        [_volumeSlider sendActionsForControlEvents:UIControlEventTouchUpInside];
        
        int currentStep = (int)(_currentVolume * 16.0);
        if (currentStep != _lastHapticStep) {
            _lastHapticStep = currentStep;
            UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [feedback impactOccurred];
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
    
    CGPoint location = [gr locationInView:self];
    
    if (gr.state == UIGestureRecognizerStateBegan) {
        _dragStartCenter = _buttonView.center;
        _dragStartTouch = location;
        
        CGFloat W = self.bounds.size.width;
        CGFloat radius = _buttonView.bounds.size.width / 2.0;
        CGPoint popCenter = _buttonView.center;
        if (popCenter.x < W / 2.0) { popCenter.x = radius + 5; } 
        else { popCenter.x = W - radius - 5; }
        
        [UIView animateWithDuration:0.2 animations:^{
            _buttonView.center = popCenter;
            _buttonView.transform = CGAffineTransformMakeScale(1.2, 1.2);
        }];
        _dragStartCenter = popCenter;
        
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
    }
    else if (gr.state == UIGestureRecognizerStateChanged) {
        CGFloat dx = location.x - _dragStartTouch.x;
        CGFloat dy = location.y - _dragStartTouch.y;
        _buttonView.center = CGPointMake(_dragStartCenter.x + dx, _dragStartCenter.y + dy);
    }
    else {
        CGFloat W = self.bounds.size.width;
        CGFloat H = self.bounds.size.height;
        CGPoint finalCenter = _buttonView.center;
        
        finalCenter.x = (finalCenter.x < W / 2.0) ? 0 : W;
        
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
        HKFFloatingWindow *win = [[HKFFloatingWindow alloc] init];
        objc_setAssociatedObject([UIApplication sharedApplication], "HKFFloatingWindowKey", win, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
}
%end
