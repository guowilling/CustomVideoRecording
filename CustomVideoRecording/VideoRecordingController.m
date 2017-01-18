//
//  VideoRecordingController.m
//  CustomVideoRecording
//
//  Created by 郭伟林 on 17/1/18.
//  Copyright © 2017年 SR. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVKit/AVKit.h>
#import "VideoRecordingController.h"
#import "VideoRecordingManager.h"
#import "VideoRecordingWriter.h"
#import "VideoRecordingProgress.h"

@interface VideoRecordingController () <VideoRecordingManagerDelegate>

@property (nonatomic, strong) VideoRecordingManager *recordingManager;

@property (nonatomic, weak) UIView   *topToolBar;
@property (nonatomic, weak) UIButton *flashBtn;
@property (nonatomic, weak) UIButton *switchCameraBtn;

@property (nonatomic, weak) UIView    *bottomToolBar;
@property (nonatomic, weak) UIButton  *startRecordingBtn;
@property (nonatomic, weak) UIButton  *playVideoBtn;

@property (nonatomic, weak) VideoRecordingProgress *recordingProgress;

@end

@implementation VideoRecordingController

#pragma mark - Lazy Load

- (VideoRecordingManager *)recordingManager {
    
    if (!_recordingManager) {
        _recordingManager = [[VideoRecordingManager alloc] init];
        _recordingManager.maxRecordingTime = 15.0;
        _recordingManager.autoSaveVideo = YES;
        _recordingManager.delegate = self;
    }
    return _recordingManager;
}

#pragma mark - Life Cycle

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    [self setupTopToolBar];
    [self setupBottomToolBar];
    
    self.recordingManager.previewLayer.frame = self.view.bounds;
    [self.view.layer insertSublayer:self.recordingManager.previewLayer atIndex:0];
    [self.recordingManager startCapture];
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    [UIApplication sharedApplication].statusBarHidden = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    
    [UIApplication sharedApplication].statusBarHidden = NO;
}

#pragma mark - Init UI

- (void)setupTopToolBar {
    
    UIView *topToolBar = [[UIView alloc] init];
    topToolBar.frame = CGRectMake(0, 0, self.view.frame.size.width, 64);
    topToolBar.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
    [self.view addSubview:topToolBar];
    _topToolBar = topToolBar;
    
    CGFloat btnWH = 44;
    CGFloat margin = 10;
    
    UIButton *flashBtn = [[UIButton alloc] init];
    flashBtn.frame = CGRectMake(0, margin, btnWH, btnWH);
    [flashBtn setImage:[UIImage imageNamed:@"camera_flash_off"] forState:UIControlStateNormal];
    [flashBtn setImage:[UIImage imageNamed:@"camera_flash_on"] forState:UIControlStateSelected];
    [flashBtn addTarget:self action:@selector(flashBtnAction:) forControlEvents:UIControlEventTouchUpInside];
    [topToolBar addSubview:flashBtn];
    _flashBtn = flashBtn;
    
    UIButton *switchCameraBtn = [[UIButton alloc] init];
    switchCameraBtn.frame = CGRectMake(self.view.frame.size.width - btnWH, margin, btnWH, btnWH);
    [switchCameraBtn setImage:[UIImage imageNamed:@"switch_camera"] forState:UIControlStateNormal];
    [switchCameraBtn addTarget:self action:@selector(switchCameraBtnAction:) forControlEvents:UIControlEventTouchUpInside];
    [topToolBar addSubview:switchCameraBtn];
    _switchCameraBtn = switchCameraBtn;
}

- (void)setupBottomToolBar {
    
    UIView *bottomToolBar = [[UIView alloc] init];
    bottomToolBar.frame = CGRectMake(0, self.view.frame.size.height - 150, self.view.frame.size.width, 150);
    bottomToolBar.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
    [self.view addSubview:bottomToolBar];
    _bottomToolBar = bottomToolBar;
    
    UIButton *startRecordingBtn = [[UIButton alloc] init];
    startRecordingBtn.frame = CGRectMake((bottomToolBar.frame.size.width - 75) * 0.5, (bottomToolBar.frame.size.height - 75) * 0.5, 75, 75);
    [startRecordingBtn setImage:[UIImage imageNamed:@"start_recording"] forState:UIControlStateNormal];
    [startRecordingBtn addTarget:self action:@selector(startRecordingBtnAction:) forControlEvents:UIControlEventTouchUpInside];
    [bottomToolBar addSubview:startRecordingBtn];
    _startRecordingBtn = startRecordingBtn;
    
    VideoRecordingProgress *recordingProgress = [[VideoRecordingProgress alloc] initWithFrame:_startRecordingBtn.frame];
    recordingProgress.progressTintColor = [UIColor colorWithRed:1.00 green:0.28 blue:0.26 alpha:1.00];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(stopRecording)];
    [recordingProgress addGestureRecognizer:tap];
    [_bottomToolBar addSubview:recordingProgress];
    _recordingProgress = recordingProgress;
    _recordingProgress.hidden = YES;
    
    UIButton *playVideoBtn = [[UIButton alloc] init];
    playVideoBtn.frame = CGRectMake((_bottomToolBar.frame.size.width * 0.5 - 50) * 0.5, (_bottomToolBar.frame.size.height - 50) * 0.5, 50, 50);
    playVideoBtn.imageView.contentMode = UIViewContentModeScaleAspectFill;
    playVideoBtn.layer.cornerRadius = playVideoBtn.frame.size.height * 0.5;
    playVideoBtn.layer.masksToBounds = YES;
    [playVideoBtn addTarget:self action:@selector(playVideoBtnAction) forControlEvents:UIControlEventTouchUpInside];
    [_bottomToolBar addSubview:playVideoBtn];
    _playVideoBtn = playVideoBtn;
    _playVideoBtn.hidden = YES;
}

#pragma mark - Actions

- (void)flashBtnAction:(UIButton *)sender {
    
    if (_switchCameraBtn.selected) {
        return;
    }
    
    sender.selected = !sender.selected;
    if (sender.selected) {
        [self.recordingManager openFlashLight];
    } else {
        [self.recordingManager closeFlashLight];
    }
}

- (void)switchCameraBtnAction:(UIButton *)sender {
    
    sender.selected = !sender.selected;
    if (sender.selected) {
        _flashBtn.selected = NO;
        [self.recordingManager closeFlashLight];
        [self.recordingManager switchCameraInputDeviceToFront];
    } else {
        [self.recordingManager swithCameraInputDeviceToBack];
    }
}

- (void)startRecordingBtnAction:(UIButton *)sender {
    
    sender.hidden = YES;
    _recordingProgress.hidden = NO;
    
    [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         _topToolBar.transform = CGAffineTransformMakeTranslation(0, -64);
                     } completion:nil];
    
    [self.recordingManager startRecoring];
}

- (void)playVideoBtnAction {
    
    AVPlayerViewController *playerViewController = [[AVPlayerViewController alloc] init];
    playerViewController.player = [AVPlayer playerWithURL:[NSURL fileURLWithPath:self.recordingManager.videoPath]];
    [self presentViewController:playerViewController animated:YES completion:nil];
}

- (void)stopRecording {
    
    _startRecordingBtn.hidden = NO;
    _recordingProgress.hidden = YES;
    _playVideoBtn.hidden = NO;
    
    [UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         _topToolBar.transform = CGAffineTransformIdentity;
                     } completion:nil];
    
    [self.recordingManager stopRecordingHandler:^(UIImage *firstFrameImage) {
        [_playVideoBtn setImage:firstFrameImage forState:UIControlStateNormal];
    }];
}

#pragma mark - SRRecordingManagerDelegate

- (void)updateRecordingProgress:(CGFloat)progress {
    
    _recordingProgress.progress = progress;
    
    if (progress >= 1.0) {
        [self stopRecording];
    }
}

@end
