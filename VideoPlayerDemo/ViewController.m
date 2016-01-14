//
//  ViewController.m
//  VideoPlayerDemo
//
//  Created by stella on 16/1/14.
//  Copyright © 2016年 stella. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end
static NSBundle *playerBundle;
NSString * const XAdVideoStatusKey = @"status";
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *urlString = @"要播放的视频地址 http://....";
    [self configPlayerControllerWithURL:urlString];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - public
- (void) configPlayerControllerWithURL:(NSString *)urlString{
    [self initBundle];
    [self setProgressRefProperties];
    [self showUI];
    NSURL *url = [NSURL URLWithString:urlString];
    [self setupPlayerWithURL:url];
    
}
/*
 * 重头播放
 */
- (void)play{
    if (self.avPlayer) {
        self.isPlaying = YES;
        [self.avPlayer play];
    }
}
/*
 * 暂停
 */
- (void)pause
{
    if (self.avPlayer) {
        [self.avPlayer pause];
        self.isPlaying = NO;
    }
    
}
/*
 * 销毁对象
 */
- (void)cancel {
    if (self.avPlayer) {
        [self.avPlayer pause];
    }
    [self removeUIView];
    [self removePlayerItemObserver];
    [self removePlayerObserver];
    [self destroyAllProperties];
    
}
/*
 * 从某一帧播放
 */
- (void)playFromTime:(double)time
{
    NSLog(@"playFromTime = %f",time);
    if (self.avPlayer) {
        [self seekToTime:time];
        [self.avPlayer play];
        self.isPlaying = YES;
    }
}
/*
 * 在某一帧暂停
 */
- (void)pauseOnTime:(double)time
{
    NSLog(@"pauseOnTime = %f",time);
    if (self.avPlayer) {
        [self seekToTime:time];
        [self.avPlayer pause];
        self.isPlaying = NO;
    }
}

#pragma mark - action event
/*
 * 点击播放或暂停按钮，控制播放状态
 */
- (void) onClickPlayOrPause{
    if (self.isPlaying) {
        [_playButton setImage:[self getImageFromBundle:playerBundle imageName:@"player_play"] forState:UIControlStateNormal];
        [self pauseOnTime:self.playheadTime];
    }else{
        [_playButton setImage:[self getImageFromBundle:playerBundle imageName:@"player_pause"] forState:UIControlStateNormal];
        if ([self playerReachedEnd]) {
            [self playFromTime:0];
        }else{
            [self playFromTime:self.playheadTime];
        }
    }
}
/*
 * 关闭按钮触发，销毁所有player和UI相关对象
 */
- (void) onClickClose{
    [self cancel];
}

#pragma mark - add observer
/*
 * 播放帧的观察者
 */
- (void)addPlayerObserver
{
    // add 应用置于后台、唤醒、屏幕旋转的监听器 （如果不需要此功能可以不添加）
    [self addAppObserver];
    CMTime interval = CMTimeMakeWithSeconds(0.1, NSEC_PER_USEC);
    __weak ViewController *selfWeak = self;
    self.playTimeObserver = [self.avPlayer addPeriodicTimeObserverForInterval:interval
                                                                        queue:NULL
                                                                   usingBlock:^(CMTime time) {
                                                                       // 当前的播放时间
                                                                       float currentTime = (float)CMTimeGetSeconds(time);
                                                                       // 刷新进度条以及时间Label的显示
                                                                       [selfWeak refreshSlide:currentTime];
                                                                   }];
}

- (void)addPlayerItemObserver{
    // 监测播放的状态（已就绪 / 失败 ）
    [self.avPlayerItem addObserver:self forKeyPath:XAdVideoStatusKey options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.avPlayerItem];
    
}

- (void)addAppObserver{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
    // 应用从后台唤醒
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    // 应用置于后台
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationWillResignActiveNotification object:nil];
    // 屏幕旋转
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

#pragma mark - remove observer
- (void)removePlayerObserver{
    [self removeAppObserver];
    if (self.avPlayer && self.playTimeObserver) {
        [self.avPlayer removeTimeObserver:self.playTimeObserver];
    }
}

- (void)removePlayerItemObserver{
    [self.avPlayerItem removeObserver:self forKeyPath:XAdVideoStatusKey context:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.avPlayerItem];
}

- (void)removeAppObserver{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

#pragma mark - observer & notification
- (void)appDidBecomeActive:(NSNotification *)notification
{
    //后台唤醒继续播放
    [self playFromTime:self.playheadTime];
}

- (void)appDidEnterBackground:(NSNotification *)notification
{
    //置于后台停止播放
    [self pauseOnTime:self.playheadTime];
}

- (void)orientationChanged:(NSNotification *)notification{
    //屏幕旋转重新布局UI
    [self reloadVideoContainerView];
}
/*
 * 监测player的状态
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context
{
    if (object == self.avPlayerItem && [keyPath isEqualToString:XAdVideoStatusKey]) {
        if (self.avPlayerItem.status == AVPlayerItemStatusFailed) {
            NSLog(@"AVPlayerItemStatusFailed.");
        } else if (self.avPlayerItem.status == AVPlayerItemStatusReadyToPlay) {
            if (self.videoContainer) {
                self.avPlayerLayer.frame = [self.videoContainer bounds];
                NSLog(@"add playerLayer to video container.");
                [self.videoContainer.layer insertSublayer:self.avPlayerLayer atIndex:0];
                [self play];
            }
        }
    }
}
- (void) playerItemDidReachEnd:(NSNotification *)notification{
    // 播放结束，改变播放暂停按钮的状态
    [self changePlayOrPauseUI];
    
}
/*
 * 刷新进度条以及相关UI
 */
- (void)refreshSlide:(float) time{
    CMTime duration = self.avPlayer.currentItem.asset.duration;
    self.playheadTime = time;
    int currentSeconds = (int)(self.playheadTime);
    int fullDuration = (int)(duration.value/duration.timescale);
    self.progress.minimumValue = 0;
    self.progress.maximumValue = fullDuration;
    // 刷新进度条的进度
    self.progress.value = currentSeconds;
    // 刷新时间的显示
    NSMutableAttributedString *startLabelText = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%02d:%02d",currentSeconds/60,currentSeconds%60]];
    NSMutableAttributedString *endLabelText = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%02d:%02d",fullDuration/60,fullDuration%60]];
    [startLabelText addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0,startLabelText.length)];
    [endLabelText addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0,endLabelText.length)];
    self.startLabel.attributedText = startLabelText;
    self.endLabel.attributedText = endLabelText;
}
/*
 * 手动滑动进度条继续播放或者暂停
 */
- (void) progressChanged{
    if ([self isPlaying]) {
        // 如果之前是播放状态，那么继续播放
        [self playFromTime:self.progress.value];
    }else{
        // 如果之前是是暂停状态，那么保持暂停
        [self pauseOnTime:self.progress.value];
    }
    
}
/*
 * 进度条被拖拽，改变播放暂停按钮的状态
 */
- (void) progressDragInside{
    NSLog(@"progressDragInside value:%f",self.progress.value);
    [_playButton setImage:[self getImageFromBundle:playerBundle imageName:@"player_play"] forState:UIControlStateNormal];
}
/*
 * 进度条被按住，改变播放暂停按钮的状态
 */
- (void) progressTouchDown{
    NSLog(@"progressTouchDown value:%f",self.progress.value);
    [_playButton setImage:[self getImageFromBundle:playerBundle imageName:@"player_play"] forState:UIControlStateNormal];
    
}
/*
 * 进度条按住后松开，改变播放暂停按钮的状态
 */
- (void)progressTouchUpInside{
    NSLog(@"progressTouchUpInside value:%f",self.progress.value);
    if ([self isPlaying]) {
        [_playButton setImage:[self getImageFromBundle:playerBundle imageName:@"player_pause"] forState:UIControlStateNormal];
    }else{
        [_playButton setImage:[self getImageFromBundle:playerBundle imageName:@"player_play"] forState:UIControlStateNormal];
    }
}

#pragma mark - private
/*
 * 屏幕旋转后刷新frame的大小
 */
- (void)reloadVideoContainerView{
    CGPoint currentOrigin = [UIScreen mainScreen].applicationFrame.origin;
    CGSize currentSize = [self getScreenSize];
    CGRect currentScreenFrame = CGRectMake(currentOrigin.x, currentOrigin.y, currentSize.width, currentSize.height);
    self.videoContainer.frame = currentScreenFrame;
    self.avPlayerLayer.frame = self.videoContainer.bounds;
}
/*
 * 进度条相关UI的布局（如果无此需求可忽略，但是在初始化时的CGRect要设置好）
 * 布局顺序：在app的底部 ==> 播放/暂停按钮、播放时间、进度条、播放时长
 *         在app的左上角 ==> 关闭按钮
 */
- (void)addConstraint{
    
    _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    _progress.translatesAutoresizingMaskIntoConstraints = NO;
    _playButton.translatesAutoresizingMaskIntoConstraints = NO;
    _startLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _endLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    // Align play button left to video container
    NSLayoutConstraint* playbuttonLeftConstraint = [NSLayoutConstraint constraintWithItem:_playButton attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.videoContainer attribute:NSLayoutAttributeLeading multiplier:1.0f constant:10.0f];
    // Align play button buttom to video container
    NSLayoutConstraint* playbuttonButtomConstraint = [NSLayoutConstraint constraintWithItem:_playButton attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.videoContainer attribute:NSLayoutAttributeBottom multiplier:1.0f constant: -5.0f];
    
    // Align start label left to play button
    NSLayoutConstraint* startLabelLeftConstraint = [NSLayoutConstraint constraintWithItem:_startLabel attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.playButton attribute:NSLayoutAttributeTrailing multiplier:1.0f constant:10.0f];
    // Align start label centerY to video container
    NSLayoutConstraint* startLabelCenterYConstraint = [NSLayoutConstraint constraintWithItem:_startLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.progress attribute:NSLayoutAttributeCenterY multiplier:1.0f constant:0.0f];
    
    // Align progress slider left to start label
    NSLayoutConstraint* progressLeftConstraint = [NSLayoutConstraint constraintWithItem:_progress attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.startLabel attribute:NSLayoutAttributeTrailing multiplier:1.0f constant:10.0f];
    // Align progress slider right to end label
    NSLayoutConstraint* progressRightConstraint = [NSLayoutConstraint constraintWithItem:_progress attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.endLabel attribute:NSLayoutAttributeLeading multiplier:1.0f constant:-10.0f];
    // Align progress centerY to play button
    NSLayoutConstraint* progressCenterYConstraint = [NSLayoutConstraint constraintWithItem:_progress attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.playButton attribute:NSLayoutAttributeCenterY multiplier:1.0f constant:0.0f];
    
    // Align end label right to video contrainer
    NSLayoutConstraint* endLabelRightConstraint = [NSLayoutConstraint constraintWithItem:_endLabel attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:self.videoContainer attribute:NSLayoutAttributeTrailing multiplier:1.0f constant:-10.0f];
    // Align end label centerY to video container
    NSLayoutConstraint* endLabelCenterYConstraint = [NSLayoutConstraint constraintWithItem:_endLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.progress attribute:NSLayoutAttributeCenterY multiplier:1.0f constant:0.0f];
    
    // Align close button left to video container
    NSLayoutConstraint* closebuttonLeftConstraint = [NSLayoutConstraint constraintWithItem:_closeButton attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self.videoContainer attribute:NSLayoutAttributeLeading multiplier:1.0f constant:3.0f];
    // Align close button top to video container
    NSLayoutConstraint* closebuttonTopConstraint = [NSLayoutConstraint constraintWithItem:_closeButton attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.videoContainer attribute:NSLayoutAttributeTop multiplier:1.0f constant:3.0f];
    
    [self.videoContainer addConstraints:@[playbuttonLeftConstraint, startLabelLeftConstraint, progressLeftConstraint, endLabelRightConstraint,progressRightConstraint,playbuttonButtomConstraint,closebuttonLeftConstraint,closebuttonTopConstraint,playbuttonButtomConstraint,startLabelCenterYConstraint,endLabelCenterYConstraint,progressCenterYConstraint]];
    
}
/*
 * 获取屏幕大小，IOS8以后屏幕宽高是真实宽高，IOS8之前需要翻转
 */
- (CGSize) getScreenSize{
    CGSize size;
    CGSize screenSize = [UIScreen mainScreen].applicationFrame.size;
    if ([self isLaterThanIOS8]) {
        size = screenSize;
        NSLog(@"ios8 or ios9, width = %f,height = %f",size.width,size.height);
    }else{
        if ( UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation))
        {
            // Landscape Orientation, reverse size values
            size.width = screenSize.height;
            size.height = screenSize.width;
        }
        else
        {
            // portrait orientation, use normal size values
            size.width = screenSize.width;
            size.height = screenSize.height;
        }
        NSLog(@" not ios8 or ios9, width = %f,height = %f",size.width,size.height);
    }
    return size;
}
/*
 * 初始化avplayerItem、avplayer、avplayerLayer
 */
- (void)setupPlayerWithURL:(NSURL *)URL
{
//        dispatch_async(dispatch_get_global_queue(0, 0), ^{
    self.avPlayerItem = [AVPlayerItem playerItemWithURL:URL];
    [self addPlayerItemObserver];
    self.avPlayer = [AVPlayer playerWithPlayerItem:self.avPlayerItem];
    [self addPlayerObserver];
    self.avPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:self.avPlayer];
    [self.avPlayerLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    self.avPlayerLayer.needsDisplayOnBoundsChange = YES;
//        });
    
}

- (void) showUI{
    [self addConstraint];
    [self.view addSubview:self.videoContainer];
    [self.videoContainer addSubview:self.progress];
    [self.videoContainer addSubview:self.startLabel];
    [self.videoContainer addSubview:self.endLabel];
    [self.videoContainer addSubview:self.playButton];
    [self.videoContainer addSubview:self.closeButton];
    
    
}

- (void)setProgressRefProperties{
    // 获取不包括状态栏的屏幕frame
    CGRect appViewFrame = [ UIScreen mainScreen ].applicationFrame;
    _videoContainer = [[UIView alloc]initWithFrame:appViewFrame];
    self.videoContainer.backgroundColor = [UIColor blackColor];
    // 初始化进度条（尺寸没有生效，因为后面用了布局约束）
    _progress = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 100, 5)];
    // 设置进度条播放按钮的图片
    [_progress setThumbImage:[self getImageFromBundle:playerBundle imageName:@"player_dot"] forState:UIControlStateNormal];
    [_progress setThumbImage:[self getImageFromBundle:playerBundle imageName:@"player_dot"] forState:UIControlStateHighlighted];
    // 设置进度条已播放和未播放部分的颜色
    [_progress setMinimumTrackTintColor:[UIColor whiteColor]];
    [_progress setMaximumTrackTintColor:[UIColor darkGrayColor]];
    // 设置进度条的事件函数
    [self.progress addTarget:self action:@selector(progressChanged) forControlEvents:(UIControlEventValueChanged)];
    [self.progress addTarget:self action:@selector(progressDragInside) forControlEvents:(UIControlEventTouchDragInside)];
    [self.progress addTarget:self action:@selector(progressTouchDown) forControlEvents:(UIControlEventTouchDown)];
    [self.progress addTarget:self action:@selector(progressTouchUpInside) forControlEvents:(UIControlEventTouchUpInside)];
    // 初始化进度条（尺寸没有生效，因为后面用了布局约束）
    _startLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 50, 15)];
    _endLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 50, 15)];
    // 设置时间Lable字体样式和颜色
    NSMutableAttributedString *startLabelText = [[NSMutableAttributedString alloc] initWithString:@"00:00"];
    NSMutableAttributedString *endLabelText = [[NSMutableAttributedString alloc] initWithString:@"00:00"];
    [startLabelText addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0,startLabelText.length)];
    [endLabelText addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0,endLabelText.length)];
    self.startLabel.attributedText = startLabelText;
    self.endLabel.attributedText = endLabelText;
    //初始化播放暂停按钮，设置图片
    _playButton = [[UIButton alloc] initWithFrame:CGRectMake(10, 50, 20, 20)];
    [_playButton setImage:[self getImageFromBundle:playerBundle imageName:@"player_pause"] forState:UIControlStateNormal];
    [_playButton addTarget:self action:@selector(onClickPlayOrPause) forControlEvents:UIControlEventTouchUpInside];
    //初始化关闭按钮，设置相应图片
    _closeButton = [[UIButton alloc]initWithFrame:CGRectMake(50, 50, 20, 20)];
    [_closeButton setImage:[self getImageFromBundle:playerBundle imageName:@"player_close"] forState:UIControlStateNormal];
    [_closeButton addTarget:self action:@selector(onClickClose) forControlEvents:UIControlEventTouchUpInside];
    
}
/*
 * 改变播放或暂停按钮的状态
 */
- (void) changePlayOrPauseUI{
    if (self.isPlaying) {
        [_playButton setImage:[self getImageFromBundle:playerBundle imageName:@"player_play"] forState:UIControlStateNormal];
        self.isPlaying = NO;
    }else{
        [_playButton setImage:[self getImageFromBundle:playerBundle imageName:@"player_pause"] forState:UIControlStateNormal];
        self.isPlaying = YES;
    }
}
/*
 * 判断播放是否结束
 */
- (BOOL)playerReachedEnd {
    CMTime duration = self.avPlayer.currentItem.asset.duration;
    CMTime currentTime = self.avPlayer.currentItem.currentTime;
    // CMTime包含value和timescale两个属性，比值用来获取真正的播放时间
    int currentSeconds = (int)(currentTime.value/currentTime.timescale);
    int fullDuration = (int)(duration.value/duration.timescale);
    return (currentSeconds == fullDuration) ? YES : NO;
}
/*
 * 跳到某一播放帧
 */
- (void)seekToTime:(double)time
{
    if (time >= 0) {
        CMTime timeStruct = CMTimeMake(time * 1000, 1000);
        [self.avPlayer seekToTime:timeStruct
                  toleranceBefore:kCMTimeZero
                   toleranceAfter:kCMTimePositiveInfinity];
    }
}
/*
 * 获取资源包
 */
- (void) initBundle{
    NSString * bundlePath = [[ NSBundle mainBundle] pathForResource: @"playicon" ofType :@"bundle"];
    playerBundle = [NSBundle bundleWithPath:bundlePath];
}
/*
 * 获取资源包中的图片资源
 */
- (UIImage *)getImageFromBundle:(NSBundle *) bundle imageName:(NSString *)imageName{
    NSString *imagePath = [playerBundle pathForResource:imageName ofType:@"png"];
    UIImage *image = [[UIImage alloc]init];
    if (imagePath) {
        image = [UIImage imageWithContentsOfFile:imagePath];
    }
    return image;
}
/*
 * 是否系统版本高于IOS8
 */
- (BOOL) isLaterThanIOS8{
    return ([[[UIDevice currentDevice] systemVersion] hasPrefix:@"8."] || [[[UIDevice currentDevice] systemVersion] hasPrefix:@"9."]);
}

- (void)destroyAllProperties{
    _avPlayer = nil;
    _avPlayerItem = nil;
    _avPlayerLayer = nil;
    _progress = nil;
    _startLabel = nil;
    _endLabel = nil;
    _closeButton = nil;
    _playButton = nil;
    _playTimeObserver = nil;
}

- (void) removeUIView{
    if (self.avPlayerLayer) {
        [self.avPlayerLayer removeFromSuperlayer];
    }
    if (self.videoContainer) {
        [self.videoContainer removeFromSuperview];
    }
    if (self.progress) {
        [self.progress removeFromSuperview];
    }
    if (self.closeButton) {
        [self.closeButton removeFromSuperview];
    }
    if (self.startLabel) {
        [self.startLabel removeFromSuperview];
    }
    if (self.endLabel) {
        [self.endLabel removeFromSuperview];
    }
    if (self.playButton) {
        [self.playButton removeFromSuperview];
    }
    
}

- (void)dealloc
{
    [self cancel];
}


@end
