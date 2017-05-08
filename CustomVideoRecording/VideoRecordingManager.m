//
//  VideoRecordingManager.m
//  CustomVideoRecording
//
//  Created by 郭伟林 on 17/1/18.
//  Copyright © 2017年 SR. All rights reserved.
//

#import "VideoRecordingManager.h"
#import "VideoRecordingWriter.h"
#import <Photos/Photos.h>

@interface VideoRecordingManager () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, CAAnimationDelegate>
{
    // 视频分辨率宽
    NSInteger _resolutionWidth;
    // 视频分辨率高
    NSInteger _resolutionHeight;
    
    // 音频通道
    int _audioChannel;
    // 音频采样率
    Float64 _sampleRate;
}

@property (nonatomic, strong) AVCaptureSession *captureSession;

@property (nonatomic, strong) AVCaptureDeviceInput *backCameraInput;
@property (nonatomic, strong) AVCaptureDeviceInput *frontCameraInput;
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;

@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;

@property (nonatomic, strong) AVCaptureConnection *videoConnection;
@property (nonatomic, strong) AVCaptureConnection *audioConnection;

@property (nonatomic, strong) dispatch_queue_t captureQueue;

@property (nonatomic, strong) VideoRecordingWriter *recordingWriter;

@property (nonatomic, assign) CMTime  startRecordingCMTime;

@property (nonatomic, assign) CGFloat currentRecordingTime;

@property (nonatomic, assign) BOOL isRecording;

@property (nonatomic, copy) NSString *cacheDirectoryPath;

@property (nonatomic, strong) NSURL *videoFileURL;

@end

@implementation VideoRecordingManager

- (void)dealloc {
    
    [_captureSession stopRunning];
    
    _captureSession   = nil;
    _previewLayer     = nil;
    _backCameraInput  = nil;
    _frontCameraInput = nil;
    _audioOutput      = nil;
    _videoOutput      = nil;
    _audioConnection  = nil;
    _videoConnection  = nil;
    _recordingWriter  = nil;
    _captureQueue     = nil;
}

+ (void)load {
    
    NSString *cacheDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]
                                stringByAppendingPathComponent:NSStringFromClass([self class])];
    BOOL isDirectory = NO;
    BOOL isExists = [[NSFileManager defaultManager] fileExistsAtPath:cacheDirectory isDirectory:&isDirectory];
    if (!isExists || !isDirectory) {
        [[NSFileManager defaultManager] createDirectoryAtPath:cacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

#pragma mark - Lazy Load

- (NSString *)cacheDirectoryPath {
    
    if (!_cacheDirectoryPath) {
        _cacheDirectoryPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]
                               stringByAppendingPathComponent:NSStringFromClass([self class])];
    }
    return _cacheDirectoryPath;
}

- (AVCaptureVideoPreviewLayer *)previewLayer {
    
    if (!_previewLayer) {
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
        _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    return _previewLayer;
}

- (AVCaptureSession *)captureSession {
    
    if (!_captureSession) {
        _captureSession = [[AVCaptureSession alloc] init];
        
        if ([_captureSession canAddInput:self.backCameraInput]) {
            [_captureSession addInput:self.backCameraInput];
        }
        if ([_captureSession canAddInput:self.audioInput]) {
            [_captureSession addInput:self.audioInput];
        }
        
        if ([_captureSession canAddOutput:self.videoOutput]) {
            [_captureSession addOutput:self.videoOutput];
        }
        if ([_captureSession canAddOutput:self.audioOutput]) {
            [_captureSession addOutput:self.audioOutput];
        }
        
        _resolutionWidth  = 360;
        _resolutionHeight = 640;
        
        self.videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    }
    return _captureSession;
}

- (AVCaptureDeviceInput *)backCameraInput {
    
    if (!_backCameraInput) {
        AVCaptureDevice *backCameraDevice = nil;
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices) {
            if (device.position == AVCaptureDevicePositionBack) {
                backCameraDevice = device;
                break;
            }
        }
        NSError *error = nil;
        _backCameraInput = [[AVCaptureDeviceInput alloc] initWithDevice:backCameraDevice error:&error];
        if (error) {
            NSLog(@"初始化后置摄像头失败!");
        }
    }
    return _backCameraInput;
}

- (AVCaptureDeviceInput *)frontCameraInput {
    
    if (!_frontCameraInput) {
        AVCaptureDevice *frontCameraDevice = nil;
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices) {
            if (device.position == AVCaptureDevicePositionFront) {
                frontCameraDevice = device;
                break;
            }
        }
        NSError *error = nil;
        _frontCameraInput = [[AVCaptureDeviceInput alloc] initWithDevice:frontCameraDevice error:&error];
        if (error) {
            NSLog(@"初始化前置摄像头失败!");
        }
    }
    return _frontCameraInput;
}

- (AVCaptureDeviceInput *)audioInput {
    
    if (!_audioInput) {
        AVCaptureDevice *captureDeviceAudio = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        NSError *error = nil;
        _audioInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDeviceAudio error:&error];
        if (error) {
            NSLog(@"初始化麦克风失败!");
        }
    }
    return _audioInput;
}

- (AVCaptureVideoDataOutput *)videoOutput {
    
    if (!_videoOutput) {
        _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [_videoOutput setSampleBufferDelegate:self queue:self.captureQueue];
        _videoOutput.videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), kCVPixelBufferPixelFormatTypeKey, nil];
    }
    return _videoOutput;
}

- (AVCaptureAudioDataOutput *)audioOutput {
    
    if (!_audioOutput) {
        _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
        [_audioOutput setSampleBufferDelegate:self queue:self.captureQueue];
    }
    return _audioOutput;
}

- (dispatch_queue_t)captureQueue {
    
    if (!_captureQueue) {
        _captureQueue = dispatch_queue_create("com.willing.SRVideoRecorder", DISPATCH_QUEUE_SERIAL);
    }
    return _captureQueue;
}

- (AVCaptureConnection *)videoConnection {
    
    // Notice: Should not use lazy load, cos switch camera input device will have bug!
    _videoConnection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
    if (!_videoConnection) {
    }
    return _videoConnection;
}

- (AVCaptureConnection *)audioConnection {
    
    if (!_audioConnection) {
        _audioConnection = [self.audioOutput connectionWithMediaType:AVMediaTypeAudio];
    }
    return _audioConnection;
}

#pragma mark - Init

- (instancetype)init {
    
    if (self = [super init]) {
        _maxRecordingTime = 10.0;
        _autoSaveVideo = NO;
    }
    return self;
}

#pragma mark - Public Methods

- (void)startCapture {
    
    _isRecording = NO;
    _startRecordingCMTime = CMTimeMake(0, 0);
    _currentRecordingTime = 0;
    
    [self.captureSession startRunning];
}

- (void)stopCapture {
    
    [self.captureSession stopRunning];
}

- (void)startRecoring {
    
    if (self.isRecording) {
        return;
    }
    _isRecording = YES;
}

- (void)stopRecoring {
    
    [self stopRecordingHandler:nil];
}

- (void)stopRecordingHandler:(void (^)(UIImage *firstFrameImage))handler {
    
    if (!_isRecording) {
        return;
    }
    
    _isRecording = NO;
    _videoFileURL = [NSURL fileURLWithPath:_recordingWriter.videoPath];
    
    dispatch_async(self.captureQueue, ^{
        __weak typeof(self) weakSelf = self;
        [_recordingWriter finishWritingWithCompletionHandler:^{
            weakSelf.isRecording = NO;
            weakSelf.startRecordingCMTime = CMTimeMake(0, 0);
            weakSelf.currentRecordingTime = 0;
            weakSelf.recordingWriter = nil;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([weakSelf.delegate respondsToSelector:@selector(updateRecordingProgress:)]) {
                    [weakSelf.delegate updateRecordingProgress:self.currentRecordingTime / self.maxRecordingTime];
                }
            });
            
            if (weakSelf.autoSaveVideo) {
                [self saveCurrentRecordingVideo];
            }
            
            if (handler) {
                NSURL *videoFileURL = [NSURL fileURLWithPath:weakSelf.videoPath];
                AVURLAsset *videoAsset = [[AVURLAsset alloc] initWithURL:videoFileURL options:nil];
                AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:videoAsset];
                imageGenerator.appliesPreferredTrackTransform = TRUE;
                CMTime thumbTime = CMTimeMakeWithSeconds(0, 60);
                imageGenerator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
                [imageGenerator generateCGImagesAsynchronouslyForTimes:[NSArray arrayWithObject:[NSValue valueWithCMTime:thumbTime]]
                                                     completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image,
                                                                         CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
                                                         if (result != AVAssetImageGeneratorSucceeded) {
                                                             return;
                                                         }
                                                         UIImage *firstFrameImage = [UIImage imageWithCGImage:image];
                                                         dispatch_async(dispatch_get_main_queue(), ^{
                                                             if (firstFrameImage) {
                                                                 handler(firstFrameImage);
                                                             } else {
                                                                 handler(nil);
                                                             }
                                                         });
                                                     }];
            }
        }];
    });
}

#pragma mark - Public Methods

- (void)switchCameraAnimation {
    
    CATransition *filpAnimation = [CATransition animation];
    filpAnimation.delegate = self;
    filpAnimation.duration = 0.5;
    filpAnimation.type = @"oglFlip";
    filpAnimation.subtype = kCATransitionFromRight;
    filpAnimation.timingFunction = UIViewAnimationCurveEaseInOut;
    [self.previewLayer addAnimation:filpAnimation forKey:@"filpAnimation"];
}

- (void)animationDidStart:(CAAnimation *)anim {
    
    self.videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    [self.captureSession startRunning];
}

- (void)switchCameraInputDeviceToFront {

    [self.captureSession stopRunning];
    [self.captureSession removeInput:self.backCameraInput];
    
    if ([self.captureSession canAddInput:self.frontCameraInput]) {
        [self.captureSession addInput:self.frontCameraInput];
        [self switchCameraAnimation];
    }
}

- (void)swithCameraInputDeviceToBack {
    
    [self.captureSession stopRunning];
    [self.captureSession removeInput:self.frontCameraInput];
    
    if ([self.captureSession canAddInput:self.backCameraInput]) {
        [self.captureSession addInput:self.backCameraInput];
        [self switchCameraAnimation];
    }
}

- (void)openFlashLight {
    
    AVCaptureDevice *backCameraDevice;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionBack) {
            backCameraDevice = device;
            break;
        }
    }
    
    if (backCameraDevice.torchMode == AVCaptureTorchModeOff) {
        [backCameraDevice lockForConfiguration:nil];
        
        backCameraDevice.torchMode = AVCaptureTorchModeOn;
        backCameraDevice.flashMode = AVCaptureFlashModeOn;
        
        [backCameraDevice unlockForConfiguration];
    }
}

- (void)closeFlashLight {
    
    AVCaptureDevice *backCameraDevice;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionBack) {
            backCameraDevice = device;
            break;
        }
    }
    
    if (backCameraDevice.torchMode == AVCaptureTorchModeOn) {
        [backCameraDevice lockForConfiguration:nil];
        
        backCameraDevice.torchMode = AVCaptureTorchModeOff;
        backCameraDevice.flashMode = AVCaptureTorchModeOff;
        
        [backCameraDevice unlockForConfiguration];
    }
}

- (void)saveCurrentRecordingVideo {
    
    if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            [self saveCurrentRecordingVideoToPhotoLibrary];
        }];
    } else {
        [self saveCurrentRecordingVideoToPhotoLibrary];
    }
}

- (void)saveCurrentRecordingVideoToPhotoLibrary {
    
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:_videoFileURL];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (!error) {
            NSLog(@"Save video success!");
        } else {
            NSLog(@"Save video failure!");
        }
    }];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    BOOL isVideo = YES;
    
    if (!_isRecording) {
        return;
    }
    
    if (captureOutput != self.videoOutput) {
        isVideo = NO;
    }
    
    if (!_recordingWriter && !isVideo) {
        CMFormatDescriptionRef formatDescriptionRef = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        const AudioStreamBasicDescription *audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescriptionRef);
        _sampleRate = audioStreamBasicDescription -> mSampleRate;
        _audioChannel = audioStreamBasicDescription -> mChannelsPerFrame;
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"HH:mm:ss";
        NSDate *currentDate = [NSDate dateWithTimeIntervalSince1970:[[NSDate date] timeIntervalSince1970]];
        NSString *currentDateString = [dateFormatter stringFromDate:currentDate];
        NSString *videoName = [NSString stringWithFormat:@"video_%@.mp4", currentDateString];
        _videoPath = [self.cacheDirectoryPath stringByAppendingPathComponent:videoName];
        
        _recordingWriter = [VideoRecordingWriter recordingWriterWithVideoPath:_videoPath
                                                              resolutionWidth:_resolutionWidth resolutionHeight:_resolutionHeight
                                                                 audioChannel:_audioChannel sampleRate:_sampleRate];
    }
    
    CMTime presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    if (_startRecordingCMTime.value == 0) {
        _startRecordingCMTime = presentationTimeStamp;
    }
    
    CMTime subtract = CMTimeSubtract(presentationTimeStamp, _startRecordingCMTime);
    _currentRecordingTime = CMTimeGetSeconds(subtract);
    if (_currentRecordingTime > _maxRecordingTime) {
        if (_currentRecordingTime - _maxRecordingTime >= 0.1) {
            return;
        }
    }
    
    [_recordingWriter writeWithSampleBuffer:sampleBuffer isVideo:isVideo];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(updateRecordingProgress:)]) {
            [self.delegate updateRecordingProgress:_currentRecordingTime / _maxRecordingTime];
        }
    });
}

@end
