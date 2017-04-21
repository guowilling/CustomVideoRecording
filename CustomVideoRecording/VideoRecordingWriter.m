//
//  VideoRecordingWriter.m
//  CustomVideoRecording
//
//  Created by 郭伟林 on 17/1/18.
//  Copyright © 2017年 SR. All rights reserved.
//

#import "VideoRecordingWriter.h"

@interface VideoRecordingWriter ()

@property (nonatomic, copy, readwrite) NSString *videoPath;

@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *assetVideoInput;
@property (nonatomic, strong) AVAssetWriterInput *assetAudioInput;

@end

@implementation VideoRecordingWriter

- (void)dealloc {
    
    _assetWriter     = nil;
    _assetVideoInput = nil;
    _assetAudioInput = nil;
    _videoPath       = nil;
}

+ (instancetype)recordingWriterWithVideoPath:(NSString*)videoPath
                             resolutionWidth:(NSInteger)width
                            resolutionHeight:(NSInteger)height
                                audioChannel:(int)channel
                                  sampleRate:(Float64)rate
{
    return [[self alloc] initWithVideoPath:videoPath resolutionWidth:width resolutionHeight:height audioChannel:channel sampleRate:rate];
}

- (instancetype)initWithVideoPath:(NSString*)videoPath
                  resolutionWidth:(NSInteger)width
                 resolutionHeight:(NSInteger)height
                     audioChannel:(int)channel
                       sampleRate:(Float64)rate
{
    self = [super init];
    if (self) {
        _videoPath = videoPath;
        // 删除此路径下的文件如果已经存在, 保证文件是最新录制.
        [[NSFileManager defaultManager] removeItemAtPath:self.videoPath error:nil];
        // 初始化 AVAssetWriter, 写入媒体类型为 MP4.
        _assetWriter = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:self.videoPath] fileType:AVFileTypeMPEG4 error:nil];
        _assetWriter.shouldOptimizeForNetworkUse = YES;
        
        {
            // 初始化视频输入.
            // 配置视频的分辨率, 编码方式等.
            NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264, AVVideoCodecKey,
                                      @(width), AVVideoWidthKey,
                                      @(height), AVVideoHeightKey, nil];
            _assetVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
            _assetVideoInput.expectsMediaDataInRealTime = YES; // 调整输入应该处理实时数据源的数据.
            [_assetWriter addInput:_assetVideoInput];
        }
        
        if (channel != 0 && rate != 0) {
            // 初始化音频输入.
            // 配置音频的AAC, 音频通道, 采样率, 比特率等.
            NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:@(kAudioFormatMPEG4AAC), AVFormatIDKey,
                                      @(channel), AVNumberOfChannelsKey,
                                      @(rate), AVSampleRateKey,
                                      @(128000), AVEncoderBitRateKey, nil];
            _assetAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:settings];
            _assetAudioInput.expectsMediaDataInRealTime = YES;
            [_assetWriter addInput:_assetAudioInput];
        }
    }
    return self;
}

- (BOOL)writeWithSampleBuffer:(CMSampleBufferRef)sampleBuffer isVideo:(BOOL)isVideo {
    
    BOOL isSuccess;
    if (CMSampleBufferDataIsReady(sampleBuffer)) {
        if (_assetWriter.status == AVAssetWriterStatusUnknown && isVideo) { // 保证首先写入的是视频.
            [_assetWriter startWriting];
            [_assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
        }
        if (_assetWriter.status == AVAssetWriterStatusFailed) {
            NSLog(@"write error %@", _assetWriter.error.localizedDescription);
            isSuccess = NO;
        }
        
        if (isVideo) {
            if (_assetVideoInput.readyForMoreMediaData) {
                [_assetVideoInput appendSampleBuffer:sampleBuffer];
                isSuccess = YES;
            }
        } else {
            if (_assetAudioInput.readyForMoreMediaData) {
                [_assetAudioInput appendSampleBuffer:sampleBuffer];
                isSuccess = YES;
            }
        }
    }
    return isSuccess;
}

- (void)finishWritingWithCompletionHandler:(void (^)(void))handler {
    
    [_assetWriter finishWritingWithCompletionHandler:handler];
}

@end
