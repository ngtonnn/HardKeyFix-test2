#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// --- Private APIs ---
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

// --- Preferences ---
static BOOL prefs_lockPosition = NO;
static CGFloat prefs_idleOpacity = 0.4;
static CGFloat prefs_idleTimeout = 3.0;

static void ReloadPrefs() {
    CFPreferencesAppSynchronize(CFSTR("com.yourname.hardkeyfix"));
    id lockPos = (__bridge id)CFPreferencesCopyAppValue(CFSTR("lockPosition"), CFSTR("com.yourname.hardkeyfix"));
    if (lockPos) prefs_lockPosition = [lockPos boolValue];
    
    id opacity = (__bridge id)CFPreferencesCopyAppValue(CFSTR("idleOpacity"), CFSTR("com.yourname.hardkeyfix"));
    if (opacity) prefs_idleOpacity = [opacity floatValue];
    
    id timeout = (__bridge id)CFPreferencesCopyAppValue(CFSTR("idleTimeout"), CFSTR("com.yourname.hardkeyfix"));
    if (timeout) prefs_idleTimeout = [timeout floatValue];
}

// --- Floating Widget ---
@interface HKFFloatingWindow : UIWindow <UIGestureRecognizerDelegate>
@end

@implementation HKFFloatingWindow {
    UIView *_buttonView;
    NSTimer *_idleTimer;
    BOOL _isIdle;
    
    // Volume
    float _volumeAtGestureStart;
    CGFloat _panStartY;
    int _lastHapticStep;
    MPVolumeView *_hiddenVolumeView;
    UISlider *_volumeSlider;
    
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
    _hiddenVolumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    _hiddenVolumeView.alpha = 0.0;
    _hiddenVolumeView.clipsToBounds = YES;
    _hiddenVolumeView.userInteractionEnabled = NO;
    [rootVC.view addSubview:_hiddenVolumeView];
    for (UIView *view in _hiddenVolumeView.subviews) {
        if ([view isKindOfClass:[UISlider class]]) {
            _volumeSlider = (UISlider *)view;
            break;
        }
    }

    // --- Floating Button ---
    CGFloat btnSize = 55.0;
    _buttonView = [[UIView alloc] initWithFrame:CGRectMake(self.bounds.size.width - btnSize - 10, self.bounds.size.height / 2, btnSize, btnSize)];
    _buttonView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.9];
    _buttonView.layer.cornerRadius = btnSize / 2.0;
    _buttonView.layer.masksToBounds = YES;
    _buttonView.layer.borderWidth = 1.5;
    _buttonView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    
    // Thêm hiệu ứng mờ (blur)
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = _buttonView.bounds;
    blurView.userInteractionEnabled = NO;
    [_buttonView addSubview:blurView];
    
    [rootVC.view addSubview:_buttonView];

    // --- Gestures ---
    // 1. Double Tap -> Screenshot
    UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleDoubleTap:)];
    tapGR.numberOfTapsRequired = 2;
    [_buttonView addGestureRecognizer:tapGR];

    // 2. Pan -> Volume
    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handleVolumePan:)];
    [_buttonView addGestureRecognizer:panGR];

    // 3. Long Press -> Move
    UILongPressGestureRecognizer *longPressGR = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_handleLongPressMove:)];
    longPressGR.minimumPressDuration = 0.5;
    [_buttonView addGestureRecognizer:longPressGR];

    // Lắng nghe thay đổi cài đặt
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_prefsChanged) name:@"com.yourname.hardkeyfix/ReloadPrefs" object:nil];
    
    _isIdle = NO;
    [self _resetIdleTimer];
}

- (void)_prefsChanged {
    ReloadPrefs();
    [self _resetIdleTimer];
}

// Xuyên thấu cảm ứng, chỉ bắt trên nút
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return CGRectContainsPoint(_buttonView.frame, point);
}

// --- Trạng thái nghỉ (Idle) ---
- (void)_resetIdleTimer {
    [_idleTimer invalidate];
    _idleTimer = [NSTimer scheduledTimerWithTimeInterval:prefs_idleTimeout target:self selector:@selector(_idleTimerFired) userInfo:nil repeats:NO];
}

- (void)_idleTimerFired {
    if (_isIdle) return;
    _isIdle = YES;
    
    [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        _buttonView.alpha = prefs_idleOpacity;
        
        // Edge Docking (Tự động lún vào viền 1 nửa)
        CGFloat W = self.bounds.size.width;
        CGPoint center = _buttonView.center;
        if (center.x < W / 2.0) {
            center.x = 0; // lún vào mép trái
        } else {
            center.x = W; // lún vào mép phải
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
        
        // Kéo ra khỏi viền
        CGFloat W = self.bounds.size.width;
        CGFloat radius = _buttonView.bounds.size.width / 2.0;
        CGPoint center = _buttonView.center;
        if (center.x < W / 2.0) {
            center.x = radius + 5;
        } else {
            center.x = W - radius - 5;
        }
        _buttonView.center = center;
    }];
}

// --- Cử chỉ ---

// 1. Chụp màn hình
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

// 2. Vuốt âm lượng
- (void)_handleVolumePan:(UIPanGestureRecognizer *)gr {
    [self _wakeUp];
    CGPoint location = [gr locationInView:self];
    
    if (gr.state == UIGestureRecognizerStateBegan) {
        _panStartY = location.y;
        _volumeAtGestureStart = _volumeSlider ? _volumeSlider.value : 0.5;
        _lastHapticStep = 0;
    } 
    else if (gr.state == UIGestureRecognizerStateChanged) {
        CGFloat deltaY = location.y - _panStartY; // Vuốt lên -> delta âm
        
        // 20 pixel cho 1 nấc âm lượng (1 nấc = 0.0625)
        int steps = (int)(-deltaY / 20.0);
        
        if (steps != _lastHapticStep) {
            _lastHapticStep = steps;
            
            // Rung phản hồi
            UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [feedback impactOccurred];
            
            float newVol = _volumeAtGestureStart + (steps * 0.0625);
            newVol = MAX(0.0f, MIN(1.0f, newVol));
            
            if (_volumeSlider) {
                [_volumeSlider setValue:newVol animated:NO];
                [_volumeSlider sendActionsForControlEvents:UIControlEventTouchUpInside];
            }
        }
    }
    else {
        [self _resetIdleTimer];
    }
}

// 3. Nhấn giữ để kéo di chuyển
- (void)_handleLongPressMove:(UILongPressGestureRecognizer *)gr {
    [self _wakeUp];
    
    if (prefs_lockPosition) {
        [self _resetIdleTimer];
        return; // Khóa vị trí thì không cho di chuyển
    }
    
    CGPoint location = [gr locationInView:self];
    
    if (gr.state == UIGestureRecognizerStateBegan) {
        _dragStartCenter = _buttonView.center;
        _dragStartTouch = location;
        
        // Phóng to nhẹ để báo hiệu đang di chuyển
        [UIView animateWithDuration:0.2 animations:^{
            _buttonView.transform = CGAffineTransformMakeScale(1.1, 1.1);
        }];
        
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
    }
    else if (gr.state == UIGestureRecognizerStateChanged) {
        CGFloat dx = location.x - _dragStartTouch.x;
        CGFloat dy = location.y - _dragStartTouch.y;
        _buttonView.center = CGPointMake(_dragStartCenter.x + dx, _dragStartCenter.y + dy);
    }
    else { // Ended / Cancelled
        // Giới hạn trong Safe Area và hút về viền gần nhất
        CGFloat W = self.bounds.size.width;
        CGFloat H = self.bounds.size.height;
        CGFloat radius = _buttonView.bounds.size.width / 2.0;
        
        CGPoint finalCenter = _buttonView.center;
        
        // Hút ngang
        if (finalCenter.x < W / 2.0) {
            finalCenter.x = radius + 5;
        } else {
            finalCenter.x = W - radius - 5;
        }
        
        // Giới hạn dọc (tránh tai thỏ và home bar)
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
    ReloadPrefs();
    
    // Đăng ký nhận thông báo thay đổi cấu hình từ file
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)ReloadPrefs, CFSTR("com.yourname.hardkeyfix/ReloadPrefs"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        HKFFloatingWindow *win = [[HKFFloatingWindow alloc] init];
        objc_setAssociatedObject([UIApplication sharedApplication], "HKFFloatingWindowKey", win, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
}
%end
