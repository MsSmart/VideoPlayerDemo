//
//  ViewController.h
//  VideoPlayerDemo
//
//  Created by stella on 16/1/14.
//  Copyright © 2016年 stella. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController : UIViewController

@property (nonatomic,strong)AVPlayer *avPlayer;

@property (nonatomic,strong)AVPlayerItem *avPlayerItem;

@property (nonatomic,strong)AVPlayerLayer *avPlayerLayer;

//装载视频layer、进度条、时间、时长等UI的容器
@property (nonatomic,strong)UIView *videoContainer;

//进度条UI
@property (nonatomic,strong)UISlider *progress;

//当前播放时间UI
@property (nonatomic,strong) UILabel *startLabel;

//视频总时长UI
@property (nonatomic,strong) UILabel *endLabel;

//关闭按钮
@property (nonatomic,strong) UIButton *closeButton;

//控制播放和暂停的按钮
@property (nonatomic,strong) UIButton *playButton;

//当前播放时间
@property (nonatomic,assign) float playheadTime;

//是否处于播放状态
@property (nonatomic,assign) BOOL isPlaying;

//播放帧的监视器
@property (nonatomic,strong) id playTimeObserver;

@end

