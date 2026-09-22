#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// --- Private APIs ---
@interface SBMediaController : NSObject
+ (instancetype)sharedInstance;
- (float)volume;
- (void)setVolume:(float)volume;
@end

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

// --- Constants ---
static const CGFloat kTopAreaHeight = 45.0; // Chiều cao thanh trạng thái
static const CGFloat kClockAreaHalfW = 80.0; // Vùng đồng hồ
static const CGFloat kVolumePerPointX = 0.004; // Độ nhạy (tăng/giảm tuỳ khoảng cách vuốt)

// --- Gesture Overlay ---
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
    self.windowLevel = UIWindowLevelStatusBar + 100;
    self.userInteractionEnabled = YES;
    self.hidden = NO;

    UIViewController *rootVC = [UIViewController new];
    rootVC.view.backgroundColor = [UIColor clearColor];
    rootVC.view.userInteractionEnabled = YES;
    self.rootViewController = rootVC;

    UIPanGestureRecognizer *panGR = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_handleVolumePan:)];
    panGR.delegate = self;
    panGR.maximumNumberOfTouches = 1;
    panGR.minimumNumberOfTouches = 1;
    [rootVC.view addGestureRecognizer:panGR];

    UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_handleScreenshotTap:)];
    tapGR.numberOfTapsRequired = 2;
    tapGR.numberOfTouchesRequired = 1;
    tapGR.delegate = self;
    [rootVC.view addGestureRecognizer:tapGR];

    _volumePanActive = NO;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (point.y <= kTopAreaHeight) {
        return YES;
    }
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldReceiveTouch:(UITouch *)touch {
    CGPoint pt = [touch locationInView:self];
    CGFloat W = self.bounds.size.width;

    if (pt.y > kTopAreaHeight) return NO;

    if ([gr isKindOfClass:[UITapGestureRecognizer class]]) {
        CGRect clockZone = CGRectMake(W / 2.0 - kClockAreaHalfW, 0, kClockAreaHalfW * 2, kTopAreaHeight);
        return CGRectContainsPoint(clockZone, pt);
    }
    
    if ([gr isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}

- (void)_handleVolumePan:(UIPanGestureRecognizer *)gr {
    CGPoint location = [gr locationInView:self];
    
    // Lấy instance của SBMediaController để chỉnh âm lượng chuẩn xác trên SpringBoard
    SBMediaController *mediaController = nil;
    if (NSClassFromString(@"SBMediaController")) {
        mediaController = [objc_getClass("SBMediaController") sharedInstance];
    }
    
    if (!mediaController) return;

    switch (gr.state) {
        case UIGestureRecognizerStateBegan:
            _panStartX = location.x;
            _volumeAtGestureStart = [mediaController volume]; // Lấy âm lượng hiện tại chuẩn
            _volumePanActive = YES;
            break;
        case UIGestureRecognizerStateChanged: {
            if (!_volumePanActive) return;
            // Tính toán sự thay đổi dựa vào khoảng cách lướt từ điểm bắt đầu
            CGFloat deltaX = (location.x - _panStartX) * kVolumePerPointX;
            float newVol = _volumeAtGestureStart + (float)deltaX;
            newVol = MAX(0.0f, MIN(1.0f, newVol));
            
            [mediaController setVolume:newVol];
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
    
    // Thử cách 1: dùng SBScreenshotManager của iOS 16
    SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
    if ([sb respondsToSelector:@selector(screenshotManager)]) {
        id manager = [sb screenshotManager];
        if (manager && [manager respondsToSelector:@selector(saveScreenshotsWithCompletion:)]) {
            [manager saveScreenshotsWithCompletion:nil];
            return;
        }
    }
    
    // Thử cách 2: dùng SBScreenShotter cũ
    Class shotterClass = objc_getClass("SBScreenShotter");
    if (shotterClass && [shotterClass respondsToSelector:@selector(sharedInstance)]) {
        id shotter = [shotterClass sharedInstance];
        if ([shotter respondsToSelector:@selector(saveScreenshot:)]) {
            [shotter saveScreenshot:YES];
        }
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
