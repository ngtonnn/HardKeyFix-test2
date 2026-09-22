#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Khai báo API ẩn của iOS để chụp màn hình
@interface SBScreenShotter : NSObject
+ (instancetype)sharedInstance;
- (void)saveScreenshot:(BOOL)saveToPhotos;
@end

// Hằng số vùng vuốt
static const CGFloat kTopAreaHeight = 45.0; // Chiều cao thanh trạng thái (cho dư ra chút để dễ bấm)
static const CGFloat kClockAreaHalfW = 80.0; // Vùng giữa đồng hồ để chụp màn hình
static const CGFloat kVolumePerPointX = 0.005; // Độ nhạy khi vuốt ngang (1 point = 0.5% âm lượng)

// Hàm đổi âm lượng bằng thanh ẩn
static void HKF_SetSystemVolume(float volume) {
    volume = MAX(0.0f, MIN(1.0f, volume));
    static MPVolumeView *_hiddenVolumeView = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _hiddenVolumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-3000, -3000, 1, 1)];
        _hiddenVolumeView.hidden = NO;
        UIWindow *keyWindow = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *w in scene.windows) {
                    if (w.isKeyWindow) { keyWindow = w; break; }
                }
            }
        }
        if (keyWindow) [keyWindow addSubview:_hiddenVolumeView];
    });
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIView *subview in _hiddenVolumeView.subviews) {
            if ([subview isKindOfClass:[UISlider class]]) {
                UISlider *slider = (UISlider *)subview;
                [slider setValue:volume animated:NO];
                [slider sendActionsForControlEvents:UIControlEventTouchUpInside];
                break;
            }
        }
    });
}

// Cửa sổ trong suốt nhận cảm ứng
@interface HKFGestureWindow : UIWindow <UIGestureRecognizerDelegate>
@end

@implementation HKFGestureWindow {
    float _volumeAtGestureStart;
    CGFloat _panStartX;
    BOOL _volumePanActive;
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
    // Nổi trên cùng (chặn StatusBar)
    self.windowLevel = UIWindowLevelStatusBar + 100;
    self.userInteractionEnabled = YES;
    self.hidden = NO;

    UIViewController *rootVC = [UIViewController new];
    rootVC.view.backgroundColor = [UIColor clearColor];
    rootVC.view.userInteractionEnabled = YES;
    self.rootViewController = rootVC;

    // Cử chỉ vuốt (Pan)
    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handleVolumePan:)];
    panGR.delegate = self;
    panGR.maximumNumberOfTouches = 1;
    panGR.minimumNumberOfTouches = 1;
    [rootVC.view addGestureRecognizer:panGR];

    // Cử chỉ chạm 2 lần (Double Tap)
    UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleScreenshotTap:)];
    tapGR.numberOfTapsRequired = 2;
    tapGR.numberOfTouchesRequired = 1;
    tapGR.delegate = self;
    [rootVC.view addGestureRecognizer:tapGR];

    _volumePanActive = NO;
}

// Chỉ nhận cảm ứng ở khu vực StatusBar (trên cùng)
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (point.y <= kTopAreaHeight) {
        return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return NO;
}

// Lọc cử chỉ: Vuốt có thể mọi nơi trên StatusBar, Double Tap chỉ ở giữa (Đồng hồ)
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldReceiveTouch:(UITouch *)touch {
    CGPoint pt = [touch locationInView:self];
    CGFloat W = self.bounds.size.width;

    if (pt.y > kTopAreaHeight) return NO;

    if ([gr isKindOfClass:[UITapGestureRecognizer class]]) {
        // Vùng đồng hồ (ở giữa màn hình)
        CGRect clockZone = CGRectMake(W / 2.0 - kClockAreaHalfW, 0, kClockAreaHalfW * 2, kTopAreaHeight);
        return CGRectContainsPoint(clockZone, pt);
    }
    
    // Vuốt ngang (ở bất kỳ đâu trên phần đỉnh màn hình)
    if ([gr isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}

- (void)_handleVolumePan:(UIPanGestureRecognizer *)gr {
    CGPoint location = [gr locationInView:self];
    
    switch (gr.state) {
        case UIGestureRecognizerStateBegan:
            _panStartX = location.x;
            _volumeAtGestureStart = [AVAudioSession sharedInstance].outputVolume;
            _volumePanActive = YES;
            break;
        case UIGestureRecognizerStateChanged: {
            if (!_volumePanActive) return;
            // Vuốt phải (location.x lớn hơn _panStartX) => deltaX dương => Tăng âm lượng
            // Vuốt trái (location.x nhỏ hơn _panStartX) => deltaX âm => Giảm âm lượng
            CGFloat deltaX = (location.x - _panStartX) * kVolumePerPointX;
            float newVol = _volumeAtGestureStart + (float)deltaX;
            newVol = MAX(0.0f, MIN(1.0f, newVol));
            HKF_SetSystemVolume(newVol);
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            _volumePanActive = NO;
            break;
        default:
            break;
    }
}

- (void)_handleScreenshotTap:(UITapGestureRecognizer *)gr {
    if (gr.state != UIGestureRecognizerStateRecognized) return;
    
    // Gọi lệnh chụp màn hình trực tiếp bằng hàm chuẩn của iOS
    if (NSClassFromString(@"SBScreenShotter")) {
        [[objc_getClass("SBScreenShotter") sharedInstance] saveScreenshot:YES];
    }
}

@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        HKFGestureWindow *win = [[HKFGestureWindow alloc] init];
        objc_setAssociatedObject([UIApplication sharedApplication], "HKFGestureWindowKey", win, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
}
%end
